import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/lifecycle_manager.dart';

void main() {
  group('LifecycleManager Tests', () {
    late LifecycleManager lifecycleManager;

    setUp(() {
      lifecycleManager = LifecycleManager(enableDebugMode: false);
    });

    tearDown(() {
      lifecycleManager.dispose();
    });

    test('adds listeners and triggers events', () async {
      final executionOrder = <String>[];

      // Add listeners for different events
      lifecycleManager.addListener(
        LifecycleEvent.initialize,
        () async {
          executionOrder.add('initialize');
        },
      );

      lifecycleManager.addListener(
        LifecycleEvent.ready,
        () async {
          executionOrder.add('ready');
        },
      );

      lifecycleManager.addListener(
        LifecycleEvent.pause,
        () async {
          executionOrder.add('pause');
        },
      );

      // Trigger events
      await lifecycleManager.triggerEvent(LifecycleEvent.initialize);
      await lifecycleManager.triggerEvent(LifecycleEvent.ready);
      await lifecycleManager.triggerEvent(LifecycleEvent.pause);

      expect(executionOrder, ['initialize', 'ready', 'pause']);
    });

    test('executes multiple listeners for same event', () async {
      final executionOrder = <String>[];

      lifecycleManager.addListener(
        LifecycleEvent.initialize,
        () async {
          executionOrder.add('listener1');
        },
      );

      lifecycleManager.addListener(
        LifecycleEvent.initialize,
        () async {
          executionOrder.add('listener2');
        },
      );

      lifecycleManager.addListener(
        LifecycleEvent.initialize,
        () async {
          executionOrder.add('listener3');
        },
      );

      await lifecycleManager.triggerEvent(LifecycleEvent.initialize);

      expect(executionOrder, ['listener1', 'listener2', 'listener3']);
    });

    test('executes hooks from action definitions', () async {
      // Test hook execution with mock actions
      final actions = [
        {
          'type': 'state',
          'action': 'set',
          'path': 'initialized',
          'value': true,
        },
        {
          'type': 'service',
          'service': 'navigation',
          'action': 'initialize',
        },
        {
          'type': 'notification',
          'action': 'requestPermission',
        },
      ];

      // Should execute without errors
      await lifecycleManager.executeLifecycleHooks(
        LifecycleEvent.initialize,
        actions,
      );
    });

    test('handles async listeners correctly', () async {
      final executionOrder = <String>[];

      lifecycleManager.addListener(
        LifecycleEvent.ready,
        () async {
          await Future.delayed(const Duration(milliseconds: 50));
          executionOrder.add('async1');
        },
      );

      lifecycleManager.addListener(
        LifecycleEvent.ready,
        () async {
          await Future.delayed(const Duration(milliseconds: 25));
          executionOrder.add('async2');
        },
      );

      lifecycleManager.addListener(
        LifecycleEvent.ready,
        () async {
          executionOrder.add('sync');
        },
      );

      await lifecycleManager.triggerEvent(LifecycleEvent.ready);

      // All listeners should complete
      expect(executionOrder.length, 3);
    });

    test('handles listener errors gracefully', () async {
      final executionOrder = <String>[];

      lifecycleManager.addListener(
        LifecycleEvent.destroy,
        () async {
          throw Exception('Test error');
        },
      );

      lifecycleManager.addListener(
        LifecycleEvent.destroy,
        () async {
          executionOrder.add('success');
        },
      );

      // Should not throw, but continue with other listeners
      await lifecycleManager.triggerEvent(LifecycleEvent.destroy);

      expect(executionOrder, ['success']);
    });

    test('removes listeners', () async {
      final executed = <String>[];

      void testListener() {
        executed.add('should_not_execute');
      }

      lifecycleManager.addListener(LifecycleEvent.initialize, testListener);
      lifecycleManager.removeListener(LifecycleEvent.initialize, testListener);

      await lifecycleManager.triggerEvent(LifecycleEvent.initialize);

      expect(executed, isEmpty);
    });

    test('supports all lifecycle events', () async {
      final events = <LifecycleEvent>[];

      for (final event in LifecycleEvent.values) {
        lifecycleManager.addListener(
          event,
          () async {
            events.add(event);
          },
        );
      }

      // Trigger all events
      for (final event in LifecycleEvent.values) {
        await lifecycleManager.triggerEvent(event);
      }

      expect(events.length, LifecycleEvent.values.length);
      expect(events.toSet(), LifecycleEvent.values.toSet());
    });

    test('passes data to listeners', () async {
      dynamic receivedData;

      lifecycleManager.addListener(
        LifecycleEvent.mount,
        (data) async {
          receivedData = data;
        },
      );

      await lifecycleManager.triggerEvent(LifecycleEvent.mount, 'test_data');

      expect(receivedData, 'test_data');
    });

    test('creates component lifecycle handler', () {
      final handler = lifecycleManager.createComponentHandler('test_component');

      expect(handler, isNotNull);
      expect(handler.componentId, 'test_component');
      expect(handler.isMounted, false);
    });
  });

  group('ComponentLifecycleHandler Tests', () {
    late LifecycleManager lifecycleManager;
    late ComponentLifecycleHandler handler;

    setUp(() {
      lifecycleManager = LifecycleManager(enableDebugMode: false);
      handler = lifecycleManager.createComponentHandler('test_component');
    });

    tearDown(() {
      lifecycleManager.dispose();
    });

    test('handles mount and unmount', () async {
      expect(handler.isMounted, false);

      await handler.mount();
      expect(handler.isMounted, true);

      await handler.unmount();
      expect(handler.isMounted, false);
    });

    test('prevents double mount', () async {
      await handler.mount();
      expect(handler.isMounted, true);

      // Second mount should be ignored
      await handler.mount();
      expect(handler.isMounted, true);
    });

    test('executes lifecycle config hooks', () async {
      final executionOrder = <String>[];

      // Set up global listeners to track execution
      lifecycleManager.addListener(LifecycleEvent.mount, (componentId) {
        executionOrder.add('mount:$componentId');
      });

      lifecycleManager.addListener(LifecycleEvent.unmount, (componentId) {
        executionOrder.add('unmount:$componentId');
      });

      await handler.mount();
      await handler.unmount();

      expect(executionOrder, ['mount:test_component', 'unmount:test_component']);
    });

    test('executes component-specific lifecycle hooks', () async {
      handler.setLifecycleConfig({
        'onMount': [
          {
            'type': 'state',
            'action': 'set',
            'path': 'mounted',
            'value': true,
          },
        ],
        'onUnmount': [
          {
            'type': 'state',
            'action': 'set',
            'path': 'mounted',
            'value': false,
          },
        ],
      });

      // Should execute without errors
      await handler.mount();
      await handler.unmount();
    });
  });
}