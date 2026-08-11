// `linear`'s alignment vocabulary and `canvas`'s drawing commands.
//
// Both are lookup tables a document writes into, and both fail the same
// quiet way: an unrecognised spelling falls back to the first value, so a row
// declared `space-between` renders left-aligned and looks like a layout
// mistake rather than a dropped property.

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

  const probeKey = ValueKey<String>('probe');

  Future<void> pump(WidgetTester tester, Map<String, dynamic> definition) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: isolated(
            SizedBox(
              width: 300,
              height: 200,
              child: context.renderer.renderWidget(definition, context),
            ),
            key: probeKey,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> text(String content) =>
      <String, dynamic>{'type': 'text', 'content': content};

  group('linear — cross-axis alignment', () {
    Future<CrossAxisAlignment> alignmentOf(
        WidgetTester tester, String declared) async {
      await pump(tester, <String, dynamic>{
        'type': 'linear',
        'direction': 'horizontal',
        'crossAxisAlignment': declared,
        'children': <dynamic>[text('a'), text('b')],
      });
      return tester.widget<Row>(find.byType(Row)).crossAxisAlignment;
    }

    testWidgets('each declared value reaches the row', (tester) async {
      expect(await alignmentOf(tester, 'start'), CrossAxisAlignment.start);
      expect(await alignmentOf(tester, 'end'), CrossAxisAlignment.end);
      expect(await alignmentOf(tester, 'center'), CrossAxisAlignment.center);
      expect(await alignmentOf(tester, 'stretch'), CrossAxisAlignment.stretch);
      expect(await alignmentOf(tester, 'nonsense'), CrossAxisAlignment.start,
          reason: 'an unknown spelling is a typo; the first value is the safe '
              'reading, and it must not throw');
    });

  });

  group('linear — wrapping', () {
    Future<Wrap> wrapWith(
      WidgetTester tester, {
      String? alignment,
      String? crossAlignment,
    }) async {
      await pump(tester, <String, dynamic>{
        'type': 'linear',
        'direction': 'horizontal',
        'wrap': true,
        if (alignment != null) 'mainAxisAlignment': alignment,
        if (crossAlignment != null) 'crossAxisAlignment': crossAlignment,
        'children': <dynamic>[text('a'), text('b')],
      });
      return tester.widget<Wrap>(find.byType(Wrap));
    }

    testWidgets('both spellings of every space rule are read', (tester) async {
      expect((await wrapWith(tester, alignment: 'start')).alignment,
          WrapAlignment.start);
      expect((await wrapWith(tester, alignment: 'end')).alignment,
          WrapAlignment.end);
      expect((await wrapWith(tester, alignment: 'center')).alignment,
          WrapAlignment.center);
      expect((await wrapWith(tester, alignment: 'space-between')).alignment,
          WrapAlignment.spaceBetween,
          reason: 'a row declared space-between that renders left-aligned '
              'reads as a layout mistake, not a dropped property');
      expect((await wrapWith(tester, alignment: 'spaceBetween')).alignment,
          WrapAlignment.spaceBetween);
      expect((await wrapWith(tester, alignment: 'space-around')).alignment,
          WrapAlignment.spaceAround);
      expect((await wrapWith(tester, alignment: 'spaceAround')).alignment,
          WrapAlignment.spaceAround);
      expect((await wrapWith(tester, alignment: 'space-evenly')).alignment,
          WrapAlignment.spaceEvenly);
      expect((await wrapWith(tester, alignment: 'spaceEvenly')).alignment,
          WrapAlignment.spaceEvenly);
      expect((await wrapWith(tester, alignment: 'nonsense')).alignment,
          WrapAlignment.start);
    });

    testWidgets('the cross-axis rule is read too', (tester) async {
      expect(
          (await wrapWith(tester, crossAlignment: 'start')).crossAxisAlignment,
          WrapCrossAlignment.start);
      expect((await wrapWith(tester, crossAlignment: 'end')).crossAxisAlignment,
          WrapCrossAlignment.end);
      expect(
          (await wrapWith(tester, crossAlignment: 'center'))
              .crossAxisAlignment,
          WrapCrossAlignment.center);
      expect(
          (await wrapWith(tester, crossAlignment: 'stretch'))
              .crossAxisAlignment,
          WrapCrossAlignment.start,
          reason: 'a wrap has no stretch; falling back is the honest answer');
    });
  });

  group('canvas', () {
    Future<Painted> shot(WidgetTester tester) async {
      late Painted painted;
      await tester.runAsync(() async {
        painted = await paintedOf(tester, find.byKey(probeKey));
      });
      return painted;
    }

    Map<String, dynamic> canvas(List<dynamic> commands) => <String, dynamic>{
          'type': 'canvas',
          'width': 300,
          'height': 200,
          'commands': commands,
        };

    testWidgets('a stroked rectangle paints its outline', (tester) async {
      await pump(tester, canvas(<dynamic>[
        <String, dynamic>{
          'op': 'rect',
          'x': 20,
          'y': 20,
          'width': 100,
          'height': 60,
          'stroke': '#FF0000',
          'strokeWidth': 4,
        },
      ]));

      expect((await shot(tester)).count(const Color(0xFFFF0000)),
          greaterThan(0),
          reason: 'a stroke-only shape that paints nothing is a drawing '
              'command the document wrote and the canvas ignored');
    });

    testWidgets('a stroked rounded rectangle paints too', (tester) async {
      await pump(tester, canvas(<dynamic>[
        <String, dynamic>{
          'op': 'rect',
          'x': 20,
          'y': 20,
          'width': 100,
          'height': 60,
          'cornerRadius': 12,
          'stroke': '#00FF00',
          'strokeWidth': 4,
        },
      ]));

      expect((await shot(tester)).count(const Color(0xFF00FF00)),
          greaterThan(0));
    });

    testWidgets('a filled rounded rectangle paints its fill', (tester) async {
      await pump(tester, canvas(<dynamic>[
        <String, dynamic>{
          'op': 'rect',
          'x': 20,
          'y': 20,
          'width': 100,
          'height': 60,
          'cornerRadius': 12,
          'fill': '#0000FF',
        },
      ]));

      expect((await shot(tester)).count(const Color(0xFF0000FF)),
          greaterThan(1000));
    });

    testWidgets('a path with curves is drawn', (tester) async {
      await pump(tester, canvas(<dynamic>[
        <String, dynamic>{
          'op': 'path',
          'd': 'M 20 100 C 60 20 140 20 180 100 Q 200 140 240 100 Z',
          'stroke': '#FF00FF',
          'strokeWidth': 3,
        },
      ]));

      expect((await shot(tester)).count(const Color(0xFFFF00FF)),
          greaterThan(0),
          reason: 'cubic and quadratic segments are the two curve commands a '
              'path can carry; skipping them straightens the drawing');
    });

    testWidgets('an eight-digit colour keeps its alpha', (tester) async {
      await pump(tester, canvas(<dynamic>[
        <String, dynamic>{
          'op': 'rect',
          'x': 0,
          'y': 0,
          'width': 100,
          'height': 100,
          'fill': '#80FF0000',
        },
      ]));

      final painted = await shot(tester);
      expect(painted.count(const Color(0xFFFF0000)), 0,
          reason: 'the declared alpha is half; painting it opaque is a '
              'different colour entirely');
      expect(painted.nonBackground(), greaterThan(0));
    });

    testWidgets('a colour that is not hex is left undrawn', (tester) async {
      await pump(tester, canvas(<dynamic>[
        <String, dynamic>{
          'op': 'rect',
          'x': 0,
          'y': 0,
          'width': 100,
          'height': 100,
          'fill': 'crimson',
        },
      ]));

      expect(tester.takeException(), isNull);
    });
  });
}
