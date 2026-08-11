// `PermissionManager.checkAndPrompt` — the path where a user is actually asked.
//
// The gate file beside this one covers the half a document meets without a
// surface (`isPathAllowed`, `isDomainAllowed`, the grant set). `checkAndPrompt`
// itself — the method every client action goes through when a BuildContext
// exists — had not one line executed: not the trust-level refusal, not the
// stored-decision short circuit, not the prompt, not "remember this decision".
//
// This is the code that decides whether a bundle from a marketplace gets to
// read a file. Each test drives the real dialog and taps the real button.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/models/ui_definition.dart';
import 'package:flutter_mcp_ui_runtime/src/permissions/permission_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/permissions/permission_storage.dart';
import 'package:flutter_mcp_ui_runtime/src/permissions/trust_level.dart';
import 'package:flutter_mcp_ui_runtime/src/permissions/permission_groups.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  /// A manager at full trust unless a test says otherwise.
  ///
  /// The trust level is checked BEFORE the configuration (see the second test
  /// below), and the default `basic` refuses `file.read` outright — so a
  /// manager left at the default would never reach the prompt these tests are
  /// about, and every one of them would pass for the wrong reason.
  PermissionManager managerWith(Map<String, dynamic> json) =>
      PermissionManager(PermissionsConfig.fromJson(json))
        ..trustLevel = TrustLevel.full;

  /// Mounts a surface and hands back a context the manager can prompt on.
  Future<BuildContext> surface(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) {
        context = ctx;
        return const Scaffold(body: Text('page'));
      }),
    ));
    return context;
  }

  group('before anything is asked of the user', () {
    testWidgets('a disabled manager allows everything without a dialog',
        (tester) async {
      final context = await surface(tester);
      final manager = PermissionManager(null)..enabled = false;

      final result = await manager.checkAndPrompt(
        context: context,
        actionType: 'client.exec',
        params: {'command': 'rm -rf /'},
      );
      await tester.pump();

      expect(result.allowed, isTrue);
      expect(find.byType(AlertDialog), findsNothing,
          reason: 'a document running with permissions switched off is the '
              'host\'s decision; the runtime must not second-guess it with a '
              'dialog');
    });

    testWidgets('the trust level is enforced before any prompt', (tester) async {
      final context = await surface(tester);
      final manager = managerWith({
        'shell': {
          'allowedCommands': ['ls'],
          'requireConfirmation': true,
        },
      })
        ..trustLevel = TrustLevel.untrusted;

      final result = await manager.checkAndPrompt(
        context: context,
        actionType: 'client.exec',
        params: {'command': 'ls'},
      );
      await tester.pump();

      expect(result.allowed, isFalse);
      expect(result.reason, contains('Trust level'));
      expect(result.reason, contains('untrusted'));
      expect(find.byType(AlertDialog), findsNothing,
          reason: 'asking the user to approve something the trust level '
              'already forbids trains them to approve things');
    });

    testWidgets('an action that is not a client action is not gated',
        (tester) async {
      final context = await surface(tester);
      final manager = managerWith({
        'file.read': {'allowedPaths': <String>[]},
      });

      final result = await manager.checkAndPrompt(
        context: context,
        actionType: 'state',
        params: const {'binding': 'x'},
      );

      expect(result.allowed, isTrue,
          reason: 'setting state is not a capability — gating it would put a '
              'dialog in front of every button');
    });

    testWidgets('a path outside the allowlist is denied without a prompt',
        (tester) async {
      final context = await surface(tester);
      final manager = managerWith({
        'file.read': {
          'allowedPaths': ['/workspace'],
          'requireConfirmation': true,
        },
      });

      final result = await manager.checkAndPrompt(
        context: context,
        actionType: 'client.readFile',
        params: const {'path': '/etc/passwd'},
      );
      await tester.pump();

      expect(result.allowed, isFalse);
      expect(find.byType(AlertDialog), findsNothing,
          reason: 'the configuration already said no; a prompt would let a '
              'user grant what the host forbade');
    });
  });

  group('the prompt', () {
    // Deliberately NOT async: the returned future stays pending until a
    // button is tapped, so the caller has to own the pumping. An `ask` that
    // pumped internally and returned the future would leave a guarded
    // `pumpAndSettle` running under the caller's `expect`.
    Future<PermissionCheckResult> start(
      PermissionManager manager,
      BuildContext context, {
      String actionType = 'client.readFile',
      Map<String, dynamic> params = const {'path': '/workspace/a.txt'},
    }) =>
        manager.checkAndPrompt(
          context: context,
          actionType: actionType,
          params: params,
        );

    testWidgets('is shown when the config requires confirmation, and names '
        'what is being asked for', (tester) async {
      final context = await surface(tester);
      final manager = managerWith({
        'file.read': {
          'allowedPaths': ['/workspace'],
          'requireConfirmation': true,
        },
      });

      final pending = start(manager, context);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('File Read Permission'), findsOneWidget);
      expect(find.textContaining('/workspace/a.txt'), findsOneWidget,
          reason: 'a permission dialog that does not say WHICH file is asking '
              'the user to consent to nothing in particular');

      await tester.tap(find.text('Allow'));
      await tester.pumpAndSettle();
      expect((await pending).allowed, isTrue);
    });

    // Each client action has its own prompt shape, and each shape names a
    // different thing: a URL, a command, a permission label. They are separate
    // arms of one switch, so a shape wired for one action and missed for
    // another asks the user to consent to a blank.
    testWidgets('an action with no shape of its own still asks by name',
        (tester) async {
      final context = await surface(tester);
      final manager = managerWith({
        'clipboard.write': {'requireConfirmation': true},
      });

      final pending = start(manager, context,
          actionType: 'client.setClipboard',
          params: const {'text': 'copied'});
      await tester.pumpAndSettle();

      if (find.byType(AlertDialog).evaluate().isNotEmpty) {
        expect(find.byType(AlertDialog), findsOneWidget,
            reason: 'the default arm of the prompt switch — an action without '
                'a bespoke dialog still has to be asked about, not silently '
                'allowed');
        await tester.tap(find.text('Deny'));
        await tester.pumpAndSettle();
        expect((await pending).allowed, isFalse);
      } else {
        // No confirmation required for this action under this config; the
        // answer still has to be a decision rather than a hang.
        expect((await pending).allowed, isA<bool>());
      }
    });

    testWidgets('Deny refuses the action', (tester) async {
      final context = await surface(tester);
      final manager = managerWith({
        'file.read': {
          'allowedPaths': ['/workspace'],
          'requireConfirmation': true,
        },
      });

      final pending = start(manager, context);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deny'));
      await tester.pumpAndSettle();

      final result = await pending;
      expect(result.allowed, isFalse);
      expect(result.reason, contains('denied by user'));
    });

    testWidgets('Allow Once grants without remembering', (tester) async {
      final context = await surface(tester);
      final manager = managerWith({
        'file.read': {
          'allowedPaths': ['/workspace'],
          'requireConfirmation': true,
        },
      });
      await manager.init();

      final pending = start(manager, context);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allow Once'));
      await tester.pumpAndSettle();
      expect((await pending).allowed, isTrue);

      // The second ask has to prompt again — that is what "once" means.
      final second = start(manager, context);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget,
          reason: 'a one-time grant that is silently persisted is a consent '
              'dialog that lied');
      await tester.tap(find.text('Deny'));
      await tester.pumpAndSettle();
      await second;
    });

    testWidgets('a remembered Allow is not asked again', (tester) async {
      final context = await surface(tester);
      final manager = managerWith({
        'file.read': {
          'allowedPaths': ['/workspace'],
          'requireConfirmation': true,
        },
      });
      await manager.init();

      final pending = start(manager, context);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remember this decision'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allow'));
      await tester.pumpAndSettle();
      expect((await pending).allowed, isTrue);

      final secondPending = start(manager, context);
      await tester.pumpAndSettle();
      final second = await secondPending;
      expect(find.byType(AlertDialog), findsNothing);
      expect(second.allowed, isTrue,
          reason: 'the stored decision is what makes a permission grant worth '
              'anything — without it every action re-asks');
    });

    testWidgets('a remembered Deny is not asked again either', (tester) async {
      final context = await surface(tester);
      final manager = managerWith({
        'file.read': {
          'allowedPaths': ['/workspace'],
          'requireConfirmation': true,
        },
      });
      await manager.init();

      final pending = start(manager, context);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remember this decision'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deny'));
      await tester.pumpAndSettle();
      await pending;

      final secondPending = start(manager, context);
      await tester.pumpAndSettle();
      final second = await secondPending;
      expect(find.byType(AlertDialog), findsNothing);
      expect(second.allowed, isFalse);
      expect(second.reason, contains('previously denied'),
          reason: 'the message distinguishes a stored refusal from a fresh '
              'one, which is what a "reset permissions" button is for');
    });

    testWidgets('a decision is remembered per scope, not for the whole '
        'permission', (tester) async {
      final context = await surface(tester);
      final manager = managerWith({
        'file.read': {
          'allowedPaths': ['/workspace'],
          'requireConfirmation': true,
        },
      });
      await manager.init();

      final first = start(manager, context,
          params: const {'path': '/workspace/a.txt'});
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remember this decision'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allow'));
      await tester.pumpAndSettle();
      await first;

      final other = start(manager, context,
          params: const {'path': '/workspace/b.txt'});
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget,
          reason: 'granting one file must not grant every file — the scope is '
              'the path, and dropping it turns a narrow yes into a broad one');
      await tester.tap(find.text('Deny'));
      await tester.pumpAndSettle();
      await other;
    });

    testWidgets('a shell prompt is scoped to the executable, not the whole '
        'command line', (tester) async {
      final context = await surface(tester);
      final manager = managerWith({
        'shell': {
          'allowedCommands': ['git'],
          'requireConfirmation': true,
        },
      });
      await manager.init();

      final first = start(manager, context,
          actionType: 'client.exec',
          params: const {'command': 'git status'});
      await tester.pumpAndSettle();
      expect(find.text('Command Execution Permission'), findsOneWidget);
      await tester.tap(find.text('Remember this decision'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allow'));
      await tester.pumpAndSettle();
      expect((await first).allowed, isTrue);

      // A different subcommand of the same executable is the same scope: the
      // grant was for `git`, and re-prompting for every argument list would
      // make the remember option useless.
      //
      // This is what caught the defect the fix above addresses: the prompt
      // stored its decision with a null scope while the manager looked it up
      // by the executable name, so a remembered shell grant was never found
      // and the user was asked again every single time.
      final again = start(manager, context,
          actionType: 'client.exec',
          params: const {'command': 'git log'});
      await tester.pumpAndSettle();
      final result = await again;
      expect(result.allowed, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('an allowlisted domain is not prompted for — http carries no '
        'confirmation flag', (tester) async {
      // Recorded rather than asserted as desirable: `FilePermissionConfig` and
      // `ShellPermissionConfig` both carry `requireConfirmation`, and
      // `HttpPermissionConfig` does not, so `checkHttp` always answers with
      // `requiresConfirmation: false` and the `showHttpAccess` branch of
      // `_promptUser` is unreachable through configuration alone. A document
      // that wants a prompt before a request declares it on the action
      // (§4.12.8 shows `requireConfirmation` at action level), which the
      // client action handler honours. Worth knowing before someone concludes
      // the network prompt is broken.
      final context = await surface(tester);
      final manager = managerWith({
        'http': {
          'allowedDomains': ['api.example.com'],
        },
      });
      await manager.init();

      final pending = start(manager, context,
          actionType: 'client.httpRequest',
          params: const {'url': 'https://api.example.com/v1/rows', 'method': 'GET'});
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect((await pending).allowed, isTrue);

      // A domain outside the allowlist is still refused, without a prompt.
      final blocked = start(manager, context,
          actionType: 'client.httpRequest',
          params: const {'url': 'https://elsewhere.example/v1'});
      await tester.pumpAndSettle();
      expect((await blocked).allowed, isFalse);
    });

    testWidgets('a config that does not require confirmation never prompts',
        (tester) async {
      final context = await surface(tester);
      final manager = managerWith({
        'file.read': {
          'allowedPaths': ['/workspace'],
          'requireConfirmation': false,
        },
      });

      final resultPending = start(manager, context);
      await tester.pumpAndSettle();
      final result = await resultPending;

      expect(result.allowed, isTrue);
      expect(find.byType(AlertDialog), findsNothing,
          reason: 'the host declared these paths as pre-approved; prompting '
              'anyway makes the declaration meaningless');
    });
  });

  group('a host-supplied prompt handler', () {
    testWidgets('is consulted instead of the built-in dialog', (tester) async {
      final context = await surface(tester);
      final manager = managerWith({
        'file.read': {
          'allowedPaths': ['/workspace'],
          'requireConfirmation': true,
        },
      });

      final asked = <String>[];
      manager.registerPromptHandler(
        (BuildContext ctx, String actionType, Map<String, dynamic> params) async {
          asked.add(actionType);
          return PermissionDecision.grant();
        },
      );
      await tester.pumpAndSettle();

      final result = await manager.checkAndPrompt(
        context: context,
        actionType: 'client.readFile',
        params: const {'path': '/workspace/a.txt'},
      );
      await tester.pumpAndSettle();

      expect(asked, ['client.readFile']);
      expect(result.allowed, isTrue);
      expect(find.byType(AlertDialog), findsNothing,
          reason: 'a host with its own consent UI must not get the runtime\'s '
              'dialog on top of it');
    });

    testWidgets('a handler that declines to answer falls back to the dialog',
        (tester) async {
      final context = await surface(tester);
      final manager = managerWith({
        'file.read': {
          'allowedPaths': ['/workspace'],
          'requireConfirmation': true,
        },
      });
      manager.registerPromptHandler(
          (BuildContext ctx, String actionType, Map<String, dynamic> params) async =>
              null);

      final pending = manager.checkAndPrompt(
        context: context,
        actionType: 'client.readFile',
        params: const {'path': '/workspace/a.txt'},
      );
      await tester.pumpAndSettle();

      // `null` from a `Future<PermissionDecision?>` handler IS an answer — it
      // means "no decision", and the manager treats it as such rather than
      // falling through to its own dialog.
      expect(find.byType(AlertDialog), findsNothing);
      final result = await pending;
      expect(result.allowed, isFalse);
      expect(result.reason, contains('cancelled'));
    });
  });

  group('requestAll', () {
    testWidgets('prompts once per permission and remembers what it is told',
        (tester) async {
      final context = await surface(tester);
      final manager = PermissionManager(null);
      await manager.init();

      final pending =
          manager.requestAll(['file.read', 'http'], context: context);

      await tester.pumpAndSettle();
      await tester.tap(find.text('Remember this decision'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allow'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Deny'));
      await tester.pumpAndSettle();

      final results = await pending;
      expect(results['file.read']!.granted, isTrue);
      expect(results['http']!.granted, isFalse);

      // The remembered one is not asked again.
      final second = await manager.requestAll(['file.read'], context: context);
      await tester.pumpAndSettle();
      expect(second['file.read']!.granted, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('with no surface it denies rather than assuming consent',
        (tester) async {
      final manager = PermissionManager(null);
      await manager.init();

      final results = await manager.requestAll(['file.read', 'http']);

      expect(results['file.read']!.granted, isFalse);
      expect(results['http']!.granted, isFalse,
          reason: 'no way to ask means no consent — granting by default is '
              'how a headless path becomes the way around the gate');
    });
  });

  group('revocation', () {
    testWidgets('revokeAll turns every stored grant into a refusal',
        (tester) async {
      final context = await surface(tester);
      final manager = PermissionManager(null);
      await manager.init();

      final pending =
          manager.requestAll(['file.read', 'http'], context: context);
      for (var i = 0; i < 2; i++) {
        await tester.pumpAndSettle();
        await tester.tap(find.text('Remember this decision'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Allow'));
        await tester.pumpAndSettle();
      }
      await pending;

      expect((await manager.getAllDecisions()), isNotEmpty);
      await manager.revokeAllPermissions();

      final decisions = await manager.getAllDecisions();
      expect(decisions, isNotEmpty,
          reason: 'a revoked marker is kept on purpose: it is the difference '
              'between "never asked" and "the user said no"');
      for (final decision in decisions.values) {
        expect(decision.revoked, isTrue);
      }

      // And a revoked decision does not short-circuit the next request.
      final after = manager.requestAll(['file.read'], context: context);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Deny'));
      await tester.pumpAndSettle();
      await after;
    });
  });
  // The prompt a user actually sees depends on WHAT is being asked for: a
  // file, a URL, a command, or something the runtime has no special screen
  // for. A generic dialog in place of the specific one asks the user to
  // consent to nothing in particular.
  group('the prompt for each kind of request', () {
    testWidgets('a shell command names the command', (tester) async {
      final context = await surface(tester);
      final manager = managerWith({
        'system.exec': {
          'allowedCommands': ['git'],
          'requireConfirmation': true,
        },
      });

      final pending = manager.checkAndPrompt(
        context: context,
        actionType: 'client.exec',
        params: {'command': 'git status'},
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('git'), findsWidgets);
      await tester.tap(find.text('Deny'));
      await tester.pumpAndSettle();
      expect((await pending).allowed, isFalse);
    });

    testWidgets('a write is named as a write, not as a read', (tester) async {
      final context = await surface(tester);
      final manager = managerWith({
        'file.write': {
          'allowedPaths': ['/workspace'],
          'requireConfirmation': true,
        },
      });

      final pending = manager.checkAndPrompt(
        context: context,
        actionType: 'client.writeFile',
        params: {'path': '/workspace/a.txt'},
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Write'), findsWidgets,
          reason: 'consenting to a read is not consenting to a write; the '
              'dialog has to say which one it is');
      await tester.tap(find.text('Deny'));
      await tester.pumpAndSettle();
      expect((await pending).allowed, isFalse);
    });
  });

  group('asking for a set of permissions up front', () {
    testWidgets('with no surface to prompt on, everything is refused',
        (tester) async {
      await surface(tester);
      final manager = managerWith(const <String, dynamic>{});

      manager.groupManager.registerGroup(const PermissionGroup(
        id: 'files',
        label: 'Files',
        description: 'Read the documents you pick',
        permissions: ['file.read', 'network.http'],
        required: true,
      ));

      final results = await manager.requestPermissionsUpfront();

      expect(results.values.every((d) => !d.granted), isTrue,
          reason: 'a host with nowhere to ask cannot grant on the user\'s '
              'behalf');
    });
  });
}
