import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/service_registry.dart';

// Test service implementations
class TestService extends RuntimeService {
  TestService({super.enableDebugMode});
  
  bool initializeCalled = false;
  bool disposeCalled = false;
  Map<String, dynamic>? lastConfig;
  
  @override
  Future<void> onInitialize(Map<String, dynamic> config) async {
    initializeCalled = true;
    lastConfig = config;
  }
  
  @override
  Future<void> onDispose() async {
    disposeCalled = true;
  }
}

class FailingService extends RuntimeService {
  FailingService({super.enableDebugMode});
  
  @override
  Future<void> onInitialize(Map<String, dynamic> config) async {
    throw Exception('Initialization failed');
  }
}

class SlowService extends RuntimeService {
  SlowService({super.enableDebugMode, this.delay = const Duration(milliseconds: 50)});
  
  final Duration delay;
  
  @override
  Future<void> onInitialize(Map<String, dynamic> config) async {
    await Future.delayed(delay);
  }
}

class OrderTrackingService extends RuntimeService {
  OrderTrackingService(this.name, this.orderList, {super.enableDebugMode});
  
  final String name;
  final List<String> orderList;
  
  @override
  Future<void> onInitialize(Map<String, dynamic> config) async {
    orderList.add(name);
  }
}

class DisposeTrackingService extends RuntimeService {
  DisposeTrackingService(this.name, this.orderList, {super.enableDebugMode});
  
  final String name;
  final List<String> orderList;
  
  @override
  Future<void> onDispose() async {
    orderList.add(name);
  }
}

class FailingDisposeService extends RuntimeService {
  FailingDisposeService({super.enableDebugMode});
  
  @override
  Future<void> onDispose() async {
    throw Exception('Disposal failed');
  }
}

