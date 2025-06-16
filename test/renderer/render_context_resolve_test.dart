import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';

void main() {
  group('RenderContext.resolve Tests', () {
    late RenderContext context;
    late StateManager stateManager;
    late BindingEngine bindingEngine;
    late Renderer renderer;
    late ActionHandler actionHandler;
    late ThemeManager themeManager;
    late WidgetRegistry widgetRegistry;

    setUp(() {
      stateManager = StateManager();
      bindingEngine = BindingEngine();
      actionHandler = ActionHandler();
      themeManager = ThemeManager();
      widgetRegistry = WidgetRegistry();
      
      renderer = Renderer(
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

    test('should not resolve action objects with binding property', () {
      // This is the case that was failing before our fix
      final action = {
        'type': 'resource',
        'action': 'subscribe',
        'uri': 'data://temperature',
        'binding': 'temperature',
      };

      final resolved = context.resolve<Map<String, dynamic>>(action);
      
      // The action should remain unchanged as a Map
      expect(resolved, isA<Map<String, dynamic>>());
      expect(resolved, equals(action));
      expect(resolved['type'], equals('resource'));
      expect(resolved['binding'], equals('temperature'));
    });

    test('should resolve binding definitions without type property', () {
      // This is a pure binding definition
      final binding = {
        'binding': 'temperature',
      };

      // Set up state for the binding
      stateManager.set('temperature', 25.5);

      final resolved = context.resolve<String>(binding);
      
      // The binding should be resolved to the binding name (string)
      // because BindingEngine.resolve expects a string like "temperature" not a map
      expect(resolved, equals('temperature'));
    });

    test('should not resolve widget definitions with type property', () {
      final widget = {
        'type': 'text',
        'content': 'Hello',
        'binding': 'someBinding', // Even with binding property
      };

      final resolved = context.resolve<Map<String, dynamic>>(widget);
      
      // Widget definition should remain unchanged
      expect(resolved, isA<Map<String, dynamic>>());
      expect(resolved, equals(widget));
    });

    test('should resolve nested values in maps without type property', () {
      final data = {
        'name': '{{user.name}}',
        'age': '{{user.age}}',
        'nested': {
          'city': '{{user.city}}',
        },
      };

      stateManager.set('user.name', 'John');
      stateManager.set('user.age', 30);
      stateManager.set('user.city', 'New York');

      final resolved = context.resolve<Map<String, dynamic>>(data);
      
      expect(resolved['name'], equals('John'));
      expect(resolved['age'], equals(30));  // BindingEngine returns the actual number, not string
      expect(resolved['nested']['city'], equals('New York'));
    });

    test('should handle different action types correctly', () {
      final toolAction = {
        'type': 'tool',
        'tool': 'increment',
        'args': {},
      };

      final navigationAction = {
        'type': 'navigation',
        'action': 'push',
        'route': '/profile',
      };

      final stateAction = {
        'type': 'state',
        'action': 'set',
        'path': 'counter',
        'value': 10,
      };

      // All actions should remain unchanged
      expect(context.resolve(toolAction), equals(toolAction));
      expect(context.resolve(navigationAction), equals(navigationAction));
      expect(context.resolve(stateAction), equals(stateAction));
    });

    test('should resolve string bindings', () {
      stateManager.set('message', 'Hello World');
      
      final resolved = context.resolve<String>('{{message}}');
      expect(resolved, equals('Hello World'));
    });
    
    test('should resolve binding from string directly', () {
      // When we pass a direct binding string
      stateManager.set('temperature', 25.5);

      // Direct binding resolution
      final resolved = context.resolve<double>('{{temperature}}');
      
      // This should resolve to the actual value
      expect(resolved, equals(25.5));
    });

    test('should resolve mixed string bindings', () {
      stateManager.set('name', 'John');
      stateManager.set('age', 30);
      
      final resolved = context.resolve<String>('My name is {{name}} and I am {{age}} years old');
      expect(resolved, equals('My name is John and I am 30 years old'));
    });

    test('should resolve lists', () {
      stateManager.set('item1', 'Apple');
      stateManager.set('item2', 'Banana');
      
      final list = ['{{item1}}', '{{item2}}', 'Cherry'];
      final resolved = context.resolve<List>(list);
      
      expect(resolved, equals(['Apple', 'Banana', 'Cherry']));
    });

    test('should handle null values', () {
      final resolved = context.resolve<String?>(null);
      expect(resolved, isNull);
    });

    test('should handle non-binding strings', () {
      final resolved = context.resolve<String>('Just a regular string');
      expect(resolved, equals('Just a regular string'));
    });
  });
}