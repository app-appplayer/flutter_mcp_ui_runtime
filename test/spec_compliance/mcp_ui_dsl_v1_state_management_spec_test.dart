import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

/// MCP UI DSL v1.0 State Management Specification Compliance Test
/// 
/// This test verifies that state management functionality correctly implements
/// the state management features as defined in the MCP UI DSL v1.0 specification.
void main() {
  group('MCP UI DSL v1.0 State Management Specification Compliance', () {
    late MCPUIRuntime runtime;
    
    setUp(() {
      runtime = MCPUIRuntime();
    });
    
    tearDown(() {
      runtime.destroy();
    });
    
    group('Initial State', () {
      test('should initialize with provided state', () async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'counter': 0,
                  'user': {
                    'name': 'John',
                    'email': 'john@example.com',
                  },
                  'settings': {
                    'theme': 'light',
                    'notifications': true,
                  },
                },
              },
            },
          },
          'content': {'type': 'box'},
        });
        
        expect(runtime.stateManager.get('counter'), 0);
        expect(runtime.stateManager.get('user.name'), 'John');
        expect(runtime.stateManager.get('user.email'), 'john@example.com');
        expect(runtime.stateManager.get('settings.theme'), 'light');
        expect(runtime.stateManager.get('settings.notifications'), true);
      });
      
      test('should handle complex nested structures', () async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'app': {
                    'version': '1.0.0',
                    'features': {
                      'auth': {
                        'enabled': true,
                        'providers': ['email', 'google', 'github'],
                      },
                      'analytics': {
                        'enabled': false,
                        'key': null,
                      },
                    },
                  },
                  'data': {
                    'items': [
                      {'id': 1, 'name': 'Item 1'},
                      {'id': 2, 'name': 'Item 2'},
                    ],
                    'metadata': {
                      'total': 2,
                      'page': 1,
                    },
                  },
                },
              },
            },
          },
          'content': {'type': 'box'},
        });
        
        expect(runtime.stateManager.get('app.version'), '1.0.0');
        expect(runtime.stateManager.get('app.features.auth.enabled'), true);
        expect(runtime.stateManager.get('app.features.auth.providers'), 
          ['email', 'google', 'github']);
        expect(runtime.stateManager.get('app.features.analytics.enabled'), false);
        expect(runtime.stateManager.get('app.features.analytics.key'), null);
        expect(runtime.stateManager.get('data.items.length'), 2);
        expect(runtime.stateManager.get('data.items[0].name'), 'Item 1');
        expect(runtime.stateManager.get('data.metadata.total'), 2);
      });
    });
    
    group('State Updates', () {
      testWidgets('should update simple values', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'message': 'Hello',
                  'count': 0,
                  'active': false,
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
                'type': 'text',
                'content': 'Count: {{count}}',
              },
              {
                'type': 'text',
                'content': 'Active: {{active}}',
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Hello'), findsOneWidget);
        expect(find.text('Count: 0'), findsOneWidget);
        expect(find.text('Active: false'), findsOneWidget);
        
        runtime.stateManager.set('message', 'World');
        runtime.stateManager.set('count', 5);
        runtime.stateManager.set('active', true);
        await tester.pump();
        
        expect(find.text('World'), findsOneWidget);
        expect(find.text('Count: 5'), findsOneWidget);
        expect(find.text('Active: true'), findsOneWidget);
      });
      
      testWidgets('should update nested values', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'user': {
                    'profile': {
                      'name': 'Alice',
                      'age': 25,
                    },
                  },
                },
              },
            },
          },
          'content': {
            'type': 'text',
            'content': '{{user.profile.name}} ({{user.profile.age}})',
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Alice (25)'), findsOneWidget);
        
        runtime.stateManager.set('user.profile.name', 'Bob');
        runtime.stateManager.set('user.profile.age', 30);
        await tester.pump();
        
        expect(find.text('Bob (30)'), findsOneWidget);
      });
      
      testWidgets('should update array elements', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'items': ['Apple', 'Banana', 'Orange'],
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
                'content': 'First: {{items[0]}}',
              },
              {
                'type': 'text',
                'content': 'Second: {{items[1]}}',
              },
              {
                'type': 'text',
                'content': 'Count: {{items.length}}',
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('First: Apple'), findsOneWidget);
        expect(find.text('Second: Banana'), findsOneWidget);
        expect(find.text('Count: 3'), findsOneWidget);
        
        // Update array element
        runtime.stateManager.set('items[0]', 'Mango');
        await tester.pump();
        
        expect(find.text('First: Mango'), findsOneWidget);
        
        // Replace entire array
        runtime.stateManager.set('items', ['Grape', 'Kiwi']);
        await tester.pump();
        
        expect(find.text('First: Grape'), findsOneWidget);
        expect(find.text('Second: Kiwi'), findsOneWidget);
        expect(find.text('Count: 2'), findsOneWidget);
      });
    });
    
    group('State Actions', () {
      testWidgets('should handle increment action', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'counter': 10,
                  'score': 100,
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
                'content': 'Counter: {{counter}}',
              },
              {
                'type': 'text',
                'content': 'Score: {{score}}',
              },
              {
                'type': 'button',
                'label': 'Increment Counter',
                'click': {
                  'type': 'state',
                  'action': 'increment',
                  'path': 'counter',
                },
              },
              {
                'type': 'button',
                'label': 'Add 10 to Score',
                'click': {
                  'type': 'state',
                  'action': 'increment',
                  'path': 'score',
                  'value': 10,
                },
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Counter: 10'), findsOneWidget);
        expect(find.text('Score: 100'), findsOneWidget);
        
        await tester.tap(find.text('Increment Counter'));
        await tester.pump();
        expect(find.text('Counter: 11'), findsOneWidget);
        
        await tester.tap(find.text('Add 10 to Score'));
        await tester.pump();
        expect(find.text('Score: 110'), findsOneWidget);
      });
      
      testWidgets('should handle decrement action', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'lives': 5,
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
                'content': 'Lives: {{lives}}',
              },
              {
                'type': 'button',
                'label': 'Lose a Life',
                'click': {
                  'type': 'state',
                  'action': 'decrement',
                  'path': 'lives',
                },
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Lives: 5'), findsOneWidget);
        
        await tester.tap(find.text('Lose a Life'));
        await tester.pump();
        expect(find.text('Lives: 4'), findsOneWidget);
      });
      
      testWidgets('should handle toggle action', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'isVisible': true,
                  'darkMode': false,
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
                'content': 'Visible: {{isVisible}}',
              },
              {
                'type': 'text',
                'content': 'Dark Mode: {{darkMode}}',
              },
              {
                'type': 'button',
                'label': 'Toggle Visibility',
                'click': {
                  'type': 'state',
                  'action': 'toggle',
                  'path': 'isVisible',
                },
              },
              {
                'type': 'button',
                'label': 'Toggle Dark Mode',
                'click': {
                  'type': 'state',
                  'action': 'toggle',
                  'path': 'darkMode',
                },
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Visible: true'), findsOneWidget);
        expect(find.text('Dark Mode: false'), findsOneWidget);
        
        await tester.tap(find.text('Toggle Visibility'));
        await tester.pump();
        expect(find.text('Visible: false'), findsOneWidget);
        
        await tester.tap(find.text('Toggle Dark Mode'));
        await tester.pump();
        expect(find.text('Dark Mode: true'), findsOneWidget);
      });
      
      testWidgets('should handle append and remove actions', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'todos': ['Task 1', 'Task 2'],
                  'newTask': '',
                },
              },
            },
          },
          'content': {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'list',
                'items': '{{todos}}',
                'shrinkWrap': true,
                'itemTemplate': {
                  'type': 'linear',
                  'direction': 'horizontal',
                  'distribution': 'space-between',
                  'children': [
                    {
                      'type': 'text',
                      'content': '{{item}}',
                    },
                    {
                      'type': 'button',
                      'label': 'Remove',
                      'click': {
                        'type': 'state',
                        'action': 'remove',
                        'path': 'todos',
                        'index': '{{index}}',
                      },
                    },
                  ],
                },
              },
              {
                'type': 'textInput',
                'label': 'New Task',
                'value': '{{newTask}}',
                'change': {
                  'type': 'state',
                  'action': 'set',
                  'path': 'newTask',
                  'value': '{{event.value}}',
                },
              },
              {
                'type': 'button',
                'label': 'Add Task',
                'click': {
                  'type': 'batch',
                  'actions': [
                    {
                      'type': 'state',
                      'action': 'append',
                      'path': 'todos',
                      'value': '{{newTask}}',
                    },
                    {
                      'type': 'state',
                      'action': 'set',
                      'path': 'newTask',
                      'value': '',
                    },
                  ],
                },
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Task 1'), findsOneWidget);
        expect(find.text('Task 2'), findsOneWidget);
        
        // Add a new task
        await tester.enterText(find.byType(TextField), 'Task 3');
        await tester.pumpAndSettle();
        
        await tester.tap(find.text('Add Task'));
        await tester.pumpAndSettle();
        
        expect(find.text('Task 3'), findsOneWidget);
        expect(runtime.stateManager.get('todos.length'), 3);
        
        // Remove the middle task
        await tester.tap(find.text('Remove').at(1));
        await tester.pumpAndSettle();
        
        expect(find.text('Task 1'), findsOneWidget);
        expect(find.text('Task 2'), findsNothing);
        expect(find.text('Task 3'), findsOneWidget);
        expect(runtime.stateManager.get('todos.length'), 2);
      });
    });
    
    group('State Subscriptions', () {
      testWidgets('should react to state changes from subscriptions', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'serverTime': 'Loading...',
                  'connectionStatus': 'disconnected',
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
                'content': 'Server Time: {{serverTime}}',
              },
              {
                'type': 'text',
                'content': 'Status: {{connectionStatus}}',
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Server Time: Loading...'), findsOneWidget);
        expect(find.text('Status: disconnected'), findsOneWidget);
        
        // Simulate subscription updates
        runtime.stateManager.set('connectionStatus', 'connected');
        await tester.pump();
        expect(find.text('Status: connected'), findsOneWidget);
        
        runtime.stateManager.set('serverTime', '2024-01-01 12:00:00');
        await tester.pump();
        expect(find.text('Server Time: 2024-01-01 12:00:00'), findsOneWidget);
      });
    });
    
    group('Computed State', () {
      testWidgets('should support computed values in expressions', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'firstName': 'John',
                  'lastName': 'Doe',
                  'items': [
                    {'name': 'Apple', 'price': 1.5, 'quantity': 3},
                    {'name': 'Banana', 'price': 0.8, 'quantity': 5},
                    {'name': 'Orange', 'price': 2.0, 'quantity': 2},
                  ],
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
                'content': 'Full Name: {{firstName}} {{lastName}}',
              },
              {
                'type': 'text',
                'content': 'Total Items: {{items.length}}',
              },
              {
                'type': 'list',
                'items': '{{items}}',
                'shrinkWrap': true,
                'itemTemplate': {
                  'type': 'text',
                  'content': '{{item.name}}: \${{item.price * item.quantity}}',
                },
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Full Name: John Doe'), findsOneWidget);
        expect(find.text('Total Items: 3'), findsOneWidget);
        expect(find.text('Apple: \$4.5'), findsOneWidget);
        expect(find.text('Banana: \$4'), findsOneWidget);
        expect(find.text('Orange: \$4'), findsOneWidget);
      });
    });
    
    group('State Persistence', () {
      test('should maintain state across widget rebuilds', () async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'persistentValue': 'Initial',
                },
              },
            },
          },
          'content': {'type': 'box'},
        });
        
        expect(runtime.stateManager.get('persistentValue'), 'Initial');
        
        runtime.stateManager.set('persistentValue', 'Updated');
        expect(runtime.stateManager.get('persistentValue'), 'Updated');
        
        // Simulate widget rebuild by triggering a state change
        // State manager should maintain state across rebuilds
        runtime.stateManager.notifyListeners();
        
        // State should persist after rebuild
        expect(runtime.stateManager.get('persistentValue'), 'Updated');
      });
    });
    
    group('State Validation', () {
      test('should handle invalid state paths gracefully', () async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'data': {'value': 10},
                },
              },
            },
          },
          'content': {'type': 'box'},
        });
        
        // Valid path
        expect(runtime.stateManager.get('data.value'), 10);
        
        // Invalid paths should return null
        expect(runtime.stateManager.get('data.nonexistent'), null);
        expect(runtime.stateManager.get('nonexistent.path'), null);
        expect(runtime.stateManager.get('data.value.nested'), null);
      });
      
      test('should handle type conversions', () async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'stringNumber': '42',
                  'boolString': 'true',
                  'numberBool': 1,
                },
              },
            },
          },
          'content': {'type': 'box'},
        });
        
        expect(runtime.stateManager.get('stringNumber'), '42');
        expect(runtime.stateManager.get('boolString'), 'true');
        expect(runtime.stateManager.get('numberBool'), 1);
      });
    });
  });
}