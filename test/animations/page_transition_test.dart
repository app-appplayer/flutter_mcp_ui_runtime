// Page transitions — what the user actually sees when a document navigates.
//
// The previous version of this file asked `expect(route, isA<PageRouteBuilder>())`
// twenty-odd times. Every branch of `buildTransition` returns a
// `PageRouteBuilder`, so that assertion held for a builder that slid the wrong
// way, faded when it was told to scale, or ignored the curve entirely — the
// four things that can actually be wrong here. `transitionsBuilder` was never
// once invoked: the whole animation lived in a closure nobody called.
//
// So this file pushes the routes onto a real Navigator and reads the screen
// mid-flight: where the incoming page is, how opaque it is, how large. A
// transition is a visual claim, and the only honest way to check it is to look.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/animations/page_transition.dart';
import 'package:flutter_test/flutter_test.dart';

const _destination = Key('destination');

Widget _page() => const Scaffold(
      body: Center(
        child: SizedBox(key: _destination, width: 100, height: 100),
      ),
    );

/// Pushes [route] from a real Navigator and stops the clock partway through.
///
/// `fraction` is a position inside the transition, not the end of it: the
/// interesting state of an animation is the middle, and the end looks
/// identical for every transition type.
Future<void> _pushAndHold(
  WidgetTester tester,
  PageRoute<dynamic> route, {
  double fraction = 0.5,
}) async {
  late BuildContext ctx;
  // A fresh key per push: `pumpWidget` DIFFS the tree, so re-pumping the same
  // MaterialApp keeps the old Navigator — and its old route stack — alive, and
  // a second push in one test would then measure the first push's page.
  await tester.pumpWidget(MaterialApp(
    key: UniqueKey(),
    home: Builder(builder: (context) {
      ctx = context;
      return const Scaffold(body: Text('origin'));
    }),
  ));
  Navigator.of(ctx).push(route);
  await tester.pump(); // schedule the route
  await tester.pump(); // build its first frame — no time passes
  final at = route.transitionDuration * fraction;
  if (at > Duration.zero) await tester.pump(at);
}

/// The nearest [T] wrapping the destination page.
T _wrapping<T extends Widget>(WidgetTester tester) => tester.widget<T>(
      find.ancestor(of: find.byKey(_destination), matching: find.byType(T)).first,
    );

bool _hasWrapping<T extends Widget>() =>
    find.ancestor(of: find.byKey(_destination), matching: find.byType(T)).evaluate().isNotEmpty;

