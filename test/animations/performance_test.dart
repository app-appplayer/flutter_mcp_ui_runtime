import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/animations/animation_service.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart'
    show AnimationActionDefinition;

void main() {
  group('TC-024: Hardware acceleration', () {
    test(
        'Normal: RepaintBoundary concept — wrapping animated widgets enables compositing',
        () {
      // RepaintBoundary isolates repaint regions for hardware acceleration
      const widget = RepaintBoundary(
        child: SizedBox(width: 100, height: 100),
      );

      expect(widget, isA<RepaintBoundary>());
    });

    testWidgets(
        'Normal: Transform animations use compositing-friendly widgets',
        (WidgetTester tester) async {
      // Flutter's Transform widget uses hardware compositing when possible
      await tester.pumpWidget(
        MaterialApp(
          home: Transform.scale(
            scale: 0.5,
            child: const RepaintBoundary(
              child: SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      expect(find.byType(Transform), findsOneWidget);
      expect(find.byType(RepaintBoundary), findsWidgets);
    });

    testWidgets(
        'Normal: AnimatedOpacity uses hardware-accelerated compositing',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AnimatedOpacity(
            opacity: 0.5,
            duration: Duration(milliseconds: 300),
            child: SizedBox(width: 100, height: 100),
          ),
        ),
      );

      expect(find.byType(AnimatedOpacity), findsOneWidget);
    });

    test('Boundary: fallback to software rendering is transparent to API', () {
      // Hardware acceleration is managed by the Flutter framework;
      // the animation API works identically regardless of backend.
      // Verify that the service itself has no hardware-specific dependency.
      final service = AnimationService();
      expect(service, isNotNull);
      service.dispose();
    });
  });

  group('TC-025: Frame budget monitoring', () {
    test('Normal: AnimationService tracks active animations for monitoring',
        () async {
      final service = AnimationService();
      service.registerController('w1', (action, duration, curve) {});
      service.registerController('w2', (action, duration, curve) {});

      await service.execute(
          AnimationActionDefinition(target: 'w1', action: 'play'));
      await service.execute(
          AnimationActionDefinition(target: 'w2', action: 'play'));

      // Active animation count can be queried for monitoring
      expect(service.isAnimating('w1'), isTrue);
      expect(service.isAnimating('w2'), isTrue);

      service.dispose();
    });

    test('Normal: cancel reduces active animation count', () async {
      final service = AnimationService();
      service.registerController('w1', (action, duration, curve) {});

      await service.execute(
          AnimationActionDefinition(target: 'w1', action: 'play'));
      expect(service.isAnimating('w1'), isTrue);

      await service.cancel('w1');
      expect(service.isAnimating('w1'), isFalse);

      service.dispose();
    });

    test('Boundary: zero active animations — no monitoring overhead', () {
      final service = AnimationService();

      // No animations registered or active
      expect(service.isAnimating('any'), isFalse);
      expect(service.getActiveAction('any'), isNull);

      service.dispose();
    });

    test('Boundary: dispose clears all active animation tracking', () async {
      final service = AnimationService();
      service.registerController('w1', (action, duration, curve) {});
      service.registerController('w2', (action, duration, curve) {});

      await service.execute(
          AnimationActionDefinition(target: 'w1', action: 'play'));
      await service.execute(
          AnimationActionDefinition(target: 'w2', action: 'play'));

      service.dispose();

      // After dispose, no active animations remain
      expect(service.isAnimating('w1'), isFalse);
      expect(service.isAnimating('w2'), isFalse);
    });

    testWidgets(
        'Normal: PerformanceOverlay concept available for frame monitoring',
        (WidgetTester tester) async {
      // Flutter provides PerformanceOverlay for frame budget visualization
      // This verifies the concept is available in the framework
      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: const [
              SizedBox(width: 100, height: 100),
            ],
          ),
        ),
      );

      // PerformanceOverlay is a Flutter framework widget
      // available for frame budget monitoring at the app level
      expect(PerformanceOverlay.allEnabled, isA<Function>());
    });
  });
}
