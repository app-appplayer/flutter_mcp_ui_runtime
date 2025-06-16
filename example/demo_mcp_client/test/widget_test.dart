// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:demo_mcp_client/main.dart';

void main() {
  testWidgets('MCP Demo App loads and shows UI', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MCPClientApp());

    // Initial pump to show loading state
    await tester.pump();

    // Verify that the app loads with expected UI
    expect(find.text('MCP UI Runtime Client'), findsOneWidget);
    
    // Let connection attempt timeout and show demo mode
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 100));
    
    // Should show connection status
    expect(find.textContaining('Connecting'), findsAny);
  });
}