import 'dart:async';
import 'package:flutter/foundation.dart';

import '../renderer/render_context.dart';
import '../utils/mcp_logger.dart';
import 'action_result.dart';

/// Handles action execution
class ActionHandler {
  final Map<String, ActionExecutor> _executors = {};
  final Map<String, Function> _toolExecutors = {};
  final MCPLogger _logger = MCPLogger('ActionHandler');

  ActionHandler() {
    _registerDefaultExecutors();
  }

  void _registerDefaultExecutors() {
    final toolExecutor = ToolActionExecutor();
    toolExecutor._toolExecutors = _toolExecutors; // Connect the tool executors map
    _executors['tool'] = toolExecutor;
    _executors['navigation'] = NavigationActionExecutor();
    _executors['state'] = StateActionExecutor();
    _executors['resource'] = ResourceActionExecutor();
    _executors['batch'] = BatchActionExecutor();
    _executors['conditional'] = ConditionalActionExecutor();
    _executors['addRandomWidget'] = TestActionExecutor();
    _executors['deleteRandomWidget'] = TestActionExecutor();
    _executors['shuffleWidgets'] = TestActionExecutor();
    _executors['clearWidgets'] = TestActionExecutor();
    _executors['addHeavyWidget'] = TestActionExecutor();
    _executors['increment'] = StateActionExecutor(); // Alias for state increment
  }

  /// Register a tool executor function
  void registerToolExecutor(String toolName, Function executor) {
    _toolExecutors[toolName] = executor;
  }

  /// Execute an action
  Future<ActionResult> execute(
    Map<String, dynamic> action,
    RenderContext context,
  ) async {
    final type = action['type'] as String?;
    if (type == null) {
      return ActionResult.error('Action type is required');
    }

    final executor = _executors[type];
    if (executor == null) {
      _logger.error('Unknown action type: $type - Available: ${_executors.keys.toList()}');
      throw Exception('Unknown action type: $type');
    }

    try {
      // Pass dependencies to executor if needed
      if (executor is ToolActionExecutor) {
        executor._toolExecutors = _toolExecutors;
      } else if (executor is BatchActionExecutor) {
        executor._actionHandler = this;
      } else if (executor is ConditionalActionExecutor) {
        executor._actionHandler = this;
      }

      _logger.debug('About to execute action with executor: ${executor.runtimeType}');
      final result = await executor.execute(action, context);
      _logger.debug('Executor returned result: ${result.success} - ${result.data}');

      // Handle success/error callbacks
      if (result.success) {
        final onSuccess = action['onSuccess'] as Map<String, dynamic>?;
        if (onSuccess != null) {
          await execute(onSuccess, context);
        }
      } else {
        final onError = action['onError'] as Map<String, dynamic>?;
        if (onError != null) {
          await execute(onError, context);
        }
      }

      return result;
    } catch (e) {
      // Re-throw validation errors (ArgumentError, Exception with validation messages)
      if (e is ArgumentError || 
          (e is Exception && e.toString().contains('required'))) {
        rethrow;
      }
      // Catch and wrap other errors (network, tool execution, etc.)
      return ActionResult.error(e.toString());
    }
  }

  /// Register a custom action executor
  void registerExecutor(String type, ActionExecutor executor) {
    _executors[type] = executor;
  }

  /// Debug: Get registered tool executors
  Map<String, Function> get toolExecutors => Map.from(_toolExecutors);
}

/// Base class for action executors
abstract class ActionExecutor {
  Future<ActionResult> execute(
    Map<String, dynamic> action,
    RenderContext context,
  );
}

/// Executes tool actions
class ToolActionExecutor extends ActionExecutor {
  final MCPLogger _logger = MCPLogger('ToolActionExecutor');
  Map<String, Function>? _toolExecutors;

