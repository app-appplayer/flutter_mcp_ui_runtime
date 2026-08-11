import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

/// A launch route has to mean the same thing whether or not the application
/// declares a navigation shell.
///
/// `RouteManager.initialRoute` already carries the contract — the requested
/// route when the document declares it, the document's own otherwise — and the
/// tests that existed asked *the manager*. They passed while the screen showed
/// something else: the shell picked its tab from `appDefinition.initialRoute`
/// and never consulted the manager, so three stations opening the same
/// application at `/kiosk`, `/pos` and `/kds` all drew the first tab.
///
/// These render the shell and assert on what is on screen.
void main() {
  Map<String, dynamic> appWithShell() => <String, dynamic>{
        'type': 'application',
        'title': 'Station App',
        'initialRoute': '/order',
        'routes': <String, dynamic>{
          '/order': 'ui://pages/order',
          '/pos': 'ui://pages/pos',
          '/kds': 'ui://pages/kds',
        },
        'navigation': <String, dynamic>{
          'type': 'tabs',
          'items': <dynamic>[
            <String, dynamic>{'title': 'Order', 'route': '/order'},
            <String, dynamic>{'title': 'POS', 'route': '/pos'},
            <String, dynamic>{'title': 'KDS', 'route': '/kds'},
          ],
        },
      };

  /// Each page renders its own route so the assertion reads the screen, not
  /// the loader: a page that was fetched but not shown must not count.
  Future<MCPUIRuntime> boot({String? launchRoute}) async {
    final runtime = MCPUIRuntime();
    await runtime.initialize(
      appWithShell(),
      pageLoader: (uri) async => <String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{
          'type': 'text',
          'content': 'PAGE ${uri.split('/').last}',
        },
      },
      launchRoute: launchRoute,
    );
    return runtime;
  }

  Future<void> pumpUntilText(WidgetTester tester, String text) async {
    // The shell materializes its body through a future; pump until the text
    // is there rather than for a fixed slice, because a fixed slice is what
    // hid this class of defect in the first place.
    //
    // Bounded by FRAMES, not by the wall clock: a real-time deadline inside a
    // fake-clock test expires because the machine is busy, which is a failure
    // about the test runner rather than about the shell.
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text(text).evaluate().isNotEmpty) return;
    }
  }

  testWidgets('a launch route selects the shell tab it names', (tester) async {
    final runtime = await boot(launchRoute: '/pos');
    await tester.pumpWidget(runtime.buildUI());
    await pumpUntilText(tester, 'PAGE pos');

    expect(find.text('PAGE pos'), findsOneWidget,
        reason: 'the station asked for /pos and must be standing there');
    expect(find.text('PAGE order'), findsNothing);

    await runtime.destroy();
    // Regression (konpi, 2026-08-03): the shell used to pick its tab from
    // `appDefinition.initialRoute` and never consult `RouteManager`, so a
    // launch route was ignored wherever a navigation shell existed — since
    // 0.1.0.
  });

  testWidgets('without a launch route the document decides', (tester) async {
    final runtime = await boot();
    await tester.pumpWidget(runtime.buildUI());
    await pumpUntilText(tester, 'PAGE order');

    expect(find.text('PAGE order'), findsOneWidget);

    await runtime.destroy();
  });

  testWidgets('a launch route the document does not declare is not honoured',
      (tester) async {
    final runtime = await boot(launchRoute: '/nowhere');
    await tester.pumpWidget(runtime.buildUI());
    await pumpUntilText(tester, 'PAGE order');

    // A stale binding must not look like a working one: the document's own
    // initial route is drawn and `launchRouteMissing` reports the request.
    expect(find.text('PAGE order'), findsOneWidget);
    expect(runtime.engine.routeManager!.launchRouteMissing, isTrue);

    await runtime.destroy();
  });
}
