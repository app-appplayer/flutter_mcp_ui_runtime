import 'package:flutter_mcp_ui_runtime/src/binding/binding_expression.dart';

void main() {
  print('Testing expression parsing for: canvasWidgets.length > 0');
  print('');
  
  final expr = BindingExpression.parse('canvasWidgets.length > 0');
  
  print('Expression type: ${expr.type}');
  print('Expression path: ${expr.path}');
  print('Expression operator: ${expr.operator}');
  print('');
  
  if (expr.left != null) {
    print('Left expression:');
    print('  - type: ${expr.left!.type}');
    print('  - path: ${expr.left!.path}');
    print('  - value: ${expr.left!.value}');
  }
  
  if (expr.right != null) {
    print('Right expression:');
    print('  - type: ${expr.right!.type}');
    print('  - path: ${expr.right!.path}');
    print('  - value: ${expr.right!.value}');
  }
  
  print('\n--- Testing indexOf behavior ---');
  final testExpr = 'canvasWidgets.length > 0';
  print('Expression: "$testExpr"');
  print('Index of ">": ${testExpr.indexOf('>')}');
  print('Substring before ">": "${testExpr.substring(0, testExpr.indexOf('>'))}".trim() = "${testExpr.substring(0, testExpr.indexOf('>')).trim()}"');
  print('Substring after ">": "${testExpr.substring(testExpr.indexOf('>') + 1)}".trim() = "${testExpr.substring(testExpr.indexOf('>') + 1).trim()}"');
}