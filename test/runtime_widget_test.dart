import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  group('Runtime Widget Tests', () {
    testWidgets('renders simple text', (WidgetTester tester) async {
      final definition = {
        'type': 'page',
        'metadata': {
          'title': 'Test Page',
        },
        'content': {
          'type': 'text',
          'content': 'Hello Runtime',
        },
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MCPUIRuntimeHelper.render(definition),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Hello Runtime'), findsOneWidget);
    });

    testWidgets('renders scaffold with appbar', (WidgetTester tester) async {
      final definition = {
        'type': 'page',
        'metadata': {
          'title': 'Test Page',
        },
        'content': {
          'type': 'linear',
          'direction': 'vertical',
          'children': [
            {
              'type': 'text',
              'content': 'Test App',
              'style': {'fontSize': 20, 'fontWeight': 'bold'},
            },
            {
              'type': 'center',
              'child': {
                'type': 'text',
                'content': 'Body Content',
              },
            },
          ],
        },
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MCPUIRuntimeHelper.render(definition),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Test App'), findsOneWidget);
      expect(find.text('Body Content'), findsOneWidget);
    });

    testWidgets('handles button clicks', (WidgetTester tester) async {
      var clicked = false;
      
      final definition = {
        'type': 'page',
        'metadata': {
          'title': 'Test Page',
        },
        'content': {
          'type': 'center',
          'child': {
            'type': 'button',
            'label': 'Click Me',
            'click': {
              'type': 'tool',
              'tool': 'testClick',
              'params': {},
            },
          },
        },
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MCPUIRuntimeHelper.render(
              definition,
              onToolCall: (tool, args) {
                if (tool == 'testClick') {
                  clicked = true;
                }
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      
      await tester.tap(find.text('Click Me'));
      await tester.pump();
      
      expect(clicked, isTrue);
    });

    testWidgets('renders with state bindings', (WidgetTester tester) async {
      final definition = {
        'type': 'page',
        'metadata': {
          'title': 'Test Page',
        },
        'runtime': {
          'services': {
            'state': {
              'initialState': {
                'message': 'Hello from State',
                'count': 42,
              },
            },
          },
        },
        'content': {
          'type': 'center',
          'child': {
            'type': 'linear',
          'direction': 'vertical',
            'mainAxisAlignment': 'center',
            'children': [
              {
                'type': 'text',
                'content': '{{message}}',
              },
              {
                'type': 'text',
                'content': 'Count: {{count}}',
              },
            ],
          },
        },
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MCPUIRuntimeHelper.render(definition),
          ),
        ),
      );

      await tester.pumpAndSettle();
      
      expect(find.text('Hello from State'), findsOneWidget);
      expect(find.text('Count: 42'), findsOneWidget);
    });

    testWidgets('renders list with itemBuilder', (WidgetTester tester) async {
      final definition = {
        'type': 'page',
        'metadata': {
          'title': 'Test Page',
        },
        'runtime': {
          'services': {
            'state': {
              'initialState': {
                'items': [
                  {'name': 'Item 1'},
                  {'name': 'Item 2'},
                  {'name': 'Item 3'},
                ],
              },
            },
          },
        },
        'content': {
          'type': 'list',
          'shrinkWrap': true,
          'itemCount': '{{items.length}}',
          'itemBuilder': {
            'type': 'listTile',
            'title': {
              'type': 'text',
              'content': '{{items[index].name}}',
            },
          },
        },
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MCPUIRuntimeHelper.render(definition),
          ),
        ),
      );

      await tester.pumpAndSettle();
      
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Item 3'), findsOneWidget);
    });
  });
}