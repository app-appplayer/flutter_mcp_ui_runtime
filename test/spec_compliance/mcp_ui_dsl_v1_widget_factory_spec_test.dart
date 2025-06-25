import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';

/// MCP UI DSL v1.0 Widget Factory Specification Compliance Test
/// 
/// This test verifies that widget factories correctly create widgets
/// with all properties as defined in the MCP UI DSL v1.0 specification.
void main() {
  group('MCP UI DSL v1.0 Widget Factory Specification Compliance', () {
    late WidgetRegistry registry;
    late MCPUIRuntime runtime;
    
    setUp(() {
      registry = WidgetRegistry();
      DefaultWidgets.registerAll(registry);
      runtime = MCPUIRuntime();
    });
    
    tearDown(() {
      runtime.destroy();
    });
    
    group('Text Widget Factory', () {
      testWidgets('should create text with all supported properties', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'text',
            'content': 'Test Text',
            'style': {
              'fontSize': 24,
              'fontWeight': 'bold',
              'fontFamily': 'Roboto',
              'color': '#FF0000',
              'decoration': 'underline',
              'letterSpacing': 2.0,
              'wordSpacing': 4.0,
              'height': 1.5,
            },
            'textAlign': 'center',
            'maxLines': 2,
            'overflow': 'ellipsis',
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        final text = tester.widget<Text>(find.text('Test Text'));
        expect(text.style?.fontSize, 24);
        expect(text.style?.fontWeight, FontWeight.bold);
        expect(text.style?.fontFamily, 'Roboto');
        expect(text.style?.color, const Color(0xFFFF0000));
        expect(text.style?.decoration, TextDecoration.underline);
        expect(text.style?.letterSpacing, 2.0);
        expect(text.style?.wordSpacing, 4.0);
        expect(text.style?.height, 1.5);
        expect(text.textAlign, TextAlign.center);
        expect(text.maxLines, 2);
        expect(text.overflow, TextOverflow.ellipsis);
      });
      
      testWidgets('should handle data binding in text content', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'name': 'John',
                  'age': 30,
                },
              },
            },
          },
          'content': {
            'type': 'text',
            'content': 'Hello {{name}}, you are {{age}} years old',
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Hello John, you are 30 years old'), findsOneWidget);
      });
    });
    
    group('Button Widget Factory', () {
      testWidgets('should create button with all variants', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'linear',
            'direction': 'vertical',
            'gap': 10,
            'children': [
              {
                'type': 'button',
                'label': 'Elevated Button',
                'variant': 'elevated',
                'style': {
                  'backgroundColor': '#2196F3',
                  'foregroundColor': '#FFFFFF',
                  'elevation': 4,
                },
              },
              {
                'type': 'button',
                'label': 'Text Button',
                'variant': 'text',
              },
              {
                'type': 'button',
                'label': 'Outlined Button',
                'variant': 'outlined',
                'style': {
                  'borderColor': '#FF5722',
                  'borderWidth': 2,
                },
              },
              {
                'type': 'button',
                'label': 'Icon Button',
                'icon': 'star',
                'variant': 'icon',
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.byType(ElevatedButton), findsOneWidget);
        expect(find.byType(TextButton), findsOneWidget);
        expect(find.byType(OutlinedButton), findsOneWidget);
        expect(find.byType(IconButton), findsOneWidget);
        
        expect(find.text('Elevated Button'), findsOneWidget);
        expect(find.text('Text Button'), findsOneWidget);
        expect(find.text('Outlined Button'), findsOneWidget);
        expect(find.byIcon(Icons.star), findsOneWidget);
      });
      
      testWidgets('should handle button states', (WidgetTester tester) async {
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
                'type': 'button',
                'label': 'Disabled Button',
                'enabled': false,
              },
              {
                'type': 'button',
                'label': 'Dynamic Button',
                'enabled': '{{isEnabled}}',
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        final disabledButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Disabled Button'),
        );
        expect(disabledButton.onPressed, isNull);
        
        final dynamicButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Dynamic Button'),
        );
        expect(dynamicButton.onPressed, isNull);
        
        runtime.stateManager.set('isEnabled', true);
        await tester.pump();
        
        final enabledButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Dynamic Button'),
        );
        expect(enabledButton.onPressed, isNotNull);
      });
    });
    
    group('TextInput Widget Factory', () {
      testWidgets('should create text input with all properties', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'textInput',
            'label': 'Email Address',
            'placeholder': 'user@example.com',
            'value': '',
            'keyboardType': 'emailAddress',
            'obscureText': false,
            'maxLength': 100,
            'maxLines': 1,
            'enabled': true,
            'validator': {
              'type': 'email',
              'message': 'Please enter a valid email',
            },
            'style': {
              'fontSize': 16,
              'color': '#333333',
            },
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Email Address'), findsOneWidget);
        
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.decoration?.hintText, 'user@example.com');
        expect(textField.keyboardType, TextInputType.emailAddress);
        expect(textField.obscureText, false);
        expect(textField.maxLength, 100);
        expect(textField.maxLines, 1);
        expect(textField.enabled, true);
        expect(textField.style?.fontSize, 16);
        expect(textField.style?.color, const Color(0xFF333333));
      });
      
      testWidgets('should support different input types', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'textInput',
                'label': 'Password',
                'obscureText': true,
                'keyboardType': 'text',
              },
              {
                'type': 'textInput',
                'label': 'Phone',
                'keyboardType': 'phone',
              },
              {
                'type': 'textInput',
                'label': 'Number',
                'keyboardType': 'number',
              },
              {
                'type': 'textInput',
                'label': 'Multiline',
                'maxLines': 5,
                'keyboardType': 'multiline',
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        final textFields = tester.widgetList<TextField>(find.byType(TextField));
        final fieldsList = textFields.toList();
        
        expect(fieldsList[0].obscureText, true);
        expect(fieldsList[1].keyboardType, TextInputType.phone);
        expect(fieldsList[2].keyboardType, TextInputType.number);
        expect(fieldsList[3].maxLines, 5);
        expect(fieldsList[3].keyboardType, TextInputType.multiline);
      });
    });
    
    group('Linear Layout Factory', () {
      testWidgets('should create linear layout with all properties', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'linear',
            'direction': 'horizontal',
            'distribution': 'space-between',
            'alignment': 'center',
            'gap': 16,
            'padding': {'all': 20},
            'wrap': false,
            'children': [
              {'type': 'text', 'content': 'Start'},
              {'type': 'text', 'content': 'Center'},
              {'type': 'text', 'content': 'End'},
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Start'), findsOneWidget);
        expect(find.text('Center'), findsOneWidget);
        expect(find.text('End'), findsOneWidget);
        
        // Verify horizontal layout
        final startPos = tester.getTopLeft(find.text('Start'));
        final endPos = tester.getTopLeft(find.text('End'));
        expect(endPos.dx, greaterThan(startPos.dx));
        expect(endPos.dy, equals(startPos.dy));
        
        // Verify padding
        expect(find.byType(Padding), findsOneWidget);
        final padding = tester.widget<Padding>(find.byType(Padding).first);
        expect(padding.padding, const EdgeInsets.all(20));
      });
      
      testWidgets('should support flexible children', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'linear',
            'direction': 'horizontal',
            'children': [
              {
                'type': 'box',
                'flex': 1,
                'backgroundColor': '#FF0000',
                'height': 50,
              },
              {
                'type': 'box',
                'flex': 2,
                'backgroundColor': '#00FF00',
                'height': 50,
              },
              {
                'type': 'box',
                'width': 100,
                'backgroundColor': '#0000FF',
                'height': 50,
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.byType(Flexible), findsNWidgets(2));
        expect(find.byType(Container), findsNWidgets(3));
        
        final flexibles = tester.widgetList<Flexible>(find.byType(Flexible));
        final flexList = flexibles.toList();
        expect(flexList[0].flex, 1);
        expect(flexList[1].flex, 2);
      });
    });
    
    group('List Widget Factory', () {
      testWidgets('should create list with item template', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'users': [
                    {'id': 1, 'name': 'Alice', 'role': 'Admin'},
                    {'id': 2, 'name': 'Bob', 'role': 'User'},
                    {'id': 3, 'name': 'Charlie', 'role': 'Guest'},
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
              'subtitle': 'Role: {{item.role}}',
              'leading': {
                'type': 'icon',
                'icon': 'person',
              },
              'trailing': {
                'type': 'text',
                'content': '#{{item.id}}',
              },
            },
            'physics': 'alwaysScrollable',
            'shrinkWrap': true,
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Alice'), findsOneWidget);
        expect(find.text('Bob'), findsOneWidget);
        expect(find.text('Charlie'), findsOneWidget);
        expect(find.text('Role: Admin'), findsOneWidget);
        expect(find.text('Role: User'), findsOneWidget);
        expect(find.text('Role: Guest'), findsOneWidget);
        expect(find.text('#1'), findsOneWidget);
        expect(find.text('#2'), findsOneWidget);
        expect(find.text('#3'), findsOneWidget);
        expect(find.byIcon(Icons.person), findsNWidgets(3));
      });
      
      testWidgets('should support static children', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'list',
            'children': [
              {
                'type': 'card',
                'child': {
                  'type': 'text',
                  'content': 'Card 1',
                },
              },
              {
                'type': 'card',
                'child': {
                  'type': 'text',
                  'content': 'Card 2',
                },
              },
              {
                'type': 'divider',
              },
              {
                'type': 'card',
                'child': {
                  'type': 'text',
                  'content': 'Card 3',
                },
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.byType(Card), findsNWidgets(3));
        expect(find.text('Card 1'), findsOneWidget);
        expect(find.text('Card 2'), findsOneWidget);
        expect(find.text('Card 3'), findsOneWidget);
        expect(find.byType(Divider), findsOneWidget);
      });
    });
    
    group('Conditional Widget Factory', () {
      testWidgets('should render based on boolean condition', (WidgetTester tester) async {
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
              'content': 'Content is visible',
            },
            'orElse': {
              'type': 'text',
              'content': 'Content is hidden',
            },
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Content is visible'), findsOneWidget);
        expect(find.text('Content is hidden'), findsNothing);
        
        runtime.stateManager.set('showContent', false);
        await tester.pump();
        
        expect(find.text('Content is visible'), findsNothing);
        expect(find.text('Content is hidden'), findsOneWidget);
      });
      
      testWidgets('should support complex conditions', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'userRole': 'admin',
                  'isLoggedIn': true,
                },
              },
            },
          },
          'content': {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'conditional',
                'condition': '{{isLoggedIn && userRole == "admin"}}',
                'then': {
                  'type': 'button',
                  'label': 'Admin Panel',
                },
              },
              {
                'type': 'conditional',
                'condition': '{{isLoggedIn && userRole != "admin"}}',
                'then': {
                  'type': 'button',
                  'label': 'User Dashboard',
                },
              },
              {
                'type': 'conditional',
                'condition': '{{!isLoggedIn}}',
                'then': {
                  'type': 'button',
                  'label': 'Login',
                },
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Admin Panel'), findsOneWidget);
        expect(find.text('User Dashboard'), findsNothing);
        expect(find.text('Login'), findsNothing);
        
        runtime.stateManager.set('userRole', 'user');
        await tester.pump();
        
        expect(find.text('Admin Panel'), findsNothing);
        expect(find.text('User Dashboard'), findsOneWidget);
        expect(find.text('Login'), findsNothing);
        
        runtime.stateManager.set('isLoggedIn', false);
        await tester.pump();
        
        expect(find.text('Admin Panel'), findsNothing);
        expect(find.text('User Dashboard'), findsNothing);
        expect(find.text('Login'), findsOneWidget);
      });
    });
    
    group('Form Widget Factory', () {
      testWidgets('should create form with validation', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'form',
            'children': [
              {
                'type': 'textInput',
                'label': 'Email',
                'value': '',
                'validator': {
                  'type': 'email',
                  'message': 'Invalid email',
                },
              },
              {
                'type': 'textInput',
                'label': 'Password',
                'obscureText': true,
                'value': '',
                'validator': {
                  'type': 'minLength',
                  'value': 8,
                  'message': 'Password must be at least 8 characters',
                },
              },
              {
                'type': 'button',
                'label': 'Submit',
                'submit': {
                  'type': 'tool',
                  'tool': 'submitForm',
                },
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.byType(Form), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
        expect(find.text('Submit'), findsOneWidget);
        
        final textFields = tester.widgetList<TextField>(find.byType(TextField));
        expect(textFields.length, 2);
        
        final passwordField = textFields.last;
        expect(passwordField.obscureText, true);
      });
    });
    
    group('Style Application', () {
      testWidgets('should apply complex styles correctly', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'box',
            'width': 200,
            'height': 100,
            'padding': {
              'left': 10,
              'top': 20,
              'right': 30,
              'bottom': 40,
            },
            'margin': {'all': 15},
            'backgroundColor': '#FF5722',
            'border': {
              'color': '#000000',
              'width': 2,
              'style': 'solid',
            },
            'borderRadius': {
              'topLeft': 10,
              'topRight': 20,
              'bottomLeft': 30,
              'bottomRight': 40,
            },
            'shadow': {
              'color': '#000000',
              'blurRadius': 10,
              'spreadRadius': 2,
              'offset': {'x': 4, 'y': 4},
            },
            'child': {
              'type': 'text',
              'content': 'Styled Box',
            },
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Styled Box'), findsOneWidget);
        
        // Find the container with decoration
        final container = tester.widget<Container>(
          find.ancestor(
            of: find.text('Styled Box'),
            matching: find.byType(Container),
          ).first,
        );
        
        expect(container.constraints?.maxWidth, 200);
        expect(container.constraints?.maxHeight, 100);
        
        final decoration = container.decoration as BoxDecoration?;
        expect(decoration?.color, const Color(0xFFFF5722));
        expect(decoration?.border?.top.color, const Color(0xFF000000));
        expect(decoration?.border?.top.width, 2);
        expect(decoration?.borderRadius, const BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(40),
        ));
        expect(decoration?.boxShadow?.length, 1);
        expect(decoration?.boxShadow?.first.color, const Color(0xFF000000));
        expect(decoration?.boxShadow?.first.blurRadius, 10);
        expect(decoration?.boxShadow?.first.spreadRadius, 2);
      });
    });
  });
}