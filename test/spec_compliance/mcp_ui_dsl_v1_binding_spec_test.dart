import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

/// MCP UI DSL v1.0 Binding Engine Specification Compliance Test
/// 
/// This test verifies that the binding engine correctly implements
/// the expression evaluation and data binding as defined in the spec.
void main() {
  group('MCP UI DSL v1.0 Binding Engine Specification Compliance', () {
    late MCPUIRuntime runtime;
    
    setUp(() {
      runtime = MCPUIRuntime();
    });
    
    tearDown(() {
      runtime.destroy();
    });
    
    group('Simple Bindings', () {
      testWidgets('should bind single property value', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'title': 'Hello World',
                },
              },
            },
          },
          'content': {
            'type': 'text',
            'content': '{{title}}',
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pumpAndSettle();
        
        expect(find.text('Hello World'), findsOneWidget);
      });
      
      testWidgets('should bind numeric values', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'count': 42,
                  'price': 19.99,
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
                'content': 'Count: {{count}}',
              },
              {
                'type': 'text',
                'content': 'Price: \${{price}}',
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pumpAndSettle();
        
        expect(find.text('Count: 42'), findsOneWidget);
        expect(find.text('Price: \$19.99'), findsOneWidget);
      });
      
      testWidgets('should bind boolean values', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'isActive': true,
                  'isDisabled': false,
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
                'content': 'Active: {{isActive}}',
              },
              {
                'type': 'text',
                'content': 'Disabled: {{isDisabled}}',
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pumpAndSettle();
        
        expect(find.text('Active: true'), findsOneWidget);
        expect(find.text('Disabled: false'), findsOneWidget);
      });
    });
    
    group('Nested Property Access', () {
      testWidgets('should access nested object properties', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'user': {
                    'profile': {
                      'name': 'John Doe',
                      'email': 'john@example.com',
                      'settings': {
                        'theme': 'dark',
                        'notifications': true,
                      },
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
                'content': 'Name: {{user.profile.name}}',
              },
              {
                'type': 'text',
                'content': 'Email: {{user.profile.email}}',
              },
              {
                'type': 'text',
                'content': 'Theme: {{user.profile.settings.theme}}',
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pumpAndSettle();
        
        expect(find.text('Name: John Doe'), findsOneWidget);
        expect(find.text('Email: john@example.com'), findsOneWidget);
        expect(find.text('Theme: dark'), findsOneWidget);
      });
      
      testWidgets('should handle null values gracefully', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'user': {
                    'name': null,
                    'profile': null,
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
                'type': 'text',
                'content': 'City: {{user.profile.city}}',
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pumpAndSettle();
        
        // Should display empty string for null values
        expect(find.text('Name: '), findsOneWidget);
        expect(find.text('City: '), findsOneWidget);
      });
    });
    
    group('Array Access', () {
      testWidgets('should access array elements by index', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'items': ['First', 'Second', 'Third'],
                  'numbers': [10, 20, 30, 40],
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
                'content': 'First item: {{items[0]}}',
              },
              {
                'type': 'text',
                'content': 'Third item: {{items[2]}}',
              },
              {
                'type': 'text',
                'content': 'Second number: {{numbers[1]}}',
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pumpAndSettle();
        
        expect(find.text('First item: First'), findsOneWidget);
        expect(find.text('Third item: Third'), findsOneWidget);
        expect(find.text('Second number: 20'), findsOneWidget);
      });
      
      testWidgets('should access array length', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'todos': [
                    {'text': 'Task 1'},
                    {'text': 'Task 2'},
                    {'text': 'Task 3'},
                  ],
                },
              },
            },
          },
          'content': {
            'type': 'text',
            'content': 'Total tasks: {{todos.length}}',
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pumpAndSettle();
        
        expect(find.text('Total tasks: 3'), findsOneWidget);
      });
    });
    
    group('Expression Evaluation', () {
      testWidgets('should evaluate comparison expressions', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'count': 5,
                  'max': 10,
                  'isActive': true,
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
                'content': 'Count > 3: {{count > 3}}',
              },
              {
                'type': 'text',
                'content': 'Count <= max: {{count <= max}}',
              },
              {
                'type': 'text',
                'content': 'Is inactive: {{!isActive}}',
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pumpAndSettle();
        
        expect(find.text('Count > 3: true'), findsOneWidget);
        expect(find.text('Count <= max: true'), findsOneWidget);
        expect(find.text('Is inactive: false'), findsOneWidget);
      });
      
      testWidgets('should evaluate logical expressions', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'isLoggedIn': true,
                  'hasPermission': false,
                  'isAdmin': true,
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
                'content': 'Can access: {{isLoggedIn && hasPermission}}',
              },
              {
                'type': 'text',
                'content': 'Is authorized: {{isAdmin || hasPermission}}',
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pumpAndSettle();
        
        expect(find.text('Can access: false'), findsOneWidget);
        expect(find.text('Is authorized: true'), findsOneWidget);
      });
      
      testWidgets('should evaluate ternary expressions', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'isDarkMode': true,
                  'count': 1,
                  'items': ['a', 'b', 'c'],
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
                'content': 'Theme: {{isDarkMode ? "Dark" : "Light"}}',
              },
              {
                'type': 'text',
                'content': '{{count == 1 ? "1 item" : count + " items"}}',
              },
              {
                'type': 'text',
                'content': 'Status: {{items.length > 0 ? "Has items" : "Empty"}}',
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pumpAndSettle();
        
        expect(find.text('Theme: Dark'), findsOneWidget);
        expect(find.text('1 item'), findsOneWidget);
        expect(find.text('Status: Has items'), findsOneWidget);
      });
    });
    
    group('Event Object Bindings', () {
      testWidgets('should bind event.value in change events', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'inputText': '',
                  'displayText': '',
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
                'value': '{{inputText}}',
                'change': {
                  'type': 'state',
                  'action': 'set',
                  'path': 'inputText',
                  'value': '{{event.value}}',
                },
              },
              {
                'type': 'text',
                'content': 'You typed: {{inputText}}',
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
      
      testWidgets('should bind event properties in click events', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'lastClicked': '',
                  'items': [
                    {'id': 'btn1', 'label': 'Button 1'},
                    {'id': 'btn2', 'label': 'Button 2'},
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
                'items': '{{items}}',
                'itemTemplate': {
                  'type': 'button',
                  'label': '{{item.label}}',
                  'click': {
                    'type': 'state',
                    'action': 'set',
                    'path': 'lastClicked',
                    'value': '{{item.id}}',
                  },
                },
              },
              {
                'type': 'text',
                'content': 'Last clicked: {{lastClicked}}',
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pumpAndSettle();
        
        await tester.tap(find.text('Button 1'));
        await tester.pumpAndSettle();
        
        expect(find.text('Last clicked: btn1'), findsOneWidget);
        
        await tester.tap(find.text('Button 2'));
        await tester.pumpAndSettle();
        
        expect(find.text('Last clicked: btn2'), findsOneWidget);
      });
    });
    
    group('Mixed Content Bindings', () {
      testWidgets('should support bindings within text content', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'name': 'Alice',
                  'age': 25,
                  'city': 'New York',
                },
              },
            },
          },
          'content': {
            'type': 'text',
            'content': 'Hello {{name}}, you are {{age}} years old and live in {{city}}.',
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pumpAndSettle();
        
        expect(
          find.text('Hello Alice, you are 25 years old and live in New York.'),
          findsOneWidget,
        );
      });
      
      testWidgets('should handle multiple bindings in attributes', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'user': {
                    'firstName': 'John',
                    'lastName': 'Doe',
                  },
                  'count': 3,
                },
              },
            },
          },
          'content': {
            'type': 'button',
            'label': '{{user.firstName}} {{user.lastName}} ({{count}} items)',
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pumpAndSettle();
        
        expect(find.text('John Doe (3 items)'), findsOneWidget);
      });
    });
    
    group('Reactive Updates', () {
      testWidgets('should update bindings when state changes', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'counter': 0,
                  'message': 'Click to increment',
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
                'type': 'text',
                'content': '{{message}}',
              },
              {
                'type': 'button',
                'label': 'Increment',
                'click': {
                  'type': 'batch',
                  'actions': [
                    {
                      'type': 'state',
                      'action': 'increment',
                      'path': 'counter',
                    },
                    {
                      'type': 'state',
                      'action': 'set',
                      'path': 'message',
                      'value': 'Counter updated!',
                    },
                  ],
                },
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pumpAndSettle();
        
        expect(find.text('Count: 0'), findsOneWidget);
        expect(find.text('Click to increment'), findsOneWidget);
        
        await tester.tap(find.text('Increment'));
        await tester.pumpAndSettle();
        
        expect(find.text('Count: 1'), findsOneWidget);
        expect(find.text('Counter updated!'), findsOneWidget);
      });
      
      testWidgets('should update nested property bindings', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'form': {
                    'input1': '',
                    'input2': '',
                    'combined': '',
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
                'label': 'First Name',
                'value': '{{form.input1}}',
                'change': {
                  'type': 'state',
                  'action': 'set',
                  'path': 'form.input1',
                  'value': '{{event.value}}',
                },
              },
              {
                'type': 'textInput',
                'label': 'Last Name',
                'value': '{{form.input2}}',
                'change': {
                  'type': 'state',
                  'action': 'set',
                  'path': 'form.input2',
                  'value': '{{event.value}}',
                },
              },
              {
                'type': 'button',
                'label': 'Combine',
                'click': {
                  'type': 'state',
                  'action': 'set',
                  'path': 'form.combined',
                  'value': '{{form.input1}} {{form.input2}}',
                },
              },
              {
                'type': 'text',
                'content': 'Full Name: {{form.combined}}',
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pumpAndSettle();
        
        await tester.enterText(find.byType(TextField).first, 'John');
        await tester.pumpAndSettle();
        
        await tester.enterText(find.byType(TextField).last, 'Doe');
        await tester.pumpAndSettle();
        
        await tester.tap(find.text('Combine'));
        await tester.pumpAndSettle();
        
        expect(find.text('Full Name: John Doe'), findsOneWidget);
      });
    });
    
    group('Edge Cases', () {
      testWidgets('should handle empty bindings', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'empty': '',
                  'nullValue': null,
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
                'content': 'Empty: [{{empty}}]',
              },
              {
                'type': 'text',
                'content': 'Null: [{{nullValue}}]',
              },
              {
                'type': 'text',
                'content': 'Undefined: [{{undefinedValue}}]',
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pumpAndSettle();
        
        expect(find.text('Empty: []'), findsOneWidget);
        expect(find.text('Null: []'), findsOneWidget);
        expect(find.text('Undefined: []'), findsOneWidget);
      });
      
      testWidgets('should handle special characters in bindings', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'email': 'user@example.com',
                  'price': 19.99,
                  'percentage': 95,
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
                'content': 'Contact: {{email}} (verified)',
              },
              {
                'type': 'text',
                'content': 'Price: \${{price}} USD',
              },
              {
                'type': 'text',
                'content': 'Progress: {{percentage}}%',
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pumpAndSettle();
        
        expect(find.text('Contact: user@example.com (verified)'), findsOneWidget);
        expect(find.text('Price: \$19.99 USD'), findsOneWidget);
        expect(find.text('Progress: 95%'), findsOneWidget);
      });
    });
  });
}