  @override
  Future<ActionResult> execute(
    Map<String, dynamic> action,
    RenderContext context,
  ) async {
    final tool = action['tool'] as String?;
    if (tool == null) {
      _logger.error('Tool action error: Tool name is required');
      return ActionResult.error('Tool name is required');
    }

    _logger.debug('Executing tool action: $tool with action: $action');

    // Try to find specific tool executor, fallback to 'default' handler
    final toolExecutor = _toolExecutors?[tool] ?? _toolExecutors?['default'];
    if (toolExecutor == null) {
      _logger.error('Tool executor not found: $tool, available: ${_toolExecutors?.keys}');
      return ActionResult.error('Tool executor not found: $tool');
    }

    _logger.debug('Found tool executor for: $tool');
    _logger.debug('About to extract args from action');

    Map<String, dynamic> args;
    try {
      final rawArgs = action['args'];
      if (rawArgs == null) {
        args = {};
      } else if (rawArgs is Map<String, dynamic>) {
        args = rawArgs;
      } else if (rawArgs is Map) {
        // Convert Map<dynamic, dynamic> to Map<String, dynamic>
        args = Map<String, dynamic>.from(rawArgs);
      } else {
        args = {};
      }
      _logger.debug('Successfully extracted args');
      _logger.debug('Args: $args');
    } catch (e, stack) {
      _logger.error('Error extracting args', e, stack);
      return ActionResult.error('Error extracting args: $e');
    }
    
    // Resolve argument values
    final resolvedArgs = <String, dynamic>{};
    try {
      args.forEach((key, value) {
        resolvedArgs[key] = context.resolve(value);
      });
      _logger.debug('Resolved args: $resolvedArgs');
    } catch (e) {
      _logger.error('Error resolving args: $e');
      return ActionResult.error('Error resolving args: $e');
    }

    try {
      dynamic result;
      // If using default fallback handler, pass the tool name as first parameter
      if (_toolExecutors?[tool] == null && _toolExecutors?['default'] != null) {
        _logger.debug('Calling default tool executor with tool=$tool, args=$resolvedArgs');
        result = await toolExecutor(tool, resolvedArgs);
        _logger.debug('Default tool executor returned: $result');
      } else {
        _logger.debug('Calling specific tool executor with args=$resolvedArgs');
        result = await toolExecutor(resolvedArgs);
        _logger.debug('Specific tool executor returned: $result');
      }
      
      // Handle MCP-style response format
      if (result is Map<String, dynamic> && result.containsKey('success')) {
        final isSuccess = result['success'] as bool? ?? false;
        final resultData = result['result'];
        final message = result['message'] as String?;
        
        // Bind result if specified
        final bindResult = action['bindResult'] as String?;
        if (bindResult != null) {
          context.setValue(bindResult, resultData);
        }
        
        if (isSuccess) {
          return ActionResult.success(data: resultData);
        } else {
          final error = result['error'] as String? ?? message ?? 'Tool execution failed';
          return ActionResult.error(error);
        }
      } else {
        // Legacy format - treat any non-null result as success
        final bindResult = action['bindResult'] as String?;
        if (bindResult != null) {
          context.setValue(bindResult, result);
        }
        
        return ActionResult.success(data: result);
      }
    } catch (e) {
      _logger.error('Tool executor error: $e');
      return ActionResult.error(e.toString());
    }
  }
}

/// Executes navigation actions
class NavigationActionExecutor extends ActionExecutor {
  @override
  Future<ActionResult> execute(
    Map<String, dynamic> action,
    RenderContext context,
  ) async {
    // Navigation actions require a BuildContext, which would be available
    // through the widget tree. For now, we'll just return success without
    // actual navigation in this demo.
    // In a real implementation, the BuildContext would be passed through
    // the action execution context.

    final actionType = action['action'] as String? ?? 'push';
    final route = action['route'] as String?;
    final params = action['params'] as Map<String, dynamic>?;

    if (route == null) {
      return ActionResult.error('Route is required for navigation action');
    }

    // For demo purposes, just log the navigation action
    if (kDebugMode) {
      MCPLogger('NavigationActionExecutor').debug('Navigation action: $actionType to $route with params: $params');
    }
    
    // TODO: Implement actual navigation using NavigationService
    // context.navigationService.navigate(actionType, route, params);
    
    return ActionResult.success();
  }
}

/// Executes state actions
class StateActionExecutor extends ActionExecutor {
  @override
  Future<ActionResult> execute(
    Map<String, dynamic> action,
    RenderContext context,
  ) async {
    final actionType = action['action'] as String? ?? 'set';
    final binding = action['binding'] as String? ?? action['path'] as String?;
    
    if (binding == null) {
      throw Exception('Binding or path is required for state action');
    }

    try {
      switch (actionType) {
        case 'set':
          final value = context.resolve(action['value']);
          context.setValue(binding, value);
          break;

        case 'increment':
          final amount = action['value'] as num? ?? 1;
          final current = context.getValue(binding) as num? ?? 0;
          context.setValue(binding, current + amount);
          break;

        case 'decrement':
          final amount = action['value'] as num? ?? 1;
          final current = context.getValue(binding) as num? ?? 0;
          context.setValue(binding, current - amount);
          break;

        case 'toggle':
          final current = context.getValue(binding) as bool? ?? false;
          context.setValue(binding, !current);
          break;

        case 'append':
          final value = context.resolve(action['value']);
          final current = context.getValue(binding) as List? ?? [];
          if (value is List) {
            context.setValue(binding, [...current, ...value]);
          } else {
            context.setValue(binding, [...current, value]);
          }
          break;

        case 'remove':
          final value = context.resolve(action['value']);
          final current = context.getValue(binding) as List? ?? [];
          final newList = List.from(current);
          final index = newList.indexOf(value);
          if (index != -1) {
            newList.removeAt(index);
          }
          context.setValue(binding, newList);
          break;

        case 'removeAt':
          final index = action['value'] as int?;
          if (index == null) {
            return ActionResult.error('Index is required for removeAt action');
          }
          final current = context.getValue(binding) as List? ?? [];
          if (index >= 0 && index < current.length) {
            final newList = List.from(current);
            newList.removeAt(index);
            context.setValue(binding, newList);
          }
          break;

        default:
          return ActionResult.error('Unknown state action: $actionType');
      }

      return ActionResult.success();
    } catch (e) {
      return ActionResult.error(e.toString());
    }
  }
}

