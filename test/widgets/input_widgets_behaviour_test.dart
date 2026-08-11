// `combobox`, `multiSelect` and `numberField` — driven from the keyboard and
// the mouse.
//
// All three were under half covered, and what was missing is everything a user
// does: typing into the combobox, walking the suggestion list with the arrow
// keys, ticking options past a ceiling, pressing the stepper. Each of these
// widgets writes into state, so a slot that quietly stops writing produces a
// form that looks filled in and submits nothing.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        body: SingleChildScrollView(
          child: context.renderer.renderWidget(definition, context),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('combobox', () {
    Map<String, dynamic> combo({Map<String, dynamic> extra = const {}}) => {
          'type': 'combobox',
          'binding': 'choice',
          'options': ['Apple', 'Apricot', 'Banana'],
          ...extra,
        };

    testWidgets('the list opens on typing and narrows to what matches',
        (tester) async {
      await pump(tester, combo());

      await tester.enterText(find.byType(TextField), 'ap');
      await tester.pumpAndSettle();

      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Apricot'), findsOneWidget);
      expect(find.text('Banana'), findsNothing,
          reason: 'a suggestion list that does not filter is a list the user '
              'has to read in full every keystroke');
    });

    testWidgets('choosing a suggestion fills the field and writes to state',
        (tester) async {
      await pump(tester, combo());

      await tester.enterText(find.byType(TextField), 'ap');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apricot'));
      await tester.pumpAndSettle();

      expect(stateManager.get('choice'), 'Apricot');
      expect(find.byType(ListTile), findsNothing,
          reason: 'the list closes on a pick; leaving it open covers the rest '
              'of the form');
    });

    testWidgets('a free value is committed as typed when allowCustom is on',
        (tester) async {
      await pump(tester, combo());

      await tester.enterText(find.byType(TextField), 'Cherry');
      await tester.pumpAndSettle();

      expect(stateManager.get('choice'), 'Cherry',
          reason: 'allowCustom defaults to true — the list is a suggestion '
              'surface, not the domain');
    });

    testWidgets('with allowCustom off, typing alone does not commit',
        (tester) async {
      await pump(tester, combo(extra: {'allowCustom': false}));

      await tester.enterText(find.byType(TextField), 'Cherry');
      await tester.pumpAndSettle();
      expect(stateManager.get('choice'), isNull);

      await tester.enterText(find.byType(TextField), 'App');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apple'));
      await tester.pumpAndSettle();
      expect(stateManager.get('choice'), 'Apple',
          reason: 'a constrained field still has to accept a value from its '
              'own list');
    });

    testWidgets('the arrow keys walk the list and Enter takes the highlight',
        (tester) async {
      await pump(tester, combo(extra: {'allowCustom': false}));

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'a');
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(stateManager.get('choice'), 'Apricot',
          reason: 'two downs land on the second match; keyboard use is the '
              'whole reason this is not a plain dropdown');
    });

    testWidgets('arrow up wraps to the end of the list', (tester) async {
      await pump(tester, combo(extra: {'allowCustom': false}));

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'a');
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(stateManager.get('choice'), 'Banana');
    });

    testWidgets('Escape closes the list and leaves the text alone',
        (tester) async {
      await pump(tester, combo());

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'ap');
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsWidgets);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsNothing);
      expect(find.widgetWithText(TextField, 'ap'), findsOneWidget,
          reason: 'Escape dismisses the suggestions, it does not undo the '
              'typing');
    });

    testWidgets('minChars holds the list back until enough is typed',
        (tester) async {
      await pump(tester, combo(extra: {'minChars': 3}));

      await tester.enterText(find.byType(TextField), 'ap');
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNothing);

      await tester.enterText(find.byType(TextField), 'app');
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsOneWidget);
    });

    testWidgets('onSearch fires with the query, and is debounced',
        (tester) async {
      await pump(tester, combo(extra: {
        'debounceMs': 400,
        'onSearch': {
          'type': 'state',
          'action': 'append',
          'binding': 'queries',
          'value': '{{event.query}}',
        },
      }));
      stateManager.set('queries', <dynamic>[]);

      await tester.enterText(find.byType(TextField), 'ap');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'app');
      await tester.pumpAndSettle();

      expect(stateManager.get('queries'), ['ap'],
          reason: 'the second keystroke lands inside the debounce window — a '
              'search per keystroke is a request per keystroke');
    });

    testWidgets('options given as {value,label} maps show their labels',
        (tester) async {
      await pump(tester, {
        'type': 'combobox',
        'binding': 'choice',
        'options': [
          {'value': 'a', 'label': 'Alpha'},
          {'value': 'b', 'label': 'Beta'},
        ],
      });

      await tester.enterText(find.byType(TextField), 'al');
      await tester.pumpAndSettle();
      expect(find.text('Alpha'), findsOneWidget);
    });

    testWidgets('a disabled combobox refuses input', (tester) async {
      await pump(tester, combo(extra: {'enabled': false}));
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
    });

    testWidgets('the label and placeholder reach the decoration',
        (tester) async {
      await pump(tester,
          combo(extra: {'label': 'Fruit', 'placeholder': 'start typing'}));
      expect(find.text('Fruit'), findsOneWidget);
      expect(find.text('start typing'), findsOneWidget);
    });
  });

  group('multiSelect', () {
    Map<String, dynamic> multi({Map<String, dynamic> extra = const {}}) => {
          'type': 'multiSelect',
          'binding': 'picked',
          'options': [
            {'value': 'r', 'label': 'Red'},
            {'value': 'g', 'label': 'Green'},
            {'value': 'b', 'label': 'Blue'},
          ],
          ...extra,
        };

    testWidgets('opens, ticks an option, and writes the value list',
        (tester) async {
      await pump(tester, multi());

      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Green'));
      await tester.pumpAndSettle();

      expect(stateManager.get('picked'), ['g'],
          reason: 'the VALUE is written, not the label — a form submitting '
              '"Green" to an API expecting "g" fails at the far end');
    });

    testWidgets('ticking again removes it', (tester) async {
      stateManager.set('picked', ['g']);
      await pump(tester, multi());

      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(CheckboxListTile),
        matching: find.text('Green'),
      ));
      await tester.pumpAndSettle();

      expect(stateManager.get('picked'), isEmpty);
    });

    testWidgets('the current selection is shown as chips, and a chip removes '
        'its own value', (tester) async {
      stateManager.set('picked', ['r', 'b']);
      await pump(tester, multi());

      expect(find.byType(Chip), findsNWidgets(2));
      expect(find.text('Red'), findsOneWidget);
      expect(find.text('Blue'), findsOneWidget);

      await tester.tap(find.descendant(
        of: find.widgetWithText(Chip, 'Red'),
        matching: find.byType(Icon),
      ));
      await tester.pumpAndSettle();

      expect(stateManager.get('picked'), ['b']);
    });

    testWidgets('showChips off summarises by count instead', (tester) async {
      stateManager.set('picked', ['r', 'b']);
      await pump(tester, multi(extra: {'showChips': false}));

      expect(find.byType(Chip), findsNothing);
      expect(find.text('2 selected'), findsOneWidget);
    });

    testWidgets('an empty selection shows the placeholder', (tester) async {
      await pump(tester, multi(extra: {'placeholder': 'Pick some colours'}));
      expect(find.text('Pick some colours'), findsOneWidget);
    });

    testWidgets('maxSelections disables the rest rather than dropping a pick',
        (tester) async {
      stateManager.set('picked', ['r']);
      await pump(tester, multi(extra: {'maxSelections': 1}));

      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      final tiles = tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .toList();
      final green = tiles.firstWhere((t) => (t.title as Text).data == 'Green');
      final red = tiles.firstWhere((t) => (t.title as Text).data == 'Red');

      expect(green.onChanged, isNull,
          reason: '§2.6.25 — at the ceiling the unselected rows are disabled, '
              'so the user can see why nothing happens');
      expect(red.onChanged, isNotNull,
          reason: 'and what is already picked can still be un-picked, or the '
              'user is stuck');
    });

    testWidgets('selectAll picks everything and Clear empties it',
        (tester) async {
      await pump(tester, multi(extra: {'selectAll': true}));

      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Select all'));
      await tester.pumpAndSettle();
      expect(stateManager.get('picked'), ['r', 'g', 'b']);

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(stateManager.get('picked'), isEmpty);
    });

    testWidgets('searchable narrows the option list', (tester) async {
      await pump(tester, multi(extra: {'searchable': true}));

      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'gre');
      await tester.pumpAndSettle();

      expect(find.text('Green'), findsOneWidget);
      expect(find.text('Red'), findsNothing);
    });

    testWidgets('onChange fires with the new list', (tester) async {
      await pump(tester, multi(extra: {
        'onChange': {
          'type': 'state',
          'action': 'set',
          'binding': 'lastChange',
          'value': '{{event.value}}',
        },
      }));

      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blue'));
      await tester.pumpAndSettle();

      expect(stateManager.get('lastChange'), ['b']);
    });

    testWidgets('a disabled multiSelect does not open', (tester) async {
      await pump(tester, multi(extra: {'enabled': false}));

      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      expect(find.byType(CheckboxListTile), findsNothing);
    });

    testWidgets('a bound value that is not a list reads as empty',
        (tester) async {
      stateManager.set('picked', 'still loading');
      await pump(tester, multi(extra: {'placeholder': 'none yet'}));
      expect(find.text('none yet'), findsOneWidget);
    });
  });

  group('numberField', () {
    Map<String, dynamic> number({Map<String, dynamic> extra = const {}}) => {
          'type': 'numberField',
          'binding': 'qty',
          ...extra,
        };

    testWidgets('typing writes a number, not a string', (tester) async {
      await pump(tester, number());

      await tester.enterText(find.byType(TextField), '42');
      await tester.pumpAndSettle();

      expect(stateManager.get('qty'), 42,
          reason: 'a numeric field writing "42" makes every downstream '
              'comparison a string comparison');
    });

    testWidgets('decimals are kept when the field declares them',
        (tester) async {
      await pump(tester, number(extra: {'decimals': 2}));

      await tester.enterText(find.byType(TextField), '3.5');
      await tester.pumpAndSettle();

      expect(stateManager.get('qty'), 3.5);
    });

    testWidgets('what is not part of a number is dropped, and the rest kept',
        (tester) async {
      await pump(tester, number());

      // Typed, then a paste that carries letters. The filter used to match
      // the WHOLE field against `^-?\d*$`, and a string that does not match
      // in full yields no matches — so it kept NOTHING: the digits already in
      // the field went too. An earlier reading of this called it "refused in
      // one piece and the field stays as it was"; it did not stay, it
      // emptied, which is why this now types first and pastes second.
      await tester.enterText(find.byType(TextField), '12');
      await tester.pump();
      expect(stateManager.get('qty'), 12);

      await tester.enterText(find.byType(TextField), '12abc3');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, '12abc3'), findsNothing,
          reason: 'the letters are not part of a number');
      expect(stateManager.get('qty'), 123,
          reason: 'dropping the offending characters is what a character '
              'filter is for; emptying the field takes away digits the user '
              'had already entered');
    });

    testWidgets('clearing the field writes null rather than zero',
        (tester) async {
      stateManager.set('qty', 5);
      await pump(tester, number());

      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      expect(stateManager.get('qty'), isNull,
          reason: 'an empty field means "not answered"; zero is an answer');
    });

    testWidgets('the stepper adds and subtracts by the declared step',
        (tester) async {
      stateManager.set('qty', 10);
      await pump(tester, number(extra: {'step': 5}));

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(stateManager.get('qty'), 15);

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();
      expect(stateManager.get('qty'), 10);
    });

    testWidgets('the stepper stops at min and max', (tester) async {
      stateManager.set('qty', 1);
      await pump(tester, number(extra: {'min': 1, 'max': 2}));

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();
      expect(stateManager.get('qty'), 1,
          reason: 'a stepper that walks past its own minimum makes the bound '
              'decorative');

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(stateManager.get('qty'), 2);
    });

    testWidgets('showStepper: false leaves keyboard entry only',
        (tester) async {
      await pump(tester, number(extra: {'showStepper': false}));
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('a thousand separator is shown, and the stepper still counts '
        'from the real number', (tester) async {
      // The stepper parses the CONTROLLER TEXT. With a separator in it,
      // `num.tryParse` answers null and the arithmetic starts from zero — so
      // stepping a formatted 1,000 would land on 1 rather than 1,001.
      stateManager.set('qty', 1000);
      await pump(tester, number(extra: {'thousandSeparator': ','}));

      expect(find.text('1,000'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(stateManager.get('qty'), 1001,
          reason: 'the separator is presentation; the step is arithmetic on '
              'the value');
    });

    testWidgets('a format pattern wraps the displayed value', (tester) async {
      stateManager.set('qty', 12);
      await pump(tester, number(extra: {'format': '{value} kg'}));
      expect(find.text('12 kg'), findsOneWidget);
    });

    testWidgets('label, hint, prefix and suffix reach the decoration',
        (tester) async {
      await pump(tester, number(extra: {
        'label': 'Quantity',
        'helperText': 'per box',
        'prefix': '#',
        'suffix': 'kg',
      }));

      expect(find.text('Quantity'), findsOneWidget);
      expect(find.text('per box'), findsOneWidget);
      expect(find.text('#'), findsOneWidget);
      expect(find.text('kg'), findsOneWidget);
    });

    testWidgets('a disabled field takes no input and its stepper is dead',
        (tester) async {
      await pump(tester, number(extra: {'enabled': false, 'step': 1}));

      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      final add = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.add));
      expect(add.onPressed, isNull);
    });

    testWidgets('onChange fires with the parsed value', (tester) async {
      await pump(tester, number(extra: {
        'onChange': {
          'type': 'state',
          'action': 'set',
          'binding': 'seen',
          'value': '{{event.value}}',
        },
      }));

      await tester.enterText(find.byType(TextField), '7');
      await tester.pumpAndSettle();

      expect(stateManager.get('seen'), 7);
    });
  });
  group('numberField, formatted', () {
    Map<String, dynamic> money({Map<String, dynamic> extra = const {}}) =>
        <String, dynamic>{
          'type': 'numberField',
          'binding': 'amount',
          'decimals': 2,
          ...extra,
        };

    testWidgets('a declared decimal count is shown, not just stored',
        (tester) async {
      stateManager.set('amount', 12.5);
      await pump(tester, money());

      expect(find.text('12.50'), findsOneWidget,
          reason: 'a price field that shows 12.5 where the document asked for '
              'two decimals reads as a different number');
    });

    testWidgets('a value that arrived as a string is still formatted',
        (tester) async {
      stateManager.set('amount', '12.5');
      await pump(tester, money());

      expect(find.text('12.50'), findsOneWidget,
          reason: 'a binding fed from a server produces a string; falling '
              'back to the raw text drops the formatting the document asked '
              'for');
    });

    testWidgets('a value that is not a number at all is shown as it is',
        (tester) async {
      stateManager.set('amount', 'n/a');
      await pump(tester, money());

      expect(find.text('n/a'), findsOneWidget,
          reason: 'blanking a value the field cannot parse hides what the '
              'state actually holds');
    });

    testWidgets('typing a decimal writes a double', (tester) async {
      await pump(tester, money());

      await tester.enterText(find.byType(TextField), '3.25');
      await tester.pump();

      expect(stateManager.get('amount'), 3.25,
          reason: 'parsing a decimal field as an integer truncates the money');
    });

    testWidgets('the stepper keeps the decimals', (tester) async {
      stateManager.set('amount', 1.0);
      await pump(tester, money(extra: <String, dynamic>{'step': 0.25}));

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(stateManager.get('amount'), 1.25);
      expect(find.text('1.25'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();

      expect(stateManager.get('amount'), 1.0);
      expect(find.text('1.00'), findsOneWidget,
          reason: 'a stepper that drops back to "1" changes how the field '
              'reads between one press and the next');
    });

    testWidgets('a thousand separator is displayed and stripped on the way '
        'back', (tester) async {
      stateManager.set('qty', 1234567);
      await pump(tester, <String, dynamic>{
        'type': 'numberField',
        'binding': 'qty',
        'thousandSeparator': ',',
      });

      expect(find.text('1,234,567'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '7,654');
      await tester.pump();

      expect(stateManager.get('qty'), 7654,
          reason: 'reading the separator as part of the number gives a parse '
              'failure and a field that silently stops writing');
    });

    testWidgets('a stray keystroke is dropped, not the whole number',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'numberField',
        'binding': 'qty',
      });

      await tester.enterText(find.byType(TextField), '12a3');
      await tester.pump();

      expect(find.text('123'), findsOneWidget,
          reason: 'a filter that answers "this whole string is not a number" '
              'by emptying the field takes away what the user had already '
              'typed; it is there to drop the character');
      expect(stateManager.get('qty'), 123);
    });

    testWidgets('a negative number keeps its sign through the separator',
        (tester) async {
      stateManager.set('qty', -1234);
      await pump(tester, <String, dynamic>{
        'type': 'numberField',
        'binding': 'qty',
        'thousandSeparator': ',',
      });

      expect(find.text('-1,234'), findsOneWidget,
          reason: 'grouping the minus sign in with the digits turns a debit '
              'into something unreadable');
    });
  });
}
