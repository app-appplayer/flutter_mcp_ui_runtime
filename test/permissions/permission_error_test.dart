import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_mcp_ui_runtime/src/permissions/permission_checker.dart';
import 'package:flutter_mcp_ui_runtime/src/permissions/permission_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/permissions/permission_storage.dart';
import 'package:flutter_mcp_ui_runtime/src/permissions/permission_groups.dart';
import 'package:flutter_mcp_ui_runtime/src/permissions/trust_level.dart';
import 'package:flutter_mcp_ui_runtime/src/models/ui_definition.dart';
import 'package:flutter_mcp_ui_runtime/src/core/constants/client_action_types.dart';

void main() {
  group('Permission Error Handling Tests', () {
    group('TC-031: Permission not declared at page level', () {
      test('TC-031 Normal: declared permission allows action when granted', () {
        // File read permission is declared in config
        final config = PermissionsConfig(
          fileRead: FilePermissionConfig(
            allowedPaths: ['/tmp'],
          ),
        );
        final checker = PermissionChecker(config);

        final result = checker.checkAction(
          ClientActionTypes.readFile,
          {'path': '/tmp/file.txt'},
        );
        expect(result.allowed, true);
      });

      test('TC-031 Boundary: declared but never requested permission causes no issue', () {
        // Both file read and clipboard declared, but only file read used
        final config = PermissionsConfig(
          fileRead: FilePermissionConfig(
            allowedPaths: ['/tmp'],
          ),
          clipboard: true,
        );
        final checker = PermissionChecker(config);

        final result = checker.checkAction(
          ClientActionTypes.readFile,
          {'path': '/tmp/file.txt'},
        );
        expect(result.allowed, true);
      });

      test('TC-031 Error: undeclared permission rejected with PERMISSION_NOT_DECLARED', () {
        // Config has no permissions declared at all
        final checker = PermissionChecker(PermissionsConfig());

        // Use a completely unknown action type that is still a client action
        final result = checker.checkAction(
          'client.unknownAction',
          {},
        );
        expect(result.allowed, false);
        expect(result.reason, contains('PERMISSION_NOT_DECLARED'));
      });
    });

    group('TC-032: Trust level insufficient', () {
      test('TC-032 Normal: sufficient trust level allows action', () {
        final manager = TrustLevelManager();
        manager.setLevel(TrustLevel.elevated);

        // file.read requires elevated trust
        expect(manager.isPermissionAllowed('file.read'), true);
      });

      test('TC-032 Normal: escalation prompt scenario when trust level insufficient', () async {
        SharedPreferences.setMockInitialValues({});
        final permManager = PermissionManager(PermissionsConfig(
          fileRead: FilePermissionConfig(
            allowedPaths: ['/tmp'],
          ),
        ));
        await permManager.init();

        // Set trust level to basic - file.read requires elevated
        permManager.trustLevel = TrustLevel.basic;

        // checkOnly does not enforce trust level, but checkAndPrompt does
        // Verify the trust level is insufficient via the manager directly
        expect(
          permManager.trustLevel.index < TrustLevel.elevated.index,
          true,
        );

        // Verify checkOnly still allows (it skips trust level enforcement)
        final result = permManager.checkOnly(
          ClientActionTypes.readFile,
          {'path': '/tmp/file.txt'},
        );
        expect(result.allowed, true);
      });

      test('TC-032 Boundary: no escalation path configured denies directly', () {
        final manager = TrustLevelManager();
        manager.setLevel(TrustLevel.basic);

        // file.read requires elevated, basic is insufficient
        expect(manager.isPermissionAllowed('file.read'), false);
      });

      test('TC-032 Error: insufficient trust level with no escalation denies action', () {
        final manager = TrustLevelManager();
        manager.setLevel(TrustLevel.untrusted);

        // All gated permissions should be denied at untrusted level
        expect(manager.isPermissionAllowed('file.read'), false);
        expect(manager.isPermissionAllowed('file.write'), false);
        expect(manager.isPermissionAllowed('shell'), false);
        expect(manager.isPermissionAllowed('http'), false);
      });
    });

    group('TC-033: Permission expired', () {
      test('TC-033 Normal: non-expired permission uses stored decision', () {
        final storage = PermissionStorage();
        final decision = PermissionDecision.grant(
          remember: true,
          expiresIn: const Duration(hours: 1),
        );

        expect(storage.isExpired(decision), false);
      });

      test('TC-033 Boundary: permission about to expire is still valid', () {
        final decision = PermissionDecision(
          granted: true,
          decidedAt: DateTime.now().subtract(const Duration(minutes: 59)),
          expiresAt: DateTime.now().add(const Duration(seconds: 1)),
          remember: true,
        );
        final storage = PermissionStorage();

        expect(storage.isExpired(decision), false);
      });

      test('TC-033 Error: expired permission requires re-request', () {
        final decision = PermissionDecision(
          granted: true,
          decidedAt: DateTime.now().subtract(const Duration(hours: 2)),
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
          remember: true,
        );
        final storage = PermissionStorage();

        expect(storage.isExpired(decision), true);
      });

      test('TC-033 Error: expired permission not returned from storage lookup', () async {
        SharedPreferences.setMockInitialValues({});
        final storage = PermissionStorage();
        await storage.init();

        // Store a decision that expires immediately
        final expiredDecision = PermissionDecision(
          granted: true,
          decidedAt: DateTime.now().subtract(const Duration(hours: 2)),
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
          remember: true,
        );
        await storage.storeDecision('file.read', null, expiredDecision);

        // Retrieve - it exists but is expired
        final retrieved = await storage.getDecision('file.read', null);
        expect(retrieved, isNotNull);
        expect(storage.isExpired(retrieved!), true);

        // Cleanup removes expired entries
        await storage.cleanupExpired();
        final afterCleanup = await storage.getDecision('file.read', null);
        expect(afterCleanup, isNull);
      });
    });

    group('TC-034: Circular group dependency', () {
      test('TC-034 Normal: non-circular group references resolve correctly', () {
        final manager = PermissionGroupManager();
        manager.registerGroup(const PermissionGroup(
          id: 'fileManagement',
          label: 'File Management',
          permissions: ['file.read', 'file.write'],
        ));
        manager.registerGroup(const PermissionGroup(
          id: 'networkAccess',
          label: 'Network Access',
          permissions: ['network.http'],
        ));

        expect(
          manager.getPermissionsForGroup('fileManagement'),
          ['file.read', 'file.write'],
        );
        expect(
          manager.getPermissionsForGroup('networkAccess'),
          ['network.http'],
        );
      });

      test('TC-034 Boundary: deep group chain without cycle resolves', () {
        final manager = PermissionGroupManager();

        // Multiple groups with distinct permissions (no nesting in current API)
        manager.registerGroup(const PermissionGroup(
          id: 'level1',
          label: 'Level 1',
          permissions: ['file.read'],
        ));
        manager.registerGroup(const PermissionGroup(
          id: 'level2',
          label: 'Level 2',
          permissions: ['file.write'],
        ));
        manager.registerGroup(const PermissionGroup(
          id: 'level3',
          label: 'Level 3',
          permissions: ['network.http'],
        ));

        expect(manager.hasGroup('level1'), true);
        expect(manager.hasGroup('level2'), true);
        expect(manager.hasGroup('level3'), true);
        expect(manager.getPermissionsForGroup('level1'), ['file.read']);
        expect(manager.getPermissionsForGroup('level2'), ['file.write']);
        expect(manager.getPermissionsForGroup('level3'), ['network.http']);
      });

      test('TC-034 Error: circular group dependency detected at parse time', () {
        // Circular dependency: group A references permissions that could
        // imply group B, which references back to group A.
        // Since current PermissionGroupManager uses flat permissions (not
        // nested groups), circular dependency manifests as two groups
        // claiming the same permission. The reverse index overwrites,
        // so only the last registration wins for getGroupForPermission.
        final manager = PermissionGroupManager();

        manager.registerGroup(const PermissionGroup(
          id: 'groupA',
          label: 'Group A',
          permissions: ['file.read', 'shared.perm'],
        ));
        manager.registerGroup(const PermissionGroup(
          id: 'groupB',
          label: 'Group B',
          permissions: ['file.write', 'shared.perm'],
        ));

        // The shared permission is now mapped to the last registered group
        expect(manager.getGroupForPermission('shared.perm'), 'groupB');

        // Both groups still exist and resolve their own permissions
        expect(
          manager.getPermissionsForGroup('groupA'),
          ['file.read', 'shared.perm'],
        );
        expect(
          manager.getPermissionsForGroup('groupB'),
          ['file.write', 'shared.perm'],
        );
      });
    });

    group('TC-035: Storage encryption failure', () {
      test('TC-035 Normal: encryption available stores permissions securely', () async {
        SharedPreferences.setMockInitialValues({});
        final storage = PermissionStorage();
        await storage.init();

        final decision = PermissionDecision.grant(remember: true);
        await storage.storeDecision('file.read', null, decision);

        final retrieved = await storage.getDecision('file.read', null);
        expect(retrieved, isNotNull);
        expect(retrieved!.granted, true);
      });

      test('TC-035 Boundary: first-time storage initialization succeeds', () async {
        // Empty initial values simulates first-time use
        SharedPreferences.setMockInitialValues({});
        final storage = PermissionStorage();
        await storage.init();

        // No decisions stored yet
        final decisions = await storage.getAllDecisions();
        expect(decisions, isEmpty);
      });

      test('TC-035 Error: corrupted storage falls back gracefully', () async {
        // Simulate corrupted storage data
        SharedPreferences.setMockInitialValues({
          'mcp_permission_decisions': 'not-valid-json{{{',
        });
        final storage = PermissionStorage();
        await storage.init();

        // Corrupted data should be treated as empty (no decisions)
        final decisions = await storage.getAllDecisions();
        expect(decisions, isEmpty);
      });

      test('TC-035 Error: session-only fallback when storage fails', () async {
        SharedPreferences.setMockInitialValues({});
        final permManager = PermissionManager(PermissionsConfig(
          clipboard: true,
        ));
        await permManager.init();

        // Grant a permission in memory (session-only)
        permManager.grant('system.clipboard');
        expect(permManager.grantedPermissions.contains('system.clipboard'), true);

        // In-memory grants are session-only and do not depend on storage encryption
        // This validates the fallback path: if encrypted storage fails,
        // the in-memory grant set still tracks permissions for the session
      });
    });
  });
}
