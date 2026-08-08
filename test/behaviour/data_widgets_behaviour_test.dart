// The rest of the data-display family, asked the same way as the chart.
//
// gauge, graph, heatmap, timeline, networkGraph. Each one is a picture drawn
// from numbers, and each declares settings — a range, a colour scale, an
// orientation — that a document is entitled to bind to state. The question is
// never "does it build"; it is "is the value I declared the one on screen".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

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
    Map<String, dynamic> content, {
    Map<String, dynamic>? initialState,
    Size size = const Size(400, 320),
  }) async {
    final key = ValueKey('probe-${seq++}');
    final runtime = MCPUIRuntime();
    live.add(runtime);
    final definition = <String, dynamic>{'type': 'page', 'content': content};
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
                  width: size.width, height: size.height, child: runtime.buildUI()),
              key: key,
            ),
          ),
        ),
      ),
    );
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

  group('gauge', () {
    testWidgets('the needle follows value within min..max', (tester) async {
      Map<String, dynamic> gauge(num value) => {
            'type': 'gauge',
            'value': value,
            'min': 0,
            'max': 100,
            'size': 200,
            'valueColor': '#FF0000',
          };
      final low = await render(tester, gauge(10));
      final high = await render(tester, gauge(90));
      expect(high.count(const Color(0xFFFF0000)),
          greaterThan(low.count(const Color(0xFFFF0000)) + 100),
          reason: 'a higher value must sweep more of the arc');
    });

    testWidgets('min and max are read, including from state', (tester) async {
      Map<String, dynamic> gauge(Object min, Object max) => {
            'type': 'gauge',
            'value': 50,
            'min': min,
            'max': max,
            'size': 200,
            'valueColor': '#FF0000',
          };
      final wide = await render(tester, gauge(0, 100));
      final narrow = await render(tester, gauge(0, 50));
      expect(narrow.count(const Color(0xFFFF0000)),
          greaterThan(wide.count(const Color(0xFFFF0000)) + 100),
          reason: '50 of 50 is a full arc; 50 of 100 is half of one');

      final bound = await render(
        tester,
        gauge('{{low}}', '{{high}}'),
        initialState: {'low': 0, 'high': 50},
      );
      expect(tester.takeException(), isNull,
          reason: 'a bound range must not throw');
      expect((bound.count(const Color(0xFFFF0000)) -
              narrow.count(const Color(0xFFFF0000)))
          .abs(),
          lessThan(200),
          reason: 'a range read from state must draw what the literal drew');
    });

    testWidgets('the declared segments are painted', (tester) async {
      final painted = await render(tester, {
        'type': 'gauge',
        'value': 50,
        'min': 0,
        'max': 100,
        'size': 200,
        'segments': [
          {'from': 0, 'to': 50, 'color': '#00FF00'},
          {'from': 50, 'to': 100, 'color': '#0000FF'},
        ],
      });
      expect(painted.count(const Color(0xFF00FF00)), greaterThan(20),
          reason: 'first segment colour missing');
      expect(painted.count(const Color(0xFF0000FF)), greaterThan(20),
          reason: 'second segment colour missing');
    });

    testWidgets('labelFormat decides the text, and showLabel removes it',
        (tester) async {
      await render(tester, {
        'type': 'gauge',
        'value': 42,
        'min': 0,
        'max': 100,
        'size': 200,
        'labelFormat': '{value} kg',
      });
      expect(find.text('42 kg'), findsOneWidget);

      await render(tester, {
        'type': 'gauge',
        'value': 42,
        'min': 0,
        'max': 100,
        'size': 200,
        'showLabel': false,
      });
      expect(find.textContaining('42'), findsNothing,
          reason: 'showLabel: false still drew the reading');
    });
  });

  group('graph', () {
    testWidgets('the series is drawn in the declared colour', (tester) async {
      final painted = await render(tester, {
        'type': 'graph',
        'data': [1, 5, 2, 8],
        'lineColor': '#FF0000',
        'width': 380,
        'height': 200,
      });
      expect(painted.count(const Color(0xFFFF0000)), greaterThan(50));
    });

    testWidgets('a series of {x, y} points is plotted', (tester) async {
      // The form §10.12 names first. Reading only `{label, value}` plotted a
      // flat line of zeros for it — a graph that looks drawn and says nothing.
      final points = await render(tester, {
        'type': 'graph',
        'data': [
          {'x': 0, 'y': 1},
          {'x': 1, 'y': 9},
          {'x': 2, 'y': 3},
        ],
        'lineColor': '#FF0000',
        'showGrid': false,
        'width': 380,
        'height': 200,
      });
      final flat = await render(tester, {
        'type': 'graph',
        'data': [
          {'x': 0, 'y': 0},
          {'x': 1, 'y': 0},
          {'x': 2, 'y': 0},
        ],
        'lineColor': '#FF0000',
        'showGrid': false,
        'width': 380,
        'height': 200,
      });
      expect(difference(points, flat), greaterThan(0.005),
          reason: 'the y values were dropped and every point drew the same');
    });

    testWidgets('showGrid and strokeWidth reach the picture, bound or not',
        (tester) async {
      Map<String, dynamic> graph(Object showGrid, Object stroke) => {
            'type': 'graph',
            'data': [1, 5, 2, 8],
            'lineColor': '#FF0000',
            'gridColor': '#00FF00',
            'showGrid': showGrid,
            'strokeWidth': stroke,
            'width': 380,
            'height': 200,
          };
      final on = await render(tester, graph(true, 2));
      final off = await render(tester, graph(false, 2));
      expect(difference(on, off), greaterThan(0.005),
          reason: 'showGrid: false rendered exactly what true did');

      final thick = await render(tester, graph(true, 8));
      expect(thick.count(const Color(0xFFFF0000)),
          greaterThan(on.count(const Color(0xFFFF0000))),
          reason: 'strokeWidth was declared and the line did not thicken');

      final bound = await render(
        tester,
        graph('{{grid}}', '{{stroke}}'),
        initialState: {'grid': false, 'stroke': 2},
      );
      expect(tester.takeException(), isNull);
      expect(difference(bound, off), lessThan(0.01),
          reason: 'settings read from state must draw what literals drew');
    });
  });

  group('heatmap', () {
    testWidgets('a cell colour follows its value against min/max',
        (tester) async {
      final painted = await render(tester, {
        'type': 'heatmap',
        'data': [
          [0, 1],
          [1, 0],
        ],
        'minValue': 0,
        'maxValue': 1,
        'colorRange': {'low': '#FFFFFF', 'high': '#FF0000'},
        'cellSize': 60,
      });
      expect(painted.count(const Color(0xFFFF0000)), greaterThan(200),
          reason: 'the high end of the declared range never appeared');
    });

    testWidgets('showValues prints the numbers in the cells', (tester) async {
      await render(tester, {
        'type': 'heatmap',
        'data': [
          [7, 3],
        ],
        'minValue': 0,
        'maxValue': 10,
        'showValues': true,
        'cellSize': 60,
      });
      expect(find.textContaining('7'), findsWidgets);
    });

    testWidgets('a bound scale is read', (tester) async {
      await render(
        tester,
        {
          'type': 'heatmap',
          'data': '{{grid}}',
          'minValue': '{{min}}',
          'maxValue': '{{max}}',
          'cellSize': 40,
        },
        initialState: {
          'grid': [
            [1, 2],
            [3, 4],
          ],
          'min': 0,
          'max': 4,
        },
      );
      expect(tester.takeException(), isNull,
          reason: 'a heatmap fed from state must not throw');
    });

    testWidgets('onCellTap reports which cell', (tester) async {
      final runtime = MCPUIRuntime();
      live.add(runtime);
      await runtime.initialize({
        'type': 'page',
        'runtime': {
          'services': {
            'state': {
              'initialState': {'tapped': ''},
            },
          },
        },
        'content': {
          'type': 'linear',
          'direction': 'vertical',
          'children': [
            {
              'type': 'heatmap',
              'data': [
                [1, 2],
              ],
              'cellSize': 60,
              'onCellTap': {
                'type': 'state',
                'action': 'set',
                'binding': 'tapped',
                'value': '{{event.row}}:{{event.column}}',
              },
            },
            {'type': 'text', 'text': 'tapped={{tapped}}'},
          ],
        },
      });
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pumpAndSettle();

      final cells = find.byType(InkWell);
      expect(cells, findsWidgets,
          reason: 'onCellTap was declared and no cell is tappable');
      await tester.tap(cells.first);
      await tester.pumpAndSettle();
      expect(find.text('tapped=0:0'), findsOneWidget,
          reason: 'the tap must say which cell it was');
    });
  });

  group('timeline', () {
    testWidgets('every declared item is drawn', (tester) async {
      await render(tester, {
        'type': 'timeline',
        'items': [
          {'title': 'Ordered', 'subtitle': 'today'},
          {'title': 'Shipped'},
          {'title': 'Delivered'},
        ],
      });
      expect(find.text('Ordered'), findsOneWidget);
      expect(find.text('Shipped'), findsOneWidget);
      expect(find.text('Delivered'), findsOneWidget);
    });

    testWidgets('orientation changes the layout', (tester) async {
      Map<String, dynamic> timeline(String orientation) => {
            'type': 'timeline',
            'orientation': orientation,
            'items': [
              {'title': 'A'},
              {'title': 'B'},
            ],
          };
      await render(tester, timeline('vertical'));
      final verticalGap =
          (tester.getCenter(find.text('B')).dy - tester.getCenter(find.text('A')).dy)
              .abs();
      await render(tester, timeline('horizontal'));
      final horizontalGap =
          (tester.getCenter(find.text('B')).dx - tester.getCenter(find.text('A')).dx)
              .abs();
      expect(verticalGap, greaterThan(1),
          reason: 'vertical items were not stacked');
      expect(horizontalGap, greaterThan(1),
          reason: 'orientation: horizontal laid the items out vertically');
    });

    testWidgets('items from state are drawn', (tester) async {
      await render(
        tester,
        {
          'type': 'timeline',
          'items': '{{events}}',
        },
        initialState: {
          'events': [
            {'title': 'From state'},
          ],
        },
      );
      expect(find.text('From state'), findsOneWidget);
    });
  });

  group('gantt', () {
    testWidgets('a task keeps its own colour and its band', (tester) async {
      final painted = await render(tester, size: const Size(600, 420), {
        'type': 'gantt',
        'rowHeight': 28,
        'tasks': [
          {
            'id': 'a',
            'label': 'Design',
            'start': '2026-01-01',
            'end': '2026-01-05',
            'group': 'Team A',
            'color': '#FF0000',
          },
          {
            'id': 'b',
            'label': 'Build',
            'start': '2026-01-03',
            'end': '2026-01-09',
            'group': 'Team B',
            'color': '#00FF00',
          },
        ],
      });
      // ignore: avoid_print
      expect(painted.count(const Color(0xFFFF0000)), greaterThan(100),
          reason: 'the task named a colour and the bar came out theme blue');
      expect(painted.count(const Color(0xFF00FF00)), greaterThan(100));
      expect(find.text('Team A'), findsOneWidget,
          reason: '`group` was declared and the rows were one undivided list');
      expect(find.text('Team B'), findsOneWidget);
    });
  });

  group('networkGraph — the topology may come from state', () {
    // §10.12 now types `nodes` / `edges` as `array<object> | binding`, the way
    // every other data widget reads (`heatmap.data`, `dataTable.rows`,
    // `kanban.columns`). A dashboard the server draws cannot have its topology
    // written into the document by hand, and a literal-only graph was the one
    // widget in the family that forced exactly that. Reported by konpi, who
    // read the property table first and asked rather than filing it as a bug.
    const nodes = [
      {'id': 'a', 'label': 'A'},
      {'id': 'b', 'label': 'B'},
      {'id': 'c', 'label': 'C'},
    ];
    const edges = [
      {'from': 'a', 'to': 'b'},
      {'from': 'b', 'to': 'c'},
    ];

    testWidgets('nodes that arrive after the first frame still draw',
        (tester) async {
      // The failure konpi measured on the published build, and the reason the
      // unit check above passed while the app drew an empty panel: state is
      // present before the first build in this harness, and in an app it
      // arrives after it. The node list was copied once in initState, so a
      // late `nodes` never reached the layout — while `edges` looked fine,
      // because the painter reads those on every paint.
      final runtime = MCPUIRuntime();
      addTearDown(runtime.destroy);
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'networkGraph',
          'nodes': '{{late.nodes}}',
          'edges': '{{late.edges}}',
          'nodeColor': '#E91E63',
          'layout': 'tree',
        },
        'runtime': {
          'services': {
            'state': {
              'initialState': {'late': <String, dynamic>{}},
            },
          },
        },
      });
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: isolated(
              SizedBox(width: 420, height: 320, child: runtime.buildUI()),
              key: const ValueKey('late-nodes'),
            ),
          ),
        ),
      ));
      await tester.pump();

      runtime.stateManager.set('late', {'nodes': nodes, 'edges': edges});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      late Painted painted;
      await tester.runAsync(() async {
        painted = await paintedOf(tester, find.byKey(const ValueKey('late-nodes')));
      });
      expect(painted.count(const Color(0xFFE91E63)), greaterThan(0),
          reason: 'a topology that arrives from state after the first frame '
              'must be drawn, the way every other data widget draws late data');
    });

    testWidgets('a bound topology draws what a literal one draws',
        (tester) async {
      final literal = await render(tester, {
        'type': 'networkGraph',
        'nodes': nodes,
        'edges': edges,
        'layout': 'circular',
      });
      final bound = await render(
        tester,
        {
          'type': 'networkGraph',
          'nodes': '{{graph.nodes}}',
          'edges': '{{graph.edges}}',
          'layout': 'circular',
        },
        initialState: {
          'graph': {'nodes': nodes, 'edges': edges},
        },
      );

      expect(literal.nonBackground(), greaterThan(0),
          reason: 'the literal form is the control — if it draws nothing the '
              'comparison below means nothing');
      expect(bound.nonBackground(), greaterThan(0),
          reason: 'a bound topology drew an empty panel');
      expect(difference(literal, bound), lessThan(0.01),
          reason: 'the same topology, declared two ways, is the same picture');
    });
  });

  group('heatmap — the scale, the precision, and what showLabels means', () {
    // konpi authored a factory report from a heatmap and shipped a screen that
    // was one flat red block: every cell painted at the top of the scale. The
    // range defaulted to 0..1 while the data ran 1.5..6.2, and `minValue` /
    // `maxValue` are optional in the property table — so a document that omits
    // them is entitled to a scale, not to a wall of one colour.
    Map<String, dynamic> heat({bool withRange = false, bool labels = false}) => {
          'type': 'heatmap',
          'data': [
            [1.5, 3.0, 6.2],
            [2.2, 4.1, 5.4],
          ],
          'rowLabels': ['P-1', 'P-2'],
          'columnLabels': ['06', '07', '08'],
          'colorRange': {'low': '#E8F5E9', 'high': '#B71C1C'},
          'cellSize': 48,
          if (labels) 'showLabels': true,
          if (withRange) 'minValue': 0,
          if (withRange) 'maxValue': 7,
        };

    testWidgets('an unspecified range is taken from the data', (tester) async {
      // Read two cells, not the picture as a whole: counting colours passes on
      // grid lines and anti-aliased digits even when every cell is the same
      // block of red. The lowest value and the highest must not be painted the
      // same colour — that IS the heatmap.
      Color cellColour(Painted p, int col) {
        // Cells are laid out left to right at `cellSize` 48 with a 2px gap,
        // inside the widget's own padding; sample the middle of the first row.
        final x = 24 + col * 50;
        return p.at(x.clamp(0, p.width - 1), 24);
      }

      final auto = await render(tester, heat());
      final low = cellColour(auto, 0);   // 1.5 — bottom of the data
      final high = cellColour(auto, 2);  // 6.2 — top of the data
      final spread = (low.r - high.r).abs() +
          (low.g - high.g).abs() +
          (low.b - high.b).abs();
      expect(spread, greaterThan(0.15),
          reason: 'with no declared range the scale must still come from the '
              'data: 1.5 and 6.2 painted the same colour is a flat block, '
              'which is what a 0..1 default produces');
    });

    testWidgets('a fractional value is not shown as an integer',
        (tester) async {
      await tester.pumpWidget(const SizedBox());
      final runtime = MCPUIRuntime();
      live.add(runtime);
      await runtime.initialize({'type': 'page', 'content': heat()});
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SizedBox(width: 420, height: 320, child: runtime.buildUI())),
      ));
      await tester.pump(const Duration(milliseconds: 200));
      // 1.5 and 2.2 both printed as "2": a defect rate of 1.8 and one of 2.4
      // read the same, and the screen is wrong while looking finished.
      expect(find.text('1.5'), findsOneWidget);
      expect(find.text('6.2'), findsOneWidget);
    });

    testWidgets('row and column labels draw when declared', (tester) async {
      await tester.pumpWidget(const SizedBox());
      final runtime = MCPUIRuntime();
      live.add(runtime);
      await runtime.initialize({'type': 'page', 'content': heat(labels: true)});
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SizedBox(width: 420, height: 320, child: runtime.buildUI())),
      ));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('P-1'), findsOneWidget);
      expect(find.text('06'), findsOneWidget);
    });
  });

  group('networkGraph', () {
    testWidgets('nodes and edges are drawn in the declared colours',
        (tester) async {
      final painted = await render(tester, {
        'type': 'networkGraph',
        'nodes': [
          {'id': 'a', 'label': 'A'},
          {'id': 'b', 'label': 'B'},
        ],
        'edges': [
          {'from': 'a', 'to': 'b'},
        ],
        'nodeColor': '#FF0000',
        'edgeColor': '#00FF00',
        'width': 380,
        'height': 260,
      });
      expect(painted.count(const Color(0xFFFF0000)), greaterThan(50),
          reason: 'no node was drawn in the declared node colour');
      // An edge is a 1.5px line, so almost every one of its pixels is a blend
      // with the background — the tolerance is what "this line is green"
      // means at that width, and the comparison below is what proves the line
      // is there at all.
      expect(painted.count(const Color(0xFF00FF00), tolerance: 130),
          greaterThan(50),
          reason: 'the edge is drawn in something other than the declared '
              'edge colour');

      final noEdge = await render(tester, {
        'type': 'networkGraph',
        'nodes': [
          {'id': 'a', 'label': 'A'},
          {'id': 'b', 'label': 'B'},
        ],
        'edges': <dynamic>[],
        'nodeColor': '#FF0000',
        'edgeColor': '#00FF00',
        'width': 380,
        'height': 260,
      });
      expect(difference(painted, noEdge), greaterThan(0.001),
          reason: 'the edge between two declared nodes is missing — spec '
              '§10.13 spells it {from, to}');
    });

    testWidgets('a graph fed from state is drawn', (tester) async {
      final painted = await render(
        tester,
        {
          'type': 'networkGraph',
          'nodes': '{{nodes}}',
          'edges': '{{edges}}',
          'nodeColor': '#FF0000',
          'width': 380,
          'height': 260,
        },
        initialState: {
          'nodes': [
            {'id': 'a', 'label': 'A'},
            {'id': 'b', 'label': 'B'},
          ],
          'edges': [
            {'from': 'a', 'to': 'b'},
          ],
        },
      );
      expect(painted.count(const Color(0xFFFF0000)), greaterThan(50));
    });
  });
}
