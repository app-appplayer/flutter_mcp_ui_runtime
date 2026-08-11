// ClientActionHandler — the confirmation surface, and the routing table.
//
// Two uncovered halves. The first is what happens when there IS a surface to
// ask on: the confirmation dialog, and the permission prompt behind it. The
// existing tests all run headless, which takes the other branch — so the
// "Confirm"/"Cancel" path had never been pressed, and a dialog that returns
// the wrong answer would have performed the action it was asking about.
//
// The second is the switch that picks an executor. Every arm that had not run
// is an action type a document can declare and get "Unknown client action"
// for, which is indistinguishable from a typo in the document.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/client_actions/client_action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/models/ui_definition.dart'
    show PermissionsConfig;
import 'package:flutter_mcp_ui_runtime/src/permissions/trust_level.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StateManager stateManager;
  late BindingEngine bindingEngine;
  late ActionHandler actionHandler;
  late Directory tmp;

  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    stateManager = StateManager()..initialize(<String, dynamic>{});
    bindingEngine = BindingEngine();
    actionHandler = ActionHandler();
    tmp = Directory.systemTemp.createTempSync('client_routing_');
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
    bindingEngine.dispose();
  });

  RenderContext contextFor(BuildContext? buildContext) => RenderContext(
        renderer: Renderer(
          widgetRegistry: WidgetRegistry(),
          bindingEngine: bindingEngine,
          actionHandler: actionHandler,
          stateManager: stateManager,
        ),
        stateManager: stateManager,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        themeManager: ThemeManager.instance,
        buildContext: buildContext,
      );

  /// Everything this document is allowed to do, so a refusal in these tests
  /// can only come from the branch under test.
  ///
  /// Full trust as well as configuration: the trust level is checked BEFORE
  /// the allowlists, and the default `basic` refuses `file.write` outright —
  /// a handler left at the default would never reach the branch under test.
  ClientActionHandler gated() {
    final handler = ClientActionHandler(
      PermissionsConfig.fromJson({
        'file.read': {
          'allowedPaths': [tmp.path],
        },
        'file.write': {
          'allowedPaths': [tmp.path],
        },
        'system.exec': {
          'allowedCommands': ['echo'],
        },
        'system.info': true,
      }),
    );
    handler.permissionManager.trustLevel = TrustLevel.full;
    return handler;
  }

  /// The same handler with the permission gate off.
  ///
  /// The gate has its own suite; leaving it on here would mean every test
  /// below also has to dismiss a permission prompt, and a hung prompt would
  /// look exactly like a routing failure. What is under test in this file is
  /// the confirmation the DOCUMENT asked for, and the switch that picks an
  /// executor.
  ClientActionHandler permissive() => gated()..permissionManager.enabled = false;

  group('what is not a client action', () {
    test('an action with no type is refused', () async {
      final result =
          await permissive().execute(<String, dynamic>{}, contextFor(null));

      expect(result.success, isFalse);
      expect(result.error, contains('type'));
    });

    test('a non-client action is refused by name', () async {
      final result = await permissive()
          .execute({'type': 'state', 'action': 'set'}, contextFor(null));

      expect(result.success, isFalse);
      expect(result.error, contains('state'),
          reason: 'routing a state action through the client handler would '
              'run it with the wrong permission model');
    });

    test('an unknown client.* action is named', () async {
      final result = await permissive()
          .execute({'type': 'client.teleport'}, contextFor(null));

      expect(result.success, isFalse);
      expect(result.error, contains('client.teleport'));
    });

    test('init() prepares the permission manager', () async {
      final handler = permissive();
      await handler.init();

      expect(handler.permissionManager, isNotNull);
    });
  });

  group('the confirmation dialog', () {
    /// Mounts an app and runs [body] with a live BuildContext.
    Future<void> withSurface(
      WidgetTester tester,
      Future<void> Function(BuildContext context) body,
    ) async {
      late BuildContext captured;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          captured = context;
          return const Scaffold(body: SizedBox());
        }),
      ));
      await body(captured);
    }

    /// A read of a path the document did not declare.
    ///
    /// Deliberately one the gate refuses OUTRIGHT — no prompt, no executor,
    /// no file touched. The confirmation is what is under test, and its two
    /// outcomes are then distinguishable by the error code alone: reaching
    /// the gate means the user confirmed, and never reaching it means they
    /// cancelled. (An action that actually wrote would need real file IO,
    /// which a widget test's fake-async zone never delivers.)
    Map<String, dynamic> undeclaredRead({
      String? confirmMessage,
      bool requireConfirmation = false,
      bool inParams = false,
    }) =>
        {
          'type': 'client.readFile',
          if (!inParams) 'path': '/etc/hosts',
          if (!inParams && confirmMessage != null)
            'confirmMessage': confirmMessage,
          if (requireConfirmation) 'requireConfirmation': true,
          if (inParams)
            'params': {
              'path': '/etc/hosts',
              if (confirmMessage != null) 'confirmMessage': confirmMessage,
            },
        };

    testWidgets('a declared confirmMessage is put in front of the user',
        (tester) async {
      await withSurface(tester, (buildContext) async {
        final pending = gated().execute(
            undeclaredRead(confirmMessage: 'Read the hosts file?'),
            contextFor(buildContext));

        await tester.pumpAndSettle();
        expect(find.text('Read the hosts file?'), findsOneWidget);
        expect(find.text('Confirmation Required'), findsOneWidget);

        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();

        final result = await pending;
        expect(result.errorCode, 'PERMISSION_DENIED',
            reason: 'confirming has to carry on to the gate — a Confirm that '
                'ends the action is a button that lies');
      });
    });

    testWidgets('cancelling ends the action there', (tester) async {
      await withSurface(tester, (buildContext) async {
        final pending = gated().execute(
            undeclaredRead(confirmMessage: 'Read the hosts file?'),
            contextFor(buildContext));

        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        final result = await pending;
        expect(result.success, isFalse);
        expect(result.errorCode, 'USER_CANCELLED',
            reason: 'a cancelled confirmation that still proceeds is the '
                'worst possible reading of the button the user pressed');
      });
    });

    testWidgets('requireConfirmation alone raises a default prompt',
        (tester) async {
      await withSurface(tester, (buildContext) async {
        final pending = gated()
            .execute(undeclaredRead(requireConfirmation: true), contextFor(buildContext));

        await tester.pumpAndSettle();
        expect(find.textContaining('Are you sure'), findsOneWidget);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect((await pending).errorCode, 'USER_CANCELLED');
      });
    });

    testWidgets('the message may be carried inside params', (tester) async {
      await withSurface(tester, (buildContext) async {
        final pending = gated().execute(
            undeclaredRead(confirmMessage: 'From params', inParams: true),
            contextFor(buildContext));

        await tester.pumpAndSettle();
        expect(find.text('From params'), findsOneWidget,
            reason: '§6 wraps parameters under `params`; a message read only '
                'from the top level would never be shown for a document '
                'written the spec\'s way');

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        await pending;
      });
    });

    testWidgets('with no confirmation declared, nothing is asked',
        (tester) async {
      await withSurface(tester, (buildContext) async {
        final result =
            await gated().execute(undeclaredRead(), contextFor(buildContext));

        expect(find.text('Confirmation Required'), findsNothing);
        expect(result.errorCode, 'PERMISSION_DENIED',
            reason: 'having somewhere to ask is not the same as being '
                'allowed');
      });
    });
  });

  group('the routing table', () {
    test('writeFile, readFile and listFiles each reach their executor',
        () async {
      final handler = permissive();
      final context = contextFor(null);

      final written = await handler.execute({
        'type': 'client.writeFile',
        'path': '${tmp.path}/a.txt',
        'content': 'one',
      }, context);
      expect(written.success, isTrue);

      final read = await handler.execute({
        'type': 'client.readFile',
        'path': '${tmp.path}/a.txt',
      }, context);
      expect(read.success, isTrue);

      final listed = await handler.execute({
        'type': 'client.listFiles',
        'path': tmp.path,
      }, context);
      expect(listed.success, isTrue,
          reason: 'an arm that falls through to the default answers "Unknown '
              'client action", which reads as a typo in the document');
    });

    test('saveFile reaches its executor', () async {
      final result = await permissive().execute({
        'type': 'client.saveFile',
        'path': '${tmp.path}/saved.txt',
        'content': 'saved',
      }, contextFor(null));

      // Whether a save dialog can open here is the host's business; what this
      // pins is that the action is ROUTED rather than rejected as unknown.
      expect(result.error ?? '', isNot(contains('Unknown client action')));
    });

    test('selectFile reaches its executor', () async {
      final result = await permissive()
          .execute({'type': 'client.selectFile'}, contextFor(null));

      expect(result.error ?? '', isNot(contains('Unknown client action')));
    });

    test('getSystemInfo answers with the platform', () async {
      final result = await permissive()
          .execute({'type': 'client.getSystemInfo'}, contextFor(null));

      expect(result.success, isTrue, reason: 'error was: ${result.error}');
      expect((result.data! as Map)['platform'], isNotNull);
    });

    test('exec reaches the shell executor for an allowed command', () async {
      final result = await permissive().execute({
        'type': 'client.exec',
        'command': 'echo',
        'args': ['routed'],
      }, contextFor(null));

      expect(result.success, isTrue, reason: 'error was: ${result.error}');
      expect((result.data! as Map)['stdout'], contains('routed'));
    });

    test('clipboard defaults to read, and `write` picks the other executor',
        () async {
      final handler = permissive();
      final context = contextFor(null);

      final read = await handler
          .execute({'type': 'client.clipboard'}, context);
      expect(read.error ?? '', isNot(contains('Unknown client action')));

      final write = await handler.execute({
        'type': 'client.clipboard',
        'params': {'action': 'write', 'text': 'copied'},
      }, context);
      expect(write.error ?? '', isNot(contains('Unknown client action')),
          reason: 'the read/write split is decided by params.action; reading '
              'the top level only would make every write a read');
    });

    test('notification reaches the system executor', () async {
      final result = await permissive().execute({
        'type': 'client.notification',
        'title': 'Done',
        'body': 'The job finished',
      }, contextFor(null));

      expect(result.error ?? '', isNot(contains('Unknown client action')));
    });

    test('storage get/set/remove all route to the storage executor', () async {
      final handler = permissive();
      final context = contextFor(null);

      for (final type in const [
        'client.storage.set',
        'client.storage.get',
        'client.storage.remove',
      ]) {
        final result = await handler.execute({
          'type': type,
          'key': 'k',
          'value': 'v',
        }, context);
        expect(result.error ?? '', isNot(contains('Unknown client action')),
            reason: type);
      }
    });
  });
}
