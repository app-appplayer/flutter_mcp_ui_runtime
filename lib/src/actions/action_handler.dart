import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../renderer/render_context.dart';
import '../utils/mcp_logger.dart';
import '../services/dialog_service.dart';
import '../services/navigation_service.dart';
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
    toolExecutor._toolExecutors =
        _toolExecutors; // Connect the tool executors map
    _executors['tool'] = toolExecutor;
    _executors['navigation'] = NavigationActionExecutor();
    _executors['state'] = StateActionExecutor();
    _executors['resource'] = ResourceActionExecutor();
    _executors['dialog'] = DialogActionExecutor();

    final batchExecutor = BatchActionExecutor();
    batchExecutor._actionHandler = this; // Connect the action handler
    _executors['batch'] = batchExecutor;

    final conditionalExecutor = ConditionalActionExecutor();
    conditionalExecutor._actionHandler = this; // Connect the action handler
    _executors['conditional'] = conditionalExecutor;
    _executors['addRandomWidget'] = TestActionExecutor();
    _executors['deleteRandomWidget'] = TestActionExecutor();
    _executors['shuffleWidgets'] = TestActionExecutor();
    _executors['clearWidgets'] = TestActionExecutor();
    _executors['addHeavyWidget'] = TestActionExecutor();
    _executors['increment'] =
        StateActionExecutor(); // Alias for state increment
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
      _logger.error(
          'Unknown action type: $type - Available: ${_executors.keys.toList()}');
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

      _logger.debug(
          'About to execute action with executor: ${executor.runtimeType}');
      final result = await executor.execute(action, context);
      _logger.debug(
          'Executor returned result: ${result.success} - ${result.data}');

      // Handle success/error callbacks
      if (result.success) {
        final onSuccess = action['onSuccess'] as Map<String, dynamic>?;
        if (onSuccess != null) {
          // Create a child context with the response data
          final successContext = context.createChildContext(
            variables: {
              'response': result.data,
            },
          );
          await execute(onSuccess, successContext);
        }
      } else {
        final onError = action['onError'] as Map<String, dynamic>?;
        if (onError != null) {
          // Create a child context with the error message
          final errorContext = context.createChildContext(
            variables: {
              'error': result.data ?? 'Unknown error',
            },
          );
          await execute(onError, errorContext);
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

  /// Register navigation handler globally
  void registerNavigationHandler(
      bool Function(String action, String route, Map<String, dynamic> params)
          handler) {
    _logger.info('ActionHandler: Registering navigation handler');
    NavigationActionExecutor.setGlobalNavigationHandler(handler);
    _logger.info('ActionHandler: Navigation handler registered');
  }
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
      _logger.error(
          'Tool executor not found: $tool, available: ${_toolExecutors?.keys}');
      return ActionResult.error('Tool executor not found: $tool');
    }

    _logger.debug('Found tool executor for: $tool');
    _logger.debug('About to extract params from action');

    // 하위호환성 제거: args를 사용할 경우 오류 발생
    if (action.containsKey('args')) {
      throw ArgumentError(
          'Use "params" instead of deprecated "args" for tool actions');
    }

    Map<String, dynamic> params;
    try {
      // MCP UI DSL v1.0은 항상 'params' 사용
      final rawParams = action['params'];
      if (rawParams == null) {
        params = {};
      } else if (rawParams is Map<String, dynamic>) {
        params = rawParams;
      } else if (rawParams is Map) {
        // Convert Map<dynamic, dynamic> to Map<String, dynamic>
        params = Map<String, dynamic>.from(rawParams);
      } else {
        params = {};
      }
      _logger.debug('Successfully extracted params');
      _logger.debug('Params: $params');
    } catch (e, stack) {
      _logger.error('Error extracting params', e, stack);
      return ActionResult.error('Error extracting params: $e');
    }

    // Resolve parameter values
    final resolvedParams = <String, dynamic>{};
    try {
      params.forEach((key, value) {
        resolvedParams[key] = context.resolve(value);
      });
      _logger.debug('Resolved params: $resolvedParams');
    } catch (e) {
      _logger.error('Error resolving params: $e');
      return ActionResult.error('Error resolving params: $e');
    }

    try {
      dynamic result;
      // If using default fallback handler, pass the tool name as first parameter
      if (_toolExecutors?[tool] == null && _toolExecutors?['default'] != null) {
        _logger.debug(
            'Calling default tool executor with tool=$tool, params=$resolvedParams');
        result = await toolExecutor(tool, resolvedParams);
        _logger.debug('Default tool executor returned: $result');
      } else {
        _logger.debug(
            'Calling specific tool executor with params=$resolvedParams');
        result = await toolExecutor(resolvedParams);
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
          final error =
              result['error'] as String? ?? message ?? 'Tool execution failed';
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
///
/// This executor handles navigation actions from UI components like buttons.
/// It supports three levels of navigation handlers:
/// 1. Context-specific handler (highest priority)
/// 2. Renderer-specific handler
/// 3. Global handler (lowest priority, used by ApplicationShell)
///
/// When used with ApplicationShell, the global handler converts route-based
/// navigation to index-based navigation for drawer/tab/bottom navigation.
class NavigationActionExecutor extends ActionExecutor {
  static bool Function(
          String action, String route, Map<String, dynamic> params)?
      _globalNavigationHandler;

  // Get navigator key from NavigationService
  static GlobalKey<NavigatorState> get navigatorKey =>
      NavigationService().navigatorKey;

  /// Sets the global navigation handler
  /// This is typically used by ApplicationShell to handle navigation
  /// from buttons and other UI components
  static void setGlobalNavigationHandler(
      bool Function(String action, String route, Map<String, dynamic> params)?
          handler) {
    MCPLogger('NavigationActionExecutor')
        .info('Setting global navigation handler: ${handler != null}');
    _globalNavigationHandler = handler;
    MCPLogger('NavigationActionExecutor')
        .info('Global handler is now: ${_globalNavigationHandler != null}');
  }

  static void clearGlobalNavigationHandler() {
    _globalNavigationHandler = null;
  }

  @override
  Future<ActionResult> execute(
    Map<String, dynamic> action,
    RenderContext context,
  ) async {
    final actionType = action['action'] as String? ?? 'push';
    final route = action['route'] as String?;
    final params = action['params'] as Map<String, dynamic>?;

    // Route is only required for push and replace actions
    if (route == null && ['push', 'replace'].contains(actionType)) {
      return ActionResult.error(
          'Route is required for $actionType navigation action');
    }

    // For demo purposes, just log the navigation action
    if (kDebugMode) {
      MCPLogger('NavigationActionExecutor').debug(
          'Navigation action: $actionType to $route with params: $params');
    }

    // First try custom navigation handlers
    var handler = context.navigationHandler;
    MCPLogger('NavigationActionExecutor')
        .debug('Context handler: ${handler != null}');
    if (handler == null && context.renderer.navigationHandler != null) {
      handler = context.renderer.navigationHandler;
      MCPLogger('NavigationActionExecutor')
          .debug('Using renderer handler: ${handler != null}');
    }
    if (handler == null) {
      handler = _globalNavigationHandler;
      MCPLogger('NavigationActionExecutor')
          .debug('Using global handler: ${handler != null}');
    }

    // If custom handler is available, use it
    if (handler != null) {
      final handled = handler(actionType, route ?? '', params ?? {});
      if (!handled) {
        return ActionResult.error('Navigation handler rejected the navigation');
      }
      return ActionResult.success();
    }

    // Otherwise, use the global navigator key for actual navigation
    MCPLogger('NavigationActionExecutor')
        .debug('Getting navigatorKey from NavigationService');
    MCPLogger('NavigationActionExecutor').debug('NavigatorKey: $navigatorKey');
    MCPLogger('NavigationActionExecutor')
        .debug('NavigatorKey hashCode: ${navigatorKey.hashCode}');

    final navigatorState = navigatorKey.currentState;
    MCPLogger('NavigationActionExecutor')
        .debug('Navigator currentState: $navigatorState');

    if (navigatorState == null) {
      MCPLogger('NavigationActionExecutor')
          .debug('Navigator state is null - navigation not possible');
      MCPLogger('NavigationActionExecutor')
          .debug('NavigationService instance: ${NavigationService.instance}');
      MCPLogger('NavigationActionExecutor').debug(
          'NavigationService navigatorKey: ${NavigationService.instance.navigatorKey}');
      MCPLogger('NavigationActionExecutor').debug(
          'NavigationService navigatorKey hashCode: ${NavigationService.instance.navigatorKey.hashCode}');
      return ActionResult.success(); // Return success to avoid breaking the app
    }

    try {
      switch (actionType) {
        case 'push':
          await navigatorState.pushNamed(route!, arguments: params);
          break;
        case 'replace':
          await navigatorState.pushReplacementNamed(route!, arguments: params);
          break;
        case 'pop':
          navigatorState.pop(params);
          break;
        case 'popToRoot':
          navigatorState.popUntil((route) => route.isFirst);
          break;
        default:
          return ActionResult.error('Unknown navigation action: $actionType');
      }

      MCPLogger('NavigationActionExecutor')
          .debug('Navigation completed: $actionType to $route');
      return ActionResult.success();
    } catch (e) {
      MCPLogger('NavigationActionExecutor').error('Navigation error: $e');
      return ActionResult.error('Navigation failed: $e');
    }
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
          // Support both value-based and index-based removal
          final index = context.resolve(action['index']);
          if (index != null) {
            // Index-based removal
            final indexNum =
                index is int ? index : int.tryParse(index.toString());
            if (indexNum != null) {
              final current = context.getValue(binding) as List? ?? [];
              if (indexNum >= 0 && indexNum < current.length) {
                final newList = List.from(current);
                newList.removeAt(indexNum);
                context.setValue(binding, newList);
              }
            }
          } else {
            // Value-based removal
            final value = context.resolve(action['value']);
            final current = context.getValue(binding) as List? ?? [];
            final newList = List.from(current);
            final removeIndex = newList.indexOf(value);
            if (removeIndex != -1) {
              newList.removeAt(removeIndex);
            }
            context.setValue(binding, newList);
          }
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
    // Check if this is an HTTP-style resource action
    final method = action['method'] as String?;
    final target = action['target'] as String?;
    final resourceName = action['resource'] as String?;

    if (method != null && target != null) {
      // HTTP-style resource action
      _logger.debug('HTTP-style resource action: $method $target');

      // Call resource handler if available
      if (context.resourceHandler != null) {
        final data = action['data'];
        final result = await context.resourceHandler!(
            resourceName ?? 'default', method, target, data);

        // Bind result if specified
        final bindResult = action['bindResult'] as String?;
        if (bindResult != null) {
          context.setValue(bindResult, result);
        }

        return ActionResult.success(data: result);
      } else {
        return ActionResult.error('No resource handler configured');
      }
    }

    // Otherwise, handle subscription-style resource actions
    final actionType = action['action'] as String?;
    final uri = action['uri'] as String?;

    _logger.debug(
        'ResourceActionExecutor called with action: $actionType, uri: $uri');

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
            return ActionResult.error(
                'Binding is required for subscribe action');
          }

          // Register the subscription in the runtime engine
          if (context.engine != null) {
            context.engine.registerResourceSubscription(uri, binding);
          }

          // Call the resource subscribe handler
          _logger.debug(
              'Checking onResourceSubscribe handler: ${context.onResourceSubscribe != null}');
          if (context.onResourceSubscribe != null) {
            _logger.debug(
                'Calling onResourceSubscribe handler for $uri -> $binding');
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
          _logger.debug(
              'Checking onResourceUnsubscribe handler: ${context.onResourceUnsubscribe != null}');
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
        final futures = actions
            .map((a) =>
                _actionHandler!.execute(a as Map<String, dynamic>, context))
            .toList();

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

/// Executes dialog actions
class DialogActionExecutor extends ActionExecutor {
  static final _logger = MCPLogger('DialogActionExecutor');
  static final _dialogService = DialogService();

  @override
  Future<ActionResult> execute(
    Map<String, dynamic> action,
    RenderContext context,
  ) async {
    final dialog = action['dialog'] as Map<String, dynamic>?;

    if (dialog == null) {
      return ActionResult.error('Dialog configuration is required');
    }

    final dialogType = dialog['type'] as String? ?? 'alert';
    final title = context.resolve(dialog['title']) as String?;
    final content = context.resolve(dialog['content']) as String?;
    final dismissible = dialog['dismissible'] as bool? ?? true;
    final actions = dialog['actions'] as List<dynamic>?;

    try {
      bool? result;

      switch (dialogType) {
        case 'alert':
          // Convert actions to DialogAction objects
          final dialogActions = actions?.map((actionDef) {
            final label = actionDef['label'] as String? ?? '';
            final action = actionDef['action'];
            final primary = actionDef['primary'] as bool? ?? false;

            return DialogAction(
              text: label,
              onPressed: () async {
                // Get the current context from DialogService
                final navigatorContext =
                    DialogService.navigatorKey.currentContext;
                if (navigatorContext == null) return;

                // Handle special 'close' action
                if (action == 'close') {
                  // Just close the dialog
                  Navigator.of(navigatorContext).pop();
                } else if (action is Map<String, dynamic>) {
                  // Execute the action first
                  await context.actionHandler.execute(action, context);
                  // Then close the dialog (standard behavior)
                  if (navigatorContext.mounted) {
                    Navigator.of(navigatorContext).pop();
                  }
                }
              },
              isDefault: primary,
            );
          }).toList();

          await _dialogService.show(
            content: Text(content ?? ''),
            title: title,
            actions: dialogActions,
            barrierDismissible: dismissible,
            type: DialogType.alert,
          );
          result = true;
          break;

        case 'simple':
          // For simple dialog, use showAlert for now
          await _dialogService.showAlert(
            message: content ?? '',
            title: title,
          );
          result = true;
          break;

        case 'bottomSheet':
          final child = dialog['child'] as Map<String, dynamic>?;
          if (child != null) {
            result = await _dialogService.showBottomSheet<bool>(
              content: context.renderer.renderWidget(child, context),
              isDismissible: dismissible,
              enableDrag: dialog['enableDrag'] as bool? ?? true,
              backgroundColor: dialog['backgroundColor'] != null
                  ? _parseColor(dialog['backgroundColor'] as String)
                  : null,
            );
          }
          break;

        case 'custom':
          final child = dialog['child'] as Map<String, dynamic>?;
          if (child != null) {
            result = await _dialogService.show<bool>(
              content: context.renderer.renderWidget(child, context),
              title: title,
              barrierDismissible: dismissible,
              type: DialogType.custom,
            );
          }
          break;

        default:
          return ActionResult.error('Unknown dialog type: $dialogType');
      }

      // Handle onDismiss action if dialog was dismissed
      if (result == null && action['onDismiss'] != null) {
        final onDismiss = action['onDismiss'] as Map<String, dynamic>;
        await context.actionHandler.execute(onDismiss, context);
      }

      return ActionResult.success(data: result);
    } catch (e) {
      _logger.error('Error showing dialog: $e');
      return ActionResult.error(e.toString());
    }
  }

  Color? _parseColor(String colorString) {
    if (colorString.startsWith('#')) {
      return Color(int.parse(colorString.substring(1), radix: 16));
    }
    return null;
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
