// The `dialog` widget — the surface a document declares inline, as opposed to
// the one an action opens.
//
// It was 38% covered, and a third of the file cannot be covered at all. The
// factory switches on `properties['type']` to choose between an alert, a
// simple chooser and a bare surface, but `extractProperties` builds the
// property map by copying the definition and REMOVING `type` — the widget type
// and the dialog kind are the same key. `properties['type']` is therefore
// always null, always falls through to `?? 'custom'`, and `_buildAlertDialog`
// and `_buildSimpleDialog` can never run from any document.
//
// Nothing is lost in capability: spec 1.4 names `alertDialog` and
// `simpleDialog` as their own widget types with their own factories, and those
// are the documented spelling. The two unreachable arms are left in place and
// recorded rather than deleted — removing them is a call for whoever owns the
// legacy shape, not for a test pass.

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
      home: AnimatedBuilder(
        animation: stateManager,
        builder: (_, __) => context.renderer.renderWidget(definition, context),
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('the custom surface — what `dialog` and `customDialog` build', () {
    testWidgets('wraps the first child in a Dialog', (tester) async {
      await pump(tester, {
        'type': 'dialog',
        'children': [
          {'type': 'text', 'content': 'anything at all'},
        ],
      });

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('anything at all'), findsOneWidget);
    });

    testWidgets('customDialog builds the same surface', (tester) async {
      await pump(tester, {
        'type': 'customDialog',
        'children': [
          {'type': 'text', 'content': 'anything at all'},
        ],
      });

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('anything at all'), findsOneWidget,
          reason: '§17 names customDialog; a document using the spec spelling '
              'must get what the alias gets');
    });

    testWidgets('with no children it is an empty surface', (tester) async {
      await pump(tester, {'type': 'dialog'});

      expect(find.byType(Dialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('backgroundColor and elevation are applied, not ignored',
        (tester) async {
      await pump(tester, {
        'type': 'dialog',
        'backgroundColor': '#FF00FF',
        'elevation': 12,
        'children': [
          {'type': 'text', 'content': 'body'},
        ],
      });

      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      expect(dialog.backgroundColor, const Color(0xFFFF00FF));
      expect(dialog.elevation, 12);
    });

    testWidgets('shadowColor and surfaceTintColor are applied', (tester) async {
      await pump(tester, {
        'type': 'dialog',
        'shadowColor': '#112233',
        'surfaceTintColor': '#445566',
        'children': [
          {'type': 'text', 'content': 'body'},
        ],
      });

      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      expect(dialog.shadowColor, const Color(0xFF112233));
      expect(dialog.surfaceTintColor, const Color(0xFF445566));
    });

    testWidgets('a rounded shape becomes a RoundedRectangleBorder',
        (tester) async {
      await pump(tester, {
        'type': 'dialog',
        'shape': {'type': 'rounded', 'radius': 24},
        'children': [
          {'type': 'text', 'content': 'body'},
        ],
      });

      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      final shape = dialog.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(24));
    });

    testWidgets('a rounded shape with no radius still rounds', (tester) async {
      await pump(tester, {
        'type': 'dialog',
        'shape': {'type': 'rounded'},
        'children': [
          {'type': 'text', 'content': 'body'},
        ],
      });

      final shape = tester.widget<Dialog>(find.byType(Dialog)).shape!
          as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(8));
    });

    testWidgets('a circle shape is honoured', (tester) async {
      await pump(tester, {
        'type': 'dialog',
        'shape': {'type': 'circle'},
        'children': [
          {'type': 'text', 'content': 'body'},
        ],
      });

      expect(tester.widget<Dialog>(find.byType(Dialog)).shape,
          isA<CircleBorder>());
    });

    testWidgets('an unknown shape falls back to the theme rather than failing',
        (tester) async {
      await pump(tester, {
        'type': 'dialog',
        'shape': {'type': 'hexagon'},
        'children': [
          {'type': 'text', 'content': 'body'},
        ],
      });

      expect(tester.widget<Dialog>(find.byType(Dialog)).shape, isNull);
    });

    testWidgets('every clipBehavior spelling is read', (tester) async {
      for (final entry in const {
        'none': Clip.none,
        'hardEdge': Clip.hardEdge,
        'antiAlias': Clip.antiAlias,
        'antiAliasWithSaveLayer': Clip.antiAliasWithSaveLayer,
        'nonsense': Clip.none,
      }.entries) {
        await pump(tester, {
          'type': 'dialog',
          'clipBehavior': entry.key,
          'children': [
            {'type': 'text', 'content': 'body'},
          ],
        });

        expect(tester.widget<Dialog>(find.byType(Dialog)).clipBehavior,
            entry.value,
            reason: 'clipBehavior "${entry.key}"');
      }
    });

    testWidgets('insetPadding and alignment are read', (tester) async {
      await pump(tester, {
        'type': 'dialog',
        'insetPadding': 8,
        'alignment': 'topLeft',
        'children': [
          {'type': 'text', 'content': 'body'},
        ],
      });

      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      expect(dialog.insetPadding, const EdgeInsets.all(8));
      expect(dialog.alignment, Alignment.topLeft);
    });

    testWidgets('with no insetPadding the surface keeps a margin',
        (tester) async {
      await pump(tester, {
        'type': 'dialog',
        'children': [
          {'type': 'text', 'content': 'body'},
        ],
      });

      expect(tester.widget<Dialog>(find.byType(Dialog)).insetPadding,
          const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
          reason: 'a dialog flush to the screen edge reads as a page, not a '
              'dialog');
    });
  });
}
