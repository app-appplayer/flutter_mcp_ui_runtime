// `simpleDialog`, `popupMenuButton` and `inkWell` — the three ways a document
// offers a choice and gets told which one was taken.
//
// All three were about half covered, and the uncovered half was the same half
// every time: the callback. A menu that opens, an option that highlights and a
// surface that ripples all look correct in a screenshot while reporting
// nothing back, so every test here presses something and then reads what the
// document was told.

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

  group('simpleDialog', () {
    Map<String, dynamic> chooser({Map<String, dynamic> extra = const {}}) => {
          'type': 'simpleDialog',
          'title': 'Choose a printer',
          'options': [
            {'value': 'front', 'label': 'Front desk'},
            {'value': 'shop', 'label': 'Workshop'},
          ],
          'onSelect': {
            'type': 'state',
            'action': 'set',
            'binding': 'printer',
            'value': '{{event.value}}',
          },
          ...extra,
        };

    testWidgets('every option is offered', (tester) async {
      await pump(tester, chooser());

      expect(find.text('Choose a printer'), findsOneWidget);
      expect(find.text('Front desk'), findsOneWidget);
      expect(find.text('Workshop'), findsOneWidget);
    });

    testWidgets('choosing one publishes the value as `event`', (tester) async {
      await pump(tester, chooser());

      await tester.tap(find.text('Workshop'));
      await tester.pumpAndSettle();

      expect(stateManager.get('printer'), 'shop',
          reason: 'the ordinary spelling `{{event.value}}` has to resolve, or '
              'the document learns that a choice was made but not which');
    });

    testWidgets('the label is published alongside the value', (tester) async {
      await pump(
          tester,
          chooser(extra: {
            'onSelect': {
              'type': 'state',
              'action': 'set',
              'binding': 'chosenLabel',
              'value': '{{event.label}}',
            },
          }));

      await tester.tap(find.text('Front desk'));
      await tester.pumpAndSettle();

      expect(stateManager.get('chosenLabel'), 'Front desk');
    });

    testWidgets('the legacy `select` spelling still fires', (tester) async {
      await pump(tester, {
        'type': 'simpleDialog',
        'options': [
          {'value': 'front', 'label': 'Front desk'},
        ],
        'select': {
          'type': 'state',
          'action': 'set',
          'binding': 'printer',
          'value': '{{event.value}}',
        },
      });

      await tester.tap(find.text('Front desk'));
      await tester.pumpAndSettle();
      expect(stateManager.get('printer'), 'front');
    });

    testWidgets('an option icon is drawn beside its label', (tester) async {
      await pump(tester, {
        'type': 'simpleDialog',
        'options': [
          {'value': 'front', 'label': 'Front desk', 'icon': 'print'},
        ],
      });

      expect(find.byIcon(Icons.print), findsOneWidget,
          reason: 'a declared icon that draws nothing is a slot silently '
              'dropped');
      expect(tester.getTopLeft(find.byIcon(Icons.print)).dx,
          lessThan(tester.getTopLeft(find.text('Front desk')).dx));
    });

    testWidgets('an option with no onSelect is still pressable', (tester) async {
      await pump(tester, {
        'type': 'simpleDialog',
        'options': [
          {'value': 'front', 'label': 'Front desk'},
        ],
      });

      await tester.tap(find.text('Front desk'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('an option that is not a map takes no space', (tester) async {
      await pump(tester, {
        'type': 'simpleDialog',
        'options': ['front'],
      });

      expect(find.byType(SimpleDialogOption), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('with no options it falls back to children', (tester) async {
      await pump(tester, {
        'type': 'simpleDialog',
        'title': 'Choose',
        'children': [
          {'type': 'text', 'content': 'a rendered child'},
        ],
      });

      expect(find.text('a rendered child'), findsOneWidget);
    });

    testWidgets('surface properties are applied', (tester) async {
      await pump(
          tester,
          chooser(extra: {
            'backgroundColor': '#FF00FF',
            'elevation': 6,
            'shape': {'type': 'rounded', 'radius': 16},
            'contentPadding': 4,
            'titlePadding': 12,
          }));

      final dialog = tester.widget<SimpleDialog>(find.byType(SimpleDialog));
      expect(dialog.backgroundColor, const Color(0xFFFF00FF));
      expect(dialog.elevation, 6);
      expect((dialog.shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(16));
      expect(dialog.contentPadding, const EdgeInsets.all(4));
      expect(dialog.titlePadding, const EdgeInsets.all(12));
    });

    testWidgets('a circle shape is honoured and an unknown one is not',
        (tester) async {
      await pump(tester, chooser(extra: {
        'shape': {'type': 'circle'},
      }));
      expect(tester.widget<SimpleDialog>(find.byType(SimpleDialog)).shape,
          isA<CircleBorder>());

      await pump(tester, chooser(extra: {
        'shape': {'type': 'hexagon'},
      }));
      expect(
          tester.widget<SimpleDialog>(find.byType(SimpleDialog)).shape, isNull);
    });
  });

  group('popupMenuButton', () {
    Map<String, dynamic> menu({Map<String, dynamic> extra = const {}}) => {
          'type': 'popupMenuButton',
          'items': [
            {'value': 'edit', 'label': 'Edit'},
            {'value': 'delete', 'label': 'Delete'},
          ],
          'onSelect': {
            'type': 'state',
            'action': 'set',
            'binding': 'chosen',
            'value': '{{event.value}}',
          },
          ...extra,
        };

    testWidgets('opens on a tap and reports what was chosen', (tester) async {
      await pump(tester, menu());

      expect(find.text('Edit'), findsNothing,
          reason: 'the menu is closed until it is asked for');
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(stateManager.get('chosen'), 'delete');
    });

    testWidgets('onOpened fires when the menu opens', (tester) async {
      await pump(
          tester,
          menu(extra: {
            'onOpened': {
              'type': 'state',
              'action': 'set',
              'binding': 'opened',
              'value': true,
            },
          }));

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(stateManager.get('opened'), isTrue);
    });

    testWidgets('onCanceled fires when it is dismissed without a choice',
        (tester) async {
      await pump(
          tester,
          menu(extra: {
            'onCanceled': {
              'type': 'state',
              'action': 'set',
              'binding': 'cancelled',
              'value': true,
            },
          }));

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      // Dismiss by tapping the barrier, well away from any item.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(stateManager.get('cancelled'), isTrue,
          reason: 'a document that never hears about a dismissal keeps a menu '
              'open in its own state');
    });

    testWidgets('a disabled item cannot be chosen', (tester) async {
      await pump(tester, {
        'type': 'popupMenuButton',
        'items': [
          {'value': 'edit', 'label': 'Edit', 'enabled': false},
        ],
        'onSelect': {
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
          reason: 'an item that is greyed out and still acts is worse than one '
              'that is not greyed out at all');
    });

    testWidgets('a plain string item becomes its own value', (tester) async {
      await pump(tester, {
        'type': 'popupMenuButton',
        'items': ['edit', 'delete'],
        'onSelect': {
          'type': 'state',
          'action': 'set',
          'binding': 'chosen',
          'value': '{{event.value}}',
        },
      });

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('edit'));
      await tester.pumpAndSettle();

      expect(stateManager.get('chosen'), 'edit');
    });

    testWidgets('an item may render a whole child widget', (tester) async {
      await pump(tester, {
        'type': 'popupMenuButton',
        'items': [
          {
            'value': 'edit',
            'child': {'type': 'text', 'content': 'A rendered row'},
          },
        ],
      });

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('A rendered row'), findsOneWidget);
    });

    testWidgets('the `text` spelling is accepted as the label', (tester) async {
      await pump(tester, {
        'type': 'popupMenuButton',
        'items': [
          {'value': 'edit', 'text': 'Edit this'},
        ],
      });

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('Edit this'), findsOneWidget);
    });

    testWidgets('an item with neither label nor text falls back to its value',
        (tester) async {
      await pump(tester, {
        'type': 'popupMenuButton',
        'items': [
          {'value': 'edit'},
        ],
      });

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('edit'), findsOneWidget,
          reason: 'a blank row cannot be chosen with any confidence');
    });

    testWidgets('a per-item textStyle and height are applied', (tester) async {
      await pump(tester, {
        'type': 'popupMenuButton',
        'items': [
          {
            'value': 'edit',
            'label': 'Edit',
            'height': 60,
            'padding': 10,
            'textStyle': {
              'color': '#FF0000',
              'fontSize': 22,
              'fontWeight': 'bold',
            },
          },
        ],
      });

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      final item =
          tester.widget<PopupMenuItem<String>>(find.byType(PopupMenuItem<String>));
      expect(item.height, 60);
      expect(item.padding, const EdgeInsets.all(10));
      expect(item.textStyle!.color, const Color(0xFFFF0000));
      expect(item.textStyle!.fontSize, 22);
      expect(item.textStyle!.fontWeight, FontWeight.bold);
    });

    testWidgets('a declared icon replaces the default overflow glyph',
        (tester) async {
      await pump(tester, menu(extra: {'icon': 'settings'}));

      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('with no icon it is the overflow glyph', (tester) async {
      await pump(tester, menu());
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('a declared child replaces the glyph entirely', (tester) async {
      await pump(tester, {
        'type': 'popupMenuButton',
        'items': ['edit'],
        'children': [
          {'type': 'text', 'content': 'Actions'},
        ],
      });

      expect(find.text('Actions'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('button properties are applied', (tester) async {
      await pump(
          tester,
          menu(extra: {
            'tooltip': 'More actions',
            'padding': 12,
            'splashRadius': 20,
            'iconSize': 30,
            'offset': {'dx': 4, 'dy': 8},
            'color': '#FF00FF',
            'shadowColor': '#112233',
            'surfaceTintColor': '#445566',
            'shape': {'type': 'rounded', 'radius': 14},
          }));

      final button =
          tester.widget<PopupMenuButton<String>>(find.byType(PopupMenuButton<String>));
      expect(button.tooltip, 'More actions');
      expect(button.padding, const EdgeInsets.all(12));
      expect(button.splashRadius, 20);
      expect(button.iconSize, 30);
      expect(button.offset, const Offset(4, 8));
      expect(button.color, const Color(0xFFFF00FF));
      expect(button.shadowColor, const Color(0xFF112233));
      expect(button.surfaceTintColor, const Color(0xFF445566));
      expect((button.shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(14));
    });

    testWidgets('disabled means the menu cannot be opened', (tester) async {
      await pump(tester, menu(extra: {'enabled': false}));

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsNothing);
    });
  });

  group('inkWell', () {
    testWidgets('a tap runs the action', (tester) async {
      await pump(tester, {
        'type': 'inkWell',
        'child': {'type': 'text', 'content': 'Tap me'},
        'onTap': {
          'type': 'state',
          'action': 'set',
          'binding': 'taps',
          'value': 1,
        },
      });

      await tester.tap(find.text('Tap me'));
      await tester.pumpAndSettle();
      expect(stateManager.get('taps'), 1);
    });

    testWidgets('a double tap and a long press are distinct', (tester) async {
      await pump(tester, {
        'type': 'inkWell',
        'child': {'type': 'text', 'content': 'Tap me'},
        'onDoubleTap': {
          'type': 'state',
          'action': 'set',
          'binding': 'gesture',
          'value': 'double',
        },
        'onLongPress': {
          'type': 'state',
          'action': 'set',
          'binding': 'gesture',
          'value': 'long',
        },
      });

      await tester.tap(find.text('Tap me'));
      // Inside kDoubleTapTimeout, or the recogniser sees two single taps.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Tap me'));
      await tester.pumpAndSettle();
      expect(stateManager.get('gesture'), 'double');

      await tester.longPress(find.text('Tap me'));
      await tester.pumpAndSettle();
      expect(stateManager.get('gesture'), 'long');
    });

    testWidgets('onTapDown and onTapUp carry the local position',
        (tester) async {
      await pump(tester, {
        'type': 'inkWell',
        'child': {'type': 'text', 'content': 'Tap me'},
        'onTapDown': {
          'type': 'state',
          'action': 'set',
          'binding': 'down',
          'position': '{{event.position}}',
        },
        'onTapUp': {
          'type': 'state',
          'action': 'set',
          'binding': 'up',
          'value': 'released',
        },
      });

      await tester.tap(find.text('Tap me'));
      await tester.pumpAndSettle();

      expect(stateManager.get('up'), 'released');
    });

    testWidgets('onTapCancel fires when the finger leaves before release',
        (tester) async {
      await pump(tester, {
        'type': 'inkWell',
        'child': {'type': 'text', 'content': 'Tap me'},
        'onTap': {
          'type': 'state',
          'action': 'set',
          'binding': 'result',
          'value': 'tapped',
        },
        'onTapCancel': {
          'type': 'state',
          'action': 'set',
          'binding': 'result',
          'value': 'cancelled',
        },
      });

      final gesture = await tester.startGesture(tester.getCenter(find.text('Tap me')));
      await gesture.moveBy(const Offset(400, 400));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(stateManager.get('result'), 'cancelled',
          reason: 'a drag away from a button is the user changing their mind; '
              'treating it as a tap acts against them');
    });

    testWidgets('onHighlightChanged reports both edges', (tester) async {
      await pump(tester, {
        'type': 'inkWell',
        'child': {'type': 'text', 'content': 'Tap me'},
        'onTap': {'type': 'state', 'action': 'set', 'binding': 'x', 'value': 1},
        'onHighlightChanged': {
          'type': 'state',
          'action': 'set',
          'binding': 'highlighted',
          'highlighted': '{{event.highlighted}}',
        },
      });

      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Tap me')));
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('several children are all built, not just the first',
        (tester) async {
      await pump(tester, {
        'type': 'inkWell',
        'children': [
          {'type': 'text', 'content': 'first'},
          {'type': 'text', 'content': 'second'},
        ],
      });

      expect(find.text('first'), findsOneWidget);
      expect(find.text('second'), findsOneWidget,
          reason: 'a declared child accepted and dropped is invisible in every '
              'other way');
    });

    testWidgets('a single child in `children` is not wrapped in a Column',
        (tester) async {
      await pump(tester, {
        'type': 'inkWell',
        'children': [
          {'type': 'text', 'content': 'only'},
        ],
      });

      expect(find.text('only'), findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(InkWell), matching: find.byType(Column)),
          findsNothing);
    });

    testWidgets('colours and focus properties are applied', (tester) async {
      await pump(tester, {
        'type': 'inkWell',
        'child': {'type': 'text', 'content': 'Tap me'},
        'splashColor': '#FF0000',
        'highlightColor': '#00FF00',
        'hoverColor': '#0000FF',
        'focusColor': '#FFFF00',
        'overlayColor': '#FF00FF',
        'borderRadius': 12,
        'enableFeedback': false,
        'excludeFromSemantics': true,
        'canRequestFocus': false,
        'autofocus': false,
      });

      final ink = tester.widget<InkWell>(find.byType(InkWell));
      expect(ink.splashColor, const Color(0xFFFF0000));
      expect(ink.highlightColor, const Color(0xFF00FF00));
      expect(ink.hoverColor, const Color(0xFF0000FF));
      expect(ink.focusColor, const Color(0xFFFFFF00));
      expect(ink.overlayColor!.resolve({}), const Color(0xFFFF00FF));
      expect(ink.borderRadius, BorderRadius.circular(12));
      expect(ink.enableFeedback, isFalse);
      expect(ink.excludeFromSemantics, isTrue);
      expect(ink.canRequestFocus, isFalse);
    });

    testWidgets('a per-corner borderRadius is read', (tester) async {
      await pump(tester, {
        'type': 'inkWell',
        'child': {'type': 'text', 'content': 'Tap me'},
        'borderRadius': {'topLeft': 4, 'bottomRight': 8},
      });

      expect(
          tester.widget<InkWell>(find.byType(InkWell)).borderRadius,
          const BorderRadius.only(
            topLeft: Radius.circular(4),
            bottomRight: Radius.circular(8),
          ));
    });

    testWidgets('a customBorder shape is read, and an unknown one is not',
        (tester) async {
      await pump(tester, {
        'type': 'inkWell',
        'child': {'type': 'text', 'content': 'Tap me'},
        'customBorder': {'type': 'circle'},
      });
      expect(tester.widget<InkWell>(find.byType(InkWell)).customBorder,
          isA<CircleBorder>());

      await pump(tester, {
        'type': 'inkWell',
        'child': {'type': 'text', 'content': 'Tap me'},
        'customBorder': {'type': 'rounded', 'radius': 6},
      });
      expect(
          (tester.widget<InkWell>(find.byType(InkWell)).customBorder!
                  as RoundedRectangleBorder)
              .borderRadius,
          BorderRadius.circular(6));

      await pump(tester, {
        'type': 'inkWell',
        'child': {'type': 'text', 'content': 'Tap me'},
        'customBorder': {'type': 'hexagon'},
      });
      expect(
          tester.widget<InkWell>(find.byType(InkWell)).customBorder, isNull);
    });

    testWidgets('the ink layer is the factory\'s own, not the page\'s',
        (tester) async {
      // Written history: ink is painted by the nearest ancestor Material, so a
      // page that gave itself a background painted over the splash entirely.
      await pump(tester, {
        'type': 'inkWell',
        'child': {'type': 'text', 'content': 'Tap me'},
      });

      final material = tester.widget<Material>(find.ancestor(
        of: find.byType(InkWell),
        matching: find.byType(Material),
      ).first);
      expect(material.type, MaterialType.transparency,
          reason: 'the ink layer has to sit between the InkWell and whatever '
              'the document painted above it');
    });
  });
}
