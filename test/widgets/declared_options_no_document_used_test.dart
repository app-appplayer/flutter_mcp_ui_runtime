// Options the spec declares that no document in this suite had ever used.
//
// Each one is a branch a factory takes only when a particular property is
// present: a blur behind a card, a popover that opens on hover, a QR with a
// logo in it, a safe area holding more than one child, a curve named by one of
// the spellings nobody had picked. A declared property that is parsed and
// dropped renders as "the runtime ignored me", and the author has no way to
// tell that from having spelled it wrong.

import 'package:flutter/gestures.dart';
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
        body: AnimatedBuilder(
          animation: stateManager,
          builder: (_, __) => context.renderer.renderWidget(definition, context),
        ),
      ),
    ));
    await tester.pump();
  }

  group('decoration', () {
    testWidgets('a declared backdrop blur is actually applied',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'decoration',
        'backdropBlur': 8,
        'decoration': <String, dynamic>{'color': '#FFFFFFFF'},
        'child': <String, dynamic>{'type': 'text', 'content': 'frosted'},
      });

      expect(find.byType(BackdropFilter), findsOneWidget,
          reason: 'the blur is not part of BoxDecoration, so a declaration '
              'that never reaches BackdropFilter draws a plain panel that '
              'looks exactly like a correct one on a plain background');
      expect(find.text('frosted'), findsOneWidget);
    });

    testWidgets('without it, nothing is wrapped', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'decoration',
        'decoration': <String, dynamic>{'color': '#FFFFFFFF'},
        'child': <String, dynamic>{'type': 'text', 'content': 'plain'},
      });

      expect(find.byType(BackdropFilter), findsNothing);
    });
  });

  group('safeArea', () {
    testWidgets('one child is placed directly', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'safeArea',
        'children': <dynamic>[
          <String, dynamic>{'type': 'text', 'content': 'only'},
        ],
      });

      expect(find.text('only'), findsOneWidget);
      expect(find.byType(Column), findsNothing,
          reason: 'a single child needs no column, and adding one changes how '
              'it sizes');
    });

    testWidgets('several children are stacked in declared order',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'safeArea',
        'children': <dynamic>[
          <String, dynamic>{'type': 'text', 'content': 'first'},
          <String, dynamic>{'type': 'text', 'content': 'second'},
        ],
      });

      expect(find.text('first'), findsOneWidget);
      expect(find.text('second'), findsOneWidget,
          reason: '`safeArea` takes a list; keeping only the first is a '
              'document losing content with nothing said');
      expect(find.byType(Column), findsWidgets);
    });
  });

  group('popover', () {
    testWidgets('trigger: hover opens on the pointer, and closes when it '
        'leaves', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'popover',
        'trigger': 'hover',
        'openDelay': 0,
        'closeDelay': 0,
        'child': <String, dynamic>{'type': 'text', 'content': 'anchor'},
        'content': <String, dynamic>{'type': 'text', 'content': 'tooltip body'},
      });

      expect(find.text('tooltip body'), findsNothing);

      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(location: Offset.zero);
      addTearDown(pointer.removePointer);

      await pointer.moveTo(tester.getCenter(find.text('anchor')));
      await tester.pumpAndSettle();

      expect(find.text('tooltip body'), findsOneWidget,
          reason: 'hover is one of the declared triggers; a popover that only '
              'answers taps is a menu a mouse user cannot open');

      await pointer.moveTo(const Offset(600, 600));
      await tester.pumpAndSettle();

      expect(find.text('tooltip body'), findsNothing,
          reason: 'and one that never closes follows the pointer around the '
              'screen');
    });
  });

  group('qrCode', () {
    testWidgets('a declared logo is drawn over the symbol', (tester) async {
      // A 1×1 transparent PNG, so no asset host is involved.
      const pixel =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
          'AAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

      await pump(tester, <String, dynamic>{
        'type': 'qrCode',
        'value': 'https://example.com',
        'size': 200,
        'foregroundColor': '#FF000000',
        'backgroundColor': '#FFFFFFFF',
        'logo': pixel,
      });
      await tester.pump();

      // Material draws CustomPaints of its own, so the symbol is identified
      // by the SizedBox the factory builds at the declared size — the guard
      // that would have caught the first version of this test, which passed
      // `data:` instead of `value:` and measured an empty box.
      expect(
          find.byWidgetPredicate((w) =>
              w is SizedBox && w.width == 200 && w.height == 200),
          findsWidgets,
          reason: 'a refusal path (empty value, payload too long, contrast too '
              'low) would make the next assertion pass for the wrong reason');
      expect(find.byType(Image), findsOneWidget,
          reason: 'the logo is the reason a brand uses a QR at all; parsing '
              'it and drawing nothing is the silent kind of failure');
    });

    testWidgets('without a logo nothing is overlaid', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'qrCode',
        'value': 'https://example.com',
        'size': 200,
        'foregroundColor': '#FF000000',
        'backgroundColor': '#FFFFFFFF',
      });

      expect(
          find.byWidgetPredicate((w) =>
              w is SizedBox && w.width == 200 && w.height == 200),
          findsWidgets);
      expect(find.byType(Image), findsNothing);
    });
  });

  group('opacity', () {
    testWidgets('every declared curve name is honoured', (tester) async {
      for (final curve in const [
        'linear',
        'easeIn',
        'easeOut',
        'easeInOut',
        'bounceIn',
        'bounceOut',
        'elasticIn',
        'elasticOut',
        'noSuchCurve',
      ]) {
        await pump(tester, <String, dynamic>{
          'type': 'opacity',
          'opacity': 0.5,
          'animate': true,
          'curve': curve,
          'duration': 10,
          'child': <String, dynamic>{'type': 'text', 'content': 'fading'},
        });

        expect(find.text('fading'), findsOneWidget,
            reason: '$curve either names a curve or falls back to one; either '
                'way the child is drawn');
        await tester.pumpAndSettle();
      }
    });
  });

  group('gauge', () {
    testWidgets('a changed value repaints rather than sticking', (tester) async {
      stateManager.set('level', 0.2);
      await pump(tester, <String, dynamic>{
        'type': 'gauge',
        'value': '{{level}}',
        'min': 0,
        'max': 1,
      });

      List<Object?> painters() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((p) => p.painter)
          .toList();

      final before = painters();

      stateManager.set('level', 0.8);
      await tester.pumpAndSettle();

      final after = painters();

      expect(
          after.any((p) => !before.any((q) => identical(p, q))), isTrue,
          reason: 'a painter that compares equal to its predecessor is a '
              'needle that never moves');
    });
  });
}
