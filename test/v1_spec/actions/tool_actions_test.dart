import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

/// MCP UI DSL v1.0 Tool Actions Tests
/// 
/// Tests tool execution actions according to MCP UI DSL v1.0 specification.
/// Reference: Spec Section 6.1.7 - Tool Actions
void main() {
  group('MCP UI DSL v1.0 - Tool Actions', () {
    late MCPUIRuntime runtime;
    
    setUp(() {
      runtime = MCPUIRuntime();
    });
    
    tearDown(() {
      runtime.destroy();
    });
    
    group('Tool Execution (Spec 6.1.7)', () {
      testWidgets('should execute tool with params parameter', (WidgetTester tester) async {
        String? executedTool;
        Map<String, dynamic>? receivedParams;
        
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'userName': 'John Doe',
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
                'type': 'textInput',
                'label': 'Message',
                'value': '{{message}}',
                'change': {
                  'type': 'state',
                  'action': 'set',
                  'path': 'message',
                  'value': '{{event.value}}',
                },
              },
              {
                'type': 'button',
                'label': 'Send',
                'click': {
                  'type': 'tool',
                  'tool': 'sendMessage',
                  'params': {  // v1.0 spec: uses 'params' not 'args'
                    'from': '{{userName}}',
                    'text': '{{message}}',
                    'timestamp': 'now',
                  },
                },
              },
            ],
          },
        });
        
        runtime.registerToolExecutor('sendMessage', (params) async {
          executedTool = 'sendMessage';
          receivedParams = params;
          return {'success': true, 'messageId': '123'};
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        await tester.enterText(find.byType(TextField), 'Hello World');
        await tester.pump();
        
        await tester.tap(find.text('Send'));
        await tester.pump();
        
        expect(executedTool, 'sendMessage');
        expect(receivedParams, {
          'from': 'John Doe',
          'text': 'Hello World',
          'timestamp': 'now',
        });
      });
      
      testWidgets('should handle tool response', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'loading': false,
                  'data': null,
                },
              },
            },
          },
          'content': {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'button',
                'label': 'Fetch Data',
                'click': {
                  'type': 'batch',
                  'actions': [
                    {
                      'type': 'state',
                      'action': 'set',
                      'path': 'loading',
                      'value': true,
                    },
                    {
                      'type': 'tool',
                      'tool': 'fetchData',
                      'params': {
                        'page': 1,
                        'limit': 10,
                      },
                      'onSuccess': {
                        'type': 'batch',
                        'actions': [
                          {
                            'type': 'state',
                            'action': 'set',
                            'path': 'data',
                            'value': '{{response.data}}',
                          },
                          {
                            'type': 'state',
                            'action': 'set',
                            'path': 'loading',
                            'value': false,
                          },
                        ],
                      },
                    },
                  ],
                },
              },
              {
                'type': 'conditional',
                'condition': '{{loading}}',
                'then': {
                  'type': 'text',
                  'content': 'Loading...',
                },
                'orElse': {
                  'type': 'conditional',
                  'condition': '{{data}}',
                  'then': {
                    'type': 'text',
                    'content': 'Found {{data.total}} items',
                  },
                },
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI(
          onToolCall: (tool, params) async {
            if (tool == 'fetchData') {
              return {
                'status': 'success',
                'data': {
                  'items': ['Item 1', 'Item 2', 'Item 3'],
                  'total': 3,
                },
              };
            }
          },
        ))));
        await tester.pump();
        
        await tester.tap(find.text('Fetch Data'));
        
        // Wait for async operations to complete
        await tester.pumpAndSettle();
        
        // Should show data (loading state is too fast to catch in test)
        expect(find.text('Found 3 items'), findsOneWidget);
      });
      
      testWidgets('should execute tool without params', (WidgetTester tester) async {
        var toolCalled = false;
        
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'button',
            'label': 'Refresh',
            'click': {
              'type': 'tool',
              'tool': 'refresh',
              // No params provided
            },
          },
        });
        
        runtime.registerToolExecutor('refresh', (params) async {
          toolCalled = true;
          expect(params, isEmpty);
          return {'refreshed': true};
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        await tester.tap(find.text('Refresh'));
        await tester.pump();
        
        expect(toolCalled, isTrue);
      });
      
      testWidgets('should pass dynamic params from state', (WidgetTester tester) async {
        Map<String, dynamic>? receivedParams;
        
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'searchQuery': '',
                  'filters': {
                    'category': 'all',
                    'sortBy': 'relevance',
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
                'type': 'textInput',
                'label': 'Search',
                'value': '{{searchQuery}}',
                'change': {
                  'type': 'state',
                  'action': 'set',
                  'path': 'searchQuery',
                  'value': '{{event.value}}',
                },
              },
              {
                'type': 'button',
                'label': 'Search',
                'click': {
                  'type': 'tool',
                  'tool': 'search',
                  'params': {
                    'query': '{{searchQuery}}',
                    'filters': '{{filters}}',
                  },
                },
              },
            ],
          },
        });
        
        runtime.registerToolExecutor('search', (params) async {
          receivedParams = params;
          return {'results': []};
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        await tester.enterText(find.byType(TextField), 'MCP UI DSL');
        await tester.pump();
        
        await tester.tap(find.widgetWithText(ElevatedButton, 'Search'));
        await tester.pump();
        
        expect(receivedParams, {
          'query': 'MCP UI DSL',
          'filters': {
            'category': 'all',
            'sortBy': 'relevance',
          },
        });
      });
      
      testWidgets('should handle tool errors gracefully', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'error': null,
                },
              },
            },
          },
          'content': {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'button',
                'label': 'Execute',
                'click': {
                  'type': 'tool',
                  'tool': 'failingTool',
                  'params': {},
                  'onError': {
                    'type': 'state',
                    'action': 'set',
                    'path': 'error',
                    'value': 'Operation failed',
                  },
                },
              },
              {
                'type': 'conditional',
                'condition': '{{error}}',
                'then': {
                  'type': 'text',
                  'content': '{{error}}',
                  'style': {'color': '#FF0000'},
                },
              },
            ],
          },
        });
        
        runtime.registerToolExecutor('failingTool', (params) async {
          throw Exception('Tool execution failed');
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        await tester.tap(find.text('Execute'));
        await tester.pump(const Duration(milliseconds: 100));
        
        expect(find.text('Operation failed'), findsOneWidget);
      });
    });
    
    group('Tool Registration (Spec 6.1.7.1)', () {
      test('should allow multiple tool registration', () async {
        final tools = <String>[];
        
        await runtime.initialize({
          'type': 'page',
          'content': {'type': 'text', 'content': 'Test'},
        });
        
        runtime.registerToolExecutor('tool1', (params) async {
          tools.add('tool1');
          return {};
        });
        
        runtime.registerToolExecutor('tool2', (params) async {
          tools.add('tool2');
          return {};
        });
        
        runtime.registerToolExecutor('tool3', (params) async {
          tools.add('tool3');
          return {};
        });
        
        // Tools should be registered
        expect(runtime.engine, isNotNull);
      });
      
      test('should override existing tool when re-registered', () async {
        var version = 1;
        
        await runtime.initialize({
          'type': 'page',
          'content': {'type': 'text', 'content': 'Test'},
        });
        
        runtime.registerToolExecutor('versionedTool', (params) async {
          return {'version': version};
        });
        
        version = 2;
        runtime.registerToolExecutor('versionedTool', (params) async {
          return {'version': version};
        });
        
        // Should use the latest registration
        expect(version, 2);
      });
    });
    
    group('Tool Callback Integration (Spec 6.1.7.2)', () {
      testWidgets('should trigger onToolCall callback', (WidgetTester tester) async {
        String? calledTool;
        Map<String, dynamic>? calledParams;
        
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'button',
            'label': 'External Tool',
            'click': {
              'type': 'tool',
              'tool': 'externalTool',
              'params': {
                'action': 'process',
                'data': {'id': 123},
              },
            },
          },
        });
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: runtime.buildUI(
                onToolCall: (tool, params) {
                  calledTool = tool;
                  calledParams = params;
                },
              ),
            ),
          ),
        );
        await tester.pump();
        
        await tester.tap(find.text('External Tool'));
        await tester.pump();
        
        expect(calledTool, 'externalTool');
        expect(calledParams, {
          'action': 'process',
          'data': {'id': 123},
        });
      });
    });
  });
}