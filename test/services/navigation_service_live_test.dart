// `NavigationService` against a mounted navigator.
//
// The existing file covers the parts that need no tree — the key, the index
// listeners, the route table. Everything that actually moves the user was
// uncovered: navigateTo and its three modes, the guards that can refuse a
// route, `preventNavigation`, popUntil, and the dialog / sheet / snackbar
// helpers. This is the service a shell drives, and every failure here is a
// button that appears to work.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/services/navigation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late NavigationService service;

  setUp(() {
    NavigationService.resetInstance();
    service = NavigationService.instance;
  });

  tearDown(NavigationService.resetInstance);

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      navigatorKey: service.navigatorKey,
      routes: {
        '/': (context) => const Scaffold(body: Text('home')),
        '/details': (context) => const Scaffold(body: Text('details')),
        '/other': (context) => const Scaffold(body: Text('other')),
      },
    ));
    await tester.pumpAndSettle();
  }

  group('navigateTo', () {
    testWidgets('opens the route, and its arguments arrive', (tester) async {
      Object? received;
      await tester.pumpWidget(MaterialApp(
        navigatorKey: service.navigatorKey,
        routes: {
          '/': (context) => const Scaffold(body: Text('home')),
          '/details': (context) {
            received = ModalRoute.of(context)!.settings.arguments;
            return const Scaffold(body: Text('details'));
          },
        },
      ));
      await tester.pumpAndSettle();

      service.navigateTo('/details', arguments: {'id': 3});
      await tester.pumpAndSettle();

      expect(find.text('details'), findsOneWidget);
      expect(received, {'id': 3});
    });

    testWidgets('replace: true swaps the current route', (tester) async {
      await mount(tester);

      service.navigateTo('/details');
      await tester.pumpAndSettle();
      service.navigateTo('/other', replace: true);
      await tester.pumpAndSettle();

      expect(find.text('other'), findsOneWidget);
      service.goBack();
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget,
          reason: 'replace removed /details, so one back lands on home');
    });

    testWidgets('clearStack: true leaves nothing behind', (tester) async {
      await mount(tester);

      service.navigateTo('/details');
      await tester.pumpAndSettle();
      service.navigateTo('/other', clearStack: true);
      await tester.pumpAndSettle();

      expect(find.text('other'), findsOneWidget);
      expect(service.canGoBack(), isFalse,
          reason: 'a completed sign-in must not leave the login screen '
              'reachable by a back gesture');
    });

    testWidgets('with no navigator attached it refuses by name',
        (tester) async {
      expect(() => service.navigateTo('/details'),
          throwsA(isA<StateError>()));
      expect(() => service.goBack(), throwsA(isA<StateError>()));
      expect(() => service.popToRoot(), throwsA(isA<StateError>()));
      expect(() => service.popUntil('/x'), throwsA(isA<StateError>()));
      expect(service.canGoBack(), isFalse,
          reason: 'the read-only question answers false rather than throwing, '
              'because a shell asks it on every build');
    });

    testWidgets('a route that is not registered rethrows rather than '
        'swallowing', (tester) async {
      await mount(tester);

      await expectLater(service.navigateTo('/nowhere'), throwsA(anything));
      tester.takeException();
    });
  });

  group('route guards', () {
    testWidgets('a guard that refuses stops the navigation', (tester) async {
      await mount(tester);
      final asked = <Object?>[];
      service.addRouteGuard('/details', (arguments) async {
        asked.add(arguments);
        return false;
      });

      final result = await service.navigateTo('/details', arguments: 'ctx');
      await tester.pumpAndSettle();

      expect(result, isNull);
      expect(asked, ['ctx'],
          reason: 'the guard is handed the arguments so it can decide on the '
              'subject, not just the route');
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('a guard that allows lets it through', (tester) async {
      await mount(tester);
      service.addRouteGuard('/details', (arguments) async => true);

      service.navigateTo('/details');
      await tester.pumpAndSettle();
      expect(find.text('details'), findsOneWidget);
    });

    testWidgets('removing a guard restores plain navigation', (tester) async {
      await mount(tester);
      service.addRouteGuard('/details', (arguments) async => false);
      service.removeRouteGuard('/details');

      service.navigateTo('/details');
      await tester.pumpAndSettle();
      expect(find.text('details'), findsOneWidget);
    });

    testWidgets('a guard on another route does not apply', (tester) async {
      await mount(tester);
      service.addRouteGuard('/other', (arguments) async => false);

      service.navigateTo('/details');
      await tester.pumpAndSettle();
      expect(find.text('details'), findsOneWidget,
          reason: 'a guard that applied to every route would lock the app');
    });
  });

  group('preventNavigation', () {
    testWidgets('holds navigation until it is allowed again', (tester) async {
      await mount(tester);
      service.preventNavigation();

      expect(await service.navigateTo('/details'), isNull);
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget,
          reason: 'this is what a form with unsaved changes switches on');

      expect(await service.pushAndClear('/other'), isNull,
          reason: 'the block covers every entry point, or the one that was '
              'missed becomes the way around it');

      service.allowNavigation();
      service.navigateTo('/details');
      await tester.pumpAndSettle();
      expect(find.text('details'), findsOneWidget);
    });
  });

  group('the stack', () {
    testWidgets('popToRoot unwinds everything', (tester) async {
      await mount(tester);
      service.navigateTo('/details');
      await tester.pumpAndSettle();
      service.navigateTo('/other');
      await tester.pumpAndSettle();

      service.popToRoot();
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('popUntil stops at the named route', (tester) async {
      await mount(tester);
      service.navigateTo('/details');
      await tester.pumpAndSettle();
      service.navigateTo('/other');
      await tester.pumpAndSettle();

      service.popUntil('/details');
      await tester.pumpAndSettle();

      expect(find.text('details'), findsOneWidget,
          reason: 'a "back to the list" action that overshoots to home loses '
              'the user\'s place');
    });

    testWidgets('goBack on the root route does nothing rather than closing '
        'the app', (tester) async {
      await mount(tester);
      expect(service.canGoBack(), isFalse);

      service.goBack();
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('pushAndClear starts a new root', (tester) async {
      await mount(tester);
      service.navigateTo('/details');
      await tester.pumpAndSettle();

      service.pushAndClear('/other', params: {'from': 'details'});
      await tester.pumpAndSettle();

      expect(find.text('other'), findsOneWidget);
      expect(service.canGoBack(), isFalse);
    });
  });

  group('the overlay helpers', () {
    testWidgets('showDialogModal opens a dialog and returns its answer',
        (tester) async {
      await mount(tester);

      final pending = service.showDialogModal<String>(
        builder: (context) => AlertDialog(
          content: const Text('Are you sure?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('yes'),
              child: const Text('Yes'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Are you sure?'), findsOneWidget);

      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      expect(await pending, 'yes',
          reason: 'the answer is the entire point of a modal — a dialog that '
              'closes without reporting leaves the caller waiting');
    });

    testWidgets('showBottomSheet opens a sheet and returns its answer',
        (tester) async {
      await mount(tester);

      final pending = service.showBottomSheet<int>(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).pop(7),
          child: const Text('Pick 7'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pick 7'), findsOneWidget);

      await tester.tap(find.text('Pick 7'));
      await tester.pumpAndSettle();
      expect(await pending, 7);
    });

    testWidgets('showSnackBar puts the message on screen', (tester) async {
      await mount(tester);

      service.showSnackBar(message: 'Saved');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets('the overlay helpers refuse when nothing is mounted',
        (tester) async {
      expect(
        () => service.showDialogModal<void>(builder: (_) => const SizedBox()),
        throwsA(isA<StateError>()),
      );
      expect(
        () => service.showBottomSheet<void>(builder: (_) => const SizedBox()),
        throwsA(isA<StateError>()),
      );
      expect(() => service.showSnackBar(message: 'x'),
          throwsA(isA<StateError>()),
          reason: 'a message that goes nowhere has to be reported, or a host '
              'believes the user was told');
    });
  });

  group('the route observer', () {
    testWidgets('follows the stack as routes come and go', (tester) async {
      final observer = service.createRouteObserver();

      await tester.pumpWidget(MaterialApp(
        navigatorKey: service.navigatorKey,
        navigatorObservers: [observer],
        routes: {
          '/': (context) => const Scaffold(body: Text('home')),
          '/details': (context) => const Scaffold(body: Text('details')),
        },
      ));
      await tester.pumpAndSettle();

      service.navigateTo('/details');
      await tester.pumpAndSettle();
      expect(service.routeStack, contains('/details'));
      expect(service.currentRoute, '/details',
          reason: 'a shell highlighting the current tab reads this');

      service.goBack();
      await tester.pumpAndSettle();
      expect(service.routeStack, isNot(contains('/details')),
          reason: 'a stack that only grows makes "where am I" unanswerable');
    });
  });
}
