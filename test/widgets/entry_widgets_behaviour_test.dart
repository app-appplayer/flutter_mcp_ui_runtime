// `otpInput`, `dateTimePicker`, `dateRangePicker`, `tooltip` and
// `popupMenuButton` — five widgets between 30% and 55% covered.
//
// What they share is that the uncovered part is the interaction: the OTP cell
// that has to redistribute a pasted code, the picker that has to reassemble a
// date and a time into one instant, the menu whose items carry the values a
// document acts on. All of them render fine while doing none of that, which is
// why the widget tree is the wrong thing to assert on.

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
    await tester.pumpAndSettle();
  }

  group('otpInput', () {
    Map<String, dynamic> otp({Map<String, dynamic> extra = const {}}) => {
          'type': 'otpInput',
          'binding': 'code',
          'length': 4,
          ...extra,
        };

    testWidgets('one cell per declared digit', (tester) async {
      await pump(tester, otp());
      expect(find.byType(TextField), findsNWidgets(4));
    });

    testWidgets('a six-digit code gets six cells', (tester) async {
      // A separate test rather than a second pump: the cell controllers are
      // built once per State, so re-pumping a different length into the same
      // position keeps the old row.
      await pump(tester, otp(extra: {'length': 6}));
      expect(find.byType(TextField), findsNWidgets(6));
    });

    testWidgets('typing a digit advances and the joined value is written',
        (tester) async {
      await pump(tester, otp());

      await tester.enterText(find.byType(TextField).at(0), '1');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '2');
      await tester.pumpAndSettle();

      expect(stateManager.get('code'), '12',
          reason: 'the binding carries the whole code — per-cell state would '
              'leave a document assembling it itself');
    });

    testWidgets('each cell holds exactly one character', (tester) async {
      // The redistribution path (a platform paste delivering the whole code to
      // one cell) cannot be driven from here: every cell carries
      // `maxLength: 1`, so `enterText` is truncated by the formatter before
      // the handler sees it. What IS reachable is the invariant that makes the
      // row readable — one character per box.
      await pump(tester, otp());

      await tester.enterText(find.byType(TextField).at(0), '9137');
      await tester.pumpAndSettle();

      final cells = tester
          .widgetList<TextField>(find.byType(TextField))
          .map((f) => f.controller!.text)
          .toList();
      expect(cells.every((c) => c.length <= 1), isTrue);
      expect(cells.first, '9');
    });

    testWidgets('onComplete fires once the last cell is filled',
        (tester) async {
      await pump(tester, otp(extra: {
        'onComplete': {
          'type': 'state',
          'action': 'set',
          'binding': 'submitted',
          'value': '{{event.value}}',
        },
      }));

      for (var i = 0; i < 3; i++) {
        await tester.enterText(find.byType(TextField).at(i), '${i + 1}');
        await tester.pumpAndSettle();
      }
      expect(stateManager.get('submitted'), isNull,
          reason: 'submitting a partial code would fail the verification the '
              'user has not finished entering');

      await tester.enterText(find.byType(TextField).at(3), '4');
      await tester.pumpAndSettle();
      expect(stateManager.get('submitted'), '1234',
          reason: 'the common case needs no separate button');
    });

    testWidgets('onChange fires for every keystroke', (tester) async {
      await pump(tester, otp(extra: {
        'onChange': {
          'type': 'state',
          'action': 'append',
          'binding': 'seen',
          'value': '{{event.value}}',
        },
      }));
      stateManager.set('seen', <dynamic>[]);

      await tester.enterText(find.byType(TextField).at(0), '1');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '2');
      await tester.pumpAndSettle();

      expect(stateManager.get('seen'), ['1', '12']);
    });

    testWidgets('masked hides the digits', (tester) async {
      await pump(tester, otp(extra: {'masked': true}));
      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.obscureText, isTrue);
    });

    testWidgets('a numeric field refuses letters, alphanumeric accepts them',
        (tester) async {
      await pump(tester, otp());
      await tester.enterText(find.byType(TextField).at(0), 'a');
      await tester.pumpAndSettle();
      expect(stateManager.get('code'), anyOf(isNull, ''),
          reason: 'a numeric code field that accepts letters sends a value '
              'the server will reject');

      await pump(tester, otp(extra: {'inputType': 'alphanumeric'}));
      await tester.enterText(find.byType(TextField).at(0), 'a');
      await tester.pumpAndSettle();
      expect(stateManager.get('code'), 'a');
    });

    testWidgets('an existing value fills the cells', (tester) async {
      stateManager.set('code', '42');
      await pump(tester, otp());

      final cells = tester
          .widgetList<TextField>(find.byType(TextField))
          .map((f) => f.controller!.text)
          .toList();
      expect(cells, ['4', '2', '', '']);
    });

    testWidgets('a disabled field takes no input', (tester) async {
      await pump(tester, otp(extra: {'enabled': false}));
      expect(tester.widget<TextField>(find.byType(TextField).first).enabled,
          isFalse);
    });
  });

  group('dateTimePicker', () {
    Map<String, dynamic> picker({Map<String, dynamic> extra = const {}}) => {
          'type': 'dateTimePicker',
          'binding': 'when',
          ...extra,
        };

    testWidgets('an existing value is shown formatted', (tester) async {
      stateManager.set('when', '2026-08-09T14:30:00');
      await pump(tester, picker());

      expect(find.textContaining('2026'), findsOneWidget,
          reason: 'an ISO string shown raw is not a date a person reads');
      expect(find.textContaining('14'), findsOneWidget);
    });

    testWidgets('an empty binding shows an empty field, not a placeholder '
        'date', (tester) async {
      await pump(tester, picker(extra: {'label': 'When'}));

      expect(find.text('When'), findsOneWidget);
      expect(find.textContaining('20'), findsNothing,
          reason: 'defaulting to today would submit a date the user never '
              'chose');
    });

    testWidgets('picking a date and a time writes one instant', (tester) async {
      await pump(tester, picker());

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      // The time picker follows immediately — the pair is one decision.
      expect(find.byType(TimePickerDialog), findsOneWidget,
          reason: 'a dateTime picker that stops after the date leaves the '
              'time at whatever it was');

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final written = stateManager.get<String>('when');
      expect(written, isNotNull);
      expect(DateTime.tryParse(written!), isNotNull,
          reason: 'the value is an ISO instant, which is what a server can '
              'read back');
    });

    testWidgets('cancelling the date picker writes nothing', (tester) async {
      await pump(tester, picker());

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(stateManager.get('when'), isNull);
      expect(find.byType(TimePickerDialog), findsNothing,
          reason: 'a cancelled date must not drag the user into choosing a '
              'time for it');
    });

    testWidgets('a disabled picker does not open', (tester) async {
      await pump(tester, picker(extra: {'enabled': false}));

      await tester.tap(find.byType(InkWell), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing);
    });
  });

  group('tooltip', () {
    testWidgets('the message appears on a long press and names the child',
        (tester) async {
      await pump(tester, {
        'type': 'tooltip',
        'message': 'Saves without closing',
        'child': {'type': 'text', 'content': 'Apply'},
      });

      expect(find.text('Apply'), findsOneWidget);
      expect(find.text('Saves without closing'), findsNothing);

      await tester.longPress(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(find.text('Saves without closing'), findsOneWidget,
          reason: 'a tooltip that renders its child and never its message is '
              'a wrapper with no purpose');
    });

    testWidgets('the declared styling reaches the Tooltip', (tester) async {
      await pump(tester, {
        'type': 'tooltip',
        'message': 'Styled',
        'preferBelow': false,
        'verticalOffset': 30,
        'waitDuration': 400,
        'excludeFromSemantics': true,
        'child': {'type': 'text', 'content': 'Apply'},
      });

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.preferBelow, isFalse);
      expect(tooltip.verticalOffset, 30);
      expect(tooltip.waitDuration, const Duration(milliseconds: 400));
      expect(tooltip.excludeFromSemantics, isTrue);
    });

    testWidgets('a tooltip with no message still renders its child',
        (tester) async {
      await pump(tester, {
        'type': 'tooltip',
        'child': {'type': 'text', 'content': 'Apply'},
      });
      expect(find.text('Apply'), findsOneWidget);
    });
  });

  group('popupMenuButton', () {
    Map<String, dynamic> menu({Map<String, dynamic> extra = const {}}) => {
          'type': 'popupMenuButton',
          'items': [
            {'value': 'edit', 'label': 'Edit'},
            {'value': 'delete', 'label': 'Delete'},
          ],
          'onSelected': {
            'type': 'state',
            'action': 'set',
            'binding': 'chosen',
            'value': '{{event.value}}',
          },
          ...extra,
        };

    testWidgets('opens on tap, and choosing an item reports its VALUE',
        (tester) async {
      await pump(tester, menu());

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(stateManager.get('chosen'), 'delete',
          reason: 'the value is what a document branches on; reporting the '
              'label makes every consumer translate it back');
    });

    testWidgets('a disabled button does not open', (tester) async {
      await pump(tester, menu(extra: {'enabled': false}));

      await tester.tap(find.byType(PopupMenuButton<String>),
          warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsNothing);
    });

    testWidgets('an item marked disabled cannot be chosen', (tester) async {
      await pump(tester, {
        'type': 'popupMenuButton',
        'items': [
          {'value': 'edit', 'label': 'Edit', 'enabled': false},
          {'value': 'delete', 'label': 'Delete'},
        ],
        'onSelected': {
          'type': 'state',
          'action': 'set',
          'binding': 'chosen',
          'value': '{{event.value}}',
        },
      });

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(stateManager.get('chosen'), isNull,
          reason: 'an item a document greyed out must not fire when tapped');
    });

    testWidgets('the tooltip and icon the document declared are used',
        (tester) async {
      await pump(tester, menu(extra: {
        'tooltip': 'More actions',
        'icon': 'more_vert',
      }));

      expect(find.byTooltip('More actions'), findsWidgets,
          reason: 'the tooltip is on the button; Material adds its own on the '
              'inner icon, so more than one node carries it');
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });
  });
}
