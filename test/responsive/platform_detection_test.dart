import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/responsive/platform_detector.dart';

void main() {
  group('Platform Detection Tests', () {
    setUp(() {
      PlatformDetector.resetCache();
    });

    // TC-016: Platform detection — mobile
    group('TC-016: Mobile detection', () {
      test('phone-sized device (width < 600) returns mobile', () {
        final result = PlatformDetector.classify(375);
        expect(result, equals(PlatformType.mobile));
      });

      test('width exactly 599 returns mobile', () {
        final result = PlatformDetector.classify(599);
        expect(result, equals(PlatformType.mobile));
      });

      test('small width returns mobile', () {
        final result = PlatformDetector.classify(320);
        expect(result, equals(PlatformType.mobile));
      });
    });

    // TC-017: Platform detection — tablet
    group('TC-017: Tablet detection', () {
      test('medium screen with touch (600 <= width < 1024) returns tablet', () {
        final result = PlatformDetector.classify(768, hasTouch: true);
        expect(result, equals(PlatformType.tablet));
      });

      test('width exactly 600 with touch returns tablet', () {
        final result = PlatformDetector.classify(600, hasTouch: true);
        expect(result, equals(PlatformType.tablet));
      });

      test('medium screen without touch returns desktop', () {
        final result = PlatformDetector.classify(768, hasTouch: false);
        expect(result, equals(PlatformType.desktop));
      });
    });

    // TC-018: Platform detection — desktop and web
    group('TC-018: Desktop and web detection', () {
      test('large screen with pointer input returns desktop', () {
        final result = PlatformDetector.classify(1440, hasTouch: false);
        expect(result, equals(PlatformType.desktop));
      });

      test('width 1024 without touch returns desktop', () {
        final result = PlatformDetector.classify(1024, hasTouch: false);
        expect(result, equals(PlatformType.desktop));
      });

      test('large screen with touch returns desktop (width >= 1024)', () {
        final result = PlatformDetector.classify(1440, hasTouch: true);
        expect(result, equals(PlatformType.desktop));
      });

      // Note: kIsWeb is a compile-time constant and cannot be mocked in unit tests.
      // Web detection is verified through the classify logic: if kIsWeb were true,
      // PlatformType.web would be returned regardless of width/touch.
    });

    // TC-019: Platform detection caching
    group('TC-019: Caching', () {
      test('detect caches result after first call', () {
        final first = PlatformDetector.detect(375, hasTouch: true);
        expect(first, equals(PlatformType.mobile));
        expect(PlatformDetector.cached, equals(PlatformType.mobile));
      });

      test('subsequent detect returns cached value regardless of new width', () {
        final first = PlatformDetector.detect(375, hasTouch: true);
        expect(first, equals(PlatformType.mobile));

        // Screen resize should not change cached platform type
        final second = PlatformDetector.detect(1440, hasTouch: false);
        expect(second, equals(PlatformType.mobile));
      });

      test('resetCache allows re-detection', () {
        PlatformDetector.detect(375, hasTouch: true);
        expect(PlatformDetector.cached, equals(PlatformType.mobile));

        PlatformDetector.resetCache();
        expect(PlatformDetector.cached, isNull);

        PlatformDetector.detect(1440, hasTouch: false);
        expect(PlatformDetector.cached, equals(PlatformType.desktop));
      });
    });
  });
}
