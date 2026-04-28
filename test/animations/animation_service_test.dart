import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart'
    show AnimationActionDefinition;
import 'package:flutter_mcp_ui_runtime/src/animations/animation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TC-001: AnimationService — constructor', () {
    test('Normal: no-arg constructor creates instance successfully', () {
      final service = AnimationService();
      expect(service, isNotNull);
    });

    test('Normal: service ready for registration immediately after construction',
        () {
      final service = AnimationService();
      // Should not throw when registering right after construction
      service.registerController('target1', (action, duration, curve) {});
      expect(service.isAnimating('target1'), isFalse);
    });

    test('Boundary: multiple instances are independent', () {
      final service1 = AnimationService();
      final service2 = AnimationService();

      service1.registerController('target', (action, duration, curve) {});
      // service2 should not have service1's controller
      expect(service2.isAnimating('target'), isFalse);
      expect(service2.getActiveAction('target'), isNull);
    });
  });

  group('TC-002: AnimationService — registerController', () {
    late AnimationService service;

    setUp(() {
      service = AnimationService();
    });

    test('Normal: register controller with unique ID', () {
      String? receivedAction;
      service.registerController('fade-ctrl', (action, duration, curve) {
        receivedAction = action;
      });

      // Verify controller is registered by executing an action
      service.execute(const AnimationActionDefinition(
        action: 'play',
        target: 'fade-ctrl',
      ));
      expect(receivedAction, equals('play'));
    });

    test('Normal: register multiple controllers with different IDs', () {
      String? action1;
      String? action2;
      service.registerController('ctrl-a', (action, duration, curve) {
        action1 = action;
      });
      service.registerController('ctrl-b', (action, duration, curve) {
        action2 = action;
      });

      service.execute(
          const AnimationActionDefinition(action: 'play', target: 'ctrl-a'));
      service.execute(
          const AnimationActionDefinition(action: 'reverse', target: 'ctrl-b'));

      expect(action1, equals('play'));
      expect(action2, equals('reverse'));
    });

    test('Boundary: re-register same ID replaces previous controller', () {
      String? oldAction;
      String? newAction;

      service.registerController('ctrl', (action, duration, curve) {
        oldAction = action;
      });
      service.registerController('ctrl', (action, duration, curve) {
        newAction = action;
      });

      service.execute(
          const AnimationActionDefinition(action: 'play', target: 'ctrl'));

      expect(oldAction, isNull);
      expect(newAction, equals('play'));
    });

    test('Boundary: register with empty ID is handled gracefully', () {
      // Should not throw
      service.registerController('', (action, duration, curve) {});
    });

    test('Normal: deferred action dispatched on registration', () {
      String? receivedAction;

      // Execute before any controller is registered
      service.execute(
          const AnimationActionDefinition(action: 'play', target: 'deferred-ctrl'));

      // Now register — pending action should be dispatched
      service.registerController('deferred-ctrl', (action, duration, curve) {
        receivedAction = action;
      });

      expect(receivedAction, equals('play'));
    });
  });

  group('TC-003: AnimationService — unregisterController', () {
    late AnimationService service;

    setUp(() {
      service = AnimationService();
    });

    test('Normal: unregister existing controller', () {
      service.registerController('ctrl', (action, duration, curve) {});
      service.execute(
          const AnimationActionDefinition(action: 'play', target: 'ctrl'));
      expect(service.isAnimating('ctrl'), isTrue);

      service.unregisterController('ctrl');
      expect(service.getActiveAction('ctrl'), isNull);
      expect(service.isAnimating('ctrl'), isFalse);
    });

    test('Boundary: unregister non-existent ID is a no-op', () {
      // Should not throw
      service.unregisterController('nonexistent');
    });
  });

  group('TC-004: AnimationService — executeAction', () {
    late AnimationService service;
    late List<String> receivedActions;

    setUp(() {
      service = AnimationService();
      receivedActions = [];
      service.registerController('target', (action, duration, curve) {
        receivedActions.add(action);
      });
    });

    test('Normal: play action dispatches to controller', () async {
      final result = await service.execute(
          const AnimationActionDefinition(action: 'play', target: 'target'));
      expect(result.success, isTrue);
      expect(receivedActions, contains('play'));
    });

    test('Normal: reverse action dispatches to controller', () async {
      await service.execute(
          const AnimationActionDefinition(action: 'reverse', target: 'target'));
      expect(receivedActions, contains('reverse'));
    });

    test('Normal: pause action dispatches to controller', () async {
      await service.execute(
          const AnimationActionDefinition(action: 'pause', target: 'target'));
      expect(receivedActions, contains('pause'));
    });

    test('Normal: resume action dispatches to controller', () async {
      await service.execute(
          const AnimationActionDefinition(action: 'resume', target: 'target'));
      expect(receivedActions, contains('resume'));
    });

    test('Normal: reset action dispatches to controller', () async {
      await service.execute(
          const AnimationActionDefinition(action: 'reset', target: 'target'));
      expect(receivedActions, contains('reset'));
    });

    test('Normal: stop action dispatches to controller', () async {
      await service.execute(
          const AnimationActionDefinition(action: 'stop', target: 'target'));
      expect(receivedActions, contains('stop'));
    });

    test('Normal: override duration via duration parameter', () async {
      int? receivedDuration;
      service.registerController('dur-target', (action, duration, curve) {
        receivedDuration = duration;
      });
      await service.execute(const AnimationActionDefinition(
        action: 'play',
        target: 'dur-target',
        duration: 800,
      ));
      expect(receivedDuration, equals(800));
    });

    test('Normal: override curve via curve parameter', () async {
      String? receivedCurve;
      service.registerController('curve-target', (action, duration, curve) {
        receivedCurve = curve;
      });
      await service.execute(const AnimationActionDefinition(
        action: 'play',
        target: 'curve-target',
        curve: 'bounceOut',
      ));
      expect(receivedCurve, equals('bounceOut'));
    });

    test('Boundary: target not found stores action for deferred pickup',
        () async {
      final result = await service.execute(
          const AnimationActionDefinition(action: 'play', target: 'unknown'));
      expect(result.success, isTrue);
      expect(service.getActiveAction('unknown'), equals('play'));
    });

    test('Error: empty target returns error', () async {
      final result = await service
          .execute(const AnimationActionDefinition(action: 'play', target: ''));
      expect(result.success, isFalse);
      expect(result.error, contains('Target is required'));
    });
  });

  group('TC-005: AnimationService — disposeAll', () {
    test('Normal: dispose all registered controllers', () {
      final service = AnimationService();
      service.registerController('a', (action, duration, curve) {});
      service.registerController('b', (action, duration, curve) {});
      service.execute(
          const AnimationActionDefinition(action: 'play', target: 'a'));

      service.dispose();

      expect(service.isAnimating('a'), isFalse);
      expect(service.getActiveAction('a'), isNull);
      expect(service.getActiveAction('b'), isNull);
    });

    test('Boundary: dispose with no controllers registered is a no-op', () {
      final service = AnimationService();
      // Should not throw
      service.dispose();
    });
  });

  group('TC-026: Controller cleanup', () {
    test('Normal: controllers disposed prevent memory leaks', () {
      final service = AnimationService();
      service.registerController('widget-1', (action, duration, curve) {});
      service.execute(
          const AnimationActionDefinition(action: 'play', target: 'widget-1'));
      expect(service.isAnimating('widget-1'), isTrue);

      // Simulate page destroy
      service.unregisterController('widget-1');
      expect(service.isAnimating('widget-1'), isFalse);
    });

    test('Normal: disposeAll called during page lifecycle cleanup', () {
      final service = AnimationService();
      service.registerController('c1', (action, duration, curve) {});
      service.registerController('c2', (action, duration, curve) {});
      service.execute(
          const AnimationActionDefinition(action: 'play', target: 'c1'));
      service.execute(
          const AnimationActionDefinition(action: 'play', target: 'c2'));

      service.dispose();

      expect(service.isAnimating('c1'), isFalse);
      expect(service.isAnimating('c2'), isFalse);
    });

    test('Boundary: controller already disposed does not cause double-dispose error',
        () {
      final service = AnimationService();
      service.registerController('x', (action, duration, curve) {});
      service.unregisterController('x');
      // Second unregister should be a no-op
      service.unregisterController('x');
    });
  });

  group('TC-027: AnimationService — getActiveAction', () {
    test('Normal: returns currently executing action for target', () async {
      final service = AnimationService();
      service.registerController('anim-1', (action, duration, curve) {});
      await service.execute(
          const AnimationActionDefinition(action: 'play', target: 'anim-1'));
      expect(service.getActiveAction('anim-1'), equals('play'));
    });

    test('Boundary: no active animation returns null', () {
      final service = AnimationService();
      expect(service.getActiveAction('nonexistent'), isNull);
    });
  });

  group('TC-028: AnimationService — isAnimating', () {
    test('Normal: returns true while animation is active', () async {
      final service = AnimationService();
      service.registerController('anim-2', (action, duration, curve) {});
      await service.execute(
          const AnimationActionDefinition(action: 'play', target: 'anim-2'));
      expect(service.isAnimating('anim-2'), isTrue);
    });

    test('Normal: returns false after unregister', () async {
      final service = AnimationService();
      service.registerController('anim-3', (action, duration, curve) {});
      await service.execute(
          const AnimationActionDefinition(action: 'play', target: 'anim-3'));
      service.unregisterController('anim-3');
      expect(service.isAnimating('anim-3'), isFalse);
    });

    test('Boundary: unknown target returns false', () {
      final service = AnimationService();
      expect(service.isAnimating('unknown-target'), isFalse);
    });
  });
}
