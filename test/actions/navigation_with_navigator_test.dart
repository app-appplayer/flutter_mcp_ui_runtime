// `navigation.*` against a REAL navigator, and the confirmation dialog.
//
// The existing navigation tests run without a navigator attached, which is a
// legitimate case (a headless render reports that nothing moved) but it means
// the entire switch — push, replace, pop, popToRoot, pushAndClear, openApp,
// exitApp, setIndex — had never actually navigated anything. A document's
// buttons are mostly navigation, and the failure mode is a button that looks
// like it worked.
//
// The confirmation dialog in `ActionHandler.execute` was in the same state:
// the gate a `client.*` action passes through before it touches the machine,
// never once shown.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_result.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ActionHandler handler;
  late StateManager stateManager;

  setUp(() {
    handler = ActionHandler();
    stateManager = StateManager()..initialize(<String, dynamic>{});
    NavigationActionExecutor.clearOnExitCallback();
    NavigationActionExecutor.clearOnOpenAppCallback();
  });

  tearDown(() {
    NavigationActionExecutor.clearOnExitCallback();
    NavigationActionExecutor.clearOnOpenAppCallback();
  });

  RenderContext contextFor(BuildContext? buildContext) {
    final registry = WidgetRegistry();
    DefaultWidgets.registerAll(registry);
    final bindingEngine = BindingEngine();
    return RenderContext(
      renderer: Renderer(
        widgetRegistry: registry,
        bindingEngine: bindingEngine,
        actionHandler: handler,
        stateManager: stateManager,
      ),
      stateManager: stateManager,
      bindingEngine: bindingEngine,
      actionHandler: handler,
      themeManager: ThemeManager.instance,
      buildContext: buildContext,
    );
  }

  /// An app on the navigator key the executor reaches for, with named routes.
  Future<RenderContext> mountApp(WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      navigatorKey: NavigationActionExecutor.navigatorKey,
      routes: {
        '/': (context) {
          ctx = context;
          return const Scaffold(body: Text('home'));
        },
        '/details': (context) => const Scaffold(body: Text('details')),
        '/other': (context) => const Scaffold(body: Text('other')),
      },
    ));
    await tester.pumpAndSettle();
    return contextFor(ctx);
  }

  /// Fires the action, lets the frames run, and hands back the pending result.
  ///
  /// NOT awaited internally, and callers must not await a push. `push`,
  /// `replace`, `pushAndClear` and `openApp` all `await` the navigator's own
  /// future, which by Flutter's contract completes when the pushed route is
  /// POPPED — so the ActionResult for a push does not exist until the user
  /// comes back. Worth knowing: a document that hangs `onSuccess` off a push
  /// sees it fire on the user's RETURN, not when the screen opens. Pinned here
  /// rather than changed; it is a contract decision, and the tests below are
  /// written around it.
  Future<ActionResult> nav(
    RenderContext context,
    Map<String, dynamic> action,
  ) =>
      handler.execute(action, context);

  Future<void> settle(WidgetTester tester) => tester.pumpAndSettle();

  group('with a navigator attached', () {
    testWidgets('push opens the named route and pop comes back',
        (tester) async {
      final context = await mountApp(tester);

      nav(context,
          {'type': 'navigation', 'action': 'push', 'route': '/details'});
      await settle(tester);
      expect(find.text('details'), findsOneWidget);
      expect(find.text('home'), findsNothing);

      await nav(context, {'type': 'navigation', 'action': 'pop'});
      await settle(tester);
      expect(find.text('home'), findsOneWidget,
          reason: 'a pop that does not pop leaves a user stuck on a detail '
              'screen with a back button that does nothing');
    });

    testWidgets('the declared params arrive as route arguments', (tester) async {
      Object? received;
      await tester.pumpWidget(MaterialApp(
        navigatorKey: NavigationActionExecutor.navigatorKey,
        routes: {
          '/': (context) => const Scaffold(body: Text('home')),
          '/details': (context) {
            received = ModalRoute.of(context)!.settings.arguments;
            return const Scaffold(body: Text('details'));
          },
        },
      ));
      await tester.pumpAndSettle();

      nav(contextFor(null), {
        'type': 'navigation',
        'action': 'push',
        'route': '/details',
        'params': {'id': 7},
      });
      await settle(tester);

      expect(received, {'id': 7},
          reason: 'the destination reads its subject from the arguments; '
              'dropping them opens the right screen with no data');
    });

    testWidgets('replace swaps the current route rather than stacking',
        (tester) async {
      final context = await mountApp(tester);

      nav(context,
          {'type': 'navigation', 'action': 'push', 'route': '/details'});
      await settle(tester);
      nav(context,
          {'type': 'navigation', 'action': 'replace', 'route': '/other'});
      await settle(tester);
      expect(find.text('other'), findsOneWidget);

      await nav(context, {'type': 'navigation', 'action': 'pop'});
      await settle(tester);
      expect(find.text('home'), findsOneWidget,
          reason: 'replace removed /details, so one pop lands on home — if it '
              'had pushed instead, the user would have to press back twice');
    });

    testWidgets('popToRoot unwinds the whole stack', (tester) async {
      final context = await mountApp(tester);

      nav(context,
          {'type': 'navigation', 'action': 'push', 'route': '/details'});
      await settle(tester);
      nav(context,
          {'type': 'navigation', 'action': 'push', 'route': '/other'});
      await settle(tester);
      await nav(context, {'type': 'navigation', 'action': 'popToRoot'});
      await settle(tester);

      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('pushAndClear leaves nothing to go back to', (tester) async {
      final context = await mountApp(tester);

      nav(context,
          {'type': 'navigation', 'action': 'push', 'route': '/details'});
      await settle(tester);
      nav(context,
          {'type': 'navigation', 'action': 'pushAndClear', 'route': '/other'});
      await settle(tester);
      expect(find.text('other'), findsOneWidget);

      final navigator = NavigationActionExecutor.navigatorKey.currentState!;
      expect(navigator.canPop(), isFalse,
          reason: 'this is what a sign-out or a completed onboarding uses; a '
              'back button into the cleared flow is the bug');
    });

    testWidgets('an unknown action is refused by name', (tester) async {
      final context = await mountApp(tester);
      final result =
          await nav(context, {'type': 'navigation', 'action': 'teleport'});

      expect(result.success, isFalse);
      expect(result.error, contains('teleport'),
          reason: 'with a navigator present the switch is reached, and a typo '
              'has to be named rather than silently doing nothing');
    });

    testWidgets('setIndex needs a shell, and says which piece is missing',
        (tester) async {
      final context = await mountApp(tester);

      final noIndex =
          await nav(context, {'type': 'navigation', 'action': 'setIndex'});
      expect(noIndex.success, isFalse);
      expect(noIndex.error, contains('index'));

      final withIndex = await nav(context,
          {'type': 'navigation', 'action': 'setIndex', 'index': 2});
      expect(withIndex.success, isFalse);
      expect(withIndex.error, contains('navigation handler'),
          reason: 'index-based navigation belongs to the shell that owns the '
              'tab strip; the runtime cannot guess it');
    });

    testWidgets('a route that does not exist fails as a reported error',
        (tester) async {
      final context = await mountApp(tester);
      final result = await nav(context,
          {'type': 'navigation', 'action': 'push', 'route': '/nowhere'});
      await settle(tester);
      tester.takeException();

      expect(result.success, isFalse);
      expect(result.error, contains('Navigation failed'),
          reason: 'an unregistered route throws inside the navigator, and the '
              'document has to receive that as an answer rather than as a '
              'crash out of a button');
    });
  });

  group('openApp and exitApp', () {
    testWidgets('openApp hands off to the host callback when one is wired',
        (tester) async {
      final calls = <List<String?>>[];
      NavigationActionExecutor.setOnOpenAppCallback(
          (appId, route) => calls.add([appId, route]));

      final context = await mountApp(tester);
      final result = await nav(context, {
        'type': 'navigation',
        'action': 'openApp',
        'appId': 'app-7',
        'route': '/app/7',
      });

      expect(result.success, isTrue);
      expect(calls.single, ['app-7', '/app/7']);
      expect(find.text('home'), findsOneWidget,
          reason: 'the host owns the transition — the runtime must not also '
              'push its own route, or the app opens twice');
    });

    testWidgets('with no host callback it clears the stack and opens the route '
        'itself', (tester) async {
      final context = await mountApp(tester);

      nav(context,
          {'type': 'navigation', 'action': 'openApp', 'route': '/details'});
      await settle(tester);

      expect(find.text('details'), findsOneWidget);
      expect(NavigationActionExecutor.navigatorKey.currentState!.canPop(), isFalse,
          reason: '§4.3.1 — leaving the dashboard behind the app would let a '
              'back gesture drop out of the app that was just opened');
    });

    testWidgets('exitApp calls the host callback', (tester) async {
      var exits = 0;
      NavigationActionExecutor.setOnExitCallback(() => exits++);
      expect(NavigationActionExecutor.hasOnExit, isTrue);

      final context = await mountApp(tester);
      final result =
          await nav(context, {'type': 'navigation', 'action': 'exitApp'});

      expect(result.success, isTrue);
      expect(exits, 1);
    });

    testWidgets('exitApp with nobody listening is still an answer, not a crash',
        (tester) async {
      final context = await mountApp(tester);
      expect(NavigationActionExecutor.hasOnExit, isFalse);

      final result =
          await nav(context, {'type': 'navigation', 'action': 'exitApp'});
      expect(result.success, isTrue);
      expect(find.text('home'), findsOneWidget);
    });
  });

  group('a host navigation handler', () {
    testWidgets('takes the route when it accepts it, and the navigator never '
        'moves', (tester) async {
      final context = await mountApp(tester);
      final taken = <String>[];
      handler.registerNavigationHandler((action, route, params) {
        taken.add(route);
        return true;
      });

      final result = await nav(context,
          {'type': 'navigation', 'action': 'push', 'route': '/details'});
      await settle(tester);

      expect(result.success, isTrue);
      expect(taken, ['/details']);
      expect(find.text('home'), findsOneWidget,
          reason: 'a handler that accepted the route has already shown it its '
              'own way; pushing as well would stack two screens');
    });

    testWidgets('declining hands the route to the navigator', (tester) async {
      final context = await mountApp(tester);
      handler.registerNavigationHandler((action, route, params) => false);

      nav(context,
          {'type': 'navigation', 'action': 'push', 'route': '/details'});
      await settle(tester);

      expect(find.text('details'), findsOneWidget,
          reason: 'false means "not mine" — a page not pinned to a tab strip '
              'still has to be reachable from a button or a deep link');
    });
  });

  group('the confirmation gate', () {
    Future<ActionResult> fire(
      WidgetTester tester,
      RenderContext context,
      Map<String, dynamic> action,
    ) {
      final pending = handler.execute(action, context);
      return pending;
    }

    testWidgets('a client action with requireConfirmation asks first, and '
        'Cancel stops it', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          ctx = context;
          return const Scaffold(body: Text('page'));
        }),
      ));
      final context = contextFor(ctx);

      final pending = fire(tester, context, {
        'type': 'client.exec',
        'requireConfirmation': true,
        'command': 'rm -rf /',
      });
      await tester.pumpAndSettle();

      expect(find.text('Confirmation Required'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      final result = await pending;
      expect(result.success, isFalse);
      expect(result.error, contains('cancelled by user'),
          reason: 'the whole point of the gate: declining has to stop the '
              'action, not just close the dialog');
    });

    testWidgets('confirmMessage is what the user is shown', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          ctx = context;
          return const Scaffold(body: Text('page'));
        }),
      ));

      final pending = fire(tester, contextFor(ctx), {
        'type': 'client.exec',
        'confirmMessage': 'This will delete the archive. Continue?',
        'command': 'rm archive',
      });
      await tester.pumpAndSettle();

      expect(find.text('This will delete the archive. Continue?'),
          findsOneWidget,
          reason: 'a generic "are you sure" tells the user nothing about what '
              'they are agreeing to');

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await pending;
    });

    testWidgets('Confirm carries the action on to its executor',
        (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          ctx = context;
          return const Scaffold(body: Text('page'));
        }),
      ));

      // A client verb with no executor behind it: the gate is what is under
      // test, and the two outcomes are then told apart by the error alone.
      // (A verb that really runs — `client.exec` — never returns inside a
      // widget test's fake-async zone, so it cannot be used to measure this.)
      final pending = fire(tester, contextFor(ctx), {
        'type': 'client.nosuchverb',
        'requireConfirmation': true,
      });
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      final result = await pending;
      expect(result.error, contains('Unknown action type'),
          reason: 'the two buttons have to lead somewhere different — a '
              'Confirm that ends the action the same way Cancel does is a '
              'dialog that only ever refuses, and every test here so far '
              'pressed Cancel');
    });

    testWidgets('a non-client action is never gated', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          ctx = context;
          return const Scaffold(body: Text('page'));
        }),
      ));

      final result = await handler.execute({
        'type': 'state',
        'action': 'set',
        'binding': 'x',
        'value': 1,
        'requireConfirmation': true,
      }, contextFor(ctx));
      await tester.pumpAndSettle();

      expect(find.text('Confirmation Required'), findsNothing,
          reason: 'setting state is not a capability; a dialog in front of it '
              'would train the user to tap Confirm without reading');
      expect(result.success, isTrue);
      expect(stateManager.get('x'), 1);
    });

    testWidgets('with no surface to ask on the action proceeds unconfirmed — '
        'pinned', (tester) async {
      // Recorded rather than asserted as desirable. On a headless render there
      // is no BuildContext, the gate is skipped, and the action runs. The
      // permission manager is what refuses in that situation (its own
      // fail-closed branch), so this is not the only line of defence — but a
      // host relying on `requireConfirmation` alone gets nothing here.
      final result = await handler.execute({
        'type': 'client.getSystemInfo',
        'requireConfirmation': true,
      }, contextFor(null));

      expect(result, isNotNull);
      expect(find.text('Confirmation Required'), findsNothing);
    });
  });
}
