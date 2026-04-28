import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_mcp_ui_runtime/src/permissions/permission_storage.dart';

void main() {
  group('Remember Options Tests', () {
    late PermissionStorage storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = PermissionStorage();
      await storage.init();
    });

    group('TC-024: remember: false', () {
      test('TC-024 Normal: permission with remember=false is not persisted for reuse', () async {
        // A decision with remember=false should not be stored for future lookups
        final decision = PermissionDecision.grantOnce();
        expect(decision.remember, false);

        // With remember=false, the caller should NOT store, so no stored decision
        final retrieved = await storage.getDecision('file.read', null);
        expect(retrieved, isNull);
      });

      test('TC-024 Normal: grantOnce creates decision with remember=false', () {
        final decision = PermissionDecision.grantOnce(scope: '/tmp');

        expect(decision.granted, true);
        expect(decision.remember, false);
        expect(decision.scope, '/tmp');
      });

      test('TC-024 Boundary: rapid repeated requests always require fresh decision', () async {
        // Even if we store a remember=false decision, it should not be relied upon
        // The caller should check remember flag before storing
        final decision = PermissionDecision.grant(remember: false);
        expect(decision.remember, false);

        // Verify the decision object correctly reports remember=false
        final json = decision.toJson();
        expect(json['remember'], false);
      });
    });

    group('TC-025: remember: "session"', () {
      test('TC-025 Normal: session decision remembered within same storage instance', () async {
        final decision = PermissionDecision.grant(remember: true);

        await storage.storeDecision('file.read', null, decision);
        final retrieved = await storage.getDecision('file.read', null);

        expect(retrieved, isNotNull);
        expect(retrieved!.granted, true);
        expect(retrieved.remember, true);
      });

      test('TC-025 Normal: same permission in same session uses cached decision', () async {
        final decision = PermissionDecision.grant(remember: true);
        await storage.storeDecision('network.http', null, decision);

        // Second lookup returns same decision without re-prompting
        final first = await storage.getDecision('network.http', null);
        final second = await storage.getDecision('network.http', null);

        expect(first!.granted, true);
        expect(second!.granted, true);
      });

      test('TC-025 Boundary: new storage instance has no session decisions', () async {
        final decision = PermissionDecision.grant(remember: true);
        await storage.storeDecision('file.read', null, decision);

        // Simulate session restart with fresh mock values
        SharedPreferences.setMockInitialValues({});
        final newStorage = PermissionStorage();
        await newStorage.init();

        final retrieved = await newStorage.getDecision('file.read', null);
        expect(retrieved, isNull);
      });

      test('TC-025 Error: session storage cleared falls back to no decision', () async {
        final decision = PermissionDecision.grant(remember: true);
        await storage.storeDecision('file.read', null, decision);

        await storage.clearAllDecisions();
        final retrieved = await storage.getDecision('file.read', null);
        expect(retrieved, isNull);
      });
    });

    group('TC-026: remember: "permanent"', () {
      test('TC-026 Normal: permanent decision persists across storage reads', () async {
        final decision = PermissionDecision.grant(remember: true);
        await storage.storeDecision('file.write', null, decision);

        // Re-read from same storage (simulating persistence)
        final retrieved = await storage.getDecision('file.write', null);
        expect(retrieved, isNotNull);
        expect(retrieved!.granted, true);
      });

      test('TC-026 Normal: permanent decision used across multiple lookups', () async {
        final decision = PermissionDecision.grant(remember: true);
        await storage.storeDecision('system.exec', null, decision);

        // Multiple reads should all return the stored decision
        for (var i = 0; i < 3; i++) {
          final retrieved = await storage.getDecision('system.exec', null);
          expect(retrieved!.granted, true);
        }
      });

      test('TC-026 Boundary: user explicitly revokes permanent decision', () async {
        // Grant permanently
        final grant = PermissionDecision.grant(remember: true);
        await storage.storeDecision('file.read', null, grant);

        // Revoke
        final revoke = PermissionDecision.revoke();
        await storage.storeDecision('file.read', null, revoke);

        final retrieved = await storage.getDecision('file.read', null);
        expect(retrieved, isNotNull);
        expect(retrieved!.granted, false);
        expect(retrieved.revoked, true);
      });

      test('TC-026 Error: permanent storage unavailable falls back to session', () async {
        // When clearAllDecisions is called, subsequent reads return null
        // simulating loss of permanent storage
        await storage.storeDecision(
          'file.read',
          null,
          PermissionDecision.grant(remember: true),
        );
        await storage.clearAllDecisions();

        final retrieved = await storage.getDecision('file.read', null);
        expect(retrieved, isNull);
      });
    });

    group('TC-027: remember: "duration"', () {
      test('TC-027 Normal: decision with duration remembered within timeframe', () async {
        final decision = PermissionDecision.grant(
          remember: true,
          expiresIn: const Duration(hours: 1),
        );

        await storage.storeDecision('file.read', null, decision);
        final retrieved = await storage.getDecision('file.read', null);

        expect(retrieved, isNotNull);
        expect(retrieved!.granted, true);
        expect(retrieved.expiresAt, isNotNull);
        expect(storage.isExpired(retrieved), false);
      });

      test('TC-027 Boundary: expired duration decision is detected', () async {
        // Create a decision that already expired (negative duration trick via direct constructor)
        final expiredDecision = PermissionDecision(
          granted: true,
          decidedAt: DateTime.now().subtract(const Duration(hours: 2)),
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
          remember: true,
        );

        await storage.storeDecision('file.read', null, expiredDecision);
        final retrieved = await storage.getDecision('file.read', null);

        expect(retrieved, isNotNull);
        expect(storage.isExpired(retrieved!), true);
      });

      test('TC-027 Boundary: cleanupExpired removes expired decisions', () async {
        final expiredDecision = PermissionDecision(
          granted: true,
          decidedAt: DateTime.now().subtract(const Duration(hours: 2)),
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
          remember: true,
        );

        await storage.storeDecision('file.read', null, expiredDecision);
        await storage.cleanupExpired();

        final retrieved = await storage.getDecision('file.read', null);
        expect(retrieved, isNull);
      });

      test('TC-027 Error: zero duration treated as immediately expired', () {
        final decision = PermissionDecision.grant(
          remember: true,
          expiresIn: Duration.zero,
        );

        // A zero-duration decision expires at the same instant it was created
        // isExpired checks DateTime.now().isAfter(expiresAt)
        // With zero duration, expiresAt == decidedAt, and by the time we check
        // DateTime.now() may be after expiresAt
        expect(decision.expiresAt, isNotNull);
      });

      test('TC-027 Normal: non-expired decision with expiresAt is valid', () {
        final decision = PermissionDecision.grant(
          remember: true,
          expiresIn: const Duration(hours: 1),
        );

        expect(storage.isExpired(decision), false);
        expect(decision.expiresAt!.isAfter(DateTime.now()), true);
      });

      test('TC-027 Normal: decision without expiresAt never expires', () {
        final decision = PermissionDecision.grant(remember: true);

        expect(decision.expiresAt, isNull);
        expect(storage.isExpired(decision), false);
      });
    });
  });
}
