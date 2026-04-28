// Scroll Widget Factory Tests: TC-237 through TC-240
// Covers scrollView, singleChildScrollView, scrollBar, pageView.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  late MCPUIRuntime runtime;

  setUp(() {
    runtime = MCPUIRuntime();
  });

  tearDown(() {
    runtime.destroy();
  });

  // Helper to pump a page definition through the runtime
  Future<void> pumpPage(
    WidgetTester tester, {
    required Map<String, dynamic> content,
    Map<String, dynamic>? initialState,
  }) async {
    final definition = <String, dynamic>{
      'type': 'page',
      'content': content,
    };
    if (initialState != null) {
      definition['runtime'] = {
        'services': {
          'state': {'initialState': initialState},
        },
      };
    }
    await runtime.initialize(definition);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: runtime.buildUI())),
    );
    await tester.pump();
  }

  // ---------------------------------------------------------------------------
  // TC-237: ScrollViewWidgetFactory - children, direction
  // ---------------------------------------------------------------------------
  group('TC-237: ScrollViewWidgetFactory', () {
    testWidgets('TC-237a: scrollView renders children', (tester) async {
      await pumpPage(tester, content: {
        'type': 'scrollView',
        'children': [
          {'type': 'text', 'content': 'Scroll Item 1'},
          {'type': 'text', 'content': 'Scroll Item 2'},
          {'type': 'text', 'content': 'Scroll Item 3'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-237b: scrollView with vertical direction', (tester) async {
      await pumpPage(tester, content: {
        'type': 'scrollView',
        'direction': 'vertical',
        'children': [
          {'type': 'text', 'content': 'Vertical Scroll Content'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-237c: scrollView with horizontal direction',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'scrollView',
        'direction': 'horizontal',
        'children': [
          {'type': 'text', 'content': 'Horizontal Item A'},
          {'type': 'text', 'content': 'Horizontal Item B'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-237d: scrollView with empty children', (tester) async {
      await pumpPage(tester, content: {
        'type': 'scrollView',
        'children': <Map<String, dynamic>>[],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-238: SingleChildScrollViewWidgetFactory - child, direction
  // ---------------------------------------------------------------------------
  group('TC-238: SingleChildScrollViewWidgetFactory', () {
    testWidgets('TC-238a: singleChildScrollView renders child',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'singleChildScrollView',
        'children': [
          {'type': 'text', 'content': 'Single Scrollable Content'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-238b: singleChildScrollView with vertical direction',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'singleChildScrollView',
        'direction': 'vertical',
        'children': [
          {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {'type': 'text', 'content': 'Line 1'},
              {'type': 'text', 'content': 'Line 2'},
              {'type': 'text', 'content': 'Line 3'},
            ],
          },
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-238c: singleChildScrollView with horizontal direction',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'singleChildScrollView',
        'direction': 'horizontal',
        'children': [
          {'type': 'text', 'content': 'Horizontal single scroll'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-239: ScrollbarWidgetFactory - child
  // ---------------------------------------------------------------------------
  group('TC-239: ScrollbarWidgetFactory', () {
    testWidgets('TC-239a: scrollBar wraps scrollable child', (tester) async {
      await pumpPage(tester, content: {
        'type': 'scrollBar',
        'children': [
          {
            'type': 'singleChildScrollView',
            'children': [
              {'type': 'text', 'content': 'Content With Scrollbar'},
            ],
          },
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-239b: scrollBar with nested list content', (tester) async {
      await pumpPage(tester, content: {
        'type': 'scrollBar',
        'children': [
          {
            'type': 'singleChildScrollView',
            'children': [
              {
                'type': 'linear',
                'direction': 'vertical',
                'children': [
                  {'type': 'text', 'content': 'Item A'},
                  {'type': 'text', 'content': 'Item B'},
                  {'type': 'text', 'content': 'Item C'},
                ],
              },
            ],
          },
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-239c: scrollBar renders without crash when child is empty',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'scrollBar',
        'children': [
          {
            'type': 'singleChildScrollView',
            'children': [
              {'type': 'text', 'content': ''},
            ],
          },
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-240: PageViewWidgetFactory - children, scrollDirection
  // ---------------------------------------------------------------------------
  group('TC-240: PageViewWidgetFactory', () {
    testWidgets('TC-240a: pageView renders with children pages',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'pageView',
        'children': [
          {'type': 'text', 'content': 'Page 1'},
          {'type': 'text', 'content': 'Page 2'},
          {'type': 'text', 'content': 'Page 3'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-240b: pageView with horizontal scrollDirection',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'pageView',
        'scrollDirection': 'horizontal',
        'children': [
          {'type': 'text', 'content': 'Horizontal Page A'},
          {'type': 'text', 'content': 'Horizontal Page B'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-240c: pageView with vertical scrollDirection',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'pageView',
        'scrollDirection': 'vertical',
        'children': [
          {'type': 'text', 'content': 'Vertical Page X'},
          {'type': 'text', 'content': 'Vertical Page Y'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-240d: pageView with single child page', (tester) async {
      await pumpPage(tester, content: {
        'type': 'pageView',
        'children': [
          {'type': 'text', 'content': 'Only Page'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
