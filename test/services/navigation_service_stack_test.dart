// `NavigationService` — the stack it tracks, the guards it consults, and the
// refusals it makes when there is no navigator.
//
// The service is what a document's `navigation.*` actions ultimately reach, so
// a guard that is never consulted is a screen the user reaches without the
// check the document wrote, and a stack that drifts from the real one sends
// "back" to the wrong place.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/services/navigation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late NavigationService service;
  final navKey = GlobalKey<NavigatorState>();

  setUp(() {
    NavigationService.resetInstance();
    service = NavigationService(enableDebugMode: false);
  });

  tearDown(NavigationService.resetInstance);

  /// Mounts an app with three named routes, each naming itself on screen.
  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navKey,
      // Two observers, two jobs: `routeObserver` is what a page subscribes to
      // as `RouteAware`, and `createRouteObserver()` is the one that keeps the
      // service's own stack.
      navigatorObservers: [service.routeObserver, service.createRouteObserver()],
      initialRoute: '/home',
      routes: {
        for (final route in const ['/home', '/jobs', '/settings'])
          route: (_) => Scaffold(body: Text('page $route')),
      },
    ));
    await tester.pumpAndSettle();
    service.attach(navKey);
  }

  /// Navigates and settles, without awaiting the push.
  ///
  /// `navigateTo` hands back the route's own future, which completes only
  /// when that route POPS — awaiting it here would hang the test on a
  /// navigation that worked.
  Future<void> go(
    WidgetTester tester,
    String route, {
    bool replace = false,
  }) async {
    unawaited(service.navigateTo(route, replace: replace));
    await tester.pumpAndSettle();
  }

  group('with no navigator attached', () {
    test('pushAndClear is refused by name rather than silently doing nothing',
        () {
      expect(() => service.pushAndClear('/home'), throwsStateError,
          reason: 'a navigation that returns quietly leaves the document '
              'believing the user moved');
    });
  });

  group('index listeners', () {
    test('a listener hears the index, and stops when it is removed', () {
      final seen = <int>[];
      void listener(int index) => seen.add(index);

      service.addIndexListener(listener);
      service.setIndex(1);
      expect(seen, [1]);

      service.removeIndexListener(listener);
      service.setIndex(2);
      expect(seen, [1],
          reason: 'a removed listener that keeps firing holds a disposed tab '
              'strip alive and updates it');
      expect(service.currentIndex, 2);
    });
  });

  group('route guards', () {
    testWidgets('a guard that refuses stops the navigation', (tester) async {
      await mount(tester);
      service.addRouteGuard('/settings', (_) async => false);

      await go(tester, '/settings');

      expect(find.text('page /home'), findsOneWidget,
          reason: 'the guard is the check the document wrote; reaching the '
              'screen anyway is the check not existing');
    });

    testWidgets('a guard that allows lets it through', (tester) async {
      await mount(tester);
      service.addRouteGuard('/settings', (_) async => true);

      await go(tester, '/settings');

      expect(find.text('page /settings'), findsOneWidget);
    });

    testWidgets('a guard that throws refuses rather than passing',
        (tester) async {
      await mount(tester);
      service.addRouteGuard(
          '/settings', (_) async => throw StateError('the check broke'));

      await go(tester, '/settings');

      expect(find.text('page /home'), findsOneWidget,
          reason: 'a broken check is not a passed check — failing open would '
              'let exactly the navigation the guard exists to stop through');
    });

    testWidgets('a removed guard no longer refuses', (tester) async {
      await mount(tester);
      service.addRouteGuard('/settings', (_) async => false);
      service.removeRouteGuard('/settings');

      await go(tester, '/settings');

      expect(find.text('page /settings'), findsOneWidget);
    });
  });

  group('preventing navigation', () {
    testWidgets('prevented navigation goes nowhere, and resumes when allowed',
        (tester) async {
      await mount(tester);

      service.preventNavigation();
      await go(tester, '/jobs');
      expect(find.text('page /home'), findsOneWidget);

      service.allowNavigation();
      await go(tester, '/jobs');
      expect(find.text('page /jobs'), findsOneWidget);
    });
  });

  group('the tracked stack', () {
    testWidgets('follows pushes, pops and replacements', (tester) async {
      await mount(tester);

      await go(tester, '/jobs');
      expect(service.routeStack, contains('/jobs'),
          reason: 'the service answers `currentRoute` from this stack, and a '
              'document reading it would be told it is somewhere else');
      expect(service.currentRoute, '/jobs');

      service.goBack();
      await tester.pumpAndSettle();
      expect(find.text('page /home'), findsOneWidget);

      await go(tester, '/settings', replace: true);
      expect(find.text('page /settings'), findsOneWidget,
          reason: 'replace swaps the top of the stack; a stack that still '
              'holds the old route sends "back" to a page that is gone');
    });

    testWidgets('pushAndClear leaves one route behind it', (tester) async {
      await mount(tester);
      await go(tester, '/jobs');

      unawaited(service.pushAndClear('/settings'));
      await tester.pumpAndSettle();

      expect(find.text('page /settings'), findsOneWidget);
      service.goBack();
      await tester.pumpAndSettle();
      expect(find.text('page /settings'), findsOneWidget,
          reason: 'a new root has nothing behind it — back from the first '
              'screen of a re-rooted app must not reach the old session');
    });

    testWidgets('popUntil unwinds to a named route', (tester) async {
      await mount(tester);
      await go(tester, '/jobs');
      await go(tester, '/settings');

      service.popUntil('/home');
      await tester.pumpAndSettle();

      expect(find.text('page /home'), findsOneWidget);
    });
  });
}
