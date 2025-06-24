import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';

void main() {
  group('BindingEngine Tests', () {
    late BindingEngine bindingEngine;
    late StateManager stateManager;
    late RenderContext context;

    setUp(() {
      bindingEngine = BindingEngine();
      stateManager = StateManager();
      final actionHandler = ActionHandler();
      final themeManager = ThemeManager();
      final widgetRegistry = WidgetRegistry();
      
      stateManager.initialize({
        'user': {'name': 'John', 'age': 30},
        'title': 'Test App',
        'version': '1.0.0',
        'form': {'email': 'test@example.com', 'validated': true}
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
      bindingEngine.dispose();
      stateManager.dispose();
    });

    test('recognizes binding expressions', () {
      expect(bindingEngine.isBindingExpression('{{user.name}}'), isTrue);
      expect(bindingEngine.isBindingExpression('plain text'), isFalse);
    });

    test('recognizes mixed content with bindings', () {
      expect(bindingEngine.containsBindingExpression('Hello {{user.name}}!'), isTrue);
      expect(bindingEngine.containsBindingExpression('plain text'), isFalse);
    });

    test('resolves simple binding expressions', () {
      const expression = '{{user.name}}';
      final result = bindingEngine.resolve(expression, context);
      expect(result, equals('John'));
    });

    test('resolves nested object bindings', () {
      const expression = '{{app.title}}';
      final result = bindingEngine.resolve(expression, context);
      expect(result, equals('Test App'));
    });

    test('resolves boolean bindings', () {
      const expression = '{{form.validated}}';
      final result = bindingEngine.resolve(expression, context);
      expect(result, equals(true));
    });

    test('resolves number bindings', () {
      const expression = '{{user.age}}';
      final result = bindingEngine.resolve(expression, context);
      expect(result, equals(30));
    });

    test('returns original value for non-binding expressions', () {
      const expression = 'Plain text';
      final result = bindingEngine.resolve(expression, context);
      expect(result, equals('Plain text'));
    });

    test('handles missing properties gracefully', () {
      const expression = '{{user.missing}}';
      final result = bindingEngine.resolve(expression, context);
      expect(result, isNull);
    });

    test('handles complex nested paths', () {
      stateManager.set('nested.deep.value', 'found');
      const expression = '{{nested.deep.value}}';
      final result = bindingEngine.resolve(expression, context);
      expect(result, equals('found'));
    });

    test('registers complex bindings', () {
      final binding = {
        'id': 'test-binding',
        'source': 'state',
        'path': 'user.name',
        'transform': 'uppercase'
      };
      
      bindingEngine.registerBinding(binding);
      
      // Test that binding was registered (no exception thrown)
      expect(true, isTrue);
    });

    test('handles multiple bindings in single expression', () {
      const expression = 'Hello {{user.name}}, version {{app.version}}';
      final result = bindingEngine.resolve(expression, context);
      expect(result, equals('Hello John, version 1.0.0'));
    });

    test('registers transform functions', () {
      bindingEngine.registerTransform('reverse', (value) {
        if (value is String) {
          return value.split('').reversed.join('');
        }
        return value;
      });
      
      // Test that transform was registered (no exception thrown)
      expect(true, isTrue);
    });
  });
}