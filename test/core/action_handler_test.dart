import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';

void main() {
  group('ActionHandler Tests', () {
    late ActionHandler actionHandler;
    late RenderContext context;
    late StateManager stateManager;

    setUp(() {
      actionHandler = ActionHandler();
      stateManager = StateManager();
      final bindingEngine = BindingEngine();
      final themeManager = ThemeManager();
      final widgetRegistry = WidgetRegistry();
      
      stateManager.initialize({
        'counter': 0,
        'user': {'name': 'John', 'isLoggedIn': false},
        'form': {'email': '', 'password': ''}
      });

      final renderer = Renderer(
        widgetRegistry: widgetRegistry,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        stateManager: stateManager,
      );

      context = RenderContext(
        renderer: renderer,
        stateManager: stateManager,
        actionHandler: actionHandler,
        themeManager: themeManager,
        bindingEngine: bindingEngine,
        buildContext: null,
      );
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('registers and executes tool executors', () async {
      bool toolExecuted = false;
      
      actionHandler.registerToolExecutor('testTool', (Map<String, dynamic> params) async {
        toolExecuted = true;
        return {'success': true, 'data': params};
      });

      final action = {
        'type': 'tool',
        'tool': 'testTool',
        'args': {'test': 'data'}
      };

      final result = await actionHandler.execute(action, context);
      expect(result.success, isTrue);
      expect(toolExecuted, isTrue);
    });

    test('executes state set actions', () async {
      final action = {
        'type': 'state',
        'action': 'set',
        'binding': 'counter',
        'value': 42
      };

      final result = await actionHandler.execute(action, context);
      expect(result.success, isTrue);
      expect(stateManager.get<int>('counter'), equals(42));
    });

    test('executes state increment actions', () async {
      stateManager.set('counter', 5);
      
      final action = {
        'type': 'state',
        'action': 'increment',
        'binding': 'counter',
        'value': 3
      };

      final result = await actionHandler.execute(action, context);
      expect(result.success, isTrue);
      expect(stateManager.get<int>('counter'), equals(8));
    });

    test('executes state decrement actions', () async {
      stateManager.set('counter', 10);
      
      final action = {
        'type': 'state',
        'action': 'decrement',
        'binding': 'counter',
        'value': 4
      };

      final result = await actionHandler.execute(action, context);
      expect(result.success, isTrue);
      expect(stateManager.get<int>('counter'), equals(6));
    });

    test('executes state toggle actions', () async {
      stateManager.set('user.isLoggedIn', false);
      
      final action = {
        'type': 'state',
        'action': 'toggle',
        'binding': 'user.isLoggedIn'
      };

      final result = await actionHandler.execute(action, context);
      expect(result.success, isTrue);
      expect(stateManager.get<bool>('user.isLoggedIn'), isTrue);
      
      final result2 = await actionHandler.execute(action, context);
      expect(result2.success, isTrue);
      expect(stateManager.get<bool>('user.isLoggedIn'), isFalse);
    });

    test('executes state append actions', () async {
      stateManager.set('items', [1, 2, 3]);
      
      final action = {
        'type': 'state',
        'action': 'append',
        'binding': 'items',
        'value': 4
      };

      final result = await actionHandler.execute(action, context);
      expect(result.success, isTrue);
      expect(stateManager.get<List>('items'), equals([1, 2, 3, 4]));
    });

    test('executes state remove actions', () async {
      stateManager.set('items', [1, 2, 3, 2]);
      
      final action = {
        'type': 'state',
        'action': 'remove',
        'binding': 'items',
        'value': 2
      };

      final result = await actionHandler.execute(action, context);
      expect(result.success, isTrue);
      expect(stateManager.get<List>('items'), equals([1, 3, 2]));
    });

    test('handles navigation actions', () async {
      final action = {
        'type': 'navigation',
        'action': 'push',
        'route': '/profile',
        'params': {'id': '123'}
      };

      final result = await actionHandler.execute(action, context);
      expect(result.success, isTrue); // Navigation should succeed without error
    });

    test('executes batch actions in sequence', () async {
      final action = {
        'type': 'batch',
        'parallel': false,
        'actions': [
          {'type': 'state', 'action': 'set', 'binding': 'counter', 'value': 1},
          {'type': 'state', 'action': 'increment', 'binding': 'counter', 'value': 2},
          {'type': 'state', 'action': 'increment', 'binding': 'counter', 'value': 3}
        ]
      };

      final result = await actionHandler.execute(action, context);
      expect(result.success, isTrue);
      expect(stateManager.get<int>('counter'), equals(6));
    });

    test('handles action execution errors gracefully', () async {
      final action = {
        'type': 'unknown_action',
        'data': 'test'
      };

      // Should throw exception for unknown action types
      expect(
        () => actionHandler.execute(action, context),
        throwsException,
      );
    });
  });
}