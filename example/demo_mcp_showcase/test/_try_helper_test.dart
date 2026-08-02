import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:demo_mcp_showcase/showcase_definition.dart';

/// Pump pattern that tolerates runtime's real-time timers.
Future<void> settleRuntime(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump();
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 3),
  );
}

void main() {
  testWidgets('end-to-end pattern', (tester) async {
    late MCPUIRuntime runtime;
    await tester.runAsync(() async {
      runtime = MCPUIRuntime(enableDebugMode: true);
      await runtime.initialize(
        showcaseDefinition,
        pageLoader: (uri) async => showcasePages[uri] ?? {},
      );
    });
    await tester.pumpWidget(runtime.buildUI());
    await settleRuntime(tester);

    // Verify Scaffold has drawer configured (Drawer widget inflates on open)
    final scaffoldWidget = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffoldWidget.drawer, isNotNull);
    // Home content
    expect(find.text('Welcome to MCP UI DSL v1.4 Showcase'), findsOneWidget);

    // Open drawer, then Drawer appears
    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold).first);
    scaffoldState.openDrawer();
    await settleRuntime(tester);
    expect(find.byType(Drawer), findsOneWidget);

    await runtime.destroy();
  });
}
