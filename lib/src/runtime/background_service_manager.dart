import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/ui_definition.dart';

/// Manages background services for the runtime
class BackgroundServiceManager {
  final bool enableDebugMode;
  final Map<String, BackgroundServiceRunner> _runningServices = {};
  bool _isDisposed = false;

  BackgroundServiceManager({
    this.enableDebugMode = false,
  });

  /// Start background services from definition
  Future<void> startServices(Map<String, BackgroundServiceDefinition> services) async {
    if (_isDisposed) return;

    for (final entry in services.entries) {
      await startService(entry.key, entry.value);
    }
  }

  /// Start a single background service
  Future<void> startService(String id, BackgroundServiceDefinition definition) async {
    if (_isDisposed) return;

    // Stop existing service with same ID
    await stopService(id);

    final runner = BackgroundServiceRunner(
      definition: definition,
      enableDebugMode: enableDebugMode,
    );

    _runningServices[id] = runner;
    await runner.start();

    if (enableDebugMode) {
      debugPrint('BackgroundServiceManager: Started service "$id"');
    }
  }

  /// Stop a background service
  Future<void> stopService(String id) async {
    final runner = _runningServices.remove(id);
    if (runner != null) {
      await runner.stop();
      
      if (enableDebugMode) {
        debugPrint('BackgroundServiceManager: Stopped service "$id"');
      }
    }
  }

  /// Stop all background services
  Future<void> stopAllServices() async {
    final runners = List<BackgroundServiceRunner>.from(_runningServices.values);
    _runningServices.clear();

    for (final runner in runners) {
      await runner.stop();
    }

    if (enableDebugMode) {
      debugPrint('BackgroundServiceManager: Stopped all services');
    }
  }

  /// Get running service IDs
  List<String> get runningServices => _runningServices.keys.toList();

  /// Check if service is running
  bool isRunning(String id) => _runningServices.containsKey(id);

  /// Dispose and cleanup
  Future<void> dispose() async {
    _isDisposed = true;
    await stopAllServices();
  }
}

/// Runs a single background service
class BackgroundServiceRunner {
  final BackgroundServiceDefinition definition;
  final bool enableDebugMode;
  
  Timer? _timer;
  bool _isRunning = false;
  
  BackgroundServiceRunner({
    required this.definition,
    this.enableDebugMode = false,
  });

  /// Start the service
  Future<void> start() async {
    if (_isRunning) return;
    
    _isRunning = true;
    
    switch (definition.type) {
      case BackgroundServiceType.periodic:
        _startPeriodicService();
        break;
      case BackgroundServiceType.scheduled:
        _startScheduledService();
        break;
      case BackgroundServiceType.continuous:
        _startContinuousService();
        break;
      case BackgroundServiceType.event:
        _startEventService();
        break;
      case BackgroundServiceType.oneoff:
        _startOneoffService();
        break;
    }
  }

  /// Stop the service
  Future<void> stop() async {
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
  }

  void _startPeriodicService() {
    final interval = definition.interval;
    if (interval == null || interval <= 0) {
      if (enableDebugMode) {
        debugPrint('BackgroundService: Invalid interval for periodic service ${definition.id}');
      }
      return;
    }

    _timer = Timer.periodic(Duration(milliseconds: interval), (timer) {
      if (!_isRunning) {
        timer.cancel();
        return;
      }
      _executeTool();
    });
  }

  void _startScheduledService() {
    // TODO: Implement cron-like scheduling
    if (enableDebugMode) {
      debugPrint('BackgroundService: Scheduled service not yet implemented for ${definition.id}');
    }
  }

  void _startContinuousService() {
    // Run continuously with minimal delay
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isRunning) {
        timer.cancel();
        return;
      }
      _executeTool();
    });
  }

  void _startEventService() {
    // TODO: Implement event-based triggering
    if (enableDebugMode) {
      debugPrint('BackgroundService: Event service not yet implemented for ${definition.id}');
    }
  }

  void _startOneoffService() {
    final delay = definition.interval ?? 0;
    _timer = Timer(Duration(milliseconds: delay), () {
      if (_isRunning) {
        _executeTool();
      }
      _isRunning = false;
    });
  }

  void _executeTool() {
    try {
      // TODO: Execute the tool through MCP
      if (enableDebugMode) {
        debugPrint('BackgroundService: Executing tool "${definition.tool}" for service ${definition.id}');
      }
      
      // This would normally call the MCP tool with the provided parameters
      // For now, just log the execution
      
    } catch (error) {
      if (enableDebugMode) {
        debugPrint('BackgroundService: Error executing tool for ${definition.id}: $error');
      }
    }
  }
}