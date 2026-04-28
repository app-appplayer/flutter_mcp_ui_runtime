import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/responsive/orientation_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Orientation Handling Tests', () {
    final List<MethodCall> methodCalls = [];

    setUp(() {
      OrientationManager.reset();
      methodCalls.clear();

      // Mock SystemChrome method channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          methodCalls.add(call);
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    // TC-020: Orientation change triggers re-evaluation
    group('TC-020: Orientation state changes', () {
      test('lock and unlock change state correctly', () async {
        expect(OrientationManager.isLocked, isFalse);
        expect(OrientationManager.currentLock, isNull);

        await OrientationManager.lockPortrait();
        expect(OrientationManager.isLocked, isTrue);
        expect(OrientationManager.currentLock, equals('portrait'));

        await OrientationManager.unlock();
        expect(OrientationManager.isLocked, isFalse);
        expect(OrientationManager.currentLock, isNull);
      });

      test('switching lock mode updates state', () async {
        await OrientationManager.lockPortrait();
        expect(OrientationManager.currentLock, equals('portrait'));

        await OrientationManager.lockLandscape();
        expect(OrientationManager.currentLock, equals('landscape'));
      });
    });

    // TC-021: Orientation lock — portrait
    group('TC-021: Portrait lock', () {
      test('lockPortrait sets preferred orientations to portrait', () async {
        await OrientationManager.lockPortrait();

        expect(OrientationManager.currentLock, equals('portrait'));
        expect(OrientationManager.isLocked, isTrue);

        // Verify SystemChrome was called
        final setCall = methodCalls.where(
          (c) => c.method == 'SystemChrome.setPreferredOrientations',
        );
        expect(setCall, isNotEmpty);
      });

      test('lock("portrait") delegates to lockPortrait', () async {
        await OrientationManager.lock('portrait');
        expect(OrientationManager.currentLock, equals('portrait'));
      });
    });

    // TC-022: Orientation lock — landscape
    group('TC-022: Landscape lock', () {
      test('lockLandscape sets preferred orientations to landscape', () async {
        await OrientationManager.lockLandscape();

        expect(OrientationManager.currentLock, equals('landscape'));
        expect(OrientationManager.isLocked, isTrue);

        final setCall = methodCalls.where(
          (c) => c.method == 'SystemChrome.setPreferredOrientations',
        );
        expect(setCall, isNotEmpty);
      });

      test('lock("landscape") delegates to lockLandscape', () async {
        await OrientationManager.lock('landscape');
        expect(OrientationManager.currentLock, equals('landscape'));
      });

      test('lock with null-equivalent (unknown mode) does not lock', () async {
        await OrientationManager.lock('invalid');
        expect(OrientationManager.isLocked, isFalse);
        expect(OrientationManager.currentLock, isNull);
      });
    });

    // TC-023: Orientation unlock
    group('TC-023: Orientation unlock', () {
      test('unlock after lock removes lock', () async {
        await OrientationManager.lockPortrait();
        expect(OrientationManager.isLocked, isTrue);

        await OrientationManager.unlock();
        expect(OrientationManager.isLocked, isFalse);
        expect(OrientationManager.currentLock, isNull);
      });

      test('unlock when not locked is a no-op', () async {
        expect(OrientationManager.isLocked, isFalse);

        await OrientationManager.unlock();
        expect(OrientationManager.isLocked, isFalse);
        expect(OrientationManager.currentLock, isNull);
      });

      test('unlock calls SystemChrome with empty orientations', () async {
        await OrientationManager.lockLandscape();
        methodCalls.clear();

        await OrientationManager.unlock();

        final setCall = methodCalls.where(
          (c) => c.method == 'SystemChrome.setPreferredOrientations',
        );
        expect(setCall, isNotEmpty);
      });
    });

    // =========================================================================
    // TC-031: Orientation lock on unsupported platform
    // =========================================================================
    group('TC-031: Orientation lock on unsupported platform', () {
      test('Normal: orientation lock on mobile → lock applied', () async {
        await OrientationManager.lockPortrait();
        expect(OrientationManager.isLocked, isTrue);
        expect(OrientationManager.currentLock, equals('portrait'));

        final setCall = methodCalls.where(
          (c) => c.method == 'SystemChrome.setPreferredOrientations',
        );
        expect(setCall, isNotEmpty);
      });

      test('Boundary: lock with unknown mode → ignored with warning', () async {
        // 'desktop' is not a valid lock mode ('portrait' or 'landscape')
        await OrientationManager.lock('desktop');

        // Lock should not be applied
        expect(OrientationManager.isLocked, isFalse);
        expect(OrientationManager.currentLock, isNull);
      });

      test('Error: invalid lock mode → layout continues without lock', () async {
        await OrientationManager.lock('invalid_mode');

        // Verify no lock was applied
        expect(OrientationManager.isLocked, isFalse);
        expect(OrientationManager.currentLock, isNull);

        // Verify unlock still works (no-op when not locked)
        await OrientationManager.unlock();
        expect(OrientationManager.isLocked, isFalse);
      });
    });
  });
}
