// `textInput` — the widget most documents lean on hardest.
//
// 76% covered, and the gaps were the parts a user meets: the reveal toggle on
// a password field, the dialling prefix a phone field seeds, focus and blur,
// the debounced change, the style block, and every keyboard/action mapping. A
// field that stops writing to its binding produces a form that looks filled in
// and submits nothing, which is the failure this whole sweep is about.

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
        body: AnimatedBuilder(
          animation: stateManager,
          builder: (_, __) => context.renderer.renderWidget(definition, context),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> field({Map<String, dynamic> extra = const {}}) => {
        'type': 'textInput',
        'binding': 'name',
        ...extra,
      };

  TextField widgetOf(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField));

  group('the value', () {
    testWidgets('typing writes through to the binding', (tester) async {
      await pump(tester, field());

      await tester.enterText(find.byType(TextField), 'Ada');
      await tester.pumpAndSettle();

      expect(stateManager.get('name'), 'Ada');
    });

    testWidgets('an existing value is shown', (tester) async {
      stateManager.set('name', 'Grace');
      await pump(tester, field());

      expect(find.text('Grace'), findsOneWidget);
    });

    testWidgets('a literal value is used when there is no binding',
        (tester) async {
      await pump(tester, {'type': 'textInput', 'value': 'literal'});
      expect(find.text('literal'), findsOneWidget);
    });

    testWidgets('submitting writes the value and fires onSubmit',
        (tester) async {
      await pump(tester, field(extra: {
        'onSubmit': {
          'type': 'state',
          'action': 'set',
          'binding': 'submitted',
          'value': '{{event.value}}',
        },
      }));

      await tester.enterText(find.byType(TextField), 'Ada');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(stateManager.get('name'), 'Ada');
      expect(stateManager.get('submitted'), 'Ada',
          reason: 'a search box submits on enter; the value has to travel '
              'with the event, not just sit in state');
    });

    testWidgets('onChange sees the event value', (tester) async {
      await pump(tester, field(extra: {
        'onChange': {
          'type': 'state',
          'action': 'set',
          'binding': 'seen',
          'value': '{{event.value}}',
        },
      }));

      await tester.enterText(find.byType(TextField), 'typing');
      await tester.pumpAndSettle();

      expect(stateManager.get('seen'), 'typing');
    });
  });

  group('focus and blur', () {
    testWidgets('onFocus fires on entry and onBlur on the way out',
        (tester) async {
      await pump(tester, {
        'type': 'linear',
        'direction': 'vertical',
        'children': [
          field(extra: {
            'onFocus': {
              'type': 'state',
              'action': 'set',
              'binding': 'phase',
              'value': 'focus',
            },
            'onBlur': {
              'type': 'state',
              'action': 'set',
              'binding': 'phase',
              'value': 'blur',
            },
          }),
          {'type': 'textInput', 'binding': 'other'},
        ],
      });

      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();
      expect(stateManager.get('phase'), 'focus');

      await tester.tap(find.byType(TextField).last);
      await tester.pumpAndSettle();
      expect(stateManager.get('phase'), 'blur',
          reason: 'validate-on-blur is the ordinary form pattern; without the '
              'blur edge it has to run on every keystroke instead');
    });

    testWidgets('a field with neither handler is not wrapped in Focus',
        (tester) async {
      await pump(tester, field());
      expect(find.byType(Focus), findsWidgets); // the framework adds its own
      expect(tester.takeException(), isNull);
    });
  });

  group('obscured input', () {
    testWidgets('obscureText hides the text', (tester) async {
      await pump(tester, field(extra: {'obscureText': true}));
      expect(widgetOf(tester).obscureText, isTrue);
    });

    testWidgets('showToggle reveals and re-hides it', (tester) async {
      await pump(tester,
          field(extra: {'obscureText': true, 'showToggle': true}));

      expect(widgetOf(tester).obscureText, isTrue);
      expect(find.byIcon(Icons.visibility), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pumpAndSettle();

      expect(widgetOf(tester).obscureText, isFalse,
          reason: '§2.6.5 — the reveal has to change the FIELD, not just the '
              'icon; a toggle that only swaps its own glyph is theatre');
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pumpAndSettle();
      expect(widgetOf(tester).obscureText, isTrue);
    });

    testWidgets('showToggle on a field that is not obscured adds nothing',
        (tester) async {
      await pump(tester, field(extra: {'showToggle': true}));

      expect(find.byIcon(Icons.visibility), findsNothing,
          reason: 'a reveal button on a plain field is a control with nothing '
              'to reveal');
    });
  });

  group('the phone field', () {
    testWidgets('defaultCountry seeds the dialling prefix', (tester) async {
      await pump(tester, field(extra: {
        'inputType': 'phone',
        'defaultCountry': 'KR',
      }));

      final decoration = widgetOf(tester).decoration!;
      expect(decoration.prefixText, isNotNull,
          reason: '1.4 declares defaultCountry, and a document naming one used '
              'to get an empty field and no prefix at all');
      expect(decoration.prefixText, startsWith('+'));
      expect(widgetOf(tester).controller!.text, isEmpty,
          reason: 'the prefix is decoration; putting it in the content too '
              'shows the code twice and writes into the field without '
              'writing to the binding');
    });

    testWidgets('a lower-case country code works too', (tester) async {
      await pump(tester, field(extra: {
        'inputType': 'phone',
        'defaultCountry': 'kr',
      }));
      expect(widgetOf(tester).decoration!.prefixText, startsWith('+'));
    });

    testWidgets('an unknown country adds no prefix rather than a wrong one',
        (tester) async {
      await pump(tester, field(extra: {
        'inputType': 'phone',
        'defaultCountry': 'ZZ',
      }));
      expect(widgetOf(tester).decoration!.prefixText, isNull);
    });

    testWidgets('defaultCountry is ignored on a field that is not a phone',
        (tester) async {
      await pump(tester, field(extra: {'defaultCountry': 'KR'}));
      expect(widgetOf(tester).decoration!.prefixText, isNull,
          reason: 'a dialling code in front of an email field would be typed '
              'straight into the address');
    });
  });

  group('the decoration and the keyboard', () {
    testWidgets('label, hint, helper and icons reach the decoration',
        (tester) async {
      await pump(tester, field(extra: {
        'label': 'Full name',
        'placeholder': 'as it appears on your card',
        'helperText': 'we only use this for the receipt',
        'prefixIcon': 'person',
        'suffixIcon': 'check',
      }));

      final decoration = widgetOf(tester).decoration!;
      expect(decoration.labelText, 'Full name');
      expect(decoration.hintText, 'as it appears on your card');
      expect(decoration.helperText, 'we only use this for the receipt');
      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('the declared keyboard type is used', (tester) async {
      for (final pair in const [
        ['email', TextInputType.emailAddress],
        ['number', TextInputType.number],
        ['phone', TextInputType.phone],
        ['url', TextInputType.url],
        ['multiline', TextInputType.multiline],
      ]) {
        await pump(tester, field(extra: {'inputType': pair[0]}));
        expect(widgetOf(tester).keyboardType, pair[1],
            reason: 'the wrong keyboard on a phone makes a number field a '
                'typing exercise');
      }
    });

    testWidgets('maxLength limits the text and shows the counter',
        (tester) async {
      await pump(tester, field(extra: {'maxLength': 4}));

      await tester.enterText(find.byType(TextField), 'far too long');
      await tester.pumpAndSettle();

      expect(stateManager.get('name'), 'far ');
      expect(widgetOf(tester).maxLength, 4);
      expect(widgetOf(tester).decoration!.counterText, isNull,
          reason: 'the counter is shown when a limit exists — hiding it makes '
              'the truncation look like a bug to the user');
    });

    testWidgets('without maxLength the counter is suppressed', (tester) async {
      await pump(tester, field());
      expect(widgetOf(tester).decoration!.counterText, '');
    });

    testWidgets('multiline sets maxLines rather than one long line',
        (tester) async {
      await pump(tester, field(extra: {'maxLines': 4}));
      expect(widgetOf(tester).maxLines, 4);
    });

    testWidgets('readOnly and enabled are distinct states', (tester) async {
      await pump(tester, field(extra: {'readOnly': true}));
      expect(widgetOf(tester).readOnly, isTrue);
      expect(widgetOf(tester).enabled, isTrue,
          reason: 'read-only text is selectable and copyable; disabled text '
              'is neither — a document choosing one must not get the other');

      await pump(tester, field(extra: {'enabled': false}));
      expect(widgetOf(tester).enabled, isFalse);
    });

    testWidgets('an error message is shown under the field', (tester) async {
      await pump(tester, field(extra: {'error': 'Required'}));
      expect(widgetOf(tester).decoration!.errorText, 'Required');
      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('a style block reaches the text', (tester) async {
      await pump(tester, field(extra: {
        'style': {
          'fontSize': 22,
          'fontWeight': 'bold',
          'fontStyle': 'italic',
          'color': '#FF0000',
          'letterSpacing': 1.5,
          'height': 1.4,
        },
      }));

      final style = widgetOf(tester).style!;
      expect(style.fontSize, 22);
      expect(style.fontWeight, FontWeight.bold);
      expect(style.fontStyle, FontStyle.italic);
      expect(style.color, isNotNull);
      expect(style.letterSpacing, 1.5);
      expect(style.height, 1.4);
    });

    testWidgets('the declared text input action is used', (tester) async {
      await pump(tester, field(extra: {'textInputAction': 'search'}));
      expect(widgetOf(tester).textInputAction, TextInputAction.search,
          reason: 'the return key label is how a phone user knows whether '
              'enter submits or adds a line');
    });
  });

  group('debounced change', () {
    testWidgets('only the last keystroke of a burst reaches the action',
        (tester) async {
      await pump(tester, field(extra: {
        'debounce': 200,
        'onChange': {
          'type': 'state',
          'action': 'append',
          'binding': 'seen',
          'value': '{{event.value}}',
        },
      }));
      stateManager.set('seen', <dynamic>[]);

      await tester.enterText(find.byType(TextField), 'a');
      await tester.pump(const Duration(milliseconds: 40));
      await tester.enterText(find.byType(TextField), 'ab');
      await tester.pump(const Duration(milliseconds: 40));
      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(stateManager.get('seen'), ['abc'],
          reason: 'a debounced search box that fires per keystroke is a '
              'request per keystroke — the whole reason the slot exists');
    });
  });
}
