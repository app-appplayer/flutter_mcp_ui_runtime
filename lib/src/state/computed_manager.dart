import 'dart:async';
import '../state/state_manager.dart';
import '../binding/binding_engine.dart';
import '../renderer/render_context.dart';
import '../utils/mcp_logger.dart';

/// Configuration for computed property
class ComputedConfig {
  final String expression;
  final List<String> dependencies;

  ComputedConfig({
    required this.expression,
    required this.dependencies,
  });
}

/// Configuration for watcher
class WatcherConfig {
  final Function(dynamic value, dynamic oldValue) handler;
  final bool immediate;
  final bool deep;

  WatcherConfig({
    required this.handler,
    this.immediate = false,
    this.deep = false,
  });
}

/// Computed property implementation
class ComputedProperty {
  final String key;
  final String expression;
  final List<String> dependencies;
  final StateManager stateManager;
  final BindingEngine bindingEngine;

  dynamic _cachedValue;
  bool _isDirty = true;

  ComputedProperty({
    required this.key,
    required this.expression,
    required this.dependencies,
    required this.stateManager,
    required this.bindingEngine,
  });

  dynamic get value {
    if (_isDirty) {
      _recompute();
    }
    return _cachedValue;
  }

  void invalidate() {
    _isDirty = true;
  }

  void _recompute() {
    // Create a simple context for evaluation
    final context = SimpleComputedContext(stateManager);
    _cachedValue = bindingEngine.resolve(expression, context);
    _isDirty = false;
  }
}

/// Watcher implementation
class Watcher {
  final String path;
  final Function(dynamic value, dynamic oldValue) handler;
  final bool immediate;
  final bool deep;
  dynamic _lastValue;

  Watcher({
    required this.path,
    required this.handler,
    this.immediate = false,
    this.deep = false,
  });

  void update(dynamic newValue) {
    if (_hasChanged(newValue, _lastValue)) {
      final oldValue = _lastValue;
      _lastValue = _cloneValue(newValue);
      handler(newValue, oldValue);
    }
  }

  bool _hasChanged(dynamic newValue, dynamic oldValue) {
    if (deep) {
      // Deep comparison for objects and arrays
      return !_deepEquals(newValue, oldValue);
    }
    return newValue != oldValue;
  }

  bool _deepEquals(dynamic a, dynamic b) {
    if (a == b) return true;
    if (a.runtimeType != b.runtimeType) return false;

    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) {
          return false;
        }
      }
      return true;
    }

    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }

    return false;
  }

  dynamic _cloneValue(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    if (value is List) {
      return List.from(value);
    }
    return value;
  }
}

/// Manager for computed properties and watchers
class ComputedManager {
  final Map<String, ComputedProperty> _computedProperties = {};
  final Map<String, List<Watcher>> _watchers = {};
  final StateManager _stateManager;
  final BindingEngine _bindingEngine;
  final Map<String, StreamSubscription> _subscriptions = {};
  final MCPLogger _logger = MCPLogger('ComputedManager');

  ComputedManager({
    required StateManager stateManager,
    required BindingEngine bindingEngine,
  })  : _stateManager = stateManager,
        _bindingEngine = bindingEngine;

  /// Register a computed property
  void registerComputed(String key, ComputedConfig config) {
    final computed = ComputedProperty(
      key: key,
      expression: config.expression,
      dependencies: config.dependencies,
      stateManager: _stateManager,
      bindingEngine: _bindingEngine,
    );

    _computedProperties[key] = computed;

    // Listen to dependencies
    for (final _ in config.dependencies) {
      _stateManager.addListener(() {
        computed.invalidate();
        _notifyWatchers(key);
      });
    }

    _logger.debug(
        'Registered computed property: $key with dependencies: ${config.dependencies}');
  }

  /// Register a watcher
  void registerWatcher(String path, WatcherConfig config) {
    final watcher = Watcher(
      path: path,
      handler: config.handler,
      immediate: config.immediate,
      deep: config.deep,
    );

    _watchers[path] ??= [];
    _watchers[path]!.add(watcher);

    // Listen to changes
    _stateManager.addListener(() {
      final value = _getValue(path);
      watcher.update(value);
    });

    if (watcher.immediate) {
      final value = _getValue(path);
      watcher._lastValue = watcher._cloneValue(value);
      watcher.handler(value, null);
    }

    _logger.debug(
        'Registered watcher for: $path (immediate: ${config.immediate}, deep: ${config.deep})');
  }

  /// Get computed property value
  dynamic getComputed(String key) {
    return _computedProperties[key]?.value;
  }

  /// Get value (either computed or from state)
  dynamic _getValue(String path) {
    // Check if it's a computed property
    if (_computedProperties.containsKey(path)) {
      return _computedProperties[path]!.value;
    }

    // Otherwise get from state
    return _stateManager.get(path);
  }

  /// Notify watchers of a change
  void _notifyWatchers(String path) {
    final watchers = _watchers[path];
    if (watchers != null) {
      final value = _getValue(path);
      for (final watcher in watchers) {
        watcher.update(value);
      }
    }
  }

  /// Dispose of all resources
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _computedProperties.clear();
    _watchers.clear();
  }
}

/// Simple context for computed property evaluation
class SimpleComputedContext implements RenderContext {
  final StateManager _stateManager;

  SimpleComputedContext(this._stateManager);

  @override
  T getValue<T>(String path) {
    return _stateManager.get(path) as T;
  }

  @override
  T resolve<T>(dynamic value) {
    // For computed properties, we only need basic resolution
    if (value is T) return value;
    if (T == String) return value?.toString() as T;
    return value as T;
  }

  // These are not used in computed property evaluation
  @override
  T? getState<T>(String path) => getValue(path) as T?;

  @override
  void setValue(String path, dynamic value) {
    _stateManager.set(path, value);
  }

  @override
  void setState(String path, dynamic value) {
    setValue(path, value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
