import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'renderer.dart';
import '../binding/binding_engine.dart';
import '../actions/action_handler.dart';
import '../state/state_manager.dart';
import '../theme/theme_manager.dart';
import '../i18n/i18n_manager.dart';
import '../utils/mcp_logger.dart';

/// Render context that provides access to runtime services during widget rendering
class RenderContext {
  static final MCPLogger _logger = MCPLogger('RenderContext');
  final Renderer renderer;
  final StateManager stateManager;
  final BindingEngine bindingEngine;
  final ActionHandler actionHandler;
  final ThemeManager themeManager;
  final String? parentId;
  final Map<String, dynamic> localVariables;
  final List<String> _idPath;
  final BuildContext? buildContext;
  final dynamic engine;
  final bool Function(String action, String route, Map<String, dynamic> params)? navigationHandler;
  final Future<dynamic> Function(String resource, String method, String target, dynamic data)? resourceHandler;

  RenderContext({
    required this.renderer,
    required this.stateManager,
    required this.bindingEngine,
    required this.actionHandler,
    required this.themeManager,
    this.parentId,
    this.buildContext,
    this.engine,
    this.navigationHandler,
    this.resourceHandler,
    Map<String, dynamic>? localVariables,
    List<String>? idPath,
  }) : localVariables = localVariables ?? {},
        _idPath = idPath ?? [];

  /// Create a child context with additional local variables
  RenderContext createChildContext({
    String? id,
    Map<String, dynamic>? variables,
  }) {
    final childVars = Map<String, dynamic>.from(localVariables);
    if (variables != null) {
      childVars.addAll(variables);
    }

    final childPath = List<String>.from(_idPath);
    if (id != null) {
      childPath.add(id);
    }

    return RenderContext(
      renderer: renderer,
      stateManager: stateManager,
      bindingEngine: bindingEngine,
      actionHandler: actionHandler,
      themeManager: themeManager,
      parentId: id ?? parentId,
      buildContext: buildContext,
      engine: engine,
      navigationHandler: navigationHandler,
      resourceHandler: resourceHandler,
      localVariables: childVars,
      idPath: childPath,
    );
  }

  /// Generate a unique ID for the current context
  String get contextId => _idPath.join('.');

  /// Resolve a value that might contain bindings
  T resolve<T>(dynamic value) {
    if (value == null) return null as T;
    
    // Handle different value types
    if (value is Map<String, dynamic>) {
      // Check if it's an action definition (has 'type' property)
      // Action objects should not be resolved even if they have a 'binding' property
      if (value.containsKey('type')) {
        // This is likely an action or widget definition, not a binding
        // Don't try to resolve it as a binding
        return value as T;
      }
      
      // Check if it's a binding definition
      if (value.containsKey('binding')) {
        return bindingEngine.resolve<T>(value['binding'], this);
      }
      // Otherwise resolve each value in the map
      final resolved = <String, dynamic>{};
      for (final entry in value.entries) {
        resolved[entry.key] = resolve(entry.value);
      }
      return resolved as T;
    } else if (value is List) {
      // Resolve each item in the list
      return value.map((item) => resolve(item)).toList() as T;
    } else if (value is String) {
      // Check for i18n strings first
      if (value.startsWith('i18n:')) {
        final translated = I18nManager.instance.resolveI18nString(value);
        return (translated ?? value) as T;
      }
      // Check if it contains any binding expressions
      if (value.contains('{{') && value.contains('}}')) {
        return bindingEngine.resolve<T>(value, this);
      }
    }
    
    return value as T;
  }

  /// Build a child widget
  Widget buildWidget(Map<String, dynamic> definition) {
    return renderer.renderWidget(definition, this);
  }

  /// Handle an action
  Future<void> handleAction(Map<String, dynamic>? action) async {
    if (action == null) return;
    
    // Resolve any bindings in the action
    final resolvedAction = resolve<Map<String, dynamic>>(action);
    await actionHandler.execute(resolvedAction, this);
  }

