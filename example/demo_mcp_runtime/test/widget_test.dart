import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:demo_mcp_runtime/demo_app.dart';

void main() {
  testWidgets('Demo app builds without errors', (WidgetTester tester) async {
    // This test verifies the app can be built and rendered without exceptions
    await tester.pumpWidget(const MCPUIRuntimeDemoApp());

    // Basic verification that the app structure exists
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
    
    // Check for main title
    expect(find.text('MCP UI Runtime Demo'), findsOneWidget);
  });

  testWidgets('App structure is correct', (WidgetTester tester) async {
    await tester.pumpWidget(const MCPUIRuntimeDemoApp());

    // Verify core components exist
    expect(find.textContaining('Runtime Features'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Lifecycle'), findsAtLeastNWidgets(1));
    
    // Verify debug button exists (at least one)
    expect(find.byIcon(Icons.bug_report_outlined), findsAtLeastNWidgets(1));
  });
}