import 'package:flutter/foundation.dart';
import '../runtime/service_registry.dart';
import '../state/state_watcher.dart';
import '../state/computed_property.dart';
import '../utils/json_path.dart';
import '../utils/mcp_logger.dart';

/// Enhanced state management service with watchers and computed properties
class StateService extends RuntimeService {
  StateService({super.enableDebugMode}) : _logger = MCPLogger('StateService', enableLogging: enableDebugMode);
  
  final MCPLogger _logger;

  Map<String, dynamic> _state = {};
  final Map<String, StateWatcher> _watchers = {};
  final Map<String, ComputedProperty> _computedProperties = {};
  final List<VoidCallback> _listeners = [];

  bool _persistenceEnabled = false;
  List<String> _persistencePaths = [];
  String _storageType = 'local';

  /// Gets the current state
  Map<String, dynamic> get state => Map<String, dynamic>.from(_state);

  /// Gets a value from the state at the specified path
  T? getValue<T>(String path) {
    try {
      return JsonPath.get(_state, path) as T?;
    } catch (error) {
      _logger.error('Error getting value at path "$path"', error);
      return null;
    }
  }

  /// Sets a value in the state at the specified path
  Future<void> setValue(String path, dynamic value) async {
    final oldValue = getValue(path);
    
    try {
      JsonPath.set(_state, path, value);
      
      _logger.debug('Set "$path" = $value');

      // Trigger watchers
      await _triggerWatchers(path, value, oldValue);
      
      // Update computed properties
      _updateComputedProperties();
      
      // Notify listeners
      _notifyListeners();
      
      // Persist if enabled
      if (_persistenceEnabled && _shouldPersist(path)) {
        await _persistState();
      }
    } catch (error) {
      _logger.error('Error setting value at path "$path"', error);
      rethrow;
    }
  }

  /// Increments a numeric value at the specified path
  Future<void> increment(String path, [num amount = 1]) async {
    final currentValue = getValue<num>(path) ?? 0;
    await setValue(path, currentValue + amount);
  }

  /// Decrements a numeric value at the specified path
  Future<void> decrement(String path, [num amount = 1]) async {
    final currentValue = getValue<num>(path) ?? 0;
    await setValue(path, currentValue - amount);
  }

  /// Toggles a boolean value at the specified path
  Future<void> toggle(String path) async {
    final currentValue = getValue<bool>(path) ?? false;
    await setValue(path, !currentValue);
  }

  /// Appends a value to an array at the specified path
  Future<void> append(String path, dynamic value) async {
    final currentList = getValue<List<dynamic>>(path) ?? [];
    final newList = [...currentList, value];
    await setValue(path, newList);
  }

  /// Removes a value from an array at the specified path
  Future<void> remove(String path, dynamic value) async {
    final currentList = getValue<List<dynamic>>(path) ?? [];
    final newList = currentList.where((item) => item != value).toList();
    await setValue(path, newList);
  }

  /// Removes an item at a specific index from an array
  Future<void> removeAt(String path, int index) async {
    final currentList = getValue<List<dynamic>>(path) ?? [];
    if (index >= 0 && index < currentList.length) {
      final newList = [...currentList];
      newList.removeAt(index);
      await setValue(path, newList);
    }
  }

  /// Clears the value at the specified path
  Future<void> clear(String path) async {
    await setValue(path, null);
  }

  /// Merges an object with the value at the specified path
  Future<void> merge(String path, Map<String, dynamic> values) async {
    final currentValue = getValue<Map<String, dynamic>>(path) ?? {};
    final mergedValue = {...currentValue, ...values};
    await setValue(path, mergedValue);
  }

  /// Alias for merge - merges an object with the value at the specified path
  Future<void> mergeValue(String path, Map<String, dynamic> values) async {
    await merge(path, values);
  }

  /// Alias for append - appends a value to an array at the specified path
  Future<void> appendValue(String path, dynamic value) async {
    await append(path, value);
  }

