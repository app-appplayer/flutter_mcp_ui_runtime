import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

/// Complete UI Integration Tests
/// These tests verify that the entire UI rendering and action execution pipeline works correctly
void main() {
  group('Full UI Integration Tests', () {
    testWidgets('Counter demo should render and increment/decrement properly', (tester) async {
      // State tracking for verification
      Map<String, dynamic> toolCallResults = {};
      int toolCallCount = 0;

      // Create runtime
      final runtime = MCPUIRuntime(enableDebugMode: true);
      
      // Define the counter demo
      final counterDemo = {
        'type': 'page',
        'content': {
          'type': 'container',
          'padding': {'all': 16},
          'child': {
            'type': 'column',
            'children': [
              {
                'type': 'text',
                'content': 'Counter: {{counter}}',
                'style': {'fontSize': 18},
              },
              {
                'type': 'row',
                'mainAxisAlignment': 'center',
                'children': [
                  {
                    'type': 'button',
                    'label': '-',
                    'style': 'elevated',
                    'onTap': {
                      'type': 'tool',
                      'tool': 'decrement',
                      'args': {},
                    },
                  },
                  {
                    'type': 'button',
                    'label': '+',
                    'style': 'elevated',
                    'onTap': {
                      'type': 'tool',
                      'tool': 'increment',
                      'args': {},
                    },
                  },
                  {
                    'type': 'button',
                    'label': 'Reset',
                    'style': 'outlined',
                    'onTap': {
                      'type': 'tool',
                      'tool': 'reset',
                      'args': {},
                    },
                  },
                ],
              },
            ],
          },
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

      // Initialize runtime
      await runtime.initialize(counterDemo);

      // Create the app widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: runtime.buildUI(
              initialState: {'counter': 5},
              onToolCall: (tool, args) {
                toolCallCount++;
                toolCallResults[tool] = args;
                
                // Simulate actual tool execution
                if (tool == 'increment') {
                  final current = runtime.stateManager.get<int>('counter') ?? 0;
                  runtime.stateManager.set('counter', current + 1);
                } else if (tool == 'decrement') {
                  final current = runtime.stateManager.get<int>('counter') ?? 0;
                  runtime.stateManager.set('counter', current - 1);
                } else if (tool == 'reset') {
                  runtime.stateManager.set('counter', 0);
                }
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify initial rendering
      expect(find.text('Counter: 5'), findsOneWidget);
      expect(find.text('-'), findsOneWidget);
      expect(find.text('+'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);

      // Test increment button
      await tester.tap(find.text('+'));
      await tester.pumpAndSettle();
      
      expect(toolCallCount, equals(1));
      expect(toolCallResults['increment'], isNotNull);
      expect(find.text('Counter: 6'), findsOneWidget);

      // Test decrement button
      await tester.tap(find.text('-'));
      await tester.pumpAndSettle();
      
      expect(toolCallCount, equals(2));
      expect(toolCallResults['decrement'], isNotNull);
      expect(find.text('Counter: 5'), findsOneWidget);

      // Test reset button
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      
      expect(toolCallCount, equals(3));
      expect(toolCallResults['reset'], isNotNull);
      expect(find.text('Counter: 0'), findsOneWidget);

      await runtime.destroy();
    });

    testWidgets('State bindings should update UI dynamically', (tester) async {
      final runtime = MCPUIRuntime(enableDebugMode: true);
      
      final stateDemo = {
        'type': 'page',
        'content': {
          'type': 'column',
          'children': [
            {
              'type': 'text',
              'content': 'Name: {{user.name}}',
            },
            {
              'type': 'text',
              'content': 'Status: {{user.status}}',
            },
            {
              'type': 'text',
              'content': 'Count: {{items.length}}',
            },
            {
              'type': 'button',
              'label': 'Update User',
              'onTap': {
                'type': 'tool',
                'tool': 'updateUser',
                'args': {'name': 'John Doe', 'status': 'active'},
              },
            },
          ],
        },
        'runtime': {
          'services': {
            'state': {
              'initialState': {
                'user': {'name': 'Unknown', 'status': 'inactive'},
                'items': [1, 2, 3],
              },
            },
          },
        },
      };

      await runtime.initialize(stateDemo);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: runtime.buildUI(
              onToolCall: (tool, args) {
                if (tool == 'updateUser') {
                  runtime.stateManager.set('user.name', args['name']);
                  runtime.stateManager.set('user.status', args['status']);
                }
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify initial state
      expect(find.text('Name: Unknown'), findsOneWidget);
      expect(find.text('Status: inactive'), findsOneWidget);
      expect(find.text('Count: 3'), findsOneWidget);

      // Trigger state update
      await tester.tap(find.text('Update User'));
      await tester.pumpAndSettle();

      // Verify updated state
      expect(find.text('Name: John Doe'), findsOneWidget);
      expect(find.text('Status: active'), findsOneWidget);

      await runtime.destroy();
    });

    testWidgets('Complex nested widgets should render correctly', (tester) async {
      final runtime = MCPUIRuntime(enableDebugMode: true);
      
      final complexDemo = {
        'type': 'page',
        'content': {
          'type': 'container',
          'padding': {'all': 16},
          'child': {
            'type': 'column',
            'children': [
              {
                'type': 'card',
                'child': {
                  'type': 'container',
                  'padding': {'all': 16},
                  'child': {
                    'type': 'row',
                    'children': [
                      {
                        'type': 'expanded',
                        'child': {
                          'type': 'column',
                          'crossAxisAlignment': 'start',
                          'children': [
                            {
                              'type': 'text',
                              'content': 'Title',
                              'style': {'fontSize': 18, 'fontWeight': 'bold'},
                            },
                            {
                              'type': 'text',
                              'content': 'Description text here',
                            },
                          ],
                        },
                      },
                      {
                        'type': 'button',
                        'label': 'Action',
                        'onTap': {
                          'type': 'tool',
                          'tool': 'cardAction',
                          'args': {'card': 'first'},
                        },
                      },
                    ],
                  },
                },
              },
              {
                'type': 'column',
                'children': [
                  {
                    'type': 'listTile',
                    'title': 'Item 1',
                    'subtitle': 'First item description',
                  },
                  {
                    'type': 'listTile',
                    'title': 'Item 2',
                    'subtitle': 'Second item description',
                  },
                ],
              },
            ],
          },
        },
      };

      await runtime.initialize(complexDemo);

      bool cardActionCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: runtime.buildUI(
              onToolCall: (tool, args) {
                if (tool == 'cardAction') {
                  cardActionCalled = true;
                  expect(args['card'], equals('first'));
                }
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify complex structure rendered
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Description text here'), findsOneWidget);
      expect(find.text('Action'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);

      // Test nested action
      await tester.tap(find.text('Action'));
      await tester.pumpAndSettle();
      
      expect(cardActionCalled, isTrue);

      await runtime.destroy();
    });

    testWidgets('Error handling should work gracefully', (tester) async {
      final runtime = MCPUIRuntime(enableDebugMode: true);
      
      final errorDemo = {
        'type': 'page',
        'content': {
          'type': 'column',
          'children': [
            {
              'type': 'text',
              'content': '{{missing.property}}',  // This should not crash
            },
            {
              'type': 'button',
              'label': 'Cause Error',
              'onTap': {
                'type': 'tool',
                'tool': 'errorTool',
                'args': {},
              },
            },
          ],
        },
      };

      await runtime.initialize(errorDemo);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: runtime.buildUI(
              onToolCall: (tool, args) {
                if (tool == 'errorTool') {
                  throw Exception('Tool execution failed');
                }
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should render despite missing binding
      expect(find.text('Cause Error'), findsOneWidget);

      // Error in tool call should not crash app
      await tester.tap(find.text('Cause Error'));
      await tester.pumpAndSettle();

      // App should still be functional
      expect(find.text('Cause Error'), findsOneWidget);

      await runtime.destroy();
    });

    testWidgets('All widget types should render without errors', (tester) async {
      final runtime = MCPUIRuntime(enableDebugMode: true);
      
      // Test basic widgets including checkbox and switch
      final allWidgetsDemo = {
        'type': 'page',
        'content': {
          'type': 'column',
          'children': [
            // Text widget
            {'type': 'text', 'content': 'Simple text'},
            
            // RichText widget with proper structure
            {
              'type': 'richtext',
              'spans': [
                {'text': 'Rich ', 'style': {'fontWeight': 'bold'}},
                {'text': 'text'}
              ],
            },
            
            // Checkbox widget
            {'type': 'checkbox', 'value': true, 'label': 'Check me'},
            
            // Switch widget  
            {'type': 'switch', 'value': false, 'label': 'Switch me'},
          ],
        },
      };

      await runtime.initialize(allWidgetsDemo);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: runtime.buildUI(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify text widgets rendered
      expect(find.text('Simple text'), findsOneWidget);
      // RichText renders with RichText widget, not as plain text
      expect(find.byType(RichText), findsAtLeast(1));
      
      // Verify checkbox rendered (as CheckboxListTile)
      expect(find.byType(CheckboxListTile), findsOneWidget);
      expect(find.text('Check me'), findsOneWidget);
      
      // Verify switch rendered (as SwitchListTile)
      expect(find.byType(SwitchListTile), findsOneWidget);
      expect(find.text('Switch me'), findsOneWidget);

      await runtime.destroy();
    });

    testWidgets('Performance test with large lists', (tester) async {
      final runtime = MCPUIRuntime(enableDebugMode: true);
      
      // Generate large list
      final items = List.generate(100, (index) => {
        'type': 'listTile',
        'title': 'Item $index',
        'subtitle': 'Description for item $index',
      });

      final performanceDemo = {
        'type': 'page',
        'content': {
          'type': 'singlechildscrollview',
          'child': {
            'type': 'column',
            'children': items,
          },
        },
      };

      await runtime.initialize(performanceDemo);

      final stopwatch = Stopwatch()..start();
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: runtime.buildUI(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      stopwatch.stop();

      // Verify it renders in reasonable time
      expect(stopwatch.elapsedMilliseconds, lessThan(5000)); // Should complete within 5 seconds

      // Verify some items are rendered
      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);

      await runtime.destroy();
    });
  });
}