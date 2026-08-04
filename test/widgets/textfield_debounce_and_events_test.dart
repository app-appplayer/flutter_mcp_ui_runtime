// The debounced field, and the focus / blur / submit events.
//
// `debounce` exists so a keystroke does not become a server round-trip. Its
// two failure modes are opposite and both quiet: firing on every keystroke
// makes a search box hammer the backend, and never firing at all makes it look
// like the user typed nothing.

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

  group('debounce', () {
    testWidgets('holds the change until the window closes', (tester) async {
      await mount(
        tester,
        <String, dynamic>{
          'type': 'textField',
          'debounce': 300,
          'change': <String, dynamic>{
            'type': 'state',
            'action': 'set',
            'binding': 'q',
            'value': '{{event.value}}',
          },
        },
        initial: <String, dynamic>{'q': ''},
      );

      await tester.enterText(find.byType(TextField), 'ch');
      await tester.pump(const Duration(milliseconds: 100));
      expect(runtime.stateManager.get<String>('q'), '',
          reason: 'a debounced field that fires immediately is not debounced');

      await tester.pump(const Duration(milliseconds: 400));
      expect(runtime.stateManager.get<String>('q'), 'ch');
    });

    testWidgets('only the last value in a burst is delivered', (tester) async {
      final seen = <String>[];
      await mount(
        tester,
        <String, dynamic>{
          'type': 'textField',
          'debounce': 200,
          'change': <String, dynamic>{
            'type': 'state',
            'action': 'set',
            'binding': 'q',
            'value': '{{event.value}}',
          },
        },
        initial: <String, dynamic>{'q': ''},
      );
      runtime.stateManager.addListener(() {
        final v = runtime.stateManager.get<String>('q');
        if (v != null && v.isNotEmpty) seen.add(v);
      });

      await tester.enterText(find.byType(TextField), 'c');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.enterText(find.byType(TextField), 'ch');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.enterText(find.byType(TextField), 'che');
      await tester.pump(const Duration(milliseconds: 400));

      expect(seen, <String>['che'],
          reason: 'the point of the window is that the middle keystrokes '
              'never reach the handler');
    });

    testWidgets('typing still shows immediately while the change waits',
        (tester) async {
      await mount(tester, <String, dynamic>{
        'type': 'textField',
        'debounce': 500,
      });

      await tester.enterText(find.byType(TextField), 'visible');
      await tester.pump();

      expect(find.text('visible'), findsOneWidget,
          reason: 'debouncing the handler must not debounce the caret');
    });
  });

  group('events', () {
    testWidgets('submit fires on the keyboard action', (tester) async {
      await mount(
        tester,
        <String, dynamic>{
          'type': 'textField',
          'submit': <String, dynamic>{
            'type': 'state',
            'action': 'set',
            'binding': 'submitted',
            'value': '{{event.value}}',
          },
        },
        initial: <String, dynamic>{'submitted': ''},
      );

      await tester.enterText(find.byType(TextField), 'go');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(runtime.stateManager.get<String>('submitted'), 'go');
    });

    testWidgets('blur fires when focus leaves the field', (tester) async {
      await mount(
        tester,
        <String, dynamic>{
          'type': 'linear',
          'children': <dynamic>[
            <String, dynamic>{
              'type': 'textField',
              'blur': <String, dynamic>{
                'type': 'state',
                'action': 'set',
                'binding': 'blurred',
                'value': true,
              },
            },
            <String, dynamic>{'type': 'textField'},
          ],
        },
        initial: <String, dynamic>{'blurred': false},
      );

      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      await tester.tap(find.byType(TextField).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(runtime.stateManager.get<bool>('blurred'), isTrue,
          reason: 'blur is where a form validates what was just left; if it '
              'never fires the field is never checked');
    });
  });
}
