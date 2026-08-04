// Every chart type actually paints.
//
// `chart_factory.dart` sat at 53.9%, and what was uncovered was the painter
// itself — area, radar, polar, bubble, scatter, donut. A painter that throws
// takes the page with it, and one that quietly draws nothing looks like an
// empty dataset; both are invisible to a test that only builds the widget.
// These render each type through the runtime and read the canvas.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  const types = <String>[
    'line',
    'bar',
    'pie',
    'donut',
    'polar',
    'scatter',
    'bubble',
    'area',
    'radar',
  ];

  Future<void> render(
    WidgetTester tester,
    Map<String, dynamic> chart,
  ) async {
    final runtime = MCPUIRuntime();
    await runtime.initialize(<String, dynamic>{
      'type': 'page',
      'content': <String, dynamic>{
        'type': 'box',
        'height': 400,
        'child': chart,
      },
    });
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: runtime.buildUI())),
    );
    await tester.pump(const Duration(milliseconds: 50));
    addTearDown(runtime.dispose);
  }

  Map<String, dynamic> chartOf(String type) => <String, dynamic>{
        'type': 'chart',
        'chartType': type,
        'height': 300,
        'title': '$type chart',
        'data': <dynamic>[
          <String, dynamic>{'label': 'Mon', 'value': 3},
          <String, dynamic>{'label': 'Tue', 'value': 7},
          <String, dynamic>{'label': 'Wed', 'value': 5},
        ],
      };

  for (final type in types) {
    testWidgets('$type renders without taking the page down', (tester) async {
      await render(tester, chartOf(type));

      expect(tester.takeException(), isNull,
          reason: 'a painter that throws replaces the whole page with an '
              'error box');
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.text('$type chart'), findsOneWidget,
          reason: 'the title is part of the chart surface, so its absence '
              'means the widget never built');
    });
  }

  testWidgets('an empty dataset draws an empty chart, not an exception',
      (tester) async {
    await render(tester, <String, dynamic>{
      'type': 'chart',
      'chartType': 'bar',
      'height': 200,
      'data': <dynamic>[],
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('a single point is enough for the line painters',
      (tester) async {
    for (final type in <String>['line', 'area', 'scatter']) {
      await render(tester, <String, dynamic>{
        'type': 'chart',
        'chartType': type,
        'height': 200,
        'data': <dynamic>[
          <String, dynamic>{'label': 'only', 'value': 1},
        ],
      });
      expect(tester.takeException(), isNull, reason: type);
    }
  });

  testWidgets('identical values do not divide by a zero range',
      (tester) async {
    for (final type in <String>['line', 'bar', 'area', 'radar']) {
      await render(tester, <String, dynamic>{
        'type': 'chart',
        'chartType': type,
        'height': 200,
        'data': <dynamic>[
          <String, dynamic>{'label': 'a', 'value': 5},
          <String, dynamic>{'label': 'b', 'value': 5},
        ],
      });
      expect(tester.takeException(), isNull,
          reason: '$type: a flat series has max == min, and scaling by '
              '(max - min) is where that becomes a NaN');
    }
  });

  testWidgets('negative values are drawn, not dropped', (tester) async {
    await render(tester, <String, dynamic>{
      'type': 'chart',
      'chartType': 'bar',
      'height': 200,
      'data': <dynamic>[
        <String, dynamic>{'label': 'loss', 'value': -4},
        <String, dynamic>{'label': 'gain', 'value': 6},
      ],
    });
    expect(tester.takeException(), isNull);
  });

  group('the legend follows §10 options.legend.position', () {
    testWidgets('a declared position is honoured over the legacy flag',
        (tester) async {
      await render(tester, <String, dynamic>{
        'type': 'chart',
        'chartType': 'bar',
        'height': 300,
        'showLegend': true, // legacy key says show
        'options': <String, dynamic>{
          'legend': <String, dynamic>{'position': 'none'}, // spec key says no
        },
        // §10.x: labels and datasets live inside `data`.
        'data': <String, dynamic>{
          'labels': <dynamic>['a', 'b', 'c'],
          'datasets': <dynamic>[
            <String, dynamic>{
              'label': 'Series A',
              'data': <dynamic>[1, 2, 3],
            },
          ],
        },
      });

      expect(find.text('Series A'), findsNothing,
          reason: 'reading the legacy flag last would let a stale key '
              'override the documented one');
    });

    testWidgets('the default shows a legend for named datasets',
        (tester) async {
      await render(tester, <String, dynamic>{
        'type': 'chart',
        'chartType': 'bar',
        'height': 300,
        // §10.x: labels and datasets live inside `data`.
        'data': <String, dynamic>{
          'labels': <dynamic>['a', 'b', 'c'],
          'datasets': <dynamic>[
            <String, dynamic>{
              'label': 'Series A',
              'data': <dynamic>[1, 2, 3],
            },
          ],
        },
      });

      expect(find.text('Series A'), findsOneWidget);
    });
  });
}
