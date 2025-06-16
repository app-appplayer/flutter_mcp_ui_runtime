/// Represents a parsed binding expression
class BindingExpression {
  final ExpressionType type;
  final String path;
  final String? operator;
  final BindingExpression? left;
  final BindingExpression? right;
  final BindingExpression? trueValue;
  final BindingExpression? falseValue;
  final String? transform;
  final dynamic value;
  final String? methodName;
  final List<BindingExpression>? arguments;

  BindingExpression({
    required this.type,
    required this.path,
    this.operator,
    this.left,
    this.right,
    this.trueValue,
    this.falseValue,
    this.transform,
    this.value,
    this.methodName,
    this.arguments,
  });

  /// Parse a binding expression string
  static BindingExpression parse(String expression) {
    // Remove whitespace
    expression = expression.trim();
    
    // Check for transform (single | that is not part of ||)
    String? transform;
    String baseExpr = expression;
    
    final pipeIndex = expression.indexOf('|');
    if (pipeIndex != -1) {
      // Make sure it's not part of ||
      final isLogicalOr = (pipeIndex > 0 && expression[pipeIndex - 1] == '|') ||
                         (pipeIndex < expression.length - 1 && expression[pipeIndex + 1] == '|');
      if (!isLogicalOr) {
        baseExpr = expression.substring(0, pipeIndex).trim();
        transform = expression.substring(pipeIndex + 1).trim();
      }
    }
    
    // Check for ternary operator
    final questionIndex = baseExpr.indexOf('?');
    if (questionIndex != -1) {
      final colonIndex = baseExpr.indexOf(':', questionIndex);
      if (colonIndex != -1) {
        final condition = baseExpr.substring(0, questionIndex).trim();
        final trueVal = baseExpr.substring(questionIndex + 1, colonIndex).trim();
        final falseVal = baseExpr.substring(colonIndex + 1).trim();
        
        return BindingExpression(
          type: ExpressionType.conditional,
          path: '',
          left: parse(condition),
          trueValue: _parseValue(trueVal),
          falseValue: _parseValue(falseVal),
          transform: transform,
        );
      }
    }
    
    // Check for null coalescing (lowest precedence)
    final nullCoalescingIndex = baseExpr.indexOf('??');
    if (nullCoalescingIndex != -1) {
      final left = baseExpr.substring(0, nullCoalescingIndex).trim();
      final right = baseExpr.substring(nullCoalescingIndex + 2).trim();
      
      return BindingExpression(
        type: ExpressionType.nullCoalescing,
        path: '',
        operator: '??',
        left: parse(left),
        right: _parseValue(right),
        transform: transform,
      );
    }
    
    // Check for logical OR (second lowest precedence)
    final orIndex = baseExpr.indexOf('||');
    if (orIndex != -1) {
      final left = baseExpr.substring(0, orIndex).trim();
      final right = baseExpr.substring(orIndex + 2).trim();
      
      return BindingExpression(
        type: ExpressionType.logical,
        path: '',
        operator: '||',
        left: parse(left), // Recursive parse for complex expressions
        right: parse(right),
        transform: transform,
      );
    }
    
    // Check for logical AND (medium precedence)
    final andIndex = baseExpr.indexOf('&&');
    if (andIndex != -1) {
      final left = baseExpr.substring(0, andIndex).trim();
      final right = baseExpr.substring(andIndex + 2).trim();
      
      return BindingExpression(
        type: ExpressionType.logical,
        path: '',
        operator: '&&',
        left: parse(left), // Recursive parse for complex expressions
        right: parse(right),
        transform: transform,
      );
    }
    
    // Check for comparison operators
    for (final op in ['==', '!=', '>=', '<=', '>', '<']) {
      final opIndex = baseExpr.indexOf(op);
      if (opIndex != -1) {
        final left = baseExpr.substring(0, opIndex).trim();
        final right = baseExpr.substring(opIndex + op.length).trim();
        
        return BindingExpression(
          type: ExpressionType.comparison,
          path: '',
          operator: op,
          left: _parseValue(left),
          right: _parseValue(right),
          transform: transform,
        );
      }
    }
    
    // Check for arithmetic operators (lower precedence: +, -)
    // Use lastIndexOf for proper left-to-right evaluation (a + b + c) = ((a + b) + c)
    for (final op in ['+', '-']) {
      final opIndex = baseExpr.lastIndexOf(op);
      if (opIndex > 0 && opIndex < baseExpr.length - 1) {
        final left = baseExpr.substring(0, opIndex).trim();
        final right = baseExpr.substring(opIndex + 1).trim();
        
        return BindingExpression(
          type: ExpressionType.arithmetic,
          path: '',
          operator: op,
          left: parse(left), // Recursive parse to handle left side properly
          right: _parseValue(right),
          transform: transform,
        );
      }
    }
    
    // Check for arithmetic operators (higher precedence: *, /, %)
    for (final op in ['*', '/', '%']) {
      final opIndex = baseExpr.lastIndexOf(op);
      if (opIndex > 0 && opIndex < baseExpr.length - 1) {
        final left = baseExpr.substring(0, opIndex).trim();
        final right = baseExpr.substring(opIndex + 1).trim();
        
        return BindingExpression(
          type: ExpressionType.arithmetic,
          path: '',
          operator: op,
          left: _parseValue(left),
          right: _parseValue(right),
          transform: transform,
        );
      }
    }
    
    // Check for unary logical operators (highest precedence)
    if (baseExpr.startsWith('!')) {
      final operand = baseExpr.substring(1).trim();
      return BindingExpression(
        type: ExpressionType.logical,
        path: '',
        operator: '!',
        left: parse(operand),
        transform: transform,
      );
    }
    
    // Check for function or method calls
    final callMatch = RegExp(r'^([\w\.]+)\((.*)\)$').firstMatch(baseExpr);
    if (callMatch != null) {
      final fullPath = callMatch.group(1)!;
      final argsString = callMatch.group(2)!;
      
      // Parse arguments
      final args = _parseArguments(argsString);
      
      // Check if it's a method call (has a dot before the method name)
      final lastDotIndex = fullPath.lastIndexOf('.');
      if (lastDotIndex > 0) {
        // Method call
        final objectPath = fullPath.substring(0, lastDotIndex);
        final methodName = fullPath.substring(lastDotIndex + 1);
        
        return BindingExpression(
          type: ExpressionType.methodCall,
          path: objectPath,
          methodName: methodName,
          arguments: args,
          transform: transform,
        );
      } else {
        // Function call
        return BindingExpression(
          type: ExpressionType.functionCall,
          path: '',
          methodName: fullPath,
          arguments: args,
          transform: transform,
        );
      }
    }
    
    // Simple path expression
    return BindingExpression(
      type: ExpressionType.simple,
      path: baseExpr,
      transform: transform,
    );
  }
  
