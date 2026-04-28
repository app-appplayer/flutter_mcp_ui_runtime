import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart'
    show AnimationActionDefinition;
import 'package:flutter_mcp_ui_runtime/src/animations/animation_service.dart';

void main() {
  late AnimationService service;

  setUp(() {
    service = AnimationService();
  });

  tearDown(() {
    service.dispose();
  });

  group('TC-127: AnimationService — execute and cancel', () {
    test('Normal: controller registered → dispatch immediately → success', () async {
      String? receivedAction;
      int? receivedDuration;
      String? receivedCurve;

      service.registerController('widget1', (action, duration, curve) {
        receivedAction = action;
        receivedDuration = duration;
        receivedCurve = curve;
      });

      final result = await service.execute(AnimationActionDefinition(
        target: 'widget1',
        action: 'play',
        duration: 300,
        curve: 'easeInOut',
      ));

      expect(result.success, isTrue);
      expect(receivedAction, equals('play'));
      expect(receivedDuration, equals(300));
      expect(receivedCurve, equals('easeInOut'));
    });

    test('Normal: not registered → store as pending → success with deferred', () async {
      final result = await service.execute(AnimationActionDefinition(
        target: 'widget2',
        action: 'play',
      ));

      expect(result.success, isTrue);
      expect(result.data['deferred'], isTrue);
    });

    test('Normal: cancel sends stop to controller and removes active', () async {
      String? receivedAction;
      service.registerController('widget1', (action, duration, curve) {
        receivedAction = action;
      });

      await service.execute(AnimationActionDefinition(
        target: 'widget1',
        action: 'play',
      ));

      final cancelResult = await service.cancel('widget1');
      expect(cancelResult.success, isTrue);
      expect(receivedAction, equals('stop'));
      expect(service.isAnimating('widget1'), isFalse);
    });

    test('Boundary: cancel non-existent target → no-op success', () async {
      final result = await service.cancel('nonexistent');
      expect(result.success, isTrue);
    });

    test('Error: empty target → error result', () async {
      final result = await service.execute(AnimationActionDefinition(
        target: '',
        action: 'play',
      ));

      expect(result.success, isFalse);
      expect(result.error, contains('Target is required'));
    });
  });

  group('TC-128: AnimationService — registerController / unregisterController', () {
    test('Normal: registerController registers widget controller', () {
      bool called = false;
      service.registerController('widget1', (action, duration, curve) {
        called = true;
      });

      // Controller is registered; execute should dispatch to it
      service.execute(AnimationActionDefinition(
        target: 'widget1',
        action: 'play',
      ));

      expect(called, isTrue);
    });

    test('Normal: pending animation exists → auto-dispatches on registration', () async {
      // First execute without controller → stored as pending
      await service.execute(AnimationActionDefinition(
        target: 'widget1',
        action: 'play',
      ));

      String? receivedAction;
      service.registerController('widget1', (action, duration, curve) {
        receivedAction = action;
      });

      expect(receivedAction, equals('play'));
    });

    test('Normal: unregisterController removes controller and active animation', () async {
      service.registerController('widget1', (action, duration, curve) {});

      await service.execute(AnimationActionDefinition(
        target: 'widget1',
        action: 'play',
      ));

      expect(service.isAnimating('widget1'), isTrue);

      service.unregisterController('widget1');
      expect(service.isAnimating('widget1'), isFalse);
    });

    test('Boundary: register controller with no pending animation → just registers', () {
      bool called = false;
      service.registerController('widget1', (action, duration, curve) {
        called = true;
      });

      // No pending animation, so callback should not have been called
      expect(called, isFalse);
    });
  });

  group('TC-129: AnimationService — query methods', () {
    test('Normal: getActiveAction returns current animation action', () async {
      service.registerController('widget1', (action, duration, curve) {});

      await service.execute(AnimationActionDefinition(
        target: 'widget1',
        action: 'play',
      ));

      expect(service.getActiveAction('widget1'), equals('play'));
    });

    test('Normal: isAnimating returns true if target has active animation', () async {
      service.registerController('widget1', (action, duration, curve) {});

      await service.execute(AnimationActionDefinition(
        target: 'widget1',
        action: 'play',
      ));

      expect(service.isAnimating('widget1'), isTrue);
    });

    test('Boundary: non-existent target → getActiveAction null, isAnimating false', () {
      expect(service.getActiveAction('nonexistent'), isNull);
      expect(service.isAnimating('nonexistent'), isFalse);
    });
  });

  group('TC-130: AnimationService — controller callback signature', () {
    test('Normal: callback receives action, duration, curve', () async {
      String? a;
      int? d;
      String? c;

      service.registerController('w', (action, duration, curve) {
        a = action;
        d = duration;
        c = curve;
      });

      await service.execute(AnimationActionDefinition(
        target: 'w',
        action: 'reverse',
        duration: 500,
        curve: 'linear',
      ));

      expect(a, equals('reverse'));
      expect(d, equals(500));
      expect(c, equals('linear'));
    });

    test('Normal: supported actions include play, stop, reverse, repeat, reset', () async {
      final actions = <String>[];

      service.registerController('w', (action, duration, curve) {
        actions.add(action);
      });

      for (final action in ['play', 'stop', 'reverse', 'repeat', 'reset']) {
        await service.execute(AnimationActionDefinition(
          target: 'w',
          action: action,
        ));
      }

      expect(actions, equals(['play', 'stop', 'reverse', 'repeat', 'reset']));
    });

    test('Boundary: null duration and curve → defaults applied by controller', () async {
      int? receivedDuration;
      String? receivedCurve;

      service.registerController('w', (action, duration, curve) {
        receivedDuration = duration;
        receivedCurve = curve;
      });

      await service.execute(AnimationActionDefinition(
        target: 'w',
        action: 'play',
      ));

      expect(receivedDuration, isNull);
      expect(receivedCurve, isNull);
    });
  });

  group('TC-001: AnimationService — constructor', () {
    test('Normal: no-arg constructor creates instance successfully', () {
      final svc = AnimationService();
      expect(svc, isNotNull);
      svc.dispose();
    });

    test('Normal: service ready for registration immediately after construction', () {
      final svc = AnimationService();
      bool called = false;
      svc.registerController('test', (action, duration, curve) {
        called = true;
      });
      // Should be able to register without error
      expect(called, isFalse);
      svc.dispose();
    });

    test('Boundary: multiple instances are independent', () async {
      final svc1 = AnimationService();
      final svc2 = AnimationService();

      svc1.registerController('w', (action, duration, curve) {});
      await svc1.execute(AnimationActionDefinition(
        target: 'w',
        action: 'play',
      ));

      expect(svc1.isAnimating('w'), isTrue);
      expect(svc2.isAnimating('w'), isFalse);

      svc1.dispose();
      svc2.dispose();
    });
  });

  group('TC-002: AnimationService — registerController', () {
    test('Normal: register controller with unique ID → retrievable via getActiveAction', () async {
      service.registerController('w1', (action, duration, curve) {});
      await service.execute(AnimationActionDefinition(
        target: 'w1',
        action: 'play',
      ));
      expect(service.getActiveAction('w1'), equals('play'));
    });

    test('Normal: register multiple controllers with different IDs → all retrievable', () async {
      service.registerController('a', (action, duration, curve) {});
      service.registerController('b', (action, duration, curve) {});

      await service.execute(AnimationActionDefinition(target: 'a', action: 'play'));
      await service.execute(AnimationActionDefinition(target: 'b', action: 'reverse'));

      expect(service.getActiveAction('a'), equals('play'));
      expect(service.getActiveAction('b'), equals('reverse'));
    });

    test('Boundary: re-register same ID → replaces previous controller', () async {
      String? first;
      String? second;
      service.registerController('w', (action, duration, curve) {
        first = action;
      });
      service.registerController('w', (action, duration, curve) {
        second = action;
      });

      await service.execute(AnimationActionDefinition(target: 'w', action: 'play'));
      expect(first, isNull);
      expect(second, equals('play'));
    });
  });

  group('TC-003: AnimationService — unregisterController', () {
    test('Normal: unregister existing controller → getActiveAction returns null', () async {
      service.registerController('w', (action, duration, curve) {});
      await service.execute(AnimationActionDefinition(target: 'w', action: 'play'));
      service.unregisterController('w');
      expect(service.getActiveAction('w'), isNull);
    });

    test('Boundary: unregister non-existent ID → no-op', () {
      // Should not throw
      service.unregisterController('nonexistent');
      expect(service.isAnimating('nonexistent'), isFalse);
    });
  });

  group('TC-004: AnimationService — executeAction', () {
    test('Normal: action play on registered controller → dispatched', () async {
      String? received;
      service.registerController('w', (action, duration, curve) {
        received = action;
      });
      await service.execute(AnimationActionDefinition(target: 'w', action: 'play'));
      expect(received, equals('play'));
    });

    test('Normal: action reverse → dispatched', () async {
      String? received;
      service.registerController('w', (action, duration, curve) {
        received = action;
      });
      await service.execute(AnimationActionDefinition(target: 'w', action: 'reverse'));
      expect(received, equals('reverse'));
    });

    test('Normal: action stop → dispatched', () async {
      String? received;
      service.registerController('w', (action, duration, curve) {
        received = action;
      });
      await service.execute(AnimationActionDefinition(target: 'w', action: 'stop'));
      expect(received, equals('stop'));
    });

    test('Normal: action reset → dispatched', () async {
      String? received;
      service.registerController('w', (action, duration, curve) {
        received = action;
      });
      await service.execute(AnimationActionDefinition(target: 'w', action: 'reset'));
      expect(received, equals('reset'));
    });

    test('Normal: override duration via duration parameter', () async {
      int? received;
      service.registerController('w', (action, duration, curve) {
        received = duration;
      });
      await service.execute(AnimationActionDefinition(target: 'w', action: 'play', duration: 750));
      expect(received, equals(750));
    });

    test('Normal: override curve via curve parameter', () async {
      String? received;
      service.registerController('w', (action, duration, curve) {
        received = curve;
      });
      await service.execute(AnimationActionDefinition(target: 'w', action: 'play', curve: 'bounceOut'));
      expect(received, equals('bounceOut'));
    });

    test('Boundary: target not found → deferred success', () async {
      final result = await service.execute(AnimationActionDefinition(target: 'missing', action: 'play'));
      expect(result.success, isTrue);
      expect(result.data['deferred'], isTrue);
    });

    test('Error: empty target → error result', () async {
      final result = await service.execute(AnimationActionDefinition(target: '', action: 'play'));
      expect(result.success, isFalse);
    });
  });

  group('TC-005: AnimationService — disposeAll', () {
    test('Normal: dispose all registered controllers → all removed', () async {
      service.registerController('a', (action, duration, curve) {});
      service.registerController('b', (action, duration, curve) {});
      await service.execute(AnimationActionDefinition(target: 'a', action: 'play'));
      await service.execute(AnimationActionDefinition(target: 'b', action: 'play'));

      service.dispose();
      expect(service.isAnimating('a'), isFalse);
      expect(service.isAnimating('b'), isFalse);
      expect(service.getActiveAction('a'), isNull);
      expect(service.getActiveAction('b'), isNull);
    });

    test('Boundary: dispose with no controllers registered → no-op', () {
      // Should not throw
      final svc = AnimationService();
      svc.dispose();
    });
  });

  group('TC-026: AnimationService — controller cleanup', () {
    test('Normal: unregister removes controller and active state', () async {
      service.registerController('w', (action, duration, curve) {});
      await service.execute(AnimationActionDefinition(target: 'w', action: 'play'));
      expect(service.isAnimating('w'), isTrue);
      service.unregisterController('w');
      expect(service.isAnimating('w'), isFalse);
    });

    test('Boundary: double unregister → no error', () {
      service.registerController('w', (action, duration, curve) {});
      service.unregisterController('w');
      service.unregisterController('w');
      expect(service.isAnimating('w'), isFalse);
    });
  });

  group('TC-027: AnimationService — getActiveAction', () {
    test('Normal: returns currently executing action identifier', () async {
      service.registerController('w', (action, duration, curve) {});
      await service.execute(AnimationActionDefinition(target: 'w', action: 'play'));
      expect(service.getActiveAction('w'), equals('play'));
    });

    test('Boundary: no active animation on target → returns null', () {
      expect(service.getActiveAction('unknown'), isNull);
    });
  });

  group('TC-028: AnimationService — isAnimating', () {
    test('Normal: returns true while animation is active', () async {
      service.registerController('w', (action, duration, curve) {});
      await service.execute(AnimationActionDefinition(target: 'w', action: 'play'));
      expect(service.isAnimating('w'), isTrue);
    });

    test('Normal: returns false after cancel', () async {
      service.registerController('w', (action, duration, curve) {});
      await service.execute(AnimationActionDefinition(target: 'w', action: 'play'));
      await service.cancel('w');
      expect(service.isAnimating('w'), isFalse);
    });

    test('Boundary: unknown target → returns false', () {
      expect(service.isAnimating('unknown'), isFalse);
    });
  });

  group('TC-131: AnimationService — deferred execution pattern', () {
    test('Normal: action dispatched before widget mounted → stored', () async {
      await service.execute(AnimationActionDefinition(
        target: 'deferred-widget',
        action: 'play',
      ));

      expect(service.getActiveAction('deferred-widget'), equals('play'));
    });

    test('Normal: widget calls registerController → pending auto-dispatched', () async {
      await service.execute(AnimationActionDefinition(
        target: 'deferred-widget',
        action: 'play',
        duration: 300,
      ));

      String? receivedAction;
      service.registerController('deferred-widget', (action, duration, curve) {
        receivedAction = action;
      });

      expect(receivedAction, equals('play'));
    });

    test('Normal: ensures animation commands never lost due to timing', () async {
      // Simulate action → register pattern
      await service.execute(AnimationActionDefinition(
        target: 'w1',
        action: 'play',
      ));
      await service.execute(AnimationActionDefinition(
        target: 'w2',
        action: 'reverse',
      ));

      final actions = <String, String>{};
      service.registerController('w1', (action, duration, curve) {
        actions['w1'] = action;
      });
      service.registerController('w2', (action, duration, curve) {
        actions['w2'] = action;
      });

      expect(actions['w1'], equals('play'));
      expect(actions['w2'], equals('reverse'));
    });

    test('Boundary: multiple pending animations for same target → latest wins', () async {
      await service.execute(AnimationActionDefinition(
        target: 'w',
        action: 'play',
      ));
      await service.execute(AnimationActionDefinition(
        target: 'w',
        action: 'reverse',
      ));

      String? receivedAction;
      service.registerController('w', (action, duration, curve) {
        receivedAction = action;
      });

      // Latest action ('reverse') should be dispatched
      expect(receivedAction, equals('reverse'));
    });
  });
}