  /// Alias for remove - removes a value from an array at the specified path
  Future<void> removeValue(String path, dynamic value) async {
    await remove(path, value);
  }

  /// Alias for increment - increments a numeric value at the specified path
  Future<void> incrementValue(String path, [num amount = 1]) async {
    await increment(path, amount);
  }

  /// Alias for decrement - decrements a numeric value at the specified path
  Future<void> decrementValue(String path, [num amount = 1]) async {
    await decrement(path, amount);
  }

  /// Adds a state watcher for the specified path
  void addWatcher(String path, StateWatcher watcher) {
    _watchers[path] = watcher;
    
    if (enableDebugMode) {
      _logger.debug('Added watcher for path "$path"');
    }
  }

  /// Removes a state watcher for the specified path
  void removeWatcher(String path) {
    _watchers.remove(path);
    
    if (enableDebugMode) {
      _logger.debug('Removed watcher for path "$path"');
    }
  }

  /// Adds a computed property
  void addComputedProperty(String name, ComputedProperty property) {
    _computedProperties[name] = property;
    
    if (enableDebugMode) {
      _logger.debug('Added computed property "$name"');
    }
  }

  /// Gets a computed property value
  T? getComputedValue<T>(String name) {
    final property = _computedProperties[name];
    if (property != null) {
      return property.compute(_state) as T?;
    }
    return null;
  }

  /// Adds a state change listener
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// Removes a state change listener
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// Resets the state to its initial values
  Future<void> reset() async {
    if (enableDebugMode) {
      _logger.debug('Resetting state');
    }

    _state.clear();
    _notifyListeners();
  }

  /// Sets the entire state
  void setState(Map<String, dynamic> newState) {
    _state = Map<String, dynamic>.from(newState);
    _notifyListeners();
    
    if (enableDebugMode) {
      _logger.debug('State set with ${_state.length} keys');
    }
  }

  /// Persists the current state
  Future<void> persist() async {
    if (_persistenceEnabled) {
      await _persistState();
    }
  }

  /// Refreshes the state from persistent storage
  Future<void> refresh() async {
    if (_persistenceEnabled) {
      await _loadPersistedState();
    }
  }

  /// Cleans up resources
  Future<void> cleanup() async {
    _watchers.clear();
    _computedProperties.clear();
    _listeners.clear();
    
    if (enableDebugMode) {
      _logger.debug('Cleaned up resources');
    }
  }

  @override
  Future<void> onInitialize(Map<String, dynamic> config) async {
    // Initialize state
    _state = Map<String, dynamic>.from(config['initialState'] ?? {});

    // Setup persistence
    final persistenceConfig = config['persistence'] as Map<String, dynamic>?;
    if (persistenceConfig != null) {
      _persistenceEnabled = persistenceConfig['enabled'] as bool? ?? false;
      _persistencePaths = List<String>.from(persistenceConfig['paths'] ?? []);
      _storageType = persistenceConfig['storage'] as String? ?? 'local';
    }

    // Load persisted state
    if (_persistenceEnabled) {
      await _loadPersistedState();
    }

    // Setup watchers
    final watchersConfig = config['watchers'] as List<dynamic>?;
    if (watchersConfig != null) {
      for (final watcherConfig in watchersConfig) {
        if (watcherConfig is Map<String, dynamic>) {
          await _setupWatcher(watcherConfig);
        }
      }
    }

    // Setup computed properties
    final computedConfig = config['computed'] as Map<String, dynamic>?;
    if (computedConfig != null) {
      for (final entry in computedConfig.entries) {
        final property = ComputedProperty.fromExpression(
          entry.key,
          entry.value as String,
        );
        addComputedProperty(entry.key, property);
      }
    }

    if (enableDebugMode) {
      _logger.info('Initialized with ${_state.length} state keys');
    }
  }

  @override
  Future<void> onDispose() async {
    await cleanup();
  }