void main() {
  group('RuntimeService Tests', () {
    late TestService service;
    
    setUp(() {
      service = TestService();
    });
    
    test('should initialize once', () async {
      expect(service.isInitialized, isFalse);
      
      await service.initialize({'key': 'value'});
      
      expect(service.isInitialized, isTrue);
      expect(service.initializeCalled, isTrue);
      expect(service.lastConfig, equals({'key': 'value'}));
    });
    
    test('should throw if already initialized', () async {
      await service.initialize({});
      
      expect(
        () => service.initialize({}),
        throwsStateError,
      );
    });
    
    test('should dispose correctly', () async {
      await service.initialize({});
      expect(service.isInitialized, isTrue);
      
      await service.dispose();
      
      expect(service.isInitialized, isFalse);
      expect(service.disposeCalled, isTrue);
    });
    
    test('should handle dispose when not initialized', () async {
      // Should not throw
      await service.dispose();
      expect(service.disposeCalled, isFalse);
    });
  });
  
  group('ServiceRegistry Tests', () {
    late ServiceRegistry registry;
    
    setUp(() {
      registry = ServiceRegistry(enableDebugMode: true);
    });
    
    tearDown(() async {
      await registry.dispose();
    });
    
    group('Service Registration', () {
      test('should register service', () {
        final service = TestService();
        
        registry.register('test', service);
        
        expect(registry.isRegistered('test'), isTrue);
        expect(registry.serviceNames, contains('test'));
      });
      
      test('should throw if service already registered', () {
        final service1 = TestService();
        final service2 = TestService();
        
        registry.register('test', service1);
        
        expect(
          () => registry.register('test', service2),
          throwsArgumentError,
        );
      });
      
      test('should unregister service', () async {
        final service = TestService();
        registry.register('test', service);
        await service.initialize({});
        
        await registry.unregister('test');
        
        expect(registry.isRegistered('test'), isFalse);
        expect(service.disposeCalled, isTrue);
      });
      
      test('should handle unregistering non-existent service', () async {
        // Should not throw
        await registry.unregister('non-existent');
      });
    });
    
    group('Service Retrieval', () {
      test('should get service by name', () {
        final service = TestService();
        registry.register('test', service);
        
        final retrieved = registry.get<TestService>('test');
        
        expect(retrieved, equals(service));
      });
      
      test('should return null for non-existent service', () {
        final retrieved = registry.get<TestService>('non-existent');
        expect(retrieved, isNull);
      });
      
      test('should return null for wrong type', () {
        final service = TestService();
        registry.register('test', service);
        
        final retrieved = registry.get<SlowService>('test');
        expect(retrieved, isNull);
      });
      
      test('should get required service', () {
        final service = TestService();
        registry.register('test', service);
        
        final retrieved = registry.getRequired<TestService>('test');
        
        expect(retrieved, equals(service));
      });
      
      test('should throw for required non-existent service', () {
        expect(
          () => registry.getRequired<TestService>('non-existent'),
          throwsStateError,
        );
      });
    });
    
    group('Dependencies', () {
      test('should register dependencies', () {
        final service1 = TestService();
        final service2 = TestService();
        
        registry.register('service1', service1);
        registry.register('service2', service2);
        registry.registerDependency('service2', 'service1');
        
        final statuses = registry.getServiceStatuses();
        expect(statuses['service2']!.dependencies, contains('service1'));
      });
      
      test('should initialize in dependency order', () async {
        final initOrder = <String>[];
        
        final service1 = OrderTrackingService('service1', initOrder);
        final service2 = OrderTrackingService('service2', initOrder);
        final service3 = OrderTrackingService('service3', initOrder);
        
        registry.register('service1', service1);
        registry.register('service2', service2);
        registry.register('service3', service3);
        
        // service3 depends on service2, which depends on service1
        registry.registerDependency('service2', 'service1');
        registry.registerDependency('service3', 'service2');
        
        await registry.initializeAll({});
        
        expect(initOrder, equals(['service1', 'service2', 'service3']));
      });
      
      test('should detect circular dependencies', () async {
        // Create a separate registry for this test to avoid tearDown issues
        final testRegistry = ServiceRegistry(enableDebugMode: true);
        final service1 = TestService();
        final service2 = TestService();
        
        testRegistry.register('service1', service1);
        testRegistry.register('service2', service2);
        
        // Create circular dependency
        testRegistry.registerDependency('service1', 'service2');
        testRegistry.registerDependency('service2', 'service1');
        
        expect(
          () => testRegistry.initializeAll({}),
          throwsStateError,
        );
        // Don't dispose testRegistry since it has circular dependencies
      });
      
      test('should throw for missing dependencies', () async {
        // Create a separate registry for this test to avoid tearDown issues
        final testRegistry = ServiceRegistry(enableDebugMode: true);
        final service = TestService();
        
        testRegistry.register('service', service);
        testRegistry.registerDependency('service', 'missing');
        
        expect(
          () => testRegistry.initializeAll({}),
          throwsStateError,
        );
        // Don't dispose testRegistry since it has missing dependencies
      });
    });
    
    group('Initialization', () {
      test('should initialize all services', () async {
        final service1 = TestService();
        final service2 = TestService();
        
        registry.register('service1', service1);
        registry.register('service2', service2);
        
        await registry.initializeAll({
          'service1': {'config1': 'value1'},
          'service2': {'config2': 'value2'},
        });
        
        expect(service1.isInitialized, isTrue);
        expect(service1.lastConfig, equals({'config1': 'value1'}));
        expect(service2.isInitialized, isTrue);
        expect(service2.lastConfig, equals({'config2': 'value2'}));
      });
      
      test('should use empty config if not provided', () async {
        final service = TestService();
        registry.register('test', service);
        
        await registry.initializeAll({});
        
        expect(service.isInitialized, isTrue);
        expect(service.lastConfig, equals({}));
      });
      
      test('should not re-initialize already initialized services', () async {
        final service = TestService();
        registry.register('test', service);
        
        await service.initialize({'initial': true});
        service.initializeCalled = false;
        
        await registry.initializeAll({'test': {'new': true}});
        
        expect(service.initializeCalled, isFalse);
        expect(service.lastConfig, equals({'initial': true}));
      });
      
      test('should handle initialization failures', () async {
        final failingService = FailingService();
        registry.register('failing', failingService);
        
        expect(
          () => registry.initializeAll({}),
          throwsException,
        );
      });
    });
    
    group('Service Operations', () {
      test('should execute operation with service', () async {
        final service = TestService();
        registry.register('test', service);
        await service.initialize({});
        
        final result = await registry.withService<String>(
          'test',
          (service) async => 'Success',
        );
        
        expect(result, equals('Success'));
      });
      
      test('should throw if service not found for operation', () async {
        expect(
          () => registry.withService<String>(
            'non-existent',
            (service) async => 'Success',
          ),
          throwsStateError,
        );
      });
      
      test('should throw if service not initialized for operation', () async {
        final service = TestService();
        registry.register('test', service);
        
        expect(
          () => registry.withService<String>(
            'test',
            (service) async => 'Success',
          ),
          throwsStateError,
        );
      });
    });
    
    group('Service Status', () {
      test('should get service statuses', () async {
        final service1 = TestService();
        final service2 = TestService();
        
        registry.register('service1', service1);
        registry.register('service2', service2);
        registry.registerDependency('service2', 'service1');
        
        await service1.initialize({});
        
        final statuses = registry.getServiceStatuses();
        
        expect(statuses.length, equals(2));
        
        final status1 = statuses['service1']!;
        expect(status1.name, equals('service1'));
        expect(status1.isInitialized, isTrue);
        expect(status1.dependencies, isEmpty);
        expect(status1.type, equals('TestService'));
        
        final status2 = statuses['service2']!;
        expect(status2.name, equals('service2'));
        expect(status2.isInitialized, isFalse);
        expect(status2.dependencies, equals(['service1']));
      });
    });
    
    group('Disposal', () {
      test('should dispose all services', () async {
        final service1 = TestService();
        final service2 = TestService();
        
        registry.register('service1', service1);
        registry.register('service2', service2);
        
        await registry.initializeAll({});
        await registry.dispose();
        
        expect(service1.disposeCalled, isTrue);
        expect(service2.disposeCalled, isTrue);
        expect(registry.serviceNames, isEmpty);
      });
      
      test('should dispose in reverse dependency order', () async {
        final disposeOrder = <String>[];
        
        final service1 = DisposeTrackingService('service1', disposeOrder);
        final service2 = DisposeTrackingService('service2', disposeOrder);
        final service3 = DisposeTrackingService('service3', disposeOrder);
        
        registry.register('service1', service1);
        registry.register('service2', service2);
        registry.register('service3', service3);
        
        registry.registerDependency('service2', 'service1');
        registry.registerDependency('service3', 'service2');
        
        await registry.initializeAll({});
        await registry.dispose();
        
        expect(disposeOrder, equals(['service3', 'service2', 'service1']));
      });
      
      test('should handle disposal errors gracefully', () async {
        final service = FailingDisposeService();
        
        registry.register('test', service);
        await service.initialize({});
        
        // Should not throw
        await registry.dispose();
      });
    });
  });
  
  group('ServiceStatus Tests', () {
    test('should create service status', () {
      const status = ServiceStatus(
        name: 'test',
        isInitialized: true,
        dependencies: ['dep1', 'dep2'],
        type: 'TestService',
      );
      
      expect(status.name, equals('test'));
      expect(status.isInitialized, isTrue);
      expect(status.dependencies, equals(['dep1', 'dep2']));
      expect(status.type, equals('TestService'));
    });
    
    test('should have meaningful toString', () {
      const status = ServiceStatus(
        name: 'test',
        isInitialized: true,
        dependencies: ['dep1'],
        type: 'TestService',
      );
      
      final str = status.toString();
      expect(str, contains('test'));
      expect(str, contains('true'));
      expect(str, contains('dep1'));
      expect(str, contains('TestService'));
    });
  });
  
  group('ServiceException Tests', () {
    test('should create exception with message', () {
      const exception = ServiceException('Test error');
      
      expect(exception.message, equals('Test error'));
      expect(exception.cause, isNull);
      expect(exception.toString(), equals('ServiceException: Test error'));
    });
    
    test('should create exception with cause', () {
      final cause = Exception('Root cause');
      final exception = ServiceException('Test error', cause);
      
      expect(exception.message, equals('Test error'));
      expect(exception.cause, equals(cause));
      expect(exception.toString(), contains('Test error'));
      expect(exception.toString(), contains('Root cause'));
    });
  });
}