  /// Get current theme
  ThemeData get theme => themeManager.currentTheme;

  /// Get a value from state (handles local.* and app.* prefixes per v1.0 spec)
  T? getState<T>(String path) {
    // Handle v1.0 state prefixes
    if (path.startsWith('local.')) {
      // Page-local state (stored in localVariables)
      final localPath = path.substring(6);
      return localVariables[localPath] as T?;
    } else if (path.startsWith('app.')) {
      // Global application state
      final globalPath = path.substring(4);
      final result = stateManager.get<T>(globalPath);
      _logger.debug('getState app.$globalPath: $result');
      return result;
    } else {
      // No prefix - default to global state for backward compatibility
      final result = stateManager.get<T>(path);
      _logger.debug('getState path: $path, result: $result');
      return result;
    }
  }

  /// Set a value in state (handles local.* and app.* prefixes per v1.0 spec)
  void setState(String path, dynamic value) {
    // Handle v1.0 state prefixes
    if (path.startsWith('local.')) {
      // Page-local state (stored in localVariables)
      final localPath = path.substring(6);
      localVariables[localPath] = value;
      _logger.debug('setState local.$localPath: $value');
    } else if (path.startsWith('app.')) {
      // Global application state
      final globalPath = path.substring(4);
      stateManager.set(globalPath, value);
      _logger.debug('setState app.$globalPath: $value');
    } else {
      // No prefix - default to global state for backward compatibility
      stateManager.set(path, value);
      _logger.debug('setState path: $path, value: $value');
    }
  }

  /// Update state
  void updateState(Map<String, dynamic> updates) {
    stateManager.updateAll(updates);
  }
  
  /// Get a value from state (alias for getState)
  T? getValue<T>(String path) {
    // Check local variables first (including nested paths)
    if (path.contains('.')) {
      final parts = path.split('.');
      final firstPart = parts[0];
      
      // Check if the first part is in local variables
      if (localVariables.containsKey(firstPart)) {
        dynamic current = localVariables[firstPart];
        
        // Navigate the rest of the path
        for (int i = 1; i < parts.length; i++) {
          if (current is Map<String, dynamic>) {
            current = current[parts[i]];
          } else {
            return null;
          }
        }
        
        return current as T?;
      }
    } else if (localVariables.containsKey(path)) {
      return localVariables[path] as T?;
    }
    
    // Check for complex paths like items[index].name
    if (path.contains('[') && path.contains(']')) {
      // Parse the path
      final match = RegExp(r'(\w+)\[(\w+)\](?:\.(.+))?').firstMatch(path);
      if (match != null) {
        final arrayName = match.group(1)!;
        final indexName = match.group(2)!;
        final propertyPath = match.group(3);
        
        // Get the index value from local variables
        final indexValue = localVariables[indexName];
        if (indexValue is int) {
          // Get the array from state
          final array = getState<List<dynamic>>(arrayName);
          if (array != null && indexValue < array.length) {
            final item = array[indexValue];
            if (propertyPath != null && item is Map<String, dynamic>) {
              // Navigate the property path
              dynamic current = item;
              for (final part in propertyPath.split('.')) {
                if (current is Map<String, dynamic>) {
                  current = current[part];
                } else {
                  return null;
                }
              }
              return current as T?;
            } else {
              return item as T?;
            }
          }
        }
      }
    }
    
    return getState<T>(path);
  }

  /// Set a value in state (alias for setState)
  void setValue(String path, dynamic value) {
    setState(path, value);
  }

  /// Get a local variable
  T? getLocal<T>(String key) {
    return localVariables[key] as T?;
  }

  /// Set a local variable
  void setLocal(String key, dynamic value) {
    localVariables[key] = value;
  }

