import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/runtime_engine.dart';

void main() {
  group('ResourceActionExecutor', () {
    late ActionHandler actionHandler;
    late StateManager stateManager;
    late BindingEngine bindingEngine;
    late WidgetRegistry widgetRegistry;
    late Renderer renderer;
    late RenderContext context;
    late RuntimeEngine engine;

    setUp(() {
      actionHandler = ActionHandler();
      stateManager = StateManager();
      bindingEngine = BindingEngine();
      widgetRegistry = WidgetRegistry();
      renderer = Renderer(
        widgetRegistry: widgetRegistry,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        stateManager: stateManager,
      );
      
      engine = RuntimeEngine();
      
      context = RenderContext(
        renderer: renderer,
        stateManager: stateManager,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        themeManager: ThemeManager(),
        engine: engine,
      );
    });

    test('executes subscribe action with valid parameters', () async {
      // Track subscription calls
      String? subscribedUri;
      String? subscribedBinding;
      
      engine.setResourceHandlers(
        onResourceSubscribe: (uri, binding) async {
          subscribedUri = uri;
          subscribedBinding = binding;
        },
      );

      final action = {
        'type': 'resource',
        'action': 'subscribe',
        'uri': 'mcp://server/metrics/cpu',
        'binding': 'state.cpuUsage',
      };

      final result = await actionHandler.execute(action, context);

      expect(result.success, true);
      expect(subscribedUri, 'mcp://server/metrics/cpu');
      expect(subscribedBinding, 'state.cpuUsage');
    });

    test('executes unsubscribe action with valid parameters', () async {
      // Track unsubscription calls
      String? unsubscribedUri;
      
      engine.setResourceHandlers(
        onResourceUnsubscribe: (uri) async {
          unsubscribedUri = uri;
        },
      );

      final action = {
        'type': 'resource',
        'action': 'unsubscribe',
        'uri': 'mcp://server/metrics/cpu',
      };

      final result = await actionHandler.execute(action, context);

      expect(result.success, true);
      expect(unsubscribedUri, 'mcp://server/metrics/cpu');
    });

    test('fails when action is missing', () async {
      final action = {
        'type': 'resource',
        'uri': 'mcp://server/metrics/cpu',
      };

      final result = await actionHandler.execute(action, context);

      expect(result.success, false);
      expect(result.error, 'Action is required for resource action');
    });

    test('fails when uri is missing', () async {
      final action = {
        'type': 'resource',
        'action': 'subscribe',
        'binding': 'state.cpuUsage',
      };

      final result = await actionHandler.execute(action, context);

      expect(result.success, false);
      expect(result.error, 'URI is required for resource action');
    });

    test('fails when binding is missing for subscribe action', () async {
      final action = {
        'type': 'resource',
        'action': 'subscribe',
        'uri': 'mcp://server/metrics/cpu',
      };

      final result = await actionHandler.execute(action, context);

      expect(result.success, false);
      expect(result.error, 'Binding is required for subscribe action');
    });

    test('fails with unknown resource action', () async {
      final action = {
        'type': 'resource',
        'action': 'invalid',
        'uri': 'mcp://server/metrics/cpu',
      };

      final result = await actionHandler.execute(action, context);

      expect(result.success, false);
      expect(result.error, 'Unknown resource action: invalid');
    });

    test('handles missing resource handlers gracefully', () async {
      // Don't set any handlers
      
      final action = {
        'type': 'resource',
        'action': 'subscribe',
        'uri': 'mcp://server/metrics/cpu',
        'binding': 'state.cpuUsage',
      };

      final result = await actionHandler.execute(action, context);

      // Should still succeed, just log a warning
      expect(result.success, true);
    });
  });

  group('Resource Subscription Integration', () {
    test('updates state when notification is received', () async {
      final engine = RuntimeEngine();
      
      // Initialize engine with minimal setup
      await engine.initialize(
        definition: {
          'type': 'page',
          'metadata': {
            'title': 'Test Page',
          },
          'content': {
            'type': 'box',
          },
        },
      );
      
      // Set initial state
      engine.stateManager.set('cpuUsage', 0);
      
      // Simulate receiving a notification
      engine.handleNotification('mcp://server/metrics/cpu', {
        'binding': 'cpuUsage',
        'value': 85.5,
      });
      
      // Check that state was updated
      expect(engine.stateManager.get('cpuUsage'), 85.5);
    });
  });
}