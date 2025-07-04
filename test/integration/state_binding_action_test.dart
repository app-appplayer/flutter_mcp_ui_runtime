import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  group('State Binding and Action Integration Tests', () {
    late MCPUIRuntime runtime;
    
    setUp(() {
      runtime = MCPUIRuntime();
    });
    
    tearDown(() {
      runtime.destroy();
    });
    
    testWidgets('Text widget should display state value with binding', (tester) async {
      // Initialize runtime with counter state
      await runtime.initialize({
        'type': 'page',
        'runtime': {
          'services': {
            'state': {
              'initialState': {
                'counter': 0,
                'message': 'Count: 0'
              }
            }
          }
        },
        'content': {
          'type': 'linear',
          'direction': 'vertical',
          'children': [
            {
              'type': 'text',
              'content': 'Counter: {{counter}}'
            },
            {
              'type': 'text', 
              'content': '{{message}}'
            }
          ]
        }
      });
      
      // Build widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: runtime.buildUI(),
          ),
        ),
      );
      
      await tester.pump();
      
      // Should display initial counter value
      expect(find.text('Counter: 0'), findsOneWidget);
      expect(find.text('Count: 0'), findsOneWidget); // Message should resolve the nested binding
    });
    
    testWidgets('Counter should increment when button is tapped', (tester) async {
      // Initialize runtime
      await runtime.initialize({
        'type': 'page',
        'runtime': {
          'services': {
            'state': {
              'initialState': {
                'counter': 0
              }
            }
          }
        },
        'content': {
          'type': 'linear',
          'direction': 'vertical',
          'children': [
            {
              'type': 'text',
              'content': 'Counter: {{counter}}'
            },
            {
              'type': 'button',
              'label': 'Increment',
              'click': {
                'type': 'state',
                'action': 'increment',
                'path': 'counter'
              }
            }
          ]
        }
      });
      
      // No need to register tool - using state action
      
      // Build widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: runtime.buildUI(),
          ),
        ),
      );
      
      await tester.pump();
      
      // Initial state
      expect(find.text('Counter: 0'), findsOneWidget);
      
      // Tap increment button
      await tester.tap(find.text('Increment'));
      await tester.pump();
      
      // Wait for async operations to complete
      await tester.pump(const Duration(milliseconds: 100));
      
      // Counter should be incremented
      expect(find.text('Counter: 1'), findsOneWidget);
      expect(find.text('Counter: 0'), findsNothing);
      
      // Tap again
      await tester.tap(find.text('Increment'));
      await tester.pump();
      
      // Counter should be 2
      expect(find.text('Counter: 2'), findsOneWidget);
      expect(find.text('Counter: 1'), findsNothing);
    });
    
    testWidgets('Counter should decrement when button is tapped', (tester) async {
      // Initialize runtime
      await runtime.initialize({
        'type': 'page',
        'runtime': {
          'services': {
            'state': {
              'initialState': {
                'counter': 5
              }
            }
          }
        },
        'content': {
          'type': 'linear',
          'direction': 'vertical',
          'children': [
            {
              'type': 'text',
              'content': 'Counter: {{counter}}'
            },
            {
              'type': 'button',
              'label': 'Decrement',
              'click': {
                'type': 'state',
                'action': 'decrement',
                'path': 'counter'
              }
            }
          ]
        }
      });
      
      // No need to register tool - using state action
      
      // Build widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: runtime.buildUI(),
          ),
        ),
      );
      
      await tester.pump();
      
      // Initial state
      expect(find.text('Counter: 5'), findsOneWidget);
      
      // Tap decrement button
      await tester.tap(find.text('Decrement'));
      await tester.pump();
      
      // Counter should be decremented
      expect(find.text('Counter: 4'), findsOneWidget);
      expect(find.text('Counter: 5'), findsNothing);
    });
    
    testWidgets('Multiple buttons should update state correctly', (tester) async {
      // Initialize runtime
      await runtime.initialize({
        'type': 'page',
        'runtime': {
          'services': {
            'state': {
              'initialState': {
                'counter': 0
              }
            }
          }
        },
        'content': {
          'type': 'linear',
          'direction': 'vertical',
          'children': [
            {
              'type': 'text',
              'content': 'Counter: {{counter}}'
            },
            {
              'type': 'linear',
              'direction': 'horizontal',
              'children': [
                {
                  'type': 'button',
                  'label': '-',
                  'click': {
                    'type': 'state',
                    'action': 'decrement',
                    'path': 'counter'
                  }
                },
                {
                  'type': 'button',
                  'label': '+',
                  'click': {
                    'type': 'state',
                    'action': 'increment',
                    'path': 'counter'
                  }
                },
                {
                  'type': 'button',
                  'label': 'Reset',
                  'click': {
                    'type': 'state',
                    'action': 'set',
                    'path': 'counter',
                    'value': 0
                  }
                }
              ]
            }
          ]
        }
      });
      
      // No need to register tools - using state actions
      
      // Build widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: runtime.buildUI(),
          ),
        ),
      );
      
      await tester.pump();
      
      // Initial state
      expect(find.text('Counter: 0'), findsOneWidget);
      
      // Increment
      await tester.tap(find.text('+'));
      await tester.pump();
      expect(find.text('Counter: 1'), findsOneWidget);
      
      // Increment again
      await tester.tap(find.text('+'));
      await tester.pump();
      expect(find.text('Counter: 2'), findsOneWidget);
      
      // Decrement
      await tester.tap(find.text('-'));
      await tester.pump();
      expect(find.text('Counter: 1'), findsOneWidget);
      
      // Reset
      await tester.tap(find.text('Reset'));
      await tester.pump();
      expect(find.text('Counter: 0'), findsOneWidget);
    });
  });
}