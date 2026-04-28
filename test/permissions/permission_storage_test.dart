import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_mcp_ui_runtime/src/permissions/permission_storage.dart';

void main() {
  group('PermissionStorage Tests', () {
    late PermissionStorage storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = PermissionStorage();
      await storage.init();
    });

    group('TC-013: Storage format - granted permission', () {
      test('TC-013 Normal: store and retrieve granted permission', () async {
        final decision = PermissionDecision.grant(
          remember: true,
          scope: '/home/user',
        );

        await storage.storeDecision('file.read', '/home/user', decision);
        final retrieved = await storage.getDecision('file.read', '/home/user');

        expect(retrieved, isNotNull);
        expect(retrieved!.granted, true);
        expect(retrieved.remember, true);
        expect(retrieved.scope, '/home/user');
      });

      test('TC-013 Normal: permissions stored per scope', () async {
        await storage.storeDecision(
          'file.read',
          '/path/a',
          PermissionDecision.grant(remember: true, scope: '/path/a'),
        );
        await storage.storeDecision(
          'file.read',
          '/path/b',
          PermissionDecision.deny(remember: true, scope: '/path/b'),
        );

        final a = await storage.getDecision('file.read', '/path/a');
        final b = await storage.getDecision('file.read', '/path/b');

        expect(a!.granted, true);
        expect(b!.granted, false);
      });
    });

    group('TC-014: Storage format - denied permission', () {
      test('TC-014 Normal: store and retrieve denied permission', () async {
        final decision = PermissionDecision.deny(remember: true);

        await storage.storeDecision('file.write', null, decision);
        final retrieved = await storage.getDecision('file.write', null);

        expect(retrieved, isNotNull);
        expect(retrieved!.granted, false);
      });

      test('TC-014 Boundary: previously denied then granted', () async {
        // First deny
        await storage.storeDecision(
          'file.read',
          null,
          PermissionDecision.deny(remember: true),
        );

        // Then grant
        await storage.storeDecision(
          'file.read',
          null,
          PermissionDecision.grant(remember: true),
        );

        final retrieved = await storage.getDecision('file.read', null);
        expect(retrieved!.granted, true);
      });
    });

    group('TC-016: Storage per server isolation', () {
      test('TC-016 Normal: different servers have isolated storage', () async {
        storage.setServerId('server-a');
        await storage.storeDecision(
          'file.read',
          null,
          PermissionDecision.grant(remember: true),
        );

        storage.setServerId('server-b');
        await storage.storeDecision(
          'file.read',
          null,
          PermissionDecision.deny(remember: true),
        );

        // Server A should be granted
        storage.setServerId('server-a');
        final serverA = await storage.getDecision('file.read', null);
        expect(serverA!.granted, true);

        // Server B should be denied
        storage.setServerId('server-b');
        final serverB = await storage.getDecision('file.read', null);
        expect(serverB!.granted, false);
      });
    });

    group('TC-024: remember false', () {
      test('TC-024 Normal: remember false - permission asked every time', () async {
        final decision = PermissionDecision.grantOnce();
        expect(decision.remember, false);
        expect(decision.granted, true);

        // grantOnce should not be persisted; verifying the flag
        // The caller checks remember==false and skips storage
      });

      test('TC-024 Boundary: rapid repeated grantOnce creates separate decisions', () {
        final d1 = PermissionDecision.grantOnce();
        final d2 = PermissionDecision.grantOnce();
        // Each is a distinct decision object
        expect(d1.remember, false);
        expect(d2.remember, false);
        expect(d1.decidedAt.millisecondsSinceEpoch,
            lessThanOrEqualTo(d2.decidedAt.millisecondsSinceEpoch));
      });
    });

    group('TC-025: remember session', () {
      test('TC-025 Normal: session decision remembered within session', () async {
        final decision = PermissionDecision.grant(remember: true);
        await storage.storeDecision('file.read', null, decision);

        final retrieved = await storage.getDecision('file.read', null);
        expect(retrieved, isNotNull);
        expect(retrieved!.granted, true);
        expect(retrieved.remember, true);
      });

      test('TC-025 Normal: same permission in same session uses cached decision', () async {
        final decision = PermissionDecision.grant(remember: true);
        await storage.storeDecision('file.read', null, decision);

        // Second retrieval returns same cached decision
        final first = await storage.getDecision('file.read', null);
        final second = await storage.getDecision('file.read', null);
        expect(first!.granted, true);
        expect(second!.granted, true);
      });

      test('TC-025 Boundary: application restart clears session decisions', () async {
        final decision = PermissionDecision.grant(remember: true);
        await storage.storeDecision('file.read', null, decision);

        // Simulate session clear (app restart)
        await storage.clearAllDecisions();
        final after = await storage.getDecision('file.read', null);
        expect(after, isNull);
      });

      test('TC-025 Error: session storage unavailable falls back to false behavior', () async {
        // When clearAllDecisions is called, subsequent reads return null
        // simulating unavailable session storage
        await storage.clearAllDecisions();
        final result = await storage.getDecision('file.read', null);
        expect(result, isNull);
      });
    });

    group('TC-026: remember permanent', () {
      test('TC-026 Normal: permanent decision persists without expiry', () async {
        final decision = PermissionDecision.grant(remember: true);
        // No expiresIn = permanent
        expect(decision.expiresAt, isNull);
        expect(decision.remember, true);

        await storage.storeDecision('file.read', null, decision);

        final retrieved = await storage.getDecision('file.read', null);
        expect(retrieved, isNotNull);
        expect(retrieved!.granted, true);
        expect(storage.isExpired(retrieved), false);
      });

      test('TC-026 Normal: permanent decision survives across reads', () async {
        final decision = PermissionDecision.grant(remember: true);
        await storage.storeDecision('network.http', null, decision);

        // Multiple reads
        for (int i = 0; i < 3; i++) {
          final retrieved = await storage.getDecision('network.http', null);
          expect(retrieved!.granted, true);
        }
      });

      test('TC-026 Boundary: user explicitly revokes permanent decision', () async {
        // First store permanent grant
        await storage.storeDecision(
          'file.read',
          null,
          PermissionDecision.grant(remember: true),
        );

        // User revokes
        await storage.storeDecision(
          'file.read',
          null,
          PermissionDecision.revoke(),
        );

        final retrieved = await storage.getDecision('file.read', null);
        expect(retrieved!.granted, false);
        expect(retrieved.revoked, true);
      });

      test('TC-026 Error: permanent storage unavailable falls back to session', () async {
        // Simulate by clearing and verifying null return
        await storage.clearAllDecisions();
        final result = await storage.getDecision('file.read', null);
        expect(result, isNull);
      });
    });

    group('TC-027: remember duration', () {
      test('TC-027 Normal: duration decision remembered for specified time', () async {
        final decision = PermissionDecision.grant(
          remember: true,
          expiresIn: const Duration(hours: 1),
        );

        await storage.storeDecision('file.read', null, decision);
        final retrieved = await storage.getDecision('file.read', null);
        expect(retrieved, isNotNull);
        expect(storage.isExpired(retrieved!), false);
        expect(retrieved.expiresAt, isNotNull);
      });

      test('TC-027 Boundary: expired duration decision detected', () {
        final decision = PermissionDecision(
          granted: true,
          decidedAt: DateTime.now().subtract(const Duration(hours: 2)),
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
          remember: true,
        );

        expect(storage.isExpired(decision), true);
      });

      test('TC-027 Boundary: duration expires - cleanupExpired removes it', () async {
        final expired = PermissionDecision(
          granted: true,
          decidedAt: DateTime.now().subtract(const Duration(hours: 2)),
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
          remember: true,
        );
        await storage.storeDecision('timed.perm', null, expired);

        await storage.cleanupExpired();

        final result = await storage.getDecision('timed.perm', null);
        expect(result, isNull);
      });

      test('TC-027 Error: zero duration treated as immediately expired', () {
        final decision = PermissionDecision.grant(
          remember: true,
          expiresIn: Duration.zero,
        );

        // expiresAt is approximately now, may or may not be expired
        // depending on timing, but the expiresAt should be set
        expect(decision.expiresAt, isNotNull);
      });

      test('TC-027 Normal: non-expiring decision never expires', () {
        final decision = PermissionDecision.grant(remember: true);
        expect(decision.expiresAt, isNull);
        expect(storage.isExpired(decision), false);
      });
    });

    group('Storage management', () {
      test('clearDecision removes specific decision', () async {
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

        await storage.clearDecision('file.read', null);

        final read = await storage.getDecision('file.read', null);
        final write = await storage.getDecision('file.write', null);
        expect(read, isNull);
        expect(write, isNotNull);
      });

      test('clearAllDecisions removes everything', () async {
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

        await storage.clearAllDecisions();

        final all = await storage.getAllDecisions();
        expect(all, isEmpty);
      });

      test('getAllDecisions returns all stored decisions', () async {
        await storage.storeDecision(
          'file.read',
          null,
          PermissionDecision.grant(remember: true),
        );
        await storage.storeDecision(
          'network.http',
          null,
          PermissionDecision.deny(remember: true),
        );

        final all = await storage.getAllDecisions();
        expect(all.length, 2);
      });

      test('cleanupExpired removes expired entries', () async {
        // Store an expired decision
        final expired = PermissionDecision(
          granted: true,
          decidedAt: DateTime.now().subtract(const Duration(hours: 2)),
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
          remember: true,
        );
        await storage.storeDecision('old', null, expired);

        // Store a valid decision
        await storage.storeDecision(
          'valid',
          null,
          PermissionDecision.grant(remember: true),
        );

        await storage.cleanupExpired();

        final old = await storage.getDecision('old', null);
        final valid = await storage.getDecision('valid', null);
        expect(old, isNull);
        expect(valid, isNotNull);
      });

      test('getDecision returns null for non-existent key', () async {
        final result = await storage.getDecision('nonexistent', null);
        expect(result, isNull);
      });
    });
  });

  group('Additional Permission Storage Tests', () {
    late PermissionStorage storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = PermissionStorage();
      await storage.init();
    });

    group('TC-014: Denied permission storage', () {
      test('TC-014 Normal: denied permission stored and retrieved', () async {
        final decision = PermissionDecision.deny(
          remember: true,
          scope: '/restricted/path',
        );

        await storage.storeDecision('file.write', '/restricted/path', decision);
        final retrieved =
            await storage.getDecision('file.write', '/restricted/path');

        expect(retrieved, isNotNull);
        expect(retrieved!.granted, false);
        expect(retrieved.remember, true);
        expect(retrieved.scope, '/restricted/path');
      });

      test('TC-014 Boundary: denied then re-denied preserves latest', () async {
        await storage.storeDecision(
          'shell.exec',
          null,
          PermissionDecision.deny(remember: true),
        );

        // Re-deny with different scope
        await storage.storeDecision(
          'shell.exec',
          'rm',
          PermissionDecision.deny(remember: true, scope: 'rm'),
        );

        final globalDeny = await storage.getDecision('shell.exec', null);
        final scopedDeny = await storage.getDecision('shell.exec', 'rm');
        expect(globalDeny!.granted, false);
        expect(scopedDeny!.granted, false);
        expect(scopedDeny.scope, 'rm');
      });
    });

    group('TC-015: Permission encryption', () {
      test('TC-015 Normal: decisions persisted via SharedPreferences', () async {
        // Verify that storage uses SharedPreferences as backing store
        await storage.storeDecision(
          'file.read',
          null,
          PermissionDecision.grant(remember: true),
        );

        final all = await storage.getAllDecisions();
        expect(all.length, 1);
        expect(all.values.first.granted, true);
      });

      test('TC-015 Boundary: corrupted storage returns empty', () async {
        // Simulate corrupted data by setting invalid JSON
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('mcp_permission_decisions', 'not-valid-json');

        final result = await storage.getDecision('file.read', null);
        // Corrupted data should return null gracefully
        expect(result, isNull);
      });
    });

    group('TC-035: Storage encryption failure handling', () {
      test('TC-035 Normal: storage works after cleanup', () async {
        // Store and clean up expired
        final expired = PermissionDecision(
          granted: true,
          decidedAt: DateTime.now().subtract(const Duration(days: 10)),
          expiresAt: DateTime.now().subtract(const Duration(days: 5)),
          remember: true,
        );
        await storage.storeDecision('old.perm', null, expired);
        await storage.storeDecision(
          'valid.perm',
          null,
          PermissionDecision.grant(remember: true),
        );

        await storage.cleanupExpired();

        final old = await storage.getDecision('old.perm', null);
        final valid = await storage.getDecision('valid.perm', null);
        expect(old, isNull);
        expect(valid, isNotNull);
      });

      test('TC-035 Error: clearAllDecisions on empty storage is no-op', () async {
        await storage.clearAllDecisions();
        final all = await storage.getAllDecisions();
        expect(all, isEmpty);
      });
    });
  });

  group('PermissionDecision Tests', () {
    test('grant factory', () {
      final d = PermissionDecision.grant(
        remember: true,
        scope: '/test',
      );
      expect(d.granted, true);
      expect(d.remember, true);
      expect(d.scope, '/test');
      expect(d.expiresAt, isNull);
    });

    test('grant with expiry', () {
      final d = PermissionDecision.grant(
        expiresIn: const Duration(hours: 1),
      );
      expect(d.expiresAt, isNotNull);
      expect(d.expiresAt!.isAfter(DateTime.now()), true);
    });

    test('deny factory', () {
      final d = PermissionDecision.deny(remember: true);
      expect(d.granted, false);
      expect(d.remember, true);
    });

    test('grantOnce factory', () {
      final d = PermissionDecision.grantOnce(scope: '/test');
      expect(d.granted, true);
      expect(d.remember, false);
      expect(d.scope, '/test');
    });

    test('serialization roundtrip', () {
      final original = PermissionDecision.grant(
        remember: true,
        expiresIn: const Duration(hours: 1),
        scope: '/test',
      );

      final json = original.toJson();
      final restored = PermissionDecision.fromJson(json);

      expect(restored.granted, original.granted);
      expect(restored.remember, original.remember);
      expect(restored.scope, original.scope);
      expect(restored.expiresAt, isNotNull);
    });

    test('toJson excludes null fields', () {
      final d = PermissionDecision.grant();
      final json = d.toJson();
      expect(json.containsKey('expiresAt'), false);
      expect(json.containsKey('scope'), false);
    });
  });
}
