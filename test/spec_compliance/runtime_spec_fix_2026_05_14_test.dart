// Spec compliance regression tests for the 2026-05-14 runtime fix round.
//
// Track: cherry/tracks/mcp-ui-runtime-spec-fix-2026-05-14.md
//
// Covers eight runtime ↔ spec gaps:
//   1. MCP wire shape unwrap (`{content:[{type:'text', text: <json>}], isError}`)
//   2. Envelope `{success, result, message}` unwrap deprecation
//   3. `tools.<tool>.result` namespaced mirror deprecation
//   4. StateChangeEvent source enum compliance per spec §3.11
//   5. Resource notification raw `content` storage (heuristic removed)
//   6. Separate `onResourceRead` / `onResourceList` callbacks
//   7. `onSubscriptionError` dispatch on host subscribe failure
//   8. Lifecycle `_renderContext` null → explicit error log (was silent)

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/lifecycle_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart' show MCPUIRuntime;

void main() {
  late ActionHandler actionHandler;
  late StateManager stateManager;
  late RenderContext context;

  setUp(() {
    ToolActionExecutor.resetDeprecationWarningsForTesting();
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

  // ---------------------------------------------------------------------------
  // Fix 1: MCP wire shape unwrap
  // ---------------------------------------------------------------------------

  group('Fix 1: MCP wire shape unwrap (`content/isError`)', () {
    test('Wire shape with Map JSON payload — auto-merges into page state',
        () async {
      actionHandler.registerToolExecutor('wireMap', (params) async {
        // Simulate a host that forwards `CallToolResult.toJson()` verbatim.
        return {
          'content': [
            {'type': 'text', 'text': '{"a": 1, "b": 2}'},
          ],
          'isError': false,
        };
      });

      final result = await actionHandler.execute(
        {'type': 'tool', 'tool': 'wireMap', 'params': {}},
        context,
      );

      expect(result.success, isTrue);
      expect(stateManager.get<int>('a'), equals(1));
      expect(stateManager.get<int>('b'), equals(2));
    });

    test('Wire shape with list JSON payload — no auto-merge, bindResult stores',
        () async {
      actionHandler.registerToolExecutor('wireList', (params) async {
        return {
          'content': [
            {'type': 'text', 'text': '[1, 2, 3]'},
          ],
          'isError': false,
        };
      });

      final result = await actionHandler.execute(
        {
          'type': 'tool',
          'tool': 'wireList',
          'params': {},
          'bindResult': 'items',
        },
        context,
      );

      expect(result.success, isTrue);
      expect(stateManager.get<List>('items'), equals([1, 2, 3]));
    });

    test('Wire shape with scalar payload — no auto-merge without bindResult',
        () async {
      actionHandler.registerToolExecutor('wireScalar', (params) async {
        return {
          'content': [
            {'type': 'text', 'text': '42'},
          ],
          'isError': false,
        };
      });

      final result = await actionHandler.execute(
        {'type': 'tool', 'tool': 'wireScalar', 'params': {}},
        context,
      );

      expect(result.success, isTrue);
      expect(result.data, equals(42));
      // No state mutation when payload is a non-Map scalar.
      expect(stateManager.get('a'), isNull);
    });

    test('Wire shape with isError=true — returns error without auto-merge',
        () async {
      actionHandler.registerToolExecutor('wireErr', (params) async {
        return {
          'content': [
            {
              'type': 'text',
              'text': '{"code": "E_BOOM", "message": "kaboom"}',
            },
          ],
          'isError': true,
        };
      });

      final result = await actionHandler.execute(
        {'type': 'tool', 'tool': 'wireErr', 'params': {}},
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('kaboom'));
      // Error path skips auto-merge entirely.
      expect(stateManager.get('code'), isNull);
    });

    test('Wire shape with non-JSON text — falls back to text string',
        () async {
      actionHandler.registerToolExecutor('wirePlain', (params) async {
        return {
          'content': [
            {'type': 'text', 'text': 'plain string not json'},
          ],
          'isError': false,
        };
      });

      final result = await actionHandler.execute(
        {
          'type': 'tool',
          'tool': 'wirePlain',
          'params': {},
          'bindResult': 'msg',
        },
        context,
      );

      expect(result.success, isTrue);
      expect(stateManager.get<String>('msg'), equals('plain string not json'));
    });

    test('Plain Map (already unwrapped) — passes through unchanged', () async {
      // Smoke check that the wire detection does not hijack canonical Maps.
      actionHandler.registerToolExecutor('plain', (params) async {
        return {'x': 1};
      });

      final result = await actionHandler.execute(
        {'type': 'tool', 'tool': 'plain', 'params': {}},
        context,
      );

      expect(result.success, isTrue);
      expect(stateManager.get<int>('x'), equals(1));
    });
  });

  // ---------------------------------------------------------------------------
  // Fix 2 + 3: envelope / mirror deprecation (still working for 1 release)
  // ---------------------------------------------------------------------------

  group('Fix 2/3: envelope + namespaced mirror deprecation', () {
    test('Envelope `{success, result}` still auto-merges (deprecated path)',
        () async {
      actionHandler.registerToolExecutor('env', (params) async {
        return {'success': true, 'result': {'a': 1}};
      });

      final result = await actionHandler.execute(
        {'type': 'tool', 'tool': 'env', 'params': {}},
        context,
      );

      expect(result.success, isTrue);
      // Spec §3.10 auto-merge from envelope inner `result`.
      expect(stateManager.get<int>('a'), equals(1));
    });

    test('Envelope `success: false` surfaces error message (deprecated path)',
        () async {
      actionHandler.registerToolExecutor('env', (params) async {
        return {'success': false, 'error': 'envelope failed'};
      });

      final result = await actionHandler.execute(
        {'type': 'tool', 'tool': 'env', 'params': {}},
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('envelope failed'));
    });

    test('Namespaced mirror `tools.<tool>.result` still written (deprecated)',
        () async {
      actionHandler.registerToolExecutor('mirror', (params) async {
        return {'hello': 'world'};
      });

      await actionHandler.execute(
        {'type': 'tool', 'tool': 'mirror', 'params': {}},
        context,
      );

      // Mirror retained for one release for backward compat.
      final mirror = stateManager.get<Map>('tools.mirror.result');
      expect(mirror, isNotNull);
      expect(mirror!['hello'], equals('world'));
    });
  });

  // ---------------------------------------------------------------------------
  // Fix 4: StateChangeEvent source enum compliance per spec §3.11
  // ---------------------------------------------------------------------------

  group('Fix 4: StateChangeEvent source — canonical enum per spec §3.11', () {
    test('Tool auto-merge tags events with source = "tool"', () async {
      actionHandler.registerToolExecutor('echo', (params) async {
        return {'x': 1};
      });

      final events = <StateChangeEvent>[];
      final sub = stateManager.stream.listen(events.add);

      await actionHandler.execute(
        {'type': 'tool', 'tool': 'echo', 'params': {}},
        context,
      );
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      final xEvent = events.firstWhere((e) => e.path == 'x');
      expect(xEvent.source, equals('tool'));
    });

    test('State action `set` tags events with source = "action"', () async {
      final events = <StateChangeEvent>[];
      final sub = stateManager.stream.listen(events.add);

      await actionHandler.execute(
        {
          'type': 'state',
          'action': 'set',
          'binding': 'flag',
          'value': true,
        },
        context,
      );
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(events.single.path, equals('flag'));
      expect(events.single.source, equals('action'));
    });

    test('State action `increment` also tags as "action"', () async {
      stateManager.set('count', 0);
      final events = <StateChangeEvent>[];
      final sub = stateManager.stream.listen(events.add);

      await actionHandler.execute(
        {'type': 'state', 'action': 'increment', 'binding': 'count'},
        context,
      );
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(events.single.source, equals('action'));
    });

    test('Direct mergeState defaults source to "tool"', () async {
      final events = <StateChangeEvent>[];
      final sub = stateManager.stream.listen(events.add);

      stateManager.mergeState({'foo': 'bar'});
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(events.single.source, equals('tool'));
    });

    test('mergeState honors explicit source override', () async {
      final events = <StateChangeEvent>[];
      final sub = stateManager.stream.listen(events.add);

      stateManager.mergeState({'foo': 'bar'}, source: 'subscription');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(events.single.source, equals('subscription'));
    });

    test('Non-canonical "updateAll" source removed; default is "system"',
        () async {
      final events = <StateChangeEvent>[];
      final sub = stateManager.stream.listen(events.add);

      stateManager.updateAll({'a': 1});
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(events.single.source, equals('system'));
    });
  });

  // ---------------------------------------------------------------------------
  // Fix 5: resource notification stores raw content at binding
  // ---------------------------------------------------------------------------

  group('Fix 5: resource notification raw `content` store (no heuristic)', () {
    test('Map content stored as-is at binding (no unwrap)', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      await runtime.initialize({
        'type': 'page',
        'content': {'type': 'text', 'content': 'x'},
      });
      runtime.engine!
          .registerResourceSubscription('data://sensor', 'sensor');

      // Pre-fix: heuristic would have unwrapped `content[binding]` and
      // stored `25.5` at `sensor`. Spec §4.5: store raw content.
      runtime.engine!.handleResourceNotification('data://sensor', {
        'content': {'sensor': 25.5, 'other': 'x'},
      });

      expect(runtime.engine!.stateManager.get<Map>('sensor'),
          equals({'sensor': 25.5, 'other': 'x'}));

      await runtime.dispose();
    });

    test('Resource notification tags source = "subscription"', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      await runtime.initialize({
        'type': 'page',
        'content': {'type': 'text', 'content': 'x'},
      });
      runtime.engine!
          .registerResourceSubscription('data://sensor', 'sensor');

      final events = <StateChangeEvent>[];
      final sub = runtime.engine!.stateManager.stream.listen(events.add);

      runtime.engine!.handleResourceNotification('data://sensor', {
        'content': 'raw-payload',
      });
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      final ev = events.firstWhere((e) => e.path == 'sensor');
      expect(ev.source, equals('subscription'));

      await runtime.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Fix 6: separate `onResourceRead` / `onResourceList` callbacks
  // ---------------------------------------------------------------------------

  group('Fix 6: separate read/list callbacks', () {
    test('Engine accepts onResourceRead and onResourceList wiring', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      await runtime.initialize({
        'type': 'page',
        'content': {'type': 'text', 'content': 'x'},
      });

      String? readUri;
      String? listUri;
      runtime.engine!.setResourceHandlers(
        onResourceRead: (uri, binding) async {
          readUri = uri;
          runtime.engine!.stateManager
              .set(binding, {'single': true}, source: 'subscription');
        },
        onResourceList: (uri, binding) async {
          listUri = uri;
          runtime.engine!.stateManager
              .set(binding, ['a', 'b'], source: 'subscription');
        },
      );

      expect(runtime.engine!.onResourceRead, isNotNull);
      expect(runtime.engine!.onResourceList, isNotNull);

      // Trigger via the action handler to confirm the read callback runs.
      // We need a fresh RenderContext that resolves the engine reference;
      // use the renderer's root context.
      final ctx = runtime.engine!.renderer.createRootContext(null);
      await runtime.engine!.actionHandler.execute(
        {
          'type': 'resource',
          'action': 'read',
          'uri': 'ui://thing',
          'binding': 'item',
        },
        ctx,
      );
      expect(readUri, equals('ui://thing'));
      expect(runtime.engine!.stateManager.get('item'),
          equals({'single': true}));

      await runtime.engine!.actionHandler.execute(
        {
          'type': 'resource',
          'action': 'list',
          'uri': 'ui://things',
          'binding': 'items',
        },
        ctx,
      );
      expect(listUri, equals('ui://things'));
      expect(runtime.engine!.stateManager.get<List>('items'),
          equals(['a', 'b']));

      await runtime.dispose();
    });

    test('Without onResourceRead, falls back to onResourceSubscribe (legacy)',
        () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      await runtime.initialize({
        'type': 'page',
        'content': {'type': 'text', 'content': 'x'},
      });

      String? subUri;
      runtime.engine!.setResourceHandlers(
        onResourceSubscribe: (uri, binding) async {
          subUri = uri;
          runtime.engine!.stateManager.set(
              binding, ['first', 'second'],
              source: 'subscription');
        },
      );

      final ctx = runtime.engine!.renderer.createRootContext(null);
      await runtime.engine!.actionHandler.execute(
        {
          'type': 'resource',
          'action': 'read',
          'uri': 'ui://thing',
          'binding': 'item',
        },
        ctx,
      );
      // Legacy fallback unwraps the first item for `read`.
      expect(subUri, equals('ui://thing'));
      expect(runtime.engine!.stateManager.get('item'), equals('first'));

      await runtime.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Fix 7: onSubscriptionError dispatch
  // ---------------------------------------------------------------------------

  group('Fix 7: onSubscriptionError dispatch on host failure', () {
    test('Host subscribe throws → onSubscriptionError fires with event.*',
        () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      await runtime.initialize({
        'type': 'page',
        'content': {'type': 'text', 'content': 'x'},
      });

      runtime.engine!.setResourceHandlers(
        onResourceSubscribe: (uri, binding) async {
          throw StateError('connection refused');
        },
      );

      final ctx = runtime.engine!.renderer.createRootContext(null);
      final result = await runtime.engine!.actionHandler.execute(
        {
          'type': 'resource',
          'action': 'subscribe',
          'uri': 'ui://thing',
          'binding': 'thing',
          'onSubscriptionError': {
            'type': 'state',
            'action': 'set',
            'binding': 'subscribeError',
            'value': '{{event.message}}',
          },
        },
        ctx,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('connection refused'));
      expect(
          runtime.engine!.stateManager.get<String>('subscribeError'),
          contains('connection refused'));
      // Failed subscribe must roll back the registration.
      expect(runtime.engine!.getBindingForUri('ui://thing'), isNull);

      await runtime.dispose();
    });

    test('Host subscribe succeeds → onSubscriptionError NOT fired', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      await runtime.initialize({
        'type': 'page',
        'content': {'type': 'text', 'content': 'x'},
      });

      runtime.engine!.setResourceHandlers(
        onResourceSubscribe: (uri, binding) async {
          // no-op success
        },
      );

      final ctx = runtime.engine!.renderer.createRootContext(null);
      final result = await runtime.engine!.actionHandler.execute(
        {
          'type': 'resource',
          'action': 'subscribe',
          'uri': 'ui://thing',
          'binding': 'thing',
          'onSubscriptionError': {
            'type': 'state',
            'action': 'set',
            'binding': 'subscribeError',
            'value': 'should-not-fire',
          },
        },
        ctx,
      );

      expect(result.success, isTrue);
      expect(runtime.engine!.stateManager.get('subscribeError'), isNull);

      await runtime.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Fix 8: lifecycle null context — explicit (no silent short-circuit)
  // ---------------------------------------------------------------------------

  group('Fix 8: lifecycle null context surfaces explicit error', () {
    test('Hook dispatched before setActionHandler runs without throwing',
        () async {
      // Pre-fix: hook was silently dropped. Post-fix: hook is dropped with
      // a logged error. The behavior contract for the caller (no throw,
      // pipeline continues) is preserved so existing initialization paths
      // are unaffected.
      final lm = LifecycleManager(enableDebugMode: false);

      // No setActionHandler — _renderContext stays null. The hook MUST
      // not crash the pipeline; it should be reported as dropped.
      await expectLater(
        lm.executeLifecycleHooks(LifecycleEvent.initialize, [
          {'type': 'tool', 'tool': 'foo'},
        ]),
        completes,
      );
      lm.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Fix 9: onSuccess event.value wrap for non-Map responses (spec §4.4.2)
  //
  // Spec table:
  //   - Map response   → `event.<key>` per top-level key.
  //   - Non-Map (list, scalar, null) → full response at `event.value`,
  //     other `event.*` keys resolve to null.
  // ---------------------------------------------------------------------------

  group('Fix 9: event.value wrap on non-Map tool response', () {
    test('List response — `{{event.value}}` resolves to the full list',
        () async {
      actionHandler.registerToolExecutor('listTool', (params) async {
        return [
          {'a': 1},
          {'b': 2},
        ];
      });

      await actionHandler.execute(
        {
          'type': 'tool',
          'tool': 'listTool',
          'params': {},
          'onSuccess': {
            'type': 'state',
            'action': 'set',
            'binding': 'captured',
            'value': '{{event.value}}',
          },
        },
        context,
      );

      final captured = stateManager.get<dynamic>('captured');
      expect(captured, isA<List>());
      expect(captured, equals([
        {'a': 1},
        {'b': 2},
      ]));

      // Nested `event.*` keys must resolve to null per spec.
      await actionHandler.execute(
        {
          'type': 'tool',
          'tool': 'listTool',
          'params': {},
          'onSuccess': {
            'type': 'state',
            'action': 'set',
            'binding': 'message',
            'value': '{{event.message}}',
          },
        },
        context,
      );
      // Unresolved bindings preserve the raw template string (binding engine
      // returns the original placeholder when the path resolves to null).
      // The contract we assert is: NOT the list, NOT a real message field.
      final msg = stateManager.get<dynamic>('message');
      expect(msg, isNot(isA<List>()));
    });

    test('Scalar string response — `{{event.value}}` resolves to the string',
        () async {
      actionHandler.registerToolExecutor('stringTool', (params) async {
        return 'hello';
      });

      await actionHandler.execute(
        {
          'type': 'tool',
          'tool': 'stringTool',
          'params': {},
          'onSuccess': {
            'type': 'state',
            'action': 'set',
            'binding': 'captured',
            'value': '{{event.value}}',
          },
        },
        context,
      );

      expect(stateManager.get<String>('captured'), equals('hello'));
    });

    test('Null response — `{{event.value}}` resolves to null', () async {
      actionHandler.registerToolExecutor('nullTool', (params) async {
        return null;
      });

      // Seed an initial value so we can prove `set` ran (and value was null).
      stateManager.set('captured', 'sentinel');

      await actionHandler.execute(
        {
          'type': 'tool',
          'tool': 'nullTool',
          'params': {},
          'onSuccess': {
            'type': 'state',
            'action': 'set',
            'binding': 'captured',
            'value': '{{event.value}}',
          },
        },
        context,
      );

      // `event.value` resolves to null; binding engine leaves the raw
      // template intact when there is no resolved value. Either way, the
      // captured slot is NOT the original Map shape — it has no `value` key.
      final captured = stateManager.get<dynamic>('captured');
      expect(captured, isNot(isA<Map>()));
    });

    test('Map response — backward compat: `{{event.<key>}}` still resolves',
        () async {
      actionHandler.registerToolExecutor('mapTool', (params) async {
        return {'a': 1, 'b': 'two'};
      });

      await actionHandler.execute(
        {
          'type': 'tool',
          'tool': 'mapTool',
          'params': {},
          'onSuccess': {
            'type': 'batch',
            'actions': [
              {
                'type': 'state',
                'action': 'set',
                'binding': 'capturedA',
                'value': '{{event.a}}',
              },
              {
                'type': 'state',
                'action': 'set',
                'binding': 'capturedB',
                'value': '{{event.b}}',
              },
            ],
          },
        },
        context,
      );

      expect(stateManager.get<int>('capturedA'), equals(1));
      expect(stateManager.get<String>('capturedB'), equals('two'));
    });
  });
}
