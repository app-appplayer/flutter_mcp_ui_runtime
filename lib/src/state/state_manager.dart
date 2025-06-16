import 'dart:async';

import 'package:flutter/foundation.dart';

import '../utils/json_path.dart';
import '../utils/mcp_logger.dart';

/// Manages application state with change notifications
class StateManager extends ChangeNotifier {
  final Map<String, dynamic> _state = {};
  final Map<String, StreamController> _streamControllers = {};
  final MCPLogger _logger = MCPLogger('StateManager');

  /// Initialize state with initial values
  void initialize(Map<String, dynamic> initialState) {
    _state.clear();
    _state.addAll(initialState);
    _logger.debug('initialize with: $initialState');
    _logger.debug('state after init: $_state');
    _logger.debug('hashCode: ${hashCode}');
    notifyListeners();
  }

  /// Get a value from state using a path
  T? get<T>(String path) {
    final result = JsonPath.get(_state, path) as T?;
    _logger.debug('get path: $path, result: $result, state: $_state');
    return result;
  }

  /// Set a value in state using a path
  void set(String path, dynamic value) {
    JsonPath.set(_state, path, value);
    _logger.debug('set path: $path, value: $value, new state: $_state');
    
    // Notify stream listeners for this specific path
    final controller = _streamControllers[path];
    if (controller != null && !controller.isClosed) {
      controller.add(value);
    }
    
    // Notify general listeners
    _logger.debug('calling notifyListeners() for path: $path');
    notifyListeners();
  }

  /// Update multiple values at once
  void updateAll(Map<String, dynamic> updates) {
    updates.forEach((path, value) {
      JsonPath.set(_state, path, value);
      
      // Notify stream listeners
      final controller = _streamControllers[path];
      if (controller != null && !controller.isClosed) {
        controller.add(value);
      }
    });
    
    notifyListeners();
  }

  /// Watch a specific path for changes
  Stream<T> watch<T>(String path) {
    // Create or get existing stream controller
    _streamControllers.putIfAbsent(
      path,
      () => StreamController<T>.broadcast(),
    );
    
    final controller = _streamControllers[path] as StreamController<T>;
    
    // Emit current value immediately
    final currentValue = get<T>(path);
    if (currentValue != null) {
      controller.add(currentValue);
    }
    
    return controller.stream;
  }

  /// Increment a numeric value
  void increment(String path, [num amount = 1]) {
    final current = get<num>(path) ?? 0;
    set(path, current + amount);
  }

  /// Decrement a numeric value
  void decrement(String path, [num amount = 1]) {
    final current = get<num>(path) ?? 0;
    set(path, current - amount);
  }

  /// Toggle a boolean value
  void toggle(String path) {
    final current = get<bool>(path) ?? false;
    set(path, !current);
  }

  /// Append to a list
  void append(String path, dynamic item) {
    final current = get<List>(path) ?? [];
    final newList = List.from(current)..add(item);
    set(path, newList);
  }

  /// Remove from a list
  void remove(String path, dynamic item) {
    final current = get<List>(path) ?? [];
    final newList = List.from(current)..remove(item);
    set(path, newList);
  }

  /// Remove at index from a list
  void removeAt(String path, int index) {
    final current = get<List>(path) ?? [];
    if (index >= 0 && index < current.length) {
      final newList = List.from(current)..removeAt(index);
      set(path, newList);
    }
  }

  /// Clear a list or map
  void clear(String path) {
    final current = get(path);
    if (current is List) {
      set(path, []);
    } else if (current is Map) {
      set(path, {});
    }
  }

  /// Get a copy of the entire state
  Map<String, dynamic> getState() {
    return Map<String, dynamic>.from(_state);
  }

  /// Replace the entire state
  void setState(Map<String, dynamic> newState) {
    _state.clear();
    _state.addAll(newState);
    
    // Notify all stream listeners
    _streamControllers.forEach((path, controller) {
      if (!controller.isClosed) {
        final value = get(path);
        if (value != null) {
          controller.add(value);
        }
      }
    });
    
    notifyListeners();
  }

  /// Clear all state
  void clearState() {
    _state.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    // Close all stream controllers
    for (final controller in _streamControllers.values) {
      controller.close();
    }
    _streamControllers.clear();
    
    super.dispose();
  }
}