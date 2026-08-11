// `datePicker`, `timePicker`, `dropdown` and `navigationRail`.
//
// The two pickers are the BUTTON form — a control that opens a dialog and
// writes the chosen value back — as opposed to the field forms covered
// elsewhere. Everything after the tap was uncovered in both, which is to say
// the writing back.

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

  group('datePicker', () {
    testWidgets('shows the bound date and writes the chosen one back',
        (tester) async {
      stateManager.set('day', '2026-03-15');
      await pump(tester, {
        'type': 'datePicker',
        'binding': 'day',
        'firstDate': '2026-03-01',
        'lastDate': '2026-03-31',
        'onChange': {
          'type': 'state',
          'action': 'set',
          'binding': 'reported',
          'value': '{{event.value}}',
        },
      });

      expect(find.text('2026-03-15'), findsOneWidget,
          reason: 'the button label IS the current value; a button that always '
              'reads "Select Date" hides what is already chosen');

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(stateManager.get('day'), '2026-03-20');
      expect(stateManager.get('reported'), '2026-03-20',
          reason: 'the picker is a control; a document that is not told what '
              'was chosen cannot act on it');
    });

    testWidgets('cancelling writes nothing', (tester) async {
      stateManager.set('day', '2026-03-15');
      await pump(tester, {
        'type': 'datePicker',
        'binding': 'day',
        'firstDate': '2026-03-01',
        'lastDate': '2026-03-31',
      });

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(stateManager.get('day'), '2026-03-15');
    });

    testWidgets('the declared format is what gets written', (tester) async {
      stateManager.set('day', '2026-03-15');
      await pump(tester, {
        'type': 'datePicker',
        'binding': 'day',
        'firstDate': '2026-03-01',
        'lastDate': '2026-03-31',
        'dateFormat': 'dd/MM/yyyy',
      });

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(stateManager.get('day'), '20/03/2026');
    });

    testWidgets('each variant is a different button, and text is a TextButton',
        (tester) async {
      await pump(tester, {
        'type': 'datePicker',
        'binding': 'day',
        'variant': 'text',
      });
      expect(find.byType(TextButton), findsOneWidget);

      await pump(tester, {
        'type': 'datePicker',
        'binding': 'day',
        'variant': 'outlined',
      });
      expect(find.byType(OutlinedButton), findsOneWidget);

      await pump(tester, {
        'type': 'datePicker',
        'binding': 'day',
        'variant': 'icon',
        'label': 'Pick a day',
      });
      expect(find.byType(IconButton), findsOneWidget);
      expect(tester.widget<IconButton>(find.byType(IconButton)).tooltip,
          'Pick a day',
          reason: 'the icon form has nowhere to put the label but the tooltip; '
              'dropping it leaves an unlabelled button');
    });

    testWidgets('a value that is not a date leaves the label showing',
        (tester) async {
      stateManager.set('day', 'sometime');
      await pump(tester, {
        'type': 'datePicker',
        'binding': 'day',
        'label': 'Pick a day',
      });

      expect(find.text('Pick a day'), findsOneWidget);
    });

    testWidgets('a declared icon replaces the calendar', (tester) async {
      await pump(tester, {
        'type': 'datePicker',
        'binding': 'day',
        'icon': 'event',
      });

      expect(find.byIcon(Icons.event), findsOneWidget);
    });
  });

  group('timePicker', () {
    testWidgets('shows the bound time and writes the chosen one back',
        (tester) async {
      stateManager.set('at', '09:30');
      await pump(tester, {
        'type': 'timePicker',
        'binding': 'at',
        'onChange': {
          'type': 'state',
          'action': 'set',
          'binding': 'reported',
          'value': '{{event.value}}',
        },
      });

      expect(find.text('09:30'), findsOneWidget);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      // The dial opens on the value already chosen, so accepting without
      // touching it returns that same time.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(stateManager.get('at'), '09:30',
          reason: 'opening at the wall clock instead of the chosen value makes '
              'every correction start over');
      expect(stateManager.get('reported'), '09:30');
    });

    testWidgets('cancelling writes nothing', (tester) async {
      stateManager.set('at', '09:30');
      await pump(tester, {'type': 'timePicker', 'binding': 'at'});

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(stateManager.get('at'), '09:30');
    });

    testWidgets('a 12-hour picker writes the meridiem form', (tester) async {
      stateManager.set('at', '13:45');
      await pump(tester, {
        'type': 'timePicker',
        'binding': 'at',
        'use24HourFormat': false,
        'timeFormat': 'hh:mm a',
      });

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(stateManager.get('at'), '01:45 PM',
          reason: 'a document that asked for 12-hour and got 13:45 back has to '
              'convert it itself');
    });

    testWidgets('an unparseable value leaves the label showing',
        (tester) async {
      stateManager.set('at', 'lunchtime');
      await pump(tester, {
        'type': 'timePicker',
        'binding': 'at',
        'label': 'Pick a time',
      });

      expect(find.text('Pick a time'), findsOneWidget);
    });

    testWidgets('the variants build, and icon keeps the label as a tooltip',
        (tester) async {
      await pump(tester, {
        'type': 'timePicker',
        'binding': 'at',
        'variant': 'outlined',
      });
      expect(find.byType(OutlinedButton), findsOneWidget);

      await pump(tester, {
        'type': 'timePicker',
        'binding': 'at',
        'variant': 'text',
      });
      expect(find.byType(TextButton), findsOneWidget);

      await pump(tester, {
        'type': 'timePicker',
        'binding': 'at',
        'variant': 'icon',
        'label': 'Pick a time',
        'icon': 'alarm',
      });
      expect(find.byIcon(Icons.alarm), findsOneWidget);
      expect(tester.widget<IconButton>(find.byType(IconButton)).tooltip,
          'Pick a time');
    });
  });

  group('dropdown', () {
    // The dropdown is a `PopupMenuButton` behind a bordered trigger — the
    // Material `DropdownButton` was replaced to get compact menu tokens.
    Map<String, dynamic> dropdown({Map<String, dynamic> extra = const {}}) =>
        <String, dynamic>{
          'type': 'dropdown',
          'binding': 'site',
          'options': <dynamic>[
            <String, dynamic>{'value': 'north', 'label': 'North'},
            <String, dynamic>{'value': 'south', 'label': 'South'},
          ],
          ...extra,
        };

    testWidgets('the trigger shows the selected label, not the raw value',
        (tester) async {
      stateManager.set('site', 'north');
      await pump(tester, dropdown());

      expect(find.text('North'), findsOneWidget,
          reason: 'the label is what the document wrote for a human; showing '
              '"north" leaks the wire value');
    });

    testWidgets('choosing an option writes it back', (tester) async {
      stateManager.set('site', 'north');
      await pump(tester, dropdown());

      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('South').last);
      await tester.pumpAndSettle();

      expect(stateManager.get('site'), 'south');
      expect(find.text('South'), findsOneWidget,
          reason: 'the trigger has to follow the write, or the next tap opens '
              'on the old selection');
    });

    testWidgets('onChange is told the value and the index', (tester) async {
      stateManager.set('site', 'north');
      await pump(tester, dropdown(extra: {
        'onChange': <String, dynamic>{
          'type': 'batch',
          'actions': <dynamic>[
            <String, dynamic>{
              'type': 'state',
              'action': 'set',
              'binding': 'chosen',
              'value': '{{event.value}}',
            },
            <String, dynamic>{
              'type': 'state',
              'action': 'set',
              'binding': 'chosenIndex',
              'value': '{{event.index}}',
            },
          ],
        },
      }));

      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('South').last);
      await tester.pumpAndSettle();

      expect(stateManager.get('chosen'), 'south');
      expect(stateManager.get('chosenIndex'), 1);
    });

    testWidgets('plain string options are their own value', (tester) async {
      await pump(tester, dropdown(extra: {
        'options': <dynamic>['north', 'south'],
      }));

      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('south').last);
      await tester.pumpAndSettle();

      expect(stateManager.get('site'), 'south');
    });

    testWidgets('the legacy `items` spelling still resolves', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'dropdown',
        'binding': 'site',
        'items': <dynamic>[
          <String, dynamic>{'value': 'north', 'text': 'North'},
        ],
      });

      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('North').last);
      await tester.pumpAndSettle();

      expect(stateManager.get('site'), 'north');
    });

    testWidgets('with nothing selected the placeholder shows', (tester) async {
      await pump(tester, dropdown(extra: {'placeholder': 'Choose a site'}));

      expect(find.text('Choose a site'), findsOneWidget);
    });

    testWidgets('with no binding and no onChange it is inert', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'dropdown',
        'options': <dynamic>['north'],
        'disabledHint': 'Unavailable',
      });

      expect(find.text('Unavailable'), findsOneWidget);
      expect(tester.widget<PopupMenuButton<int>>(
              find.byType(PopupMenuButton<int>)).enabled,
          isFalse,
          reason: 'a selector with nowhere to write is not a control; opening '
              'it would offer a choice that goes nowhere');
    });

    testWidgets('a declared style reaches the trigger text', (tester) async {
      stateManager.set('site', 'north');
      await pump(tester, dropdown(extra: {
        'style': <String, dynamic>{
          'color': '#FF0000',
          'fontSize': 20,
          'fontWeight': 'w600',
          'italic': true,
          'letterSpacing': 1.5,
          'height': 1.4,
        },
      }));

      final style = tester.widget<Text>(find.text('North')).style!;
      expect(style.color, const Color(0xFFFF0000));
      expect(style.fontSize, 20);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.fontStyle, FontStyle.italic);
      expect(style.letterSpacing, 1.5);
      expect(style.height, 1.4);
    });

    testWidgets('a label is drawn above it', (tester) async {
      await pump(tester, dropdown(extra: {'label': 'Site'}));

      expect(find.text('Site'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Site')).dy,
          lessThan(tester.getTopLeft(find.byType(PopupMenuButton<int>)).dy));
    });
  });

  group('navigationRail', () {
    Map<String, dynamic> rail({Map<String, dynamic> extra = const {}}) => {
          'type': 'navigationRail',
          'selectedIndex': 0,
          'destinations': [
            {'icon': 'home', 'label': 'Home'},
            {'icon': 'list', 'label': 'Jobs'},
          ],
          ...extra,
        };

    testWidgets('draws its destinations', (tester) async {
      await pump(tester, rail(extra: {'labelType': 'all'}));

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Jobs'), findsOneWidget);
    });

    testWidgets('selecting one reports the index', (tester) async {
      await pump(tester, rail(extra: {
        'labelType': 'all',
        'onChange': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'tab',
          'value': '{{event.index}}',
        },
      }));

      await tester.tap(find.text('Jobs'));
      await tester.pumpAndSettle();

      expect(stateManager.get('tab'), 1,
          reason: 'the rail highlights on its own; the index is the only way '
              'the document learns which destination');
    });

    testWidgets('with no handler the destinations are inert', (tester) async {
      await pump(tester, rail(extra: {'labelType': 'all'}));

      expect(
          tester
              .widget<NavigationRail>(find.byType(NavigationRail))
              .onDestinationSelected,
          isNull);
    });

    testWidgets('a bound selectedIndex follows state', (tester) async {
      stateManager.set('tab', 1);
      await pump(tester, rail(extra: {
        'labelType': 'all',
        'selectedIndex': '{{tab}}',
      }));

      expect(
          tester.widget<NavigationRail>(find.byType(NavigationRail))
              .selectedIndex,
          1);

      stateManager.set('tab', 0);
      await tester.pumpAndSettle();
      expect(
          tester.widget<NavigationRail>(find.byType(NavigationRail))
              .selectedIndex,
          0);
    });

    testWidgets('an index past the end is clamped rather than asserting',
        (tester) async {
      await pump(tester, rail(extra: {'labelType': 'all', 'selectedIndex': 9}));

      expect(
          tester.widget<NavigationRail>(find.byType(NavigationRail))
              .selectedIndex,
          1);
    });

    testWidgets('a labelText destination is accepted', (tester) async {
      await pump(tester, rail(extra: {
        'labelType': 'all',
        'destinations': [
          {'icon': 'home', 'labelText': 'Home'},
          {'icon': 'list', 'labelText': 'Jobs'},
        ],
      }));

      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('a widget label is built', (tester) async {
      await pump(tester, rail(extra: {
        'labelType': 'all',
        'destinations': [
          {
            'icon': 'home',
            'label': {'type': 'text', 'content': 'Rendered'},
          },
          {'icon': 'list', 'label': 'Jobs'},
        ],
      }));

      expect(find.text('Rendered'), findsOneWidget,
          reason: 'a label slot that accepts a widget and draws nothing loses '
              'whatever the document put there');
    });

    testWidgets('leading and trailing slots are built', (tester) async {
      await pump(tester, rail(extra: {
        'labelType': 'all',
        'leading': {'type': 'text', 'content': 'top'},
        'trailing': {'type': 'text', 'content': 'bottom'},
      }));

      expect(find.text('top'), findsOneWidget);
      expect(find.text('bottom'), findsOneWidget);
    });

    testWidgets('a widget icon is built, and shows on the selected one too',
        (tester) async {
      await pump(tester, rail(extra: {
        'labelType': 'all',
        'selectedIndex': 0,
        'destinations': <dynamic>[
          <String, dynamic>{
            'icon': <String, dynamic>{'type': 'text', 'content': 'ICON'},
            'label': 'Home',
          },
          <String, dynamic>{'icon': 'list', 'label': 'Jobs'},
        ],
      }));

      expect(find.text('ICON'), findsOneWidget,
          reason: 'an undeclared selectedIcon means "the same icon"; putting a '
              'house there replaces the document\'s own icon on exactly the '
              'destination the user is looking at');
    });

    testWidgets('a declared selectedIcon is used for the selected one',
        (tester) async {
      await pump(tester, rail(extra: {
        'labelType': 'all',
        'selectedIndex': 0,
        'destinations': <dynamic>[
          <String, dynamic>{
            'icon': 'star_border',
            'selectedIcon': 'star',
            'label': 'Home',
          },
          <String, dynamic>{'icon': 'list', 'label': 'Jobs'},
        ],
      }));

      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('a destination that is not a map still draws something',
        (tester) async {
      await pump(tester, rail(extra: {
        'labelType': 'all',
        'destinations': <dynamic>['Home', 'Jobs'],
      }));

      expect(find.text('Item'), findsNWidgets(2));
    });

    testWidgets('the label and icon themes are read', (tester) async {
      await pump(tester, rail(extra: {
        'labelType': 'all',
        'extended': false,
        'minWidth': 90,
        'groupAlignment': 0,
        'elevation': 4,
        'backgroundColor': '#EEEEEE',
        'selectedLabelTextStyle': <String, dynamic>{
          'color': '#FF0000',
          'fontSize': 16,
          'fontWeight': 'bold',
        },
        'unselectedLabelTextStyle': <String, dynamic>{'fontSize': 12},
        'selectedIconTheme': <String, dynamic>{
          'color': '#00FF00',
          'size': 30,
          'opacity': 1,
        },
        'unselectedIconTheme': <String, dynamic>{'size': 20},
      }));

      final built = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(built.selectedLabelTextStyle!.color, const Color(0xFFFF0000));
      expect(built.selectedLabelTextStyle!.fontSize, 16);
      expect(built.selectedLabelTextStyle!.fontWeight, FontWeight.bold);
      expect(built.unselectedLabelTextStyle!.fontSize, 12);
      expect(built.selectedIconTheme!.color, const Color(0xFF00FF00));
      expect(built.selectedIconTheme!.size, 30);
      expect(built.unselectedIconTheme!.size, 20);
      expect(built.backgroundColor, const Color(0xFFEEEEEE));
      expect(built.elevation, 4);
      expect(built.minWidth, 90);
      expect(built.groupAlignment, 0);
    });

    testWidgets('an extended rail shows labels beside the icons',
        (tester) async {
      await pump(tester, rail(extra: {
        'extended': true,
        'minExtendedWidth': 200,
      }));

      final railWidget =
          tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(railWidget.extended, isTrue);
      expect(railWidget.minExtendedWidth, 200);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('an unknown labelType leaves Material to decide',
        (tester) async {
      await pump(tester, rail(extra: {'labelType': 'sometimes'}));

      expect(
          tester.widget<NavigationRail>(find.byType(NavigationRail)).labelType,
          isNull);
    });

    testWidgets('destination padding is applied', (tester) async {
      await pump(tester, rail(extra: {
        'labelType': 'all',
        'destinations': <dynamic>[
          <String, dynamic>{'icon': 'home', 'label': 'Home', 'padding': 12},
          <String, dynamic>{'icon': 'list', 'label': 'Jobs'},
        ],
      }));

      final railWidget =
          tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(railWidget.destinations.first.padding, const EdgeInsets.all(12));
    });
  });
}
