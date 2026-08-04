// Dialogs, actually shown.
//
// The dialog branches were the largest uncovered block left in
// `action_handler.dart`. They are the one action family whose result depends
// on a user pressing something, so nothing about them is observable until a
// dialog is on screen and a button is tapped: an `onTap` that never fires, or
// a `confirm` that always answers the same way, looks like a working dialog.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_mcp_ui_runtime/src/services/dialog_service.dart';

void main() {
  late MCPUIRuntime runtime;

  /// Mounts a MaterialApp on the navigator key the dialog service uses, so a
  /// dialog raised by an action has somewhere to appear.
  Future<void> mount(WidgetTester tester) async {
    runtime = MCPUIRuntime();
    await runtime.initialize(<String, dynamic>{
      'type': 'page',
      'state': <String, dynamic>{
        'initial': <String, dynamic>{'answer': 'none'}
      },
      'content': <String, dynamic>{'type': 'text', 'content': 'page'},
    });
    await tester.pumpWidget(MaterialApp(
      navigatorKey: DialogService.navigatorKey,
      home: Scaffold(body: runtime.buildUI()),
    ));
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> fire(Map<String, dynamic> action) async {
    // Not awaited: a dialog action completes when the dialog closes.
    // ignore: unawaited_futures
    runtime.engine.actionHandler
        .execute(action, runtime.engine.renderer.createRootContext(null));
  }

  tearDown(() async => runtime.destroy());

  testWidgets('an alert shows its title and content', (tester) async {
    await mount(tester);
    await fire(<String, dynamic>{
      'type': 'dialog',
      'action': 'show',
      'dialog': <String, dynamic>{
        'type': 'alert',
        'title': 'Saved',
        'content': 'Your changes are stored.',
      },
    });
    await tester.pumpAndSettle();

    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Your changes are stored.'), findsOneWidget);

    // Leave nothing open: the service refuses a second dialog while one is up,
    // so a test that walks away takes the next one down with it.
    Navigator.of(DialogService.navigatorKey.currentContext!).pop();
    await tester.pumpAndSettle();
  });

  testWidgets('an alert action runs its onTap handler', (tester) async {
    await mount(tester);
    await fire(<String, dynamic>{
      'type': 'dialog',
      'action': 'show',
      'dialog': <String, dynamic>{
        'type': 'alert',
        'title': 'Delete?',
        'content': 'This cannot be undone.',
        'actions': <dynamic>[
          <String, dynamic>{
            'label': 'Delete',
            'primary': true,
            'onTap': <String, dynamic>{
              'type': 'state',
              'action': 'set',
              'binding': 'answer',
              'value': 'deleted',
            },
          },
        ],
      },
    });
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(runtime.stateManager.get<String>('answer'), 'deleted',
        reason: 'a dialog button whose handler never runs is a dialog that '
            'asks a question and throws the answer away');
  });

  testWidgets('a title-only alert still renders', (tester) async {
    await mount(tester);
    await fire(<String, dynamic>{
      'type': 'dialog',
      'action': 'show',
      'dialog': <String, dynamic>{'type': 'alert', 'title': 'Heads up'},
    });
    await tester.pumpAndSettle();

    expect(find.text('Heads up'), findsOneWidget);
    Navigator.of(DialogService.navigatorKey.currentContext!).pop();
    await tester.pumpAndSettle();
  });

  testWidgets('the special handler "close" dismisses the dialog',
      (tester) async {
    await mount(tester);
    await fire(<String, dynamic>{
      'type': 'dialog',
      'action': 'show',
      'dialog': <String, dynamic>{
        'type': 'alertDialog',
        'title': 'Delete Item',
        'content': 'Are you sure?',
        'actions': <dynamic>[
          <String, dynamic>{'label': 'Cancel', 'onTap': 'close'},
        ],
      },
    });
    await tester.pumpAndSettle();
    expect(find.text('Delete Item'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Item'), findsNothing,
        reason: '§4.6 gives "close" as the handler that dismisses; a dialog '
            'that stays open has taken the answer and kept the question');
  });

  testWidgets('an unknown dialog type is reported rather than ignored',
      (tester) async {
    await mount(tester);
    final result = await runtime.engine.actionHandler.execute(
      <String, dynamic>{
        'type': 'dialog',
        'action': 'show',
        'dialog': <String, dynamic>{'type': 'telepathy', 'title': 'x'},
      },
      runtime.engine.renderer.createRootContext(null),
    );
    expect(result.success, isFalse);
    expect(result.error, contains('telepathy'));
  });

  testWidgets('a simple dialog carries each option value into onSelect',
      (tester) async {
    await mount(tester);
    await fire(<String, dynamic>{
      'type': 'dialog',
      'action': 'show',
      'dialog': <String, dynamic>{
        'type': 'simple',
        'title': 'Pick a lane',
        'options': <dynamic>[
          <String, dynamic>{'label': 'Left', 'value': 'L'},
          <String, dynamic>{'label': 'Right', 'value': 'R'},
        ],
        'onSelect': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'answer',
          'value': '{{event.value}}',
        },
      },
    });
    await tester.pumpAndSettle();

    expect(find.text('Left'), findsOneWidget);
    expect(find.text('Right'), findsOneWidget);

    await tester.tap(find.text('Right'));
    await tester.pumpAndSettle();

    expect(runtime.stateManager.get<String>('answer'), 'R',
        reason: 'the selected option has to reach the handler as `event.value`; '
            'without it every option does the same thing');
  });

  testWidgets('a dialog action with no dialog block is refused',
      (tester) async {
    await mount(tester);
    final result = await runtime.engine.actionHandler.execute(
      <String, dynamic>{'type': 'dialog', 'action': 'show'},
      runtime.engine.renderer.createRootContext(null),
    );
    expect(result.success, isFalse);
    expect(result.error, contains('Dialog configuration'));
  });
}
