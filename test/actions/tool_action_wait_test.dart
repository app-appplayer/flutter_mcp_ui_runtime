// `tool` actions: how long the runtime waits for the result, and how the
// person ends the wait (spec 04_Actions §4.4, §4.11, §4.15, §4.16).
//
// The document sets the limit: omitted is 30000 ms, `0` is no limit. A call
// that needs a person in the middle of it — a sign-in sheet raised by the
// host — runs past any fixed limit, so `0` has to wait it out and still apply
// the result. While it waits, the person can still end it: an explicit
// `cancel`, or leaving the page.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_result.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/tool_call_signal.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/models/ui_definition.dart';
import 'package:flutter_mcp_ui_runtime/src/routing/page_state_scope.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/runtime_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ActionHandler handler;
  late StateManager stateManager;
  late int calls;
  late Completer<dynamic> pending;
  Future<String>? signal;
  String? signalled;

  /// Records what the executor saw as [ToolCallSignal.current].
  void watchSignal() {
    signal = ToolCallSignal.current;
    signalled = null;
    signal?.then((reason) => signalled = reason);
  }

  RenderContext contextFor(BuildContext? build) {
    final engine = BindingEngine();
    return RenderContext(
      renderer: Renderer(
        widgetRegistry: WidgetRegistry(),
        bindingEngine: engine,
        actionHandler: handler,
        stateManager: stateManager,
      ),
      stateManager: stateManager,
      actionHandler: handler,
      themeManager: ThemeManager(),
      bindingEngine: engine,
      buildContext: build,
    );
  }

  /// The tool `open` answers only when [pending] completes.
  void wire() {
    calls = 0;
    pending = Completer<dynamic>();
    stateManager = StateManager()..initialize(<String, dynamic>{});
    handler = ActionHandler();
    handler.registerToolExecutor('open', (Map<String, dynamic> params) {
      calls++;
      watchSignal();
      return pending.future;
    });
  }

  Map<String, dynamic> setFlag(String binding) => <String, dynamic>{
        'type': 'state',
        'action': 'set',
        'binding': binding,
        'value': true,
      };

  test('outside a tool executor there is no signal', () {
    expect(ToolCallSignal.current, isNull);
  });

  group('the limit the document sets', () {
    test('timeout 0 waits as long as the call takes and applies the result',
        () {
      FakeAsync().run((async) {
        wire();
        final context = contextFor(null);
        ActionResult? result;
        handler.execute({
          'type': 'tool',
          'tool': 'open',
          'timeout': 0,
          'loading': 'busy',
          'onSuccess': setFlag('opened'),
        }, context).then((r) => result = r);

        // A person signing in mid-call: ten minutes, far past 30 s.
        async.elapse(const Duration(minutes: 10));
        expect(result, isNull, reason: '0 means no limit');
        expect(stateManager.get('busy'), isTrue);

        pending.complete(<String, dynamic>{'holder': true});
        async.flushMicrotasks();
        expect(result!.success, isTrue);
        expect(stateManager.get('holder'), isTrue);
        expect(stateManager.get('opened'), isTrue);
        expect(stateManager.get('busy'), isFalse);
        expect(calls, 1, reason: 'one press, one call');
        expect(signal, isNotNull);
        expect(signalled, isNull,
            reason: 'a call that answered was not dropped');
      });
    });

    test('an omitted timeout is 30000 ms and reports TIMEOUT to onError', () {
      FakeAsync().run((async) {
        wire();
        final context = contextFor(null);
        ActionResult? result;
        handler.execute({
          'type': 'tool',
          'tool': 'open',
          'onTimeout': setFlag('timedOut'),
          'onError': <String, dynamic>{
            'type': 'state',
            'action': 'set',
            'binding': 'code',
            'value': '{{event.code}}',
          },
        }, context).then((r) => result = r);

        async.elapse(const Duration(milliseconds: 29999));
        expect(result, isNull);
        async.elapse(const Duration(milliseconds: 1));
        expect(result!.errorCode, ActionResult.timeoutCode);
        expect(signalled, ToolCallSignal.timeout,
            reason: 'the host is told so it can cancel on its side');
        expect(stateManager.get('timedOut'), isTrue);
        expect(calls, 1);
        expect(stateManager.get('code'), ActionResult.timeoutCode);
      });
    });

    test('a result that arrives after the limit is dropped', () {
      FakeAsync().run((async) {
        wire();
        handler.execute(
            {'type': 'tool', 'tool': 'open', 'timeout': 50}, contextFor(null));
        async.elapse(const Duration(milliseconds: 60));
        pending.complete(<String, dynamic>{'late': true});
        async.flushMicrotasks();
        expect(stateManager.get('late'), isNull);
      });
    });
  });

  group('the person ends the wait', () {
    test('cancel ends a cancellable call: onCancel runs, onError does not', () {
      FakeAsync().run((async) {
        wire();
        final context = contextFor(null);
        ActionResult? result;
        handler.execute({
          'type': 'tool',
          'tool': 'open',
          'timeout': 0,
          'cancellable': true,
          'loading': 'busy',
          'onCancel': setFlag('cancelled'),
          'onError': setFlag('failed'),
        }, context).then((r) => result = r);
        async.flushMicrotasks();

        handler.execute({'type': 'cancel', 'target': 'open'}, context);
        async.flushMicrotasks();
        expect(result!.errorCode, ActionResult.cancelledCode);
        expect(signalled, ToolCallSignal.cancelled);
        expect(stateManager.get('cancelled'), isTrue);
        expect(stateManager.get('failed'), isNull);
        expect(stateManager.get('busy'), isFalse);

        pending.complete(<String, dynamic>{'late': true});
        async.flushMicrotasks();
        expect(stateManager.get('late'), isNull,
            reason: 'the person already left this call');
      });
    });

    test('cancel targets the action id when the action has one', () {
      FakeAsync().run((async) {
        wire();
        final context = contextFor(null);
        ActionResult? result;
        handler.execute({
          'type': 'tool',
          'tool': 'open',
          'id': 'holderOpen',
          'timeout': 0,
          'cancellable': true,
        }, context).then((r) => result = r);
        async.flushMicrotasks();

        handler.execute({'type': 'cancel', 'target': 'open'}, context);
        async.flushMicrotasks();
        expect(result, isNull,
            reason: 'the id, not the tool name, is the target');

        handler.execute({'type': 'cancel', 'target': 'holderOpen'}, context);
        async.flushMicrotasks();
        expect(result!.errorCode, ActionResult.cancelledCode);
      });
    });

    test('cancel leaves a call that is not cancellable running', () {
      FakeAsync().run((async) {
        wire();
        final context = contextFor(null);
        ActionResult? result;
        handler.execute({'type': 'tool', 'tool': 'open', 'timeout': 0},
            context).then((r) => result = r);
        async.flushMicrotasks();

        handler.execute({'type': 'cancel', 'target': 'open'}, context);
        async.flushMicrotasks();
        expect(result, isNull);

        pending.complete(<String, dynamic>{'ok': true});
        async.flushMicrotasks();
        expect(result!.success, isTrue);
      });
    });

    test('a call scoped to another origin waits and cancels the same way', () {
      FakeAsync().run((async) {
        wire();
        final originCall = Completer<dynamic>();
        final context = contextFor(null);
        context.renderer.originToolCaller = (origin, tool, params) {
          calls++;
          watchSignal();
          return originCall.future;
        };
        final scoped = context..origin = <String, dynamic>{'server': 'served'};
        ActionResult? result;
        handler.execute({
          'type': 'tool',
          'tool': 'open',
          'timeout': 0,
          'cancellable': true,
        }, scoped).then((r) => result = r);

        async.elapse(const Duration(minutes: 5));
        expect(result, isNull);
        handler.execute({'type': 'cancel', 'target': 'open'}, scoped);
        async.flushMicrotasks();
        expect(result!.errorCode, ActionResult.cancelledCode);
        expect(signalled, ToolCallSignal.cancelled);
      });
    });
  });

  group('the page that started the call', () {
    late RuntimeEngine engine;

    setUp(() async {
      engine = RuntimeEngine(enableDebugMode: false);
      await engine.initialize(definition: <String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{'type': 'text', 'content': 'root'},
      });
      pending = Completer<dynamic>();
      engine.actionHandler.registerToolExecutor('open',
          (Map<String, dynamic> params) {
        watchSignal();
        return pending.future;
      });
    });

    tearDown(() async {
      NavigationActionExecutor.clearOnExitCallback();
      await engine.destroy();
    });

    PageDefinition page(String body) => PageDefinition(
          route: '/$body',
          content: <String, dynamic>{'type': 'text', 'content': body},
        );

    RenderContext engineContext(BuildContext build) => RenderContext(
          renderer: engine.renderer,
          stateManager: engine.stateManager,
          actionHandler: engine.actionHandler,
          themeManager: ThemeManager(),
          bindingEngine: engine.bindingEngine,
          buildContext: build,
        );

    Future<ActionResult?> Function() startIn(WidgetTester tester, String body) {
      ActionResult? result;
      engine.actionHandler.execute({
        'type': 'tool',
        'tool': 'open',
        'timeout': 0,
        'onCancel': setFlag('cancelled'),
        'onError': setFlag('failed'),
      }, engineContext(tester.element(find.text(body)))).then(
          (r) => result = r);
      return () async => result;
    }

    testWidgets('removing it ends the wait without running callbacks',
        (tester) async {
      final show = ValueNotifier<bool>(true);
      await tester.pumpWidget(MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: show,
          builder: (_, visible, __) => visible
              ? MCPPageWidget(pageDefinition: page('a'), runtimeEngine: engine)
              : const SizedBox(),
        ),
      ));
      await tester.pumpAndSettle();
      final result = startIn(tester, 'a');
      await tester.pump();

      show.value = false;
      await tester.pumpAndSettle();

      expect((await result())!.errorCode, ActionResult.cancelledCode);
      await tester.pump();
      expect(signalled, ToolCallSignal.pageRemoved);
      expect(engine.stateManager.get('cancelled'), isNull,
          reason: 'no page is left to show a callback on');
      expect(engine.stateManager.get('failed'), isNull);
    });

    testWidgets('removing another page leaves it waiting', (tester) async {
      final showB = ValueNotifier<bool>(true);
      await tester.pumpWidget(MaterialApp(
        home: Column(children: [
          Expanded(
              child: MCPPageWidget(
                  pageDefinition: page('a'), runtimeEngine: engine)),
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: showB,
              builder: (_, visible, __) => visible
                  ? MCPPageWidget(
                      pageDefinition: page('b'), runtimeEngine: engine)
                  : const SizedBox(),
            ),
          ),
        ]),
      ));
      await tester.pumpAndSettle();
      final result = startIn(tester, 'a');
      await tester.pump();

      showB.value = false;
      await tester.pumpAndSettle();
      expect(await result(), isNull,
          reason: 'a wait belongs to the page that started it');

      pending.complete(<String, dynamic>{'opened': true});
      for (var i = 0; i < 50 && await result() == null; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump();
      }
      expect((await result())!.success, isTrue);
    });
  });
}
