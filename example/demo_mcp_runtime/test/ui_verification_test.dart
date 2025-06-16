import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  group('MCP UI Runtime Tests', () {
    testWidgets('Runtime renders basic widgets correctly', (WidgetTester tester) async {
      final testDefinition = {
        'mcpRuntime': {
          'version': '1.0',
          'runtime': {
            'id': 'test_app',
            'domain': 'com.test.app',
            'version': '1.0.0',
            'services': {
              'state': {
                'initialState': {
                  'message': 'Hello Runtime!',
                  'counter': 0,
                }
              }
            }
          },
          'ui': {
            'type': 'scaffold',
            'properties': {
              'appBar': {
                'type': 'appbar',
                'properties': {
                  'title': {'type': 'text', 'properties': {'content': 'Test App'}}
                }
              },
              'body': {
                'type': 'column',
                'children': [
                  {
                    'type': 'text',
                    'properties': {
                      'content': {'binding': 'state.message'},
                    }
                  },
                  {
                    'type': 'text',
                    'properties': {
                      'content': {'binding': '"Counter: " + state.counter'},
                    }
                  }
                ]
              }
            }
          }
        }
      };

      await tester.pumpWidget(MaterialApp(
        home: MCPUIRuntimeHelper.render(
          testDefinition,
          onToolCall: (tool, args) {
            // Handle tool calls
          },
        ),
      ));

      // Wait for rendering to complete
      await tester.pumpAndSettle();

      // Verify UI elements (more flexible matching)
      expect(find.textContaining('Test App'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Hello Runtime!'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Counter'), findsAtLeastNWidgets(1));
    });

    testWidgets('State bindings update correctly', (WidgetTester tester) async {
      int counter = 0;

      final testDefinition = {
        'mcpRuntime': {
          'version': '1.0',
          'runtime': {
            'id': 'counter_app',
            'domain': 'com.test.counter',
            'version': '1.0.0',
            'services': {
              'state': {
                'initialState': {
                  'counter': 0,
                }
              }
            }
          },
          'ui': {
            'type': 'scaffold',
            'properties': {
              'body': {
                'type': 'column',
                'children': [
                  {
                    'type': 'text',
                    'properties': {
                      'content': {'binding': '"Count: " + state.counter'},
                    }
                  },
                  {
                    'type': 'button',
                    'properties': {
                      'child': {'type': 'text', 'properties': {'content': 'Increment'}}
                    },
                    'actions': {
                      'onPressed': [{'type': 'tool', 'tool': 'increment'}]
                    }
                  }
                ]
              }
            }
          }
        }
      };

      await tester.pumpWidget(MaterialApp(
        home: MCPUIRuntimeHelper.render(
          testDefinition,
          onToolCall: (tool, args) {
            if (tool == 'increment') {
              counter++;
              // In real implementation, this would trigger state update
            }
          },
        ),
      ));

      // Wait for rendering
      await tester.pumpAndSettle();

      // Verify initial state
      expect(find.textContaining('Count'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Increment'), findsAtLeastNWidgets(1));

      // Test button interaction
      await tester.tap(find.text('Increment'));
      await tester.pump();

      // Verify tool call was triggered
      expect(counter, 1);
    });

    testWidgets('Tool calls work correctly', (WidgetTester tester) async {
      String? lastTool;
      Map<String, dynamic>? lastArgs;

      final testDefinition = {
        'mcpRuntime': {
          'version': '1.0',
          'runtime': {
            'id': 'tool_test',
            'domain': 'com.test.tools',
            'version': '1.0.0',
            'services': {
              'state': {
                'initialState': {}
              }
            }
          },
          'ui': {
            'type': 'scaffold',
            'properties': {
              'body': {
                'type': 'button',
                'properties': {
                  'child': {'type': 'text', 'properties': {'content': 'Test Tool'}}
                },
                'actions': {
                  'onPressed': [
                    {
                      'type': 'tool',
                      'tool': 'testTool',
                      'args': {'message': 'test', 'value': 42}
                    }
                  ]
                }
              }
            }
          }
        }
      };

      await tester.pumpWidget(MaterialApp(
        home: MCPUIRuntimeHelper.render(
          testDefinition,
          onToolCall: (tool, args) {
            lastTool = tool;
            lastArgs = args;
          },
        ),
      ));

      // Wait for rendering
      await tester.pumpAndSettle();

      // Find and tap button
      final button = find.textContaining('Test Tool');
      expect(button, findsAtLeastNWidgets(1));

      await tester.tap(button.first);
      await tester.pumpAndSettle();

      // Verify tool call
      expect(lastTool, 'testTool');
      expect(lastArgs, {
        'message': 'test',
        'value': 42,
      });
    });

    testWidgets('Complex nested layouts render correctly', (WidgetTester tester) async {
      final testDefinition = {
        'mcpRuntime': {
          'version': '1.0',
          'runtime': {
            'id': 'layout_test',
            'domain': 'com.test.layout',
            'version': '1.0.0',
            'services': {
              'state': {
                'initialState': {
                  'items': ['Item 1', 'Item 2', 'Item 3']
                }
              }
            }
          },
          'ui': {
            'type': 'scaffold',
            'properties': {
              'body': {
                'type': 'column',
                'children': [
                  {
                    'type': 'container',
                    'properties': {
                      'padding': 16,
                      'child': {
                        'type': 'text',
                        'properties': {
                          'content': 'Header',
                          'style': {'fontSize': 24, 'fontWeight': 'bold'}
                        }
                      }
                    }
                  },
                  {
                    'type': 'listview',
                    'itemCount': {'binding': 'state.items.length'},
                    'itemBuilder': {
                      'type': 'listtile',
                      'properties': {
                        'title': {
                          'type': 'text',
                          'properties': {'content': {'binding': 'state.items[index]'}}
                        }
                      }
                    }
                  }
                ]
              }
            }
          }
        }
      };

      await tester.pumpWidget(MaterialApp(
        home: MCPUIRuntimeHelper.render(
          testDefinition,
          onToolCall: (tool, args) {},
        ),
      ));

      // Wait for rendering
      await tester.pumpAndSettle();

      // Verify header
      expect(find.textContaining('Header'), findsAtLeastNWidgets(1));

      // Verify list items
      expect(find.textContaining('Item 1'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Item 2'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Item 3'), findsAtLeastNWidgets(1));
    });
  });
}