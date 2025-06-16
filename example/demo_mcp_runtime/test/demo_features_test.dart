import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:demo_mcp_runtime/demo_app.dart';

void main() {
  group('Demo Features Tests', () {
    testWidgets('Demo app renders all sections', (WidgetTester tester) async {
      await tester.pumpWidget(const MCPUIRuntimeDemoApp());

      // Verify main sections exist
      expect(find.text('MCP UI Runtime Demo'), findsOneWidget);
      expect(find.text('Runtime Features'), findsOneWidget);
      
      // Verify first demo is visible
      expect(find.text('📄 Page Type Demo'), findsAtLeastNWidgets(1));
      expect(find.text('Single page UI definition'), findsAtLeastNWidgets(1));
    });

    testWidgets('Demo navigation works', (WidgetTester tester) async {
      await tester.pumpWidget(const MCPUIRuntimeDemoApp());

      // Verify initial demo
      expect(find.text('📄 Page Type Demo'), findsAtLeastNWidgets(1));
      
      // Navigate to lifecycle demo
      await tester.tap(find.textContaining('Lifecycle Management'));
      await tester.pumpAndSettle();
      
      // Verify demo changed
      expect(find.text('Runtime lifecycle with hooks'), findsAtLeastNWidgets(1));
    });

    testWidgets('Debug panel toggle works', (WidgetTester tester) async {
      await tester.pumpWidget(const MCPUIRuntimeDemoApp());

      // Debug panel should not be visible initially
      expect(find.text('Runtime Debug'), findsNothing);
      
      // Toggle debug panel
      await tester.tap(find.byIcon(Icons.bug_report_outlined));
      await tester.pumpAndSettle();
      
      // Debug panel should now be visible
      expect(find.text('Runtime Debug'), findsOneWidget);
      
      // Toggle again to hide
      await tester.tap(find.byIcon(Icons.bug_report));
      await tester.pumpAndSettle();
      
      // Debug panel should be hidden again
      expect(find.text('Runtime Debug'), findsNothing);
    });

    testWidgets('Full screen demo navigation works', (WidgetTester tester) async {
      await tester.pumpWidget(const MCPUIRuntimeDemoApp());

      // Find and tap the full screen button
      await tester.tap(find.text('Full Screen'));
      await tester.pumpAndSettle();
      
      // Should navigate to test app - back button should be present
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('All demo sections are available', (WidgetTester tester) async {
      await tester.pumpWidget(const MCPUIRuntimeDemoApp());

      // Verify all demo titles exist in the sidebar (using contains for flexibility)
      expect(find.textContaining('Application Type Demo'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Page Type Demo'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Navigation Demo'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Lifecycle Management'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Background Services'), findsAtLeastNWidgets(1));
      expect(find.textContaining('State & Bindings'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Notifications System'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Tool Integration'), findsAtLeastNWidgets(1));
    });

    testWidgets('Demo content updates when selection changes', (WidgetTester tester) async {
      await tester.pumpWidget(const MCPUIRuntimeDemoApp());

      // Start with page type demo
      expect(find.textContaining('Single page UI definition'), findsAtLeastNWidgets(1));
      
      // Switch to lifecycle demo
      await tester.tap(find.textContaining('Lifecycle Management'));
      await tester.pumpAndSettle();
      
      // Wait for any async operations
      await tester.pump(const Duration(seconds: 1));
      
      // Verify content changed - look for lifecycle-specific content
      expect(find.textContaining('Runtime lifecycle'), findsAtLeastNWidgets(1));
    });
  });
}