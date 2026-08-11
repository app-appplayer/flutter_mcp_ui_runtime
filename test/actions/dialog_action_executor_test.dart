// `dialog` actions — checked by looking at the dialog.
//
// The previous version of this file ran every branch with no Navigator in the
// tree, so `DialogService` threw before drawing anything and each test settled
// for `expect(result, isA<ActionResult>())` — a matcher the executor cannot
// fail, since its return type IS ActionResult. Fourteen tests, no dialog ever
// shown, and a comment on several of them admitting it ("Either success:false
// or success:true depends on impl").
//
// A dialog is the one action whose entire purpose is to be seen and answered.
// So these mount a real MaterialApp on the navigator key `DialogService` uses,
// fire the action, and then read the barrier, the title, the buttons and what
// comes back when one is tapped.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_result.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/services/dialog_service.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ActionHandler actionHandler;
  late StateManager stateManager;
  late BindingEngine bindingEngine;
  late RenderContext context;

  setUp(() {
    actionHandler = ActionHandler();
    stateManager = StateManager()..initialize(<String, dynamic>{});
    bindingEngine = BindingEngine();
    final themeManager = ThemeManager.instance..reset();
    // The default widgets have to be in the registry: `customDialog` and
    // `bottomSheet` render a document-authored subtree, and an empty registry
    // would let those tests pass against a dialog with nothing in it.
    final widgetRegistry = WidgetRegistry();
    DefaultWidgets.registerAll(widgetRegistry);
    context = RenderContext(
      renderer: Renderer(
        widgetRegistry: widgetRegistry,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        stateManager: stateManager,
      ),
      stateManager: stateManager,
      bindingEngine: bindingEngine,
      actionHandler: actionHandler,
      themeManager: themeManager,
    );
  });

  tearDown(() {
    bindingEngine.dispose();
    stateManager.dispose();
  });

  /// Mounts an app on the navigator key `DialogService` reaches for.
  ///
  /// Without this the service throws before drawing, which is a legitimate
  /// case (see the last group) but tells you nothing about the dialog itself.
  Future<void> mountApp(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      navigatorKey: DialogService.navigatorKey,
      home: const Scaffold(body: Text('page')),
    ));
  }

  /// Fires the action WITHOUT awaiting it: `show` completes only when the
  /// dialog is dismissed, so awaiting here would deadlock the test.
  Future<ActionResult> fire(WidgetTester tester, Map<String, dynamic> action) {
    final pending = actionHandler.execute(action, context);
    return pending;
  }

  group('alert', () {
    testWidgets('the title and body the document wrote are on screen',
        (tester) async {
      await mountApp(tester);
      final pending = fire(tester, {
        'type': 'dialog',
        'dialog': {
          'type': 'alert',
          'title': 'Alert Title',
          'content': 'Alert message body',
        },
      });
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Alert Title'), findsOneWidget);
      expect(find.text('Alert message body'), findsOneWidget);

      // Close it, then read the answer the action gives the document back.
      Navigator.of(DialogService.navigatorKey.currentContext!).pop();
      await tester.pumpAndSettle();
      final result = await pending;
      expect(result.success, isTrue);
      expect(result.data, isTrue,
          reason: 'an alert that was shown reports `true`, which is how a '
              'document distinguishes shown from dismissed-without-showing');
    });

    testWidgets('each declared action becomes a button, and `close` closes',
        (tester) async {
      await mountApp(tester);
      final pending = fire(tester, {
        'type': 'dialog',
        'dialog': {
          'type': 'alert',
          'title': 'Confirm',
          'content': 'Are you sure?',
          'actions': [
            {'label': 'Cancel', 'action': 'close'},
            {'label': 'OK', 'action': 'close', 'primary': true},
          ],
        },
      });
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing,
          reason: 'a button labelled `close` that leaves the dialog up traps '
              'the user behind a modal barrier');
      await pending;
    });

    testWidgets('an action carrying a handler runs it after closing',
        (tester) async {
      await mountApp(tester);
      final pending = fire(tester, {
        'type': 'dialog',
        'dialog': {
          'type': 'alert',
          'content': 'Delete this?',
          'actions': [
            {
              'label': 'Delete',
              'onTap': {
                'type': 'state',
                'action': 'set',
                'binding': 'deleted',
                'value': true,
              },
            },
          ],
        },
      });
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(stateManager.get('deleted'), isTrue,
          reason: 'the handler is the whole reason for a confirm dialog');
      expect(find.byType(AlertDialog), findsNothing);
      await pending;
    });

    testWidgets('a `primary` action is marked as the default one',
        (tester) async {
      await mountApp(tester);
      final pending = fire(tester, {
        'type': 'dialog',
        'dialog': {
          'type': 'alert',
          'content': 'body',
          'actions': [
            {'label': 'Later', 'action': 'close'},
            {'label': 'Now', 'action': 'close', 'primary': true},
          ],
        },
      });
      await tester.pumpAndSettle();

      final now = tester.widget<Widget>(find.ancestor(
        of: find.text('Now'),
        matching: find.byWidgetPredicate(
            (w) => w is TextButton || w is ElevatedButton || w is FilledButton),
      ).first);
      final later = tester.widget<Widget>(find.ancestor(
        of: find.text('Later'),
        matching: find.byWidgetPredicate(
            (w) => w is TextButton || w is ElevatedButton || w is FilledButton),
      ).first);
      expect(now.runtimeType, isNot(later.runtimeType),
          reason: 'the emphasised action has to look different, or `primary` '
              'is a property the document sets and nobody sees');

      await tester.tap(find.text('Now'));
      await tester.pumpAndSettle();
      await pending;
    });

    testWidgets('with neither title nor body it still shows, empty',
        (tester) async {
      // Pinned: content defaults to an empty string rather than refusing. An
      // empty alert is a visible mistake; a refused one is an invisible one.
      await mountApp(tester);
      final pending = fire(tester, {
        'type': 'dialog',
        'dialog': {'type': 'alert'},
      });
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      Navigator.of(DialogService.navigatorKey.currentContext!).pop();
      await tester.pumpAndSettle();
      await pending;
    });

    testWidgets('a dialog block with no type is an alert', (tester) async {
      await mountApp(tester);
      final pending = fire(tester, {
        'type': 'dialog',
        'dialog': {'title': 'Default Type', 'content': 'no type given'},
      });
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('no type given'), findsOneWidget);

      Navigator.of(DialogService.navigatorKey.currentContext!).pop();
      await tester.pumpAndSettle();
      await pending;
    });

    testWidgets('bindings in the title and body are resolved before showing',
        (tester) async {
      await mountApp(tester);
      stateManager.set('dialogTitle', 'Dynamic Title');
      stateManager.set('dialogContent', 'Dynamic Content');

      final pending = fire(tester, {
        'type': 'dialog',
        'dialog': {
          'type': 'alert',
          'title': '{{dialogTitle}}',
          'content': '{{dialogContent}}',
        },
      });
      await tester.pumpAndSettle();

      expect(find.text('Dynamic Title'), findsOneWidget);
      expect(find.text('Dynamic Content'), findsOneWidget);
      expect(find.text('{{dialogTitle}}'), findsNothing,
          reason: 'showing the binding syntax to a user is the failure this '
              'replaces — the old test could not tell the two apart');

      Navigator.of(DialogService.navigatorKey.currentContext!).pop();
      await tester.pumpAndSettle();
      await pending;
    });

    testWidgets('a binding that resolves to nothing shows nothing, not braces',
        (tester) async {
      await mountApp(tester);
      final pending = fire(tester, {
        'type': 'dialog',
        'dialog': {
          'type': 'alert',
          'title': '{{nonExistent}}',
          'content': 'Static content',
        },
      });
      await tester.pumpAndSettle();

      expect(find.text('Static content'), findsOneWidget);
      expect(find.text('{{nonExistent}}'), findsNothing);

      Navigator.of(DialogService.navigatorKey.currentContext!).pop();
      await tester.pumpAndSettle();
      await pending;
    });

    testWidgets('dismissible: false keeps the barrier shut', (tester) async {
      await mountApp(tester);
      final pending = fire(tester, {
        'type': 'dialog',
        'dialog': {
          'type': 'alert',
          'content': 'you must answer',
          'dismissible': false,
          'actions': [
            {'label': 'OK', 'action': 'close'},
          ],
        },
      });
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(10, 10)); // outside the dialog
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget,
          reason: 'a document that says the answer is required must not be '
              'dismissable by tapping past it');

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await pending;
    });
  });

  group('simple', () {
    testWidgets('with no options it is an alert with a single OK',
        (tester) async {
      await mountApp(tester);
      final pending = fire(tester, {
        'type': 'dialog',
        'dialog': {
          'type': 'simple',
          'title': 'Information',
          'content': 'This is a simple message',
        },
      });
      await tester.pumpAndSettle();

      expect(find.text('Information'), findsOneWidget);
      expect(find.text('This is a simple message'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget,
          reason: 'without a button the only way out is the barrier, and a '
              'non-dismissible simple dialog would trap the user');

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      final result = await pending;
      expect(result.success, isTrue);
    });

    testWidgets('options become choices and the selection reaches onSelect',
        (tester) async {
      await mountApp(tester);
      final pending = fire(tester, {
        'type': 'dialog',
        'dialog': {
          'type': 'simple',
          'title': 'Pick one',
          'options': [
            {'label': 'Red', 'value': 'r'},
            {'label': 'Blue', 'value': 'b'},
          ],
          'onSelect': {
            'type': 'state',
            'action': 'set',
            'binding': 'colour',
            'value': '{{event.value}}',
          },
        },
      });
      await tester.pumpAndSettle();

      expect(find.text('Red'), findsOneWidget);
      expect(find.text('Blue'), findsOneWidget);

      await tester.tap(find.text('Blue'));
      await tester.pumpAndSettle();

      expect(stateManager.get('colour'), 'b',
          reason: 'the VALUE is what the document asked for, not the label — '
              'a chooser that reports the label is unusable for anything but '
              'display');
      await pending;
    });

    testWidgets('a body with no title still shows', (tester) async {
      await mountApp(tester);
      final pending = fire(tester, {
        'type': 'dialog',
        'dialog': {'type': 'simple', 'content': 'Message without title'},
      });
      await tester.pumpAndSettle();
      expect(find.text('Message without title'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await pending;
    });
  });

  group('custom', () {
    testWidgets('the child definition is rendered inside the dialog',
        (tester) async {
      await mountApp(tester);
      final pending = fire(tester, {
        'type': 'dialog',
        'dialog': {
          'type': 'custom',
          'title': 'Custom Dialog',
          'child': {'type': 'text', 'content': 'Custom content'},
        },
      });
      await tester.pumpAndSettle();

      expect(find.text('Custom content'), findsOneWidget,
          reason: 'a custom dialog exists to show a document-authored widget; '
              'a frame with nothing in it is the whole failure mode');
      expect(find.text('Custom Dialog'), findsOneWidget);

      Navigator.of(DialogService.navigatorKey.currentContext!).pop();
      await tester.pumpAndSettle();
      await pending;
    });

    testWidgets('with no child nothing is shown and the document is told',
        (tester) async {
      await mountApp(tester);
      final result = await actionHandler.execute({
        'type': 'dialog',
        'dialog': {'type': 'custom', 'title': 'No Child'},
      }, context);
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(result.success, isTrue);
      expect(result.data, isNull,
          reason: 'null data is the signal that nothing was shown — the same '
              'signal a dismissed dialog gives, which is why onDismiss fires '
              'for both');
    });

    testWidgets('onDismiss runs when nothing was shown', (tester) async {
      await mountApp(tester);
      stateManager.set('dismissed', false);

      final result = await actionHandler.execute({
        'type': 'dialog',
        'dialog': {'type': 'custom'},
        'onDismiss': {
          'type': 'state',
          'action': 'set',
          'binding': 'dismissed',
          'value': true,
        },
      }, context);

      expect(result.success, isTrue);
      expect(stateManager.get<bool>('dismissed'), isTrue);
    });

    testWidgets('no onDismiss and nothing shown is still a clean success',
        (tester) async {
      await mountApp(tester);
      final result = await actionHandler.execute({
        'type': 'dialog',
        'dialog': {'type': 'custom'},
      }, context);
      expect(result.success, isTrue);
    });

    testWidgets('dismissible: false keeps a custom dialog open on a barrier tap',
        (tester) async {
      await mountApp(tester);
      final pending = fire(tester, {
        'type': 'dialog',
        'dialog': {
          'type': 'custom',
          'title': 'Non-dismissible',
          'dismissible': false,
          'child': {'type': 'text', 'content': 'Cannot dismiss'},
        },
      });
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Cannot dismiss'), findsOneWidget);

      Navigator.of(DialogService.navigatorKey.currentContext!).pop();
      await tester.pumpAndSettle();
      await pending;
    });
  });

  group('bottomSheet', () {
    testWidgets('the child is rendered in a modal sheet', (tester) async {
      await mountApp(tester);
      final pending = fire(tester, {
        'type': 'dialog',
        'dialog': {
          'type': 'bottomSheet',
          'child': {'type': 'text', 'content': 'Sheet content'},
        },
      });
      await tester.pumpAndSettle();

      expect(find.text('Sheet content'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);

      Navigator.of(DialogService.navigatorKey.currentContext!).pop();
      await tester.pumpAndSettle();
      await pending;
    });

    testWidgets('with no child nothing opens and onDismiss runs',
        (tester) async {
      await mountApp(tester);
      stateManager.set('sheetDismissed', false);

      final result = await actionHandler.execute({
        'type': 'dialog',
        'dialog': {'type': 'bottomSheet'},
        'onDismiss': {
          'type': 'state',
          'action': 'set',
          'binding': 'sheetDismissed',
          'value': true,
        },
      }, context);

      expect(find.byType(BottomSheet), findsNothing);
      expect(result.success, isTrue);
      expect(result.data, isNull);
      expect(stateManager.get<bool>('sheetDismissed'), isTrue);
    });

    testWidgets('a six-digit background colour arrives opaque', (tester) async {
      // The regression this pins: the old local parser read `#RRGGBB` with
      // `int.parse` and no alpha, producing `0x00RRGGBB` — a sheet that asked
      // for a colour and rendered fully transparent. Reading the pixel colour
      // off the live BottomSheet is the only way to tell those apart.
      await mountApp(tester);
      final pending = fire(tester, {
        'type': 'dialog',
        'dialog': {
          'type': 'bottomSheet',
          'child': {'type': 'text', 'content': 'Styled sheet'},
          'enableDrag': false,
          'dismissible': false,
          'backgroundColor': '#FF5733',
        },
      });
      await tester.pumpAndSettle();

      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(sheet.backgroundColor, isNotNull);
      expect(sheet.backgroundColor!.a, 1.0,
          reason: 'a fully transparent sheet is indistinguishable from a '
              'missing one on screen, and the document asked for #FF5733');
      expect(sheet.enableDrag, isFalse);

      Navigator.of(DialogService.navigatorKey.currentContext!).pop();
      await tester.pumpAndSettle();
      await pending;
    });
  });

  group('snackBar', () {
    testWidgets('the message is shown and the action fires', (tester) async {
      await mountApp(tester);
      final result = await actionHandler.execute({
        'type': 'dialog',
        'dialog': {
          'type': 'snackBar',
          'content': 'Saved',
          'duration': 4000,
          'action': {
            'label': 'Undo',
            'onTap': {
              'type': 'state',
              'action': 'set',
              'binding': 'undone',
              'value': true,
            },
          },
        },
      }, context);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(result.success, isTrue);
      expect(find.text('Saved'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(stateManager.get('undone'), isTrue);
    });
  });

  group('the aliases in spec §2.11 all resolve', () {
    testWidgets('alertDialog, simpleDialog and customDialog', (tester) async {
      await mountApp(tester);

      final alert = fire(tester, {
        'type': 'dialog',
        'dialog': {'type': 'alertDialog', 'content': 'canonical alert'},
      });
      await tester.pumpAndSettle();
      expect(find.text('canonical alert'), findsOneWidget);
      Navigator.of(DialogService.navigatorKey.currentContext!).pop();
      await tester.pumpAndSettle();
      await alert;

      final simple = fire(tester, {
        'type': 'dialog',
        'dialog': {'type': 'simpleDialog', 'content': 'canonical simple'},
      });
      await tester.pumpAndSettle();
      expect(find.text('canonical simple'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await simple;

      final custom = fire(tester, {
        'type': 'dialog',
        'dialog': {
          'type': 'customDialog',
          'child': {'type': 'text', 'content': 'canonical custom'},
        },
      });
      await tester.pumpAndSettle();
      expect(find.text('canonical custom'), findsOneWidget);
      Navigator.of(DialogService.navigatorKey.currentContext!).pop();
      await tester.pumpAndSettle();
      await custom;
    });

    testWidgets('a legacy widget-shaped `content` still works as the child',
        (tester) async {
      await mountApp(tester);
      final pending = fire(tester, {
        'type': 'dialog',
        'dialog': {
          'type': 'custom',
          'content': {'type': 'text', 'content': 'legacy child'},
        },
      });
      await tester.pumpAndSettle();
      expect(find.text('legacy child'), findsOneWidget);

      Navigator.of(DialogService.navigatorKey.currentContext!).pop();
      await tester.pumpAndSettle();
      await pending;
    });
  });

  group('two dialogs at once', () {
    testWidgets('the second is refused rather than silently swallowed',
        (tester) async {
      // Found by this file: `DialogService.show` declines while another dialog
      // is up and answers null, and the alert branch set `result = true`
      // regardless — so a second tap, or a batch declaring two dialogs, told
      // the document the user had been asked when nothing was drawn. The
      // executor now checks first and reports (§6.13).
      await mountApp(tester);
      final first = fire(tester, {
        'type': 'dialog',
        'dialog': {'type': 'alert', 'content': 'first'},
      });
      await tester.pumpAndSettle();

      final second = await actionHandler.execute({
        'type': 'dialog',
        'dialog': {'type': 'alert', 'content': 'second'},
      }, context);

      expect(second.success, isFalse);
      expect(second.error, contains('already open'));
      await tester.pumpAndSettle();
      expect(find.text('first'), findsOneWidget);
      expect(find.text('second'), findsNothing);

      Navigator.of(DialogService.navigatorKey.currentContext!).pop();
      await tester.pumpAndSettle();
      await first;

      // And once it is closed, the next one shows normally.
      final third = fire(tester, {
        'type': 'dialog',
        'dialog': {'type': 'alert', 'content': 'third'},
      });
      await tester.pumpAndSettle();
      expect(find.text('third'), findsOneWidget);
      Navigator.of(DialogService.navigatorKey.currentContext!).pop();
      await tester.pumpAndSettle();
      await third;
    });
  });

  group('a dialog action that cannot be honoured', () {
    test('no `dialog` block at all is refused by name', () async {
      final result = await actionHandler.execute({'type': 'dialog'}, context);
      expect(result.success, isFalse);
      expect(result.error, contains('Dialog configuration is required'));
    });

    test('an explicit null block is the same refusal', () async {
      final result =
          await actionHandler.execute({'type': 'dialog', 'dialog': null}, context);
      expect(result.success, isFalse);
      expect(result.error, contains('Dialog configuration is required'));
    });

    test('an unknown type is refused and named', () async {
      final result = await actionHandler.execute({
        'type': 'dialog',
        'dialog': {'type': 'unknownType', 'title': 'Should Fail'},
      }, context);
      expect(result.success, isFalse);
      expect(result.error, contains('Unknown dialog type: unknownType'),
          reason: 'naming the type is what turns this into a one-line fix');
    });

    test('an empty type is refused rather than defaulted', () async {
      final result = await actionHandler.execute({
        'type': 'dialog',
        'dialog': {'type': '', 'title': 'Empty Type'},
      }, context);
      expect(result.success, isFalse);
      expect(result.error, contains('Unknown dialog type:'));
    });

    test('with no navigator in the tree the failure is reported, not thrown',
        () async {
      // A headless render — a dashboard tile, a background pass — has no
      // surface to show a dialog on. `DialogService` raises a StateError and
      // the executor turns it into an answer, which is what §6.13 requires:
      // the document is told the thing did not happen.
      final result = await actionHandler.execute({
        'type': 'dialog',
        'dialog': {'type': 'alert', 'title': 'nowhere to show this'},
      }, context);

      expect(result.success, isFalse);
      expect(result.error, isNotNull);
      expect(result.error, contains('Navigator'),
          reason: 'the message has to say what is missing, or a host sees '
              'only that the dialog "failed"');
    });
  });
}
