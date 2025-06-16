import 'package:flutter/foundation.dart';

/// Enumeration of lifecycle events supported by the runtime
enum LifecycleEvent {
  initialize,
  ready,
  pause,
  resume,
  destroy,
  mount,
  unmount,
}

/// Manages component and runtime lifecycle events
class LifecycleManager {
  LifecycleManager({
    this.enableDebugMode = kDebugMode,
  });

  final bool enableDebugMode;
  final Map<LifecycleEvent, List<Function>> _eventListeners = {};

  /// Registers a listener for a specific lifecycle event
  void addListener(LifecycleEvent event, Function listener) {
    _eventListeners.putIfAbsent(event, () => []).add(listener);
    
    if (enableDebugMode) {
      debugPrint('LifecycleManager: Added listener for ${event.name}');
    }
  }

  /// Removes a listener for a specific lifecycle event
  void removeListener(LifecycleEvent event, Function listener) {
    _eventListeners[event]?.remove(listener);
    
    if (enableDebugMode) {
      debugPrint('LifecycleManager: Removed listener for ${event.name}');
    }
  }

  /// Executes lifecycle hooks defined in the runtime configuration
  Future<void> executeLifecycleHooks(
    LifecycleEvent event,
    List<dynamic> hooks,
  ) async {
    if (enableDebugMode) {
      debugPrint('LifecycleManager: Executing ${hooks.length} hooks for ${event.name}');
    }

    // Execute registered listeners first
    final listeners = _eventListeners[event];
    if (listeners != null) {
      for (final listener in listeners) {
        try {
          if (listener is Future<void> Function()) {
            await listener();
          } else if (listener is void Function()) {
            listener();
          }
        } catch (error) {
          if (enableDebugMode) {
            debugPrint('LifecycleManager: Error in listener for ${event.name}: $error');
          }
        }
      }
    }

    // Execute hooks from configuration
    for (final hook in hooks) {
      try {
        await _executeHook(event, hook);
      } catch (error) {
        if (enableDebugMode) {
          debugPrint('LifecycleManager: Error executing hook for ${event.name}: $error');
        }
        // Continue with other hooks even if one fails
      }
    }

    if (enableDebugMode) {
      debugPrint('LifecycleManager: Completed hooks for ${event.name}');
    }
  }

  /// Triggers a lifecycle event and executes associated hooks
  Future<void> triggerEvent(LifecycleEvent event, [dynamic data]) async {
    if (enableDebugMode) {
      debugPrint('LifecycleManager: Triggering ${event.name}');
    }

    // Execute registered listeners
    final listeners = _eventListeners[event];
    if (listeners != null) {
      for (final listener in listeners) {
        try {
          if (listener is Future<void> Function(dynamic)) {
            await listener(data);
          } else if (listener is void Function(dynamic)) {
            listener(data);
          } else if (listener is Future<void> Function()) {
            await listener();
          } else if (listener is void Function()) {
            listener();
          }
        } catch (error) {
          if (enableDebugMode) {
            debugPrint('LifecycleManager: Error in listener for ${event.name}: $error');
          }
        }
      }
    }
  }

  /// Executes a single lifecycle hook
  Future<void> _executeHook(LifecycleEvent event, dynamic hook) async {
    if (hook is! Map<String, dynamic>) {
      if (enableDebugMode) {
        debugPrint('LifecycleManager: Invalid hook format for ${event.name}');
      }
      return;
    }

    final hookMap = hook;
    final actionType = hookMap['type'] as String?;

    if (actionType == null) {
      if (enableDebugMode) {
        debugPrint('LifecycleManager: Hook missing type for ${event.name}');
      }
      return;
    }

    // Use ActionHandler to execute the hook
    // Note: This would need to be injected or accessed differently
    // For now, we'll create a placeholder implementation
    switch (actionType) {
      case 'state':
        await _executeStateHook(hookMap);
        break;
      case 'tool':
        await _executeToolHook(hookMap);
        break;
      case 'service':
        await _executeServiceHook(hookMap);
        break;
      case 'notification':
        await _executeNotificationHook(hookMap);
        break;
      default:
        if (enableDebugMode) {
          debugPrint('LifecycleManager: Unknown hook type: $actionType');
        }
        break;
    }
  }

