// Spec compliance tests for tool response handling.
//
// Validates two spec sections:
//   - §3.10 Tool Response Auto-Merge — when a `tool` action succeeds and no
//     `bindResult` is specified, the runtime merges top-level keys of the
//     response Map into page state (shallow overwrite, no deep merge).
//   - §4.4.2 Response/Error Context — onSuccess / onError child contexts
//     expose the response (or structured error) under the canonical `event`
//     binding scope, making `{{event.<field>}}` resolvable.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';

void main() {
  late ActionHandler actionHandler;
  late StateManager stateManager;
  late RenderContext context;

  setUp(() {
    actionHandler = ActionHandler();
    stateManager = StateManager();
    final bindingEngine = BindingEngine();
    final themeManager = ThemeManager();
    final widgetRegistry = WidgetRegistry();
    final renderer = Renderer(
      widgetRegistry: widgetRegistry,
      bindingEngine: bindingEngine,
      actionHandler: actionHandler,
      stateManager: stateManager,
    );

    context = RenderContext(
      renderer: renderer,
      stateManager: stateManager,
      bindingEngine: bindingEngine,
      actionHandler: actionHandler,
      themeManager: themeManager,
    );
  });

  tearDown(() {
    stateManager.dispose();
  });

  group('Spec §3.10: Tool Response Auto-Merge', () {
    test('Basic shallow merge — top-level keys merge into page state',
        () async {
      actionHandler.registerToolExecutor('echo', (params) async {
        return {'a': 1, 'b': 2};
      });

      final result = await actionHandler.execute(
        {'type': 'tool', 'tool': 'echo', 'params': {}},
        context,
      );

      expect(result.success, isTrue);
      expect(stateManager.get<int>('a'), equals(1));
      expect(stateManager.get<int>('b'), equals(2));
    });

    test(
        'Nested overwrite (shallow) — nested objects replace, no deep merge',
        () async {
      // Per spec §3.10.2: nested objects replace existing values entirely.
      stateManager.set('user', {'name': 'Alice'});

      actionHandler.registerToolExecutor('updateUser', (params) async {
        return {
          'user': {'age': 30},
        };
      });

      final result = await actionHandler.execute(
        {'type': 'tool', 'tool': 'updateUser', 'params': {}},
        context,
      );

      expect(result.success, isTrue);
      final user = stateManager.get<Map<String, dynamic>>('user');
      expect(user, equals({'age': 30}));
      // Alice must be gone — shallow overwrite semantics.
      expect(user!.containsKey('name'), isFalse);
    });

    test(
        'bindResult escape — explicit bindResult bypasses auto-merge',
        () async {
      actionHandler.registerToolExecutor('compute', (params) async {
        return {'a': 1};
      });

      final result = await actionHandler.execute(
        {
          'type': 'tool',
          'tool': 'compute',
          'params': {},
          'bindResult': 'result',
        },
        context,
      );

      expect(result.success, isTrue);
      expect(stateManager.get<Map<String, dynamic>>('result'),
          equals({'a': 1}));
      // Top-level `a` must NOT leak into page state when bindResult is set.
      expect(stateManager.get('a'), isNull);
    });
  });

  group('Spec §4.4.2: Response/Error Context (event.*)', () {
    test('onSuccess — {{event.<field>}} resolves from response data',
        () async {
      actionHandler.registerToolExecutor('answer', (params) async {
        return {'a': 42};
      });

      final result = await actionHandler.execute(
        {
          'type': 'tool',
          'tool': 'answer',
          'params': {},
          // Use bindResult to avoid auto-merge contaminating state.a; this
          // test asserts the event.* context, not the merge behavior.
          'bindResult': '_unused',
          'onSuccess': {
            'type': 'state',
            'action': 'set',
            'binding': 'saved',
            'value': '{{event.a}}',
          },
        },
        context,
      );

      expect(result.success, isTrue);
      expect(stateManager.get<int>('saved'), equals(42));
    });

    test('onError — {{event.message}} resolves from error message',
        () async {
      actionHandler.registerToolExecutor('boom', (params) async {
        throw Exception('something went wrong');
      });

      final result = await actionHandler.execute(
        {
          'type': 'tool',
          'tool': 'boom',
          'params': {},
          'onError': {
            'type': 'state',
            'action': 'set',
            'binding': 'msg',
            'value': '{{event.message}}',
          },
        },
        context,
      );

      expect(result.success, isFalse);
      final msg = stateManager.get<String>('msg');
      expect(msg, isNotNull);
      expect(msg, contains('something went wrong'));
    });
  });

  group('Accumulation regression — repeated tool calls update state',
      () {
    // Per memory `feedback_accumulation_test_gap`: list / accumulation paths
    // must be verified with N >= 2 invocations so that an RFC 6902
    // "add on existing replace" defect cannot hide behind a single-shot test.
    test('Two successive tool calls — state.count advances 1 -> 2',
        () async {
      var callCount = 0;
      actionHandler.registerToolExecutor('tick', (params) async {
        callCount += 1;
        return {'count': callCount};
      });

      final events = <StateChangeEvent>[];
      final subscription = stateManager.stream
          .where((e) => e.path == 'count')
          .listen(events.add);

      final r1 = await actionHandler.execute(
        {'type': 'tool', 'tool': 'tick', 'params': {}},
        context,
      );
      expect(r1.success, isTrue);
      expect(stateManager.get<int>('count'), equals(1));

      final r2 = await actionHandler.execute(
        {'type': 'tool', 'tool': 'tick', 'params': {}},
        context,
      );
      expect(r2.success, isTrue);
      expect(stateManager.get<int>('count'), equals(2));

      // Allow stream events to drain before assertion.
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      // Two distinct set() calls on `count` must each fire a StateChangeEvent.
      expect(events.length, equals(2));
      expect(events[0].newValue, equals(1));
      expect(events[1].newValue, equals(2));
    });
  });
}