  /// Check if a condition is true
  bool checkCondition(dynamic condition) {
    if (condition == null) return true;
    if (condition is bool) return condition;
    if (condition is String) {
      final resolved = resolve<dynamic>(condition);
      if (resolved is bool) return resolved;
      if (resolved is String) {
        // Handle string conditions
        return resolved.isNotEmpty && resolved.toLowerCase() != 'false';
      }
      return resolved != null;
    }
    if (condition is Map<String, dynamic>) {
      // Handle complex conditions
      return _evaluateComplexCondition(condition);
    }
    return true;
  }

  bool _evaluateComplexCondition(Map<String, dynamic> condition) {
    final operator = condition['operator'] as String?;
    final left = resolve<dynamic>(condition['left']);
    final right = resolve<dynamic>(condition['right']);

    switch (operator) {
      case '==':
      case 'equals':
        return left == right;
      case '!=':
      case 'notEquals':
        return left != right;
      case '>':
      case 'greaterThan':
        return _compareNumeric(left, right) > 0;
      case '>=':
      case 'greaterThanOrEquals':
        return _compareNumeric(left, right) >= 0;
      case '<':
      case 'lessThan':
        return _compareNumeric(left, right) < 0;
      case '<=':
      case 'lessThanOrEquals':
        return _compareNumeric(left, right) <= 0;
      case 'contains':
        if (left is String && right is String) return left.contains(right);
        if (left is List) return left.contains(right);
        if (left is Map) return left.containsKey(right);
        return false;
      case 'startsWith':
        if (left is String && right is String) return left.startsWith(right);
        return false;
      case 'endsWith':
        if (left is String && right is String) return left.endsWith(right);
        return false;
      case 'matches':
        if (left is String && right is String) {
          try {
            return RegExp(right).hasMatch(left);
          } catch (e) {
            return false;
          }
        }
        return false;
      case 'and':
      case '&&':
        final conditions = condition['conditions'] as List?;
        if (conditions != null) {
          return conditions.every((c) => checkCondition(c));
        }
        return checkCondition(left) && checkCondition(right);
      case 'or':
      case '||':
        final conditions = condition['conditions'] as List?;
        if (conditions != null) {
          return conditions.any((c) => checkCondition(c));
        }
        return checkCondition(left) || checkCondition(right);
      case 'not':
      case '!':
        return !checkCondition(left ?? condition['condition']);
      default:
        return true;
    }
  }

  int _compareNumeric(dynamic a, dynamic b) {
    final numA = _toNumber(a);
    final numB = _toNumber(b);
    if (numA == null || numB == null) return 0;
    return numA.compareTo(numB);
  }

  num? _toNumber(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }

  /// Get resource subscribe handler
  Function(String, String)? get onResourceSubscribe =>
      engine?.onResourceSubscribe as Function(String, String)?;
  
  /// Get resource unsubscribe handler
  Function(String)? get onResourceUnsubscribe =>
      engine?.onResourceUnsubscribe as Function(String)?;

  /// Format a value using a formatter
  String format(dynamic value, String? formatter) {
    if (formatter == null) return value.toString();
    
    // Handle common formatters
    switch (formatter) {
      case 'uppercase':
        return value.toString().toUpperCase();
      case 'lowercase':
        return value.toString().toLowerCase();
      case 'capitalize':
        final str = value.toString();
        if (str.isEmpty) return str;
        return str[0].toUpperCase() + str.substring(1).toLowerCase();
      case 'trim':
        return value.toString().trim();
      case 'currency':
        if (value is num) {
          return '\$${value.toStringAsFixed(2)}';
        }
        break;
      case 'percent':
        if (value is num) {
          return '${(value * 100).toStringAsFixed(1)}%';
        }
        break;
      case 'date':
        if (value is DateTime) {
          return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
        }
        break;
      case 'time':
        if (value is DateTime) {
          return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
        }
        break;
      case 'datetime':
        if (value is DateTime) {
          return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
                 '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
        }
        break;
    }
    
    return value.toString();
  }
}