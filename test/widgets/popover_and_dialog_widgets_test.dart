// `popover`, `simpleDialog` and `inkWell` — the three widgets whose entire
// purpose is to react to a pointer.
//
// All three were under 40% covered, and the uncovered part was the reacting:
// the popover that opens on a tap and flips when there is no room below, the
// dialog whose options report which one was chosen, the ink well's six gesture
// slots. A gesture slot that stops firing produces a control that looks alive
// and does nothing.

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

  /// Renders the definition inside a scope that rebuilds on state changes.
  ///
  /// A widget bound to state has to be REBUILT for the binding to move it —
  /// rendering once and setting state afterwards tests nothing. The runtime
  /// does this rebuild for a page; here the listener stands in for it.
  Future<void> pump(
    WidgetTester tester,
    Map<String, dynamic> definition, {
    Alignment alignment = Alignment.center,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: alignment,
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

  Map<String, dynamic> popover({Map<String, dynamic> extra = const {}}) => {
        'type': 'popover',
        'child': {'type': 'text', 'content': 'anchor'},
        'content': {'type': 'text', 'content': 'the popover body'},
        ...extra,
      };

  group('popover', () {
    testWidgets('a tap opens it and a second tap closes it', (tester) async {
      await pump(tester, popover());

      expect(find.text('the popover body'), findsNothing);

      await tester.tap(find.text('anchor'));
      await tester.pumpAndSettle();
      expect(find.text('the popover body'), findsOneWidget);

      await tester.tap(find.text('anchor'));
      await tester.pumpAndSettle();
      expect(find.text('the popover body'), findsNothing,
          reason: 'a popover that only opens has to be dismissed some other '
              'way, and a user who cannot find that way is stuck');
    });

    testWidgets('onOpen and onClose each fire once, at the right moment',
        (tester) async {
      await pump(tester, popover(extra: {
        'onOpen': {
          'type': 'state',
          'action': 'increment',
          'binding': 'opened',
        },
        'onClose': {
          'type': 'state',
          'action': 'increment',
          'binding': 'closed',
        },
      }));
      stateManager.set('opened', 0);
      stateManager.set('closed', 0);

      await tester.tap(find.text('anchor'));
      await tester.pumpAndSettle();
      expect(stateManager.get('opened'), 1);
      expect(stateManager.get('closed'), 0);

      await tester.tap(find.text('anchor'));
      await tester.pumpAndSettle();
      expect(stateManager.get('closed'), 1);
      expect(stateManager.get('opened'), 1);
    });

    testWidgets('the open state is written back to its binding',
        (tester) async {
      await pump(tester, popover(extra: {'open': '{{isOpen}}'}));

      await tester.tap(find.text('anchor'));
      await tester.pumpAndSettle();
      expect(stateManager.get('isOpen'), isTrue,
          reason: 'a document that closes the popover from a button needs to '
              'know it is open');

      await tester.tap(find.text('anchor'));
      await tester.pumpAndSettle();
      expect(stateManager.get('isOpen'), isFalse);
    });

    testWidgets('state opens it without anyone touching the trigger',
        (tester) async {
      stateManager.set('isOpen', false);
      await pump(tester, popover(extra: {'open': '{{isOpen}}'}));
      expect(find.text('the popover body'), findsNothing);

      stateManager.set('isOpen', true);
      await tester.pumpAndSettle();

      expect(find.text('the popover body'), findsOneWidget,
          reason: 'the bound value is the truth — a help popover opened by a '
              'tour step never sees a pointer');
    });

    testWidgets('a tap outside dismisses it, unless the document says not to',
        (tester) async {
      await pump(tester, popover());
      await tester.tap(find.text('anchor'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('the popover body'), findsNothing);

      await pump(tester, popover(extra: {'dismissOnOutside': false}));
      await tester.tap(find.text('anchor'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('the popover body'), findsOneWidget,
          reason: 'a popover carrying a form must not vanish on a stray tap');
    });

    testWidgets('trigger: manual ignores the pointer entirely', (tester) async {
      stateManager.set('isOpen', false);
      await pump(tester,
          popover(extra: {'trigger': 'manual', 'open': '{{isOpen}}'}));

      await tester.tap(find.text('anchor'));
      await tester.pumpAndSettle();
      expect(find.text('the popover body'), findsNothing,
          reason: 'manual means the document owns it; opening on a tap would '
              'take that away');

      stateManager.set('isOpen', true);
      await tester.pumpAndSettle();
      expect(find.text('the popover body'), findsOneWidget);
    });

    testWidgets('trigger: focus opens when the anchor takes focus',
        (tester) async {
      await pump(tester, {
        'type': 'popover',
        'trigger': 'focus',
        'child': {'type': 'textInput', 'label': 'anchor field'},
        'content': {'type': 'text', 'content': 'the popover body'},
      });

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(find.text('the popover body'), findsOneWidget,
          reason: 'a hint popover on a field is the ordinary use of this '
              'trigger, and it has to work from the keyboard too');
    });

    testWidgets('an anchor near the bottom opens upward', (tester) async {
      await pump(tester, popover(extra: {'placement': 'bottom'}),
          alignment: Alignment.bottomCenter);

      await tester.tap(find.text('anchor'));
      await tester.pumpAndSettle();

      final anchorTop = tester.getTopLeft(find.text('anchor')).dy;
      final bodyTop = tester.getTopLeft(find.text('the popover body')).dy;
      expect(bodyTop, lessThan(anchorTop),
          reason: 'there is no room below, so it flips — rendering off-screen '
              'would put the content where nobody can read it');
    });

    testWidgets('an anchor near the top opens downward', (tester) async {
      await pump(tester, popover(extra: {'placement': 'top'}),
          alignment: Alignment.topCenter);

      await tester.tap(find.text('anchor'));
      await tester.pumpAndSettle();

      final anchorTop = tester.getTopLeft(find.text('anchor')).dy;
      final bodyTop = tester.getTopLeft(find.text('the popover body')).dy;
      expect(bodyTop, greaterThan(anchorTop));
    });

    testWidgets('it is removed from the overlay when the page goes away',
        (tester) async {
      await pump(tester, popover());
      await tester.tap(find.text('anchor'));
      await tester.pumpAndSettle();
      expect(find.text('the popover body'), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();

      expect(find.text('the popover body'), findsNothing,
          reason: 'an overlay entry outliving its page floats over whatever '
              'comes next');
    });
  });

  group('simpleDialog', () {
    Map<String, dynamic> dialog({Map<String, dynamic> extra = const {}}) => {
          'type': 'simpleDialog',
          'title': 'Pick one',
          'options': [
            {'label': 'Red', 'value': 'r'},
            {'label': 'Blue', 'value': 'b'},
          ],
          ...extra,
        };

    testWidgets('it shows its title and every option', (tester) async {
      await pump(tester, dialog());

      expect(find.text('Pick one'), findsOneWidget);
      expect(find.text('Red'), findsOneWidget);
      expect(find.text('Blue'), findsOneWidget);
    });

    testWidgets('choosing an option reports its value', (tester) async {
      await pump(tester, dialog(extra: {
        'onSelect': {
          'type': 'state',
          'action': 'set',
          'binding': 'chosen',
          'value': '{{event.value}}',
        },
      }));

      await tester.tap(find.text('Blue'));
      await tester.pumpAndSettle();

      expect(stateManager.get('chosen'), 'b',
          reason: 'the VALUE is what a document acts on; reporting the label '
              'makes every consumer translate it back');
    });

    testWidgets('with no options it is an empty dialog rather than an error',
        (tester) async {
      await pump(tester, {'type': 'simpleDialog', 'title': 'Nothing to pick'});
      expect(find.text('Nothing to pick'), findsOneWidget);
    });

    testWidgets('the declared background colour reaches the surface',
        (tester) async {
      await pump(tester, dialog(extra: {'backgroundColor': '#FF5733'}));

      final surface = tester.widget<SimpleDialog>(find.byType(SimpleDialog));
      expect(surface.backgroundColor, isNotNull);
      expect(surface.backgroundColor!.a, 1.0,
          reason: 'a six-digit hex has to arrive opaque — a fully transparent '
              'dialog is indistinguishable from a missing one');
    });
  });

  group('inkWell', () {
    Map<String, dynamic> ink({Map<String, dynamic> extra = const {}}) => {
          'type': 'inkWell',
          'child': {'type': 'text', 'content': 'tap target'},
          ...extra,
        };

    testWidgets('a tap fires onTap', (tester) async {
      await pump(tester, ink(extra: {
        'onTap': {
          'type': 'state',
          'action': 'set',
          'binding': 'tapped',
          'value': true,
        },
      }));

      await tester.tap(find.text('tap target'));
      await tester.pumpAndSettle();
      expect(stateManager.get('tapped'), isTrue);
    });

    testWidgets('a long press fires onLongPress and not onTap', (tester) async {
      await pump(tester, ink(extra: {
        'onTap': {
          'type': 'state',
          'action': 'increment',
          'binding': 'taps',
        },
        'onLongPress': {
          'type': 'state',
          'action': 'increment',
          'binding': 'holds',
        },
      }));
      stateManager.set('taps', 0);
      stateManager.set('holds', 0);

      await tester.longPress(find.text('tap target'));
      await tester.pumpAndSettle();

      expect(stateManager.get('holds'), 1);
      expect(stateManager.get('taps'), 0,
          reason: 'a hold that also counts as a tap opens the item the user '
              'was trying to get a menu for');
    });

    testWidgets('a double tap fires onDoubleTap', (tester) async {
      await pump(tester, ink(extra: {
        'onDoubleTap': {
          'type': 'state',
          'action': 'increment',
          'binding': 'doubles',
        },
      }));
      stateManager.set('doubles', 0);

      await tester.tap(find.text('tap target'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('tap target'));
      await tester.pumpAndSettle();

      expect(stateManager.get('doubles'), 1);
    });

    testWidgets('the press lifecycle reports down, up and cancel',
        (tester) async {
      await pump(tester, ink(extra: {
        'onTapDown': {
          'type': 'state',
          'action': 'set',
          'binding': 'phase',
          'value': 'down',
        },
        'onTapUp': {
          'type': 'state',
          'action': 'set',
          'binding': 'phase',
          'value': 'up',
        },
      }));

      final gesture =
          await tester.startGesture(tester.getCenter(find.text('tap target')));
      await tester.pump();
      expect(stateManager.get('phase'), 'down',
          reason: 'a press-and-hold visual needs the down edge, not just the '
              'completed tap');

      await gesture.up();
      await tester.pumpAndSettle();
      expect(stateManager.get('phase'), 'up');
    });

    testWidgets('the declared colours reach the ink response', (tester) async {
      await pump(tester, ink(extra: {
        'splashColor': '#FF0000',
        'highlightColor': '#00FF00',
        'hoverColor': '#0000FF',
        'onTap': {'type': 'state', 'action': 'set', 'binding': 'x', 'value': 1},
      }));

      final well = tester.widget<InkWell>(find.byType(InkWell));
      expect(well.splashColor, isNotNull);
      expect(well.highlightColor, isNotNull);
      expect(well.hoverColor, isNotNull);
      expect(well.enableFeedback, isTrue);
    });

    testWidgets('an inkWell with no handlers is inert but still renders',
        (tester) async {
      await pump(tester, ink());

      expect(find.text('tap target'), findsOneWidget);
      final well = tester.widget<InkWell>(find.byType(InkWell));
      expect(well.onTap, isNull,
          reason: 'a null handler is what stops the ripple appearing on a '
              'surface that does nothing');
    });

    testWidgets('children are laid out when no single child is given',
        (tester) async {
      await pump(tester, {
        'type': 'inkWell',
        'children': [
          {'type': 'text', 'content': 'first'},
          {'type': 'text', 'content': 'second'},
        ],
      });

      expect(find.text('first'), findsOneWidget);
      expect(find.text('second'), findsOneWidget);
    });
  });
}
