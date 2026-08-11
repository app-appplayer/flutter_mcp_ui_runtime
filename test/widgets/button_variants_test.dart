// `button` — every variant, and the states that stop it firing.
//
// 65% covered. The uncovered part was the variant switch (five different
// Material widgets from one `variant` string), the disabled / loading gates,
// the icon layout, and the semantic label. A button that renders as the wrong
// variant is a visual bug; a button that stays enabled while `loading` is a
// double-submit, and one whose `ariaLabel` never reaches the semantics tree is
// unusable with a screen reader.

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
        body: context.renderer.renderWidget(definition, context),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> button({Map<String, dynamic> extra = const {}}) => {
        'type': 'button',
        'label': 'Save',
        'onTap': {
          'type': 'state',
          'action': 'increment',
          'binding': 'taps',
        },
        ...extra,
      };

  group('variants', () {
    testWidgets('each name builds its own Material button', (tester) async {
      const expected = {
        'elevated': ElevatedButton,
        'filled': FilledButton,
        'outlined': OutlinedButton,
        'text': TextButton,
      };

      for (final entry in expected.entries) {
        await pump(tester, button(extra: {'variant': entry.key}));
        expect(find.byType(entry.value), findsOneWidget,
            reason: '${entry.key} must build a ${entry.value} — a variant that '
                'silently falls through renders a different affordance than '
                'the document asked for');
        expect(find.text('Save'), findsOneWidget);
      }
    });

    testWidgets('the icon variant builds an IconButton with a tooltip',
        (tester) async {
      await pump(tester, button(extra: {'variant': 'icon', 'icon': 'save'}));

      expect(find.byType(IconButton), findsOneWidget);
      expect(find.byIcon(Icons.save), findsOneWidget);
      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.tooltip, 'Save',
          reason: 'an icon-only button with no tooltip is a mystery glyph — '
              'the label is what a screen reader and a hover both read');
    });

    testWidgets('the icon variant without an icon falls back to a labelled '
        'button', (tester) async {
      await pump(tester, button(extra: {'variant': 'icon'}));

      expect(find.byType(IconButton), findsNothing);
      expect(find.text('Save'), findsOneWidget,
          reason: 'dropping the button entirely because its icon is missing '
              'would remove the action from the page');
    });

    testWidgets('an unknown variant still builds something pressable',
        (tester) async {
      await pump(tester, button(extra: {'variant': 'holographic'}));

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(stateManager.get('taps'), 1,
          reason: 'a newer document opened on an older runtime must keep its '
              'buttons working');
    });

    testWidgets('the legacy `style` spelling selects the variant too',
        (tester) async {
      await pump(tester, button(extra: {'style': 'outlined'}));
      expect(find.byType(OutlinedButton), findsOneWidget);
    });
  });

  group('what stops it firing', () {
    testWidgets('a tap runs the action', (tester) async {
      await pump(tester, button());
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(stateManager.get('taps'), 1);
    });

    testWidgets('disabled is not pressable', (tester) async {
      await pump(tester, button(extra: {'disabled': true}));

      final widget = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(widget.onPressed, isNull);

      await tester.tap(find.text('Save'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(stateManager.get('taps'), isNull);
    });

    testWidgets('enabled: false is the same thing said the other way',
        (tester) async {
      await pump(tester, button(extra: {'enabled': false}));
      expect(
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNull);
    });

    testWidgets('loading shows a spinner and refuses the tap', (tester) async {
      // Bounded pumps: the spinner animates forever, so `pumpAndSettle` never
      // returns for a loading button.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: context.renderer
              .renderWidget(button(extra: {'loading': true}), context),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final widget = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(widget.onPressed, isNull,
          reason: 'a button that is still pressable while its request is in '
              'flight is a double submit — the spinner is not the guard, the '
              'null handler is');
    });

    testWidgets('a button with no action is still enabled', (tester) async {
      await pump(tester, {'type': 'button', 'label': 'Inert'});

      final widget = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(widget.onPressed, isNotNull,
          reason: 'greying out a button that declared no action would make an '
              'ordinary placeholder look broken');

      await tester.tap(find.text('Inert'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('the other gestures', () {
    testWidgets('long press and double tap each reach their own action',
        (tester) async {
      await pump(tester, button(extra: {
        'onLongPress': {
          'type': 'state',
          'action': 'increment',
          'binding': 'holds',
        },
        'onDoubleTap': {
          'type': 'state',
          'action': 'increment',
          'binding': 'doubles',
        },
      }));
      stateManager.set('holds', 0);
      stateManager.set('doubles', 0);

      await tester.longPress(find.text('Save'));
      await tester.pumpAndSettle();
      expect(stateManager.get('holds'), 1);

      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(stateManager.get('doubles'), 1);
    });
  });

  group('appearance', () {
    testWidgets('an icon is placed before or after the label as declared',
        (tester) async {
      await pump(tester, button(extra: {'icon': 'save'}));
      final iconFirst = tester.getTopLeft(find.byIcon(Icons.save)).dx <
          tester.getTopLeft(find.text('Save')).dx;
      expect(iconFirst, isTrue, reason: 'the default is a leading icon');

      // The schema says `start` or `end` — `right` is not a value, and the
      // factory treats anything that is not `end` as leading. Pinned so a
      // document using the wrong word does not silently get the other side.
      await pump(
          tester, button(extra: {'icon': 'save', 'iconPosition': 'end'}));
      expect(
        tester.getTopLeft(find.byIcon(Icons.save)).dx >
            tester.getTopLeft(find.text('Save')).dx,
        isTrue,
        reason: 'a trailing icon that renders leading reads as a different '
            'control — "next →" becomes "← next"',
      );
    });

    testWidgets('fullWidth stretches it across the parent', (tester) async {
      await pump(tester, button(extra: {'fullWidth': true}));
      final width = tester.getSize(find.byType(ElevatedButton)).width;

      await pump(tester, button());
      final natural = tester.getSize(find.byType(ElevatedButton)).width;

      expect(width, greaterThan(natural));
    });

    testWidgets('the declared colours and border reach the style',
        (tester) async {
      await pump(tester, button(extra: {
        'backgroundColor': '#FF0000',
        'foregroundColor': '#FFFFFF',
        'borderColor': '#00FF00',
        'borderWidth': 3,
        'elevation': 8,
      }));

      final style =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).style!;
      const pressed = <WidgetState>{};
      expect(style.backgroundColor?.resolve(pressed), isNotNull);
      expect(style.foregroundColor?.resolve(pressed), isNotNull);
      expect(style.elevation?.resolve(pressed), 8);
      expect(style.side?.resolve(pressed)?.width, 3);
    });

    testWidgets('size changes the padding', (tester) async {
      await pump(tester, button(extra: {'size': 'small'}));
      final small = tester.getSize(find.byType(ElevatedButton));

      await pump(tester, button(extra: {'size': 'large'}));
      final large = tester.getSize(find.byType(ElevatedButton));

      expect(large.height, greaterThan(small.height),
          reason: 'a size that changes nothing makes the property decorative');
    });

    testWidgets('ariaLabel overrides what a screen reader announces',
        (tester) async {
      await pump(tester, button(extra: {'ariaLabel': 'Save the document'}));

      final labelled = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((w) => w.properties.label == 'Save the document')
          .toList();
      expect(labelled, isNotEmpty,
          reason: 'a button labelled "Save" three times on one page needs '
              'each one to say what it saves');
      expect(labelled.first.properties.button, isTrue);
      expect(find.byType(ExcludeSemantics), findsWidgets,
          reason: 'the inner label is excluded, or the reader announces both');
    });
  });
}
