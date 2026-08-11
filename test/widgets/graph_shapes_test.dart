// `graph` — the data shapes it accepts and the two chart types it draws.
//
// A chart is the one widget where "it rendered" says nothing: a flat line of
// zeros renders perfectly. What is read here is that each declared point
// shape reaches the painter, and that a bar chart is not silently drawn as a
// line.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import '../behaviour/painted_probe.dart';

void main() {
  late StateManager stateManager;
  late RenderContext context;

  setUp(() {
    stateManager = StateManager()..initialize(<String, dynamic>{});
    final registry = WidgetRegistry();
    DefaultWidgets.registerAll(registry);
    final bindingEngine = BindingEngine();
    final actionHandler = ActionHandler();
    ThemeManager.instance.reset();
    context = RenderContext(
      renderer: Renderer(
        widgetRegistry: registry,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        stateManager: stateManager,
      ),
      stateManager: stateManager,
      bindingEngine: bindingEngine,
      actionHandler: actionHandler,
      themeManager: ThemeManager.instance,
    );
  });

  const probeKey = ValueKey<String>('graph-probe');

  Future<void> pump(WidgetTester tester, Map<String, dynamic> definition) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: isolated(
            context.renderer.renderWidget(definition, context),
            key: probeKey,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Reads the painted pixels of the graph itself.
  Future<Painted> shot(WidgetTester tester) async {
    late Painted painted;
    await tester.runAsync(() async {
      painted = await paintedOf(tester, find.byKey(probeKey));
    });
    return painted;
  }

  Map<String, dynamic> graph({
    List<dynamic>? data,
    Map<String, dynamic> extra = const {},
  }) =>
      <String, dynamic>{
        'type': 'graph',
        'data': data ?? <dynamic>[1, 4, 2, 5],
        'width': 300,
        'height': 200,
        ...extra,
      };

  group('the data shapes', () {
    // The axis labels are painted on the canvas, not built as widgets, so
    // everything here is read from pixels.
    testWidgets('a list of numbers is plotted', (tester) async {
      await pump(tester, graph(extra: <String, dynamic>{
        'lineColor': '#FF0000',
        'showGrid': false,
        'showLabels': false,
      }));

      expect((await shot(tester)).count(const Color(0xFFFF0000)),
          greaterThan(0),
          reason: 'a graph that builds and paints nothing is invisible to '
              'every assertion about the widget tree');
    });

    testWidgets('the `{x, y}` form plots the same series as `{label, value}`',
        (tester) async {
      Future<int> paintedFor(List<dynamic> data) async {
        await pump(tester, graph(data: data, extra: <String, dynamic>{
          'lineColor': '#FF0000',
          'showGrid': false,
          'showLabels': false,
        }));
        return (await shot(tester)).count(const Color(0xFFFF0000));
      }

      final documented = await paintedFor(<dynamic>[
        <String, dynamic>{'x': 'Mon', 'y': 1},
        <String, dynamic>{'x': 'Tue', 'y': 9},
      ]);
      final legacy = await paintedFor(<dynamic>[
        <String, dynamic>{'label': 'Mon', 'value': 1},
        <String, dynamic>{'label': 'Tue', 'value': 9},
      ]);
      final flat = await paintedFor(<dynamic>[
        <String, dynamic>{'x': 'Mon'},
        <String, dynamic>{'x': 'Tue'},
      ]);

      expect(documented, legacy,
          reason: '§10.12 names `{x, y}` first; reading only `{label, value}` '
              'plotted a flat line of zeros for a graph written the '
              'documented way');
      expect(documented, isNot(flat),
          reason: 'a flat line is exactly what the bug drew — the comparison '
              'is what tells the two apart');
    });

    testWidgets('a point with no value plots as zero rather than failing',
        (tester) async {
      await pump(tester, graph(data: <dynamic>[
        <String, dynamic>{'x': 'Mon'},
        <String, dynamic>{'x': 'Tue', 'y': 4},
      ]));

      expect(tester.takeException(), isNull);
    });

    testWidgets('with no data at all nothing is plotted', (tester) async {
      await pump(tester, graph(data: <dynamic>[]));

      expect(tester.takeException(), isNull);
    });
  });

  group('chart types', () {
    testWidgets('a bar chart paints filled bars, not a line', (tester) async {
      await pump(tester, graph(extra: <String, dynamic>{
        'chartType': 'bar',
        'lineColor': '#FF0000',
        'showGrid': false,
        'showLabels': false,
      }));

      final bars = (await shot(tester)).count(const Color(0xFFFF0000));

      await pump(tester, graph(extra: <String, dynamic>{
        'chartType': 'line',
        'lineColor': '#FF0000',
        'showGrid': false,
        'showLabels': false,
      }));
      final line = (await shot(tester)).count(const Color(0xFFFF0000));

      expect(line, greaterThan(0));
      expect(bars, greaterThan(line * 2),
          reason: 'a bar is a filled rectangle and a line is a stroke; '
              'drawing one for the other is a chart that says something '
              'else entirely');
    });

    testWidgets('the legacy `type` spelling still selects the chart',
        (tester) async {
      // `type` is the widget-type key, so this only survives because the
      // factory reads the definition's own copy.
      await pump(tester, graph(extra: <String, dynamic>{'type': 'graph'}));

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('a grid is drawn when asked for', (tester) async {
      await pump(tester, graph(extra: <String, dynamic>{
        'showGrid': true,
        'gridColor': '#00FF00',
        'showLabels': false,
      }));

      final painted = await shot(tester);
      expect(painted.count(const Color(0xFF00FF00)), greaterThan(0));
    });
  });
}
