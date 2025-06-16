import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_expression.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';

void main() {
  group('BindingEngine Simple Tests', () {
    late BindingEngine engine;
    late StateManager stateManager;
    late RenderContext context;
    
    setUp(() {
      engine = BindingEngine();
      stateManager = StateManager();
      final actionHandler = ActionHandler();
      final themeManager = ThemeManager();
      final widgetRegistry = WidgetRegistry();
      
      // Initialize test data
      stateManager.initialize({
        'canvasWidgets': ['widget1', 'widget2', 'widget3'],
        'emptyList': [],
      });
      
      final renderer = Renderer(
        widgetRegistry: widgetRegistry,
        bindingEngine: engine,
        actionHandler: actionHandler,
        stateManager: stateManager,
      );
      
      context = RenderContext(
        renderer: renderer,
        stateManager: stateManager,
        actionHandler: actionHandler,
        themeManager: themeManager,
        bindingEngine: engine,
        buildContext: null,
      );
    });
    
    test('Direct state access for length property', () {
      expect(stateManager.get('canvasWidgets.length'), equals(3));
      expect(stateManager.get('emptyList.length'), equals(0));
    });
    
    test('Expression parsing for length comparisons', () {
      final expr = BindingExpression.parse('canvasWidgets.length > 0');
      expect(expr.type, equals(ExpressionType.comparison));
      expect(expr.operator, equals('>'));
      expect(expr.left?.path, equals('canvasWidgets.length'));
      expect(expr.right?.value, equals(0));
    });
    
    test('BindingEngine resolves length comparisons correctly', () {
      // Test the actual BindingEngine resolution
      final result1 = engine.resolve<bool>('{{canvasWidgets.length > 0}}', context);
      expect(result1, isTrue);
      
      final result2 = engine.resolve<bool>('{{emptyList.length > 0}}', context);
      expect(result2, isFalse);
      
      final result3 = engine.resolve<int>('{{canvasWidgets.length}}', context);
      expect(result3, equals(3));
    });
  });
}