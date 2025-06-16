import 'package:flutter/foundation.dart';

/// Abstract base class for all runtime services
abstract class RuntimeService {
  RuntimeService({this.enableDebugMode = kDebugMode});

  final bool enableDebugMode;
  bool _isInitialized = false;

  /// Gets whether this service has been initialized
  bool get isInitialized => _isInitialized;

  /// Initializes the service with the provided configuration
  Future<void> initialize(Map<String, dynamic> config) async {
    if (_isInitialized) {
      throw StateError('Service is already initialized');
    }

    await onInitialize(config);
    _isInitialized = true;

    if (enableDebugMode) {
      debugPrint('RuntimeService: ${runtimeType.toString()} initialized');
    }
  }

  /// Override this method to implement service-specific initialization
  Future<void> onInitialize(Map<String, dynamic> config) async {}

  /// Disposes of the service and cleans up resources
  Future<void> dispose() async {
    if (!_isInitialized) return;

    await onDispose();
    _isInitialized = false;

    if (enableDebugMode) {
      debugPrint('RuntimeService: ${runtimeType.toString()} disposed');
    }
  }

  /// Override this method to implement service-specific cleanup
  Future<void> onDispose() async {}
}

/// Registry for managing runtime services
class ServiceRegistry {
  ServiceRegistry({
    this.enableDebugMode = kDebugMode,
  });

  final bool enableDebugMode;
  final Map<String, RuntimeService> _services = {};
  final Map<String, List<String>> _dependencies = {};

  /// Gets all registered service names
  List<String> get serviceNames => _services.keys.toList();

  /// Registers a service with the given name
  void register(String name, RuntimeService service) {
    if (_services.containsKey(name)) {
      throw ArgumentError('Service "$name" is already registered');
    }

    _services[name] = service;

    if (enableDebugMode) {
      debugPrint('ServiceRegistry: Registered service "$name"');
    }
  }

  /// Unregisters a service by name
  Future<void> unregister(String name) async {
    final service = _services.remove(name);
    if (service != null) {
      await service.dispose();
      _dependencies.remove(name);

      if (enableDebugMode) {
        debugPrint('ServiceRegistry: Unregistered service "$name"');
      }
    }
  }

  /// Gets a service by name
  T? get<T extends RuntimeService>(String name) {
    final service = _services[name];
    if (service is T) {
      return service;
    }
    return null;
  }

  /// Gets a service by name, throwing if not found
  T getRequired<T extends RuntimeService>(String name) {
    final service = get<T>(name);
    if (service == null) {
      throw StateError('Required service "$name" not found');
    }
    return service;
  }

  /// Checks if a service is registered
  bool isRegistered(String name) {
    return _services.containsKey(name);
  }

  /// Registers service dependencies
  void registerDependency(String serviceName, String dependsOn) {
    _dependencies.putIfAbsent(serviceName, () => []).add(dependsOn);

    if (enableDebugMode) {
      debugPrint('ServiceRegistry: Service "$serviceName" depends on "$dependsOn"');
    }
  }

  /// Initializes all services in dependency order
  Future<void> initializeAll(Map<String, Map<String, dynamic>> configs) async {
    final initializationOrder = _resolveDependencyOrder();

    for (final serviceName in initializationOrder) {
      final service = _services[serviceName];
      if (service != null && !service.isInitialized) {
        final config = configs[serviceName] ?? <String, dynamic>{};
        
        try {
          await service.initialize(config);
        } catch (error) {
          if (enableDebugMode) {
            debugPrint('ServiceRegistry: Failed to initialize service "$serviceName": $error');
          }
          rethrow;
        }
      }
    }

    if (enableDebugMode) {
      debugPrint('ServiceRegistry: All services initialized');
    }
  }

  /// Resolves the order in which services should be initialized based on dependencies
  List<String> _resolveDependencyOrder() {
    final order = <String>[];
    final visited = <String>{};
    final visiting = <String>{};

    void visit(String serviceName) {
      if (visiting.contains(serviceName)) {
        throw StateError('Circular dependency detected involving service "$serviceName"');
      }
      
      if (visited.contains(serviceName)) {
        return;
      }

      visiting.add(serviceName);

      // Visit dependencies first
      final deps = _dependencies[serviceName] ?? [];
      for (final dep in deps) {
        if (!_services.containsKey(dep)) {
          throw StateError('Service "$serviceName" depends on unregistered service "$dep"');
        }
        visit(dep);
      }

      visiting.remove(serviceName);
      visited.add(serviceName);
      order.add(serviceName);
    }

    // Visit all services
    for (final serviceName in _services.keys) {
      visit(serviceName);
    }

    return order;
  }

  /// Gets service status information
  Map<String, ServiceStatus> getServiceStatuses() {
    final statuses = <String, ServiceStatus>{};
    
    for (final entry in _services.entries) {
      statuses[entry.key] = ServiceStatus(
        name: entry.key,
        isInitialized: entry.value.isInitialized,
        dependencies: _dependencies[entry.key] ?? [],
        type: entry.value.runtimeType.toString(),
      );
    }
    
    return statuses;
  }

  /// Executes a function with a specific service
  Future<T> withService<T>(
    String serviceName,
    Future<T> Function(RuntimeService service) operation,
  ) async {
    final service = _services[serviceName];
    if (service == null) {
      throw StateError('Service "$serviceName" not found');
    }

    if (!service.isInitialized) {
      throw StateError('Service "$serviceName" is not initialized');
    }

    return await operation(service);
  }

  /// Disposes all registered services
  Future<void> dispose() async {
    // Dispose services in reverse dependency order
    final disposeOrder = _resolveDependencyOrder().reversed.toList();

    for (final serviceName in disposeOrder) {
      final service = _services[serviceName];
      if (service != null) {
        try {
          await service.dispose();
        } catch (error) {
          if (enableDebugMode) {
            debugPrint('ServiceRegistry: Error disposing service "$serviceName": $error');
          }
        }
      }
    }

    _services.clear();
    _dependencies.clear();

    if (enableDebugMode) {
      debugPrint('ServiceRegistry: All services disposed');
    }
  }
}

/// Information about a service's status
class ServiceStatus {
  const ServiceStatus({
    required this.name,
    required this.isInitialized,
    required this.dependencies,
    required this.type,
  });

  final String name;
  final bool isInitialized;
  final List<String> dependencies;
  final String type;

  @override
  String toString() {
    return 'ServiceStatus(name: $name, initialized: $isInitialized, '
        'dependencies: $dependencies, type: $type)';
  }
}

/// Exception thrown when service operations fail
class ServiceException implements Exception {
  const ServiceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() {
    if (cause != null) {
      return 'ServiceException: $message\nCaused by: $cause';
    }
    return 'ServiceException: $message';
  }
}