// The prompt *widget* had 0 of 90 lines covered. `permission_prompt_test.dart`
// next to this file checks the data models; nothing had ever pressed one of
// these buttons, and they are what stands between a document and a user's
// files, network and shell.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/permissions/permission_prompt.dart';
import 'package:flutter_mcp_ui_runtime/src/permissions/permission_storage.dart';

void main() {
  /// Mounts a button that opens [show] and records what the dialog returns.
  Future<void> openPrompt(
    WidgetTester tester,
    Future<PermissionDecision?> Function(BuildContext context) show,
    void Function(PermissionDecision?) onResult,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async => onResult(await show(context)),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<PermissionDecision?> Function(BuildContext) fileRead(String path) =>
      (context) => PermissionPrompt.show(
            context: context,
            permissionType: 'file.read',
            title: 'File Read Permission',
            description: 'wants to read a file',
            scope: path,
            details: <String>['Path: $path'],
          );

  group('the three answers', () {
    testWidgets('Allow grants and carries the scope', (tester) async {
      PermissionDecision? decision;
      await openPrompt(tester, fileRead('/tmp/a.txt'), (d) => decision = d);

      expect(find.text('File Read Permission'), findsOneWidget);
      expect(find.text('Path: /tmp/a.txt'), findsOneWidget,
          reason: 'a user asked to grant access must be told to what');

      await tester.tap(find.widgetWithText(FilledButton, 'Allow'));
      await tester.pumpAndSettle();

      expect(decision, isNotNull);
      expect(decision!.granted, isTrue);
      expect(decision!.scope, '/tmp/a.txt');
    });

    testWidgets('Deny refuses', (tester) async {
      PermissionDecision? decision;
      await openPrompt(tester, fileRead('/tmp/a.txt'), (d) => decision = d);

      await tester.tap(find.widgetWithText(TextButton, 'Deny'));
      await tester.pumpAndSettle();

      expect(decision!.granted, isFalse);
    });

    testWidgets('Allow Once grants without remembering', (tester) async {
      PermissionDecision? decision;
      await openPrompt(tester, fileRead('/tmp/a.txt'), (d) => decision = d);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Allow Once'));
      await tester.pumpAndSettle();

      expect(decision!.granted, isTrue);
      expect(decision!.remember, isFalse,
          reason: '"once" is the whole difference from "Allow"');
    });

    testWidgets('the remember box travels with the decision', (tester) async {
      PermissionDecision? decision;
      await openPrompt(tester, fileRead('/tmp'), (d) => decision = d);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Allow'));
      await tester.pumpAndSettle();

      expect(decision!.remember, isTrue);
    });
  });

  testWidgets('a stray tap outside does not answer the question',
      (tester) async {
    await openPrompt(tester, fileRead('/tmp/a.txt'), (_) {});

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.text('File Read Permission'), findsOneWidget);
  });

  group('the typed prompts describe what they ask for', () {
    testWidgets('file access names the path and the direction',
        (tester) async {
      await openPrompt(
        tester,
        (context) => PermissionPrompt.showFileAccess(
            context: context, path: '/etc/hosts', isWrite: true),
        (_) {},
      );

      expect(find.text('File Write Permission'), findsOneWidget);
      expect(find.text('Path: /etc/hosts'), findsOneWidget);
    });

    testWidgets('http access records the host, not the whole url',
        (tester) async {
      PermissionDecision? decision;
      await openPrompt(
        tester,
        (context) => PermissionPrompt.showHttpAccess(
          context: context,
          url: 'https://api.example.com/v1/items?q=1',
          method: 'POST',
        ),
        (d) => decision = d,
      );

      expect(find.text('URL: https://api.example.com/v1/items?q=1'),
          findsOneWidget);
      expect(find.text('Method: POST'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Allow'));
      await tester.pumpAndSettle();

      expect(decision!.scope, 'api.example.com',
          reason: 'granting one request must not be recorded as granting one '
              'URL only, nor as granting the whole internet');
    });

    testWidgets('shell exec names the command and working directory',
        (tester) async {
      await openPrompt(
        tester,
        (context) => PermissionPrompt.showShellExec(
          context: context,
          command: 'rm -rf build',
          workingDir: '/repo',
        ),
        (_) {},
      );

      expect(find.text('Command: rm -rf build'), findsOneWidget);
      expect(find.text('Working Directory: /repo'), findsOneWidget);
    });
  });
}
