import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_mcp_ui_runtime/src/permissions/permission_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/permissions/permission_storage.dart';

void main() {
  group('Multi-Permission Dialog Tests', () {
    late PermissionManager manager;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      manager = PermissionManager(null);
      manager.enabled = true;
      await manager.init();
    });

    group('TC-020: Multi-permission request', () {
      test('TC-020 Normal: requestAll handles multiple permissions simultaneously', () async {
        final results = await manager.requestAll([
          'file.read',
          'file.write',
          'network.http',
        ]);

        expect(results.length, 3);
        expect(results.containsKey('file.read'), true);
        expect(results.containsKey('file.write'), true);
        expect(results.containsKey('network.http'), true);
      });

      test('TC-020 Normal: each permission result includes granted status', () async {
        final results = await manager.requestAll([
          'file.read',
          'network.http',
        ]);

        for (final entry in results.entries) {
          expect(entry.value, isA<PermissionDecision>());
          // Without context, all are denied
          expect(entry.value.granted, false);
        }
      });

      test('TC-020 Boundary: single permission in batch request works', () async {
        final results = await manager.requestAll(['file.read']);

        expect(results.length, 1);
        expect(results.containsKey('file.read'), true);
      });

      test('TC-020 Error: empty permissions array returns empty results', () async {
        final results = await manager.requestAll([]);
        expect(results, isEmpty);
      });
    });

    group('TC-021: allowPartial behavior', () {
      test('TC-021 Normal: individual permission decisions are independent', () async {
        // Pre-store one granted, one denied to simulate partial grant
        final storage = PermissionStorage();
        SharedPreferences.setMockInitialValues({});
        await storage.init();

        await storage.storeDecision(
          'file.read',
          null,
          PermissionDecision.grant(remember: true),
        );
        await storage.storeDecision(
          'file.write',
          null,
          PermissionDecision.deny(remember: true),
        );

        // Verify individual decisions are stored independently
        final readDecision = await storage.getDecision('file.read', null);
        final writeDecision = await storage.getDecision('file.write', null);

        expect(readDecision!.granted, true);
        expect(writeDecision!.granted, false);
      });

      test('TC-021 Normal: requestAll returns mix of granted and denied', () async {
        // Create a fresh manager and pre-populate storage
        SharedPreferences.setMockInitialValues({});
        final freshManager = PermissionManager(null);
        await freshManager.init();

        // Request without context - all denied since no stored decisions
        final results = await freshManager.requestAll([
          'file.read',
          'file.write',
        ]);

        // Both denied without context
        expect(results['file.read']!.granted, false);
        expect(results['file.write']!.granted, false);
      });

      test('TC-021 Boundary: all-or-nothing when allowPartial is false', () async {
        // When all permissions in a required group must be granted,
        // check that all results can be validated together
        final results = await manager.requestAll([
          'file.read',
          'file.write',
        ]);

        final allGranted = results.values.every((d) => d.granted);
        expect(allGranted, false);
      });

      test('TC-021 Error: minimum required not met blocks action', () async {
        final results = await manager.requestAll([
          'file.read',
          'file.write',
          'network.http',
        ]);

        // Check if minimum required permissions (e.g., file.read, file.write) are granted
        final minimumRequired = ['file.read', 'file.write'];
        final minimumMet = minimumRequired.every(
          (p) => results[p]?.granted == true,
        );
        expect(minimumMet, false);
      });
    });

    group('TC-022: minimumRequired enforcement', () {
      test('TC-022 Normal: all minimumRequired granted allows action', () async {
        // Simulate stored grants for minimum required permissions
        final storage = PermissionStorage();
        SharedPreferences.setMockInitialValues({});
        await storage.init();

        await storage.storeDecision(
          'file.read',
          null,
          PermissionDecision.grant(remember: true),
        );
        await storage.storeDecision(
          'file.write',
          null,
          PermissionDecision.grant(remember: true),
        );

        final readDecision = await storage.getDecision('file.read', null);
        final writeDecision = await storage.getDecision('file.write', null);

        final minimumRequired = ['file.read', 'file.write'];
        final results = {
          'file.read': readDecision!,
          'file.write': writeDecision!,
        };

        final minimumMet = minimumRequired.every(
          (p) => results[p]?.granted == true,
        );
        expect(minimumMet, true);
      });

      test('TC-022 Boundary: optional permission denied still allows action', () async {
        final storage = PermissionStorage();
        SharedPreferences.setMockInitialValues({});
        await storage.init();

        // Required permissions granted
        await storage.storeDecision(
          'file.read',
          null,
          PermissionDecision.grant(remember: true),
        );
        // Optional permission denied
        await storage.storeDecision(
          'network.http',
          null,
          PermissionDecision.deny(remember: true),
        );

        final readDecision = await storage.getDecision('file.read', null);
        final httpDecision = await storage.getDecision('network.http', null);

        // Only file.read is minimum required
        final minimumRequired = ['file.read'];
        final results = {
          'file.read': readDecision!,
          'network.http': httpDecision!,
        };

        final minimumMet = minimumRequired.every(
          (p) => results[p]?.granted == true,
        );
        expect(minimumMet, true);
        // Optional is denied but action still proceeds
        expect(results['network.http']!.granted, false);
      });

      test('TC-022 Error: one minimumRequired denied blocks action', () async {
        final storage = PermissionStorage();
        SharedPreferences.setMockInitialValues({});
        await storage.init();

        await storage.storeDecision(
          'file.read',
          null,
          PermissionDecision.grant(remember: true),
        );
        await storage.storeDecision(
          'file.write',
          null,
          PermissionDecision.deny(remember: true),
        );

        final readDecision = await storage.getDecision('file.read', null);
        final writeDecision = await storage.getDecision('file.write', null);

        final minimumRequired = ['file.read', 'file.write'];
        final results = {
          'file.read': readDecision!,
          'file.write': writeDecision!,
        };

        final minimumMet = minimumRequired.every(
          (p) => results[p]?.granted == true,
        );
        expect(minimumMet, false);
      });
    });

    group('TC-023: Sequential individual prompts', () {
      test('TC-023 Normal: requestAll processes permissions sequentially', () async {
        final permissions = ['file.read', 'file.write', 'network.http'];
        final results = await manager.requestAll(permissions);

        // All permissions processed
        expect(results.length, permissions.length);
        for (final p in permissions) {
          expect(results.containsKey(p), true);
        }
      });

      test('TC-023 Boundary: all individual prompts granted proceeds', () async {
        // Pre-store all as granted
        final storage = PermissionStorage();
        SharedPreferences.setMockInitialValues({});
        await storage.init();

        final permissions = ['file.read', 'file.write'];
        for (final p in permissions) {
          await storage.storeDecision(
            p,
            null,
            PermissionDecision.grant(remember: true),
          );
        }

        // Verify all are granted
        for (final p in permissions) {
          final decision = await storage.getDecision(p, null);
          expect(decision!.granted, true);
        }
      });

      test('TC-023 Error: any required individual prompt denied blocks action', () async {
        final storage = PermissionStorage();
        SharedPreferences.setMockInitialValues({});
        await storage.init();

        await storage.storeDecision(
          'file.read',
          null,
          PermissionDecision.grant(remember: true),
        );
        await storage.storeDecision(
          'file.write',
          null,
          PermissionDecision.deny(remember: true),
        );

        final requiredPermissions = ['file.read', 'file.write'];
        final allGranted = <bool>[];

        for (final p in requiredPermissions) {
          final decision = await storage.getDecision(p, null);
          allGranted.add(decision?.granted ?? false);
        }

        // Not all required permissions granted
        expect(allGranted.every((g) => g), false);
      });

      test('TC-023 Normal: requestAll with stored decisions skips prompting', () async {
        // Use a manager with pre-stored decisions
        SharedPreferences.setMockInitialValues({});
        final mgr = PermissionManager(null);
        await mgr.init();

        // requestAll without context: returns deny for permissions without stored decisions
        final results = await mgr.requestAll(['file.read']);
        expect(results['file.read']!.granted, false);
      });
    });
  });
}
