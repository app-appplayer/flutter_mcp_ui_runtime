// RouteManager — what a multi-page document's navigation actually does.
//
// The file this replaces asked whether `routes['/home']` was `isNotNull`. It
// was, in every version of this class, including the ones that could not load
// a page or push a route. What follows drives a real Navigator: routes are
// opened, popped, and opened again with parameters; the loading and failure
// surfaces are rendered; and the page lifecycle hooks are read back from state
// rather than assumed to have run.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ApplicationDefinition appDefinition;
  late RuntimeEngine runtimeEngine;
  late Map<String, Map<String, dynamic>> pages;
  late List<String> loaded;

  /// A page whose body names itself, so the body identifies the route.
  Map<String, dynamic> page(String label, {Map<String, dynamic>? lifecycle}) => {
        'type': 'page',
        'metadata': {'title': label},
        if (lifecycle != null) 'lifecycle': lifecycle,
        'content': {'type': 'text', 'content': 'page: $label'},
      };

  /// Counts a lifecycle hook, so firing it twice is visible rather than
  /// indistinguishable from firing it once.
  List<Map<String, dynamic>> count(String binding) => [
        {
          'type': 'state',
          'action': 'increment',
          'binding': binding,
          'value': 1,
        },
      ];

  setUp(() async {
    appDefinition = ApplicationDefinition(
      title: 'Test App',
      version: '1.0.0',
      initialRoute: '/home',
      routes: const {
        '/home': 'mcp://server/pages/home',
        '/profile': 'mcp://server/pages/profile',
        '/users/:id': 'mcp://server/pages/user-detail',
      },
    );

    runtimeEngine = RuntimeEngine(enableDebugMode: false);
    await runtimeEngine.initialize(definition: {
      'type': 'page',
      'content': {'type': 'box'},
    });

    loaded = [];
    pages = {
      'mcp://server/pages/home': page('home', lifecycle: {
        'onPause': count('pauses'),
        'onResume': count('resumes'),
      }),
      'mcp://server/pages/profile': page('profile'),
      'mcp://server/pages/user-detail': page('user-detail'),
    };
  });

  tearDown(() => runtimeEngine.destroy());

  RouteManager manager({
    String? launchRoute,
    Future<Map<String, dynamic>> Function(String uri)? loader,
  }) =>
      RouteManager(
        appDefinition: appDefinition,
        runtimeEngine: runtimeEngine,
        launchRoute: launchRoute,
        pageLoader: loader ??
            (uri) async {
              loaded.add(uri);
              return pages[uri]!;
            },
      );

  final navKey = GlobalKey<NavigatorState>();

  /// Mounts an app whose routes come from [rm].
  ///
  /// Navigation goes through the navigator key rather than a captured route
  /// context: a pushed route's context is defunct after it pops, and reusing
  /// it is a test artefact, not something a document does.
  Future<void> mount(WidgetTester tester, RouteManager rm) async {
    await tester.pumpWidget(Builder(builder: (outer) {
      return MaterialApp(
        navigatorKey: navKey,
        // The page widget subscribes to this observer; it is how a covered
        // page hears that it was covered.
        navigatorObservers: [NavigationService.instance.routeObserver],
        initialRoute: rm.initialRoute,
        routes: rm.generateRoutes(outer),
        onGenerateRoute: rm.onGenerateRoute,
      );
    }));
    await tester.pumpAndSettle();
  }

  BuildContext navContext() => navKey.currentContext!;

  group('the route table', () {
    testWidgets('every declared route becomes a builder that loads its page',
        (tester) async {
      final rm = manager();
      await mount(tester, rm);

      expect(find.text('page: home'), findsOneWidget,
          reason: 'a route table whose entries build nothing is a table of '
              'blank screens');
      expect(loaded, ['mcp://server/pages/home'],
          reason: 'only the route being shown is fetched');
    });

    testWidgets('a page still loading shows a spinner', (tester) async {
      final gate = Completer<Map<String, dynamic>>();
      final rm = manager(loader: (uri) => gate.future);

      await tester.pumpWidget(Builder(builder: (outer) {
        return MaterialApp(
          initialRoute: '/home',
          routes: rm.generateRoutes(outer),
        );
      }));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget,
          reason: 'a blank screen while a page loads reads as a failure');

      gate.complete(page('home'));
      await tester.pumpAndSettle();
      expect(find.text('page: home'), findsOneWidget);
    });

    testWidgets('a page that fails to load says why', (tester) async {
      final rm = manager(
          loader: (uri) async => throw StateError('404 from the server'));

      await tester.pumpWidget(Builder(builder: (outer) {
        return MaterialApp(
          initialRoute: '/home',
          routes: rm.generateRoutes(outer),
        );
      }));
      await tester.pumpAndSettle();

      expect(find.text('Failed to load page'), findsOneWidget);
      expect(find.textContaining('404 from the server'), findsOneWidget,
          reason: 'the server\'s own message is the difference between "it '
              'broke" and something a support call can act on');
    });

    testWidgets('a loaded page is cached, not re-fetched', (tester) async {
      final rm = manager();
      await mount(tester, rm);

      unawaited(rm.navigateTo(navContext(), '/profile'));
      await tester.pumpAndSettle();
      rm.navigateBack(navContext());
      await tester.pumpAndSettle();
      unawaited(rm.navigateTo(navContext(), '/profile'));
      await tester.pumpAndSettle();

      expect(loaded.where((u) => u.endsWith('profile')).length, 1,
          reason: 'refetching a page the runtime already holds costs a round '
              'trip on every back-and-forth');
    });
  });

  group('route values that need no loader (§1.2.1)', () {
    testWidgets('an inline page is rendered without asking the host',
        (tester) async {
      appDefinition = ApplicationDefinition(
        title: 'T',
        version: '1.0.0',
        initialRoute: '/inline',
        routes: {'/inline': page('inline')},
      );

      await mount(tester, manager());

      expect(find.text('page: inline'), findsOneWidget);
      expect(loaded, isEmpty,
          reason: 'a page the document carries is already here');
    });

    testWidgets('a bare widget definition is wrapped as a page',
        (tester) async {
      appDefinition = ApplicationDefinition(
        title: 'T',
        version: '1.0.0',
        initialRoute: '/inline',
        routes: const {
          '/inline': {'type': 'text', 'content': 'just a widget'},
        },
      );

      await mount(tester, manager());

      expect(find.text('just a widget'), findsOneWidget);
    });

    testWidgets('a transition wrapper renders the page it carries',
        (tester) async {
      appDefinition = ApplicationDefinition(
        title: 'T',
        version: '1.0.0',
        initialRoute: '/wrapped',
        routes: {
          '/wrapped': {
            'page': page('wrapped'),
            'transition': {'type': 'fade'},
          },
        },
      );

      await mount(tester, manager());

      expect(find.text('page: wrapped'), findsOneWidget,
          reason: 'a per-route transition must not cost the page itself');
    });
  });

  group('navigating', () {
    testWidgets('push shows the new page and back returns', (tester) async {
      final rm = manager();
      await mount(tester, rm);

      unawaited(rm.navigateTo(navContext(), '/profile'));
      await tester.pumpAndSettle();
      expect(find.text('page: profile'), findsOneWidget);

      rm.navigateBack(navContext());
      await tester.pumpAndSettle();
      expect(find.text('page: home'), findsOneWidget);
    });

    testWidgets('the covered page is paused exactly once', (tester) async {
      final rm = manager();
      await mount(tester, rm);

      unawaited(rm.navigateTo(navContext(), '/profile'));
      await tester.pumpAndSettle();

      expect(runtimeEngine.stateManager.get('pauses'), 1,
          reason: 'a page that is covered but not paused keeps polling behind '
              'the one the user is looking at; a page paused twice runs its '
              'teardown twice, which is how a subscription gets released out '
              'from under a second subscriber');
    });

    testWidgets('coming back resumes the page underneath, once', (tester) async {
      final rm = manager();
      await mount(tester, rm);

      unawaited(rm.navigateTo(navContext(), '/profile'));
      await tester.pumpAndSettle();
      rm.navigateBack(navContext());
      await tester.pumpAndSettle();

      expect(runtimeEngine.stateManager.get('resumes'), 1,
          reason: 'a page that is uncovered and never resumed shows whatever '
              'it had when it was covered');
    });

    testWidgets('replace swaps the page instead of stacking it',
        (tester) async {
      final rm = manager();
      await mount(tester, rm);

      unawaited(rm.navigateTo(navContext(), '/profile', replace: true));
      await tester.pumpAndSettle();
      expect(find.text('page: profile'), findsOneWidget);

      expect(runtimeEngine.stateManager.get('pauses'), isNull,
          reason: 'a replaced page is gone, not paused — pausing it would '
              'leave a teardown owed on a page nobody can return to');
    });

    testWidgets('parameters are substituted into the route', (tester) async {
      final rm = manager();
      await mount(tester, rm);

      unawaited(rm.navigateTo(navContext(), '/users/:id', params: {'id': '42'}));
      await tester.pumpAndSettle();

      expect(find.text('page: user-detail'), findsOneWidget,
          reason: 'an unsubstituted ":id" reaches the Navigator as a literal '
              'and matches no route at all');
    });

    testWidgets('popToRoot unwinds the whole stack', (tester) async {
      final rm = manager();
      await mount(tester, rm);

      unawaited(rm.navigateTo(navContext(), '/profile'));
      await tester.pumpAndSettle();
      unawaited(rm.navigateTo(navContext(), '/users/:id', params: {'id': '7'}));
      await tester.pumpAndSettle();

      rm.popToRoot(navContext());
      await tester.pumpAndSettle();

      expect(find.text('page: home'), findsOneWidget,
          reason: '"home" from four pages deep has to reach home, not the '
              'page before it');
    });

    testWidgets('back from the root page is not an error', (tester) async {
      final rm = manager();
      await mount(tester, rm);

      rm.navigateBack(navContext());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('the launch route', () {
    test('is honoured when the document declares it', () {
      expect(manager(launchRoute: '/profile').initialRoute, '/profile',
          reason: 'three stations opening one app at /kiosk, /pos and /kds '
              'each have to land where they asked');
    });

    test('is ignored — and reported — when the document does not', () {
      final rm = manager(launchRoute: '/gone');

      expect(rm.initialRoute, '/home');
      expect(rm.launchRouteMissing, isTrue,
          reason: 'a stale deep link that silently lands on the home page '
              'looks exactly like one that worked');
    });

    test('with no launch route the document decides', () {
      final rm = manager();
      expect(rm.initialRoute, '/home');
      expect(rm.launchRouteMissing, isFalse);
    });
  });

  group('parsing a route', () {
    test('a plain path resolves to its page', () {
      final info = manager().parseRoute('/home');

      expect(info.route, '/home');
      expect(info.pathParams, isEmpty);
      expect(info.queryParams, isEmpty);
      expect(info.pageUri, 'mcp://server/pages/home');
    });

    test('path parameters are extracted', () {
      final info = manager().parseRoute('/users/123');

      expect(info.route, '/users/:id');
      expect(info.pathParams['id'], '123');
      expect(info.pageUri, 'mcp://server/pages/user-detail');
    });

    test('query parameters are extracted', () {
      final info = manager().parseRoute('/home?tab=settings&view=list');

      expect(info.route, '/home');
      expect(info.queryParams, {'tab': 'settings', 'view': 'list'});
    });

    test('allParams merges both kinds', () {
      final info = manager().parseRoute('/users/789?edit=true');

      expect(info.allParams, {'id': '789', 'edit': 'true'});
    });

    test('an unknown route is refused rather than guessed at', () {
      expect(() => manager().parseRoute('/unknown'), throwsArgumentError,
          reason: 'falling back to some other route would send the user '
              'somewhere they did not ask for');
    });
  });
}
