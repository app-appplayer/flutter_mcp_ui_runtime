// `shouldRepaint` on the widgets that draw themselves.
//
// A painter that answers `false` when something it draws has changed leaves
// the old picture on screen: a gauge stuck at the previous reading, a chart
// that keeps yesterday's colour, a waveform that stops moving. The widget
// tree is identical either way, and so is every assertion about it — the only
// way to see it is to change a value and look at the pixels again.

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

  /// Renders once, changes state, renders again, and hands back both frames.
  /// The widget is mounted ONCE so the painter is asked whether to repaint,
  /// which is the branch under test.
  Future<(Painted, Painted)> repaintAfter(
    WidgetTester tester,
    Map<String, dynamic> definition,
    void Function() change, {
    Size size = const Size(300, 220),
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFFFFFFFF),
        body: Center(
          child: isolated(
            SizedBox(
              width: size.width,
              height: size.height,
              child: AnimatedBuilder(
                animation: stateManager,
                builder: (_, __) =>
                    context.renderer.renderWidget(definition, context),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    late Painted before;
    await tester.runAsync(() async {
      before = await paintedOf(
          tester, find.byKey(const ValueKey('painted-probe')));
    });

    change();
    await tester.pumpAndSettle();
    late Painted after;
    await tester.runAsync(() async {
      after = await paintedOf(
          tester, find.byKey(const ValueKey('painted-probe')));
    });
    return (before, after);
  }

  testWidgets('a gauge redraws when its reading moves', (tester) async {
    stateManager.set('level', 0.1);
    final (before, after) = await repaintAfter(
      tester,
      <String, dynamic>{
        'type': 'gauge',
        'value': '{{level}}',
        'min': 0,
        'max': 1,
        'valueColor': '#FF0000',
      },
      () => stateManager.set('level', 0.9),
    );

    expect(difference(before, after), greaterThan(0.005),
        reason: 'a gauge that answers "no repaint" when the reading moves is '
            'a dial stuck at the last value, which reads as a sensor that '
            'stopped rather than a widget that did not redraw');
  });

  testWidgets('a chart redraws when its colour changes', (tester) async {
    stateManager.set('colour', '#FF0000');
    final (before, after) = await repaintAfter(
      tester,
      <String, dynamic>{
        'type': 'chart',
        'chartType': 'line',
        'primaryColor': '{{colour}}',
        'options': <String, dynamic>{
          'animation': <String, dynamic>{'duration': 0},
        },
        'data': <dynamic>[
          <String, dynamic>{'label': 'a', 'value': 3},
          <String, dynamic>{'label': 'b', 'value': 7},
        ],
      },
      () => stateManager.set('colour', '#0000FF'),
    );

    expect(difference(before, after), greaterThan(0.005));
  });

  testWidgets('a chart redraws when its labels are turned off',
      (tester) async {
    stateManager.set('labels', true);
    final (before, after) = await repaintAfter(
      tester,
      <String, dynamic>{
        'type': 'chart',
        'chartType': 'bar',
        'showLabels': '{{labels}}',
        'options': <String, dynamic>{
          'animation': <String, dynamic>{'duration': 0},
        },
        'data': <dynamic>[
          <String, dynamic>{'label': 'alpha', 'value': 3},
          <String, dynamic>{'label': 'beta', 'value': 7},
        ],
      },
      () => stateManager.set('labels', false),
    );

    expect(difference(before, after), greaterThan(0.002),
        reason: 'labels that stay on screen after the document turned them '
            'off are a setting with no effect');
  });

  testWidgets('a canvas redraws when its commands change', (tester) async {
    stateManager.set('w', 20.0);
    final (before, after) = await repaintAfter(
      tester,
      <String, dynamic>{
        'type': 'canvas',
        'width': 200,
        'height': 200,
        'commands': <dynamic>[
          <String, dynamic>{
            'op': 'rect',
            'x': 10,
            'y': 10,
            'width': '{{w}}',
            'height': 20,
            'fill': '#FF0000',
          },
        ],
      },
      () => stateManager.set('w', 120.0),
    );

    expect(difference(before, after), greaterThan(0.002),
        reason: 'a canvas is a document drawing directly; a painter that will '
            'not repaint makes every later command invisible');
  });

  testWidgets('a barcode redraws when its payload changes', (tester) async {
    stateManager.set('code', '5901234123457');
    final (before, after) = await repaintAfter(
      tester,
      <String, dynamic>{
        'type': 'barcode',
        'format': 'ean13',
        'value': '{{code}}',
        'displayValue': false,
      },
      () => stateManager.set('code', '4006381333931'),
    );

    expect(difference(before, after), greaterThan(0.002),
        reason: 'a label printed from a stale symbol scans as the previous '
            'item, which is the one failure a barcode must never have');
  });
}
