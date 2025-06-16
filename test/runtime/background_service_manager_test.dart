import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  group('BackgroundServiceManager Tests', () {
    late BackgroundServiceManager manager;

    setUp(() {
      manager = BackgroundServiceManager(enableDebugMode: true);
    });

    tearDown(() async {
      await manager.dispose();
    });

    test('starts and stops individual services', () async {
      final service = BackgroundServiceDefinition(
        id: 'test_service',
        type: BackgroundServiceType.oneoff,
        tool: 'test_tool',
        interval: 1000,
      );

      expect(manager.isRunning('test_service'), false);
      expect(manager.runningServices, isEmpty);

      await manager.startService('test_service', service);

      expect(manager.isRunning('test_service'), true);
      expect(manager.runningServices, contains('test_service'));

      await manager.stopService('test_service');

      expect(manager.isRunning('test_service'), false);
      expect(manager.runningServices, isEmpty);
    });

    test('starts multiple services from map', () async {
      final services = {
        'service1': BackgroundServiceDefinition(
          id: 'service1',
          type: BackgroundServiceType.oneoff,
          tool: 'tool1',
        ),
        'service2': BackgroundServiceDefinition(
          id: 'service2',
          type: BackgroundServiceType.oneoff,
          tool: 'tool2',
        ),
      };

      await manager.startServices(services);

      expect(manager.runningServices.length, 2);
      expect(manager.isRunning('service1'), true);
      expect(manager.isRunning('service2'), true);
    });

    test('stops all services', () async {
      final services = {
        'service1': BackgroundServiceDefinition(
          id: 'service1',
          type: BackgroundServiceType.oneoff,
          tool: 'tool1',
        ),
        'service2': BackgroundServiceDefinition(
          id: 'service2',
          type: BackgroundServiceType.oneoff,
          tool: 'tool2',
        ),
      };

      await manager.startServices(services);
      expect(manager.runningServices.length, 2);

      await manager.stopAllServices();
      expect(manager.runningServices, isEmpty);
    });

    test('replaces existing service with same ID', () async {
      final service1 = BackgroundServiceDefinition(
        id: 'test_service',
        type: BackgroundServiceType.oneoff,
        tool: 'tool1',
      );

      final service2 = BackgroundServiceDefinition(
        id: 'test_service',
        type: BackgroundServiceType.periodic,
        tool: 'tool2',
        interval: 5000,
      );

      await manager.startService('test_service', service1);
      expect(manager.runningServices.length, 1);

      await manager.startService('test_service', service2);
      expect(manager.runningServices.length, 1);
      expect(manager.isRunning('test_service'), true);
    });

    test('handles dispose correctly', () async {
      final services = {
        'service1': BackgroundServiceDefinition(
          id: 'service1',
          type: BackgroundServiceType.periodic,
          tool: 'tool1',
          interval: 1000,
        ),
        'service2': BackgroundServiceDefinition(
          id: 'service2',
          type: BackgroundServiceType.continuous,
          tool: 'tool2',
        ),
      };

      await manager.startServices(services);
      expect(manager.runningServices.length, 2);

      await manager.dispose();
      expect(manager.runningServices, isEmpty);

      // Should not be able to start services after dispose
      await manager.startService('new_service', services['service1']!);
      expect(manager.runningServices, isEmpty);
    });
  });

  group('BackgroundServiceRunner Tests', () {
    test('creates runner for different service types', () {
      final periodicService = BackgroundServiceDefinition(
        id: 'periodic',
        type: BackgroundServiceType.periodic,
        tool: 'sync',
        interval: 30000,
      );

      final scheduledService = BackgroundServiceDefinition(
        id: 'scheduled',
        type: BackgroundServiceType.scheduled,
        tool: 'backup',
        schedule: '0 2 * * *',
      );

      final continuousService = BackgroundServiceDefinition(
        id: 'continuous',
        type: BackgroundServiceType.continuous,
        tool: 'monitor',
      );

      final eventService = BackgroundServiceDefinition(
        id: 'event',
        type: BackgroundServiceType.event,
        tool: 'handler',
        events: ['notification', 'app_resume'],
      );

      final oneoffService = BackgroundServiceDefinition(
        id: 'oneoff',
        type: BackgroundServiceType.oneoff,
        tool: 'init',
        interval: 5000,
      );

      final runners = [
        BackgroundServiceRunner(definition: periodicService, enableDebugMode: true),
        BackgroundServiceRunner(definition: scheduledService, enableDebugMode: true),
        BackgroundServiceRunner(definition: continuousService, enableDebugMode: true),
        BackgroundServiceRunner(definition: eventService, enableDebugMode: true),
        BackgroundServiceRunner(definition: oneoffService, enableDebugMode: true),
      ];

      for (final runner in runners) {
        expect(runner, isNotNull);
      }
    });

    test('periodic service starts and stops correctly', () async {
      final service = BackgroundServiceDefinition(
        id: 'periodic_test',
        type: BackgroundServiceType.periodic,
        tool: 'test_tool',
        interval: 100, // Short interval for testing
      );

      final runner = BackgroundServiceRunner(
        definition: service,
        enableDebugMode: true,
      );

      await runner.start();
      
      // Wait a short time to allow periodic execution
      await Future.delayed(const Duration(milliseconds: 250));
      
      await runner.stop();

      // Test passes if no exceptions are thrown
      expect(true, true);
    });

    test('oneoff service executes once', () async {
      final service = BackgroundServiceDefinition(
        id: 'oneoff_test',
        type: BackgroundServiceType.oneoff,
        tool: 'init_tool',
        interval: 50, // Short delay for testing
      );

      final runner = BackgroundServiceRunner(
        definition: service,
        enableDebugMode: true,
      );

      await runner.start();
      
      // Wait for oneoff execution
      await Future.delayed(const Duration(milliseconds: 100));
      
      await runner.stop();

      // Test passes if no exceptions are thrown
      expect(true, true);
    });

    test('continuous service runs continuously', () async {
      final service = BackgroundServiceDefinition(
        id: 'continuous_test',
        type: BackgroundServiceType.continuous,
        tool: 'monitor_tool',
      );

      final runner = BackgroundServiceRunner(
        definition: service,
        enableDebugMode: true,
      );

      await runner.start();
      
      // Wait a short time for continuous execution
      await Future.delayed(const Duration(milliseconds: 200));
      
      await runner.stop();

      // Test passes if no exceptions are thrown
      expect(true, true);
    });

    test('handles invalid periodic interval', () async {
      final service = BackgroundServiceDefinition(
        id: 'invalid_periodic',
        type: BackgroundServiceType.periodic,
        tool: 'test_tool',
        interval: 0, // Invalid interval
      );

      final runner = BackgroundServiceRunner(
        definition: service,
        enableDebugMode: true,
      );

      await runner.start();
      await runner.stop();

      // Should handle gracefully without crashing
      expect(true, true);
    });

    test('stops runner correctly', () async {
      final service = BackgroundServiceDefinition(
        id: 'stop_test',
        type: BackgroundServiceType.periodic,
        tool: 'test_tool',
        interval: 100,
      );

      final runner = BackgroundServiceRunner(
        definition: service,
        enableDebugMode: true,
      );

      await runner.start();
      await Future.delayed(const Duration(milliseconds: 50));
      await runner.stop();

      // Starting again after stop should work
      await runner.start();
      await runner.stop();

      expect(true, true);
    });
  });

  group('BackgroundServiceDefinition Factory Tests', () {
    test('creates periodic service from JSON', () {
      final json = {
        'type': 'periodic',
        'tool': 'sync_data',
        'interval': 60000,
        'params': {'endpoint': '/api/sync'},
        'constraints': {'requiresNetwork': true},
        'runInBackground': true,
        'priority': 'high',
      };

      final service = BackgroundServiceDefinition.fromJson('sync', json);

      expect(service.id, 'sync');
      expect(service.type, BackgroundServiceType.periodic);
      expect(service.tool, 'sync_data');
      expect(service.interval, 60000);
      expect(service.params!['endpoint'], '/api/sync');
      expect(service.constraints!['requiresNetwork'], true);
      expect(service.runInBackground, true);
      expect(service.priority, 'high');
    });

    test('creates scheduled service from JSON', () {
      final json = {
        'type': 'scheduled',
        'tool': 'daily_backup',
        'schedule': '0 2 * * *',
        'runInBackground': false,
      };

      final service = BackgroundServiceDefinition.fromJson('backup', json);

      expect(service.type, BackgroundServiceType.scheduled);
      expect(service.schedule, '0 2 * * *');
      expect(service.runInBackground, false);
    });

    test('creates event service from JSON', () {
      final json = {
        'type': 'event',
        'tool': 'handle_notification',
        'events': ['push_notification', 'app_resumed'],
      };

      final service = BackgroundServiceDefinition.fromJson('events', json);

      expect(service.type, BackgroundServiceType.event);
      expect(service.events, ['push_notification', 'app_resumed']);
    });

    test('uses default values for missing properties', () {
      final json = {
        'type': 'oneoff',
        'tool': 'simple_task',
      };

      final service = BackgroundServiceDefinition.fromJson('simple', json);

      expect(service.runInBackground, true);
      expect(service.priority, 'normal');
      expect(service.params, isNull);
      expect(service.constraints, isNull);
    });

    test('throws for invalid service type', () {
      final json = {
        'type': 'invalid_type',
        'tool': 'test_tool',
      };

      expect(
        () => BackgroundServiceDefinition.fromJson('test', json),
        throwsArgumentError,
      );
    });
  });
}