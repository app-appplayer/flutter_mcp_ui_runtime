import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/animations/gesture_animation.dart';

void main() {
  group('TC-013: Drag gesture drives animation', () {
    test('Normal: horizontal drag updates animation progress proportionally',
        () {
      final controller = GestureAnimationController(
        gesture: 'horizontalDrag',
        rangeMin: 0.0,
        rangeMax: 300.0,
        properties: {
          'opacity': PropertyRange(from: 1.0, to: 0.0),
        },
      );

      expect(controller.calculateProgress(0.0), closeTo(0.0, 0.001));
      expect(controller.calculateProgress(150.0), closeTo(0.5, 0.001));
      expect(controller.calculateProgress(300.0), closeTo(1.0, 0.001));
    });

    test('Normal: drag past threshold executes onComplete', () {
      final controller = GestureAnimationController(
        rangeMin: 0.0,
        rangeMax: 200.0,
        properties: {},
        onComplete: {'action': 'navigate', 'target': '/next'},
        threshold: 0.5,
      );

      final progress = controller.calculateProgress(150.0);
      expect(controller.isComplete(progress), isTrue);
      expect(controller.onComplete, isNotNull);
      expect(controller.onComplete!['action'], equals('navigate'));
    });

    test('Normal: drag below threshold does not complete', () {
      final controller = GestureAnimationController(
        rangeMin: 0.0,
        rangeMax: 200.0,
        properties: {},
        threshold: 0.5,
      );

      final progress = controller.calculateProgress(80.0);
      expect(controller.isComplete(progress), isFalse);
    });

    test('Normal: getPropertyValues interpolates correctly', () {
      final controller = GestureAnimationController(
        rangeMin: 0.0,
        rangeMax: 100.0,
        properties: {
          'opacity': PropertyRange(from: 1.0, to: 0.0),
          'scale': PropertyRange(from: 1.0, to: 0.5),
        },
      );

      final values = controller.getPropertyValues(0.5);
      expect(values['opacity'], closeTo(0.5, 0.001));
      expect(values['scale'], closeTo(0.75, 0.001));
    });

    test('Boundary: threshold 0.0 — any drag completes', () {
      final controller = GestureAnimationController(
        rangeMin: 0.0,
        rangeMax: 100.0,
        properties: {},
        threshold: 0.0,
      );

      expect(controller.isComplete(0.0), isTrue);
      expect(controller.isComplete(0.01), isTrue);
    });

    test('Boundary: threshold 1.0 — must drag full distance', () {
      final controller = GestureAnimationController(
        rangeMin: 0.0,
        rangeMax: 100.0,
        properties: {},
        threshold: 1.0,
      );

      expect(controller.isComplete(0.99), isFalse);
      expect(controller.isComplete(1.0), isTrue);
    });

    test('Boundary: progress clamped below 0.0', () {
      final controller = GestureAnimationController(
        rangeMin: 100.0,
        rangeMax: 200.0,
        properties: {},
      );

      expect(controller.calculateProgress(50.0), equals(0.0));
    });

    test('Boundary: progress clamped above 1.0', () {
      final controller = GestureAnimationController(
        rangeMin: 0.0,
        rangeMax: 100.0,
        properties: {},
      );

      expect(controller.calculateProgress(200.0), equals(1.0));
    });

    test('Boundary: rangeMin equals rangeMax — snap behavior', () {
      final controller = GestureAnimationController(
        rangeMin: 50.0,
        rangeMax: 50.0,
        properties: {},
      );

      expect(controller.calculateProgress(49.0), equals(0.0));
      expect(controller.calculateProgress(50.0), equals(1.0));
      expect(controller.calculateProgress(51.0), equals(1.0));
    });

    test('Normal: fromJson creates controller correctly', () {
      final controller = GestureAnimationController.fromJson({
        'gesture': 'horizontalDrag',
        'range': {'min': 0.0, 'max': 300.0},
        'properties': {
          'opacity': {'from': 1.0, 'to': 0.0},
        },
        'onComplete': {'action': 'dismiss'},
        'threshold': 0.7,
      });

      expect(controller.gesture, equals('horizontalDrag'));
      expect(controller.rangeMin, equals(0.0));
      expect(controller.rangeMax, equals(300.0));
      expect(controller.properties.containsKey('opacity'), isTrue);
      expect(controller.onComplete, isNotNull);
      expect(controller.threshold, equals(0.7));
    });

    test('Normal: fromJson with missing optional fields uses defaults', () {
      final controller = GestureAnimationController.fromJson(<String, dynamic>{
        'range': <String, dynamic>{'min': 0, 'max': 100},
        'properties': <String, dynamic>{},
      });

      expect(controller.gesture, equals('horizontalDrag'));
      expect(controller.threshold, equals(0.5));
      expect(controller.onComplete, isNull);
    });

    test('Error: fromJson with empty json uses defaults', () {
      final controller = GestureAnimationController.fromJson(<String, dynamic>{});

      expect(controller.gesture, equals('horizontalDrag'));
      expect(controller.rangeMin, equals(0.0));
      expect(controller.rangeMax, equals(0.0));
      expect(controller.properties, isEmpty);
    });
  });

  group('TC-014: Gesture axis constraint', () {
    test('Normal: horizontalDrag gesture type recognized', () {
      final controller = GestureAnimationController(
        gesture: 'horizontalDrag',
        rangeMin: 0.0,
        rangeMax: 200.0,
        properties: {},
      );

      expect(controller.gesture, equals('horizontalDrag'));
    });

    test('Normal: verticalDrag gesture type recognized', () {
      final controller = GestureAnimationController(
        gesture: 'verticalDrag',
        rangeMin: 0.0,
        rangeMax: 200.0,
        properties: {},
      );

      expect(controller.gesture, equals('verticalDrag'));
    });

    test('Boundary: default gesture is horizontalDrag', () {
      final controller = GestureAnimationController(
        rangeMin: 0.0,
        rangeMax: 200.0,
        properties: {},
      );

      expect(controller.gesture, equals('horizontalDrag'));
    });

    test('Boundary: fromJson default axis is horizontalDrag', () {
      final controller = GestureAnimationController.fromJson(<String, dynamic>{
        'range': <String, dynamic>{'min': 0, 'max': 100},
        'properties': <String, dynamic>{},
      });

      expect(controller.gesture, equals('horizontalDrag'));
    });

    test('Normal: fromJson with verticalDrag axis', () {
      final controller = GestureAnimationController.fromJson(<String, dynamic>{
        'gesture': 'verticalDrag',
        'range': <String, dynamic>{'min': 0, 'max': 100},
        'properties': <String, dynamic>{},
      });

      expect(controller.gesture, equals('verticalDrag'));
    });

    test('Boundary: invalid axis value stored as-is (handled at widget level)',
        () {
      final controller = GestureAnimationController.fromJson(<String, dynamic>{
        'gesture': 'invalidAxis',
        'range': <String, dynamic>{'min': 0, 'max': 100},
        'properties': <String, dynamic>{},
      });

      // The controller stores the value; widget-level code handles fallback
      expect(controller.gesture, equals('invalidAxis'));
    });
  });

  group('PropertyRange', () {
    test('Normal: interpolate at 0.0 returns from value', () {
      const range = PropertyRange(from: 10.0, to: 50.0);
      expect(range.interpolate(0.0), equals(10.0));
    });

    test('Normal: interpolate at 1.0 returns to value', () {
      const range = PropertyRange(from: 10.0, to: 50.0);
      expect(range.interpolate(1.0), equals(50.0));
    });

    test('Normal: interpolate at 0.5 returns midpoint', () {
      const range = PropertyRange(from: 0.0, to: 100.0);
      expect(range.interpolate(0.5), equals(50.0));
    });

    test('Normal: fromJson creates PropertyRange correctly', () {
      final range = PropertyRange.fromJson({'from': 0.0, 'to': 1.0});
      expect(range.from, equals(0.0));
      expect(range.to, equals(1.0));
    });

    test('Boundary: from equals to — always returns same value', () {
      const range = PropertyRange(from: 5.0, to: 5.0);
      expect(range.interpolate(0.0), equals(5.0));
      expect(range.interpolate(0.5), equals(5.0));
      expect(range.interpolate(1.0), equals(5.0));
    });

    test('Normal: reverse range (from > to) interpolates correctly', () {
      const range = PropertyRange(from: 100.0, to: 0.0);
      expect(range.interpolate(0.5), closeTo(50.0, 0.001));
    });
  });
}
