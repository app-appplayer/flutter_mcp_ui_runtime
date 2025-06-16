import 'dart:async';

import '../renderer/render_context.dart';
import 'binding_expression.dart';
import '../utils/mcp_logger.dart';

/// Engine for handling data bindings
class BindingEngine {
  final Map<String, Binding> _bindings = {};
  final Map<String, StreamSubscription> _subscriptions = {};
  final Map<String, Function> _transforms = {};
  final MCPLogger _logger = MCPLogger('BindingEngine');

  BindingEngine() {
    _registerDefaultTransforms();
  }

  void _registerDefaultTransforms() {
    _transforms['uppercase'] = (value) => value?.toString().toUpperCase();
    _transforms['lowercase'] = (value) => value?.toString().toLowerCase();
    _transforms['capitalize'] = (value) {
      final str = value?.toString() ?? '';
      if (str.isEmpty) return str;
      return str[0].toUpperCase() + str.substring(1).toLowerCase();
    };
    _transforms['round'] = (value) {
      if (value is num) return value.round();
      return value;
    };
    _transforms['floor'] = (value) {
      if (value is num) return value.floor();
      return value;
    };
    _transforms['ceil'] = (value) {
      if (value is num) return value.ceil();
      return value;
    };
    _transforms['abs'] = (value) {
      if (value is num) return value.abs();
      return value;
    };
  }

  /// Register a custom transform function
  void registerTransform(String name, Function transform) {
    _transforms[name] = transform;
  }

  /// Register a binding definition
  void registerBinding(Map<String, dynamic> bindingDef) {
    final id = bindingDef['id'] as String;
    final source = bindingDef['source'] as String;
    final path = bindingDef['path'] as String?;
    final defaultValue = bindingDef['default'];
    final transform = bindingDef['transform'] as String?;

    _bindings[id] = Binding(
      id: id,
      source: _parseBindingSource(source),
      path: path,
      defaultValue: defaultValue,
      transform: transform,
    );
  }

  /// Check if a string is a binding expression (single, complete binding)
  bool isBindingExpression(String value) {
    if (!value.startsWith('{{') || !value.endsWith('}}')) {
      return false;
    }
    
    // Count the number of {{ and }} to ensure it's a single complete binding
    final openCount = RegExp(r'\{\{').allMatches(value).length;
    final closeCount = RegExp(r'\}\}').allMatches(value).length;
    
    // For a single binding expression, should have exactly one {{ and one }}
    return openCount == 1 && closeCount == 1;
  }

  /// Check if a string contains binding expressions
  bool containsBindingExpression(String value) {
    return value.contains('{{') && value.contains('}}');
  }

  /// Resolve a value (handle bindings)
  T resolve<T>(dynamic value, RenderContext context) {
    if (value is String) {
      _logger.debug('resolve called with value: "$value" for type: $T');
      
      // Check for theme binding
      if (value.startsWith('{{theme.') && value.endsWith('}}')) {
        final path = value.substring(8, value.length - 2);
        final themeValue = context.themeManager.getThemeValue(path);
        _logger.debug('Theme binding resolved: $path -> $themeValue');
        if (themeValue != null) {
          return _convertToType<T>(themeValue);
        }
      }
      
      if (isBindingExpression(value)) {
        _logger.debug('isBindingExpression true for: "$value"');
        return _resolveBinding<T>(value, context);
      } else if (containsBindingExpression(value)) {
        _logger.debug('containsBindingExpression true for: "$value"');
        return _resolveMixedContent<T>(value, context);
      }
    }
    return _convertToType<T>(value);
  }
  
  /// Convert a value to the requested type
  T _convertToType<T>(dynamic value) {
    // If the value is already of the correct type, return it
    if (value is T) {
      return value;
    }
    
    // Handle null values
    if (value == null) {
      if (null is T) {
        return null as T;
      }
      // For non-nullable types, provide default values
      if (T == String) return '' as T;
      if (T == int) return 0 as T;
      if (T == double) return 0.0 as T;
      if (T == bool) return false as T;
      throw Exception('Cannot convert null to non-nullable type $T');
    }
    
    // Handle type conversions to String
    if (T == String || T.toString() == 'String?') {
      return value.toString() as T;
    }
    
    // Handle type conversions to int
    if (T == int || T.toString() == 'int?') {
      if (value is double) return value.toInt() as T;
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed as T;
        if (null is T) return null as T;
        return 0 as T;
      }
    }
    
