// What a chart does with the data it is actually given.
//
// A live feed carries gaps, strings where numbers were promised, and datasets
// of different lengths. Each of those has a branch in the parser, and each of
// those branches fails the same way: the chart still draws, with fewer points
// than the reader thinks they are looking at. So these tests count ink —
// `CustomPaint` is in the tree whether or not the parser kept anything.

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
    final key = ValueKey('shape-probe-${seq++}');
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

  group('the values in a dataset', () {
    testWidgets('a numeric string is read as the number it is',
        (tester) async {
      final numbers = await render(
        tester,
        chart('line', {
          'data': {
            'labels': ['Mon', 'Tue', 'Wed'],
            'datasets': [
              {
                'label': 'Kept',
                'data': [3, 8, 5],
                'borderColor': '#FF0000',
              },
            ],
          },
        }),
      );
      final strings = await render(
        tester,
        chart('line', {
          'data': {
            'labels': ['Mon', 'Tue', 'Wed'],
            'datasets': [
              {
                'label': 'Kept',
                'data': ['3', '8', '5'],
                'borderColor': '#FF0000',
              },
            ],
          },
        }),
      );

      expect(strings.count(const Color(0xFFFF0000)),
          closeTo(numbers.count(const Color(0xFFFF0000)), 30),
          reason: 'a JSON feed that quotes its numbers is ordinary; dropping '
              'them draws a shorter line that still looks like a measurement');
    });

    testWidgets('a value that is neither is dropped, not fatal', (tester) async {
      final painted = await render(
        tester,
        chart('line', {
          'data': {
            'labels': ['Mon', 'Tue', 'Wed'],
            'datasets': [
              {
                'label': 'Kept',
                'data': [3, null, 'n/a', 5],
                'borderColor': '#FF0000',
              },
            ],
          },
        }),
      );

      expect(painted.count(const Color(0xFFFF0000)), greaterThan(10),
          reason: 'one unreadable point must cost that point and nothing else');
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty dataset draws no series', (tester) async {
      final painted = await render(
        tester,
        chart('line', {
          'data': {
            'labels': <String>[],
            'datasets': [
              {
                'label': 'Kept',
                'data': <dynamic>[],
                'borderColor': '#FF0000',
              },
            ],
          },
        }),
      );

      expect(painted.count(const Color(0xFFFF0000)), 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('which colour is which', () {
    testWidgets('borderColor draws the line and backgroundColor the fill',
        (tester) async {
      final painted = await render(
        tester,
        chart('line', {
          'data': {
            'labels': ['Mon', 'Tue', 'Wed'],
            'datasets': [
              {
                'label': 'Kept',
                'data': [3, 8, 5],
                'borderColor': '#FF0000',
                'backgroundColor': '#0000FF',
                'fill': true,
              },
            ],
          },
        }),
      );

      expect(painted.count(const Color(0xFFFF0000)), greaterThan(10),
          reason: '§10 — the line is `borderColor`');
      expect(painted.nonBackground(), greaterThan(400),
          reason: 'a filled area is a large block of ink; without it the two '
              'colours would be indistinguishable from a line alone');
    });

    testWidgets('the legacy `color` spelling still draws', (tester) async {
      final painted = await render(
        tester,
        chart('line', {
          'data': {
            'labels': ['Mon', 'Tue', 'Wed'],
            'datasets': [
              {
                'label': 'Kept',
                'data': [3, 8, 5],
                'color': '#FF0000',
              },
            ],
          },
        }),
      );

      expect(painted.count(const Color(0xFFFF0000)), greaterThan(10),
          reason: 'bundles in the field carry it, and dropping it would put '
              'them on the palette default without a word');
    });

    testWidgets('fill: false leaves the area open', (tester) async {
      final filled = await render(
        tester,
        chart('line', {
          'data': {
            'labels': ['Mon', 'Tue', 'Wed'],
            'datasets': [
              {
                'data': [3, 8, 5],
                'borderColor': '#FF0000',
                'fill': true,
              },
            ],
          },
        }),
      );
      final open = await render(
        tester,
        chart('line', {
          'data': {
            'labels': ['Mon', 'Tue', 'Wed'],
            'datasets': [
              {
                'data': [3, 8, 5],
                'borderColor': '#FF0000',
                'fill': false,
              },
            ],
          },
        }),
      );

      expect(open.nonBackground(), lessThan(filled.nonBackground()));
    });
  });

  group('a radar chart', () {
    testWidgets('draws every dataset, on axes taken from the longest',
        (tester) async {
      final painted = await render(
        tester,
        chart('radar', {
          'data': {
            'labels': ['Speed', 'Power'],
            'datasets': [
              {
                'label': 'A',
                'data': [3, 8, 5, 2],
                'borderColor': '#FF0000',
              },
              {
                'label': 'B',
                'data': [6, 2],
                'borderColor': '#0000FF',
              },
            ],
          },
        }),
      );

      expect(painted.count(const Color(0xFFFF0000)), greaterThan(10));
      expect(painted.count(const Color(0xFF0000FF)), greaterThan(10),
          reason: 'a radar that draws only the first series is a comparison '
              'chart with nothing to compare');
    });

    testWidgets('a filled radar covers more than an outlined one',
        (tester) async {
      final outlined = await render(
        tester,
        chart('radar', {
          'data': {
            'labels': ['Speed', 'Power', 'Range'],
            'datasets': [
              {
                'data': [3, 8, 5],
                'borderColor': '#FF0000',
              },
            ],
          },
        }),
      );
      final filled = await render(
        tester,
        chart('radar', {
          'data': {
            'labels': ['Speed', 'Power', 'Range'],
            'datasets': [
              {
                'data': [3, 8, 5],
                'borderColor': '#FF0000',
                'backgroundColor': '#FF0000',
                'fill': true,
              },
            ],
          },
        }),
      );

      expect(filled.nonBackground(), greaterThan(outlined.nonBackground()));
    });

    testWidgets('with no labels declared it numbers its own axes',
        (tester) async {
      final painted = await render(
        tester,
        chart('radar', {
          'data': {
            'datasets': [
              {
                'data': [3, 8, 5],
                'borderColor': '#FF0000',
              },
            ],
          },
        }),
      );

      expect(painted.count(const Color(0xFFFF0000)), greaterThan(10),
          reason: 'a radar whose author left the labels out still has three '
              'axes; refusing to draw it would make labels mandatory for a '
              'shape the spec says they are optional on');
    });
  });

  group('a bare list of numbers', () {
    testWidgets('is charted with generated labels', (tester) async {
      final painted = await render(
        tester,
        chart('bar', {
          'data': [3, 8, 5],
        }),
      );

      expect(painted.nonBackground(), greaterThan(200),
          reason: 'the shortest form a document can write has to draw — an '
              'author reaching for a chart writes this first');
    });
  });
}