/// Executes resource actions
class ResourceActionExecutor extends ActionExecutor {
  static final _logger = MCPLogger('ResourceActionExecutor');
  
  @override
  Future<ActionResult> execute(
    Map<String, dynamic> action,
    RenderContext context,
  ) async {
    final actionType = action['action'] as String?;
    final uri = action['uri'] as String?;
    
    _logger.debug('ResourceActionExecutor called with action: $actionType, uri: $uri');
    
    if (actionType == null) {
      return ActionResult.error('Action is required for resource action');
    }
    
    if (uri == null) {
      return ActionResult.error('URI is required for resource action');
    }
    
    try {
      switch (actionType) {
        case 'subscribe':
          final binding = action['binding'] as String?;
          if (binding == null) {
            return ActionResult.error('Binding is required for subscribe action');
          }
          
          // Register the subscription in the runtime engine
          if (context.engine != null) {
            context.engine.registerResourceSubscription(uri, binding);
          }
          
          // Call the resource subscribe handler
          _logger.debug('Checking onResourceSubscribe handler: ${context.onResourceSubscribe != null}');
          if (context.onResourceSubscribe != null) {
            _logger.debug('Calling onResourceSubscribe handler for $uri -> $binding');
            await context.onResourceSubscribe!(uri, binding);
            _logger.debug('onResourceSubscribe handler completed');
          } else {
            _logger.warning('No resource subscribe handler configured');
          }
          break;
          
        case 'unsubscribe':
          _logger.debug('Processing unsubscribe for URI: $uri');
          
          // Unregister the subscription in the runtime engine
          if (context.engine != null) {
            context.engine.unregisterResourceSubscription(uri);
          }
          
          // Call the resource unsubscribe handler
          _logger.debug('Checking onResourceUnsubscribe handler: ${context.onResourceUnsubscribe != null}');
          if (context.onResourceUnsubscribe != null) {
            _logger.debug('Calling onResourceUnsubscribe handler for $uri');
            await context.onResourceUnsubscribe!(uri);
            _logger.debug('onResourceUnsubscribe handler completed');
          } else {
            _logger.warning('No resource unsubscribe handler configured');
          }
          break;
          
        default:
          return ActionResult.error('Unknown resource action: $actionType');
      }
      
      return ActionResult.success();
    } catch (e) {
      return ActionResult.error(e.toString());
    }
  }
}

/// Executes batch actions
class BatchActionExecutor extends ActionExecutor {
  ActionHandler? _actionHandler;

  @override
  Future<ActionResult> execute(
    Map<String, dynamic> action,
    RenderContext context,
  ) async {
    if (_actionHandler == null) {
      return ActionResult.error('Action handler not configured');
    }

    final actions = action['actions'] as List<dynamic>?;
    if (actions == null || actions.isEmpty) {
      return ActionResult.error('Actions list is required for batch');
    }

    final parallel = action['parallel'] as bool? ?? false;
    final stopOnError = action['stopOnError'] as bool? ?? true;

    try {
      if (parallel) {
        // Execute all actions in parallel
        final futures = actions.map((a) => 
          _actionHandler!.execute(a as Map<String, dynamic>, context)
        ).toList();
        
        final results = await Future.wait(futures);
        
        // Check if any failed
        final failed = results.any((r) => !r.success);
        if (failed && stopOnError) {
          return ActionResult.error('One or more actions failed');
        }
      } else {
        // Execute actions sequentially
        for (final a in actions) {
          final result = await _actionHandler!.execute(
            a as Map<String, dynamic>,
            context,
          );
          
          if (!result.success && stopOnError) {
            return result;
          }
        }
      }

      return ActionResult.success();
    } catch (e) {
      return ActionResult.error(e.toString());
    }
  }
}

/// Executes conditional actions
class ConditionalActionExecutor extends ActionExecutor {
  ActionHandler? _actionHandler;

  @override
  Future<ActionResult> execute(
    Map<String, dynamic> action,
    RenderContext context,
  ) async {
    if (_actionHandler == null) {
      return ActionResult.error('Action handler not configured');
    }

    final condition = action['condition'] as String?;
    if (condition == null) {
      return ActionResult.error('Condition is required for conditional action');
    }

    try {
      // Evaluate condition
      final conditionResult = context.resolve<bool>(condition);
      
      if (conditionResult) {
        final thenAction = action['then'] as Map<String, dynamic>?;
        if (thenAction != null) {
          return await _actionHandler!.execute(thenAction, context);
        }
      } else {
        final elseAction = action['else'] as Map<String, dynamic>?;
        if (elseAction != null) {
          return await _actionHandler!.execute(elseAction, context);
        }
      }

      return ActionResult.success();
    } catch (e) {
      return ActionResult.error(e.toString());
    }
  }
}

/// Executes test actions for UI testing scenarios
class TestActionExecutor extends ActionExecutor {
  @override
  Future<ActionResult> execute(
    Map<String, dynamic> action,
    RenderContext context,
  ) async {
    // For test purposes, just return success
    // In a real application, these would be actual implementations
    return ActionResult.success();
  }
}