  /// Executes a state-related lifecycle hook
  Future<void> _executeStateHook(Map<String, dynamic> hook) async {
    // Placeholder implementation
    // This would interact with the StateService
    if (enableDebugMode) {
      debugPrint('LifecycleManager: Executing state hook: ${hook['action']}');
    }
  }

  /// Executes a tool-related lifecycle hook
  Future<void> _executeToolHook(Map<String, dynamic> hook) async {
    // Placeholder implementation
    // This would interact with the tool executor
    if (enableDebugMode) {
      debugPrint('LifecycleManager: Executing tool hook: ${hook['tool']}');
    }
  }

  /// Executes a service-related lifecycle hook
  Future<void> _executeServiceHook(Map<String, dynamic> hook) async {
    // Placeholder implementation
    // This would interact with the ServiceRegistry
    if (enableDebugMode) {
      debugPrint('LifecycleManager: Executing service hook: ${hook['service']}');
    }
  }

  /// Executes a notification-related lifecycle hook
  Future<void> _executeNotificationHook(Map<String, dynamic> hook) async {
    // Placeholder implementation
    // This would interact with the NotificationManager
    if (enableDebugMode) {
      debugPrint('LifecycleManager: Executing notification hook: ${hook['action']}');
    }
  }

  /// Creates a component lifecycle handler
  ComponentLifecycleHandler createComponentHandler(String componentId) {
    return ComponentLifecycleHandler(
      componentId: componentId,
      lifecycleManager: this,
      enableDebugMode: enableDebugMode,
    );
  }

  /// Disposes of the lifecycle manager and cleans up resources
  void dispose() {
    _eventListeners.clear();
    
    if (enableDebugMode) {
      debugPrint('LifecycleManager: Disposed');
    }
  }
}

/// Handles lifecycle events for individual components
class ComponentLifecycleHandler {
  ComponentLifecycleHandler({
    required this.componentId,
    required this.lifecycleManager,
    this.enableDebugMode = kDebugMode,
  });

  final String componentId;
  final LifecycleManager lifecycleManager;
  final bool enableDebugMode;

  bool _isMounted = false;
  Map<String, dynamic>? _lifecycleConfig;

  /// Gets whether the component is currently mounted
  bool get isMounted => _isMounted;

  /// Sets the lifecycle configuration for this component
  void setLifecycleConfig(Map<String, dynamic>? config) {
    _lifecycleConfig = config;
  }

  /// Handles component mount event
  Future<void> mount() async {
    if (_isMounted) return;

    _isMounted = true;
    
    if (enableDebugMode) {
      debugPrint('ComponentLifecycleHandler: Component $componentId mounted');
    }

    // Execute onMount hooks if defined
    final onMountHooks = _lifecycleConfig?['onMount'] as List<dynamic>?;
    if (onMountHooks != null) {
      await lifecycleManager.executeLifecycleHooks(
        LifecycleEvent.mount,
        onMountHooks,
      );
    }

    // Trigger global mount event
    await lifecycleManager.triggerEvent(LifecycleEvent.mount, componentId);
  }

  /// Handles component unmount event
  Future<void> unmount() async {
    if (!_isMounted) return;

    if (enableDebugMode) {
      debugPrint('ComponentLifecycleHandler: Component $componentId unmounting');
    }

    // Execute onUnmount hooks if defined
    final onUnmountHooks = _lifecycleConfig?['onUnmount'] as List<dynamic>?;
    if (onUnmountHooks != null) {
      await lifecycleManager.executeLifecycleHooks(
        LifecycleEvent.unmount,
        onUnmountHooks,
      );
    }

    // Trigger global unmount event
    await lifecycleManager.triggerEvent(LifecycleEvent.unmount, componentId);

    _isMounted = false;
    
    if (enableDebugMode) {
      debugPrint('ComponentLifecycleHandler: Component $componentId unmounted');
    }
  }
}