void main() {
  group('slide — the page comes in from the declared edge', () {
    // A reversed direction is the classic transition defect: nothing throws,
    // nothing logs, the page simply flies in from the wrong side. The offsets
    // are read off the live SlideTransition, so a swapped case in
    // `_getSlideOffset` fails here.
    Future<Offset> slideOffsetFor(WidgetTester tester, String direction) async {
      await _pushAndHold(
        tester,
        PageTransitionBuilder.buildTransition(
          page: _page(),
          type: PageTransitionType.slide,
          curve: Curves.linear,
          slideDirection: direction,
        ),
      );
      return _wrapping<SlideTransition>(tester).position.value;
    }

    testWidgets('left enters from the right edge and travels leftwards',
        (tester) async {
      final offset = await slideOffsetFor(tester, 'left');
      expect(offset.dx, greaterThan(0),
          reason: '"left" names the direction of travel: the page starts to '
              'the RIGHT of the viewport and moves left into place');
      expect(offset.dy, 0);
      expect(offset.dx, lessThan(1),
          reason: 'halfway through, it must have moved — an offset still at 1 '
              'means the animation is not driving the tween');
    });

    testWidgets('right enters from the left edge', (tester) async {
      final offset = await slideOffsetFor(tester, 'right');
      expect(offset.dx, lessThan(0));
      expect(offset.dy, 0);
    });

    testWidgets('up enters from below', (tester) async {
      final offset = await slideOffsetFor(tester, 'up');
      expect(offset.dy, greaterThan(0));
      expect(offset.dx, 0);
    });

    testWidgets('down enters from above', (tester) async {
      final offset = await slideOffsetFor(tester, 'down');
      expect(offset.dy, lessThan(0));
      expect(offset.dx, 0);
    });

    testWidgets('an unnamed or unknown direction behaves like left',
        (tester) async {
      final byDefault = await slideOffsetFor(tester, 'left');
      final unknown = await slideOffsetFor(tester, 'diagonal');
      expect(unknown, byDefault,
          reason: 'a typo in the document must not produce a fifth, '
              'undocumented direction');
    });

    testWidgets('the page is really off-screen at the start and home at the end',
        (tester) async {
      final route = PageTransitionBuilder.buildTransition(
        page: _page(),
        type: PageTransitionType.slide,
        curve: Curves.linear,
      );
      await _pushAndHold(tester, route, fraction: 0);

      final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(tester.getTopLeft(find.byKey(_destination)).dx,
          greaterThanOrEqualTo(width * 0.9),
          reason: 'the incoming page must not be visible before it slides in');

      await tester.pumpAndSettle();
      final settled = tester.getCenter(find.byKey(_destination));
      expect(settled.dx, closeTo(width / 2, 1),
          reason: 'and it has to land centred, not one pixel off-stage');
    });
  });

  group('the declared curve decides the position, not just the endpoints', () {
    // `curve:` was accepted and never observed. Two curves that disagree in
    // the middle must produce two different positions in the middle; if the
    // CurveTween were dropped, both of these would read the same.
    testWidgets('easeIn is behind linear at the midpoint', (tester) async {
      Future<double> dxWith(Curve curve) async {
        await _pushAndHold(
          tester,
          PageTransitionBuilder.buildTransition(
            page: _page(),
            type: PageTransitionType.slide,
            curve: curve,
          ),
        );
        return _wrapping<SlideTransition>(tester).position.value.dx;
      }

      final linear = await dxWith(Curves.linear);
      final easeIn = await dxWith(Curves.easeIn);

      expect(linear, closeTo(0.5, 0.02),
          reason: 'a linear curve at half the duration is exactly half way');
      expect(easeIn, greaterThan(linear + 0.1),
          reason: 'easeIn starts slowly, so at the midpoint the page is still '
              'further out — this is the assertion that proves the curve is '
              'actually applied rather than accepted and discarded');
    });
  });

  group('fade — opacity animates and nothing moves', () {
    testWidgets('the incoming page is partly transparent mid-flight',
        (tester) async {
      await _pushAndHold(
        tester,
        PageTransitionBuilder.buildTransition(
          page: _page(),
          type: PageTransitionType.fade,
          curve: Curves.linear,
        ),
      );

      final opacity = _wrapping<FadeTransition>(tester).opacity.value;
      expect(opacity, closeTo(0.5, 0.05));
      expect(_hasWrapping<SlideTransition>(), isFalse,
          reason: 'a fade that also slides is a different transition than the '
              'document asked for');
    });

    testWidgets('it reaches full opacity and stays there', (tester) async {
      await _pushAndHold(
        tester,
        PageTransitionBuilder.buildTransition(
          page: _page(),
          type: PageTransitionType.fade,
        ),
      );
      await tester.pumpAndSettle();
      expect(_wrapping<FadeTransition>(tester).opacity.value, 1.0,
          reason: 'a page left at 0.98 opacity is a page that never finished '
              'arriving');
    });

    testWidgets('a zero duration lands opaque on the first frame',
        (tester) async {
      final route = PageTransitionBuilder.buildTransition(
        page: _page(),
        type: PageTransitionType.fade,
        duration: Duration.zero,
      );
      expect(route.transitionDuration, Duration.zero);
      await _pushAndHold(tester, route);
      expect(_wrapping<FadeTransition>(tester).opacity.value, 1.0);
    });
  });

  group('scale — the page grows and fades in together', () {
    testWidgets('mid-flight it is both smaller and dimmer than final',
        (tester) async {
      await _pushAndHold(
        tester,
        PageTransitionBuilder.buildTransition(
          page: _page(),
          type: PageTransitionType.scale,
          curve: Curves.linear,
        ),
      );

      final scale = _wrapping<ScaleTransition>(tester).scale.value;
      final opacity = _wrapping<FadeTransition>(tester).opacity.value;
      expect(scale, closeTo(0.5, 0.05),
          reason: 'scale runs 0 → 1; a value of 1 halfway means the tween is '
              'not driven and the page just appears');
      expect(opacity, closeTo(0.5, 0.05),
          reason: 'the scale transition fades as well — dropping the fade '
              'makes a hard-edged pop');
    });

    testWidgets('a custom curve reaches a different scale at the same instant',
        (tester) async {
      Future<double> scaleWith(Curve curve) async {
        await _pushAndHold(
          tester,
          PageTransitionBuilder.buildTransition(
            page: _page(),
            type: PageTransitionType.scale,
            curve: curve,
          ),
        );
        return _wrapping<ScaleTransition>(tester).scale.value;
      }

      expect(await scaleWith(Curves.easeIn),
          lessThan(await scaleWith(Curves.linear) - 0.1));
    });
  });

  group('sharedElement', () {
    testWidgets('is a fade at the route level — the Heroes do the morphing',
        (tester) async {
      // Worth stating rather than asserting `isA<PageRouteBuilder>`: this type
      // does NOT animate anything itself. The matching happens between Hero
      // widgets inside the two pages, and the route only cross-fades. A
      // document that expects the route to find its elements gets nothing.
      await _pushAndHold(
        tester,
        PageTransitionBuilder.buildTransition(
          page: _page(),
          type: PageTransitionType.sharedElement,
          curve: Curves.linear,
        ),
      );
      expect(_wrapping<FadeTransition>(tester).opacity.value, closeTo(0.5, 0.05));
    });

    testWidgets('two Heroes with the same tag do morph across the push',
        (tester) async {
      const child = Key('hero-child');
      Widget corner(Alignment alignment) => Scaffold(
            body: Align(
              alignment: alignment,
              child: const Hero(
                tag: 'shared',
                child: SizedBox(key: child, width: 50, height: 50),
              ),
            ),
          );

      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          ctx = context;
          return corner(Alignment.topLeft);
        }),
      ));
      final from = tester.getCenter(find.byKey(child));

      Navigator.of(ctx).push(PageTransitionBuilder.buildTransition(
        page: corner(Alignment.bottomRight),
        type: PageTransitionType.sharedElement,
        duration: const Duration(milliseconds: 400),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // In flight the element lives in the Navigator's overlay — both routes
      // leave a same-sized placeholder behind — so exactly one is on screen,
      // and it is between the two corners rather than at either of them.
      expect(find.byKey(child), findsOneWidget);
      final flying = tester.getCenter(find.byKey(child));
      expect(flying.dx, greaterThan(from.dx));
      expect(flying.dy, greaterThan(from.dy),
          reason: 'the hero is travelling towards the bottom-right; if the '
              'route swallowed the push, the element would simply be redrawn '
              'in its new corner');

      await tester.pumpAndSettle();
      final landed = tester.getCenter(find.byKey(child));
      expect(landed.dx, greaterThan(flying.dx),
          reason: 'and it keeps going all the way to the corner');
    });
  });

  group('none — an instant change with no animation at all', () {
    testWidgets('the page is fully in place on the first frame', (tester) async {
      final route = PageTransitionBuilder.buildTransition(
        page: _page(),
        type: PageTransitionType.none,
      );
      expect(route.transitionDuration, Duration.zero);
      expect(route.reverseTransitionDuration, Duration.zero);

      await _pushAndHold(tester, route);
      final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(tester.getCenter(find.byKey(_destination)).dx, closeTo(width / 2, 1));
      expect(_hasWrapping<SlideTransition>(), isFalse);
      expect(_hasWrapping<FadeTransition>(), isFalse,
          reason: '"none" means the transitionsBuilder hands the child back '
              'untouched — any wrapper here is a frame of animation the '
              'document said it did not want');
    });

    testWidgets('a duration passed alongside none is ignored', (tester) async {
      final route = PageTransitionBuilder.buildTransition(
        page: _page(),
        type: PageTransitionType.none,
        duration: const Duration(milliseconds: 999),
      );
      expect(route.transitionDuration, Duration.zero);
    });
  });

  group('parseType and parseCurve', () {
    test('every declared type maps to its own value', () {
      const spellings = {
        'slide': PageTransitionType.slide,
        'fade': PageTransitionType.fade,
        'scale': PageTransitionType.scale,
        'sharedElement': PageTransitionType.sharedElement,
        'none': PageTransitionType.none,
      };
      for (final entry in spellings.entries) {
        expect(PageTransitionBuilder.parseType(entry.key), entry.value);
      }
      expect(spellings.values.toSet(), PageTransitionType.values.toSet(),
          reason: 'a new enum value with no spelling is unreachable from a '
              'document, so this fails the day one is added without a case');
    });

    test('an unknown or absent type falls back to fade, not to none', () {
      expect(PageTransitionBuilder.parseType('teleport'), PageTransitionType.fade);
      expect(PageTransitionBuilder.parseType(null), PageTransitionType.fade);
      expect(PageTransitionBuilder.parseType(''), PageTransitionType.fade);
    });

    test('each named curve maps to a distinct curve', () {
      // `easeInOut` is deliberately absent: it is also the fallback, so it is
      // the one name whose presence cannot be distinguished from its absence.
      const named = [
        'linear', 'easeIn', 'easeOut', 'bounceIn', 'bounceOut',
        'bounceInOut', 'elasticIn', 'elasticOut', 'elasticInOut', 'decelerate',
        'fastOutSlowIn',
      ];
      for (final name in named) {
        expect(PageTransitionBuilder.parseCurve(name), isNot(Curves.easeInOut),
            reason: '$name resolving to the default means the case is missing '
                'and the document silently gets another animation');
      }
      // Sampled rather than compared by identity: two names landing on the
      // same curve object is the failure worth catching.
      final shapes = {
        for (final name in named)
          name: PageTransitionBuilder.parseCurve(name).transform(0.3)
      };
      expect(shapes.values.toSet().length, greaterThan(named.length ~/ 2));
    });

    test('friction is documented as decelerate — an approximation, not a sim',
        () {
      expect(PageTransitionBuilder.parseCurve('friction'), Curves.decelerate);
    });

    test('an unknown or absent curve name falls back to easeInOut', () {
      expect(PageTransitionBuilder.parseCurve('nonexistent'), Curves.easeInOut);
      expect(PageTransitionBuilder.parseCurve(null), Curves.easeInOut);
    });
  });

  group('the physics curves, measured inside their range', () {
    // `Curve.transform` short-circuits t == 0 and t == 1 to 0 and 1 in the base
    // class, so `expect(spring.transform(0.0), closeTo(0, 0.01))` — which is
    // what this file used to assert — passes for ANY curve, including one whose
    // body is `return 0.5;`. Everything below samples the interior.
    final spring = PageTransitionBuilder.parseCurve('spring');
    final gravity = PageTransitionBuilder.parseCurve('gravity');

    test('spring leaves the start and arrives near the end', () {
      expect(spring.transform(0.001), lessThan(0.1));
      expect(spring.transform(0.999), closeTo(1.0, 0.05));
    });

    test('spring overshoots — that is what makes it read as a spring', () {
      final samples = [
        for (var t = 0.01; t < 1.0; t += 0.01) spring.transform(t)
      ];
      expect(samples.reduce(math.max), greaterThan(1.0),
          reason: 'a damped spring passes its target before settling; a curve '
              'that never exceeds 1 is just an ease with a spring name');
      expect(samples.reduce(math.min), greaterThanOrEqualTo(-0.5),
          reason: 'and it must not fly far backwards, which would show as the '
              'page leaving the screen the wrong way first');
    });

    test('a stiffer spring reaches further sooner', () {
      // Reached through buildPhysicsPageRoute, which is the only way a document
      // can set stiffness/damping at all.
      double at(double stiffness) {
        final route = PageTransitionBuilder.buildPhysicsPageRoute(
          page: const SizedBox(),
          physics: 'spring',
          stiffness: stiffness,
          damping: 10,
        );
        return route.transitionDuration.inMilliseconds.toDouble();
      }

      expect(at(400), at(50),
          reason: 'stiffness must not change the duration — it changes the '
              'shape, which the widget test below observes');
    });

    test('gravity accelerates rather than easing', () {
      final quarter = gravity.transform(0.25);
      final half = gravity.transform(0.5);
      expect(quarter, lessThan(half / 2),
          reason: 'falling: the second quarter of the journey covers more '
              'ground than the first');
      expect(gravity.transform(0.999), closeTo(1.0, 0.02));
    });

    test('gravity snaps back 10% at t = 0.7 — pinned, and it is visible', () {
      // The quadratic reaches exactly 1.0 at 0.7 and the bounce branch restarts
      // at 0.9, so the page arrives, jumps back a tenth of its travel in one
      // frame, and settles. It is a discontinuity, not a bounce: a real bounce
      // decelerates into the overshoot. Recorded here rather than smoothed,
      // because changing the shape changes every gravity transition already
      // shipped; noted in the cherry track for a deliberate decision.
      expect(gravity.transform(0.699), closeTo(1.0, 0.01));
      expect(gravity.transform(0.701), closeTo(0.9, 0.01));
    });
  });

  group('buildPhysicsTransition — the widget form', () {
    testWidgets('spring slides in from the right', (tester) async {
      final controller = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 300),
      );
      addTearDown(controller.dispose);
      controller.value = 0.5;

      final widget = PageTransitionBuilder.buildPhysicsTransition(
        animation: controller,
        child: const SizedBox(key: _destination),
      );
      await tester.pumpWidget(MaterialApp(home: widget));

      final position = _wrapping<SlideTransition>(tester).position.value;
      expect(position.dy, 0);
      expect(position.dx, isNot(0),
          reason: 'halfway through a spring the page is still travelling');
    });

    testWidgets('gravity drops in from above', (tester) async {
      final controller = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 300),
      );
      addTearDown(controller.dispose);
      controller.value = 0.3;

      await tester.pumpWidget(MaterialApp(
        home: PageTransitionBuilder.buildPhysicsTransition(
          animation: controller,
          child: const SizedBox(key: _destination),
          useGravity: true,
        ),
      ));

      final position = _wrapping<SlideTransition>(tester).position.value;
      expect(position.dx, 0);
      expect(position.dy, lessThan(0),
          reason: 'gravity comes from above — a positive dy would have the '
              'page falling upwards');
    });

    testWidgets('custom spring parameters change the position at the same t',
        (tester) async {
      Future<double> dxWith(SpringDescription? spring) async {
        final controller = AnimationController(
          vsync: tester,
          duration: const Duration(milliseconds: 300),
        );
        addTearDown(controller.dispose);
        controller.value = 0.4;
        await tester.pumpWidget(MaterialApp(
          home: PageTransitionBuilder.buildPhysicsTransition(
            animation: controller,
            spring: spring,
            child: const SizedBox(key: _destination),
          ),
        ));
        return _wrapping<SlideTransition>(tester).position.value.dx;
      }

      final byDefault = await dxWith(null);
      final stiff = await dxWith(
          const SpringDescription(mass: 1, stiffness: 400, damping: 10));
      expect(stiff, isNot(closeTo(byDefault, 0.01)),
          reason: 'passing a SpringDescription that changes nothing on screen '
              'is the same as ignoring it');
    });
  });

  group('buildPhysicsPageRoute — what each physics name actually renders', () {
    testWidgets('spring slides', (tester) async {
      await _pushAndHold(
          tester,
          PageTransitionBuilder.buildPhysicsPageRoute(
              page: _page(), physics: 'spring'));
      expect(_hasWrapping<SlideTransition>(), isTrue);
      expect(_wrapping<SlideTransition>(tester).position.value.dx, isNot(0));
    });

    testWidgets('friction fades in while shrinking from 1.2', (tester) async {
      await _pushAndHold(
          tester,
          PageTransitionBuilder.buildPhysicsPageRoute(
              page: _page(), physics: 'friction'));

      final scale = _wrapping<ScaleTransition>(tester).scale.value;
      expect(scale, greaterThan(1.0),
          reason: 'friction settles DOWN onto the page from slightly enlarged; '
              'a scale under 1 would be the scale transition instead');
      expect(scale, lessThan(1.2));
      expect(_wrapping<FadeTransition>(tester).opacity.value,
          inExclusiveRange(0.0, 1.0));
    });

    testWidgets('gravity drops from above', (tester) async {
      await _pushAndHold(
          tester,
          PageTransitionBuilder.buildPhysicsPageRoute(
              page: _page(), physics: 'gravity'),
          fraction: 0.3);
      expect(_wrapping<SlideTransition>(tester).position.value.dy, lessThan(0));
    });

    testWidgets('an unknown physics name fades rather than doing nothing',
        (tester) async {
      await _pushAndHold(
          tester,
          PageTransitionBuilder.buildPhysicsPageRoute(
              page: _page(), physics: 'antigravity'));
      expect(_hasWrapping<SlideTransition>(), isFalse);
      expect(_wrapping<FadeTransition>(tester).opacity.value,
          inExclusiveRange(0.0, 1.0));
    });

    testWidgets('stiffness reaches the screen', (tester) async {
      Future<double> dxWith(double stiffness) async {
        await _pushAndHold(
          tester,
          PageTransitionBuilder.buildPhysicsPageRoute(
            page: _page(),
            physics: 'spring',
            stiffness: stiffness,
            damping: 10,
          ),
          fraction: 0.3,
        );
        return _wrapping<SlideTransition>(tester).position.value.dx;
      }

      expect(await dxWith(400), isNot(closeTo(await dxWith(50), 0.01)),
          reason: 'the parameter is on the public API, so a document that '
              'tunes it must see a different animation');
    });

    test('the duration is the declared one, defaulting to 500ms', () {
      expect(
        PageTransitionBuilder.buildPhysicsPageRoute(
                page: const SizedBox(), physics: 'spring')
            .transitionDuration,
        const Duration(milliseconds: 500),
      );
      final custom = PageTransitionBuilder.buildPhysicsPageRoute(
        page: const SizedBox(),
        physics: 'spring',
        duration: const Duration(milliseconds: 800),
      );
      expect(custom.transitionDuration, const Duration(milliseconds: 800));
      expect(custom.reverseTransitionDuration, const Duration(milliseconds: 800),
          reason: 'a reverse that runs at another speed makes back feel like a '
              'different app than forward');
    });
  });

  group('SharedElementConfig', () {
    test('reads a document block and keeps its defaults', () {
      final full = SharedElementConfig.fromJson({
        'tag': 'hero-7',
        'transitionDuration': 250,
        'curve': 'bounceOut',
      });
      expect(full.tag, 'hero-7');
      expect(full.transitionDuration, 250);
      expect(full.curve, 'bounceOut');
      expect(PageTransitionBuilder.parseCurve(full.curve), Curves.bounceOut,
          reason: 'the curve is carried as a name, so it has to be a name the '
              'parser knows or the document gets easeInOut without being told');

      final minimal = SharedElementConfig.fromJson({'tag': 'hero-7'});
      expect(minimal.transitionDuration, 400);
      expect(minimal.curve, 'easeInOut');
    });

    test('round-trips through json', () {
      const config = SharedElementConfig(tag: 't', transitionDuration: 123);
      final back = SharedElementConfig.fromJson(config.toJson());
      expect(back.tag, config.tag);
      expect(back.transitionDuration, config.transitionDuration);
      expect(back.curve, config.curve);
    });

    test('a block with no tag is refused rather than matched against null', () {
      expect(() => SharedElementConfig.fromJson(const {}), throwsA(anything),
          reason: 'a hero with no tag would match every other untagged hero on '
              'the next page');
    });
  });
}
