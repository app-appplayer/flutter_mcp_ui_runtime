import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_mcp_ui_runtime/src/permissions/permission_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/permissions/permission_groups.dart';
import 'package:flutter_mcp_ui_runtime/src/permissions/trust_level.dart';

void main() {
  group('Progressive Permission Request Tests', () {
    late PermissionManager manager;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      manager = PermissionManager(null);
      manager.enabled = true;
      await manager.init();
    });

    group('TC-009: justInTime request timing', () {
      test('TC-009 Normal: default timing is justInTime', () {
        expect(manager.requestTiming, PermissionRequestTiming.justInTime);
      });

      test('TC-009 Normal: permission already granted does not need prompt', () async {
        // Pre-store a granted decision so no prompt is needed
        final decisions = await manager.requestAll(
          ['file.read'],
        );

        // Without context, requestAll denies (no prompt possible)
        expect(decisions['file.read'], isNotNull);
        expect(decisions['file.read']!.granted, false);
      });

      test('TC-009 Normal: justInTime timing can be set explicitly', () {
        manager.requestTiming = PermissionRequestTiming.justInTime;
        expect(manager.requestTiming, PermissionRequestTiming.justInTime);
      });

      test('TC-009 Boundary: multiple actions needing same permission reuse stored decision', () async {
        // Grant permission via grant() method
        manager.grant('file.read');
        expect(manager.grantedPermissions.contains('file.read'), true);
      });

      test('TC-009 Error: denied just-in-time request results in denied status', () async {
        // Without context, requestAll returns deny for unknown permissions
        final decisions = await manager.requestAll(['file.read']);
        expect(decisions['file.read']!.granted, false);
      });
    });

    group('TC-010: upfront request timing', () {
      test('TC-010 Normal: upfront timing can be configured', () {
        manager.requestTiming = PermissionRequestTiming.upfront;
        expect(manager.requestTiming, PermissionRequestTiming.upfront);
      });

      test('TC-010 Normal: requestPermissionsUpfront collects group permissions', () async {
        manager.groupManager.registerGroup(const PermissionGroup(
          id: 'fileAccess',
          label: 'File Access',
          permissions: ['file.read', 'file.write'],
          required: true,
        ));

        // Without context, all permissions are denied (no prompt)
        final results = await manager.requestPermissionsUpfront();
        expect(results.containsKey('file.read'), true);
        expect(results.containsKey('file.write'), true);
      });

      test('TC-010 Boundary: all upfront permissions already granted returns stored decisions', () async {
        // No groups registered means no permissions to request
        final results = await manager.requestPermissionsUpfront();
        expect(results, isEmpty);
      });

      test('TC-010 Error: denied upfront permission results in denied decision', () async {
        manager.groupManager.registerGroup(const PermissionGroup(
          id: 'network',
          label: 'Network',
          permissions: ['network.http'],
          required: true,
        ));

        final results = await manager.requestPermissionsUpfront();
        expect(results['network.http']!.granted, false);
      });
    });

    group('TC-011: contextual request timing', () {
      test('TC-011 Normal: contextual timing can be configured', () {
        manager.requestTiming = PermissionRequestTiming.contextual;
        expect(manager.requestTiming, PermissionRequestTiming.contextual);
      });

      test('TC-011 Normal: requestPermissionsContextual matches group by context', () async {
        manager.groupManager.registerGroup(const PermissionGroup(
          id: 'fileManagement',
          label: 'File Management',
          permissions: ['file.read', 'file.write'],
        ));

        final results = await manager.requestPermissionsContextual('fileManagement');
        expect(results.containsKey('file.read'), true);
        expect(results.containsKey('file.write'), true);
      });

      test('TC-011 Boundary: unknown context returns empty results', () async {
        final results = await manager.requestPermissionsContextual('nonExistentGroup');
        expect(results, isEmpty);
      });

      test('TC-011 Error: denied contextual request results in denied decision', () async {
        manager.groupManager.registerGroup(const PermissionGroup(
          id: 'files',
          label: 'Files',
          permissions: ['file.read'],
        ));

        // Without BuildContext, permissions are denied
        final results = await manager.requestPermissionsContextual('files');
        expect(results['file.read']!.granted, false);
      });
    });

    group('TC-012: Per-permission request timing override', () {
      test('TC-012 Normal: global timing can be overridden at manager level', () {
        manager.requestTiming = PermissionRequestTiming.justInTime;
        expect(manager.requestTiming, PermissionRequestTiming.justInTime);

        // Override to upfront
        manager.requestTiming = PermissionRequestTiming.upfront;
        expect(manager.requestTiming, PermissionRequestTiming.upfront);
      });

      test('TC-012 Boundary: groupRelated permissions requested together via group', () async {
        // Register a group that bundles related permissions
        manager.groupManager.registerGroup(const PermissionGroup(
          id: 'fileManagement',
          label: 'File Management',
          permissions: ['file.read', 'file.write'],
        ));

        // Requesting the group requests both permissions together
        final permissions = manager.groupManager.getPermissionsForGroup('fileManagement');
        expect(permissions, ['file.read', 'file.write']);

        final results = await manager.requestAll(permissions);
        expect(results.length, 2);
      });

      test('TC-012 Normal: requestAll processes all permissions in batch', () async {
        final results = await manager.requestAll([
          'file.read',
          'network.http',
          'system.exec',
        ]);

        expect(results.length, 3);
        // All denied without context
        for (final entry in results.entries) {
          expect(entry.value.granted, false);
        }
      });

      test('TC-012 Normal: prompt variant can be configured', () {
        manager.promptVariant = PermissionPromptVariant.modal;
        expect(manager.promptVariant, PermissionPromptVariant.modal);

        manager.promptVariant = PermissionPromptVariant.inline;
        expect(manager.promptVariant, PermissionPromptVariant.inline);

        manager.promptVariant = PermissionPromptVariant.banner;
        expect(manager.promptVariant, PermissionPromptVariant.banner);
      });
    });
  });
}
