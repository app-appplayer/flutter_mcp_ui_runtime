import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_expression.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/utils/json_path.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';

void main() {
  group('Expression Parsing Tests', () {
    test('JsonPath supports .length property', () {
      final data = {
        'canvasWidgets': ['widget1', 'widget2', 'widget3'],
        'emptyList': [],
        'text': 'hello world',
      };

      // Test list length
      expect(JsonPath.get(data, 'canvasWidgets.length'), 3);
      expect(JsonPath.get(data, 'emptyList.length'), 0);
      
      // Test string length
      expect(JsonPath.get(data, 'text.length'), 11);
    });

    test('Simple property access expressions', () {
      final expr1 = BindingExpression.parse('canvasWidgets.length');
      expect(expr1.type, ExpressionType.simple);
      expect(expr1.path, 'canvasWidgets.length');
      
      final expr2 = BindingExpression.parse('users[0].name.length');
      expect(expr2.type, ExpressionType.simple);
      expect(expr2.path, 'users[0].name.length');
    });

    test('Comparison expressions with property access', () {
      // This is where the issue likely is
      final expr = BindingExpression.parse('canvasWidgets.length > 0');
      
      print('Expression type: ${expr.type}');
      print('Expression path: ${expr.path}');
      print('Expression operator: ${expr.operator}');
      print('Left expression type: ${expr.left?.type}');
      print('Left expression path: ${expr.left?.path}');
      print('Right expression type: ${expr.right?.type}');
      print('Right expression path: ${expr.right?.path}');
      print('Right expression value: ${expr.right?.value}');
      
      expect(expr.type, ExpressionType.comparison);
      expect(expr.operator, '>');
      expect(expr.left?.type, ExpressionType.simple);
      expect(expr.left?.path, 'canvasWidgets.length');
      expect(expr.right?.type, ExpressionType.simple);
      expect(expr.right?.value, 0);
    });

    test('Complex comparison expressions', () {
      final expr1 = BindingExpression.parse('items[0].count >= 10');
      expect(expr1.type, ExpressionType.comparison);
      expect(expr1.operator, '>=');
      expect(expr1.left?.path, 'items[0].count');
      expect(expr1.right?.value, 10);
      
      final expr2 = BindingExpression.parse('user.name.length == 5');
      expect(expr2.type, ExpressionType.comparison);
      expect(expr2.operator, '==');
      expect(expr2.left?.path, 'user.name.length');
      expect(expr2.right?.value, 5);
    });

    test('Evaluating expressions with length property', () {
      final engine = BindingEngine();
      final stateManager = StateManager();
      final themeManager = ThemeManager();
      final actionHandler = ActionHandler();
      final widgetRegistry = WidgetRegistry();
      
      // Set up test data in state manager
      stateManager.initialize({
        'canvasWidgets': ['widget1', 'widget2', 'widget3'],
        'emptyList': [],
        'user': {
          'name': 'Alice',
        },
      });
      
      final renderer = Renderer(
        widgetRegistry: widgetRegistry,
        bindingEngine: engine,
        actionHandler: actionHandler,
        stateManager: stateManager,
      );
      
      final context = RenderContext(
        renderer: renderer,
        stateManager: stateManager,
        actionHandler: actionHandler,
        themeManager: themeManager,
        bindingEngine: engine,
        buildContext: null,
      );

      // Test simple length access
      expect(engine.resolve<int>('{{canvasWidgets.length}}', context), 3);
      expect(engine.resolve<int>('{{emptyList.length}}', context), 0);
      expect(engine.resolve<int>('{{user.name.length}}', context), 5);
      
      // Test comparison with length
      expect(engine.resolve<bool>('{{canvasWidgets.length > 0}}', context), true);
      expect(engine.resolve<bool>('{{emptyList.length > 0}}', context), false);
      expect(engine.resolve<bool>('{{user.name.length == 5}}', context), true);
      expect(engine.resolve<bool>('{{user.name.length >= 3}}', context), true);
    });

    test('Parsing edge cases', () {
      // Test with spaces around operators to avoid ambiguity
      final expr1 = BindingExpression.parse('obj.propValue > 5');
      expect(expr1.type, ExpressionType.comparison);
      expect(expr1.operator, '>');
      expect(expr1.left?.path, 'obj.propValue');
      expect(expr1.right?.value, 5);
      
      // Test with brackets in property path
      final expr2 = BindingExpression.parse('items[0].count > 10');
      expect(expr2.type, ExpressionType.comparison);
      expect(expr2.operator, '>');
      expect(expr2.left?.path, 'items[0].count');
      expect(expr2.right?.value, 10);
    });
  });
}