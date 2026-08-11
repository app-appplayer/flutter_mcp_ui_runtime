// The application shell — the chrome a multi-page bundle actually runs inside.
//
// `navigation.type` picks between a bottom bar, tabs, a rail and a drawer, and
// each one was uncovered: the tab strip nobody had clicked, the rail whose hit
// area has a written history of being wrong, the drawer that has to close
// behind itself. Below them sit the page loader's three states (loading,
// loaded, failed) and the launch route — a shell that ignores it opens every
// station on the first tab.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/mcp_ui_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MCPUIRuntime runtime;

  setUp(() => runtime = MCPUIRuntime(enableDebugMode: false));
  tearDown(() {
    NavigationActionExecutor.clearOnExitCallback();
    return runtime.dispose();
  });

  Map<String, dynamic> application({
    required String navigationType,
    String initialRoute = '/home',
  }) =>
      {
        'type': 'application',
        'title': 'Field Kit',
        'version': '1.0.0',
        'initialRoute': initialRoute,
        'routes': {
          '/home': 'home',
          '/jobs': 'jobs',
          '/settings': 'settings',
        },
        'navigation': {
          'type': navigationType,
          'items': [
            {'title': 'Home', 'route': '/home', 'icon': 'home'},
            {'title': 'Jobs', 'route': '/jobs', 'icon': 'list'},
            {'title': 'Settings', 'route': '/settings', 'icon': 'settings'},
          ],
        },
      };

  /// A loader that answers a page naming itself, so the body identifies the
  /// tab that is showing.
  Future<Map<String, dynamic>> pageFor(String route) async => {
        'type': 'page',
        'content': {'type': 'text', 'content': 'page: $route'},
      };

  Future<void> mount(
    WidgetTester tester,
    Map<String, dynamic> definition, {
    Future<Map<String, dynamic>> Function(String)? loader,
  }) async {
    await runtime.initialize(definition, pageLoader: loader ?? pageFor);
    await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  group('bottomNavigation', () {
    testWidgets('every item gets a destination, and tapping one switches the '
        'body', (tester) async {
      await mount(tester, application(navigationType: 'bottomNavigation'));

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('Home'), findsWidgets);
      expect(find.text('Jobs'), findsWidgets);
      expect(find.text('page: home'), findsOneWidget);

      await tester.tap(find.text('Jobs').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('page: jobs'), findsOneWidget,
          reason: 'a tab strip that highlights the tap and leaves the body '
              'alone is the failure a user reports as "it does nothing"');
    });

    testWidgets('the selected index is remembered in state', (tester) async {
      await mount(tester, application(navigationType: 'bottomNavigation'));

      await tester.tap(find.text('Settings').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(runtime.stateManager.get('runtime.navigation.currentIndex'), 2,
          reason: 'the shell reads this back on the next launch — without it a '
              'reopened app always lands on the first tab');
    });
  });

  group('tabs', () {
    testWidgets('a tab bar is built and switching shows the other page',
        (tester) async {
      await mount(tester, application(navigationType: 'tabs'));

      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('page: home'), findsOneWidget);

      await tester.tap(find.text('Jobs').last);
      await tester.pumpAndSettle();

      expect(find.text('page: jobs'), findsOneWidget);
    });
  });

  group('rail', () {
    testWidgets('a tap on the LABEL selects, not only on the icon',
        (tester) async {
      // Written history: Material's NavigationRail swallows hits over the
      // whole tile but only fires on the icon column, so the label read as a
      // no-op. The shell renders its own tiles for exactly this.
      await mount(tester, application(navigationType: 'rail'));

      expect(find.text('page: home'), findsOneWidget);

      await tester.tap(find.text('Jobs').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('page: jobs'), findsOneWidget,
          reason: 'the whole tile — icon, label and padding — is one target');
    });
  });

  group('drawer', () {
    testWidgets('opens, switches the body, and closes behind itself',
        (tester) async {
      await mount(tester, application(navigationType: 'drawer'));

      final scaffold = tester.firstState<ScaffoldState>(find.byType(Scaffold));
      scaffold.openDrawer();
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsOneWidget);
      expect(find.text('Jobs'), findsWidgets);

      await tester.tap(find.text('Jobs').last);
      await tester.pumpAndSettle();

      expect(find.text('page: jobs'), findsOneWidget);
      expect(find.byType(Drawer), findsNothing,
          reason: 'leaving the drawer open over the page it just opened means '
              'the user has to dismiss it before seeing what they chose');
    });
  });

  group('the launch route', () {
    testWidgets('selects the tab that carries it', (tester) async {
      await mount(tester,
          application(navigationType: 'bottomNavigation', initialRoute: '/jobs'));

      expect(find.text('page: jobs'), findsOneWidget,
          reason: 'three stations opening the same app at /kiosk, /pos and '
              '/kds must each land where they asked');
    });

    testWidgets('a declared route with no tab is pushed over the shell',
        (tester) async {
      await runtime.initialize({
        'type': 'application',
        'title': 'Field Kit',
        'version': '1.0.0',
        'initialRoute': '/deep',
        'routes': {'/home': 'home', '/deep': 'deep'},
        'navigation': {
          'type': 'bottomNavigation',
          'items': [
            {'title': 'Home', 'route': '/home', 'icon': 'home'},
          ],
        },
      }, pageLoader: pageFor);

      await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      // The deep target is pushed OVER the shell, so it is what is on screen;
      // the tab strip is underneath and back returns to it. (Asserting the
      // strip is visible would be asserting the push did not happen.)
      expect(find.text('page: deep'), findsOneWidget,
          reason: 'a scanned or deep-linked route that is declared but has no '
              'tab must still open — otherwise the launch parameter is '
              'silently ignored');
      expect(tester.takeException(), isNull);
    });
  });

  group('the page loader', () {
    testWidgets('a slow page shows a spinner until it arrives',
        (tester) async {
      final gate = Completer<Map<String, dynamic>>();
      await runtime.initialize(
        application(navigationType: 'bottomNavigation'),
        pageLoader: (route) => gate.future,
      );
      await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.byType(CircularProgressIndicator), findsWidgets,
          reason: 'a blank body while a page loads reads as an app that '
              'failed to open');

      gate.complete({
        'type': 'page',
        'content': {'type': 'text', 'content': 'arrived'},
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('arrived'), findsOneWidget);
    });

    testWidgets('a page that fails to load says so instead of staying blank',
        (tester) async {
      await runtime.initialize(
        application(navigationType: 'bottomNavigation'),
        pageLoader: (route) async => throw StateError('404 from the server'),
      );
      await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(find.text('Failed to load page'), findsOneWidget);
      expect(find.textContaining('404'), findsOneWidget,
          reason: 'the server\'s own message is what turns "it broke" into '
              'something a support call can act on');
    });
  });

  group('the host close button', () {
    testWidgets('is absent when the host wired no exit', (tester) async {
      await mount(tester, application(navigationType: 'tabs'));
      expect(find.byTooltip('Close'), findsNothing,
          reason: 'a close button on a host that cannot close anything is a '
              'dead control');
    });

    testWidgets('appears when the host wired one, and calls it',
        (tester) async {
      var exits = 0;
      NavigationActionExecutor.setOnExitCallback(() => exits++);

      await mount(tester, application(navigationType: 'tabs'));

      expect(find.byTooltip('Close'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pump();
      expect(exits, 1, reason: '§2.8.1 / §4.3.2 — the host owns the exit');
    });
  });

  group('the launch route', () {
    testWidgets('a saved index is where the shell reopens', (tester) async {
      await runtime.initialize(
        application(navigationType: 'bottomNavigation'),
        pageLoader: pageFor,
      );
      // What the previous session left behind.
      runtime.stateManager.set('runtime.navigation.currentIndex', 2);

      await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(find.text('page: settings'), findsOneWidget,
          reason: 'the saved index is what makes a reopened app land where '
              'the user left it');
    });

    testWidgets('a saved index past the end is ignored', (tester) async {
      await runtime.initialize(
        application(navigationType: 'bottomNavigation'),
        pageLoader: pageFor,
      );
      runtime.stateManager.set('runtime.navigation.currentIndex', 99);

      await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(find.text('page: home'), findsOneWidget,
          reason: 'state written by a document with more tabs must not index '
              'past the end of this one');
    });

    testWidgets('a launch route with no tab is pushed over the shell',
        (tester) async {
      await mount(
        tester,
        <String, dynamic>{
          ...application(navigationType: 'bottomNavigation'),
          'initialRoute': '/deep',
          'routes': <String, dynamic>{
            '/home': 'home',
            '/jobs': 'jobs',
            '/settings': 'settings',
            '/deep': 'deep',
          },
        },
      );
      await tester.pumpAndSettle();

      expect(find.text('page: deep'), findsOneWidget,
          reason: 'a scanned or deep-linked target is declared but usually '
              'has no tab; opening the first tab instead loses the scan');
    });
  });

  group('the page loader', () {
    testWidgets('a route with no page behind it shows the error page',
        (tester) async {
      await mount(
        tester,
        application(navigationType: 'bottomNavigation'),
        loader: (route) async => throw StateError('no such page'),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Error'), findsWidgets,
          reason: 'a blank tab reads as a page that is still loading; the '
              'failure has to be visible');
    });
  });
  group('a tab whose route is not in the route table', () {
    testWidgets('reports it on that tab, and the others still open',
        (tester) async {
      await mount(tester, <String, dynamic>{
        ...application(navigationType: 'tabs'),
        'routes': <String, dynamic>{'/home': 'home', '/jobs': 'jobs'},
      });
      await tester.pumpAndSettle();

      expect(find.text('page: home'), findsOneWidget);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to load page'), findsOneWidget,
          reason: 'a tab wired to a route nobody declared is an authoring '
              'mistake; a blank tab reads as a page that failed to load and '
              'says nothing about which route was missing');
      expect(find.textContaining('/settings'), findsWidgets);
    });

    testWidgets('a tab whose page never arrives shows it is loading',
        (tester) async {
      final gate = Completer<Map<String, dynamic>>();
      await runtime.initialize(
        application(navigationType: 'tabs'),
        pageLoader: (route) =>
            route == '/home' ? pageFor(route) : gate.future,
      );
      await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
      // Fixed pumps rather than `pumpAndSettle`: the spinner on the pending
      // tab animates forever, so nothing ever settles while it is on screen.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      await tester.tap(find.text('Jobs'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(find.byType(CircularProgressIndicator), findsWidgets,
          reason: 'a tab that goes blank while its page loads reads as a tab '
              'with nothing on it');

      gate.complete(await pageFor('/jobs'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.text('page: /jobs'), findsOneWidget);
    });
  });

  // A bundle with no `navigation` block is the ordinary single-screen app —
  // one route, no chrome. It takes its own branch, and the three states of
  // the page load are the whole of what a user sees while it opens.
  group('an application with no navigation block', () {
    Map<String, dynamic> single({String initialRoute = '/home'}) =>
        <String, dynamic>{
          'type': 'application',
          'title': 'Field Kit',
          'version': '1.0.0',
          'initialRoute': initialRoute,
          'routes': <String, dynamic>{'/home': 'home', '/jobs': 'jobs'},
        };

    testWidgets('opens its launch route with no chrome around it',
        (tester) async {
      await mount(tester, single());
      await tester.pumpAndSettle();

      expect(find.text('page: home'), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing,
          reason: 'a bundle that declared no navigation must not be given '
              'any; an empty bar takes a strip of the screen and does '
              'nothing');
    });

    testWidgets('shows a loading state until the page arrives',
        (tester) async {
      final gate = Completer<Map<String, dynamic>>();
      await runtime.initialize(single(), pageLoader: (_) => gate.future);
      await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets,
          reason: 'a blank screen while a page loads reads as a bundle that '
              'failed to open');

      gate.complete(<String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{'type': 'text', 'content': 'page: home'},
      });
      await tester.pumpAndSettle();

      expect(find.text('page: home'), findsOneWidget);
    });

    testWidgets('a loader that fails puts the failure on screen',
        (tester) async {
      await mount(
        tester,
        single(),
        loader: (route) async => throw StateError('no such page'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed to load page'), findsOneWidget,
          reason: 'a page that never arrives and says nothing is the hardest '
              'kind of failure to act on');
      expect(find.textContaining('no such page'), findsOneWidget);
    });

  });
}
