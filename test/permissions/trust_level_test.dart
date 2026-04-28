import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/permissions/trust_level.dart';

void main() {
  group('TrustLevel Enum Tests', () {
    group('TC-001: Trust level definitions - untrusted', () {
      test('TC-001 Normal: untrusted has lowest index', () {
        expect(TrustLevel.untrusted.index, 0);
      });

      test('TC-001 Boundary: untrusted does not meet basic', () {
        final manager = TrustLevelManager();
        manager.setLevel(TrustLevel.untrusted);
        expect(manager.meetsLevel(TrustLevel.basic), false);
      });
    });

    group('TC-002: Trust level definitions - basic', () {
      test('TC-002 Normal: basic permissions allowed', () {
        final manager = TrustLevelManager();
        manager.setLevel(TrustLevel.basic);

        expect(manager.isPermissionAllowed('clipboard.read'), true);
        expect(manager.isPermissionAllowed('systemInfo'), true);
        expect(manager.isPermissionAllowed('notification'), true);
      });

      test('TC-002 Boundary: file.read denied at basic level', () {
        final manager = TrustLevelManager();
        manager.setLevel(TrustLevel.basic);
        expect(manager.isPermissionAllowed('file.read'), false);
      });
    });

    group('TC-003: Trust level definitions - elevated', () {
      test('TC-003 Normal: elevated includes basic-level permissions', () {
        final manager = TrustLevelManager();
        manager.setLevel(TrustLevel.elevated);

        // Basic-level permissions
        expect(manager.isPermissionAllowed('clipboard.read'), true);
        expect(manager.isPermissionAllowed('systemInfo'), true);
        expect(manager.isPermissionAllowed('notification'), true);

        // Elevated-level permissions
        expect(manager.isPermissionAllowed('file.read'), true);
        expect(manager.isPermissionAllowed('http'), true);
        expect(manager.isPermissionAllowed('clipboard.write'), true);
      });

      test('TC-003 Boundary: file.write denied at elevated level', () {
        final manager = TrustLevelManager();
        manager.setLevel(TrustLevel.elevated);
        expect(manager.isPermissionAllowed('file.write'), false);
      });
    });

    group('TC-004: Trust level definitions - full', () {
      test('TC-004 Normal: full includes all permissions', () {
        final manager = TrustLevelManager();
        manager.setLevel(TrustLevel.full);

        // All levels
        expect(manager.isPermissionAllowed('clipboard.read'), true);
        expect(manager.isPermissionAllowed('file.read'), true);
        expect(manager.isPermissionAllowed('file.write'), true);
        expect(manager.isPermissionAllowed('shell'), true);
        expect(manager.isPermissionAllowed('exec'), true);
      });

      test('TC-004 Error: unknown permission defaults to full trust requirement', () {
        final manager = TrustLevelManager();
        final required = manager.getRequiredLevel('unknown.permission');
        expect(required, TrustLevel.full);
      });
    });

    group('TC-005: Trust level escalation', () {
      test('TC-005 Normal: current level matches required - no escalation', () {
        final manager = TrustLevelManager();
        manager.setLevel(TrustLevel.elevated);
        expect(manager.meetsLevel(TrustLevel.elevated), true);
      });

      test('TC-005 Error: current level below required', () {
        final manager = TrustLevelManager();
        manager.setLevel(TrustLevel.basic);
        expect(manager.meetsLevel(TrustLevel.elevated), false);
      });
    });
  });

  group('TrustLevelManager Tests', () {
    late TrustLevelManager manager;

    setUp(() {
      manager = TrustLevelManager();
    });

    test('default level is basic', () {
      expect(manager.currentLevel, TrustLevel.basic);
    });

    test('setLevel changes current level', () {
      manager.setLevel(TrustLevel.full);
      expect(manager.currentLevel, TrustLevel.full);
    });

    test('meetsLevel checks hierarchy correctly', () {
      manager.setLevel(TrustLevel.elevated);
      expect(manager.meetsLevel(TrustLevel.untrusted), true);
      expect(manager.meetsLevel(TrustLevel.basic), true);
      expect(manager.meetsLevel(TrustLevel.elevated), true);
      expect(manager.meetsLevel(TrustLevel.full), false);
    });

    test('getRequiredLevel maps permission types correctly', () {
      expect(manager.getRequiredLevel('clipboard.read'), TrustLevel.basic);
      expect(manager.getRequiredLevel('systemInfo'), TrustLevel.basic);
      expect(manager.getRequiredLevel('notification'), TrustLevel.basic);
      expect(manager.getRequiredLevel('file.read'), TrustLevel.elevated);
      expect(manager.getRequiredLevel('http'), TrustLevel.elevated);
      expect(manager.getRequiredLevel('clipboard.write'), TrustLevel.elevated);
      expect(manager.getRequiredLevel('file.write'), TrustLevel.full);
      expect(manager.getRequiredLevel('shell'), TrustLevel.full);
      expect(manager.getRequiredLevel('exec'), TrustLevel.full);
    });

    test('reset returns to basic', () {
      manager.setLevel(TrustLevel.full);
      manager.reset();
      expect(manager.currentLevel, TrustLevel.basic);
    });

    test('toString includes level name', () {
      manager.setLevel(TrustLevel.elevated);
      expect(manager.toString(), contains('elevated'));
    });
  });
}
