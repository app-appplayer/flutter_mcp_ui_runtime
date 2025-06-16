import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:demo_mcp_runtime/demo_app.dart';

void main() {
  group('Basic Demo Tests', () {
    testWidgets('Demo app builds without errors', (WidgetTester tester) async {
      // This test just verifies the app can be built without throwing exceptions
      await tester.pumpWidget(const MCPUIRuntimeDemoApp());
      
      // Basic verification that something rendered
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
    });

    testWidgets('App has main title', (WidgetTester tester) async {
      await tester.pumpWidget(const MCPUIRuntimeDemoApp());
      await tester.pumpAndSettle();
      
      // Check for the main title
      expect(find.textContaining('MCP UI Runtime Demo'), findsAtLeastNWidgets(1));
    });

    testWidgets('Debug panel button exists', (WidgetTester tester) async {
      await tester.pumpWidget(const MCPUIRuntimeDemoApp());
      await tester.pumpAndSettle();
      
      // Check for debug button
      expect(find.byIcon(Icons.bug_report_outlined), findsOneWidget);
    });

    testWidgets('Demo selection panel exists', (WidgetTester tester) async {
      await tester.pumpWidget(const MCPUIRuntimeDemoApp());
      await tester.pumpAndSettle();
      
      // Check for runtime features text
      expect(find.textContaining('Runtime Features'), findsAtLeastNWidgets(1));
    });

    testWidgets('At least one demo is visible', (WidgetTester tester) async {
      await tester.pumpWidget(const MCPUIRuntimeDemoApp());
      await tester.pumpAndSettle();
      
      // Check for at least one demo
      expect(find.textContaining('Lifecycle'), findsAtLeastNWidgets(1));
    });
  });
}