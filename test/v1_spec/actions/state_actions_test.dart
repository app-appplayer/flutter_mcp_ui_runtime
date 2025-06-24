import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

/// MCP UI DSL v1.0 State Actions Tests
/// 
/// Tests state manipulation actions according to MCP UI DSL v1.0 specification.
/// Reference: Spec Section 6.1 - Action Types
void main() {
  group('MCP UI DSL v1.0 - State Actions', () {
    late MCPUIRuntime runtime;
    
    setUp(() {
      runtime = MCPUIRuntime();
    });
    
    tearDown(() {
      runtime.destroy();
    });
    
    group('Set Action (Spec 6.1.1)', () {
      testWidgets('should set simple state value using path parameter', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
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
                'content': '{{message}}',
              },
              {
                'type': 'button',
                'label': 'Update Message',
                'click': {
                  'type': 'state',
                  'action': 'set',
                  'path': 'message', // v1.0 spec: uses 'path' not 'key'
                  'value': 'Updated',
                },
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pumpAndSettle();
        
        expect(find.text('Initial'), findsOneWidget);
        
        await tester.tap(find.text('Update Message'));
        await tester.pumpAndSettle();
        
        expect(find.text('Updated'), findsOneWidget);
      });
      
      testWidgets('should set nested state value', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'user': {
                    'profile': {
                      'name': 'John',
                      'age': 25,
                    },
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
                'content': '{{user.profile.name}} ({{user.profile.age}})',
              },
              {
                'type': 'button',
                'label': 'Update Name',
                'click': {
                  'type': 'state',
                  'action': 'set',
                  'path': 'user.profile.name',
                  'value': 'Jane',
                },
              },
              {
                'type': 'button',
                'label': 'Update Age',
                'click': {
                  'type': 'state',
                  'action': 'set',
                  'path': 'user.profile.age',
                  'value': 30,
                },
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pumpAndSettle();
        
        expect(find.text('John (25)'), findsOneWidget);
        
        await tester.tap(find.text('Update Name'));
        await tester.pumpAndSettle();
        
        expect(find.text('Jane (25)'), findsOneWidget);
        
        await tester.tap(find.text('Update Age'));
        await tester.pumpAndSettle();
        
        expect(find.text('Jane (30)'), findsOneWidget);
      });
      
      testWidgets('should set value from event data', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'inputValue': '',
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
                'label': 'Enter text',
                'value': '{{inputValue}}',
                'change': {
                  'type': 'state',
                  'action': 'set',
                  'path': 'inputValue',
                  'value': '{{event.value}}', // v1.0 spec: event data binding
                },
              },
              {
                'type': 'text',
                'content': 'You typed: {{inputValue}}',
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pumpAndSettle();
        
        await tester.enterText(find.byType(TextField), 'Hello MCP');
        await tester.pumpAndSettle();
        
        expect(find.text('You typed: Hello MCP'), findsOneWidget);
      });
    });
    
    group('Increment Action (Spec 6.1.2)', () {
      testWidgets('should increment by 1 when no value specified', (WidgetTester tester) async {
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
                'content': 'Counter: {{counter}}',
              },
              {
                'type': 'button',
                'label': 'Increment',
                'click': {
                  'type': 'state',
                  'action': 'increment',
                  'path': 'counter',
                },
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pumpAndSettle();
        
        expect(find.text('Counter: 10'), findsOneWidget);
        
        await tester.tap(find.text('Increment'));
        await tester.pumpAndSettle();
        
        expect(find.text('Counter: 11'), findsOneWidget);
      });
      
      testWidgets('should increment by custom value', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
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
                'content': 'Score: {{score}}',
              },
              {
                'type': 'button',
                'label': 'Add 25 Points',
                'click': {
                  'type': 'state',
                  'action': 'increment',
                  'path': 'score',
                  'value': 25,
                },
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pumpAndSettle();
        
        expect(find.text('Score: 100'), findsOneWidget);
        
        await tester.tap(find.text('Add 25 Points'));
        await tester.pumpAndSettle();
        
        expect(find.text('Score: 125'), findsOneWidget);
      });
    });
    
    group('Decrement Action (Spec 6.1.3)', () {
      testWidgets('should decrement by 1 when no value specified', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'lives': 3,
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
                'label': 'Lose Life',
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
        await tester.pumpAndSettle();
        
        expect(find.text('Lives: 3'), findsOneWidget);
        
        await tester.tap(find.text('Lose Life'));
        await tester.pumpAndSettle();
        
        expect(find.text('Lives: 2'), findsOneWidget);
      });
      
      testWidgets('should decrement by custom value', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'health': 100,
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
                'content': 'Health: {{health}}',
              },
              {
                'type': 'button',
                'label': 'Take 15 Damage',
                'click': {
                  'type': 'state',
                  'action': 'decrement',
                  'path': 'health',
                  'value': 15,
                },
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pumpAndSettle();
        
        expect(find.text('Health: 100'), findsOneWidget);
        
        await tester.tap(find.text('Take 15 Damage'));
        await tester.pumpAndSettle();
        
        expect(find.text('Health: 85'), findsOneWidget);
      });
    });
    
    group('Toggle Action (Spec 6.1.4)', () {
      testWidgets('should toggle boolean value', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'isDarkMode': false,
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
                'content': 'Dark Mode: {{isDarkMode ? "ON" : "OFF"}}',
              },
              {
                'type': 'button',
                'label': 'Toggle Dark Mode',
                'click': {
                  'type': 'state',
                  'action': 'toggle',
                  'path': 'isDarkMode',
                },
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pumpAndSettle();
        
        expect(find.text('Dark Mode: OFF'), findsOneWidget);
        
        await tester.tap(find.text('Toggle Dark Mode'));
        await tester.pumpAndSettle();
        
        expect(find.text('Dark Mode: ON'), findsOneWidget);
        
        await tester.tap(find.text('Toggle Dark Mode'));
        await tester.pumpAndSettle();
        
        expect(find.text('Dark Mode: OFF'), findsOneWidget);
      });
    });
    
    group('Append Action (Spec 6.1.5)', () {
      testWidgets('should append to array', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'items': ['Item 1', 'Item 2'],
                  'newItem': '',
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
                'shrinkWrap': true,
                'items': '{{items}}',
                'itemTemplate': {
                  'type': 'text',
                  'content': '{{item}}',
                },
              },
              {
                'type': 'textInput',
                'label': 'New Item',
                'value': '{{newItem}}',
                'change': {
                  'type': 'state',
                  'action': 'set',
                  'path': 'newItem',
                  'value': '{{event.value}}',
                },
              },
              {
                'type': 'button',
                'label': 'Add Item',
                'click': {
                  'type': 'state',
                  'action': 'append',
                  'path': 'items',
                  'value': '{{newItem}}',
                },
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pumpAndSettle();
        
        expect(find.text('Item 1'), findsOneWidget);
        expect(find.text('Item 2'), findsOneWidget);
        
        await tester.enterText(find.byType(TextField), 'Item 3');
        await tester.pumpAndSettle();
        
        await tester.tap(find.text('Add Item'));
        await tester.pumpAndSettle();
        
        // After appending, Item 3 appears in the list and remains in the text field
        expect(find.text('Item 3'), findsNWidgets(2));
      });
      
      testWidgets('should append object to array', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'todos': [
                    {'id': 1, 'text': 'First todo'},
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
                'type': 'list',
                'shrinkWrap': true,
                'items': '{{todos}}',
                'itemTemplate': {
                  'type': 'text',
                  'content': '{{item.id}}. {{item.text}}',
                },
              },
              {
                'type': 'button',
                'label': 'Add Todo',
                'click': {
                  'type': 'state',
                  'action': 'append',
                  'path': 'todos',
                  'value': {
                    'id': 2,
                    'text': 'Second todo',
                  },
                },
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pumpAndSettle();
        
        expect(find.text('1. First todo'), findsOneWidget);
        
        await tester.tap(find.text('Add Todo'));
        await tester.pumpAndSettle();
        
        expect(find.text('2. Second todo'), findsOneWidget);
      });
    });
    
    group('Remove Action (Spec 6.1.6)', () {
      testWidgets('should remove from array by index', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'colors': ['Red', 'Green', 'Blue'],
                },
              },
            },
          },
          'content': {
            'type': 'list',
                'shrinkWrap': true,
            'items': '{{colors}}',
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
                    'path': 'colors',
                    'index': '{{index}}',
                  },
                },
              ],
            },
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pumpAndSettle();
        
        expect(find.text('Red'), findsOneWidget);
        expect(find.text('Green'), findsOneWidget);
        expect(find.text('Blue'), findsOneWidget);
        
        // Remove middle item (Green)
        await tester.tap(find.text('Remove').at(1));
        await tester.pumpAndSettle();
        
        expect(find.text('Red'), findsOneWidget);
        expect(find.text('Green'), findsNothing);
        expect(find.text('Blue'), findsOneWidget);
      });
      
      testWidgets('should remove from array by value', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'tags': ['javascript', 'python', 'rust'],
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
                'shrinkWrap': true,
                'items': '{{tags}}',
                'itemTemplate': {
                  'type': 'chip',
                  'label': '{{item}}',
                },
              },
              {
                'type': 'button',
                'label': 'Remove Python',
                'click': {
                  'type': 'state',
                  'action': 'remove',
                  'path': 'tags',
                  'value': 'python',
                },
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pumpAndSettle();
        
        expect(find.text('javascript'), findsOneWidget);
        expect(find.text('python'), findsOneWidget);
        expect(find.text('rust'), findsOneWidget);
        
        await tester.tap(find.text('Remove Python'));
        await tester.pumpAndSettle();
        
        expect(find.text('javascript'), findsOneWidget);
        expect(find.text('python'), findsNothing);
        expect(find.text('rust'), findsOneWidget);
      });
    });
  });
}