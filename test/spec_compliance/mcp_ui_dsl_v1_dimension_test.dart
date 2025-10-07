import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';

/// MCP UI DSL v1.0 Dimension Format Compliance Test
/// 
/// This test verifies that dimensions in MCP UI DSL v1.0 format
/// {"value": 100, "unit": "px"} are properly handled by all widgets
void main() {
  group('MCP UI DSL v1.0 Dimension Format Compliance', () {
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
    
    group('Box Widget Dimensions', () {
      testWidgets('should handle MCP UI DSL v1.0 dimension format', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'box',
            'width': {'value': 200, 'unit': 'px'},
            'height': {'value': 100, 'unit': 'px'},
            'child': {
              'type': 'text',
              'content': 'Sized Box',
            },
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Sized Box'), findsOneWidget);
        
        // Find the Container widget
        final containerFinder = find.byType(Container);
        expect(containerFinder, findsWidgets);
        
        // Verify the Container has constraints
        final container = tester.widget<Container>(containerFinder.first);
        expect(container.constraints, isNotNull);
        expect(container.constraints!.maxWidth, 200.0);
        expect(container.constraints!.maxHeight, 100.0);
      });
      
      testWidgets('should handle backward-compatible direct numbers', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'box',
            'width': 200.0,
            'height': 100.0,
            'child': {
              'type': 'text',
              'content': 'Direct Number Box',
            },
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Direct Number Box'), findsOneWidget);
        
        final container = tester.widget<Container>(find.byType(Container).first);
        expect(container.constraints, isNotNull);
        expect(container.constraints!.maxWidth, 200.0);
        expect(container.constraints!.maxHeight, 100.0);
      });
    });
    
    group('Icon Widget Dimensions', () {
      testWidgets('should handle MCP UI DSL v1.0 size format', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'icon',
            'icon': 'home',
            'size': {'value': 48, 'unit': 'px'},
            'color': '#FF2196F3',
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        final iconFinder = find.byType(Icon);
        expect(iconFinder, findsOneWidget);
        
        final icon = tester.widget<Icon>(iconFinder);
        expect(icon.size, 48.0);
      });
      
      testWidgets('should handle direct number size', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'icon',
            'icon': 'home',
            'size': 48.0,
            'color': '#FF2196F3',
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.size, 48.0);
      });
    });
    
    group('Text Style Dimensions', () {
      testWidgets('should handle MCP UI DSL v1.0 fontSize format', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'text',
            'content': 'Styled Text',
            'style': {
              'fontSize': {'value': 24, 'unit': 'px'},
              'color': '#FF000000',
            },
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        final textFinder = find.text('Styled Text');
        expect(textFinder, findsOneWidget);
        
        final text = tester.widget<Text>(textFinder);
        expect(text.style, isNotNull);
        expect(text.style!.fontSize, 24.0);
      });
      
      testWidgets('should handle direct number fontSize', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'text',
            'content': 'Direct Font Size',
            'style': {
              'fontSize': 24.0,
              'color': '#FF000000',
            },
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        final text = tester.widget<Text>(find.text('Direct Font Size'));
        expect(text.style, isNotNull);
        expect(text.style!.fontSize, 24.0);
      });
    });
    
    group('Padding and Margin Dimensions', () {
      testWidgets('should handle MCP UI DSL v1.0 padding format', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'box',
            'padding': {
              'all': {'value': 16, 'unit': 'px'}
            },
            'child': {
              'type': 'text',
              'content': 'Padded Text',
            },
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Padded Text'), findsOneWidget);
        
        // Find Padding widget
        final paddingFinder = find.byType(Padding);
        expect(paddingFinder, findsWidgets);
      });
      
      testWidgets('should handle mixed dimension formats', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'box',
            'width': {'value': 300, 'unit': 'px'},  // MCP format
            'height': 150.0,  // Direct number
            'padding': {
              'left': {'value': 20, 'unit': 'px'},  // MCP format
              'right': 20.0,  // Direct number
              'top': {'value': 10, 'unit': 'px'},  // MCP format
              'bottom': 10.0,  // Direct number
            },
            'child': {
              'type': 'text',
              'content': 'Mixed Format',
              'style': {
                'fontSize': {'value': 18, 'unit': 'px'},  // MCP format
              }
            },
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.text('Mixed Format'), findsOneWidget);
        
        final container = tester.widget<Container>(find.byType(Container).first);
        expect(container.constraints!.maxWidth, 300.0);
        expect(container.constraints!.maxHeight, 150.0);
      });
    });
    
    group('Divider Dimensions', () {
      testWidgets('should handle MCP UI DSL v1.0 thickness format', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {'type': 'text', 'content': 'Above'},
              {
                'type': 'divider',
                'thickness': {'value': 2, 'unit': 'px'},
                'indent': {'value': 16, 'unit': 'px'},
                'endIndent': {'value': 16, 'unit': 'px'},
              },
              {'type': 'text', 'content': 'Below'},
            ],
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        expect(find.byType(Divider), findsOneWidget);
        
        final divider = tester.widget<Divider>(find.byType(Divider));
        expect(divider.thickness, 2.0);
        expect(divider.indent, 16.0);
        expect(divider.endIndent, 16.0);
      });
    });
    
    group('Progress Indicator Dimensions', () {
      testWidgets('should handle MCP UI DSL v1.0 strokeWidth format', (WidgetTester tester) async {
        await runtime.initialize({
          'type': 'page',
          'content': {
            'type': 'loadingIndicator',
            'indicatorType': 'circular',
            'value': 0.5,
            'size': {'value': 48, 'unit': 'px'},
            'strokeWidth': {'value': 4, 'unit': 'px'},
          },
        });
        
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        
        final progressFinder = find.byType(CircularProgressIndicator);
        expect(progressFinder, findsOneWidget);
        
        final progress = tester.widget<CircularProgressIndicator>(progressFinder);
        expect(progress.strokeWidth, 4.0);
        expect(progress.value, 0.5);
      });
    });
  });
}