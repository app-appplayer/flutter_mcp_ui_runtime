import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';

/// MCP UI DSL v1.0 Widget Specification Compliance Test
/// 
/// This test verifies that all widgets defined in the MCP UI DSL v1.0 spec
/// are properly implemented and behave according to the specification.
void main() {
  group('MCP UI DSL v1.0 Widget Specification Compliance', () {
    late MCPUIRuntime runtime;
    late WidgetRegistry widgetRegistry;
    
    setUp(() {
      runtime = MCPUIRuntime();
      widgetRegistry = WidgetRegistry();
      DefaultWidgets.registerAll(widgetRegistry);
    });
    
    tearDown(() {
      runtime.destroy();
    });
    
    group('Layout Widgets', () {
      group('linear', () {
        test('should be registered', () {
          expect(widgetRegistry.has('linear'), isTrue,
              reason: 'linear widget must be registered per v1.0 spec');
        });
        
        testWidgets('should support vertical direction', (WidgetTester tester) async {
          await runtime.initialize({
            'type': 'page',
            'content': {
              'type': 'linear',
              'direction': 'vertical',
              'children': [
                {'type': 'text', 'content': 'Item 1'},
                {'type': 'text', 'content': 'Item 2'},
              ],
            },
          });
          
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
          await tester.pump();
          
          expect(find.text('Item 1'), findsOneWidget);
          expect(find.text('Item 2'), findsOneWidget);
          
          // Verify vertical layout
          final item1Offset = tester.getTopLeft(find.text('Item 1'));
          final item2Offset = tester.getTopLeft(find.text('Item 2'));
          expect(item2Offset.dy, greaterThan(item1Offset.dy));
          expect(item2Offset.dx, equals(item1Offset.dx));
        });
        
        testWidgets('should support horizontal direction', (WidgetTester tester) async {
          await runtime.initialize({
            'type': 'page',
            'content': {
              'type': 'linear',
              'direction': 'horizontal',
              'children': [
                {'type': 'text', 'content': 'A'},
                {'type': 'text', 'content': 'B'},
              ],
            },
          });
          
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
          await tester.pump();
          
          // Verify horizontal layout
          final aOffset = tester.getTopLeft(find.text('A'));
          final bOffset = tester.getTopLeft(find.text('B'));
          expect(bOffset.dx, greaterThan(aOffset.dx));
          expect(bOffset.dy, equals(aOffset.dy));
        });
        
        testWidgets('should support gap property', (WidgetTester tester) async {
          await runtime.initialize({
            'type': 'page',
            'content': {
              'type': 'linear',
              'direction': 'horizontal',
              'gap': 20.0,
              'children': [
                {'type': 'text', 'content': 'A'},
                {'type': 'text', 'content': 'B'},
              ],
            },
          });
          
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
          await tester.pump();
          
          final aRect = tester.getRect(find.text('A'));
          final bRect = tester.getRect(find.text('B'));
          final gap = bRect.left - aRect.right;
          expect(gap, closeTo(20.0, 1.0));
        });
        
        testWidgets('should support distribution property', (WidgetTester tester) async {
          await runtime.initialize({
            'type': 'page',
            'content': {
              'type': 'linear',
              'direction': 'horizontal',
              'distribution': 'space-between',
              'children': [
                {'type': 'text', 'content': 'Start'},
                {'type': 'text', 'content': 'End'},
              ],
            },
          });
          
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
          await tester.pump();
          
          final containerSize = tester.getSize(find.byType(Row));
          final startRect = tester.getRect(find.text('Start'));
          final endRect = tester.getRect(find.text('End'));
          
          // Should be at opposite ends
          expect(startRect.left, lessThan(containerSize.width / 4));
          expect(endRect.right, greaterThan(containerSize.width * 3 / 4));
        });
        
        testWidgets('should support alignment property', (WidgetTester tester) async {
          await runtime.initialize({
            'type': 'page',
            'content': {
              'type': 'box',
              'height': 200,
              'child': {
                'type': 'linear',
                'direction': 'horizontal',
                'alignment': 'center',
                'children': [
                  {'type': 'text', 'content': 'Centered'},
                ],
              },
            },
          });
          
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
          await tester.pump();
          
          final containerRect = tester.getRect(find.byType(Container).first);
          final textRect = tester.getRect(find.text('Centered'));
          
          // Should be vertically centered
          final expectedCenter = containerRect.top + (containerRect.height / 2);
          final actualCenter = textRect.top + (textRect.height / 2);
          expect(actualCenter, closeTo(expectedCenter, 5.0));
        });
      });
      
      group('box', () {
        test('should be registered', () {
          expect(widgetRegistry.has('box'), isTrue,
              reason: 'box widget must be registered per v1.0 spec');
        });
        
        testWidgets('should support width and height', (WidgetTester tester) async {
          await runtime.initialize({
            'type': 'page',
            'content': {
              'type': 'box',
              'width': 100,
              'height': 50,
              'backgroundColor': '#FF0000',
            },
          });
          
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
          await tester.pump();
          
          final container = tester.widget<Container>(find.byType(Container).first);
          expect(container.constraints?.maxWidth, 100);
          expect(container.constraints?.maxHeight, 50);
        });
        
        testWidgets('should support padding', (WidgetTester tester) async {
          await runtime.initialize({
            'type': 'page',
            'content': {
              'type': 'box',
              'padding': {'all': 20},
              'child': {'type': 'text', 'content': 'Padded'},
            },
          });
          
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
          await tester.pump();
          
          final padding = tester.widget<Padding>(find.byType(Padding).first);
          expect(padding.padding, const EdgeInsets.all(20));
        });
        
        testWidgets('should support backgroundColor', (WidgetTester tester) async {
          await runtime.initialize({
            'type': 'page',
            'content': {
              'type': 'box',
              'width': 100,
              'height': 100,
              'backgroundColor': '#FF0000',
            },
          });
          
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
          await tester.pump();
          
          final container = tester.widget<Container>(find.byType(Container).first);
          final decoration = container.decoration as BoxDecoration?;
          expect(decoration?.color, const Color(0xFFFF0000));
        });
      });
      
      group('stack', () {
        test('should be registered', () {
          expect(widgetRegistry.has('stack'), isTrue,
              reason: 'stack widget must be registered per v1.0 spec');
        });
        
        testWidgets('should layer children on top of each other', (WidgetTester tester) async {
          await runtime.initialize({
            'type': 'page',
            'content': {
              'type': 'stack',
              'children': [
                {
                  'type': 'box',
                  'width': 200,
                  'height': 200,
                  'backgroundColor': '#FF0000',
                },
                {
                  'type': 'positioned',
                  'top': 50,
                  'left': 50,
                  'child': {
                    'type': 'box',
                    'width': 100,
                    'height': 100,
                    'backgroundColor': '#00FF00',
                  },
                },
              ],
            },
          });
          
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
          await tester.pump();
          
          // MaterialApp and Scaffold add their own Stack widgets, so we need to find at least one
          expect(find.byType(Stack), findsWidgets);
          expect(find.byType(Positioned), findsOneWidget);
        });
      });
    });
    
    group('Display Widgets', () {
      group('text', () {
        test('should be registered', () {
          expect(widgetRegistry.has('text'), isTrue,
              reason: 'text widget must be registered per v1.0 spec');
        });
        
        testWidgets('should display static content', (WidgetTester tester) async {
          await runtime.initialize({
            'type': 'page',
            'content': {
              'type': 'text',
              'content': 'Hello World',
            },
          });
          
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
          await tester.pump();
          
          expect(find.text('Hello World'), findsOneWidget);
        });
        
        testWidgets('should support style properties', (WidgetTester tester) async {
          await runtime.initialize({
            'type': 'page',
            'content': {
              'type': 'text',
              'content': 'Styled Text',
              'style': {
                'fontSize': 24,
                'fontWeight': 'bold',
                'color': '#FF0000',
              },
            },
          });
          
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
          await tester.pump();
          
          final text = tester.widget<Text>(find.text('Styled Text'));
          expect(text.style?.fontSize, 24);
          expect(text.style?.fontWeight, FontWeight.bold);
          expect(text.style?.color, const Color(0xFFFF0000));
        });
        
        testWidgets('should support data binding', (WidgetTester tester) async {
          await runtime.initialize({
            'type': 'page',
            'runtime': {
              'services': {
                'state': {
                  'initialState': {
                    'message': 'Bound Text',
                  },
                },
              },
            },
            'content': {
              'type': 'text',
              'content': '{{message}}',
            },
          });
          
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
          await tester.pump();
          
          expect(find.text('Bound Text'), findsOneWidget);
        });
      });
      
      group('image', () {
        test('should be registered', () {
          expect(widgetRegistry.has('image'), isTrue,
              reason: 'image widget must be registered per v1.0 spec');
        });
        
        testWidgets('should support src property', (WidgetTester tester) async {
          await runtime.initialize({
            'type': 'page',
            'content': {
              'type': 'image',
              'src': 'assets/test.png',
              'width': 100,
              'height': 100,
            },
          });
          
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
          await tester.pump();
          
          expect(find.byType(Image), findsOneWidget);
        });
      });
      
      group('icon', () {
        test('should be registered', () {
          expect(widgetRegistry.has('icon'), isTrue,
              reason: 'icon widget must be registered per v1.0 spec');
        });
        
        testWidgets('should display icon by name', (WidgetTester tester) async {
          await runtime.initialize({
            'type': 'page',
            'content': {
              'type': 'icon',
              'icon': 'star',
              'size': 48,
              'color': '#FFD700',
            },
          });
          
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
          await tester.pump();
          
          final icon = tester.widget<Icon>(find.byType(Icon));
          expect(icon.icon, Icons.star);
          expect(icon.size, 48);
          expect(icon.color, const Color(0xFFFFD700));
        });
      });
    });
    
    group('Input Widgets', () {
      group('button', () {
        test('should be registered', () {
          expect(widgetRegistry.has('button'), isTrue,
              reason: 'button widget must be registered per v1.0 spec');
        });
        
        testWidgets('should display label', (WidgetTester tester) async {
          await runtime.initialize({
            'type': 'page',
            'content': {
              'type': 'button',
              'label': 'Click Me',
            },
          });
          
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
          await tester.pump();
          
          expect(find.text('Click Me'), findsOneWidget);
          expect(find.byType(ElevatedButton), findsOneWidget);
        });
        
        testWidgets('should handle click event', (WidgetTester tester) async {
          var clicked = false;
          
          await runtime.initialize({
            'type': 'page',
            'content': {
              'type': 'button',
              'label': 'Test Button',
              'click': {
                'type': 'tool',
                'tool': 'handleClick',
              },
            },
          });
          
          runtime.registerToolExecutor('handleClick', (params) async {
            clicked = true;
            return {'success': true};
          });
          
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
          await tester.pump();
          
          await tester.tap(find.byType(ElevatedButton));
          await tester.pump();
          
          expect(clicked, isTrue);
        });
      });
      
      group('textInput', () {
        test('should be registered', () {
          expect(widgetRegistry.has('textInput'), isTrue,
              reason: 'textInput widget must be registered per v1.0 spec');
        });
        
        testWidgets('should support label and placeholder', (WidgetTester tester) async {
          await runtime.initialize({
            'type': 'page',
            'content': {
              'type': 'textInput',
              'label': 'Email',
              'placeholder': 'user@example.com',
            },
          });
          
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
          await tester.pump();
          
          expect(find.text('Email'), findsOneWidget);
          final textField = tester.widget<TextField>(find.byType(TextField));
          expect(textField.decoration?.hintText, 'user@example.com');
        });
        
        testWidgets('should handle change event', (WidgetTester tester) async {
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
              'type': 'textInput',
              'value': '{{inputValue}}',
              'change': {
                'type': 'state',
                'action': 'set',
                'path': 'inputValue',
                'value': '{{event.value}}',
              },
            },
          });
          
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
          await tester.pump();
          
          await tester.enterText(find.byType(TextField), 'Test Input');
          await tester.pump();
          
          expect(runtime.stateManager.get('inputValue'), 'Test Input');
        });
      });
      
      group('checkbox', () {
        test('should be registered', () {
          expect(widgetRegistry.has('checkbox'), isTrue,
              reason: 'checkbox widget must be registered per v1.0 spec');
        });
        
        testWidgets('should toggle state', (WidgetTester tester) async {
          await runtime.initialize({
            'type': 'page',
            'runtime': {
              'services': {
                'state': {
                  'initialState': {
                    'isChecked': false,
                  },
                },
              },
            },
            'content': {
              'type': 'checkbox',
              'label': 'Agree to terms',
              'value': '{{isChecked}}',
              'change': {
                'type': 'state',
                'action': 'set',
                'path': 'isChecked',
                'value': '{{event.value}}',
              },
            },
          });
          
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
          await tester.pump();
          
          expect(runtime.stateManager.get('isChecked'), false);
          
          await tester.tap(find.byType(Checkbox));
          await tester.pump();
          
          expect(runtime.stateManager.get('isChecked'), true);
        });
      });
      
      group('select', () {
        test('should be registered', () {
          expect(widgetRegistry.has('select'), isTrue,
              reason: 'select widget must be registered per v1.0 spec');
        });
        
        testWidgets('should display items', (WidgetTester tester) async {
          await runtime.initialize({
            'type': 'page',
            'content': {
              'type': 'select',
              'label': 'Choose option',
              'value': 'opt1',
              'items': [
                {'value': 'opt1', 'label': 'Option 1'},
                {'value': 'opt2', 'label': 'Option 2'},
              ],
            },
          });
          
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
          await tester.pump();
          
          expect(find.byType(DropdownButton<dynamic>), findsOneWidget);
          
          // Verify the dropdown has the correct value
          final dropdown = tester.widget<DropdownButton<dynamic>>(
            find.byType(DropdownButton<dynamic>)
          );
          expect(dropdown.value, 'opt1');
          expect(dropdown.items?.length, 2);
        });
      });
    });
    
    group('List Widgets', () {
      group('list', () {
        test('should be registered', () {
          expect(widgetRegistry.has('list'), isTrue,
              reason: 'list widget must be registered per v1.0 spec');
        });
        
        testWidgets('should render static items', (WidgetTester tester) async {
          await runtime.initialize({
            'type': 'page',
            'content': {
              'type': 'list',
              'children': [
                {'type': 'text', 'content': 'Item 1'},
                {'type': 'text', 'content': 'Item 2'},
                {'type': 'text', 'content': 'Item 3'},
              ],
            },
          });
          
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
          await tester.pump();
          
          expect(find.text('Item 1'), findsOneWidget);
          expect(find.text('Item 2'), findsOneWidget);
          expect(find.text('Item 3'), findsOneWidget);
        });
        
        testWidgets('should support itemTemplate', (WidgetTester tester) async {
          await runtime.initialize({
            'type': 'page',
            'runtime': {
              'services': {
                'state': {
                  'initialState': {
                    'users': [
                      {'name': 'Alice', 'age': 25},
                      {'name': 'Bob', 'age': 30},
                    ],
                  },
                },
              },
            },
            'content': {
              'type': 'list',
              'items': '{{users}}',
              'itemTemplate': {
                'type': 'listTile',
                'title': '{{item.name}}',
                'subtitle': 'Age: {{item.age}}',
              },
            },
          });
          
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
          await tester.pump();
          
          expect(find.text('Alice'), findsOneWidget);
          expect(find.text('Age: 25'), findsOneWidget);
          expect(find.text('Bob'), findsOneWidget);
          expect(find.text('Age: 30'), findsOneWidget);
        });
      });
    });
    
    group('Navigation Widgets', () {
      group('headerBar', () {
        test('should be registered', () {
          expect(widgetRegistry.has('headerBar'), isTrue,
              reason: 'headerBar widget must be registered per v1.0 spec');
        });
        
        testWidgets('should display title', (WidgetTester tester) async {
          await runtime.initialize({
            'type': 'page',
            'content': {
              'type': 'linear',
              'direction': 'vertical',
              'children': [
                {
                  'type': 'headerBar',
                  'title': 'My App',
                },
                {
                  'type': 'text',
                  'content': 'Content',
                },
              ],
            },
          });
          
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
          await tester.pump();
          
          expect(find.text('My App'), findsOneWidget);
          expect(find.byType(AppBar), findsOneWidget);
        });
      });
    });
    
    group('Special Widgets', () {
      group('conditional', () {
        test('should be registered', () {
          expect(widgetRegistry.has('conditional'), isTrue,
              reason: 'conditional widget must be registered per v1.0 spec');
        });
        
        testWidgets('should render based on condition', (WidgetTester tester) async {
          await runtime.initialize({
            'type': 'page',
            'runtime': {
              'services': {
                'state': {
                  'initialState': {
                    'showContent': true,
                  },
                },
              },
            },
            'content': {
              'type': 'conditional',
              'condition': '{{showContent}}',
              'then': {
                'type': 'text',
                'content': 'Visible Content',
              },
              'orElse': {
                'type': 'text',
                'content': 'Hidden Content',
              },
            },
          });
          
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
          await tester.pump();
          
          expect(find.text('Visible Content'), findsOneWidget);
          expect(find.text('Hidden Content'), findsNothing);
          
          runtime.stateManager.set('showContent', false);
          await tester.pump();
          
          expect(find.text('Visible Content'), findsNothing);
          expect(find.text('Hidden Content'), findsOneWidget);
        });
      });
    });
  });
}