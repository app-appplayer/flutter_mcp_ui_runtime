// The chart series that the first pixel suite did not reach: area, radar,
// scatter, bubble, polar, donut — and the multi-dataset forms of area and
// line.
//
// Same rule as its sibling: every question about a CustomPainter is a question
// about pixels. `CustomPaint` is in the tree whether the painter drew anything
// or not, which is exactly how a dropped dataset keeps its tests green.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

import 'painted_probe.dart';

void main() {
  final live = <MCPUIRuntime>[];
  tearDown(() {
    for (final r in live) {
      r.destroy();
    }
    live.clear();
  });

  var seq = 0;

  Future<Painted> render(
    WidgetTester tester,
    Map<String, dynamic> chart, {
    Size size = const Size(400, 300),
  }) async {
    final key = ValueKey('series-probe-${seq++}');
    final runtime = MCPUIRuntime();
    live.add(runtime);
    await runtime.initialize(<String, dynamic>{
      'type': 'page',
      'content': chart,
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: isolated(
            SizedBox(
              width: size.width,
              height: size.height,
              child: runtime.buildUI(),
            ),
            key: key,
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    late Painted painted;
    await tester.runAsync(() async {
      painted = await paintedOf(tester, find.byKey(key));
    });
    return painted;
  }

  Map<String, dynamic> chart(String type, Map<String, dynamic> extra) =>
      <String, dynamic>{
        'type': 'chart',
        'chartType': type,
        ...extra,
      };

  /// One dataset of plain points.
  Map<String, dynamic> singleSeries() => {
        'data': [
          {'label': 'Mon', 'value': 3},
          {'label': 'Tue', 'value': 8},
          {'label': 'Wed', 'value': 5},
          {'label': 'Thu', 'value': 11},
        ],
      };

  /// Two datasets in the canonical `{labels, datasets}` shape.
  Map<String, dynamic> twoSeries() => {
        'data': {
          'labels': ['Mon', 'Tue', 'Wed', 'Thu'],
          'datasets': [
            {
              'label': 'Kept',
              'data': [3, 8, 5, 11],
              'color': '#FF0000',
            },
            {
              'label': 'Dropped',
              'data': [9, 2, 10, 4],
              'color': '#0000FF',
            },
          ],
        },
      };

  group('every declared series type draws something', () {
    for (final type in const [
      'area',
      'radar',
      'scatter',
      'bubble',
      'polar',
      'donut',
      'pie',
    ]) {
      testWidgets('$type paints', (tester) async {
        final painted = await render(tester, chart(type, singleSeries()));

        expect(painted.nonBackground(), greaterThan(200),
            reason: '$type must put ink on the canvas — a painter that '
                'returns early leaves a CustomPaint in the tree and an empty '
                'rectangle on screen, and only a pixel count tells them '
                'apart');
      });
    }
  });

  group('the second dataset is not dropped', () {
    testWidgets('a multi-dataset AREA chart draws both series',
        (tester) async {
      final painted = await render(tester, chart('area', twoSeries()));

      expect(painted.count(const Color(0xFFFF0000)), greaterThan(20),
          reason: 'the first dataset declares red');
      expect(painted.count(const Color(0xFF0000FF)), greaterThan(20),
          reason: 'the second declares blue — a chart that paints only the '
              'first series looks complete and is missing half its data');
    });

    testWidgets('a multi-dataset LINE chart draws both series',
        (tester) async {
      final painted = await render(tester, chart('line', twoSeries()));

      expect(painted.count(const Color(0xFFFF0000)), greaterThan(10));
      expect(painted.count(const Color(0xFF0000FF)), greaterThan(10));
    });

    testWidgets('a grouped BAR chart draws both series', (tester) async {
      final painted = await render(tester, chart('bar', twoSeries()));

      expect(painted.count(const Color(0xFFFF0000)), greaterThan(50));
      expect(painted.count(const Color(0xFF0000FF)), greaterThan(50),
          reason: 'the canonical {labels, datasets} shape used to render the '
              'first dataset only, in palette colours');
    });
  });

  group('a single-point series', () {
    for (final type in const ['line', 'area', 'bar']) {
      testWidgets('$type with one point still draws', (tester) async {
        final painted = await render(
          tester,
          chart(type, {
            'data': [
              {'label': 'Only', 'value': 5},
            ],
          }),
        );

        expect(painted.nonBackground(), greaterThan(50),
            reason: 'the spacing divisor is `length - 1`; a single point is '
                'where that becomes a division by zero and the chart '
                'disappears');
      });
    }

    testWidgets('a series whose values are all equal still draws',
        (tester) async {
      // The value range is zero here, which is the other divide-by-zero in
      // every one of these painters.
      final painted = await render(
        tester,
        chart('line', {
          'data': [
            {'label': 'a', 'value': 4},
            {'label': 'b', 'value': 4},
            {'label': 'c', 'value': 4},
          ],
        }),
      );

      expect(painted.nonBackground(), greaterThan(50));
    });
  });

  group('an empty chart', () {
    testWidgets('draws its frame but no series', (tester) async {
      final empty = await render(tester, chart('line', {'data': <dynamic>[]}));
      final populated = await render(tester, chart('line', singleSeries()));

      // The grid and axes still draw — an empty plot area with its frame
      // reads as "no data yet", which is the honest picture. What must not
      // appear is a series.
      expect(empty.nonBackground(), lessThan(populated.nonBackground()),
          reason: 'a chart still loading its data must not paint a shape the '
              'reader could mistake for a measurement');
      expect(tester.takeException(), isNull);
    });
  });

  group('the settings change the picture', () {
    testWidgets('showGrid: false removes ink', (tester) async {
      final withGrid =
          await render(tester, chart('line', {...singleSeries(), 'showGrid': true}));
      final without =
          await render(tester, chart('line', {...singleSeries(), 'showGrid': false}));

      expect(without.nonBackground(), lessThan(withGrid.nonBackground()),
          reason: 'a setting that changes nothing on screen is a setting the '
              'document may as well not have');
    });

    testWidgets('a donut is a pie with a hole', (tester) async {
      final pie = await render(tester, chart('pie', singleSeries()));
      final donut = await render(tester, chart('donut', singleSeries()));

      expect(donut.nonBackground(), lessThan(pie.nonBackground()),
          reason: 'the hole is the whole difference — a donut that paints a '
              'solid pie is the wrong chart under the right name');
    });

    testWidgets('a bubble chart sizes its points by value, so it differs from '
        'the scatter it is drawn from', (tester) async {
      final scatter = await render(tester, chart('scatter', singleSeries()));
      final bubble = await render(tester, chart('bubble', singleSeries()));

      expect(bubble.nonBackground(), isNot(scatter.nonBackground()),
          reason: 'bubble scales each point by its value — identical ink '
              'means the radius was ignored and it is a scatter chart under '
              'another name. (Which way the total moves depends on the data: '
              'small values draw SMALLER than the scatter\'s fixed radius.)');
      expect(bubble.nonBackground(), greaterThan(100));
    });
  });
}
