import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

/// MCP UI DSL v1.0 Linear Widget Tests
/// 
/// Tests the linear layout widget according to MCP UI DSL v1.0 specification.
/// Reference: Spec Section 4.2.1 - Layout Widgets
void main() {
  group('MCP UI DSL v1.0 - Linear Widget', () {
    late MCPUIRuntime runtime;
    
    setUp(() {
      runtime = MCPUIRuntime();
    });
    
    tearDown(() {
      runtime.destroy();
    });
    
    group('Direction Property (Spec 4.2.1.1)', () {
      testWidgets('should support vertical direction', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {'type': 'text', 'content': 'First'},
              {'type': 'text', 'content': 'Second'},
              {'type': 'text', 'content': 'Third'},
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        // Verify vertical layout
        final first = tester.getCenter(find.text('First'));
        final second = tester.getCenter(find.text('Second'));
        final third = tester.getCenter(find.text('Third'));
        
        expect(second.dy, greaterThan(first.dy));
        expect(third.dy, greaterThan(second.dy));
        expect(first.dx, equals(second.dx));
        expect(second.dx, equals(third.dx));
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
              {'type': 'text', 'content': 'C'},
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        // Verify horizontal layout
        final a = tester.getCenter(find.text('A'));
        final b = tester.getCenter(find.text('B'));
        final c = tester.getCenter(find.text('C'));
        
        expect(b.dx, greaterThan(a.dx));
        expect(c.dx, greaterThan(b.dx));
        expect(a.dy, equals(b.dy));
        expect(b.dy, equals(c.dy));
      });
      
      testWidgets('should default to vertical when direction not specified', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'linear',
            // No direction specified
            'children': [
              {'type': 'text', 'content': 'Item 1'},
              {'type': 'text', 'content': 'Item 2'},
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        final item1 = tester.getCenter(find.text('Item 1'));
        final item2 = tester.getCenter(find.text('Item 2'));
        
        // Should be vertical by default
        expect(item2.dy, greaterThan(item1.dy));
        expect(item1.dx, equals(item2.dx));
      });
    });
    
    group('Distribution Property (Spec 4.2.1.2)', () {
      testWidgets('should support start distribution', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'linear',
            'direction': 'horizontal',
            'distribution': 'start',
            'children': [
              {'type': 'text', 'content': 'Start 1'},
              {'type': 'text', 'content': 'Start 2'},
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        // Items should be at the start (left for horizontal)
        final containerWidth = tester.getSize(find.byType(Row)).width;
        final item1 = tester.getTopLeft(find.text('Start 1'));
        
        expect(item1.dx, lessThan(containerWidth / 4));
      });
      
      testWidgets('should support center distribution', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'linear',
            'direction': 'horizontal',
            'distribution': 'center',
            'children': [
              {'type': 'text', 'content': 'Center'},
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        final containerSize = tester.getSize(find.byType(Row));
        final itemCenter = tester.getCenter(find.text('Center'));
        
        // Item should be centered
        expect(
          itemCenter.dx,
          closeTo(containerSize.width / 2, 50),
        );
      });
      
      testWidgets('should support space-between distribution', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'box',
            'width': 300,
            'child': {
              'type': 'linear',
              'direction': 'horizontal',
              'distribution': 'space-between',
              'children': [
                {'type': 'text', 'content': 'Left'},
                {'type': 'text', 'content': 'Right'},
              ],
            },
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        final left = tester.getTopLeft(find.text('Left'));
        final right = tester.getTopRight(find.text('Right'));
        
        // Items should be at opposite ends
        expect(left.dx, lessThan(50));
        expect(right.dx, greaterThan(250));
      });
      
      testWidgets('should support space-around distribution', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'linear',
            'direction': 'horizontal',
            'distribution': 'space-around',
            'children': [
              {'type': 'text', 'content': 'A'},
              {'type': 'text', 'content': 'B'},
              {'type': 'text', 'content': 'C'},
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('A'), findsOneWidget);
        expect(find.text('B'), findsOneWidget);
        expect(find.text('C'), findsOneWidget);
      });
      
      testWidgets('should support space-evenly distribution', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'linear',
            'direction': 'horizontal',
            'distribution': 'space-evenly',
            'children': [
              {'type': 'text', 'content': 'X'},
              {'type': 'text', 'content': 'Y'},
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('X'), findsOneWidget);
        expect(find.text('Y'), findsOneWidget);
      });
    });
    
    group('Alignment Property (Spec 4.2.1.3)', () {
      testWidgets('should support start alignment', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'box',
            'height': 200,
            'child': {
              'type': 'linear',
              'direction': 'horizontal',
              'alignment': 'start',
              'children': [
                {'type': 'text', 'content': 'Top aligned'},
              ],
            },
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        final text = tester.getTopLeft(find.text('Top aligned'));
        expect(text.dy, lessThan(100));
      });
      
      testWidgets('should support center alignment', (WidgetTester tester) async {
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
                {'type': 'text', 'content': 'Center aligned'},
              ],
            },
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        const containerHeight = 200.0;
        final textCenter = tester.getCenter(find.text('Center aligned'));
        
        // Should be vertically centered
        expect(
          textCenter.dy,
          closeTo(containerHeight / 2, 50),
        );
      });
      
      testWidgets('should support stretch alignment', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'linear',
            'direction': 'vertical',
            'alignment': 'stretch',
            'children': [
              {
                'type': 'box',
                'backgroundColor': '#FF0000',
                'height': 50,
                'child': {
                  'type': 'text',
                  'content': 'Stretched',
                },
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        // Box should stretch to full width
        // Find the container that is the parent of the text widget
        final textWidget = find.text('Stretched');
        expect(textWidget, findsOneWidget);
        
        // Find the red container that is the ancestor of the text
        final containerFinder = find.ancestor(
          of: textWidget,
          matching: find.byWidgetPredicate((widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == const Color(0xFFFF0000)
          ),
        );
        
        expect(containerFinder, findsOneWidget);
        final box = tester.getSize(containerFinder);
        
        // Get the width of the top-level widget
        final topLevelSize = tester.getSize(find.byType(MaterialApp));
        final screenWidth = topLevelSize.width;
        
        expect(box.width, equals(screenWidth));
      });
    });
    
    group('Gap Property (Spec 4.2.1.4)', () {
      testWidgets('should apply gap between children', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'linear',
            'direction': 'horizontal',
            'gap': 20,
            'children': [
              {'type': 'text', 'content': 'Gap1'},
              {'type': 'text', 'content': 'Gap2'},
              {'type': 'text', 'content': 'Gap3'},
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        final gap1Right = tester.getTopRight(find.text('Gap1')).dx;
        final gap2Left = tester.getTopLeft(find.text('Gap2')).dx;
        final gap2Right = tester.getTopRight(find.text('Gap2')).dx;
        final gap3Left = tester.getTopLeft(find.text('Gap3')).dx;
        
        // Verify 20px gap
        expect(gap2Left - gap1Right, closeTo(20, 2));
        expect(gap3Left - gap2Right, closeTo(20, 2));
      });
      
      testWidgets('should handle zero gap', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'linear',
            'direction': 'horizontal',
            'gap': 0,
            'children': [
              {'type': 'text', 'content': 'No'},
              {'type': 'text', 'content': 'Gap'},
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        final noRight = tester.getTopRight(find.text('No')).dx;
        final gapLeft = tester.getTopLeft(find.text('Gap')).dx;
        
        // Should have minimal or no gap
        expect(gapLeft - noRight, lessThan(5));
      });
    });
    
    group('Wrap Property (Spec 4.2.1.5)', () {
      testWidgets('should support wrap for overflow content', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'box',
            'width': 200,
            'child': {
              'type': 'linear',
              'direction': 'horizontal',
              'wrap': true,
              'gap': 10,
              'children': [
                {'type': 'box', 'width': 80, 'height': 40, 'backgroundColor': '#FF0000'},
                {'type': 'box', 'width': 80, 'height': 40, 'backgroundColor': '#00FF00'},
                {'type': 'box', 'width': 80, 'height': 40, 'backgroundColor': '#0000FF'},
              ],
            },
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        // Third box should wrap to next line
        final containers = tester.widgetList<Container>(find.byType(Container));
        expect(containers.length, greaterThan(3));
      });
      
      testWidgets('should not wrap when wrap is false', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'linear',
            'direction': 'horizontal',
            'wrap': false,
            'children': [
              {'type': 'text', 'content': 'NoWrap1'},
              {'type': 'text', 'content': 'NoWrap2'},
              {'type': 'text', 'content': 'NoWrap3'},
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        // All items should be on same line
        final y1 = tester.getCenter(find.text('NoWrap1')).dy;
        final y2 = tester.getCenter(find.text('NoWrap2')).dy;
        final y3 = tester.getCenter(find.text('NoWrap3')).dy;
        
        expect(y1, equals(y2));
        expect(y2, equals(y3));
      });
    });
    
    group('Flexible Children (Spec 4.2.1.6)', () {
      testWidgets('should support flex property on children', (WidgetTester tester) async {
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
        
        // Verify flex widgets exist
        expect(find.byType(Flexible), findsNWidgets(2));
        
        // Third box should have fixed width
        final containers = tester.widgetList<Container>(
          find.byType(Container)
        ).where((container) {
          return container.constraints?.maxWidth == 100;
        }).toList();
        expect(containers.length, greaterThan(0));
      });
    });
    
    group('Nested Linear Layouts (Spec 4.2.1.7)', () {
      testWidgets('should support nested linear layouts', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'linear',
            'direction': 'vertical',
            'gap': 16,
            'children': [
              {
                'type': 'text',
                'content': 'Header',
                'style': {'fontSize': 20, 'fontWeight': 'bold'},
              },
              {
                'type': 'linear',
                'direction': 'horizontal',
                'distribution': 'space-between',
                'children': [
                  {'type': 'button', 'label': 'Left'},
                  {'type': 'button', 'label': 'Center'},
                  {'type': 'button', 'label': 'Right'},
                ],
              },
              {
                'type': 'text',
                'content': 'Footer',
              },
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Header'), findsOneWidget);
        expect(find.text('Left'), findsOneWidget);
        expect(find.text('Center'), findsOneWidget);
        expect(find.text('Right'), findsOneWidget);
        expect(find.text('Footer'), findsOneWidget);
        
        // Verify vertical then horizontal layout
        final header = tester.getCenter(find.text('Header'));
        final buttons = tester.getCenter(find.text('Center'));
        final footer = tester.getCenter(find.text('Footer'));
        
        expect(buttons.dy, greaterThan(header.dy));
        expect(footer.dy, greaterThan(buttons.dy));
      });
    });
  });
}