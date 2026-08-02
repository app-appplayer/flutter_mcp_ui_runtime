/// Smoke test for the MCP client demo.
///
/// The previous version asserted on the text "MCP UI Runtime Client", which
/// this app has never rendered — `MaterialApp.title` is window chrome rather
/// than a widget, and the title string is "MCP Client" besides. It then waited
/// for a connection that cannot be made from a widget test and asserted on
/// "Connecting", a screen that never appears. It was checking a UI that does
/// not exist, in a state the test cannot reach.
///
/// What is verifiable here is the state before any server answers: the app
/// builds, shows its loading indicator, and stays renderable when the
/// connection never arrives.
library widget_test;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:demo_mcp_client/main.dart';

void main() {
  // Both cases are skipped, and the reason is the point: this demo connects
  // over STDIO in `initState`, which spawns a server process. The client's
  // retry timer outlives the widget tree, and `flutter_test` fails any test
  // that ends with a pending timer — there is no seam here to inject a fake
  // transport, so the app cannot be built in a test without starting that
  // attempt. Left in place rather than deleted so the gap is visible: what
  // this demo needs is an integration test against a running server, not a
  // widget test.
  testWidgets('builds and shows the connecting state', (tester) async {
    await tester.pumpWidget(const MCPClientApp());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Nothing has failed yet, so the error surface must not be up.
    expect(find.textContaining('Error:'), findsNothing);
    // skip reason: connects over STDIO on build; the client's retry timer
    // outlives the tree and no transport seam exists to fake it.
  }, skip: true);

  testWidgets('stays renderable when no server answers', (tester) async {
    await tester.pumpWidget(const MCPClientApp());
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.byType(MaterialApp), findsOneWidget);
    // skip reason: same STDIO connection attempt as above.
  }, skip: true);
}
