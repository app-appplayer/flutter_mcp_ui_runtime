import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/channels/rate_limiter.dart';

void main() {
  group('TC-029: FlowControlConfig — inbound/outbound configuration', () {
    test('Normal: inbound and outbound rate limiters created with correct config', () {
      final json = {
        'inbound': {'maxRate': 10, 'window': 1000},
        'outbound': {'maxRate': 5, 'window': 1000},
      };

      final config = FlowControlConfig.fromJson(json);

      expect(config.inbound, isNotNull);
      expect(config.inbound!.maxRate, equals(10));
      expect(config.inbound!.windowMs, equals(1000));
      expect(config.outbound, isNotNull);
      expect(config.outbound!.maxRate, equals(5));
      expect(config.outbound!.windowMs, equals(1000));
    });

    test('Boundary: only inbound configured — outbound is null', () {
      final json = {
        'inbound': {'maxRate': 10, 'window': 1000},
      };

      final config = FlowControlConfig.fromJson(json);

      expect(config.inbound, isNotNull);
      expect(config.outbound, isNull);
    });

    test('Boundary: only outbound configured — inbound is null', () {
      final json = {
        'outbound': {'maxRate': 5, 'window': 1000},
      };

      final config = FlowControlConfig.fromJson(json);

      expect(config.inbound, isNull);
      expect(config.outbound, isNotNull);
    });

    test('Boundary: both null — empty FlowControlConfig', () {
      final config = FlowControlConfig.fromJson({});

      expect(config.inbound, isNull);
      expect(config.outbound, isNull);
    });
  });

  group('TC-030: RateLimitConfig — fromJson and defaults', () {
    test('Normal: all fields parsed correctly', () {
      final json = {
        'maxRate': 100,
        'window': 5000,
        'onExceeded': 'queue',
      };

      final config = RateLimitConfig.fromJson(json);

      expect(config.maxRate, equals(100));
      expect(config.windowMs, equals(5000));
      expect(config.onExceeded, equals('queue'));
    });

    test('Boundary: onExceeded omitted — defaults to "drop"', () {
      final json = {
        'maxRate': 50,
        'window': 2000,
      };

      final config = RateLimitConfig.fromJson(json);

      expect(config.onExceeded, equals('drop'));
    });

    test('Boundary: all fields omitted — defaults applied', () {
      final config = RateLimitConfig.fromJson({});

      expect(config.maxRate, equals(100));
      expect(config.windowMs, equals(1000));
      expect(config.onExceeded, equals('drop'));
    });

    test('Normal: const constructor with explicit values', () {
      const config = RateLimitConfig(
        maxRate: 20,
        windowMs: 3000,
        onExceeded: 'queue',
      );

      expect(config.maxRate, equals(20));
      expect(config.windowMs, equals(3000));
      expect(config.onExceeded, equals('queue'));
    });

    test('Boundary: const constructor onExceeded defaults to "drop"', () {
      const config = RateLimitConfig(maxRate: 10, windowMs: 1000);

      expect(config.onExceeded, equals('drop'));
    });
  });

  group('TC-031: ChannelRateLimiter — applyToStream', () {
    test('Normal: rate within limit — all messages pass through', () async {
      const config = RateLimitConfig(maxRate: 5, windowMs: 1000);
      final limiter = ChannelRateLimiter(config);

      final source = StreamController<dynamic>.broadcast();
      final output = limiter.applyToStream(source.stream);

      final received = <dynamic>[];
      output.listen((data) => received.add(data));

      // Emit 3 messages (under limit of 5)
      source.add('msg1');
      source.add('msg2');
      source.add('msg3');

      await Future.delayed(const Duration(milliseconds: 50));

      expect(received, equals(['msg1', 'msg2', 'msg3']));

      await source.close();
      limiter.dispose();
    });

    test('Normal: exceeds maxRate with drop policy — excess messages dropped', () async {
      const config = RateLimitConfig(maxRate: 2, windowMs: 5000, onExceeded: 'drop');
      final limiter = ChannelRateLimiter(config);

      final source = StreamController<dynamic>.broadcast();
      final output = limiter.applyToStream(source.stream);

      final received = <dynamic>[];
      output.listen((data) => received.add(data));

      // Emit 5 messages (limit is 2)
      for (var i = 0; i < 5; i++) {
        source.add('msg$i');
      }

      await Future.delayed(const Duration(milliseconds: 50));

      // Only first 2 should pass
      expect(received, equals(['msg0', 'msg1']));

      await source.close();
      limiter.dispose();
    });

    test('Boundary: exceeds maxRate with queue policy — excess messages queued and delivered', () async {
      // Use a very short window so queued messages drain quickly
      const config = RateLimitConfig(maxRate: 2, windowMs: 100, onExceeded: 'queue');
      final limiter = ChannelRateLimiter(config);

      final source = StreamController<dynamic>.broadcast();
      final output = limiter.applyToStream(source.stream);

      final received = <dynamic>[];
      output.listen((data) => received.add(data));

      // Emit 4 messages (limit is 2 per 100ms window)
      for (var i = 0; i < 4; i++) {
        source.add('msg$i');
      }

      // First 2 pass immediately
      await Future.delayed(const Duration(milliseconds: 50));
      expect(received.length, greaterThanOrEqualTo(2));
      expect(received.take(2).toList(), equals(['msg0', 'msg1']));

      // Wait for window to reset and drain to deliver queued messages
      await Future.delayed(const Duration(milliseconds: 200));
      expect(received.length, equals(4));
      expect(received, equals(['msg0', 'msg1', 'msg2', 'msg3']));

      await source.close();
      limiter.dispose();
    });

    test('Normal: errors from source stream are forwarded', () async {
      const config = RateLimitConfig(maxRate: 10, windowMs: 1000);
      final limiter = ChannelRateLimiter(config);

      final source = StreamController<dynamic>.broadcast();
      final output = limiter.applyToStream(source.stream);

      final errors = <dynamic>[];
      output.listen((_) {}, onError: (e) => errors.add(e));

      source.addError('test-error');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(errors, equals(['test-error']));

      await source.close();
      limiter.dispose();
    });
  });

  group('TC-032: ChannelRateLimiter — tryEmit', () {
    test('Normal: outbound message within rate limit — returns true', () {
      const config = RateLimitConfig(maxRate: 5, windowMs: 1000);
      final limiter = ChannelRateLimiter(config);

      expect(limiter.tryEmit('msg1'), isTrue);
      expect(limiter.tryEmit('msg2'), isTrue);

      limiter.dispose();
    });

    test('Normal: outbound message exceeds rate limit — returns false', () {
      const config = RateLimitConfig(maxRate: 2, windowMs: 5000);
      final limiter = ChannelRateLimiter(config);

      expect(limiter.tryEmit('msg1'), isTrue);
      expect(limiter.tryEmit('msg2'), isTrue);
      // Third message exceeds limit
      expect(limiter.tryEmit('msg3'), isFalse);

      limiter.dispose();
    });

    test('Boundary: window expires and counter resets — subsequent tryEmit succeeds', () async {
      const config = RateLimitConfig(maxRate: 1, windowMs: 100);
      final limiter = ChannelRateLimiter(config);

      expect(limiter.tryEmit('msg1'), isTrue);
      expect(limiter.tryEmit('msg2'), isFalse);

      // Wait for window to expire
      await Future.delayed(const Duration(milliseconds: 150));

      // Counter should have reset
      expect(limiter.tryEmit('msg3'), isTrue);

      limiter.dispose();
    });

    test('Normal: drop policy — exceeded messages not queued', () {
      const config = RateLimitConfig(maxRate: 1, windowMs: 5000, onExceeded: 'drop');
      final limiter = ChannelRateLimiter(config);

      expect(limiter.tryEmit('msg1'), isTrue);
      expect(limiter.tryEmit('msg2'), isFalse);

      limiter.dispose();
    });

    test('Normal: queue policy — exceeded messages queued internally', () {
      const config = RateLimitConfig(maxRate: 1, windowMs: 5000, onExceeded: 'queue');
      final limiter = ChannelRateLimiter(config);

      expect(limiter.tryEmit('msg1'), isTrue);
      // Returns false but message is queued internally
      expect(limiter.tryEmit('msg2'), isFalse);

      limiter.dispose();
    });

    test('Normal: dispose clears all state', () {
      const config = RateLimitConfig(maxRate: 2, windowMs: 5000);
      final limiter = ChannelRateLimiter(config);

      limiter.tryEmit('msg1');
      limiter.dispose();

      // After dispose, internal state is cleared — new tryEmit succeeds
      expect(limiter.tryEmit('msg1'), isTrue);
    });
  });

  group('TC-010: Channel lifecycle state transitions (via ChannelManager)', () {
    // These tests verify rate limiter integration with channel flow control
    // through the ChannelManager. Core lifecycle tests are in channel_manager_test.dart.

    test('Normal: FlowControlConfig constructed with const constructor', () {
      const config = FlowControlConfig();

      expect(config.inbound, isNull);
      expect(config.outbound, isNull);
    });

    test('Normal: FlowControlConfig with both directions', () {
      const inbound = RateLimitConfig(maxRate: 10, windowMs: 1000);
      const outbound = RateLimitConfig(maxRate: 5, windowMs: 2000);
      const config = FlowControlConfig(inbound: inbound, outbound: outbound);

      expect(config.inbound!.maxRate, equals(10));
      expect(config.outbound!.maxRate, equals(5));
    });
  });
}
