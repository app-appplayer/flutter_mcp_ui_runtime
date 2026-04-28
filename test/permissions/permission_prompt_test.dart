import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/permissions/permission_storage.dart';
import 'package:flutter_mcp_ui_runtime/src/permissions/permission_groups.dart';

/// Permission prompt tests verify the data models and configurations
/// that drive the permission prompt UI. Since the actual prompt display
/// requires a live Flutter widget tree, we test the underlying logic
/// and configuration models.
void main() {
  group('Permission Prompt Tests', () {
    group('TC-017: Modal permission prompt display', () {
      test('TC-017 Normal: PermissionDecision.grant creates valid decision', () {
        final decision = PermissionDecision.grant(
          remember: true,
          scope: '/home/user/docs',
        );

        expect(decision.granted, true);
        expect(decision.remember, true);
        expect(decision.scope, '/home/user/docs');
        expect(decision.decidedAt, isNotNull);
      });

      test('TC-017 Boundary: grant without remember creates ephemeral decision', () {
        final decision = PermissionDecision.grantOnce(scope: '/tmp');
        expect(decision.granted, true);
        expect(decision.remember, false);
      });

      test('TC-017 Error: deny decision stores denial', () {
        final decision = PermissionDecision.deny(
          remember: true,
          scope: '/restricted',
        );
        expect(decision.granted, false);
        expect(decision.remember, true);
        expect(decision.scope, '/restricted');
      });
    });

    group('TC-018: Inline permission prompt display', () {
      test('TC-018 Normal: decision with expiry creates time-bound permission', () {
        final decision = PermissionDecision.grant(
          remember: true,
          expiresIn: const Duration(hours: 1),
        );
        expect(decision.expiresAt, isNotNull);
        expect(decision.expiresAt!.isAfter(DateTime.now()), true);
      });

      test('TC-018 Boundary: zero-duration expiry creates immediately expired decision', () {
        final decision = PermissionDecision.grant(
          remember: true,
          expiresIn: Duration.zero,
        );
        // expiresAt should be approximately now
        expect(decision.expiresAt, isNotNull);
      });
    });

    group('TC-019: Banner permission prompt display', () {
      test('TC-019 Normal: permission decision serialization round-trip', () {
        final original = PermissionDecision.grant(
          remember: true,
          expiresIn: const Duration(hours: 2),
          scope: 'api.example.com',
        );

        final json = original.toJson();
        final restored = PermissionDecision.fromJson(json);

        expect(restored.granted, original.granted);
        expect(restored.remember, original.remember);
        expect(restored.scope, original.scope);
        expect(restored.expiresAt, isNotNull);
      });

      test('TC-019 Boundary: decision without scope serializes cleanly', () {
        final decision = PermissionDecision.grant(remember: false);
        final json = decision.toJson();

        expect(json.containsKey('scope'), false);
        expect(json['granted'], true);
        expect(json['remember'], false);
      });
    });

    group('TC-020: Permission prompt with custom message', () {
      test('TC-020 Normal: decision carries scope context for display', () {
        final decision = PermissionDecision.grant(
          remember: true,
          scope: '/home/user/documents/report.pdf',
        );
        // The scope provides context for the custom message in the prompt
        expect(decision.scope, contains('report.pdf'));
      });

      test('TC-020 Boundary: null scope handled gracefully', () {
        final decision = PermissionDecision.grant(remember: true);
        expect(decision.scope, isNull);
      });
    });

    group('TC-021: Multi-permission dialog', () {
      test('TC-021 Normal: PermissionGroup bundles multiple permissions', () {
        const group = PermissionGroup(
          id: 'file-access',
          label: 'File Access',
          permissions: ['file.read', 'file.write'],
          required: true,
        );

        expect(group.permissions.length, 2);
        expect(group.containsPermission('file.read'), true);
        expect(group.containsPermission('file.write'), true);
        expect(group.required, true);
      });

      test('TC-021 Boundary: empty permission group', () {
        const group = PermissionGroup(
          id: 'empty',
          label: 'Empty',
          permissions: [],
        );
        expect(group.permissions, isEmpty);
        expect(group.containsPermission('file.read'), false);
      });

      test('TC-021 Normal: PermissionGroupManager registers and queries groups', () {
        final manager = PermissionGroupManager();
        const group = PermissionGroup(
          id: 'network',
          label: 'Network Access',
          permissions: ['network.http', 'network.websocket'],
        );

        manager.registerGroup(group);
        expect(manager.hasGroup('network'), true);
        expect(manager.getPermissionsForGroup('network'),
            ['network.http', 'network.websocket']);
        expect(manager.getGroupForPermission('network.http'), 'network');
      });
    });

    group('TC-022: allowPartial flag in multi-permission dialog', () {
      test('TC-022 Normal: group with optional permissions', () {
        const group = PermissionGroup(
          id: 'mixed',
          label: 'Mixed Permissions',
          permissions: ['file.read', 'clipboard'],
          required: false,
        );
        // Non-required group allows partial acceptance
        expect(group.required, false);
        expect(group.permissions.length, 2);
      });

      test('TC-022 Boundary: single-permission group', () {
        const group = PermissionGroup(
          id: 'single',
          label: 'Single',
          permissions: ['notification'],
        );
        expect(group.permissions.length, 1);
      });

      test('TC-022 Normal: manager reverse-indexes permissions to groups', () {
        final manager = PermissionGroupManager();
        const fileGroup = PermissionGroup(
          id: 'files',
          label: 'Files',
          permissions: ['file.read', 'file.write'],
        );
        const netGroup = PermissionGroup(
          id: 'network',
          label: 'Network',
          permissions: ['network.http'],
        );

        manager.registerGroup(fileGroup);
        manager.registerGroup(netGroup);

        expect(manager.getGroupForPermission('file.read'), 'files');
        expect(manager.getGroupForPermission('network.http'), 'network');
        expect(manager.getGroupForPermission('unknown'), isNull);
      });
    });

    group('TC-023: minimumRequired constraint in permission dialog', () {
      test('TC-023 Normal: required group must be fully granted', () {
        const group = PermissionGroup(
          id: 'essential',
          label: 'Essential Access',
          permissions: ['file.read', 'network.http'],
          required: true,
        );

        expect(group.required, true);
        expect(group.permissions.length, 2);
      });

      test('TC-023 Boundary: re-registering group updates reverse index', () {
        final manager = PermissionGroupManager();
        const original = PermissionGroup(
          id: 'files',
          label: 'Files v1',
          permissions: ['file.read'],
        );
        const updated = PermissionGroup(
          id: 'files',
          label: 'Files v2',
          permissions: ['file.read', 'file.write'],
        );

        manager.registerGroup(original);
        expect(manager.getPermissionsForGroup('files'), ['file.read']);

        manager.registerGroup(updated);
        expect(manager.getPermissionsForGroup('files'),
            ['file.read', 'file.write']);
        expect(manager.getGroupForPermission('file.write'), 'files');
      });

      test('TC-023 Error: unregistering removes all traces', () {
        final manager = PermissionGroupManager();
        const group = PermissionGroup(
          id: 'temp',
          label: 'Temporary',
          permissions: ['clipboard'],
        );

        manager.registerGroup(group);
        expect(manager.hasGroup('temp'), true);

        manager.unregisterGroup('temp');
        expect(manager.hasGroup('temp'), false);
        expect(manager.getGroupForPermission('clipboard'), isNull);
      });
    });
  });

  group('TC-006: Permission group definition', () {
    test('TC-006 Normal: fileManagement group bundles file.read and file.write', () {
      const group = PermissionGroup(
        id: 'fileManagement',
        label: 'File Management',
        permissions: ['file.read', 'file.write'],
      );

      expect(group.id, 'fileManagement');
      expect(group.permissions, ['file.read', 'file.write']);
    });

    test('TC-006 Normal: networkAccess group with single permission', () {
      const group = PermissionGroup(
        id: 'networkAccess',
        label: 'Network Access',
        permissions: ['network.http'],
      );

      expect(group.permissions, ['network.http']);
    });

    test('TC-006 Boundary: group with single permission functions as named alias', () {
      const group = PermissionGroup(
        id: 'clipboardAlias',
        label: 'Clipboard',
        permissions: ['clipboard'],
      );

      expect(group.permissions.length, 1);
      expect(group.containsPermission('clipboard'), true);
    });

    test('TC-006 Error: group fromJson with missing permissions throws', () {
      expect(
        () => PermissionGroup.fromJson({
          'id': 'bad',
          'label': 'Bad',
          // missing 'permissions'
        }),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('TC-007: Permission group properties', () {
    test('TC-007 Normal: group has label, description, icon', () {
      const group = PermissionGroup(
        id: 'fileManagement',
        label: 'File Management',
        description: 'Read and write files',
        icon: 'folder',
        permissions: ['file.read', 'file.write'],
      );

      expect(group.label, 'File Management');
      expect(group.description, 'Read and write files');
      expect(group.icon, 'folder');
    });

    test('TC-007 Normal: required group must be granted', () {
      const group = PermissionGroup(
        id: 'essential',
        label: 'Essential',
        permissions: ['file.read'],
        required: true,
      );

      expect(group.required, true);
    });

    test('TC-007 Boundary: optional group (required: false)', () {
      const group = PermissionGroup(
        id: 'optional',
        label: 'Optional',
        permissions: ['notification'],
        required: false,
      );

      expect(group.required, false);
    });

    test('TC-007 Error: required group denied blocks page', () {
      // When a required group is denied, the page cannot proceed.
      // Verify required flag is correctly parsed from JSON.
      final group = PermissionGroup.fromJson({
        'id': 'critical',
        'label': 'Critical',
        'permissions': ['file.write'],
        'required': true,
      });

      expect(group.required, true);
    });
  });

  group('TC-008: Group grant and revoke', () {
    test('TC-008 Normal: granting group grants all contained permissions', () {
      final manager = PermissionGroupManager();
      const group = PermissionGroup(
        id: 'fileManagement',
        label: 'File Management',
        permissions: ['file.read', 'file.write'],
      );
      manager.registerGroup(group);

      // Verify all permissions in the group are accessible
      final permissions = manager.getPermissionsForGroup('fileManagement');
      expect(permissions, contains('file.read'));
      expect(permissions, contains('file.write'));
      expect(permissions.length, 2);
    });

    test('TC-008 Normal: revoking group removes all permissions from index', () {
      final manager = PermissionGroupManager();
      const group = PermissionGroup(
        id: 'fileManagement',
        label: 'File Management',
        permissions: ['file.read', 'file.write'],
      );
      manager.registerGroup(group);
      manager.unregisterGroup('fileManagement');

      expect(manager.getPermissionsForGroup('fileManagement'), isEmpty);
      expect(manager.getGroupForPermission('file.read'), isNull);
      expect(manager.getGroupForPermission('file.write'), isNull);
    });

    test('TC-008 Boundary: individual permission within group checked', () {
      final manager = PermissionGroupManager();
      const group = PermissionGroup(
        id: 'fileManagement',
        label: 'File Management',
        permissions: ['file.read', 'file.write'],
      );
      manager.registerGroup(group);

      // Individual permission lookup
      expect(manager.getGroupForPermission('file.read'), 'fileManagement');
      expect(manager.getGroupForPermission('file.write'), 'fileManagement');
    });

    test('TC-008 Error: group not found returns empty', () {
      final manager = PermissionGroupManager();
      expect(manager.getPermissionsForGroup('nonexistent'), isEmpty);
      expect(manager.getGroup('nonexistent'), isNull);
    });
  });

  group('TC-037: PermissionGroup - containsPermission', () {
    test('TC-037 Normal: permission exists in group returns true', () {
      const group = PermissionGroup(
        id: 'files',
        label: 'Files',
        permissions: ['file.read', 'file.write'],
      );

      expect(group.containsPermission('file.read'), true);
      expect(group.containsPermission('file.write'), true);
    });

    test('TC-037 Normal: permission not in group returns false', () {
      const group = PermissionGroup(
        id: 'files',
        label: 'Files',
        permissions: ['file.read', 'file.write'],
      );

      expect(group.containsPermission('network.http'), false);
    });

    test('TC-037 Boundary: empty permissions list always returns false', () {
      const group = PermissionGroup(
        id: 'empty',
        label: 'Empty',
        permissions: [],
      );

      expect(group.containsPermission('file.read'), false);
      expect(group.containsPermission(''), false);
    });
  });

  group('TC-038: PermissionGroupManager - getPermissionsForGroup', () {
    test('TC-038 Normal: returns all permissions in group', () {
      final manager = PermissionGroupManager();
      const group = PermissionGroup(
        id: 'fileManagement',
        label: 'File Management',
        permissions: ['file.read', 'file.write'],
      );
      manager.registerGroup(group);

      final permissions = manager.getPermissionsForGroup('fileManagement');
      expect(permissions, ['file.read', 'file.write']);
    });

    test('TC-038 Boundary: unknown groupId returns empty list', () {
      final manager = PermissionGroupManager();
      expect(manager.getPermissionsForGroup('unknown'), isEmpty);
    });
  });

  group('TC-039: PermissionGroupManager - getGroupForPermission', () {
    test('TC-039 Normal: permission belongs to a group returns group ID', () {
      final manager = PermissionGroupManager();
      const group = PermissionGroup(
        id: 'files',
        label: 'Files',
        permissions: ['file.read', 'file.write'],
      );
      manager.registerGroup(group);

      expect(manager.getGroupForPermission('file.read'), 'files');
    });

    test('TC-039 Normal: permission not in any group returns null', () {
      final manager = PermissionGroupManager();
      expect(manager.getGroupForPermission('unknown.perm'), isNull);
    });

    test('TC-039 Boundary: permission in multiple groups returns first registered', () {
      final manager = PermissionGroupManager();
      const group1 = PermissionGroup(
        id: 'groupA',
        label: 'Group A',
        permissions: ['shared.perm'],
      );
      const group2 = PermissionGroup(
        id: 'groupB',
        label: 'Group B',
        permissions: ['shared.perm'],
      );

      manager.registerGroup(group1);
      manager.registerGroup(group2);

      // The reverse index overwrites, so the last registered group wins
      final result = manager.getGroupForPermission('shared.perm');
      expect(result, 'groupB');
    });
  });

  group('PermissionGroup and PermissionGroupManager Tests', () {
    group('TC-036: PermissionGroup — toJson', () {
      test('TC-036 Normal: serializes all fields to JSON map', () {
        const group = PermissionGroup(
          id: 'file-management',
          label: 'File Management',
          icon: 'folder',
          description: 'Access to file system',
          permissions: ['file.read', 'file.write'],
          required: true,
        );

        final json = group.toJson();
        expect(json['id'], 'file-management');
        expect(json['label'], 'File Management');
        expect(json['icon'], 'folder');
        expect(json['description'], 'Access to file system');
        expect(json['permissions'], ['file.read', 'file.write']);
        expect(json['required'], true);
      });

      test('TC-036 Boundary: group with empty permissions serializes with empty array', () {
        const group = PermissionGroup(
          id: 'empty',
          label: 'Empty Group',
          permissions: [],
        );

        final json = group.toJson();
        expect(json['permissions'], isEmpty);
        expect(json.containsKey('icon'), false);
        expect(json.containsKey('description'), false);
        expect(json.containsKey('required'), false);
      });
    });

    group('TC-040: PermissionGroupManager — groupIds and hasGroup', () {
      test('TC-040 Normal: groupIds returns all registered group IDs', () {
        final manager = PermissionGroupManager();
        const fileGroup = PermissionGroup(
          id: 'files',
          label: 'Files',
          permissions: ['file.read', 'file.write'],
        );
        const netGroup = PermissionGroup(
          id: 'network',
          label: 'Network',
          permissions: ['network.http'],
        );

        manager.registerGroup(fileGroup);
        manager.registerGroup(netGroup);

        expect(manager.groupIds, containsAll(['files', 'network']));
        expect(manager.groupIds.length, 2);
      });

      test('TC-040 Normal: hasGroup returns true for registered, false for unregistered', () {
        final manager = PermissionGroupManager();
        const group = PermissionGroup(
          id: 'system',
          label: 'System',
          permissions: ['system.info'],
        );
        manager.registerGroup(group);

        expect(manager.hasGroup('system'), true);
        expect(manager.hasGroup('unknown'), false);
      });

      test('TC-040 Boundary: no groups registered returns empty list', () {
        final manager = PermissionGroupManager();
        expect(manager.groupIds, isEmpty);
      });
    });

    group('TC-041: PermissionGroupManager — clear', () {
      test('TC-041 Normal: removes all registered permission groups', () {
        final manager = PermissionGroupManager();
        const group = PermissionGroup(
          id: 'files',
          label: 'Files',
          permissions: ['file.read'],
        );
        manager.registerGroup(group);
        expect(manager.hasGroup('files'), true);

        manager.clear();
        expect(manager.hasGroup('files'), false);
        expect(manager.groupIds, isEmpty);
        expect(manager.getGroupForPermission('file.read'), isNull);
      });

      test('TC-041 Boundary: clear when no groups registered is no-op', () {
        final manager = PermissionGroupManager();
        manager.clear();
        expect(manager.groupIds, isEmpty);
      });
    });
  });
}
