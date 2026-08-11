// A `textInput` that declares `debounce`.
//
// There are two field builders in this factory and they are chosen by that one
// property: an ordinary field goes through the stateful builder, and a
// debounced one through a different path that rebuilds the inner field on
// every keystroke. The second was the uncovered one — which means the search
// box, the filter field, and every input that talks to a server on change.
//
// The tests type character by character and watch the clock, because that is
// the whole point of the property: the state must NOT move until the user
// stops, and it must move afterwards.

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

  Map<String, dynamic> field({Map<String, dynamic> extra = const {}}) => {
        'type': 'textInput',
        'binding': 'query',
        'debounce': 300,
        ...extra,
      };

  group('the delay itself', () {
    testWidgets('typing does not reach state until the user stops',
        (tester) async {
      await pump(tester, field());

      await tester.enterText(find.byType(TextField), 'ad');
      await tester.pump(const Duration(milliseconds: 100));

      expect(stateManager.get('query'), isNull,
          reason: 'writing on every keystroke is exactly what `debounce` '
              'exists to prevent — one request per character');

      await tester.pump(const Duration(milliseconds: 400));
      expect(stateManager.get('query'), 'ad');
    });

    testWidgets('only the last value survives a burst', (tester) async {
      var writes = 0;
      stateManager.addListener(() => writes++);

      await pump(tester, field());
      for (final text in ['a', 'ad', 'ada']) {
        await tester.enterText(find.byType(TextField), text);
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 400));

      expect(stateManager.get('query'), 'ada');
      expect(writes, lessThanOrEqualTo(2),
          reason: 'three keystrokes must not become three round trips');
    });

    testWidgets('what was typed is on screen immediately, whatever the delay',
        (tester) async {
      await pump(tester, field());

      await tester.enterText(find.byType(TextField), 'ada');
      await tester.pump();

      expect(find.text('ada'), findsOneWidget,
          reason: 'a field that lags behind the keyboard is unusable however '
              'correct the state eventually is');
    });

    testWidgets('onChange fires once, after the delay, with the value',
        (tester) async {
      await pump(tester, field(extra: {
        'onChange': {
          'type': 'state',
          'action': 'set',
          'binding': 'lastEvent',
          'value': '{{event.value}}',
        },
      }));

      await tester.enterText(find.byType(TextField), 'ada');
      await tester.pump(const Duration(milliseconds: 100));
      expect(stateManager.get('lastEvent'), isNull);

      await tester.pump(const Duration(milliseconds: 400));
      expect(stateManager.get('lastEvent'), 'ada');
    });

    testWidgets('a validation rule runs on the debounced value',
        (tester) async {
      await pump(tester, field(extra: {
        'validation': [
          {'type': 'required', 'message': 'Required'},
        ],
      }));

      await tester.enterText(find.byType(TextField), 'ada');
      await tester.pump(const Duration(milliseconds: 400));

      expect(stateManager.get('query'), 'ada');
      expect(tester.takeException(), isNull);
    });
  });

  group('the rest of the field still works on this path', () {
    testWidgets('submitting writes immediately and fires onSubmit',
        (tester) async {
      await pump(tester, field(extra: {
        'onSubmit': {
          'type': 'state',
          'action': 'set',
          'binding': 'submitted',
          'value': '{{event.value}}',
        },
      }));

      await tester.enterText(find.byType(TextField), 'ada');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(stateManager.get('submitted'), 'ada',
          reason: 'pressing enter is the user saying they have stopped — '
              'making them wait out the debounce as well is the wrong reading');
    });

    testWidgets('focus and blur are reported', (tester) async {
      await pump(tester, field(extra: {
        'onFocus': {
          'type': 'state',
          'action': 'set',
          'binding': 'phase',
          'value': 'focused',
        },
        'onBlur': {
          'type': 'state',
          'action': 'set',
          'binding': 'phase',
          'value': 'blurred',
        },
      }));

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(stateManager.get('phase'), 'focused');

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(stateManager.get('phase'), 'blurred',
          reason: 'a form that never hears about blur cannot validate a field '
              'the user has left');
    });

    testWidgets('an initial value comes from the binding', (tester) async {
      stateManager.set('query', 'seeded');
      await pump(tester, field());

      expect(find.text('seeded'), findsOneWidget);
    });

    testWidgets('label, hint and helper reach the decoration', (tester) async {
      await pump(tester, field(extra: {
        'label': 'Search',
        'hint': 'name or id',
        'helperText': 'at least two characters',
      }));

      final decoration =
          tester.widget<TextField>(find.byType(TextField)).decoration!;
      expect(decoration.labelText, 'Search');
      expect(decoration.hintText, 'name or id');
      expect(decoration.helperText, 'at least two characters');
    });

    testWidgets('an error string is shown as the error', (tester) async {
      await pump(tester, field(extra: {'error': 'No such record'}));

      expect(
          tester.widget<TextField>(find.byType(TextField)).decoration!.errorText,
          'No such record');
    });

    testWidgets('error: true takes the message from errorText', (tester) async {
      await pump(tester, field(extra: {
        'error': true,
        'errorText': 'Not a valid id',
      }));

      expect(
          tester.widget<TextField>(find.byType(TextField)).decoration!.errorText,
          'Not a valid id',
          reason: 'the boolean form is how a document binds the error state to '
              'a validation flag it already holds');
    });

    testWidgets('prefix and suffix icons are drawn', (tester) async {
      await pump(tester, field(extra: {
        'prefixIcon': 'search',
        'suffixIcon': 'close',
      }));

      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('a declared style reaches the text', (tester) async {
      await pump(tester, field(extra: {
        'style': {
          'fontSize': 22,
          'fontWeight': 'bold',
          'fontStyle': 'italic',
          'color': '#FF0000',
          'letterSpacing': 1.5,
          'wordSpacing': 2.0,
          'height': 1.4,
        },
      }));

      final style = tester.widget<TextField>(find.byType(TextField)).style!;
      expect(style.fontSize, 22);
      expect(style.fontWeight, FontWeight.bold);
      expect(style.fontStyle, FontStyle.italic);
      expect(style.color, const Color(0xFFFF0000));
      expect(style.letterSpacing, 1.5);
      expect(style.wordSpacing, 2.0);
      expect(style.height, 1.4);
    });

    testWidgets('maxLength, maxLines, readOnly and enabled are applied',
        (tester) async {
      await pump(tester, field(extra: {
        'maxLength': 10,
        'maxLines': 3,
        'readOnly': true,
        'enabled': false,
      }));

      final input = tester.widget<TextField>(find.byType(TextField));
      expect(input.maxLength, 10);
      expect(input.maxLines, 3);
      expect(input.readOnly, isTrue);
      expect(input.enabled, isFalse);
    });

    testWidgets('showToggle offers a reveal control that flips the field',
        (tester) async {
      await pump(tester, field(extra: {
        'obscureText': true,
        'showToggle': true,
      }));

      expect(tester.widget<TextField>(find.byType(TextField)).obscureText,
          isTrue);
      expect(find.byIcon(Icons.visibility), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(find.byType(TextField)).obscureText,
          isFalse,
          reason: '§2.6.5 — a reveal control that does not reveal is a button '
              'that lies about what it does');
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    testWidgets('defaultCountry seeds the dialling prefix on an empty field',
        (tester) async {
      await pump(tester, field(extra: {
        'inputType': 'phone',
        'defaultCountry': 'KR',
      }));

      expect(find.textContaining('+82'), findsOneWidget,
          reason: 'a phone field that names a country and shows no prefix '
              'makes the user type it, which is the thing the property was '
              'added to avoid — and showing it twice, once as decoration and '
              'once as content, is the other way to get it wrong');
    });

    testWidgets('defaultCountry does not overwrite an existing value',
        (tester) async {
      stateManager.set('query', '01012345678');
      await pump(tester, field(extra: {
        'inputType': 'phone',
        'defaultCountry': 'KR',
      }));

      expect(find.text('01012345678'), findsOneWidget);
    });

    testWidgets('the keyboard type follows inputType', (tester) async {
      await pump(tester, field(extra: {'inputType': 'email'}));

      expect(tester.widget<TextField>(find.byType(TextField)).keyboardType,
          TextInputType.emailAddress);
    });
  });
  // The debounced path used to take the finished widget apart and rebuild a
  // `TextField` around its own handler. That worked only while the result WAS
  // a `TextField` — a document that also declared a common wrapper got the
  // built field back untouched, driven by a different controller than the one
  // holding the debounced value.
  group('a debounced field inside a wrapper', () {
    testWidgets('still debounces, and still writes once', (tester) async {
      await pump(tester, field(extra: <String, dynamic>{
        'tooltip': 'Search the catalogue',
        'change': <String, dynamic>{
          'type': 'state',
          'action': 'increment',
          'binding': 'writes',
          'value': 1,
        },
      }));
      stateManager.set('writes', 0);

      await tester.enterText(find.byType(TextField), 'a');
      await tester.enterText(find.byType(TextField), 'ab');
      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump(const Duration(milliseconds: 50));

      expect(stateManager.get<int>('writes'), 0,
          reason: 'three keystrokes inside the window are one search, not '
              'three — which is the whole reason the document asked for a '
              'debounce');

      await tester.pump(const Duration(milliseconds: 400));

      expect(stateManager.get<int>('writes'), 1);
      expect(stateManager.get<String>('query'), 'abc');
    });

    testWidgets('the wrapper itself survives', (tester) async {
      await pump(tester, field(extra: <String, dynamic>{
        'tooltip': 'Search the catalogue',
      }));

      expect(find.byType(Tooltip), findsWidgets,
          reason: 'a rebuild that only knew how to copy a TextField dropped '
              'everything the document had wrapped around it');
    });

    testWidgets('a hidden debounced field is hidden', (tester) async {
      await pump(tester, field(extra: <String, dynamic>{'visible': false}));

      expect(find.byType(TextField), findsNothing,
          reason: '`visible: false` is not advice');
    });
  });
}