    // Handle type conversions to double
    if (T == double || T.toString() == 'double?') {
      if (value is int) return value.toDouble() as T;
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed as T;
        if (null is T) return null as T;
        return 0.0 as T;
      }
    }
    
    // Handle type conversions to bool
    if (T == bool || T.toString() == 'bool?') {
      if (value is String) return (value.toLowerCase() == 'true') as T;
      if (value is int) return (value != 0) as T;
    }
    
    // Default: try direct cast
    return value as T;
  }

  /// Resolve mixed content with embedded bindings
  T _resolveMixedContent<T>(String content, RenderContext context) {
    _logger.debug('_resolveMixedContent called with: $content');
    String result = content;
    
    // Find all binding expressions in the content
    final bindingPattern = RegExp(r'\{\{([^}]+)\}\}');
    final matches = bindingPattern.allMatches(content);
    
    for (final match in matches) {
      final fullMatch = match.group(0)!; // e.g., "{{count}}"
      final expression = match.group(1)!; // e.g., "count"
      
      try {
        // Parse and evaluate the expression
        final parsed = BindingExpression.parse(expression);
        final resolvedValue = _evaluateExpression(parsed, context);
        
        // Apply transform if specified
        dynamic finalValue = resolvedValue;
        if (parsed.transform != null && _transforms.containsKey(parsed.transform)) {
          finalValue = _transforms[parsed.transform]!(resolvedValue);
        }
        
        // Replace the binding with the resolved value
        result = result.replaceAll(fullMatch, finalValue.toString());
        _logger.debug('Resolved $fullMatch to $finalValue');
      } catch (e) {
        // If evaluation fails, leave the binding as-is
        _logger.warning('Failed to resolve binding $fullMatch: $e');
      }
    }
    
    _logger.debug('_resolveMixedContent final result: $result');
    
    return _convertToType<T>(result);
  }

  /// Resolve a binding expression
  T _resolveBinding<T>(String expression, RenderContext context) {
    // Extract expression content
    final expr = expression.substring(2, expression.length - 2).trim();
    
    // Check for empty expression
    if (expr.isEmpty) {
      _logger.warning('Empty binding expression found: $expression');
      return _convertToType<T>(expression);
    }
    
    // Parse expression
    final parsed = BindingExpression.parse(expr);
    
    // Evaluate expression
    dynamic result = _evaluateExpression(parsed, context);
    
    // Apply transform if specified
    if (parsed.transform != null && _transforms.containsKey(parsed.transform)) {
      result = _transforms[parsed.transform]!(result);
    }
    
    return _convertToType<T>(result);
  }

  /// Evaluate a binding expression
  dynamic _evaluateExpression(BindingExpression expr, RenderContext context) {
    // Check if this expression has a literal value
    if (expr.value != null) {
      return expr.value;
    }
    
    switch (expr.type) {
      case ExpressionType.simple:
        return _evaluateSimple(expr.path, context);
      
      case ExpressionType.conditional:
        return _evaluateConditional(expr, context);
      
      case ExpressionType.arithmetic:
        return _evaluateArithmetic(expr, context);
      
      case ExpressionType.comparison:
        return _evaluateComparison(expr, context);
      
      case ExpressionType.logical:
        return _evaluateLogical(expr, context);
      
      case ExpressionType.nullCoalescing:
        return _evaluateNullCoalescing(expr, context);
        
      case ExpressionType.methodCall:
        return _evaluateMethodCall(expr, context);
        
      case ExpressionType.functionCall:
        return _evaluateFunctionCall(expr, context);
    }
  }

  /// Evaluate a simple path expression
  dynamic _evaluateSimple(String path, RenderContext context) {
    // Check for theme path
    if (path.startsWith('theme.')) {
      final themeValue = context.themeManager.getThemeValue(path.substring(6));
      _logger.debug('Theme path resolved: $path -> $themeValue');
      return themeValue;
    }
    
    // Check if this is a registered binding
    if (_bindings.containsKey(path)) {
      final binding = _bindings[path]!;
      // For now, just return the default value
      // In a full implementation, this would connect to the actual data source
      return binding.defaultValue;
    }
    
    // Handle app.* prefix properly by passing the full path to context
    final result = context.getValue(path);
    _logger.debug('_evaluateSimple path: $path, result: $result, stateManager: ${context.stateManager.getState()}');
    return result;
  }

  /// Evaluate a conditional expression
  dynamic _evaluateConditional(BindingExpression expr, RenderContext context) {
    final condition = _evaluateExpression(expr.left!, context);
    
    if (_isTruthy(condition)) {
      return _evaluateExpression(expr.trueValue!, context);
    } else {
      return _evaluateExpression(expr.falseValue!, context);
    }
  }

  /// Evaluate an arithmetic expression
  dynamic _evaluateArithmetic(BindingExpression expr, RenderContext context) {
    final left = _evaluateExpression(expr.left!, context);
    final right = _evaluateExpression(expr.right!, context);
    
    
    if (left is num && right is num) {
      switch (expr.operator) {
        case '+':
          return left + right;
        case '-':
          return left - right;
        case '*':
          return left * right;
        case '/':
          return right != 0 ? left / right : 0;
        case '%':
          return right != 0 ? left % right : 0;
      }
    }
    
    // String concatenation
    if (expr.operator == '+') {
      return '${left ?? ''}${right ?? ''}';
    }
    
    return null;
  }

  /// Evaluate a comparison expression
  bool _evaluateComparison(BindingExpression expr, RenderContext context) {
    final left = _evaluateExpression(expr.left!, context);
    final right = _evaluateExpression(expr.right!, context);
    
    switch (expr.operator) {
      case '==':
        return left == right;
      case '!=':
        return left != right;
      case '>':
        return (left is num && right is num) ? left > right : false;
      case '<':
        return (left is num && right is num) ? left < right : false;
      case '>=':
        return (left is num && right is num) ? left >= right : false;
      case '<=':
        return (left is num && right is num) ? left <= right : false;
      default:
        return false;
    }
  }

  /// Evaluate a null coalescing expression
  dynamic _evaluateNullCoalescing(BindingExpression expr, RenderContext context) {
    final left = _evaluateExpression(expr.left!, context);
    if (left != null) {
      return left;
    }
    return _evaluateExpression(expr.right!, context);
  }

  /// Evaluate a logical expression
  bool _evaluateLogical(BindingExpression expr, RenderContext context) {
    switch (expr.operator) {
      case '&&':
        final left = _evaluateExpression(expr.left!, context);
        if (!_isTruthy(left)) return false;
        final right = _evaluateExpression(expr.right!, context);
        return _isTruthy(right);
      
      case '||':
        final left = _evaluateExpression(expr.left!, context);
        if (_isTruthy(left)) return true;
        final right = _evaluateExpression(expr.right!, context);
        return _isTruthy(right);
      
      case '!':
        final operand = _evaluateExpression(expr.left!, context);
        return !_isTruthy(operand);
      
      default:
        return false;
    }
  }

  /// Evaluate a method call expression
  dynamic _evaluateMethodCall(BindingExpression expr, RenderContext context) {
    // Get the object
    final obj = _evaluateSimple(expr.path, context);
    if (obj == null) return null;
    
    // Evaluate arguments
    final args = <dynamic>[];
    if (expr.arguments != null) {
      for (final arg in expr.arguments!) {
        args.add(_evaluateExpression(arg, context));
      }
    }
    
    _logger.debug('Method call: ${expr.methodName} on ${obj.runtimeType} with args: $args');
    
    // Handle built-in methods
    switch (expr.methodName) {
      case 'toString':
        return obj.toString();
        
      case 'toStringAsFixed':
        if (obj is num && args.isNotEmpty && args[0] is num) {
          return obj.toStringAsFixed(args[0].toInt());
        }
        break;
        
      case 'substring':
        if (obj is String) {
          if (args.length == 1 && args[0] is num) {
            return obj.substring(args[0].toInt());
          } else if (args.length == 2 && args[0] is num && args[1] is num) {
            return obj.substring(args[0].toInt(), args[1].toInt());
          }
        }
        break;
        
      case 'toUpperCase':
        if (obj is String) {
          return obj.toUpperCase();
        }
        break;
        
      case 'toLowerCase':
        if (obj is String) {
          return obj.toLowerCase();
        }
        break;
        
      case 'trim':
        if (obj is String) {
          return obj.trim();
        }
        break;
        
      case 'contains':
        if (obj is String && args.isNotEmpty) {
          return obj.contains(args[0].toString());
        } else if (obj is List && args.isNotEmpty) {
          return obj.contains(args[0]);
        }
        break;
        
      case 'indexOf':
        if (obj is String && args.isNotEmpty) {
          return obj.indexOf(args[0].toString());
        } else if (obj is List && args.isNotEmpty) {
          return obj.indexOf(args[0]);
        }
        break;
        
      case 'replaceAll':
        if (obj is String && args.length >= 2) {
          return obj.replaceAll(args[0].toString(), args[1].toString());
        }
        break;
        
      case 'split':
        if (obj is String && args.isNotEmpty) {
          return obj.split(args[0].toString());
        }
        break;
        
      case 'join':
        if (obj is List && args.isNotEmpty) {
          return obj.join(args[0].toString());
        }
        break;
        
      case 'add':
        if (obj is List && args.isNotEmpty) {
          obj.add(args[0]);
          return obj;
        }
        break;
        
      case 'remove':
        if (obj is List && args.isNotEmpty) {
          obj.remove(args[0]);
          return obj;
        }
        break;
        
      case 'clear':
        if (obj is List) {
          obj.clear();
          return obj;
        }
        break;
    }
    
    _logger.warning('Unknown method: ${expr.methodName} on ${obj.runtimeType}');
    return null;
  }
  
  /// Evaluate a function call expression
  dynamic _evaluateFunctionCall(BindingExpression expr, RenderContext context) {
    // Evaluate arguments
    final args = <dynamic>[];
    if (expr.arguments != null) {
      for (final arg in expr.arguments!) {
        args.add(_evaluateExpression(arg, context));
      }
    }
    
    // Handle built-in functions
    switch (expr.methodName) {
      case 'min':
        if (args.length == 2 && args[0] is num && args[1] is num) {
          return args[0] < args[1] ? args[0] : args[1];
        }
        break;
        
      case 'max':
        if (args.length == 2 && args[0] is num && args[1] is num) {
          return args[0] > args[1] ? args[0] : args[1];
        }
        break;
        
      case 'abs':
        if (args.isNotEmpty && args[0] is num) {
          return args[0].abs();
        }
        break;
        
      case 'round':
        if (args.isNotEmpty && args[0] is num) {
          return args[0].round();
        }
        break;
        
      case 'floor':
        if (args.isNotEmpty && args[0] is num) {
          return args[0].floor();
        }
        break;
        
      case 'ceil':
        if (args.isNotEmpty && args[0] is num) {
          return args[0].ceil();
        }
        break;
        
      case 'parseInt':
        if (args.isNotEmpty) {
          return int.tryParse(args[0].toString());
        }
        break;
        
      case 'parseDouble':
        if (args.isNotEmpty) {
          return double.tryParse(args[0].toString());
        }
        break;
        
      case 'now':
        return DateTime.now().toIso8601String();
        
      case 'canGroup':
        // This would need custom implementation based on app logic
        // For now, return false
        return false;
        
      case 'calculateDuration':
        // This would need custom implementation based on app logic
        // For now, return 0
        return 0;
    }
    
    _logger.warning('Unknown function: ${expr.methodName}');
    return null;
  }

  /// Check if a value is truthy
  bool _isTruthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.isNotEmpty;
    if (value is List) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }

  /// Parse binding source from string
  BindingSource _parseBindingSource(String source) {
    switch (source) {
      case 'state':
        return BindingSource.state;
      case 'tool':
        return BindingSource.tool;
      case 'stream':
        return BindingSource.stream;
      case 'resource':
        return BindingSource.resource;
      default:
        return BindingSource.state;
    }
  }

  /// Dispose resources
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _bindings.clear();
  }
}

/// Binding definition
class Binding {
  final String id;
  final BindingSource source;
  final String? path;
  final dynamic defaultValue;
  final String? transform;

  Binding({
    required this.id,
    required this.source,
    this.path,
    this.defaultValue,
    this.transform,
  });
}

/// Binding source types
enum BindingSource {
  state,
  tool,
  stream,
  resource,
}