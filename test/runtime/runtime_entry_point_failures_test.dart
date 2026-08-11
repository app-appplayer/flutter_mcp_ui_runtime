// The runtime's public entry points when the thing they are asked to build is
// not there: an engine torn down under a live runtime, a definition that
// cannot be parsed at all, a page whose content the renderer cannot read, and
// a trust level granted before there is anything to grant it to.
//
// Each of these is a single line whose whole job is to say what went wrong.
// A silent `SizedBox` in their place is the failure that costs a day, because
// an empty screen is also what a correct document looks like while it loads.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildUI with nothing to build', () {
    testWidgets('an engine destroyed under a live runtime is named',
        (tester) async {
      final runtime = MCPUIRuntime();
      await runtime.initialize({
        'type': 'page',
        'content': {'type': 'text', 'content': 'hello'},
      });

      // The engine is reachable on its own, and a host that tears it down
      // still holds a runtime that believes it is initialised.
      await runtime.engine.destroy();

      expect(
        () => runtime.buildUI(),
        throwsA(isA<StateError>().having((e) => e.message, 'message',
            contains('No UI definition'))),
        reason: 'returning an empty widget here would look exactly like a '
            'page that renders nothing, and the host would go looking in the '
            'document',
      );
    });
  });

  group('trust level with nothing to grant to', () {
    tearDown(() => MCPLogger.onRecord = null);

    testWidgets('a grant that cannot be applied says so', (tester) async {
      final runtime = MCPUIRuntime();
      await runtime.initialize({
        'type': 'page',
        'content': {'type': 'text', 'content': 'hello'},
      });

      // The permission manager belongs to the client action executors the
      // runtime registers. A host that supplies its own implementations for
      // all of them — which `registerExecutor` is public in order to allow —
      // leaves nothing holding one.
      for (final type in ClientActionTypes.all) {
        runtime.engine.actionHandler.registerExecutor(type, _InertExecutor());
      }
      expect(runtime.engine.actionHandler.permissionManager, isNull,
          reason: 'the state this branch exists for; if a manager survives '
              'here the branch is unreachable and should be recorded as such '
              'rather than tested');

      final records = <String>[];
      MCPLogger.onRecord = (record) => records.add(record.message);

      runtime.setTrustLevel(TrustLevel.full);

      expect(records.where((m) => m.contains('NOT applied')), isNotEmpty,
          reason: 'the grant cannot be kept for later — the field that used '
              'to hold it is only read by `initialize`, which has already '
              'run — so a silent store would be a permission the host thinks '
              'it granted and the runtime never applied');

      await runtime.destroy();
    });
  });

  group('MCPUIRuntimeHelper.render', () {
    testWidgets('a definition that is neither application nor page shows the '
        'error rather than spinning forever', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MCPUIRuntimeHelper.render(const {
          'type': 'dashboard',
          'content': {'type': 'text', 'content': 'hi'},
        }),
      ));

      // `initialize` is genuinely asynchronous, so the rejection lands
      // outside the fake-async clock; a bare `pump` returns before the future
      // has failed at all.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();

      expect(find.byType(ErrorWidget), findsOneWidget,
          reason: 'without this branch the helper sits on its progress '
              'indicator for the rest of the session, which is what a slow '
              'load looks like too');
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a rebuild does not start a second runtime', (tester) async {
      final calls = <String>[];
      final page = <String, dynamic>{
        'type': 'page',
        'content': {'type': 'text', 'content': 'hello'},
        'lifecycle': {
          'onReady': [
            {'type': 'tool', 'tool': 'ready'}
          ]
        },
      };

      Widget host() => MaterialApp(
            home: MCPUIRuntimeHelper.render(
              page,
              onToolCall: (tool, params) => calls.add(tool),
            ),
          );

      await tester.pumpWidget(host());
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      await tester.pump();

      final afterFirst = calls.length;
      expect(afterFirst, greaterThan(0),
          reason: 'if the hook never fires at all this test cannot tell one '
              'runtime from two, and would pass either way');

      // Anything that rebuilds the subtree — a theme change, a rotation, a
      // parent's setState — used to construct and initialise a whole new
      // runtime and drop the previous one without destroying it.
      await tester.pumpWidget(host());
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      await tester.pump();

      expect(calls.length, afterFirst,
          reason: 'a second `onReady` means a second runtime was built for '
              'the same document — the first is still alive, still holding '
              'its channels, and nobody will ever destroy it');
    });

    testWidgets('a different document does get its own runtime',
        (tester) async {
      final calls = <String>[];

      Widget host(Map<String, dynamic> page) => MaterialApp(
            home: MCPUIRuntimeHelper.render(
              page,
              onToolCall: (tool, params) => calls.add(tool),
            ),
          );

      Map<String, dynamic> pageNamed(String text) => <String, dynamic>{
            'type': 'page',
            'content': {'type': 'text', 'content': text},
            'lifecycle': {
              'onReady': [
                {'type': 'tool', 'tool': 'ready-$text'}
              ]
            },
          };

      await tester.pumpWidget(host(pageNamed('one')));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      await tester.pump();

      await tester.pumpWidget(host(pageNamed('two')));
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
      }

      expect(find.text('two'), findsOneWidget,
          reason: 'holding the first runtime for a document that changed '
              'would leave the old page on screen — the opposite failure, and '
              'the reason the check is on the definition rather than on '
              'having built once');
      expect(find.text('one'), findsNothing);
      expect(calls, contains('ready-one'),
          reason: 'the first document did run, so this is measuring a '
              'replacement rather than a document that never started');
    });

    testWidgets('a host that goes away mid-initialisation leaves nothing '
        'running', (tester) async {
      final calls = <String>[];
      final page = <String, dynamic>{
        'type': 'page',
        'content': {'type': 'text', 'content': 'hello'},
        'lifecycle': {
          'onReady': [
            {'type': 'tool', 'tool': 'ready'}
          ]
        },
      };

      await tester.pumpWidget(MaterialApp(
        home: MCPUIRuntimeHelper.render(
          page,
          onToolCall: (tool, params) => calls.add(tool),
        ),
      ));

      // Torn down while `initialize` is still in flight — the frame that
      // would have built the UI never comes. The wait afterwards is real time,
      // so the runtime genuinely finishes initialising with nobody left to
      // hold it; without it this test would pass by measuring an
      // initialisation that never completed at all.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester
          .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(calls, isEmpty,
          reason: 'a runtime finished after its host is gone has nobody to '
              'draw it and nobody to destroy it; it would keep its channels '
              'and its state for the life of the process');
    });
  });
}

/// An executor that answers nothing — it exists to take a client action type
/// away from the wrapper that owns the permission manager.
class _InertExecutor extends ActionExecutor {
  @override
  Future<ActionResult> execute(
    Map<String, dynamic> action,
    RenderContext context,
  ) async =>
      ActionResult.success();
}
