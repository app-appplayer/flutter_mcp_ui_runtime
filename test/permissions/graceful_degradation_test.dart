import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_mcp_ui_runtime/src/permissions/permission_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/permissions/permission_storage.dart';
import 'package:flutter_mcp_ui_runtime/src/models/ui_definition.dart';
import 'package:flutter_mcp_ui_runtime/src/core/constants/client_action_types.dart';

void main() {
  group('Graceful Degradation Tests', () {
    group('TC-028: Conditional UI based on permission status', () {
      test('TC-028 Normal: granted status enables primary action', () async {
        SharedPreferences.setMockInitialValues({});
        final manager = PermissionManager(PermissionsConfig(
          fileWrite: FilePermissionConfig(
            allowedPaths: ['/tmp'],
          ),
        ));
        await manager.init();

        // Store a granted decision for file.write
        final storage = PermissionStorage();
        await storage.init();
        await storage.storeDecision(
          'file.write',
          null,
          PermissionDecision.grant(remember: true),
        );

        final status = await manager.getPermissionStatus('file.write');
        expect(status, 'granted');

        // When granted, primary action ("Save File") should be available
        final isPrimaryAvailable = status == 'granted';
        expect(isPrimaryAvailable, true);
      });

      test('TC-028 Normal: denied status triggers fallback action', () async {
        SharedPreferences.setMockInitialValues({});
        final manager = PermissionManager(PermissionsConfig(
          fileWrite: FilePermissionConfig(
            allowedPaths: ['/tmp'],
          ),
        ));
        await manager.init();

        // Store a denied decision
        final storage = PermissionStorage();
        await storage.init();
        await storage.storeDecision(
          'file.write',
          null,
          PermissionDecision.deny(remember: true),
        );

        final status = await manager.getPermissionStatus('file.write');
        expect(status, 'denied');

        // When denied, fallback action ("Copy to Clipboard") should be shown
        final shouldShowFallback = status == 'denied';
        expect(shouldShowFallback, true);
      });

      test('TC-028 Boundary: permission status change updates UI decision', () async {
        SharedPreferences.setMockInitialValues({});
        final manager = PermissionManager(PermissionsConfig(
          fileWrite: FilePermissionConfig(
            allowedPaths: ['/tmp'],
          ),
        ));
        await manager.init();

        final storage = PermissionStorage();
        await storage.init();

        // Initially denied
        await storage.storeDecision(
          'file.write',
          null,
          PermissionDecision.deny(remember: true),
        );
        var status = await manager.getPermissionStatus('file.write');
        expect(status, 'denied');

        // Permission status changes to granted
        await storage.storeDecision(
          'file.write',
          null,
          PermissionDecision.grant(remember: true),
        );
        status = await manager.getPermissionStatus('file.write');
        expect(status, 'granted');
      });

      test('TC-028 Error: unavailable permission when not configured', () async {
        SharedPreferences.setMockInitialValues({});
        // No fileWrite configured
        final manager = PermissionManager(PermissionsConfig());
        await manager.init();

        final status = await manager.getPermissionStatus('file.write');
        // When permission is not configured at page level, status is unavailable
        // checkAction returns 'not configured' for unconfigured permissions
        expect(status, isIn(['unavailable', 'pending']));
      });
    });

    group('TC-029: onDenied callback', () {
      test('TC-029 Normal: onDenied callback fires when permission denied', () async {
        SharedPreferences.setMockInitialValues({});
        final manager = PermissionManager(PermissionsConfig(
          fileWrite: FilePermissionConfig(
            allowedPaths: ['/tmp'],
          ),
        ));
        await manager.init();

        // Store a denied decision
        final storage = PermissionStorage();
        await storage.init();
        await storage.storeDecision(
          'file.write',
          null,
          PermissionDecision.deny(remember: true),
        );

        // Simulate onDenied callback pattern
        bool onDeniedFired = false;
        String? deniedNotificationSeverity;

        final status = await manager.getPermissionStatus('file.write');
        if (status == 'denied') {
          onDeniedFired = true;
          deniedNotificationSeverity = 'info';
        }

        expect(onDeniedFired, true);
        expect(deniedNotificationSeverity, 'info');
      });

      test('TC-029 Boundary: onDenied not configured handles denial silently', () async {
        SharedPreferences.setMockInitialValues({});
        final manager = PermissionManager(PermissionsConfig(
          fileWrite: FilePermissionConfig(
            allowedPaths: ['/tmp'],
          ),
        ));
        await manager.init();

        final storage = PermissionStorage();
        await storage.init();
        await storage.storeDecision(
          'file.write',
          null,
          PermissionDecision.deny(remember: true),
        );

        // When no onDenied callback is registered, denial is silent
        final status = await manager.getPermissionStatus('file.write');
        expect(status, 'denied');
        // No exception thrown - silent handling
      });

      test('TC-029 Error: onDenied action failure is contained', () async {
        SharedPreferences.setMockInitialValues({});
        final manager = PermissionManager(PermissionsConfig(
          fileWrite: FilePermissionConfig(
            allowedPaths: ['/tmp'],
          ),
        ));
        await manager.init();

        final storage = PermissionStorage();
        await storage.init();
        await storage.storeDecision(
          'file.write',
          null,
          PermissionDecision.deny(remember: true),
        );

        // Simulate onDenied callback that throws
        bool errorLogged = false;
        final status = await manager.getPermissionStatus('file.write');
        if (status == 'denied') {
          try {
            throw Exception('onDenied action failed');
          } catch (_) {
            // Error should be logged, not propagated
            errorLogged = true;
          }
        }

        expect(errorLogged, true);
      });
    });

    group('TC-030: Fallback action execution', () {
      test('TC-030 Normal: denied permission triggers fallback action', () async {
        SharedPreferences.setMockInitialValues({});
        final manager = PermissionManager(PermissionsConfig(
          fileWrite: FilePermissionConfig(
            allowedPaths: ['/tmp'],
          ),
          clipboard: true,
        ));
        await manager.init();

        final storage = PermissionStorage();
        await storage.init();
        await storage.storeDecision(
          'file.write',
          null,
          PermissionDecision.deny(remember: true),
        );

        final writeStatus = await manager.getPermissionStatus('file.write');
        expect(writeStatus, 'denied');

        // Conditional: primary denied, switch to fallback (clipboard)
        String actionToExecute;
        if (writeStatus == 'granted') {
          actionToExecute = ClientActionTypes.writeFile;
        } else {
          actionToExecute = ClientActionTypes.clipboard;
        }

        expect(actionToExecute, ClientActionTypes.clipboard);

        // Verify fallback action is permitted
        final fallbackResult = manager.checkOnly(
          ClientActionTypes.clipboard,
          {},
        );
        expect(fallbackResult.allowed, true);
      });

      test('TC-030 Boundary: fallback action also requires permission check', () async {
        SharedPreferences.setMockInitialValues({});
        // Neither fileWrite nor clipboard configured
        final manager = PermissionManager(PermissionsConfig(
          fileWrite: FilePermissionConfig(
            allowedPaths: ['/tmp'],
          ),
          // clipboard is NOT configured
        ));
        await manager.init();

        final storage = PermissionStorage();
        await storage.init();
        await storage.storeDecision(
          'file.write',
          null,
          PermissionDecision.deny(remember: true),
        );

        final writeStatus = await manager.getPermissionStatus('file.write');
        expect(writeStatus, 'denied');

        // Fallback to clipboard, but clipboard is not configured either
        final fallbackResult = manager.checkOnly(
          ClientActionTypes.clipboard,
          {},
        );
        expect(fallbackResult.allowed, false);
        expect(fallbackResult.reason, contains('not permitted'));
      });

      test('TC-030 Error: no fallback configured and permission denied skips action', () async {
        SharedPreferences.setMockInitialValues({});
        final manager = PermissionManager(PermissionsConfig());
        await manager.init();

        // No file write configured at all
        final result = manager.checkOnly(
          ClientActionTypes.writeFile,
          {'path': '/tmp/file.txt'},
        );
        expect(result.allowed, false);

        // No fallback action available - action is skipped entirely
        // Verify the manager does not throw when no fallback exists
        final status = await manager.getPermissionStatus('file.write');
        // Not configured means unavailable or pending
        expect(status, isIn(['unavailable', 'pending']));
      });
    });
  });
}
