// `barcode` — the widget around the encoder.
//
// The encoder has its own tests; what had none is the widget that chooses
// which encoder to run. §10.24 names eight formats, and the name is the whole
// of what an author can say: a `format` that falls through to the default
// encodes the same payload under a different symbology, and the label under
// it still reads correctly. The scanner is the only thing that would ever
// find out.

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

  Future<void> pump(WidgetTester tester, Map<String, dynamic> definition) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: context.renderer.renderWidget(definition, context),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// The bars themselves — a `CustomPaint` driven by the barcode painter,
  /// picked out from the ones the surrounding Material draws.
  final bars = find.byWidgetPredicate(
      (w) => w is CustomPaint && '${w.painter}'.contains('BarcodePainter'));

  /// The natural width of the symbol, which is one pixel per module — so this
  /// reads back the module count the chosen encoder produced.
  double moduleWidth(WidgetTester tester) => tester.getSize(bars).width;

  group('the declared format is the one encoded', () {
    // One payload per format that each format accepts, and the module count
    // each symbology is defined to produce.
    const cases = <String, List<Object>>{
      'ean13': ['5901234123457', 95],
      'ean8': ['96385074', 67],
      'upcA': ['036000291452', 95],
    };

    cases.forEach((format, expected) {
      testWidgets('$format encodes to its own module count', (tester) async {
        await pump(tester, <String, dynamic>{
          'type': 'barcode',
          'format': format,
          'value': expected.first,
        });

        expect(moduleWidth(tester), expected.last,
            reason: 'a format name that falls through to the default encodes '
                'the payload under a different symbology; the label under it '
                'still reads correctly, so only a scanner would find out');
      });
    });

    testWidgets('the same payload under two formats is two different symbols',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'barcode',
        'format': 'itf',
        'value': '1234',
      });
      final itf = moduleWidth(tester);

      await pump(tester, <String, dynamic>{
        'type': 'barcode',
        'format': 'code128',
        'value': '1234',
      });

      expect(moduleWidth(tester), isNot(itf),
          reason: 'two symbologies over one payload cannot produce the same '
              'bars');
    });

    testWidgets('codabar and code39 are each their own', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'barcode',
        'format': 'codabar',
        'value': 'A1234A',
      });
      final codabar = moduleWidth(tester);

      await pump(tester, <String, dynamic>{
        'type': 'barcode',
        'format': 'code39',
        'value': '1234',
      });

      expect(moduleWidth(tester), isNot(codabar));
    });

    testWidgets('a format nobody declared falls back rather than failing',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'barcode',
        'format': 'aztec',
        'value': 'ABC123',
      });

      expect(tester.takeException(), isNull);
      expect(bars, findsOneWidget,
          reason: 'an unknown symbology is an authoring mistake, not a reason '
              'to leave a blank where a label belongs');
    });
  });

  group('what the widget shows around the bars', () {
    testWidgets('the payload is printed under the symbol, and can be hidden',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'barcode',
        'value': 'SHIP-9912',
      });
      expect(find.text('SHIP-9912'), findsOneWidget,
          reason: 'the printed number is what a human reads when the scanner '
              'will not take it');

      await pump(tester, <String, dynamic>{
        'type': 'barcode',
        'value': 'SHIP-9912',
        'displayValue': false,
      });
      expect(find.text('SHIP-9912'), findsNothing);
    });

    testWidgets('a payload the format refuses is reported, never drawn wrong',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'barcode',
        'format': 'ean13',
        'value': 'not-a-number',
      });

      expect(bars, findsNothing,
          reason: 'a barcode that scans as the wrong number is worse than one '
              'that does not render');
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('an empty value takes its declared height and draws nothing',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'barcode',
        'value': '',
        'height': 64,
      });

      expect(bars, findsNothing);
      expect(
          tester.getSize(find.byWidgetPredicate(
              (w) => w is SizedBox && w.height == 64)).height,
          64,
          reason: 'a label bound to a value that has not arrived must not '
              'collapse the layout under it');
    });

    testWidgets('a declared width overrides the intrinsic one', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'barcode',
        'format': 'ean13',
        'value': '5901234123457',
        'width': 240,
      });

      expect(moduleWidth(tester), 240);
    });
  });
}