  /// Sets up a state watcher from configuration
  Future<void> _setupWatcher(Map<String, dynamic> config) async {
    final path = config['path'] as String?;
    final onChangeActions = config['onChange'] as List<dynamic>?;

    if (path != null && onChangeActions != null) {
      final watcher = StateWatcher(
        path: path,
        onChange: (value, oldValue) async {
          // Execute onChange actions
          // Note: This would need access to ActionHandler
          if (enableDebugMode) {
            _logger.debug('State changed at "$path": $oldValue -> $value');
          }
        },
      );

      addWatcher(path, watcher);
    }
  }

  /// Triggers watchers for a changed path
  Future<void> _triggerWatchers(String path, dynamic newValue, dynamic oldValue) async {
    // Check exact path match
    final exactWatcher = _watchers[path];
    if (exactWatcher != null) {
      await exactWatcher.trigger(newValue, oldValue);
    }

    // Check parent path watchers
    for (final entry in _watchers.entries) {
      final watcherPath = entry.key;
      final watcher = entry.value;

      if (path.startsWith('$watcherPath.') || watcherPath == '*') {
        await watcher.trigger(newValue, oldValue);
      }
    }
  }

  /// Updates all computed properties
  void _updateComputedProperties() {
    for (final entry in _computedProperties.entries) {
      try {
        final newValue = entry.value.compute(_state);
        // Store computed value in state with computed: prefix
        _state['computed:${entry.key}'] = newValue;
      } catch (error) {
        if (enableDebugMode) {
          _logger.error('Error computing property "${entry.key}"', error);
        }
      }
    }
  }

  /// Notifies all state change listeners
  void _notifyListeners() {
    for (final listener in _listeners) {
      try {
        listener();
      } catch (error) {
        if (enableDebugMode) {
          _logger.error('Error in state listener', error);
        }
      }
    }
  }

  /// Checks if a path should be persisted
  bool _shouldPersist(String path) {
    if (_persistencePaths.isEmpty) return true;
    
    return _persistencePaths.any((persistPath) => 
      path.startsWith(persistPath) || persistPath == '*');
  }

  /// Persists the current state to storage
  Future<void> _persistState() async {
    try {
      // Get data to persist
      final dataToPersist = <String, dynamic>{};
      
      if (_persistencePaths.isEmpty) {
        dataToPersist.addAll(_state);
      } else {
        for (final path in _persistencePaths) {
          if (path == '*') {
            dataToPersist.addAll(_state);
            break;
          } else {
            final value = getValue(path);
            if (value != null) {
              JsonPath.set(dataToPersist, path, value);
            }
          }
        }
      }

      // Implement persistence based on storage type
      switch (_storageType) {
        case 'local':
          // Use shared_preferences for local storage
          if (enableDebugMode) {
            _logger.debug('Local storage persistence not yet implemented');
          }
          break;
        case 'session':
          // Use in-memory storage for session
          if (enableDebugMode) {
            _logger.debug('Session storage persistence not yet implemented');
          }
          break;
        default:
          if (enableDebugMode) {
            _logger.warning('Unknown storage type: $_storageType');
          }
      }
    } catch (error) {
      if (enableDebugMode) {
        _logger.error('Error persisting state', error);
      }
    }
  }

  /// Loads persisted state from storage
  Future<void> _loadPersistedState() async {
    try {
      // Implement loading based on storage type
      switch (_storageType) {
        case 'local':
          // Use shared_preferences for local storage
          if (enableDebugMode) {
            _logger.debug('Local storage loading not yet implemented');
          }
          break;
        case 'session':
          // Use in-memory storage for session
          if (enableDebugMode) {
            _logger.debug('Session storage loading not yet implemented');
          }
          break;
        default:
          if (enableDebugMode) {
            _logger.warning('Unknown storage type: $_storageType');
          }
      }
    } catch (error) {
      if (enableDebugMode) {
        _logger.error('Error loading persisted state', error);
      }
    }
  }
}