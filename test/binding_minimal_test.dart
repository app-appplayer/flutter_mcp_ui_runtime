import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_expression.dart';

void main() {
  test('Debug: Trace expression evaluation for canvasWidgets.length > 0', () {
    // Let's manually trace through what should happen
    
    // 1. Parse the expression
    const expression = 'canvasWidgets.length > 0';
    final parsed = BindingExpression.parse(expression);
    
    print('\n=== Expression Parsing ===');
    print('Input: "$expression"');
    print('Parsed type: ${parsed.type}');
    print('Operator: ${parsed.operator}');
    print('Left:');
    print('  - Type: ${parsed.left?.type}');
    print('  - Path: ${parsed.left?.path}');
    print('  - Value: ${parsed.left?.value}');
    print('Right:');
    print('  - Type: ${parsed.right?.type}');
    print('  - Path: ${parsed.right?.path}');
    print('  - Value: ${parsed.right?.value}');
    
    // Verify parsing is correct
    expect(parsed.type, ExpressionType.comparison);
    expect(parsed.operator, '>');
    expect(parsed.left?.type, ExpressionType.simple);
    expect(parsed.left?.path, 'canvasWidgets.length');
    expect(parsed.right?.type, ExpressionType.simple);
    expect(parsed.right?.value, 0);
    
    // 2. What should happen during evaluation:
    // - _evaluateExpression is called with the comparison expression
    // - It calls _evaluateComparison
    // - _evaluateComparison evaluates left side: _evaluateExpression(expr.left)
    // - Since left is a simple expression with path "canvasWidgets.length",
    //   it calls _evaluateSimple("canvasWidgets.length", context)
    // - _evaluateSimple calls context.getValue("canvasWidgets.length")
    // - context.getValue calls stateManager.get("canvasWidgets.length")
    // - stateManager.get uses JsonPath.get which supports .length
    
    print('\n=== Expected Evaluation Flow ===');
    print('1. _evaluateExpression(comparison) -> _evaluateComparison()');
    print('2. _evaluateComparison evaluates left: _evaluateExpression(simple path)');
    print('3. _evaluateSimple("canvasWidgets.length") -> context.getValue()');
    print('4. context.getValue() -> stateManager.get("canvasWidgets.length")');
    print('5. stateManager.get() -> JsonPath.get() returns 3');
    print('6. _evaluateComparison evaluates right: value 0');
    print('7. _evaluateComparison returns: 3 > 0 = true');
  });
  
  test('Verify expression types', () {
    // Test various expressions to ensure they're parsed correctly
    final testCases = [
      ('items.length', ExpressionType.simple, null),
      ('items.length > 0', ExpressionType.comparison, '>'),
      ('items.length >= 5', ExpressionType.comparison, '>='),
      ('items.length == 0', ExpressionType.comparison, '=='),
      ('items.length != 0', ExpressionType.comparison, '!='),
      ('items.length < 10', ExpressionType.comparison, '<'),
      ('items.length <= 10', ExpressionType.comparison, '<='),
      ('items.length + 5', ExpressionType.arithmetic, '+'),
      ('items.length - 2', ExpressionType.arithmetic, '-'),
      ('items.length * 2', ExpressionType.arithmetic, '*'),
      ('items.length > 0 && enabled', ExpressionType.logical, '&&'),
      ('items.length > 0 || force', ExpressionType.logical, '||'),
      ('!items.length', ExpressionType.logical, '!'),
      ('items.length > 0 ? "yes" : "no"', ExpressionType.conditional, null),
    ];
    
    for (final (expr, expectedType, expectedOp) in testCases) {
      final parsed = BindingExpression.parse(expr);
      expect(
        parsed.type,
        expectedType,
        reason: 'Expression "$expr" should have type $expectedType',
      );
      if (expectedOp != null) {
        expect(
          parsed.operator,
          expectedOp,
          reason: 'Expression "$expr" should have operator $expectedOp',
        );
      }
    }
  });
}