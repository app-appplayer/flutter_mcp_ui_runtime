import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_expression.dart';

void main() {
  test('should parse nested ternary', () {
    const expr = 'status == "success" ? "#4CAF50" : (status == "error" ? "#F44336" : "#FF9800")';
    final parsed = BindingExpression.parse(expr);
    print('Parsed expression type: ${parsed.type}');
    
    // Check false value
    final falseValue = parsed.falseValue!;
    print('False value type: ${falseValue.type}');
    print('False value is conditional: ${falseValue.type == ExpressionType.conditional}');
    
    if (falseValue.type == ExpressionType.conditional) {
      final innerFalse = falseValue.falseValue!;
      print('Inner false value type: ${innerFalse.type}');
      print('Inner false value path: "${innerFalse.path}"');
      print('Inner false value value: ${innerFalse.value}');
    }
  });
  
  test('should parse string literal with quotes', () {
    const expr = '"#FF9800"';
    print('Testing expression: $expr');
    final parsed = BindingExpression.parse(expr);
    print('Parsed type: ${parsed.type}');
    print('Parsed path: "${parsed.path}"');
    print('Parsed value: ${parsed.value}');
  });
}