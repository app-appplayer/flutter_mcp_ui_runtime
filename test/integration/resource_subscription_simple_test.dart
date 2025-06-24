import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  group('Resource Subscription Simple Tests', () {
    testWidgets('basic resource subscription flow', (WidgetTester tester) async {
      // Track handler calls
      final handlerCalls = <String>[];
      
      final uiDefinition = {
        'type': 'page',
        'content': {
          'type': 'linear',
          'direction': 'vertical',
          'children': [
            {
              'type': 'text',
              'content': 'CPU Usage',
            },
            {
              'type': 'button',
              'label': 'Subscribe',
              'click': {
                'type': 'resource',
                'action': 'subscribe',
                'uri': 'mcp://server/cpu',
                'binding': 'cpuUsage',
              },
            },
          ],
        },
      };

      final runtime = MCPUIRuntime();
      await runtime.initialize(uiDefinition);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: runtime.buildUI(
              onResourceSubscribe: (uri, binding) async {
                handlerCalls.add('subscribe:$uri:$binding');
              },
              onResourceUnsubscribe: (uri) async {
                handlerCalls.add('unsubscribe:$uri');
              },
            ),
          ),
        ),
      );

      // Wait for the runtime to be ready
      await tester.pumpAndSettle();
      
      // Find and tap the button
      expect(find.text('Subscribe'), findsOneWidget);
      await tester.tap(find.text('Subscribe'));
      await tester.pump();
      
      // Verify handler was called
      expect(handlerCalls, contains('subscribe:mcp://server/cpu:cpuUsage'));
    });

    testWidgets('notification updates state', (WidgetTester tester) async {
      final uiDefinition = {
        'type': 'page',
        'content': {
          'type': 'text',
          'content': 'CPU: {{cpu}}%',
        },
      };

      final runtime = MCPUIRuntime();
      await runtime.initialize(uiDefinition);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: runtime.buildUI(
              initialState: {'cpu': '0'},
            ),
          ),
        ),
      );

      // Wait for the runtime to be ready
      await tester.pumpAndSettle();

      // Initial state
      expect(find.text('CPU: 0%'), findsOneWidget);

      // First register the subscription
      runtime.engine!.registerResourceSubscription('mcp://server/cpu', 'cpu');

      // Send notification
      runtime.handleNotification({
        'method': 'notifications/resources/updated',
        'params': {
          'uri': 'mcp://server/cpu',
          'content': {
            'cpu': '75',
          },
        },
      });
      
      await tester.pump();
      
      // Updated state
      expect(find.text('CPU: 75%'), findsOneWidget);
      
      // Clean up
      await runtime.destroy();
    });
  });
}