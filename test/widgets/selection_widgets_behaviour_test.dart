// Four widgets whose *declared* appearance had never been read back:
// `tooltip` (46%), `chip` (51%), `segmentedControl` (48%) and `rangeSlider`
// (43%).
//
// The pattern in all four is the same. Each takes a pile of presentation
// properties, hands them to a Material widget, and returns. A test that only
// asks "is there a Chip on screen?" passes whether or not a single one of those
// properties survived the trip — which is exactly how a document can declare an
// outlined variant, a delete icon and a background colour and get a plain grey
// pill. So each property is read back off the built widget, and every
// interactive one is driven.

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
          child: AnimatedBuilder(
            animation: stateManager,
            builder: (_, __) =>
                context.renderer.renderWidget(definition, context),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('tooltip', () {
    testWidgets('wraps its child and carries the message', (tester) async {
      await pump(tester, {
        'type': 'tooltip',
        'message': 'Sends the report',
        'child': {'type': 'text', 'content': 'Send'},
      });

      expect(find.text('Send'), findsOneWidget);
      expect(tester.widget<Tooltip>(find.byType(Tooltip)).message,
          'Sends the report');
    });

    testWidgets('the message is shown on a long press', (tester) async {
      await pump(tester, {
        'type': 'tooltip',
        'message': 'Sends the report',
        'child': {'type': 'text', 'content': 'Send'},
      });

      await tester.longPress(find.text('Send'));
      await tester.pumpAndSettle();

      expect(find.text('Sends the report'), findsOneWidget,
          reason: 'a tooltip that never appears is a comment in the document');
    });

    testWidgets('with no child it still has something to hang off',
        (tester) async {
      await pump(tester, {'type': 'tooltip', 'message': 'Help'});

      expect(find.byIcon(Icons.info), findsOneWidget,
          reason: 'an invisible tooltip cannot be triggered by anyone');
    });

    testWidgets('the message is resolved from state', (tester) async {
      stateManager.set('hint', 'Requires a signature');
      await pump(tester, {
        'type': 'tooltip',
        'message': '{{hint}}',
        'child': {'type': 'text', 'content': 'Sign'},
      });

      expect(
          tester.widget<Tooltip>(find.byType(Tooltip)).message, 'Requires a signature');
    });

    testWidgets('a richMessage replaces the plain one', (tester) async {
      await pump(tester, {
        'type': 'tooltip',
        'message': 'ignored',
        'richMessage': {
          'text': 'Bold ',
          'style': {'fontWeight': 'bold', 'color': '#FF0000', 'fontSize': 18},
          'children': [
            {'text': 'and plain'},
          ],
        },
        'child': {'type': 'text', 'content': 'Info'},
      });

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, isNull,
          reason: 'Tooltip asserts that at most one of message/richMessage is '
              'given — an empty string counts as given, and the whole tooltip '
              'failed to build');
      final span = tooltip.richMessage! as TextSpan;
      expect(span.text, 'Bold ');
      expect(span.style!.fontWeight, FontWeight.bold);
      expect(span.style!.color, const Color(0xFFFF0000));
      expect((span.children!.single as TextSpan).text, 'and plain',
          reason: 'a rich message that drops its children shows half the '
              'sentence');
    });

    testWidgets('layout and timing properties are all applied', (tester) async {
      await pump(tester, {
        'type': 'tooltip',
        'message': 'Help',
        'height': 40,
        'padding': 6,
        'margin': 4,
        'verticalOffset': 18,
        'preferBelow': false,
        'excludeFromSemantics': true,
        'waitDuration': 300,
        'showDuration': 900,
        'enableFeedback': false,
        'textAlign': 'center',
        'child': {'type': 'text', 'content': 'Send'},
      });

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.constraints, const BoxConstraints(minHeight: 40));
      expect(tooltip.padding, const EdgeInsets.all(6));
      expect(tooltip.margin, const EdgeInsets.all(4));
      expect(tooltip.verticalOffset, 18);
      expect(tooltip.preferBelow, isFalse);
      expect(tooltip.excludeFromSemantics, isTrue);
      expect(tooltip.waitDuration, const Duration(milliseconds: 300));
      expect(tooltip.showDuration, const Duration(milliseconds: 900));
      expect(tooltip.enableFeedback, isFalse);
      expect(tooltip.textAlign, TextAlign.center);
    });

    testWidgets('every textAlign spelling is read', (tester) async {
      for (final entry in const {
        'left': TextAlign.left,
        'right': TextAlign.right,
        'center': TextAlign.center,
        'justify': TextAlign.justify,
        'start': TextAlign.start,
        'end': TextAlign.end,
      }.entries) {
        await pump(tester, {
          'type': 'tooltip',
          'message': 'Help',
          'textAlign': entry.key,
          'child': {'type': 'text', 'content': 'Send'},
        });
        expect(tester.widget<Tooltip>(find.byType(Tooltip)).textAlign,
            entry.value,
            reason: 'textAlign "${entry.key}"');
      }
    });

    testWidgets('an unknown textAlign leaves the default in place',
        (tester) async {
      await pump(tester, {
        'type': 'tooltip',
        'message': 'Help',
        'textAlign': 'sideways',
        'child': {'type': 'text', 'content': 'Send'},
      });

      expect(tester.widget<Tooltip>(find.byType(Tooltip)).textAlign, isNull);
    });

    testWidgets('every triggerMode spelling is read', (tester) async {
      for (final entry in const {
        'longPress': TooltipTriggerMode.longPress,
        'tap': TooltipTriggerMode.tap,
        'manual': TooltipTriggerMode.manual,
      }.entries) {
        await pump(tester, {
          'type': 'tooltip',
          'message': 'Help',
          'triggerMode': entry.key,
          'child': {'type': 'text', 'content': 'Send'},
        });
        expect(tester.widget<Tooltip>(find.byType(Tooltip)).triggerMode,
            entry.value,
            reason: 'triggerMode "${entry.key}"');
      }
    });

    testWidgets('triggerMode tap opens on a tap', (tester) async {
      await pump(tester, {
        'type': 'tooltip',
        'message': 'Sends the report',
        'triggerMode': 'tap',
        'child': {'type': 'text', 'content': 'Send'},
      });

      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      expect(find.text('Sends the report'), findsOneWidget);
    });

    testWidgets('a decoration with a shadow is built', (tester) async {
      await pump(tester, {
        'type': 'tooltip',
        'message': 'Help',
        'decoration': {
          'color': '#202020',
          'borderRadius': 12,
          'shadow': {
            'color': '#000000',
            'blur': 6,
            'spread': 1,
            'offsetX': 2,
            'offsetY': 3,
          },
        },
        'child': {'type': 'text', 'content': 'Send'},
      });

      final decoration = tester.widget<Tooltip>(find.byType(Tooltip)).decoration!
          as BoxDecoration;
      expect(decoration.color, const Color(0xFF202020));
      expect(decoration.borderRadius, BorderRadius.circular(12));
      final shadow = decoration.boxShadow!.single;
      expect(shadow.blurRadius, 6);
      expect(shadow.spreadRadius, 1);
      expect(shadow.offset, const Offset(2, 3));
    });

    testWidgets('a decoration bound to state resolves through the binding',
        (tester) async {
      stateManager.set('tipStyle', {'color': '#123456'});
      await pump(tester, {
        'type': 'tooltip',
        'message': 'Help',
        'decoration': '{{tipStyle}}',
        'child': {'type': 'text', 'content': 'Send'},
      });

      final decoration = tester.widget<Tooltip>(find.byType(Tooltip)).decoration!
          as BoxDecoration;
      expect(decoration.color, const Color(0xFF123456));
    });

    testWidgets('a decoration binding that resolves to a scalar is ignored',
        (tester) async {
      stateManager.set('tipStyle', 'dark');
      await pump(tester, {
        'type': 'tooltip',
        'message': 'Help',
        'decoration': '{{tipStyle}}',
        'child': {'type': 'text', 'content': 'Send'},
      });

      expect(tester.widget<Tooltip>(find.byType(Tooltip)).decoration, isNull,
          reason: 'a half-loaded theme must fall back to the default tooltip, '
              'not fail the page');
    });
  });

  group('chip', () {
    testWidgets('shows its label and runs onTap', (tester) async {
      await pump(tester, {
        'type': 'chip',
        'label': 'Overdue',
        'onTap': {
          'type': 'state',
          'action': 'set',
          'binding': 'filter',
          'value': 'overdue',
        },
      });

      expect(find.text('Overdue'), findsOneWidget);
      await tester.tap(find.text('Overdue'));
      await tester.pumpAndSettle();
      expect(stateManager.get('filter'), 'overdue');
    });

    testWidgets('onDelete gives it a delete affordance that fires',
        (tester) async {
      await pump(tester, {
        'type': 'chip',
        'label': 'Overdue',
        'deleteIcon': 'close',
        'onDelete': {
          'type': 'state',
          'action': 'set',
          'binding': 'removed',
          'value': true,
        },
      });

      expect(find.byIcon(Icons.close), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(stateManager.get('removed'), isTrue,
          reason: 'a filter chip whose × does nothing traps the user in the '
              'filter they applied');
    });

    testWidgets('the legacy onDeleted spelling still works', (tester) async {
      await pump(tester, {
        'type': 'chip',
        'label': 'Overdue',
        'deleteIcon': 'close',
        'onDeleted': {
          'type': 'state',
          'action': 'set',
          'binding': 'removed',
          'value': true,
        },
      });

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(stateManager.get('removed'), isTrue);
    });

    testWidgets('no delete action means no delete affordance', (tester) async {
      await pump(tester, {'type': 'chip', 'label': 'Overdue'});

      expect(tester.widget<RawChip>(find.byType(RawChip)).onDeleted, isNull,
          reason: 'an × that does nothing is worse than no ×');
    });

    testWidgets('a text avatar shows its initial', (tester) async {
      await pump(tester, {
        'type': 'chip',
        'label': 'Ada Lovelace',
        'avatar': {'text': 'ada'},
      });

      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('an icon avatar shows the icon', (tester) async {
      await pump(tester, {
        'type': 'chip',
        'label': 'Home',
        'avatar': {'icon': 'home'},
      });

      expect(find.byIcon(Icons.home), findsOneWidget);
    });

    testWidgets('the outlined variant keeps a border and a clear background',
        (tester) async {
      await pump(tester, {
        'type': 'chip',
        'label': 'Overdue',
        'variant': 'outlined',
      });

      final chip = tester.widget<RawChip>(find.byType(RawChip));
      expect(chip.side, isNotNull,
          reason: 'outlined without an outline is the filled variant');
      expect(chip.backgroundColor, Colors.transparent);
    });

    testWidgets('the filled variant carries its declared colour',
        (tester) async {
      await pump(tester, {
        'type': 'chip',
        'label': 'Overdue',
        'backgroundColor': '#FF0000',
        'elevation': 4,
        'shadowColor': '#00FF00',
      });

      final chip = tester.widget<RawChip>(find.byType(RawChip));
      expect(chip.backgroundColor, const Color(0xFFFF0000));
      expect(chip.elevation, 4);
      expect(chip.shadowColor, const Color(0xFF00FF00));
    });

    testWidgets('selected is reflected on the built chip', (tester) async {
      await pump(tester, {
        'type': 'chip',
        'label': 'Overdue',
        'selected': true,
      });

      expect(tester.widget<RawChip>(find.byType(RawChip)).selected, isTrue,
          reason: 'a selected filter that looks unselected makes the result '
              'list read as wrong data');
    });

    testWidgets('selected is resolved from state, and follows it',
        (tester) async {
      stateManager.set('isOn', false);
      await pump(tester, {
        'type': 'chip',
        'label': 'Overdue',
        'selected': '{{isOn}}',
      });
      expect(tester.widget<RawChip>(find.byType(RawChip)).selected, isFalse);

      stateManager.set('isOn', true);
      await tester.pumpAndSettle();
      expect(tester.widget<RawChip>(find.byType(RawChip)).selected, isTrue);
    });

    testWidgets('padding and labelStyle are applied', (tester) async {
      await pump(tester, {
        'type': 'chip',
        'label': 'Overdue',
        'padding': 10,
        'labelStyle': {'color': '#0000FF', 'fontSize': 20},
      });

      final chip = tester.widget<RawChip>(find.byType(RawChip));
      expect(chip.padding, const EdgeInsets.all(10));
      expect(chip.labelStyle!.color, const Color(0xFF0000FF));
      expect(chip.labelStyle!.fontSize, 20);
    });
  });

  group('segmentedControl', () {
    Map<String, dynamic> control({String? variant, Object? extra}) => {
          'type': 'segmentedControl',
          'binding': 'view',
          'options': [
            {'value': 'day', 'label': 'Day'},
            {'value': 'week', 'label': 'Week'},
          ],
          if (variant != null) 'variant': variant,
          if (extra is Map<String, dynamic>) ...extra,
        };

    testWidgets('the default variant is a SegmentedButton and it selects',
        (tester) async {
      stateManager.set('view', 'day');
      await pump(tester, control());

      expect(find.byType(SegmentedButton<String>), findsOneWidget);
      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();

      expect(stateManager.get('view'), 'week');
    });

    testWidgets('with no value yet it draws instead of asserting',
        (tester) async {
      await pump(tester, control());

      final button =
          tester.widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>));
      expect(button.selected, isEmpty);
      expect(button.emptySelectionAllowed, isTrue,
          reason: '§2.6.0 does not require an initial value; asserting here '
              'takes the whole page down');
    });

    testWidgets('the tabs variant is a strip, and tapping one selects',
        (tester) async {
      stateManager.set('view', 'day');
      await pump(tester, control(variant: 'tabs'));

      expect(find.byType(SegmentedButton<String>), findsNothing,
          reason: 'a declared variant that renders as the default control '
              'means the declaration did nothing');
      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();
      expect(stateManager.get('view'), 'week');
    });

    testWidgets('the buttons variant marks the selection with a FilledButton',
        (tester) async {
      stateManager.set('view', 'day');
      await pump(tester, control(variant: 'buttons'));

      expect(find.widgetWithText(FilledButton, 'Day'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Week'), findsOneWidget);

      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();
      expect(stateManager.get('view'), 'week');
      expect(find.widgetWithText(FilledButton, 'Week'), findsOneWidget,
          reason: 'the highlight has to move with the selection');
    });

    testWidgets('disabled refuses every variant\'s taps', (tester) async {
      for (final variant in const ['segmented', 'tabs', 'buttons']) {
        stateManager.set('view', 'day');
        await pump(tester, control(variant: variant, extra: {'enabled': false}));

        await tester.tap(find.text('Week'), warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(stateManager.get('view'), 'day',
            reason: 'a disabled $variant control that still writes state is '
                'not disabled');
      }
    });

    testWidgets('plain string options are accepted', (tester) async {
      await pump(tester, {
        'type': 'segmentedControl',
        'binding': 'view',
        'options': ['day', 'week'],
      });

      await tester.tap(find.text('week'));
      await tester.pumpAndSettle();
      expect(stateManager.get('view'), 'week');
    });

    testWidgets('an option with a known icon renders the icon instead of text',
        (tester) async {
      await pump(tester, {
        'type': 'segmentedControl',
        'binding': 'align',
        'options': [
          {'value': 'left', 'icon': 'format_align_left', 'label': 'Left'},
          {'value': 'right', 'icon': 'format_align_right', 'label': 'Right'},
        ],
      });

      expect(find.byIcon(Icons.format_align_left), findsOneWidget);
      expect(find.text('Left'), findsNothing);
    });

    testWidgets('an unknown icon name falls back to the label', (tester) async {
      await pump(tester, {
        'type': 'segmentedControl',
        'binding': 'align',
        'options': [
          {'value': 'left', 'icon': 'no_such_icon', 'label': 'Left'},
        ],
      });

      expect(find.text('Left'), findsOneWidget,
          reason: 'a blank segment cannot be chosen from');
    });

    testWidgets('a label is drawn above the control', (tester) async {
      await pump(tester, control(extra: {'label': 'Range'}));

      expect(find.text('Range'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Range')).dy,
          lessThan(tester.getTopLeft(find.text('Day')).dy));
    });
  });

  group('rangeSlider', () {
    testWidgets('a bound {start, end} pair is read back', (tester) async {
      stateManager.set('price', {'start': 20.0, 'end': 60.0});
      await pump(tester, {
        'type': 'rangeSlider',
        'binding': 'price',
        'min': 0,
        'max': 100,
      });

      final slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
      expect(slider.values, const RangeValues(20, 60));
    });

    testWidgets('a two-element list is accepted as the same pair',
        (tester) async {
      await pump(tester, {
        'type': 'rangeSlider',
        'value': [10, 40],
        'min': 0,
        'max': 100,
      });

      expect(tester.widget<RangeSlider>(find.byType(RangeSlider)).values,
          const RangeValues(10, 40));
    });

    testWidgets('values outside min/max are clamped rather than asserting',
        (tester) async {
      await pump(tester, {
        'type': 'rangeSlider',
        'value': [-50, 500],
        'min': 0,
        'max': 100,
      });

      expect(tester.widget<RangeSlider>(find.byType(RangeSlider)).values,
          const RangeValues(0, 100),
          reason: 'stale state outside the current bounds is ordinary — a '
              'RangeSlider assertion would take the page down for it');
    });

    testWidgets('dragging writes {start, end} back to the binding',
        (tester) async {
      stateManager.set('price', {'start': 20.0, 'end': 60.0});
      await pump(tester, {
        'type': 'rangeSlider',
        'binding': 'price',
        'min': 0,
        'max': 100,
      });

      final box = tester.getRect(find.byType(RangeSlider));
      await tester.dragFrom(
        Offset(box.left + box.width * 0.6, box.center.dy),
        const Offset(60, 0),
      );
      await tester.pumpAndSettle();

      final written = stateManager.get<Map<String, dynamic>>('price')!;
      expect(written['end'], greaterThan(60.0),
          reason: 'two-way binding is what makes the filter the slider shows '
              'the filter the query uses');
      expect(written['start'], 20.0);
    });

    testWidgets('divisions and labels are applied', (tester) async {
      await pump(tester, {
        'type': 'rangeSlider',
        'value': [20, 60],
        'min': 0,
        'max': 100,
        'divisions': 10,
        'labels': ['low', 'high'],
        'activeColor': '#FF0000',
        'inactiveColor': '#00FF00',
      });

      final slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
      expect(slider.divisions, 10);
      expect(slider.labels, const RangeLabels('low', 'high'));
      expect(slider.activeColor, const Color(0xFFFF0000));
      expect(slider.inactiveColor, const Color(0xFF00FF00));
    });

    testWidgets('labels also accept the {start, end} object form',
        (tester) async {
      await pump(tester, {
        'type': 'rangeSlider',
        'value': [20, 60],
        'min': 0,
        'max': 100,
        'labels': {'start': 'from', 'end': 'to'},
      });

      expect(tester.widget<RangeSlider>(find.byType(RangeSlider)).labels,
          const RangeLabels('from', 'to'));
    });

    testWidgets('with neither a binding nor onChange the slider is inert',
        (tester) async {
      await pump(tester, {
        'type': 'rangeSlider',
        'value': [20, 60],
        'min': 0,
        'max': 100,
      });

      expect(tester.widget<RangeSlider>(find.byType(RangeSlider)).onChanged,
          isNull,
          reason: 'a slider that moves and writes nowhere reads as a control '
              'the user has already used');
    });

    testWidgets('onChangeStart and onChangeEnd fire around a drag',
        (tester) async {
      await pump(tester, {
        'type': 'rangeSlider',
        'binding': 'price',
        'min': 0,
        'max': 100,
        'onChangeStart': {
          'type': 'state',
          'action': 'set',
          'binding': 'dragging',
          'value': true,
        },
        'onChangeEnd': {
          'type': 'state',
          'action': 'set',
          'binding': 'dragging',
          'value': false,
        },
      });

      final box = tester.getRect(find.byType(RangeSlider));
      final gesture = await tester.startGesture(
          Offset(box.left + box.width * 0.2, box.center.dy));
      await tester.pump();
      expect(stateManager.get('dragging'), isTrue);

      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(stateManager.get('dragging'), isFalse,
          reason: 'a drag that never ends leaves the document believing the '
              'user is still holding the handle');
    });

    testWidgets('an onChange carrying {{event.value}} receives the pair',
        (tester) async {
      await pump(tester, {
        'type': 'rangeSlider',
        'binding': 'price',
        'min': 0,
        'max': 100,
        'onChange': {
          'type': 'state',
          'action': 'set',
          'binding': 'lastEvent',
          'value': '{{event.value}}',
        },
      });

      final box = tester.getRect(find.byType(RangeSlider));
      await tester.dragFrom(
        Offset(box.left + box.width * 0.2, box.center.dy),
        const Offset(30, 0),
      );
      await tester.pumpAndSettle();

      final event = stateManager.get<Map<String, dynamic>>('lastEvent')!;
      expect(event['start'], isA<double>());
      expect(event['end'], isA<double>());
    });
  });
}
