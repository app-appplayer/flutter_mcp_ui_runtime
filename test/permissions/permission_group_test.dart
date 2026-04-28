import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/permissions/permission_groups.dart';

void main() {
  // TC-006: Permission group definition
  group('TC-006: Permission group definition', () {
    test('Normal: fileManagement group groups two permissions under single label', () {
      const group = PermissionGroup(
        id: 'fileManagement',
        label: 'File Management',
        permissions: ['file.read', 'file.write'],
      );

      expect(group.id, 'fileManagement');
      expect(group.permissions, ['file.read', 'file.write']);
      expect(group.containsPermission('file.read'), isTrue);
      expect(group.containsPermission('file.write'), isTrue);
    });

    test('Normal: networkAccess group groups network permission', () {
      const group = PermissionGroup(
        id: 'networkAccess',
        label: 'Network Access',
        permissions: ['network.http'],
      );

      expect(group.id, 'networkAccess');
      expect(group.permissions, ['network.http']);
      expect(group.containsPermission('network.http'), isTrue);
    });

    test('Boundary: group with single permission functions as named alias', () {
      const group = PermissionGroup(
        id: 'singlePerm',
        label: 'Single',
        permissions: ['clipboard.read'],
      );

      expect(group.permissions.length, 1);
      expect(group.containsPermission('clipboard.read'), isTrue);
      expect(group.containsPermission('clipboard.write'), isFalse);
    });

    test('Normal: fromJson creates group correctly', () {
      final json = {
        'id': 'fileManagement',
        'label': 'File Management',
        'icon': 'folder',
        'description': 'File access permissions',
        'permissions': ['file.read', 'file.write'],
        'required': true,
      };

      final group = PermissionGroup.fromJson(json);

      expect(group.id, 'fileManagement');
      expect(group.label, 'File Management');
      expect(group.icon, 'folder');
      expect(group.description, 'File access permissions');
      expect(group.permissions, ['file.read', 'file.write']);
      expect(group.required, isTrue);
    });

    test('Normal: toJson serializes group correctly', () {
      const group = PermissionGroup(
        id: 'fileManagement',
        label: 'File Management',
        icon: 'folder',
        description: 'File access permissions',
        permissions: ['file.read', 'file.write'],
        required: true,
      );

      final json = group.toJson();

      expect(json['id'], 'fileManagement');
      expect(json['label'], 'File Management');
      expect(json['icon'], 'folder');
      expect(json['description'], 'File access permissions');
      expect(json['permissions'], ['file.read', 'file.write']);
      expect(json['required'], true);
    });

    test('Normal: toJson omits null optional fields', () {
      const group = PermissionGroup(
        id: 'basic',
        label: 'Basic',
        permissions: ['perm.a'],
      );

      final json = group.toJson();

      expect(json.containsKey('icon'), isFalse);
      expect(json.containsKey('description'), isFalse);
      expect(json.containsKey('required'), isFalse);
    });

    test('Normal: fromJson and toJson are symmetric', () {
      const original = PermissionGroup(
        id: 'test',
        label: 'Test Group',
        icon: 'star',
        description: 'A test group',
        permissions: ['a', 'b', 'c'],
        required: true,
      );

      final restored = PermissionGroup.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.label, original.label);
      expect(restored.icon, original.icon);
      expect(restored.description, original.description);
      expect(restored.permissions, original.permissions);
      expect(restored.required, original.required);
    });

    test('Normal: containsPermission returns false for non-member', () {
      const group = PermissionGroup(
        id: 'files',
        label: 'Files',
        permissions: ['file.read'],
      );

      expect(group.containsPermission('network.http'), isFalse);
    });

    test('Error: fromJson with missing permissions throws', () {
      final json = {
        'id': 'bad',
        'label': 'Bad Group',
      };

      expect(() => PermissionGroup.fromJson(json), throwsA(isA<TypeError>()));
    });
  });

  // TC-007: Permission group properties
  group('TC-007: Permission group properties', () {
    test('Normal: group has label, description, icon for display', () {
      const group = PermissionGroup(
        id: 'fileManagement',
        label: 'File Management',
        description: 'Access to read and write files',
        icon: 'folder_open',
        permissions: ['file.read', 'file.write'],
      );

      expect(group.label, 'File Management');
      expect(group.description, 'Access to read and write files');
      expect(group.icon, 'folder_open');
    });

    test('Normal: group with required true must be granted', () {
      const group = PermissionGroup(
        id: 'essential',
        label: 'Essential',
        permissions: ['core.access'],
        required: true,
      );

      expect(group.required, isTrue);
    });

    test('Boundary: group with required false is optional', () {
      const group = PermissionGroup(
        id: 'optional',
        label: 'Optional',
        permissions: ['extra.feature'],
        required: false,
      );

      expect(group.required, isFalse);
    });

    test('Boundary: required defaults to false', () {
      const group = PermissionGroup(
        id: 'defaultReq',
        label: 'Default',
        permissions: ['perm.a'],
      );

      expect(group.required, isFalse);
    });

    test('Normal: equality is based on id', () {
      const group1 = PermissionGroup(
        id: 'same',
        label: 'Label A',
        permissions: ['a'],
      );
      const group2 = PermissionGroup(
        id: 'same',
        label: 'Label B',
        permissions: ['b'],
      );
      const group3 = PermissionGroup(
        id: 'different',
        label: 'Label A',
        permissions: ['a'],
      );

      expect(group1, equals(group2));
      expect(group1, isNot(equals(group3)));
      expect(group1.hashCode, group2.hashCode);
    });

    test('Normal: toString includes id, label, and permission count', () {
      const group = PermissionGroup(
        id: 'files',
        label: 'Files',
        permissions: ['file.read', 'file.write'],
      );

      final str = group.toString();
      expect(str, contains('files'));
      expect(str, contains('Files'));
      expect(str, contains('2'));
    });
  });

  // TC-008: Group grant and revoke (PermissionGroupManager)
  group('TC-008: Group grant and revoke', () {
    late PermissionGroupManager manager;

    const fileGroup = PermissionGroup(
      id: 'fileManagement',
      label: 'File Management',
      permissions: ['file.read', 'file.write'],
    );

    const networkGroup = PermissionGroup(
      id: 'networkAccess',
      label: 'Network Access',
      permissions: ['network.http'],
    );

    setUp(() {
      manager = PermissionGroupManager();
    });

    test('Normal: registerGroup registers a group', () {
      manager.registerGroup(fileGroup);

      expect(manager.hasGroup('fileManagement'), isTrue);
      expect(manager.getGroup('fileManagement'), fileGroup);
    });

    test('Normal: getPermissionsForGroup returns all permissions in group', () {
      manager.registerGroup(fileGroup);

      final permissions = manager.getPermissionsForGroup('fileManagement');
      expect(permissions, ['file.read', 'file.write']);
    });

    test('Normal: getGroupForPermission returns group id for permission', () {
      manager.registerGroup(fileGroup);

      expect(manager.getGroupForPermission('file.read'), 'fileManagement');
      expect(manager.getGroupForPermission('file.write'), 'fileManagement');
    });

    test('Normal: unregisterGroup removes group and its reverse index', () {
      manager.registerGroup(fileGroup);
      manager.unregisterGroup('fileManagement');

      expect(manager.hasGroup('fileManagement'), isFalse);
      expect(manager.getGroup('fileManagement'), isNull);
      expect(manager.getGroupForPermission('file.read'), isNull);
      expect(manager.getGroupForPermission('file.write'), isNull);
    });

    test('Normal: groupIds returns all registered group ids', () {
      manager.registerGroup(fileGroup);
      manager.registerGroup(networkGroup);

      expect(manager.groupIds, containsAll(['fileManagement', 'networkAccess']));
    });

    test('Normal: groups returns all registered group objects', () {
      manager.registerGroup(fileGroup);
      manager.registerGroup(networkGroup);

      expect(manager.groups, containsAll([fileGroup, networkGroup]));
      expect(manager.groups.length, 2);
    });

    test('Normal: clear removes all groups', () {
      manager.registerGroup(fileGroup);
      manager.registerGroup(networkGroup);
      manager.clear();

      expect(manager.groupIds, isEmpty);
      expect(manager.groups, isEmpty);
      expect(manager.hasGroup('fileManagement'), isFalse);
      expect(manager.getGroupForPermission('file.read'), isNull);
    });

    test('Normal: registerGroup replaces existing group with same id', () {
      manager.registerGroup(fileGroup);

      const updatedGroup = PermissionGroup(
        id: 'fileManagement',
        label: 'Updated File Management',
        permissions: ['file.read', 'file.write', 'file.delete'],
      );
      manager.registerGroup(updatedGroup);

      expect(manager.getGroup('fileManagement')!.label, 'Updated File Management');
      expect(
        manager.getPermissionsForGroup('fileManagement'),
        ['file.read', 'file.write', 'file.delete'],
      );
    });

    test('Boundary: getPermissionsForGroup returns empty for unknown group', () {
      expect(manager.getPermissionsForGroup('nonexistent'), isEmpty);
    });

    test('Boundary: getGroupForPermission returns null for unknown permission', () {
      expect(manager.getGroupForPermission('unknown.perm'), isNull);
    });

    test('Boundary: unregisterGroup on non-existent group does nothing', () {
      // Should not throw
      manager.unregisterGroup('nonexistent');
      expect(manager.groupIds, isEmpty);
    });

    test('Error: getGroup returns null for unregistered group', () {
      expect(manager.getGroup('notRegistered'), isNull);
    });

    test('Normal: replacing group cleans up old reverse index entries', () {
      const original = PermissionGroup(
        id: 'files',
        label: 'Files',
        permissions: ['file.read', 'file.write'],
      );
      manager.registerGroup(original);

      // Replace with a group that no longer includes file.write
      const updated = PermissionGroup(
        id: 'files',
        label: 'Files',
        permissions: ['file.read'],
      );
      manager.registerGroup(updated);

      expect(manager.getGroupForPermission('file.read'), 'files');
      expect(manager.getGroupForPermission('file.write'), isNull);
    });

    test('Normal: getPermissionsForGroup returns unmodifiable list', () {
      manager.registerGroup(fileGroup);

      final permissions = manager.getPermissionsForGroup('fileManagement');
      expect(
        () => permissions.add('file.delete'),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('Normal: toString includes group count', () {
      manager.registerGroup(fileGroup);
      expect(manager.toString(), contains('1'));
    });
  });
}