  /// Parse function/method arguments
  static List<BindingExpression> _parseArguments(String argsString) {
    if (argsString.trim().isEmpty) return [];
    
    final args = <BindingExpression>[];
    var depth = 0;
    var currentArg = '';
    
    // Split by comma, but respect nested parentheses
    for (var i = 0; i < argsString.length; i++) {
      final char = argsString[i];
      
      if (char == '(') {
        depth++;
      } else if (char == ')') {
        depth--;
      } else if (char == ',' && depth == 0) {
        // Found argument separator at top level
        if (currentArg.trim().isNotEmpty) {
          args.add(_parseValue(currentArg.trim()));
        }
        currentArg = '';
        continue;
      }
      
      currentArg += char;
    }
    
    // Add the last argument
    if (currentArg.trim().isNotEmpty) {
      args.add(_parseValue(currentArg.trim()));
    }
    
    return args;
  }

  /// Parse a value (could be a literal or another expression)
  static BindingExpression _parseValue(String value) {
    value = value.trim();
    
    // Check for unary logical operators
    if (value.startsWith('!')) {
      final operand = value.substring(1).trim();
      return BindingExpression(
        type: ExpressionType.logical,
        path: '',
        operator: '!',
        left: _parseValue(operand),
      );
    }
    
    // String literal
    if ((value.startsWith("'") && value.endsWith("'")) ||
        (value.startsWith('"') && value.endsWith('"'))) {
      return BindingExpression(
        type: ExpressionType.simple,
        path: '',
        value: value.substring(1, value.length - 1),
      );
    }
    
    // Number literal
    final num? number = num.tryParse(value);
    if (number != null) {
      return BindingExpression(
        type: ExpressionType.simple,
        path: '',
        value: number,
      );
    }
    
    // Boolean literal
    if (value == 'true' || value == 'false') {
      return BindingExpression(
        type: ExpressionType.simple,
        path: '',
        value: value == 'true',
      );
    }
    
    // Otherwise, treat as a path expression
    return BindingExpression(
      type: ExpressionType.simple,
      path: value,
    );
  }
}

/// Types of binding expressions
enum ExpressionType {
  simple,         // Direct path: {{variable}}
  conditional,    // Ternary: {{condition ? true : false}}
  arithmetic,     // Math: {{a + b}}
  comparison,     // Compare: {{a > b}}
  logical,        // Logic: {{a && b}}, {{a || b}}, {{!a}}
  nullCoalescing, // Null coalescing: {{a ?? b}}
  methodCall,     // Method call: {{value.method(args)}}
  functionCall,   // Function call: {{func(args)}}
}