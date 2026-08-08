// Two documents can be on screen at once — a launcher opening a second app
// over the first, a harness pushing a probe over a running one. Each runtime
// builds its own `MaterialApp` when the document declares routes, and the key
// for that app's navigator came from a process-wide singleton, so the second
// mount put the SAME GlobalKey in two places. Flutter's answer to that is to
// truncate: the second page never appears and the first is torn out of its
// parent, with one `Duplicate GlobalKey` line in the log as the only trace.
//
// Measured live on a built host: a screen-reading gate opened its bundle, was
// told `ok`, and read the launcher — the wrong screen, reported as a pass.

import 'package:flutter/material.dart';
// The LIVE runtime is `src/mcp_ui_runtime.dart` — the one the package
// exports. `src/runtime/mcp_ui_runtime.dart` is an unexported copy, and a fix
// applied there changes nothing that ships (cost me a build to learn).
import 'package:flutter_mcp_ui_runtime/src/mcp_ui_runtime.dart';
import 'package:flutter_mcp_ui_runtime/src/services/navigation_service.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> routedApp(String title) => {
      'type': 'application',
      'title': title,
      'version': '1.0.0',
      'initialRoute': '/',
      'routes': {'/': '/pages/main'},
      'state': {'initial': <String, dynamic>{}},
    };

Map<String, dynamic> page(String text) => {
      'type': 'page',
      'content': {'type': 'text', 'text': text},
    };

void main() {
  testWidgets('two mounted runtimes do not share one navigator key',
      (tester) async {
    final first = MCPUIRuntime();
    final second = MCPUIRuntime();
    addTearDown(() async {
      await first.destroy();
      await second.destroy();
    });

    await first.initialize(routedApp('first'),
        pageLoader: (uri) async => page('first page'));
    await second.initialize(routedApp('second'),
        pageLoader: (uri) async => page('second page'));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          Expanded(child: Builder(builder: (c) => first.buildUI(context: c))),
          Expanded(child: Builder(builder: (c) => second.buildUI(context: c))),
        ]),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    // Two failures hide here, and both are reported through the error hook:
    // the duplicate GlobalKey (one key, two mounted apps → the tree truncates
    // at the second) and `observer.navigator == null` (a RouteObserver may be
    // attached to one navigator at a time, so a shared one asserts the moment
    // the second document mounts).
    expect(tester.takeException(), isNull,
        reason: 'a second mounted runtime must not collide with the first');
  });

  test('each engine owns its navigator key and route observer', () {
    final a = MCPUIRuntime();
    final b = MCPUIRuntime();
    expect(a.navigatorKey, isNot(same(b.navigatorKey)));
    expect(a.engine.routeObserver, isNot(same(b.engine.routeObserver)));
  });

  test('a runtime attaches its own key, and the last one attached wins', () {
    final service = NavigationService.instance;
    final before = service.navigatorKey;

    final mine = GlobalKey<NavigatorState>();
    service.attach(mine);
    expect(service.navigatorKey, same(mine),
        reason: 'navigation actions must act on the app in front');
    expect(service.navigatorKey, isNot(same(before)));

    // Idempotent: attaching the same key again is not a change.
    service.attach(mine);
    expect(service.navigatorKey, same(mine));

    service.attach(before); // leave the singleton as it was found
  });
}
