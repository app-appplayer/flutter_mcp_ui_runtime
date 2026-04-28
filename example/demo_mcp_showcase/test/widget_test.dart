// Widget test for the MCP UI Showcase app.
//
// MCPUIRuntime.initialize uses real-time timers (debounce/rate limiter)
// which fake_async cannot advance. Tests must use `tester.runAsync` to
// let real time flow during the initialization phase; afterwards
// pumpAndSettle can complete normally.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:demo_mcp_showcase/main.dart';

void main() {
  testWidgets('Showcase app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MCPShowcaseApp());

    // Initial frame shows loading indicator while _initializeRuntime runs.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Allow real time to flow so the async runtime initialization
    // (including internal timers) can complete.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 800));
    });

    // Flush the setState that fires after initialization completes.
    await tester.pump();
    await tester.pump();

    // Settle any remaining finite animations (e.g. AnimatedTheme).
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );

    expect(find.text('Welcome to MCP UI DSL v1.0 Showcase'), findsOneWidget);
  });
}
