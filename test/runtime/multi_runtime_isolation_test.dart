// Two documents on screen at once — a player with two apps open, a dashboard,
// a studio preview beside the editor — each act on their own.
//
// Measured before the fix, with two applications side by side:
// - a navigation action in A moved B: the navigator came from a process-wide
//   slot that answered for whichever runtime attached last;
// - a shell's route → tab handler sat in one process-wide slot, so the last
//   shell registered handled every runtime's navigation;
// - dialogs used one process-wide service and navigator, so "one dialog at a
//   time" spanned every runtime and a dialog opened on the other app's page;
// - the theme was one object, so the app set up last painted both;
// - a runtime put where another had been kept the first one's widget state:
//   the new engine was never marked ready and stayed on the progress
//   indicator.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/mcp_ui_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _app(
  String name, {
  Map<String, dynamic>? theme,
  Map<String, dynamic>? navigation,
}) =>
    {
      'type': 'application',
      'title': name,
      'version': '1.0.0',
      'initialRoute': '/',
      'routes': {'/': 'home', '/next': 'next'},
      if (theme != null) 'theme': theme,
      if (navigation != null) 'navigation': navigation,
    };

Map<String, dynamic> _home(String name) => {
      'type': 'page',
      'content': {
        'type': 'linear',
        'direction': 'vertical',
        'children': [
          {'type': 'text', 'content': '$name HOME'},
          {
            'type': 'button',
            'label': '$name GO',
            'onTap': {'type': 'navigation', 'action': 'push', 'route': '/next'},
          },
          {
            'type': 'button',
            'label': '$name ASK',
            'onTap': {
              'type': 'dialog',
              'dialog': {
                'type': 'alertDialog',
                'title': '$name DIALOG',
                'content': 'hello',
              },
            },
          },
        ],
      },
    };

Map<String, dynamic> _next(String name) => {
      'type': 'page',
      'content': {'type': 'text', 'content': '$name NEXT'},
    };

void main() {
  late List<MCPUIRuntime> runtimes;

  setUp(() => runtimes = []);
  tearDown(() async {
    for (final r in runtimes) {
      await r.dispose();
    }
  });

  Future<MCPUIRuntime> start(Map<String, dynamic> app, String name) async {
    final runtime = MCPUIRuntime(enableDebugMode: false);
    runtimes.add(runtime);
    await runtime.initialize(app,
        pageLoader: (uri) async =>
            uri.contains('next') ? _next(name) : _home(name));
    return runtime;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> sideBySide(
      WidgetTester tester, MCPUIRuntime a, MCPUIRuntime b) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Row(children: [
        Expanded(
            child: KeyedSubtree(key: const ValueKey('A'), child: a.buildUI())),
        Expanded(
            child: KeyedSubtree(key: const ValueKey('B'), child: b.buildUI())),
      ]),
    ));
    await settle(tester);
  }

  Finder inside(String side, Finder finder) =>
      find.descendant(of: find.byKey(ValueKey(side)), matching: finder);

  group('navigation acts on the runtime that asked', () {
    for (final tapped in ['A', 'B']) {
      testWidgets('tapping $tapped moves only $tapped', (tester) async {
        final a = await start(_app('A'), 'A');
        final b = await start(_app('B'), 'B');
        await sideBySide(tester, a, b);

        await tester.tap(find.text('$tapped GO'));
        await settle(tester);

        final other = tapped == 'A' ? 'B' : 'A';
        expect(find.text('$tapped NEXT'), findsOneWidget);
        expect(find.text('$other NEXT'), findsNothing,
            reason: 'the other document must not move');
        expect(find.text('$other HOME'), findsOneWidget);
      });
    }

    testWidgets('an action with no widget behind it (a hook, a timer, a host '
        'call) still moves its own runtime', (tester) async {
      final a = await start(_app('A'), 'A');
      final b = await start(_app('B'), 'B');
      await sideBySide(tester, a, b);

      // No build context: nothing to find a nearby navigator from. B attached
      // last, so the process-wide key points at B.
      // ignore: unawaited_futures
      a.engine.actionHandler.execute(
        {'type': 'navigation', 'action': 'push', 'route': '/next'},
        a.engine.renderer.createRootContext(null),
      );
      await settle(tester);

      expect(find.text('A NEXT'), findsOneWidget);
      expect(find.text('B HOME'), findsOneWidget);
    });

    testWidgets('two shells each handle their own routes', (tester) async {
      Map<String, dynamic> shell() => {
            'type': 'bottomNavigation',
            'items': [
              {'title': 'Home', 'route': '/', 'icon': 'home'},
              {'title': 'Next', 'route': '/next', 'icon': 'list'},
            ],
          };
      final a = await start(_app('A', navigation: shell()), 'A');
      final b = await start(_app('B', navigation: shell()), 'B');
      await sideBySide(tester, a, b);

      await tester.tap(find.text('A GO'));
      await settle(tester);

      expect(find.text('A NEXT'), findsOneWidget);
      expect(find.text('B HOME'), findsOneWidget,
          reason: 'the shell registered last must not take A\'s navigation');
    });
  });

  testWidgets('a dialog opens on its own document, and each may have one',
      (tester) async {
    final a = await start(_app('A'), 'A');
    final b = await start(_app('B'), 'B');
    await sideBySide(tester, a, b);

    await tester.tap(find.text('A ASK'));
    await settle(tester);
    expect(inside('A', find.text('A DIALOG')), findsOneWidget);
    expect(inside('B', find.text('A DIALOG')), findsNothing);

    await tester.tap(find.text('B ASK'));
    await settle(tester);
    expect(inside('B', find.text('B DIALOG')), findsOneWidget,
        reason: 'a dialog open in A is no reason to refuse one in B');
  });

  testWidgets('a runtime put where another was comes up and runs its own tools',
      (tester) async {
    final calls = <String>[];
    Map<String, dynamic> page() => {
          'type': 'page',
          'content': {
            'type': 'button',
            'label': 'Ping',
            'onTap': {'type': 'tool', 'tool': 'ping', 'params': {}},
          },
        };
    final a = MCPUIRuntime(enableDebugMode: false);
    final b = MCPUIRuntime(enableDebugMode: false);
    runtimes.addAll([a, b]);
    await a.initialize(page());
    await b.initialize(page());

    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: a.buildUI(onToolCall: (t, p) async => calls.add('A:$t')))));
    await settle(tester);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: b.buildUI(onToolCall: (t, p) async => calls.add('B:$t')))));
    await settle(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text('Ping'));
    await settle(tester);
    expect(calls, ['B:ping']);
  });

  testWidgets('each document draws with its own theme', (tester) async {
    final a = await start(
        _app('A', theme: {
          'mode': 'light',
          'color': {'primary': '#FF0000'},
        }),
        'A');
    final b = await start(
        _app('B', theme: {
          'mode': 'light',
          'color': {'primary': '#0000FF'},
        }),
        'B');
    await sideBySide(tester, a, b);

    Color primaryOf(String text) =>
        Theme.of(tester.element(find.text(text))).colorScheme.primary;
    expect(primaryOf('A HOME'), const Color(0xFFFF0000));
    expect(primaryOf('B HOME'), const Color(0xFF0000FF));
    expect(identical(a.engine.themeManager, b.engine.themeManager), isFalse);
  });
}
