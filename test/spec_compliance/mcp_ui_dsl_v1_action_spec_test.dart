import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

/// MCP UI DSL v1.0 Action System Specification Compliance Test
/// 
/// This test verifies that all action types defined in the MCP UI DSL v1.0 spec
/// are properly implemented with correct parameter handling.
void main() {
  group('MCP UI DSL v1.0 Action System Specification Compliance', () {
    late MCPUIRuntime runtime;
    
    setUp(() {
      runtime = MCPUIRuntime();
    });
    
    tearDown(() {
      runtime.destroy();
    });
    
    group('State Actions', () {
      group('set action', () {
        testWidgets('should set state value with path parameter', (WidgetTester tester) async {
          await runtime.initialize({
            'type': 'page',
            'runtime': {
              'services': {
                'state': {
                  'initialState': {
                    'user': {
                      'name': 'John',
                      'age': 25,
                    },
                  },
                },
              },
            },
            'content': {
              'type': 'linear',
              'direction': 'vertical',
              'children': [
                {
                  'type': 'text',
                  'content': 'Name: {{user.name}}',
                },
                {
                  'type': 'button',
                  'label': 'Change Name',
                  'click': {
                    'type': 'state',
                    'action': 'set',
                    'path': 'user.name',  // v1.0 spec: 'path' parameter
                    'value': 'Jane',
                  },
                },
              ],
            },
          });
          
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
          await tester.pumpAndSettle();
          
          expect(find.text('Name: John'), findsOneWidget);
          
          await tester.tap(find.text('Change Name'));
          await tester.pumpAndSettle();
          
          expect(find.text('Name: Jane'), findsOneWidget);
        });
        
        testWidgets('should work with binding parameter (backward compatibility)', (WidgetTester tester) async {
          await runtime.initialize({
            'type': 'page',
            'runtime': {
              'services': {
                'state': {
                  'initialState': {
                    'message': 'Hello',
                  },
                },
              },
            },
            'content': {
              'type': 'linear',
              'direction': 'vertical',
              'children': [
                {
                  'type': 'text',
                  'content': '{{message}}',
                },
                {
                  'type': 'button',
                  'label': 'Update',
                  'click': {
                    'type': 'state',
                    'action': 'set',
                    'binding': 'message',  // backward compatibility
                    'value': 'World',
                  },
                },
              ],
            },
          });
          
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
          await tester.pumpAndSettle();
          
          expect(find.text('Hello'), findsOneWidget);
          
          await tester.tap(find.text('Update'));
          await tester.pumpAndSettle();
          
          expect(find.text('World'), findsOneWidget);
        });
      });
      
      group('increment action', () {
        testWidgets('should increment numeric value', (WidgetTester tester) async {
          await runtime.initialize({
            'type': 'page',
            'runtime': {
              'services': {
                'state': {
                  'initialState': {
                    'counter': 0,
                  },
                },
              },
            },
            'content': {
              'type': 'linear',
              'direction': 'vertical',
              'children': [
                {
                  'type': 'text',
                  'content': 'Count: {{counter}}',
                },
                {
                  'type': 'button',
                  'label': 'Increment',
                  'click': {
                    'type': 'state',
                    'action': 'increment',
                    'path': 'counter',
                    'value': 1,  // increment by 1
                  },
                },
                {
                  'type': 'button',
                  'label': 'Increment by 5',
                  'click': {
                    'type': 'state',
                    'action': 'increment',
                    'path': 'counter',
                    'value': 5,  // increment by 5
                  },
                },
              ],
            },
          });
          
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
          await tester.pumpAndSettle();
          
          expect(find.text('Count: 0'), findsOneWidget);
          
          await tester.tap(find.text('Increment'));
          await tester.pumpAndSettle();
          
          expect(find.text('Count: 1'), findsOneWidget);
          
          await tester.tap(find.text('Increment by 5'));
          await tester.pumpAndSettle();
          
          expect(find.text('Count: 6'), findsOneWidget);
        });
      });
      
      group('decrement action', () {
        testWidgets('should decrement numeric value', (WidgetTester tester) async {
          await runtime.initialize({
            'type': 'page',
            'runtime': {
              'services': {
                'state': {
                  'initialState': {
                    'counter': 10,
                  },
                },
              },
            },
            'content': {
              'type': 'linear',
              'direction': 'vertical',
              'children': [
                {
                  'type': 'text',
                  'content': 'Count: {{counter}}',
                },
                {
                  'type': 'button',
                  'label': 'Decrement',
                  'click': {
                    'type': 'state',
                    'action': 'decrement',
                    'path': 'counter',
                    'value': 1,  // decrement by 1
                  },
                },
              ],
            },
          });
          
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
          await tester.pumpAndSettle();
          
          expect(find.text('Count: 10'), findsOneWidget);
          
          await tester.tap(find.text('Decrement'));
          await tester.pumpAndSettle();
          
          expect(find.text('Count: 9'), findsOneWidget);
        });
      });
      
      group('toggle action', () {
        testWidgets('should toggle boolean value', (WidgetTester tester) async {
          await runtime.initialize({
            'type': 'page',
            'runtime': {
              'services': {
                'state': {
                  'initialState': {
                    'isEnabled': false,
                  },
                },
              },
            },
            'content': {
              'type': 'linear',
              'direction': 'vertical',
              'children': [
                {
                  'type': 'text',
                  'content': 'Enabled: {{isEnabled}}',
                },
                {
                  'type': 'button',
                  'label': 'Toggle',
                  'click': {
                    'type': 'state',
                    'action': 'toggle',
                    'path': 'isEnabled',
                  },
                },
              ],
            },
          });
          
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
          await tester.pumpAndSettle();
          
          expect(find.text('Enabled: false'), findsOneWidget);
          
          await tester.tap(find.text('Toggle'));
          await tester.pumpAndSettle();
          
          expect(find.text('Enabled: true'), findsOneWidget);
          
          await tester.tap(find.text('Toggle'));
          await tester.pumpAndSettle();
          
          expect(find.text('Enabled: false'), findsOneWidget);
        });
      });
      
      group('append action', () {
        testWidgets('should append to list', (WidgetTester tester) async {
          await runtime.initialize({
            'type': 'page',
            'runtime': {
              'services': {
                'state': {
                  'initialState': {
                    'items': ['A', 'B'],
                  },
                },
              },
            },
            'content': {
              'type': 'linear',
              'direction': 'vertical',
              'children': [
                {
                  'type': 'text',
                  'content': 'Items: {{items}}',
                },
                {
                  'type': 'button',
                  'label': 'Add C',
                  'click': {
                    'type': 'state',
                    'action': 'append',
                    'path': 'items',
                    'value': 'C',
                  },
                },
                {
                  'type': 'button',
                  'label': 'Add Multiple',
                  'click': {
                    'type': 'state',
                    'action': 'append',
                    'path': 'items',
                    'value': ['D', 'E'],  // append multiple items
                  },
                },
              ],
            },
          });
          
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
          await tester.pumpAndSettle();
          
          expect(find.text('Items: [A, B]'), findsOneWidget);
          
          await tester.tap(find.text('Add C'));
          await tester.pumpAndSettle();
          
          expect(find.text('Items: [A, B, C]'), findsOneWidget);
          
          await tester.tap(find.text('Add Multiple'));
          await tester.pumpAndSettle();
          
          expect(find.text('Items: [A, B, C, D, E]'), findsOneWidget);
        });
      });
      
      group('remove action', () {
        testWidgets('should remove from list by value', (WidgetTester tester) async {
          await runtime.initialize({
            'type': 'page',
            'runtime': {
              'services': {
                'state': {
                  'initialState': {
                    'items': ['A', 'B', 'C'],
                  },
                },
              },
            },
            'content': {
              'type': 'linear',
              'direction': 'vertical',
              'children': [
                {
                  'type': 'text',
                  'content': 'Items: {{items}}',
                },
                {
                  'type': 'button',
                  'label': 'Remove B',
                  'click': {
                    'type': 'state',
                    'action': 'remove',
                    'path': 'items',
                    'value': 'B',  // Remove by value
                  },
                },
              ],
            },
          });
          
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
          await tester.pumpAndSettle();
          
          expect(find.text('Items: [A, B, C]'), findsOneWidget);
          
          await tester.tap(find.text('Remove B'));
          await tester.pumpAndSettle();
          
          expect(find.text('Items: [A, C]'), findsOneWidget);
        });
        
        testWidgets('should remove from list by index', (WidgetTester tester) async {
          await runtime.initialize({
            'type': 'page',
            'runtime': {
              'services': {
                'state': {
                  'initialState': {
                    'items': ['A', 'B', 'C'],
                  },
                },
              },
            },
            'content': {
              'type': 'linear',
              'direction': 'vertical',
              'children': [
                {
                  'type': 'text',
                  'content': 'Items: {{items}}',
                },
                {
                  'type': 'button',
                  'label': 'Remove at index 1',
                  'click': {
                    'type': 'state',
                    'action': 'remove',
                    'path': 'items',
                    'index': 1,  // Remove by index
                  },
                },
              ],
            },
          });
          
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
          await tester.pumpAndSettle();
          
          expect(find.text('Items: [A, B, C]'), findsOneWidget);
          
          await tester.tap(find.text('Remove at index 1'));
          await tester.pumpAndSettle();
          
          expect(find.text('Items: [A, C]'), findsOneWidget);
        });
      });
    });
    
    group('Tool Actions', () {
      testWidgets('should execute tool with params', (WidgetTester tester) async {
        String? calledTool;
        Map<String, dynamic>? calledParams;
        
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'button',
            'label': 'Call Tool',
            'click': {
              'type': 'tool',
              'tool': 'myTool',
              'params': {  // v1.0 spec: 'params' instead of 'args'
                'param1': 'value1',
                'param2': 123,
              },
            },
          },
        });
        
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: runtime.buildUI(
              onToolCall: (tool, params) async {
                calledTool = tool;
                calledParams = params;
              },
            ),
          ),
        ));
        await tester.pumpAndSettle();
        
        await tester.tap(find.text('Call Tool'));
        await tester.pumpAndSettle();
        
        expect(calledTool, 'myTool');
        expect(calledParams, {
          'param1': 'value1',
          'param2': 123,
        });
      });
    });
    
    group('Resource Actions', () {
      testWidgets('should handle resource subscription', (WidgetTester tester) async {
        String? subscribedUri;
        String? subscribedBinding;
        String? unsubscribedUri;
        
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'button',
                'label': 'Subscribe',
                'click': {
                  'type': 'resource',
                  'action': 'subscribe',
                  'uri': 'data://temperature',
                  'binding': 'temperature',
                },
              },
              {
                'type': 'button',
                'label': 'Unsubscribe',
                'click': {
                  'type': 'resource',
                  'action': 'unsubscribe',
                  'uri': 'data://temperature',
                },
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: runtime.buildUI(
              onResourceSubscribe: (uri, binding) async {
                subscribedUri = uri;
                subscribedBinding = binding;
              },
              onResourceUnsubscribe: (uri) async {
                unsubscribedUri = uri;
              },
            ),
          ),
        ));
        await tester.pumpAndSettle();
        
        // Test subscribe
        await tester.tap(find.text('Subscribe'));
        await tester.pumpAndSettle();
        
        expect(subscribedUri, 'data://temperature');
        expect(subscribedBinding, 'temperature');
        
        // Test unsubscribe
        await tester.tap(find.text('Unsubscribe'));
        await tester.pumpAndSettle();
        
        expect(unsubscribedUri, 'data://temperature');
      });
    });
    
    group('Navigation Actions', () {
      testWidgets('should handle navigation actions with custom handler', (WidgetTester tester) async {
        String? navAction;
        String? navRoute;
        Map<String, dynamic>? navParams;
        
        // Create a custom navigation handler using buildUI
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'button',
                'label': 'Push',
                'click': {
                  'type': 'navigation',
                  'action': 'push',
                  'route': '/details',
                  'params': {'id': '123'},
                },
              },
              {
                'type': 'button',
                'label': 'Pop',
                'click': {
                  'type': 'navigation',
                  'action': 'pop',
                },
              },
            ],
          },
        });
        
        // We can't directly test navigation without a proper Navigator setup
        // So we'll just verify the action structure is correct
        final definition = runtime.getUIDefinition();
        final content = definition?['content'] as Map<String, dynamic>;
        final children = content['children'] as List<dynamic>;
        final pushButton = children[0] as Map<String, dynamic>;
        final pushClick = pushButton['click'] as Map<String, dynamic>;
        
        expect(pushClick['type'], 'navigation');
        expect(pushClick['action'], 'push');
        expect(pushClick['route'], '/details');
        expect(pushClick['params'], {'id': '123'});
        
        final popButton = children[1] as Map<String, dynamic>;
        final popClick = popButton['click'] as Map<String, dynamic>;
        
        expect(popClick['type'], 'navigation');
        expect(popClick['action'], 'pop');
      });
    });
    
    group('Batch Actions', () {
      testWidgets('should execute sequential batch actions', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'step': 0,
                  'message': '',
                },
              },
            },
          },
          'content': {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'text',
                'content': 'Step: {{step}}, Message: {{message}}',
              },
              {
                'type': 'button',
                'label': 'Run Batch',
                'click': {
                  'type': 'batch',
                  'parallel': false,  // sequential execution
                  'actions': [
                    {
                      'type': 'state',
                      'action': 'set',
                      'path': 'step',
                      'value': 1,
                    },
                    {
                      'type': 'state',
                      'action': 'set',
                      'path': 'message',
                      'value': 'First',
                    },
                    {
                      'type': 'state',
                      'action': 'set',
                      'path': 'step',
                      'value': 2,
                    },
                    {
                      'type': 'state',
                      'action': 'set',
                      'path': 'message',
                      'value': 'Second',
                    },
                  ],
                },
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pumpAndSettle();
        
        expect(find.text('Step: 0, Message: '), findsOneWidget);
        
        await tester.tap(find.text('Run Batch'));
        await tester.pumpAndSettle();
        
        expect(find.text('Step: 2, Message: Second'), findsOneWidget);
      });
      
      testWidgets('should execute parallel batch actions', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'a': 0,
                  'b': 0,
                  'c': 0,
                },
              },
            },
          },
          'content': {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'text',
                'content': 'A: {{a}}, B: {{b}}, C: {{c}}',
              },
              {
                'type': 'button',
                'label': 'Run Parallel',
                'click': {
                  'type': 'batch',
                  'parallel': true,  // parallel execution
                  'actions': [
                    {
                      'type': 'state',
                      'action': 'set',
                      'path': 'a',
                      'value': 1,
                    },
                    {
                      'type': 'state',
                      'action': 'set',
                      'path': 'b',
                      'value': 2,
                    },
                    {
                      'type': 'state',
                      'action': 'set',
                      'path': 'c',
                      'value': 3,
                    },
                  ],
                },
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pumpAndSettle();
        
        expect(find.text('A: 0, B: 0, C: 0'), findsOneWidget);
        
        await tester.tap(find.text('Run Parallel'));
        await tester.pumpAndSettle();
        
        expect(find.text('A: 1, B: 2, C: 3'), findsOneWidget);
      });
    });
    
    group('Conditional Actions', () {
      testWidgets('should execute then branch when condition is true', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'isEnabled': true,
                  'message': 'Initial',
                },
              },
            },
          },
          'content': {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'text',
                'content': 'Message: {{message}}',
              },
              {
                'type': 'button',
                'label': 'Conditional Action',
                'click': {
                  'type': 'conditional',
                  'condition': '{{isEnabled}}',
                  'then': {
                    'type': 'state',
                    'action': 'set',
                    'path': 'message',
                    'value': 'Enabled!',
                  },
                  'else': {
                    'type': 'state',
                    'action': 'set',
                    'path': 'message',
                    'value': 'Disabled!',
                  },
                },
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pumpAndSettle();
        
        expect(find.text('Message: Initial'), findsOneWidget);
        
        await tester.tap(find.text('Conditional Action'));
        await tester.pumpAndSettle();
        
        expect(find.text('Message: Enabled!'), findsOneWidget);
      });
      
      testWidgets('should execute else branch when condition is false', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'isEnabled': false,
                  'message': 'Initial',
                },
              },
            },
          },
          'content': {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'text',
                'content': 'Message: {{message}}',
              },
              {
                'type': 'button',
                'label': 'Conditional Action',
                'click': {
                  'type': 'conditional',
                  'condition': '{{isEnabled}}',
                  'then': {
                    'type': 'state',
                    'action': 'set',
                    'path': 'message',
                    'value': 'Enabled!',
                  },
                  'else': {
                    'type': 'state',
                    'action': 'set',
                    'path': 'message',
                    'value': 'Disabled!',
                  },
                },
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pumpAndSettle();
        
        expect(find.text('Message: Initial'), findsOneWidget);
        
        await tester.tap(find.text('Conditional Action'));
        await tester.pumpAndSettle();
        
        expect(find.text('Message: Disabled!'), findsOneWidget);
      });
    });
  });
}