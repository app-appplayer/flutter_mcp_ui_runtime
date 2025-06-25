import '../utils/mcp_logger.dart';

/// Parsed expression representation
class ParsedExpression {
  final String expression;
  final CachedExpressionType type;
  final dynamic parsedData;
  final DateTime timestamp;

  ParsedExpression({
    required this.expression,
    required this.type,
    required this.parsedData,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Cached expression types
enum CachedExpressionType {
  simple, // Simple variable reference like {{name}}
  path, // Path expression like {{user.profile.name}}
  ternary, // Ternary operator like {{isActive ? "Yes" : "No"}}
  logical, // Logical expression like {{a && b || c}}
  comparison, // Comparison like {{age >= 18}}
  arithmetic, // Arithmetic like {{price * quantity}}
  array, // Array access like {{items[0]}}
  pipe, // Pipe transform like {{value | uppercase}}
  function, // Function call like {{calculateTotal()}}
  complex, // Complex expression with multiple operators
}

/// Expression cache for performance optimization
/// according to MCP UI DSL v1.0 specification
class ExpressionCache {
  static final Map<String, ParsedExpression> _cache = {};
  static const int _maxCacheSize = 1000;
  static final MCPLogger _logger = MCPLogger('ExpressionCache');

  /// Cache statistics
  static int _hits = 0;
  static int _misses = 0;

  /// Get cache statistics
  static Map<String, int> get statistics => {
        'hits': _hits,
        'misses': _misses,
        'size': _cache.length,
        'hitRate': _hits + _misses > 0
            ? ((_hits / (_hits + _misses)) * 100).round()
            : 0,
      };

  /// Parse or get cached expression
  static ParsedExpression parse(String expression) {
    // Check cache first
    if (_cache.containsKey(expression)) {
      _hits++;
      final cached = _cache[expression]!;

      // Check if cache entry is still fresh (24 hours)
      if (DateTime.now().difference(cached.timestamp).inHours < 24) {
        return cached;
      } else {
        // Remove stale entry
        _cache.remove(expression);
      }
    }

    _misses++;

    // Parse the expression
    final parsed = _parseExpression(expression);

    // Add to cache with LRU eviction
    if (_cache.length >= _maxCacheSize) {
      // Remove oldest entry
      final oldestKey = _findOldestEntry();
      _cache.remove(oldestKey);
      _logger.debug('Evicted oldest cache entry: $oldestKey');
    }

    _cache[expression] = parsed;
    return parsed;
  }

  /// Find oldest cache entry
  static String _findOldestEntry() {
    String? oldestKey;
    DateTime? oldestTime;

    for (final entry in _cache.entries) {
      if (oldestTime == null || entry.value.timestamp.isBefore(oldestTime)) {
        oldestTime = entry.value.timestamp;
        oldestKey = entry.key;
      }
    }

    return oldestKey ?? _cache.keys.first;
  }

  /// Parse an expression and determine its type
  static ParsedExpression _parseExpression(String expression) {
    // Remove {{ }} if present
    String expr = expression.trim();
    if (expr.startsWith('{{') && expr.endsWith('}}')) {
      expr = expr.substring(2, expr.length - 2).trim();
    }

    // Determine expression type and parse accordingly
    final type = _determineExpressionType(expr);
    final parsedData = _parseByType(expr, type);

    return ParsedExpression(
      expression: expression,
      type: type,
      parsedData: parsedData,
    );
  }

  /// Determine the type of expression
  static CachedExpressionType _determineExpressionType(String expr) {
    // Check for ternary operator
    if (expr.contains('?') && expr.contains(':')) {
      return CachedExpressionType.ternary;
    }

    // Check for logical operators
    if (expr.contains('&&') || expr.contains('||')) {
      return CachedExpressionType.logical;
    }

    // Check for comparison operators
    if (RegExp(r'[<>]=?|[!=]=').hasMatch(expr)) {
      return CachedExpressionType.comparison;
    }

    // Check for arithmetic operators
    if (RegExp(r'[\+\-\*/%]').hasMatch(expr) && !expr.contains('|')) {
      return CachedExpressionType.arithmetic;
    }

    // Check for pipe transforms
    if (expr.contains('|')) {
      return CachedExpressionType.pipe;
    }

    // Check for array access
    if (expr.contains('[') && expr.contains(']')) {
      return CachedExpressionType.array;
    }

    // Check for function call
    if (expr.contains('(') && expr.contains(')')) {
      return CachedExpressionType.function;
    }

    // Check for path expression
    if (expr.contains('.')) {
      return CachedExpressionType.path;
    }

    // Simple variable reference
    return CachedExpressionType.simple;
  }

  /// Parse expression based on its type
  static dynamic _parseByType(String expr, CachedExpressionType type) {
    switch (type) {
      case CachedExpressionType.simple:
        return {'variable': expr};

      case CachedExpressionType.path:
        return {'path': expr.split('.')};

      case CachedExpressionType.ternary:
        // Parse ternary: condition ? trueValue : falseValue
        final match = RegExp(r'(.+?)\s*\?\s*(.+?)\s*:\s*(.+)').firstMatch(expr);
        if (match != null) {
          return {
            'condition': match.group(1)!.trim(),
            'trueValue': match.group(2)!.trim(),
            'falseValue': match.group(3)!.trim(),
          };
        }
        break;

      case CachedExpressionType.pipe:
        // Parse pipe: value | transform:arg1:arg2
        final parts = expr.split('|').map((s) => s.trim()).toList();
        final transforms = <Map<String, dynamic>>[];

        for (int i = 1; i < parts.length; i++) {
          final transformParts = parts[i].split(':');
          transforms.add({
            'name': transformParts[0],
            'args': transformParts.skip(1).toList(),
          });
        }

        return {
          'value': parts[0],
          'transforms': transforms,
        };

      case CachedExpressionType.array:
        // Parse array access: items[index] or items[start:end]
        final match = RegExp(r'(.+?)\[(.+?)\]').firstMatch(expr);
        if (match != null) {
          final arrayName = match.group(1)!.trim();
          final indexExpr = match.group(2)!.trim();

          // Check for slice notation
          if (indexExpr.contains(':')) {
            final parts = indexExpr.split(':');
            return {
              'array': arrayName,
              'type': 'slice',
              'start': parts[0].isEmpty ? null : parts[0],
              'end': parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null,
            };
          } else {
            return {
              'array': arrayName,
              'type': 'index',
              'index': indexExpr,
            };
          }
        }
        break;

      case CachedExpressionType.function:
        // Parse function call: funcName(arg1, arg2)
        final match = RegExp(r'(\w+)\s*\((.*?)\)').firstMatch(expr);
        if (match != null) {
          final funcName = match.group(1)!;
          final argsStr = match.group(2)!;
          final args = argsStr.isEmpty
              ? <String>[]
              : argsStr.split(',').map((s) => s.trim()).toList();

          return {
            'function': funcName,
            'arguments': args,
          };
        }
        break;

      default:
        // For complex expressions, store the raw expression
        // The binding engine will handle the actual parsing
        return {'raw': expr, 'type': type.name};
    }

    // Fallback
    return {'raw': expr};
  }

  /// Clear the cache
  static void clear() {
    _cache.clear();
    _hits = 0;
    _misses = 0;
    _logger.debug('Expression cache cleared');
  }

  /// Get cache size
  static int get size => _cache.length;

  /// Check if expression is cached
  static bool isCached(String expression) => _cache.containsKey(expression);

  /// Remove specific expression from cache
  static void remove(String expression) {
    _cache.remove(expression);
  }

  /// Warmup cache with common expressions
  static void warmup(List<String> expressions) {
    for (final expr in expressions) {
      parse(expr);
    }
    _logger.debug('Warmed up cache with ${expressions.length} expressions');
  }
}
