// Does the chart draw what the document declared?
//
// Every test here renders the real widget and reads the pixels. The questions
// are the ones an author asks: is my data on the screen, is the second dataset
// there, is the line the colour I asked for, did `showGrid: false` remove the
// grid, does a bound value arrive.
//
// The existing chart tests assert that a `CustomPaint` exists and that the
// schema accepts the document. Both stayed true while `data.datasets[].data`
// carrying a binding threw, and while `backgroundColor` on a dataset was read
// by nobody.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

import 'painted_probe.dart';

void main() {
  // One runtime per render, not per test: several tests render the same chart
  // twice to compare settings, and a runtime is initialised once.
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
    Map<String, dynamic>? initialState,
    Size size = const Size(400, 300),
  }) async {
    // A fresh key per render. Reusing one meant the second render in a test
    // read the first boundary's discarded layer and came back blank — every
    // "did this setting change the picture" comparison would have passed
    // against an empty image.
    final key = ValueKey('painted-probe-${seq++}');
    final runtime = MCPUIRuntime();
    live.add(runtime);
    final definition = <String, dynamic>{'type': 'page', 'content': chart};
    if (initialState != null) {
      definition['runtime'] = {
        'services': {
          'state': {'initialState': initialState},
        },
      };
    }
    await runtime.initialize(definition);
    await tester.pumpWidget(
      MaterialApp(
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
      ),
    );
    // Not pumpAndSettle: a page already on screen from an earlier render in
    // the same test may still be running its own frames, and waiting for the
    // whole tree to go quiet then never returns. Two frames is what the chart
    // needs, and what an author sees.
    await tester.pump();
    // Past the default entry animation (§10 `options.animation.duration`,
    // 1000 ms): a probe that reads the first frame is reading a chart that is
    // still drawing itself.
    await tester.pump(const Duration(milliseconds: 1200));
    late Painted painted;
    await tester.runAsync(() async {
      painted = await paintedOf(tester, find.byKey(key));
    });
    return painted;
  }

  Map<String, dynamic> chart(Map<String, dynamic> extra) => <String, dynamic>{
        'type': 'chart',
        'chartType': 'line',
        'width': 380,
        'height': 260,
        ...extra,
      };

  group('the data reaches the picture', () {
    testWidgets('a single series is drawn in the declared colour',
        (tester) async {
      final painted = await render(
        tester,
        chart({
          'primaryColor': '#FF0000',
          'data': [
            {'label': 'a', 'value': 1},
            {'label': 'b', 'value': 8},
            {'label': 'c', 'value': 3},
          ],
        }),
      );
      expect(painted.count(const Color(0xFFFF0000)), greaterThan(50),
          reason: 'the series was declared red and nothing red was painted');
    });

    testWidgets('a bound series is resolved, not printed', (tester) async {
      final painted = await render(
        tester,
        chart({
          'primaryColor': '#FF0000',
          'data': '{{series}}',
        }),
        initialState: {
          'series': [
            {'label': 'a', 'value': 2},
            {'label': 'b', 'value': 9},
          ],
        },
      );
      expect(painted.count(const Color(0xFFFF0000)), greaterThan(50),
          reason: 'a chart whose data comes from state is the normal case');
      expect(find.text('No chart data'), findsNothing);
    });

    testWidgets('every declared dataset is drawn, not only the first',
        (tester) async {
      final painted = await render(
        tester,
        chart({
          'data': {
            'labels': ['a', 'b', 'c'],
            'datasets': [
              {
                'label': 'one',
                'data': [1, 5, 2],
                'borderColor': '#FF0000',
              },
              {
                'label': 'two',
                'data': [4, 2, 6],
                'borderColor': '#00FF00',
              },
            ],
          },
        }),
      );
      expect(painted.count(const Color(0xFFFF0000)), greaterThan(30),
          reason: 'first dataset missing');
      expect(painted.count(const Color(0xFF00FF00)), greaterThan(30),
          reason: 'a second dataset that is declared and not drawn is the '
              'chart quietly showing half the truth');
    });

    testWidgets('a dataset whose values come from state is drawn',
        (tester) async {
      final painted = await render(
        tester,
        chart({
          'data': {
            'labels': '{{labels}}',
            'datasets': [
              {
                'label': '{{name}}',
                'data': '{{values}}',
                'borderColor': '#FF0000',
              },
            ],
          },
        }),
        initialState: {
          'labels': ['a', 'b', 'c'],
          'name': 'Revenue',
          'values': [3, 7, 5],
        },
      );
      expect(painted.count(const Color(0xFFFF0000)), greaterThan(30),
          reason: 'a dataset bound to state drew nothing — which is how every '
              'chart fed by live data behaves');
      expect(find.text('Revenue'), findsOneWidget,
          reason: 'the legend printed the binding expression instead of the '
              'value it resolves to');
    });

    testWidgets('the whole dataset list can come from one binding',
        (tester) async {
      final painted = await render(
        tester,
        chart({
          'data': {
            'labels': ['a', 'b'],
            'datasets': '{{series}}',
          },
        }),
        initialState: {
          'series': [
            {
              'label': 'one',
              'data': [1, 4],
              'borderColor': '#FF0000',
            },
          ],
        },
      );
      expect(painted.count(const Color(0xFFFF0000)), greaterThan(30),
          reason: 'a dashboard builds its series in state and binds the list');
    });

    testWidgets('a dataset fill colour is honoured', (tester) async {
      final painted = await render(
        tester,
        chart({
          'chartType': 'bar',
          'data': {
            'labels': ['a', 'b'],
            'datasets': [
              {
                'label': 'one',
                'data': [4, 8],
                'backgroundColor': '#0000FF',
              },
            ],
          },
        }),
      );
      expect(painted.count(const Color(0xFF0000FF)), greaterThan(100),
          reason: 'the spec declares `datasets[].backgroundColor`; bars drawn '
              'in some other colour mean the document was ignored');
    });
  });

  group('the settings reach the picture', () {
    testWidgets('showGrid draws rules, and turning it off removes them',
        (tester) async {
      final on = await render(
        tester,
        chart({
          'showGrid': true,
          'gridColor': '#FF00FF',
          'data': [
            {'label': 'a', 'value': 1},
            {'label': 'b', 'value': 5},
          ],
        }),
      );
      expect(on.count(const Color(0xFFFF00FF), tolerance: 90), greaterThan(50),
          reason: 'showGrid: true drew nothing in the declared grid colour');

      final off = await render(
        tester,
        chart({
          'showGrid': false,
          'gridColor': '#FF00FF',
          'data': [
            {'label': 'a', 'value': 1},
            {'label': 'b', 'value': 5},
          ],
        }),
      );
      expect(difference(on, off), greaterThan(0.005),
          reason: 'showGrid: false rendered exactly what showGrid: true did');

      final otherColour = await render(
        tester,
        chart({
          'showGrid': true,
          'gridColor': '#00FF00',
          'data': [
            {'label': 'a', 'value': 1},
            {'label': 'b', 'value': 5},
          ],
        }),
      );
      expect(difference(on, otherColour), greaterThan(0.002),
          reason: 'the grid ignored the declared colour');
    });

    testWidgets('showLabels draws the axis labels, and off removes them',
        (tester) async {
      // The legend is off in both renders: it prints the same names, and a
      // test that cannot tell an axis label from a legend entry proves
      // nothing about either.
      Map<String, dynamic> spec(bool show) => chart({
            'showLabels': show,
            'options': {
              'legend': {'position': 'none'},
            },
            'data': [
              {'label': 'Mon', 'value': 1},
              {'label': 'Tue', 'value': 5},
            ],
          });

      final on = await render(tester, spec(true));
      final off = await render(tester, spec(false));
      expect(difference(on, off), greaterThan(0.002),
          reason: 'showLabels: false rendered exactly what true did');
    });

    testWidgets('the legend follows options.legend.position', (tester) async {
      final data = {
        'labels': ['a', 'b'],
        'datasets': [
          {
            'label': 'Revenue',
            'data': [1, 2],
          },
        ],
      };
      await render(tester, chart({'data': data}));
      final top = tester.getCenter(find.text('Revenue')).dy;

      await render(
        tester,
        chart({
          'data': data,
          'options': {
            'legend': {'position': 'bottom'},
          },
        }),
      );
      final bottom = tester.getCenter(find.text('Revenue')).dy;
      expect(bottom, greaterThan(top),
          reason: 'position: bottom drew the legend in the same place as top');

      await render(
        tester,
        chart({
          'data': data,
          'options': {
            'legend': {'position': 'none'},
          },
        }),
      );
      expect(find.text('Revenue'), findsNothing,
          reason: 'position: none still drew a legend');
    });

    testWidgets('the chart type changes what is drawn', (tester) async {
      final data = [
        {'label': 'a', 'value': 3},
        {'label': 'b', 'value': 7},
        {'label': 'c', 'value': 5},
      ];
      final renders = <String, Painted>{};
      for (final type in ['line', 'bar', 'pie', 'area', 'scatter']) {
        renders[type] = await render(
          tester,
          chart({
            'chartType': type,
            'data': data,
            'primaryColor': '#FF0000',
            // A pie takes one colour per slice; every type must honour the
            // series colours it is given.
            'colors': ['#FF0000', '#FF0000', '#FF0000'],
          }),
        );
      }
      for (final type in renders.keys) {
        expect(renders[type]!.count(const Color(0xFFFF0000)), greaterThan(20),
            reason: '$type drew nothing in the declared colour');
      }
      // Each type must differ from every other: a `chartType` that falls
      // through to the same drawing accepts the word and ignores it.
      final types = renders.keys.toList();
      for (var i = 0; i < types.length; i++) {
        for (var j = i + 1; j < types.length; j++) {
          expect(difference(renders[types[i]]!, renders[types[j]]!),
              greaterThan(0.01),
              reason: '${types[i]} and ${types[j]} render identically');
        }
      }
    });

    testWidgets('options.animation.duration decides the reveal', (tester) async {
      final data = [
        {'label': 'a', 'value': 3},
        {'label': 'b', 'value': 7},
        {'label': 'c', 'value': 5},
      ];
      // Mid-reveal at 100ms into a one-second animation, the chart is only
      // partly drawn; with the animation turned off it is complete on the
      // first frame. A duration nobody reads makes these identical.
      final instant = await render(
        tester,
        chart({
          'data': data,
          'primaryColor': '#FF0000',
          'options': {
            'animation': {'duration': 0},
          },
        }),
      );
      final slow = await render(
        tester,
        chart({
          'data': data,
          'primaryColor': '#FF0000',
          'options': {
            'animation': {'duration': 8000},
          },
        }),
      );
      expect(slow.count(const Color(0xFFFF0000)),
          lessThan(instant.count(const Color(0xFFFF0000))),
          reason: 'the declared duration did not delay anything');
    });

    testWidgets('the declared title is drawn', (tester) async {
      await render(
        tester,
        chart({
          'title': 'Quarterly',
          'data': [
            {'label': 'a', 'value': 1},
          ],
        }),
      );
      expect(find.text('Quarterly'), findsOneWidget);
    });
  });

  group('a chart with nothing to draw says so', () {
    testWidgets('empty data draws the empty state, not a blank panel',
        (tester) async {
      await render(tester, chart({'data': <dynamic>[]}));
      expect(find.text('No chart data'), findsOneWidget);
    });

    testWidgets('a gap in a live feed costs that point, not the chart',
        (tester) async {
      final painted = await render(
        tester,
        chart({
          'data': {
            'labels': ['a', 'b', 'c', 'd'],
            'datasets': [
              {
                'label': 'one',
                'data': [1, null, 'x', 4],
                'borderColor': '#FF0000',
              },
            ],
          },
        }),
      );
      expect(tester.takeException(), isNull);
      // Not just "no crash": the runtime catches a throwing widget and shows
      // its own panel, so a chart that threw would still leave the page
      // standing. What must survive is the chart.
      expect(painted.count(const Color(0xFFFF0000)), greaterThan(20),
          reason: 'the readable points were dropped along with the bad one');
    });
  });
}
