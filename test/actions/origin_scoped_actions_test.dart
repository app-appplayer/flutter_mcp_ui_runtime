// Tool calls and resource reads from inside an embedded `view`.
//
// A composed subtree belongs to the origin it came from (§1.9.5, §7.10): a
// tool it calls has to reach THAT device's session, not the app's own server.
// Without the host hooks the subtree renders and nothing in it works — the
// call takes the app's normal path and lands on a session with no client for
// it — so the refusals here are the difference between a screen that says it
// cannot reach the device and one that shows a label with no reading beside
// it.

import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ActionHandler handler;
  late StateManager stateManager;
  late Renderer renderer;
  late RenderContext appContext;

  const origin = {'connection': 'device-a', 'label': 'Gateway'};

  setUp(() {
    handler = ActionHandler();
    stateManager = StateManager()..initialize(<String, dynamic>{});
    final bindingEngine = BindingEngine();
    renderer = Renderer(
      widgetRegistry: WidgetRegistry(),
      bindingEngine: bindingEngine,
      actionHandler: handler,
      stateManager: stateManager,
    );
    appContext = RenderContext(
      renderer: renderer,
      stateManager: stateManager,
      bindingEngine: bindingEngine,
      actionHandler: handler,
      themeManager: ThemeManager.instance,
    );
  });

  /// A context standing inside an embedded definition from [origin].
  RenderContext embedded() =>
      appContext.createChildContext()..origin = Map<String, dynamic>.from(origin);

  group('a tool called from an embedded subtree', () {
    test('goes to the origin the subtree came from', () async {
      final calls = <List<dynamic>>[];
      renderer.originToolCaller = (o, tool, params) async {
        calls.add([o, tool, params]);
        return {'rows': 3};
      };
      handler.registerToolExecutor('fetch', (params) async {
        fail('the app\'s own executor must not be used for an embedded call');
      });

      final result = await handler.execute({
        'type': 'tool',
        'tool': 'fetch',
        'params': {'q': 'ada'},
      }, embedded());

      expect(result.success, isTrue);
      expect(calls.single[0], origin);
      expect(calls.single[1], 'fetch');
      expect(calls.single[2], {'q': 'ada'});
      expect(result.data, {'rows': 3});

      // Recorded, not asserted as correct: the ORIGIN path hands the answer
      // back as `result.data` and does NOT auto-merge its top-level keys into
      // state, which §3.10 does for an ordinary tool call. A composed panel
      // that calls a tool and binds `{{rows}}` therefore shows nothing.
      // Whether the two paths should converge is a spec call, not a test fix.
      expect(stateManager.get('rows'), isNull);
    });

    test('a host with no origin caller refuses rather than misrouting',
        () async {
      handler.registerToolExecutor('fetch', (params) async => {'rows': 3});

      final result = await handler
          .execute({'type': 'tool', 'tool': 'fetch'}, embedded());

      expect(result.success, isFalse,
          reason: 'falling back to the app\'s own session would run another '
              'server\'s tool call against this one');
      expect(stateManager.get('rows'), isNull);
    });

    test('a failing origin call is reported with the tool named', () async {
      renderer.originToolCaller = (o, tool, params) async =>
          throw StateError('the device is offline');

      final result = await handler
          .execute({'type': 'tool', 'tool': 'fetch'}, embedded());

      expect(result.success, isFalse);
      expect(result.error, contains('fetch'));
      expect(result.error, contains('offline'));
    });

    test('an ordinary context still uses the app\'s own executor', () async {
      renderer.originToolCaller = (o, tool, params) async =>
          fail('an unembedded call must not be routed to an origin');
      handler.registerToolExecutor('fetch', (params) async => {'rows': 1});

      final result =
          await handler.execute({'type': 'tool', 'tool': 'fetch'}, appContext);

      expect(result.success, isTrue);
      expect(stateManager.get('rows'), 1);
    });
  });

  group('a resource read from an embedded subtree', () {
    test('goes through the origin reader, once', () async {
      var reads = 0;
      renderer.originResourceReader = (o, uri) async {
        reads++;
        return {'temperature': 21};
      };

      final result = await handler.execute({
        'type': 'resource',
        'action': 'read',
        'uri': 'device://sensor',
        'binding': 'reading',
      }, embedded());

      expect(result.success, isTrue);
      expect(reads, 1,
          reason: 'a read that leaves a subscription behind keeps a device '
              'pushing to a view that asked once');
      expect(stateManager.get('reading'), {'temperature': 21});
    });

    test('with no binding the uri is the binding', () async {
      renderer.originResourceReader = (o, uri) async => 21;

      await handler.execute({
        'type': 'resource',
        'action': 'read',
        'uri': 'device://sensor',
      }, embedded());

      expect(stateManager.get('device://sensor'), 21);
    });

    test('a host with no origin reader refuses rather than reading its own',
        () async {
      final result = await handler.execute({
        'type': 'resource',
        'action': 'read',
        'uri': 'device://sensor',
        'binding': 'reading',
      }, embedded());

      expect(result.success, isFalse);
      expect(result.error, contains('cannot read'),
          reason: 'reading through the app\'s own path returns the embedder\'s '
              'resource under the embedded uri — a wrong answer rather than a '
              'missing one');
    });

    test('a failing read is reported', () async {
      renderer.originResourceReader =
          (o, uri) async => throw StateError('no such resource');

      final result = await handler.execute({
        'type': 'resource',
        'action': 'read',
        'uri': 'device://sensor',
        'binding': 'reading',
      }, embedded());

      expect(result.success, isFalse);
      expect(result.error, contains('failed on origin'));
    });
  });

  group('a resource subscription from an embedded subtree', () {
    test('watches through the origin, and updates land at the binding',
        () async {
      void Function(dynamic)? push;
      var disposed = 0;
      renderer.originResourceWatcher = (o, uri, onUpdate) async {
        push = onUpdate;
        return () => disposed++;
      };

      final result = await handler.execute({
        'type': 'resource',
        'action': 'subscribe',
        'uri': 'device://sensor',
        'binding': 'reading',
      }, embedded());

      expect(result.success, isTrue);
      push!({'temperature': 22});
      expect(stateManager.get('reading'), {'temperature': 22},
          reason: 'without this the subtree renders the reading\'s label and '
              'never a number, which looks like a layout bug');

      final unsubscribed = await handler.execute({
        'type': 'resource',
        'action': 'unsubscribe',
        'uri': 'device://sensor',
      }, embedded());

      expect(unsubscribed.success, isTrue);
      expect(disposed, 1);
    });

    test('re-subscribing replaces the watch rather than stacking one',
        () async {
      var disposed = 0;
      renderer.originResourceWatcher =
          (o, uri, onUpdate) async => () => disposed++;

      final action = {
        'type': 'resource',
        'action': 'subscribe',
        'uri': 'device://sensor',
        'binding': 'reading',
      };
      await handler.execute(action, embedded());
      await handler.execute(action, embedded());

      expect(disposed, 1,
          reason: 'a second watch on the same uri would double every update');

      await handler.execute({
        'type': 'resource',
        'action': 'unsubscribe',
        'uri': 'device://sensor',
      }, embedded());
    });

    test('a subscribe with no binding is refused', () async {
      renderer.originResourceWatcher = (o, uri, onUpdate) async => () {};

      final result = await handler.execute({
        'type': 'resource',
        'action': 'subscribe',
        'uri': 'device://sensor',
      }, embedded());

      expect(result.success, isFalse);
      expect(result.error, contains('Binding is required'),
          reason: 'a subscription with nowhere to put its updates is a stream '
              'nobody reads');
    });

    test('a host with no origin watcher refuses', () async {
      final result = await handler.execute({
        'type': 'resource',
        'action': 'subscribe',
        'uri': 'device://sensor',
        'binding': 'reading',
      }, embedded());

      expect(result.success, isFalse);
      expect(result.error, contains('cannot watch another origin'));
    });

    test('a failing subscribe fires onSubscriptionError', () async {
      renderer.originResourceWatcher =
          (o, uri, onUpdate) async => throw StateError('refused by the device');

      final result = await handler.execute({
        'type': 'resource',
        'action': 'subscribe',
        'uri': 'device://sensor',
        'binding': 'reading',
        'onSubscriptionError': {
          'type': 'state',
          'action': 'set',
          'binding': 'problem',
          'value': 'the device refused',
        },
      }, embedded());

      expect(result.success, isFalse);
      expect(stateManager.get('problem'), 'the device refused',
          reason: 'a composed panel that cannot subscribe has to be able to '
              'say so in its own words');
    });

    test('unsubscribing something that was never subscribed is not an error',
        () async {
      final result = await handler.execute({
        'type': 'resource',
        'action': 'unsubscribe',
        'uri': 'device://nothing',
      }, embedded());

      expect(result.success, isTrue);
    });
  });
}
