import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  group('MCP UI DSL v1.0 Flat Structure Tests', () {
    testWidgets('Text widget with flat structure properties', (WidgetTester tester) async {
      // Test that flat structure is properly supported
      final definition = {
        'type': 'page',
        'metadata': {
          'title': 'Flat Test',
        },
        'content': {
          'type': 'text',
          'content': 'Hello Flat World',
          'style': {
            'fontSize': 20,
            'color': '#FF5722',
          },
        },
      };

      await tester.pumpWidget(
        MaterialApp(
          home: MCPUIRuntimeHelper.render(definition),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that the runtime initializes successfully with flat structure
      expect(find.text('Hello Flat World'), findsOneWidget);
    });

    testWidgets('Container with nested widgets using flat structure', (WidgetTester tester) async {
      // Test nested widgets with flat structure
      final definition = {
        'type': 'page',
        'metadata': {
          'title': 'Container Test',
        },
        'content': {
          'type': 'box',
          'padding': {'all': 20},
          'child': {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'text',
                'content': 'Title Text',
                'style': {'fontSize': 18, 'fontWeight': 'bold'},
              },
              {
                'type': 'text',
                'content': 'Subtitle Text',
              },
            ],
          },
        },
      };

      await tester.pumpWidget(
        MaterialApp(
          home: MCPUIRuntimeHelper.render(definition),
        ),
      );

      await tester.pumpAndSettle();

      // Verify basic structure is rendered
      expect(find.text('Title Text'), findsOneWidget);
      expect(find.text('Subtitle Text'), findsOneWidget);
    });

    testWidgets('Button widget with flat structure and actions', (WidgetTester tester) async {
      // Test button with flat structure
      final definition = {
        'type': 'page',
        'metadata': {
          'title': 'Button Test',
        },
        'content': {
          'type': 'button',
          'label': 'Click Me',
          'style': 'elevated',
          'click': {
            'type': 'tool',
            'tool': 'test_action',
            'params': {'test': 'value'},
          },
        },
      };

      await tester.pumpWidget(
        MaterialApp(
          home: MCPUIRuntimeHelper.render(definition),
        ),
      );

      await tester.pumpAndSettle();

      // Verify basic structure is rendered
      expect(find.text('Click Me'), findsOneWidget);
    });
  });
}