import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/animations/gesture_animation.dart';
import 'package:flutter_mcp_ui_runtime/src/animations/scroll_linked_animation.dart';

void main() {
  group('TC-018: Scroll position drives animation', () {
    test('Normal: scroll between startOffset and endOffset interpolates property',
        () {
      final controller = ScrollLinkedAnimationController(
        scrollTarget: 'myList',
        scrollMin: 0.0,
        scrollMax: 500.0,
        properties: {
          'opacity': PropertyRange(from: 0.0, to: 1.0),
        },
      );

      final values = controller.getPropertyValues(250.0);
      expect(values['opacity'], closeTo(0.5, 0.001));
    });

    test('Normal: scroll before startOffset — property stays at from value',
        () {
      final controller = ScrollLinkedAnimationController(
        scrollTarget: 'myList',
        scrollMin: 100.0,
        scrollMax: 500.0,
        properties: {
          'opacity': PropertyRange(from: 0.0, to: 1.0),
        },
      );

      final values = controller.getPropertyValues(50.0);
      expect(values['opacity'], closeTo(0.0, 0.001));
    });

    test('Normal: scroll past endOffset — property stays at to value', () {
      final controller = ScrollLinkedAnimationController(
        scrollTarget: 'myList',
        scrollMin: 0.0,
        scrollMax: 500.0,
        properties: {
          'opacity': PropertyRange(from: 0.0, to: 1.0),
        },
      );

      final values = controller.getPropertyValues(600.0);
      expect(values['opacity'], closeTo(1.0, 0.001));
    });

    test('Normal: calculateProgress returns correct range', () {
      final controller = ScrollLinkedAnimationController(
        scrollTarget: 'list',
        scrollMin: 100.0,
        scrollMax: 300.0,
        properties: {},
      );

      expect(controller.calculateProgress(100.0), closeTo(0.0, 0.001));
      expect(controller.calculateProgress(200.0), closeTo(0.5, 0.001));
      expect(controller.calculateProgress(300.0), closeTo(1.0, 0.001));
    });

    test('Normal: multiple properties interpolated simultaneously', () {
      final controller = ScrollLinkedAnimationController(
        scrollTarget: 'list',
        scrollMin: 0.0,
        scrollMax: 200.0,
        properties: {
          'opacity': PropertyRange(from: 0.0, to: 1.0),
          'scale': PropertyRange(from: 0.5, to: 1.5),
          'translateY': PropertyRange(from: -100.0, to: 0.0),
        },
      );

      final values = controller.getPropertyValues(100.0);
      expect(values['opacity'], closeTo(0.5, 0.001));
      expect(values['scale'], closeTo(1.0, 0.001));
      expect(values['translateY'], closeTo(-50.0, 0.001));
    });

    test('Boundary: startOffset equals endOffset — snap at offset', () {
      final controller = ScrollLinkedAnimationController(
        scrollTarget: 'list',
        scrollMin: 200.0,
        scrollMax: 200.0,
        properties: {
          'opacity': PropertyRange(from: 0.0, to: 1.0),
        },
      );

      expect(controller.calculateProgress(199.0), equals(0.0));
      expect(controller.calculateProgress(200.0), equals(1.0));
      expect(controller.calculateProgress(201.0), equals(1.0));
    });

    test('Boundary: negative scroll offset clamped to 0.0 progress', () {
      final controller = ScrollLinkedAnimationController(
        scrollTarget: 'list',
        scrollMin: 0.0,
        scrollMax: 100.0,
        properties: {},
      );

      expect(controller.calculateProgress(-50.0), equals(0.0));
    });

    test('Normal: fromJson creates controller correctly', () {
      final controller = ScrollLinkedAnimationController.fromJson({
        'scrollTarget': 'mainList',
        'scrollRange': {'min': 0.0, 'max': 500.0},
        'properties': {
          'opacity': {'from': 0.0, 'to': 1.0},
          'scale': {'from': 0.8, 'to': 1.0},
        },
      });

      expect(controller.scrollTarget, equals('mainList'));
      expect(controller.scrollMin, equals(0.0));
      expect(controller.scrollMax, equals(500.0));
      expect(controller.properties.length, equals(2));
      expect(controller.properties.containsKey('opacity'), isTrue);
      expect(controller.properties.containsKey('scale'), isTrue);
    });

    test('Normal: fromJson with missing optional fields uses defaults', () {
      final controller = ScrollLinkedAnimationController.fromJson({});

      expect(controller.scrollTarget, equals(''));
      expect(controller.scrollMin, equals(0.0));
      expect(controller.scrollMax, equals(0.0));
      expect(controller.properties, isEmpty);
    });

    test('Error: empty properties map — getPropertyValues returns empty', () {
      final controller = ScrollLinkedAnimationController(
        scrollTarget: 'list',
        scrollMin: 0.0,
        scrollMax: 100.0,
        properties: {},
      );

      final values = controller.getPropertyValues(50.0);
      expect(values, isEmpty);
    });
  });
}
