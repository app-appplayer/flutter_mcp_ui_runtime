// `MCPUIRuntime` as a host holds it: the refusals before initialization, the
// notification router, the trust level a host sets before the document
// arrives, and the dashboard card.
//
// These are the API a host calls, not the one a document declares — so every
// uncovered line here is a host integration that would fail at run time with
// nothing in the suite to catch it.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/mcp_ui_runtime.dart';
import 'package:flutter_mcp_ui_runtime/src/permissions/trust_level.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('before initialize', () {
    test('buildUI is refused rather than drawing an empty screen', () {
      final runtime = MCPUIRuntime();
      addTearDown(runtime.dispose);

      expect(runtime.buildUI, throwsStateError,
          reason: 'a host that builds too early gets a named error rather '
              'than a blank page it has to diagnose');
    });

    test('registering a resource subscription is refused', () {
      final runtime = MCPUIRuntime();
      addTearDown(runtime.dispose);

      expect(() => runtime.registerResourceSubscription('ui://x', 'binding'),
          throwsStateError);
      expect(() => runtime.unregisterResourceSubscription('ui://x'),
          throwsStateError);
    });

    test('a trust level set early is applied once the document arrives',
        () async {
      final runtime = MCPUIRuntime();
      addTearDown(runtime.dispose);

      runtime.setTrustLevel(TrustLevel.full);
      await runtime.initialize({
        'type': 'page',
        'content': {'type': 'box'},
      });

      expect(runtime.permissionManager?.trustLevel, TrustLevel.full,
          reason: 'a host decides the trust level from who it is talking to, '
              'which it knows before the definition has been fetched — '
              'dropping it would silently downgrade every document');
    });
  });

  group('the notification router', () {
    test('a resource update is read and stored at its binding', () async {
      final runtime = MCPUIRuntime();
      addTearDown(runtime.dispose);
      await runtime.initialize({
        'type': 'page',
        'content': {'type': 'box'},
      });
      runtime.registerResourceSubscription('ui://rows', 'rows');

      await runtime.handleNotification(
        {
          'method': 'notifications/resources/updated',
          'params': {'uri': 'ui://rows'},
        },
        // Standard mode: the notification says only that the resource
        // changed, and the HOST fetches it.
        resourceReader: (uri) async => '{"count": 3}',
      );

      expect(runtime.stateManager.get('rows'), {'count': 3},
          reason: 'a subscription that is told the resource changed and never '
              'reads it leaves the screen on the old value');
    });

    test('a notification carrying the content skips the read', () async {
      final runtime = MCPUIRuntime();
      addTearDown(runtime.dispose);
      await runtime.initialize({
        'type': 'page',
        'content': {'type': 'box'},
      });
      runtime.registerResourceSubscription('ui://rows', 'rows');

      var reads = 0;
      await runtime.handleNotification(
        {
          'method': 'notifications/resources/updated',
          'params': {
            'uri': 'ui://rows',
            'content': {'text': '{"count": 5}'},
          },
        },
        resourceReader: (uri) async {
          reads++;
          return '{}';
        },
      );

      expect(runtime.stateManager.get('rows'), {'count': 5});
      expect(reads, 0,
          reason: 'a round trip for data the notification already carried is '
              'a round trip per update');
    });

    test('an update for a uri nobody subscribed to is ignored', () async {
      final runtime = MCPUIRuntime();
      addTearDown(runtime.dispose);
      await runtime.initialize({
        'type': 'page',
        'content': {'type': 'box'},
      });

      await runtime.handleNotification(
        {
          'method': 'notifications/resources/updated',
          'params': {'uri': 'ui://nobody'},
        },
        resourceReader: (uri) async => '{"count": 3}',
      );

      expect(runtime.stateManager.state.containsKey('count'), isFalse);
    });

    test('a notification for something else is ignored, not an error',
        () async {
      final runtime = MCPUIRuntime();
      addTearDown(runtime.dispose);
      await runtime.initialize({
        'type': 'page',
        'content': {'type': 'box'},
      });

      await runtime.handleNotification({'method': 'notifications/progress'});

      expect(runtime.isInitialized, isTrue,
          reason: 'a host forwards every notification it receives; the ones '
              'this runtime does not know about are not failures');
    });

    test('a notification with no params is ignored', () async {
      final runtime = MCPUIRuntime();
      addTearDown(runtime.dispose);
      await runtime.initialize({
        'type': 'page',
        'content': {'type': 'box'},
      });

      await runtime
          .handleNotification({'method': 'notifications/resources/updated'});
      expect(runtime.isInitialized, isTrue);
    });
  });

  // A page written as `{appBar, body}` — the platform-independent shape the
  // widget below has a whole branch for — is refused by `PageDefinition`
  // before it ever reaches that branch ("Page must have content defined").
  // The branch is therefore unreachable from any definition a host can pass
  // in. Recorded rather than exercised; which of the two should give way is a
  // spec call.

  group('the dashboard card (§11.9.3)', () {
    tearDown(NavigationActionExecutor.clearOnOpenAppCallback);

    Map<String, dynamic> application({Map<String, dynamic> dashboard = const {}}) => {
          'type': 'application',
          'title': 'Field Kit',
          'version': '1.0.0',
          'initialRoute': '/home',
          'routes': {'/home': 'home'},
          'dashboard': {
            'content': {'type': 'text', 'content': 'two jobs open'},
            ...dashboard,
          },
        };

    testWidgets('renders its content', (tester) async {
      final runtime = MCPUIRuntime();
      addTearDown(runtime.dispose);
      await runtime.initialize(application(),
          pageLoader: (route) async => {
                'type': 'page',
                'content': {'type': 'box'},
              });

      await tester.pumpWidget(MaterialApp(home: runtime.buildDashboard()));
      await tester.pump();

      expect(find.text('two jobs open'), findsOneWidget);
    });

    testWidgets('a tap on the card runs its onTap', (tester) async {
      final runtime = MCPUIRuntime();
      addTearDown(runtime.dispose);
      await runtime.initialize(
          application(dashboard: {
            'onTap': {
              'type': 'state',
              'action': 'set',
              'binding': 'opened',
              'value': true,
            },
          }),
          pageLoader: (route) async => {
                'type': 'page',
                'content': {'type': 'box'},
              });

      await tester.pumpWidget(MaterialApp(home: runtime.buildDashboard()));
      await tester.pump();
      await tester.tap(find.text('two jobs open'));
      await tester.pump();

      expect(runtime.stateManager.get('opened'), isTrue,
          reason: '§11.9.3 — the card is a shortcut into the app, and a card '
              'that cannot be tapped is a picture of one');
    });

    testWidgets('the host\'s openApp callback is live while it is shown',
        (tester) async {
      var opened = 0;
      final runtime = MCPUIRuntime();
      addTearDown(runtime.dispose);
      await runtime.initialize(application(),
          pageLoader: (route) async => {
                'type': 'page',
                'content': {'type': 'box'},
              });

      await tester.pumpWidget(MaterialApp(
        home: runtime.buildDashboard(onOpenApp: (id, route) => opened++),
      ));
      await tester.pump();

      // Through the action the document would fire, which is the only path
      // that proves the callback is actually installed.
      await runtime.engine.actionHandler.execute(
        {'type': 'navigation', 'action': 'openApp', 'appId': 'field-kit'},
        runtime.engine.renderer.createRootContext(null),
      );

      expect(opened, 1,
          reason: 'the callbacks are static, so another runtime mounting over '
              'this one can clear them — the dashboard re-asserts its own on '
              'every build');
    });

    testWidgets('a refresh interval rebuilds the card', (tester) async {
      final runtime = MCPUIRuntime();
      addTearDown(runtime.dispose);
      await runtime.initialize(
          {
            'type': 'application',
            'title': 'Field Kit',
            'version': '1.0.0',
            'initialRoute': '/home',
            'routes': {'/home': 'home'},
            'dashboard': {
              'refreshInterval': 100,
              'content': {'type': 'text', 'content': '{{count}} jobs'},
            },
            'state': {
              'initial': {'count': 1},
            },
          },
          pageLoader: (route) async => {
                'type': 'page',
                'content': {'type': 'box'},
              });

      await tester.pumpWidget(MaterialApp(home: runtime.buildDashboard()));
      await tester.pump();
      expect(find.text('1 jobs'), findsOneWidget);

      runtime.engine.stateManager.set('count', 2);
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('2 jobs'), findsOneWidget,
          reason: '§11.9.3 — a card declaring a refresh interval and never '
              'refreshing shows yesterday\'s number');
    });
  });
}
