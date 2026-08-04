// `textfield` — the widget a form is made of, at 44%.
//
// Everything here is two-way: what the user types has to reach state, what
// state holds has to reach the field, and validation has to run on the value
// that actually arrives. Each failure is quiet in its own way — a field that
// never writes back looks like a user who did not type, and validation that
// never runs looks like input that was always valid.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  late MCPUIRuntime runtime;

  Future<void> mount(
    WidgetTester tester,
    Map<String, dynamic> field, {
    Map<String, dynamic>? initial,
  }) async {
    runtime = MCPUIRuntime();
    await runtime.initialize(<String, dynamic>{
      'type': 'page',
      if (initial != null) 'state': <String, dynamic>{'initial': initial},
      'content': field,
    });
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: runtime.buildUI())),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  tearDown(() async => runtime.destroy());

  group('two-way binding', () {
    testWidgets('typing reaches the bound state path', (tester) async {
      await mount(
        tester,
        <String, dynamic>{
          'type': 'textField',
          'label': 'Name',
          'value': '{{form.name}}',
          'change': <String, dynamic>{
            'type': 'state',
            'action': 'set',
            'binding': 'form.name',
            'value': '{{event.value}}',
          },
        },
        initial: <String, dynamic>{
          'form': <String, dynamic>{'name': ''}
        },
      );

      await tester.enterText(find.byType(TextField), 'cherry');
      await tester.pump();

      expect(runtime.stateManager.get<String>('form.name'), 'cherry');
    });

    testWidgets('an initial state value is shown in the field',
        (tester) async {
      await mount(
        tester,
        <String, dynamic>{
          'type': 'textField',
          'value': '{{form.name}}',
        },
        initial: <String, dynamic>{
          'form': <String, dynamic>{'name': 'preset'}
        },
      );

      expect(find.text('preset'), findsOneWidget,
          reason: 'a field bound to state that renders empty loses whatever '
              'the server already knew');
    });
  });

  group('decoration', () {
    testWidgets('label, hint and helper text all render', (tester) async {
      await mount(tester, <String, dynamic>{
        'type': 'textField',
        'label': 'Email',
        'placeholder': 'you@example.com',
        'helperText': 'work address',
      });

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('you@example.com'), findsOneWidget);
      expect(find.text('work address'), findsOneWidget);
    });

    testWidgets('an explicit error message is shown', (tester) async {
      // `error` carries the message; `errorText` is a legacy companion the
      // registry does not declare, so this uses the form a validated document
      // can rely on.
      await mount(tester, <String, dynamic>{
        'type': 'textField',
        'label': 'Email',
        'error': 'that address is taken',
      });

      expect(find.text('that address is taken'), findsOneWidget);
    });
  });

  group('input constraints', () {
    testWidgets('obscureText hides what is typed', (tester) async {
      await mount(tester, <String, dynamic>{
        'type': 'textField',
        'label': 'Password',
        'obscureText': true,
      });

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.obscureText, isTrue);
    });

    testWidgets('maxLength is applied to the field', (tester) async {
      await mount(tester, <String, dynamic>{
        'type': 'textField',
        'maxLength': 5,
      });

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLength, 5);
    });

    testWidgets('enabled: false stops input', (tester) async {
      await mount(tester, <String, dynamic>{
        'type': 'textField',
        'enabled': false,
      });

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
    });

    testWidgets('readOnly keeps the value visible but uneditable',
        (tester) async {
      await mount(
        tester,
        <String, dynamic>{
          'type': 'textField',
          'readOnly': true,
          'value': '{{v}}',
        },
        initial: <String, dynamic>{'v': 'locked'},
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.readOnly, isTrue);
      expect(find.text('locked'), findsOneWidget);
    });
  });

  group('validation', () {
    testWidgets('a required rule reports on an empty value', (tester) async {
      await mount(tester, <String, dynamic>{
        'type': 'textField',
        'label': 'Name',
        // §: validation is an array of typed rules.
        'validation': <dynamic>[
          <String, dynamic>{'type': 'required', 'message': 'name is required'},
        ],
      });

      await tester.enterText(find.byType(TextField), 'x');
      await tester.pump();
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      expect(find.text('name is required'), findsOneWidget,
          reason: 'validation that never runs looks like input that was '
              'always valid');
    });

    testWidgets('a minLength rule reports until it is satisfied',
        (tester) async {
      await mount(tester, <String, dynamic>{
        'type': 'textField',
        'validation': <dynamic>[
          <String, dynamic>{
            'type': 'minLength',
            'value': 4,
            'message': 'too short',
          },
        ],
      });

      await tester.enterText(find.byType(TextField), 'ab');
      await tester.pump();
      expect(find.text('too short'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'abcd');
      await tester.pump();
      expect(find.text('too short'), findsNothing);
    });
  });

  group('keyboard', () {
    testWidgets('inputType maps to a keyboard type', (tester) async {
      await mount(tester, <String, dynamic>{
        'type': 'textField',
        'keyboardType': 'number',
      });

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType, TextInputType.number);
    });

    testWidgets('maxLines drives a multi-line field', (tester) async {
      await mount(tester, <String, dynamic>{
        'type': 'textField',
        'maxLines': 4,
      });

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLines, 4);
    });
  });
}
