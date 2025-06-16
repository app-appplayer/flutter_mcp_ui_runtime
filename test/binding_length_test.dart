import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/utils/json_path.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_expression.dart';

void main() {
  group('Length Property Binding Tests', () {
    test('JsonPath handles .length correctly', () {
      final data = {
        'canvasWidgets': ['widget1', 'widget2', 'widget3'],
        'emptyList': [],
        'text': 'hello',
        'nested': {
          'items': ['a', 'b', 'c'],
        },
      };

      expect(JsonPath.get(data, 'canvasWidgets.length'), 3);
      expect(JsonPath.get(data, 'emptyList.length'), 0);
      expect(JsonPath.get(data, 'text.length'), 5);
      expect(JsonPath.get(data, 'nested.items.length'), 3);
    });

    test('StateManager handles .length correctly', () {
      final stateManager = StateManager();
      stateManager.initialize({
        'canvasWidgets': ['widget1', 'widget2', 'widget3'],
        'emptyList': [],
      });

      expect(stateManager.get('canvasWidgets.length'), 3);
      expect(stateManager.get('emptyList.length'), 0);
    });

    test('Expression parsing handles .length in comparisons', () {
      // Test basic comparison
      final expr1 = BindingExpression.parse('canvasWidgets.length > 0');
      expect(expr1.type, ExpressionType.comparison);
      expect(expr1.operator, '>');
      expect(expr1.left?.type, ExpressionType.simple);
      expect(expr1.left?.path, 'canvasWidgets.length');
      expect(expr1.right?.type, ExpressionType.simple);
      expect(expr1.right?.value, 0);

      // Test other comparison operators
      final expr2 = BindingExpression.parse('items.length >= 5');
      expect(expr2.operator, '>=');
      expect(expr2.left?.path, 'items.length');
      expect(expr2.right?.value, 5);

      final expr3 = BindingExpression.parse('text.length == 10');
      expect(expr3.operator, '==');
      expect(expr3.left?.path, 'text.length');
      expect(expr3.right?.value, 10);
    });

    test('Expression parsing handles complex .length expressions', () {
      // Test with arithmetic
      final expr1 = BindingExpression.parse('items.length + 5');
      expect(expr1.type, ExpressionType.arithmetic);
      expect(expr1.operator, '+');
      expect(expr1.left?.path, 'items.length');
      expect(expr1.right?.value, 5);

      // Test with logical operators
      final expr2 = BindingExpression.parse('items.length > 0 && enabled');
      expect(expr2.type, ExpressionType.logical);
      expect(expr2.operator, '&&');
      expect(expr2.left?.type, ExpressionType.comparison);
      expect(expr2.left?.left?.path, 'items.length');

      // Test with ternary
      final expr3 = BindingExpression.parse('items.length > 0 ? "Has items" : "Empty"');
      expect(expr3.type, ExpressionType.conditional);
      expect(expr3.left?.type, ExpressionType.comparison);
      expect(expr3.left?.left?.path, 'items.length');
    });

    test('Expression parsing preserves property paths with dots', () {
      // Make sure dots in property paths don't interfere with operator detection
      final expr1 = BindingExpression.parse('user.profile.name.length > 5');
      expect(expr1.type, ExpressionType.comparison);
      expect(expr1.left?.path, 'user.profile.name.length');
      expect(expr1.right?.value, 5);

      // Test array access with length
      final expr2 = BindingExpression.parse('users[0].name.length == 10');
      expect(expr2.type, ExpressionType.comparison);
      expect(expr2.left?.path, 'users[0].name.length');
      expect(expr2.right?.value, 10);
    });
  });
}