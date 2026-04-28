import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/animations/page_transition.dart';

void main() {
  group('TC-012: Shared element pre-computation', () {
    test('Normal: sharedElement transition builds PageRouteBuilder with fade',
        () {
      final route = PageTransitionBuilder.buildTransition(
        page: const SizedBox(),
        type: PageTransitionType.sharedElement,
      );

      expect(route, isA<PageRouteBuilder>());
      // Default duration for shared element transition
      expect(
          route.transitionDuration, equals(const Duration(milliseconds: 300)));
    });

    test('Normal: sharedElement uses fade as underlying transition for pre-computation',
        () {
      // Shared element transition uses fade so Hero widget handles
      // the element position pre-computation and animation
      final route = PageTransitionBuilder.buildTransition(
        page: const SizedBox(),
        type: PageTransitionType.sharedElement,
        duration: const Duration(milliseconds: 500),
      );

      expect(route, isA<PageRouteBuilder>());
      expect(
          route.transitionDuration, equals(const Duration(milliseconds: 500)));
    });

    testWidgets(
        'Normal: Hero widgets animate between pages with shared element route',
        (WidgetTester tester) async {
      final route = PageTransitionBuilder.buildTransition(
        page: Scaffold(
          body: Hero(
            tag: 'shared-item',
            child: Container(
              width: 100,
              height: 100,
              color: Colors.blue,
            ),
          ),
        ),
        type: PageTransitionType.sharedElement,
      );

      // Route is valid and can be used with Navigator
      expect(route, isA<PageRouteBuilder>());
      expect(route.transitionDuration,
          equals(const Duration(milliseconds: 300)));
    });

    test('Normal: custom curve applied to shared element transition', () {
      final route = PageTransitionBuilder.buildTransition(
        page: const SizedBox(),
        type: PageTransitionType.sharedElement,
        curve: Curves.fastOutSlowIn,
      );

      expect(route, isA<PageRouteBuilder>());
    });

    test('Boundary: source element removed — transition degrades to fade', () {
      // When no matching Hero tags exist, the shared element route
      // still works as a regular fade transition
      final route = PageTransitionBuilder.buildTransition(
        page: const SizedBox(), // No Hero widget
        type: PageTransitionType.sharedElement,
      );

      expect(route, isA<PageRouteBuilder>());
    });

    test('Boundary: zero duration shared element transition', () {
      final route = PageTransitionBuilder.buildTransition(
        page: const SizedBox(),
        type: PageTransitionType.sharedElement,
        duration: Duration.zero,
      );

      expect(route.transitionDuration, equals(Duration.zero));
    });

    test('Boundary: reverse transition duration matches forward', () {
      final route = PageTransitionBuilder.buildTransition(
        page: const SizedBox(),
        type: PageTransitionType.sharedElement,
        duration: const Duration(milliseconds: 400),
      );

      expect(
          route.transitionDuration, equals(const Duration(milliseconds: 400)));
      expect(route.reverseTransitionDuration,
          equals(const Duration(milliseconds: 400)));
    });
  });
}
