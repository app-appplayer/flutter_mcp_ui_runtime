import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  group('State Binding Tests', () {
    testWidgets('State changes trigger UI updates', (WidgetTester tester) async {
      // Create a simple test definition with state bindings
      final definition = {
        'type': 'page',
        'content': {
          'type': 'column',
          'children': [
            {
              'type': 'text',
              'value': 'Counter: {{counter}}',
              'key': 'counter_text',
            },
            {
              'type': 'button',
              'label': 'Increment',
              'onTap': {
                'type': 'tool',
                'tool': 'increment',
                'args': {},
              },
            },
          ],
        },
        'runtime': {
          'services': {
            'state': {
              'initialState': {
                'counter': 0,
              },
            },
          },
        },
      };

      // Create runtime
      final runtime = MCPUIRuntime();
      await runtime.initialize(definition);

      // Track tool calls
      final toolCalls = <String>[];
      
      // Build the widget with tool call handler
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: runtime.buildUI(
              onToolCall: (tool, args) {
                print('Test: onToolCall called with tool=$tool, args=$args');
                toolCalls.add(tool);
                if (tool == 'increment') {
                  // Simulate increment logic
                  final current = runtime.stateManager.get<int>('counter') ?? 0;
                  print('Test: Current counter = $current, setting to ${current + 1}');
                  runtime.stateManager.set('counter', current + 1);
                  print('Test: New counter = ${runtime.stateManager.get<int>('counter')}');
                }
              },
            ),
          ),
        ),
      );

      // Debug: Print all widgets
      await tester.pumpAndSettle();
      print('All text widgets found: ${find.text('Counter: 0').evaluate()}');
      print('All widgets found: ${find.byType(Text).evaluate()}');
      
      // Verify initial state
      expect(find.text('Counter: 0'), findsOneWidget);

      // Check tool executors
      print('Tool executors: ${runtime.engine!.actionHandler.toolExecutors}');

      // Tap the increment button
      await tester.tap(find.text('Increment'));
      await tester.pump(); // Trigger rebuild

      // Verify tool was called
      expect(toolCalls, contains('increment'));

      // Verify UI updated
      expect(find.text('Counter: 1'), findsOneWidget);
      expect(find.text('Counter: 0'), findsNothing);

      // Tap again
      await tester.tap(find.text('Increment'));
      await tester.pump();

      // Verify UI updated again
      expect(find.text('Counter: 2'), findsOneWidget);
      expect(find.text('Counter: 1'), findsNothing);

      await runtime.destroy();
    });
  });
}