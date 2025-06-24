import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

/// MCP UI DSL v1.0 Text Widget Tests
/// 
/// Tests the text widget according to MCP UI DSL v1.0 specification.
/// Reference: Spec Section 4.2.2 - Display Widgets
void main() {
  group('MCP UI DSL v1.0 - Text Widget', () {
    late MCPUIRuntime runtime;
    
    setUp(() {
      runtime = MCPUIRuntime();
    });
    
    tearDown(() {
      runtime.destroy();
    });
    
    group('Content Property (Spec 4.2.2.1)', () {
      testWidgets('should display static text content', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'text',
            'content': 'Hello MCP UI DSL v1.0',
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Hello MCP UI DSL v1.0'), findsOneWidget);
      });
      
      testWidgets('should support data binding in content', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'message': 'Dynamic Text',
                  'count': 42,
                },
              },
            },
          },
          'content': {
            'type': 'text',
            'content': '{{message}} - Count: {{count}}',
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Dynamic Text - Count: 42'), findsOneWidget);
      });
      
      testWidgets('should support nested property binding', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'user': {
                    'name': 'John Doe',
                    'profile': {
                      'title': 'Developer',
                    },
                  },
                },
              },
            },
          },
          'content': {
            'type': 'text',
            'content': '{{user.name}} - {{user.profile.title}}',
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('John Doe - Developer'), findsOneWidget);
      });
      
      testWidgets('should handle empty content', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'text',
            'content': '',
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        // Empty text widget should still exist
        expect(find.byType(Text), findsOneWidget);
      });
    });
    
    group('Style Properties (Spec 4.2.2.2)', () {
      testWidgets('should apply fontSize style', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'text',
            'content': 'Sized Text',
            'style': {
              'fontSize': 24,
            },
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        final text = tester.widget<Text>(find.text('Sized Text'));
        expect(text.style?.fontSize, 24);
      });
      
      testWidgets('should apply fontWeight style', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'text',
            'content': 'Bold Text',
            'style': {
              'fontWeight': 'bold',
            },
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        final text = tester.widget<Text>(find.text('Bold Text'));
        expect(text.style?.fontWeight, FontWeight.bold);
      });
      
      testWidgets('should apply color style', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'text',
            'content': 'Colored Text',
            'style': {
              'color': '#FF0000',
            },
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        final text = tester.widget<Text>(find.text('Colored Text'));
        expect(text.style?.color, const Color(0xFFFF0000));
      });
      
      testWidgets('should apply multiple style properties', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'text',
            'content': 'Styled Text',
            'style': {
              'fontSize': 18,
              'fontWeight': 'w600',
              'fontFamily': 'Roboto',
              'color': '#2196F3',
              'letterSpacing': 1.5,
              'wordSpacing': 2.0,
              'decoration': 'underline',
              'decorationColor': '#FF5722',
              'decorationThickness': 2,
            },
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        final text = tester.widget<Text>(find.text('Styled Text'));
        expect(text.style?.fontSize, 18);
        expect(text.style?.fontWeight, FontWeight.w600);
        expect(text.style?.fontFamily, 'Roboto');
        expect(text.style?.color, const Color(0xFF2196F3));
        expect(text.style?.letterSpacing, 1.5);
        expect(text.style?.wordSpacing, 2.0);
        expect(text.style?.decoration, TextDecoration.underline);
        expect(text.style?.decorationColor, const Color(0xFFFF5722));
        expect(text.style?.decorationThickness, 2);
      });
      
      testWidgets('should support text shadows', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'text',
            'content': 'Shadow Text',
            'style': {
              'shadows': [
                {
                  'color': '#000000',
                  'offset': {'x': 2, 'y': 2},
                  'blurRadius': 4,
                },
              ],
            },
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        final text = tester.widget<Text>(find.text('Shadow Text'));
        expect(text.style?.shadows?.length, 1);
        expect(text.style?.shadows?.first.color, const Color(0xFF000000));
        expect(text.style?.shadows?.first.offset, const Offset(2, 2));
        expect(text.style?.shadows?.first.blurRadius, 4);
      });
    });
    
    group('Text Alignment (Spec 4.2.2.3)', () {
      testWidgets('should support left alignment', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'text',
            'content': 'Left Aligned',
            'textAlign': 'left',
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        final text = tester.widget<Text>(find.text('Left Aligned'));
        expect(text.textAlign, TextAlign.left);
      });
      
      testWidgets('should support center alignment', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'text',
            'content': 'Center Aligned',
            'textAlign': 'center',
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        final text = tester.widget<Text>(find.text('Center Aligned'));
        expect(text.textAlign, TextAlign.center);
      });
      
      testWidgets('should support right alignment', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'text',
            'content': 'Right Aligned',
            'textAlign': 'right',
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        final text = tester.widget<Text>(find.text('Right Aligned'));
        expect(text.textAlign, TextAlign.right);
      });
      
      testWidgets('should support justify alignment', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'text',
            'content': 'Justified text that should spread across the entire width',
            'textAlign': 'justify',
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        final text = tester.widget<Text>(find.textContaining('Justified'));
        expect(text.textAlign, TextAlign.justify);
      });
    });
    
    group('Text Overflow (Spec 4.2.2.4)', () {
      testWidgets('should support ellipsis overflow', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'box',
            'width': 100,
            'child': {
              'type': 'text',
              'content': 'This is a very long text that should be truncated',
              'maxLines': 1,
              'overflow': 'ellipsis',
            },
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        final text = tester.widget<Text>(find.byType(Text).last);
        expect(text.overflow, TextOverflow.ellipsis);
        expect(text.maxLines, 1);
      });
      
      testWidgets('should support fade overflow', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'text',
            'content': 'Fading text',
            'overflow': 'fade',
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        final text = tester.widget<Text>(find.text('Fading text'));
        expect(text.overflow, TextOverflow.fade);
      });
      
      testWidgets('should support clip overflow', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'text',
            'content': 'Clipped text',
            'overflow': 'clip',
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        final text = tester.widget<Text>(find.text('Clipped text'));
        expect(text.overflow, TextOverflow.clip);
      });
    });
    
    group('Multiline Text (Spec 4.2.2.5)', () {
      testWidgets('should support maxLines property', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'text',
            'content': 'Line 1\nLine 2\nLine 3\nLine 4',
            'maxLines': 2,
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        final text = tester.widget<Text>(find.textContaining('Line 1'));
        expect(text.maxLines, 2);
      });
      
      testWidgets('should support line height', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'text',
            'content': 'Text with\ncustom line height',
            'style': {
              'height': 1.5,
            },
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        final text = tester.widget<Text>(find.textContaining('Text with'));
        expect(text.style?.height, 1.5);
      });
    });
    
    group('Accessibility (Spec 4.2.2.6)', () {
      testWidgets('should support semantic label', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'text',
            'content': '🏠',
            'semanticsLabel': 'Home icon',
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        final text = tester.widget<Text>(find.text('🏠'));
        expect(text.semanticsLabel, 'Home icon');
      });
      
      testWidgets('should support aria properties', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'text',
            'content': 'Accessible Text',
            'aria-label': 'This is accessible text',
            'aria-hidden': false,
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Accessible Text'), findsOneWidget);
      });
    });
    
    group('Dynamic Updates (Spec 4.2.2.7)', () {
      testWidgets('should update text when state changes', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'runtime': {
            'services': {
              'state': {
                'initialState': {
                  'status': 'Initial',
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
                'content': 'Status: {{status}}',
              },
              {
                'type': 'button',
                'label': 'Update',
                'click': {
                  'type': 'state',
                  'action': 'set',
                  'path': 'status',
                  'value': 'Updated',
                },
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Status: Initial'), findsOneWidget);
        
        await tester.tap(find.text('Update'));
        await tester.pump();
        
        expect(find.text('Status: Updated'), findsOneWidget);
        expect(find.text('Status: Initial'), findsNothing);
      });
    });
  });
}