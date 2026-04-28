import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_result.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart' show StateActionDefinition;

void main() {
  late ActionHandler actionHandler;
  late RenderContext context;
  late StateManager stateManager;

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

  group('TC-001: ActionHandler — constructor', () {
    test('TC-001 Normal: No-arg constructor creates instance successfully', () {
      final handler = ActionHandler();
      expect(handler, isNotNull);
      expect(handler, isA<ActionHandler>());
    });

    test('TC-001 Normal: All default executors registered internally', () async {
      // State executor is registered by default
      final stateResult = await actionHandler.execute(
        {'type': 'state', 'action': 'set', 'binding': 'test', 'value': 1},
        context,
      );
      expect(stateResult.success, isTrue);

      // Tool executor is registered by default (no tool found, but executor exists)
      final toolResult = await actionHandler.execute(
        {'type': 'tool', 'tool': 'nonexistent'},
        context,
      );
      // Returns error because no tool executor registered, but the executor itself exists
      expect(toolResult.success, isFalse);
      expect(toolResult.error, contains('Tool executor not found'));
    });

    test('TC-001 Normal: ActionHandler ready for use immediately after construction', () async {
      final handler = ActionHandler();
      // Should be able to execute actions right away
      final result = await handler.execute(
        {'type': 'state', 'action': 'set', 'binding': 'counter', 'value': 0},
        context,
      );
      expect(result, isA<ActionResult>());
    });

    test('TC-001 Boundary: Multiple instances are independent', () {
      final handler1 = ActionHandler();
      final handler2 = ActionHandler();

      var tool1Called = false;
      var tool2Called = false;
      handler1.registerToolExecutor('myTool', (params) async {
        tool1Called = true;
        return {'success': true, 'result': null};
      });
      handler2.registerToolExecutor('myTool', (params) async {
        tool2Called = true;
        return {'success': true, 'result': null};
      });

      // Registering on handler1 should not affect handler2
      expect(handler1.toolExecutors.containsKey('myTool'), isTrue);
      expect(handler2.toolExecutors.containsKey('myTool'), isTrue);
      // They are separate maps
      expect(identical(handler1.toolExecutors, handler2.toolExecutors), isFalse);
    });

    test('TC-001 Boundary: Constructor completes without errors', () {
      expect(() => ActionHandler(), returnsNormally);
    });
  });

  group('TC-002: ActionHandler — execute routing', () {
    test('TC-002 Normal: state type routes to StateActionExecutor', () async {
      stateManager.set('counter', 0);
      final result = await actionHandler.execute(
        {'type': 'state', 'action': 'set', 'binding': 'counter', 'value': 42},
        context,
      );
      expect(result.success, isTrue);
      expect(stateManager.get<int>('counter'), equals(42));
    });

    test('TC-002 Normal: navigation type routes to NavigationActionExecutor', () async {
      // Without navigator, the action still routes correctly
      final result = await actionHandler.execute(
        {'type': 'navigation', 'action': 'push', 'route': '/test'},
        context,
      );
      // Returns success even without navigator state (graceful handling)
      expect(result, isA<ActionResult>());
    });

    test('TC-002 Normal: tool type routes to ToolActionExecutor', () async {
      actionHandler.registerToolExecutor('greet', (params) async {
        return {'success': true, 'result': 'hello'};
      });
      final result = await actionHandler.execute(
        {'type': 'tool', 'tool': 'greet', 'params': {}},
        context,
      );
      expect(result.success, isTrue);
      expect(result.data, equals('hello'));
    });

    test('TC-002 Normal: batch type routes to BatchActionExecutor', () async {
      stateManager.set('a', 0);
      stateManager.set('b', 0);
      final result = await actionHandler.execute({
        'type': 'batch',
        'actions': [
          {'type': 'state', 'action': 'set', 'binding': 'a', 'value': 1},
          {'type': 'state', 'action': 'set', 'binding': 'b', 'value': 2},
        ],
      }, context);
      expect(result.success, isTrue);
      expect(stateManager.get<int>('a'), equals(1));
      expect(stateManager.get<int>('b'), equals(2));
    });

    test('TC-002 Normal: conditional type routes to ConditionalActionExecutor', () async {
      stateManager.set('flag', true);
      final result = await actionHandler.execute({
        'type': 'conditional',
        'condition': 'true',
        'then': {'type': 'state', 'action': 'set', 'binding': 'result', 'value': 'yes'},
        'else': {'type': 'state', 'action': 'set', 'binding': 'result', 'value': 'no'},
      }, context);
      expect(result, isA<ActionResult>());
    });

    test('TC-002 Normal: parallel type routes to ParallelActionExecutor', () async {
      final result = await actionHandler.execute({
        'type': 'parallel',
        'actions': [
          {'type': 'state', 'action': 'set', 'binding': 'p1', 'value': 1},
          {'type': 'state', 'action': 'set', 'binding': 'p2', 'value': 2},
        ],
      }, context);
      expect(result.success, isTrue);
    });

    test('TC-002 Normal: sequence type routes to SequenceActionExecutor', () async {
      final result = await actionHandler.execute({
        'type': 'sequence',
        'actions': [
          {'type': 'state', 'action': 'set', 'binding': 's1', 'value': 1},
          {'type': 'state', 'action': 'set', 'binding': 's2', 'value': 2},
        ],
      }, context);
      expect(result.success, isTrue);
    });

    test('TC-002 Normal: cancel type routes to CancelActionExecutor', () async {
      final result = await actionHandler.execute(
        {'type': 'cancel', 'target': 'someActionId'},
        context,
      );
      expect(result.success, isTrue);
    });

    test('TC-002 Normal: animation type routes to AnimationActionExecutor', () async {
      final result = await actionHandler.execute(
        {'type': 'animation', 'target': 'myAnim', 'action': 'play'},
        context,
      );
      expect(result.success, isTrue);
    });

    test('TC-002 Normal: permission.revoke type routes to PermissionRevokeActionExecutor', () async {
      final result = await actionHandler.execute(
        {'type': 'permission.revoke', 'permission': 'file.read'},
        context,
      );
      expect(result.success, isTrue);
    });

    test('TC-002 Normal: Returns Future<ActionResult>', () async {
      final future = actionHandler.execute(
        {'type': 'state', 'action': 'set', 'binding': 'x', 'value': 1},
        context,
      );
      expect(future, isA<Future<ActionResult>>());
      final result = await future;
      expect(result, isA<ActionResult>());
    });

    test('TC-002 Boundary: Unknown action type without custom handler returns error', () async {
      final result = await actionHandler.execute(
        {'type': 'unknownType123'},
        context,
      );
      expect(result.success, isFalse);
      expect(result.error, contains('Unknown action type'));
    });

    test('TC-002 Error: Executor throws exception for missing required binding', () async {
      // State action throws when binding is missing.
      // ActionHandler rethrows exceptions whose message contains 'required'.
      expect(
        () => actionHandler.execute(
          {'type': 'state', 'action': 'set'},
          context,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('TC-003: ActionHandler — execute method signature', () {
    test('TC-003 Normal: Takes Map<String, dynamic> and RenderContext', () async {
      final action = <String, dynamic>{'type': 'state', 'action': 'set', 'binding': 'x', 'value': 1};
      final result = await actionHandler.execute(action, context);
      expect(result, isA<ActionResult>());
    });

    test('TC-003 Normal: Returns Future<ActionResult>', () async {
      final result = await actionHandler.execute(
        {'type': 'state', 'action': 'set', 'binding': 'x', 'value': 1},
        context,
      );
      expect(result, isA<ActionResult>());
      expect(result.success, isA<bool>());
    });

    test('TC-003 Normal: Action map must contain type key', () async {
      final result = await actionHandler.execute({'type': 'state', 'binding': 'x', 'value': 1}, context);
      expect(result, isA<ActionResult>());
    });

    test('TC-003 Boundary: Action map with only type key', () async {
      // notification type requires message, so it should error gracefully
      final result = await actionHandler.execute({'type': 'notification'}, context);
      expect(result, isA<ActionResult>());
    });

    test('TC-003 Boundary: Action map with extra unknown keys ignored', () async {
      final result = await actionHandler.execute(
        {'type': 'state', 'action': 'set', 'binding': 'x', 'value': 1, 'unknownKey': 'ignored'},
        context,
      );
      expect(result.success, isTrue);
    });

    test('TC-003 Error: Missing type key returns error result', () async {
      final result = await actionHandler.execute({'action': 'set', 'binding': 'x'}, context);
      expect(result.success, isFalse);
      expect(result.error, contains('Action type is required'));
    });
  });

  group('TC-004: ActionHandler — executeDefinition', () {
    test('TC-004 Normal: Converts ActionDefinition to JSON map and delegates to execute()', () async {
      final definition = StateActionDefinition(
        action: 'set',
        binding: 'counter',
        value: 42,
      );
      final result = await actionHandler.executeDefinition(definition, context);
      expect(result, isA<ActionResult>());
      expect(result.success, isTrue);
      expect(stateManager.get<int>('counter'), equals(42));
    });

    test('TC-004 Normal: Returns same ActionResult as execute() would', () async {
      final definition = StateActionDefinition(
        action: 'set',
        binding: 'val',
        value: 'hello',
      );
      final result = await actionHandler.executeDefinition(definition, context);
      expect(result.success, isTrue);
    });

    test('TC-004 Boundary: ActionDefinition with minimal fields', () async {
      final definition = StateActionDefinition(
        action: 'toggle',
        binding: 'flag',
      );
      final result = await actionHandler.executeDefinition(definition, context);
      expect(result, isA<ActionResult>());
    });
  });

  group('TC-005: ActionHandler — registerExecutor', () {
    test('TC-005 Normal: Register custom executor for type custom', () async {
      actionHandler.registerExecutor('custom', _TestExecutor());
      final result = await actionHandler.execute({'type': 'custom'}, context);
      expect(result.success, isTrue);
      expect(result.data, equals('custom_executed'));
    });

    test('TC-005 Normal: Override existing default executor', () async {
      actionHandler.registerExecutor('state', _TestExecutor());
      final result = await actionHandler.execute({'type': 'state'}, context);
      expect(result.success, isTrue);
      expect(result.data, equals('custom_executed'));
    });

    test('TC-005 Normal: registerHandler is alias for registerExecutor', () async {
      actionHandler.registerHandler('alias', _TestExecutor());
      final result = await actionHandler.execute({'type': 'alias'}, context);
      expect(result.success, isTrue);
      expect(result.data, equals('custom_executed'));
    });

    test('TC-005 Boundary: Register for new custom type works for future actions', () async {
      actionHandler.registerExecutor('newType', _TestExecutor());
      final result = await actionHandler.execute({'type': 'newType'}, context);
      expect(result.success, isTrue);
    });

    test('TC-005 Boundary: Register then override, latest registration wins', () async {
      actionHandler.registerExecutor('myType', _TestExecutor());
      actionHandler.registerExecutor('myType', _AlternateExecutor());
      final result = await actionHandler.execute({'type': 'myType'}, context);
      expect(result.success, isTrue);
      expect(result.data, equals('alternate_executed'));
    });
  });

  group('TC-006: ActionHandler — registerToolExecutor', () {
    test('TC-006 Normal: Register tool executor per tool name, called for matching tool actions', () async {
      actionHandler.registerToolExecutor('myTool', (params) async {
        return {'success': true, 'result': {'received': params}};
      });
      final result = await actionHandler.execute(
        {'type': 'tool', 'tool': 'myTool', 'params': {'key': 'val'}},
        context,
      );
      expect(result.success, isTrue);
      expect(result.data['received']['key'], equals('val'));
    });

    test('TC-006 Normal: Register default executor as catch-all', () async {
      actionHandler.registerToolExecutor('default', (toolName, params) async {
        return {'success': true, 'result': {'tool': toolName}};
      });
      final result = await actionHandler.execute(
        {'type': 'tool', 'tool': 'anyTool'},
        context,
      );
      expect(result.success, isTrue);
      expect(result.data['tool'], equals('anyTool'));
    });

    test('TC-006 Normal: Specific tool executor receives only params', () async {
      actionHandler.registerToolExecutor('specificTool', (params) async {
        return {'success': true, 'result': params};
      });
      final result = await actionHandler.execute(
        {'type': 'tool', 'tool': 'specificTool', 'params': {'a': 1}},
        context,
      );
      expect(result.success, isTrue);
    });

    test('TC-006 Boundary: Override existing tool executor, new executor used', () async {
      actionHandler.registerToolExecutor('tool1', (params) async {
        return {'success': true, 'result': 'first'};
      });
      actionHandler.registerToolExecutor('tool1', (params) async {
        return {'success': true, 'result': 'second'};
      });
      final result = await actionHandler.execute(
        {'type': 'tool', 'tool': 'tool1'},
        context,
      );
      expect(result.success, isTrue);
      expect(result.data, equals('second'));
    });

    test('TC-006 Boundary: Multiple tool-specific executors, each called for its tool', () async {
      actionHandler.registerToolExecutor('toolA', (params) async {
        return {'success': true, 'result': 'A'};
      });
      actionHandler.registerToolExecutor('toolB', (params) async {
        return {'success': true, 'result': 'B'};
      });

      final resultA = await actionHandler.execute(
        {'type': 'tool', 'tool': 'toolA'},
        context,
      );
      final resultB = await actionHandler.execute(
        {'type': 'tool', 'tool': 'toolB'},
        context,
      );

      expect(resultA.data, equals('A'));
      expect(resultB.data, equals('B'));
    });
  });

  group('TC-007: ActionHandler — registerNavigationHandler', () {
    tearDown(() {
      // Clean up global handler
      NavigationActionExecutor.clearGlobalNavigationHandler();
    });

    test('TC-007 Normal: Handler callback receives (action, route, params) and returns bool', () async {
      String? receivedAction;
      String? receivedRoute;
      Map<String, dynamic>? receivedParams;

      actionHandler.registerNavigationHandler((action, route, params) {
        receivedAction = action;
        receivedRoute = route;
        receivedParams = params;
        return true;
      });

      await actionHandler.execute(
        {'type': 'navigation', 'action': 'push', 'route': '/details', 'params': {'id': '123'}},
        context,
      );

      expect(receivedAction, equals('push'));
      expect(receivedRoute, equals('/details'));
      expect(receivedParams?['id'], equals('123'));
    });

    test('TC-007 Normal: Handler returns true, navigation considered handled', () async {
      actionHandler.registerNavigationHandler((action, route, params) => true);
      final result = await actionHandler.execute(
        {'type': 'navigation', 'action': 'push', 'route': '/test'},
        context,
      );
      expect(result.success, isTrue);
    });

    test('TC-007 Normal: Handler returns false, default navigation behavior used', () async {
      actionHandler.registerNavigationHandler((action, route, params) => false);
      final result = await actionHandler.execute(
        {'type': 'navigation', 'action': 'push', 'route': '/test'},
        context,
      );
      // Handler rejected, so error result
      expect(result.success, isFalse);
    });

    test('TC-007 Boundary: Handler registered then replaced, new handler used', () async {
      var firstCalled = false;
      var secondCalled = false;

      actionHandler.registerNavigationHandler((action, route, params) {
        firstCalled = true;
        return true;
      });
      actionHandler.registerNavigationHandler((action, route, params) {
        secondCalled = true;
        return true;
      });

      await actionHandler.execute(
        {'type': 'navigation', 'action': 'push', 'route': '/test'},
        context,
      );

      expect(firstCalled, isFalse);
      expect(secondCalled, isTrue);
    });

    test(
      'TC-007 Boundary: openApp bypasses a rejecting navigation handler '
      'and delegates to the registered host callback',
      () async {
        // Simulates ApplicationShell's handler which only recognises
        // push/replace and returns false for everything else. Without
        // the early-path dispatch in NavigationActionExecutor, a
        // dashboard `openApp` would be rejected by this handler.
        var handlerReceivedOpenApp = false;
        actionHandler.registerNavigationHandler((action, route, params) {
          if (action == 'openApp' || action == 'exitApp') {
            handlerReceivedOpenApp = true;
            return false;
          }
          return action == 'push' || action == 'replace';
        });

        String? hostAppId;
        String? hostRoute;
        NavigationActionExecutor.setOnOpenAppCallback((appId, route) {
          hostAppId = appId;
          hostRoute = route;
        });

        final result = await actionHandler.execute(
          {
            'type': 'navigation',
            'action': 'openApp',
            'appId': 'srv-1',
            'route': '/counter',
          },
          context,
        );

        expect(result.success, isTrue,
            reason: 'openApp must reach the host callback, not the handler');
        expect(handlerReceivedOpenApp, isFalse,
            reason: 'openApp must not be routed through the nav handler');
        expect(hostAppId, equals('srv-1'));
        expect(hostRoute, equals('/counter'));

        NavigationActionExecutor.clearOnOpenAppCallback();
      },
    );

    test(
      'TC-007 Boundary: exitApp bypasses a rejecting navigation handler '
      'and delegates to the registered host callback',
      () async {
        actionHandler.registerNavigationHandler(
            (action, route, params) => action == 'push' || action == 'replace');

        var exitCalled = false;
        NavigationActionExecutor.setOnExitCallback(() => exitCalled = true);

        final result = await actionHandler.execute(
          {'type': 'navigation', 'action': 'exitApp'},
          context,
        );

        expect(result.success, isTrue);
        expect(exitCalled, isTrue);

        NavigationActionExecutor.clearOnExitCallback();
      },
    );
  });

  group('TC-008: ActionHandler — setChannelManager', () {
    test('TC-008 Boundary: Channel actions without ChannelManager return error', () async {
      // No channel manager set, channel actions should return error
      final result = await actionHandler.execute(
        {'type': 'channel.start', 'channel': 'test'},
        context,
      );
      expect(result.success, isFalse);
      expect(result.error, contains('ChannelManager not configured'));
    });
  });

  group('TC-009: ActionHandler — setPermissionsConfig', () {
    test('TC-009 Boundary: Null PermissionsConfig is no-op', () {
      // Should not throw
      expect(() => actionHandler.setPermissionsConfig(null), returnsNormally);
    });
  });
}

/// Test executor that always returns success with custom data
class _TestExecutor extends ActionExecutor {
  @override
  Future<ActionResult> execute(
    Map<String, dynamic> action,
    RenderContext context,
  ) async {
    return ActionResult.success(data: 'custom_executed');
  }
}

/// Alternate test executor
class _AlternateExecutor extends ActionExecutor {
  @override
  Future<ActionResult> execute(
    Map<String, dynamic> action,
    RenderContext context,
  ) async {
    return ActionResult.success(data: 'alternate_executed');
  }
}
