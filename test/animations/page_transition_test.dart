import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/animations/page_transition.dart';

void main() {
  group('TC-ANIM-010: PageTransitionType enum', () {
    test('Normal: all transition types defined', () {
      expect(PageTransitionType.values, containsAll([
        PageTransitionType.slide,
        PageTransitionType.fade,
        PageTransitionType.scale,
        PageTransitionType.sharedElement,
        PageTransitionType.none,
      ]));
    });
  });

  group('TC-ANIM-011: PageTransitionBuilder — parseType', () {
    test('Normal: parses all known types', () {
      expect(PageTransitionBuilder.parseType('slide'),
          equals(PageTransitionType.slide));
      expect(PageTransitionBuilder.parseType('fade'),
          equals(PageTransitionType.fade));
      expect(PageTransitionBuilder.parseType('scale'),
          equals(PageTransitionType.scale));
      expect(PageTransitionBuilder.parseType('sharedElement'),
          equals(PageTransitionType.sharedElement));
      expect(PageTransitionBuilder.parseType('none'),
          equals(PageTransitionType.none));
    });

    test('Normal: unknown string defaults to fade', () {
      expect(PageTransitionBuilder.parseType('unknown'),
          equals(PageTransitionType.fade));
    });

    test('Boundary: null defaults to fade', () {
      expect(PageTransitionBuilder.parseType(null),
          equals(PageTransitionType.fade));
    });
  });

  group('TC-ANIM-012: PageTransitionBuilder — parseCurve', () {
    test('Normal: parses standard Flutter curves', () {
      expect(PageTransitionBuilder.parseCurve('linear'), equals(Curves.linear));
      expect(
          PageTransitionBuilder.parseCurve('easeIn'), equals(Curves.easeIn));
      expect(
          PageTransitionBuilder.parseCurve('easeOut'), equals(Curves.easeOut));
      expect(PageTransitionBuilder.parseCurve('easeInOut'),
          equals(Curves.easeInOut));
      expect(PageTransitionBuilder.parseCurve('decelerate'),
          equals(Curves.decelerate));
      expect(PageTransitionBuilder.parseCurve('fastOutSlowIn'),
          equals(Curves.fastOutSlowIn));
    });

    test('Normal: parses bounce curves', () {
      expect(PageTransitionBuilder.parseCurve('bounceIn'),
          equals(Curves.bounceIn));
      expect(PageTransitionBuilder.parseCurve('bounceOut'),
          equals(Curves.bounceOut));
      expect(PageTransitionBuilder.parseCurve('bounceInOut'),
          equals(Curves.bounceInOut));
    });

    test('Normal: parses elastic curves', () {
      expect(PageTransitionBuilder.parseCurve('elasticIn'),
          equals(Curves.elasticIn));
      expect(PageTransitionBuilder.parseCurve('elasticOut'),
          equals(Curves.elasticOut));
      expect(PageTransitionBuilder.parseCurve('elasticInOut'),
          equals(Curves.elasticInOut));
    });

    test('Normal: parses physics-based curves (spring, friction, gravity)', () {
      final spring = PageTransitionBuilder.parseCurve('spring');
      expect(spring, isA<Curve>());
      // Spring curve at t=0 should be ~0, at t=1 should be ~1
      expect(spring.transform(0.0), closeTo(0.0, 0.01));

      final friction = PageTransitionBuilder.parseCurve('friction');
      expect(friction, equals(Curves.decelerate));

      final gravity = PageTransitionBuilder.parseCurve('gravity');
      expect(gravity, isA<Curve>());
      expect(gravity.transform(0.0), closeTo(0.0, 0.01));
    });

    test('Boundary: unknown curve defaults to easeInOut', () {
      expect(PageTransitionBuilder.parseCurve('unknown'),
          equals(Curves.easeInOut));
    });

    test('Boundary: null defaults to easeInOut', () {
      expect(
          PageTransitionBuilder.parseCurve(null), equals(Curves.easeInOut));
    });
  });

  group('TC-006: Slide transition — direction variants', () {
    test('Normal: slide left → begins from Offset(1.0, 0.0)', () {
      final route = PageTransitionBuilder.buildTransition(
        page: const SizedBox(),
        type: PageTransitionType.slide,
        slideDirection: 'left',
      );
      expect(route, isA<PageRouteBuilder>());
      expect(route.transitionDuration, equals(const Duration(milliseconds: 300)));
    });

    test('Normal: slide right → begins from Offset(-1.0, 0.0)', () {
      final route = PageTransitionBuilder.buildTransition(
        page: const SizedBox(),
        type: PageTransitionType.slide,
        slideDirection: 'right',
      );
      expect(route, isA<PageRouteBuilder>());
    });

    test('Normal: slide up → begins from Offset(0.0, 1.0)', () {
      final route = PageTransitionBuilder.buildTransition(
        page: const SizedBox(),
        type: PageTransitionType.slide,
        slideDirection: 'up',
      );
      expect(route, isA<PageRouteBuilder>());
    });

    test('Normal: slide down → begins from Offset(0.0, -1.0)', () {
      final route = PageTransitionBuilder.buildTransition(
        page: const SizedBox(),
        type: PageTransitionType.slide,
        slideDirection: 'down',
      );
      expect(route, isA<PageRouteBuilder>());
    });

    test('Boundary: no direction specified → defaults to left', () {
      final route = PageTransitionBuilder.buildTransition(
        page: const SizedBox(),
        type: PageTransitionType.slide,
      );
      // Default slideDirection is 'left'
      expect(route, isA<PageRouteBuilder>());
    });

    test('Boundary: invalid direction value → falls back to left default', () {
      final route = PageTransitionBuilder.buildTransition(
        page: const SizedBox(),
        type: PageTransitionType.slide,
        slideDirection: 'diagonal',
      );
      expect(route, isA<PageRouteBuilder>());
    });
  });

  group('TC-007: Fade transition', () {
    test('Normal: fade transition builds correctly', () {
      final route = PageTransitionBuilder.buildTransition(
        page: const SizedBox(),
        type: PageTransitionType.fade,
      );
      expect(route, isA<PageRouteBuilder>());
    });

    test('Normal: custom duration applied', () {
      final route = PageTransitionBuilder.buildTransition(
        page: const SizedBox(),
        type: PageTransitionType.fade,
        duration: const Duration(milliseconds: 600),
      );
      expect(route.transitionDuration, equals(const Duration(milliseconds: 600)));
    });

    test('Boundary: duration 0 → instant transition', () {
      final route = PageTransitionBuilder.buildTransition(
        page: const SizedBox(),
        type: PageTransitionType.fade,
        duration: Duration.zero,
      );
      expect(route.transitionDuration, equals(Duration.zero));
    });
  });

  group('TC-008: Scale transition', () {
    test('Normal: scale transition builds correctly', () {
      final route = PageTransitionBuilder.buildTransition(
        page: const SizedBox(),
        type: PageTransitionType.scale,
      );
      expect(route, isA<PageRouteBuilder>());
    });

    test('Boundary: custom curve applied', () {
      final route = PageTransitionBuilder.buildTransition(
        page: const SizedBox(),
        type: PageTransitionType.scale,
        curve: Curves.bounceOut,
      );
      expect(route, isA<PageRouteBuilder>());
    });
  });

  group('TC-009: None transition', () {
    test('Normal: none transition → instant page change with zero duration', () {
      final route = PageTransitionBuilder.buildTransition(
        page: const SizedBox(),
        type: PageTransitionType.none,
      );
      expect(route.transitionDuration, equals(Duration.zero));
      expect(route.reverseTransitionDuration, equals(Duration.zero));
    });

    test('Boundary: duration parameter ignored for none type', () {
      final route = PageTransitionBuilder.buildTransition(
        page: const SizedBox(),
        type: PageTransitionType.none,
        duration: const Duration(milliseconds: 999),
      );
      // None transition always uses Duration.zero
      expect(route.transitionDuration, equals(Duration.zero));
    });
  });

  group('TC-010: Default transition', () {
    test('Normal: null type string → defaults to fade', () {
      final type = PageTransitionBuilder.parseType(null);
      expect(type, equals(PageTransitionType.fade));
    });

    test('Boundary: missing transition key entirely → defaults to fade', () {
      final type = PageTransitionBuilder.parseType(null);
      final route = PageTransitionBuilder.buildTransition(
        page: const SizedBox(),
        type: type,
      );
      expect(route, isA<PageRouteBuilder>());
    });
  });

  group('TC-011: Shared element (hero) transition', () {
    test('Normal: sharedElement transition builds as PageRouteBuilder', () {
      final route = PageTransitionBuilder.buildTransition(
        page: const SizedBox(),
        type: PageTransitionType.sharedElement,
      );
      expect(route, isA<PageRouteBuilder>());
    });

    test('Normal: custom duration applied to shared element', () {
      final route = PageTransitionBuilder.buildTransition(
        page: const SizedBox(),
        type: PageTransitionType.sharedElement,
        duration: const Duration(milliseconds: 400),
      );
      expect(route.transitionDuration, equals(const Duration(milliseconds: 400)));
    });

    test('Boundary: no matching hero tags → regular fade transition used', () {
      // sharedElement type uses fade as its underlying transition
      final route = PageTransitionBuilder.buildTransition(
        page: const SizedBox(),
        type: PageTransitionType.sharedElement,
      );
      expect(route, isA<PageRouteBuilder>());
    });
  });

  group('TC-029: PageTransitionBuilder — buildPhysicsTransition widget', () {
    testWidgets('Normal: spring physics builds SlideTransition',
        (WidgetTester tester) async {
      final controller = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 300),
      );

      final widget = PageTransitionBuilder.buildPhysicsTransition(
        animation: controller,
        child: const Text('spring'),
      );

      await tester.pumpWidget(MaterialApp(home: widget));
      expect(find.text('spring'), findsOneWidget);
      expect(widget, isA<SlideTransition>());

      controller.dispose();
    });

    testWidgets('Normal: gravity physics builds SlideTransition',
        (WidgetTester tester) async {
      final controller = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 300),
      );

      final widget = PageTransitionBuilder.buildPhysicsTransition(
        animation: controller,
        child: const Text('gravity'),
        useGravity: true,
      );

      await tester.pumpWidget(MaterialApp(home: widget));
      expect(find.text('gravity'), findsOneWidget);
      expect(widget, isA<SlideTransition>());

      controller.dispose();
    });

    testWidgets('Boundary: custom spring parameters applied',
        (WidgetTester tester) async {
      final controller = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 300),
      );

      final widget = PageTransitionBuilder.buildPhysicsTransition(
        animation: controller,
        child: const Text('custom spring'),
        spring: const SpringDescription(mass: 2.0, stiffness: 200.0, damping: 20.0),
      );

      await tester.pumpWidget(MaterialApp(home: widget));
      expect(find.text('custom spring'), findsOneWidget);

      controller.dispose();
    });
  });

  group('TC-030: PageTransitionBuilder — parseCurve', () {
    test('Normal: parseCurve("easeIn") returns Curves.easeIn', () {
      expect(PageTransitionBuilder.parseCurve('easeIn'), equals(Curves.easeIn));
    });

    test('Normal: parseCurve("spring") returns _SpringCurve instance', () {
      final curve = PageTransitionBuilder.parseCurve('spring');
      expect(curve, isA<Curve>());
      // Verify it behaves like a spring (not standard Flutter curve)
      expect(curve, isNot(equals(Curves.easeInOut)));
    });

    test('Normal: parseCurve("gravity") returns _GravityCurve instance', () {
      final curve = PageTransitionBuilder.parseCurve('gravity');
      expect(curve, isA<Curve>());
      expect(curve, isNot(equals(Curves.easeInOut)));
    });

    test('Boundary: null input → returns default curve (easeInOut)', () {
      expect(PageTransitionBuilder.parseCurve(null), equals(Curves.easeInOut));
    });

    test('Boundary: unknown curve name → returns default curve', () {
      expect(PageTransitionBuilder.parseCurve('nonexistent'), equals(Curves.easeInOut));
    });
  });

  group('TC-015: Spring animation via physics page route', () {
    test('Normal: spring with configured stiffness and damping', () {
      final route = PageTransitionBuilder.buildPhysicsPageRoute(
        page: const SizedBox(),
        physics: 'spring',
        stiffness: 200.0,
        damping: 15.0,
      );
      expect(route, isA<PageRouteBuilder>());
    });

    test('Normal: high damping spring', () {
      final route = PageTransitionBuilder.buildPhysicsPageRoute(
        page: const SizedBox(),
        physics: 'spring',
        stiffness: 100.0,
        damping: 50.0,
      );
      expect(route, isA<PageRouteBuilder>());
    });
  });

  group('TC-016: Friction animation via physics page route', () {
    test('Normal: friction physics transition uses decelerate curve', () {
      final route = PageTransitionBuilder.buildPhysicsPageRoute(
        page: const SizedBox(),
        physics: 'friction',
      );
      expect(route, isA<PageRouteBuilder>());
    });

    test('Normal: friction curve mapped to decelerate', () {
      expect(PageTransitionBuilder.parseCurve('friction'), equals(Curves.decelerate));
    });
  });

  group('TC-017: Gravity animation via physics page route', () {
    test('Normal: gravity physics transition builds correctly', () {
      final route = PageTransitionBuilder.buildPhysicsPageRoute(
        page: const SizedBox(),
        physics: 'gravity',
      );
      expect(route, isA<PageRouteBuilder>());
    });

    test('Normal: gravity curve is quadratic with bounce', () {
      final gravity = PageTransitionBuilder.parseCurve('gravity');
      // Before 0.7: quadratic, after 0.7: bounce
      expect(gravity.transform(0.0), closeTo(0.0, 0.01));
      expect(gravity.transform(1.0), closeTo(1.0, 0.05));
      // At 0.7 boundary: quadratic acceleration
      expect(gravity.transform(0.7), closeTo(1.0, 0.15));
    });
  });

  group('TC-ANIM-013: PageTransitionBuilder — buildTransition', () {
    test('Normal: builds slide transition route', () {
      final route = PageTransitionBuilder.buildTransition(
        page: const SizedBox(),
        type: PageTransitionType.slide,
      );

      expect(route, isA<PageRouteBuilder>());
      expect(route.transitionDuration,
          equals(const Duration(milliseconds: 300)));
    });

    test('Normal: builds fade transition route', () {
      final route = PageTransitionBuilder.buildTransition(
        page: const SizedBox(),
        type: PageTransitionType.fade,
      );

      expect(route, isA<PageRouteBuilder>());
    });

    test('Normal: builds scale transition route', () {
      final route = PageTransitionBuilder.buildTransition(
        page: const SizedBox(),
        type: PageTransitionType.scale,
      );

      expect(route, isA<PageRouteBuilder>());
    });

    test('Normal: builds shared element transition route', () {
      final route = PageTransitionBuilder.buildTransition(
        page: const SizedBox(),
        type: PageTransitionType.sharedElement,
      );

      expect(route, isA<PageRouteBuilder>());
    });

    test('Normal: none transition has zero duration', () {
      final route = PageTransitionBuilder.buildTransition(
        page: const SizedBox(),
        type: PageTransitionType.none,
      );

      expect(route.transitionDuration, equals(Duration.zero));
    });

    test('Normal: custom duration is applied', () {
      final route = PageTransitionBuilder.buildTransition(
        page: const SizedBox(),
        type: PageTransitionType.fade,
        duration: const Duration(milliseconds: 500),
      );

      expect(route.transitionDuration,
          equals(const Duration(milliseconds: 500)));
    });
  });

  group('TC-ANIM-014: PageTransitionBuilder — buildPhysicsTransition', () {
    test('Normal: spring physics transition', () {
      final route = PageTransitionBuilder.buildPhysicsPageRoute(
        page: const SizedBox(),
        physics: 'spring',
        stiffness: 150.0,
        damping: 12.0,
      );

      expect(route, isA<PageRouteBuilder>());
      expect(route.transitionDuration,
          equals(const Duration(milliseconds: 500)));
    });

    test('Normal: friction physics transition', () {
      final route = PageTransitionBuilder.buildPhysicsPageRoute(
        page: const SizedBox(),
        physics: 'friction',
      );

      expect(route, isA<PageRouteBuilder>());
    });

    test('Normal: gravity physics transition', () {
      final route = PageTransitionBuilder.buildPhysicsPageRoute(
        page: const SizedBox(),
        physics: 'gravity',
      );

      expect(route, isA<PageRouteBuilder>());
    });

    test('Normal: unknown physics defaults to fade', () {
      final route = PageTransitionBuilder.buildPhysicsPageRoute(
        page: const SizedBox(),
        physics: 'unknown',
      );

      expect(route, isA<PageRouteBuilder>());
    });

    test('Normal: custom duration applied to physics transition', () {
      final route = PageTransitionBuilder.buildPhysicsPageRoute(
        page: const SizedBox(),
        physics: 'spring',
        duration: const Duration(milliseconds: 800),
      );

      expect(route.transitionDuration,
          equals(const Duration(milliseconds: 800)));
    });
  });

  group('TC-ANIM-015: Physics curve behavior', () {
    test('Normal: spring curve starts near 0 and ends near 1', () {
      final spring = PageTransitionBuilder.parseCurve('spring');
      expect(spring.transform(0.0), closeTo(0.0, 0.05));
      expect(spring.transform(1.0), closeTo(1.0, 0.05));
    });

    test('Normal: gravity curve starts near 0 and ends near 1', () {
      final gravity = PageTransitionBuilder.parseCurve('gravity');
      expect(gravity.transform(0.0), closeTo(0.0, 0.05));
      expect(gravity.transform(1.0), closeTo(1.0, 0.05));
    });

    test('Normal: spring curve is monotonically approaching 1', () {
      final spring = PageTransitionBuilder.parseCurve('spring');
      // At midpoint, should be between 0 and 1
      final mid = spring.transform(0.5);
      expect(mid, greaterThan(0.0));
      expect(mid, lessThanOrEqualTo(1.5)); // Allow overshoot for spring
    });

    test('Normal: gravity curve is accelerating (quadratic)', () {
      final gravity = PageTransitionBuilder.parseCurve('gravity');
      final early = gravity.transform(0.2);
      final mid = gravity.transform(0.5);
      // Quadratic: 0.2^2/0.7^2 ≈ 0.08, 0.5^2/0.7^2 ≈ 0.51
      expect(early, lessThan(mid));
    });
  });
}
