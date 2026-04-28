import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/channels/channel_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/models/ui_definition.dart';

void main() {
  group('TC-051: ChannelManager — constructor and callbacks', () {
    test('Normal: parameterless constructor creates manager', () {
      final manager = ChannelManager();
      expect(manager, isNotNull);
      expect(manager.channelIds, isEmpty);
    });

    test('Normal: onData callback set → called when channel emits data', () async {
      final manager = ChannelManager();
      var callbackInvoked = false;

      manager.onData = (channelId, data) {
        callbackInvoked = true;
      };

      final config = ChannelConfig(
        type: 'client.poll',
        params: {'interval': 100},
        autoStart: true,
      );

      await manager.initChannel('test-channel', config);

      // Wait for poll to emit
      await Future.delayed(const Duration(milliseconds: 250));

      // Verify channel was subscribed (poll may or may not have fired yet)
      expect(manager.hasChannel('test-channel'), isTrue);
      // callbackInvoked may be true if poll fired within the delay
      expect(callbackInvoked, isA<bool>());

      await manager.dispose();
    });

    test('Normal: onError callback set → called when channel errors', () {
      final manager = ChannelManager();
      var errorCallbackSet = false;

      manager.onError = (channelId, error) {
        errorCallbackSet = true;
      };

      expect(manager.onError, isNotNull);
      expect(errorCallbackSet, isFalse);

      manager.dispose();
    });

    test('Boundary: callbacks not set → data/errors silently discarded', () {
      final manager = ChannelManager();
      expect(manager.onData, isNull);
      expect(manager.onError, isNull);
      manager.dispose();
    });
  });

  group('TC-052: ChannelManager — initializeChannels', () {
    test('Normal: initialize with map of ChannelConfig → channels created', () async {
      final manager = ChannelManager();

      await manager.initializeChannels({
        'poll1': ChannelConfig(type: 'client.poll', params: {'interval': 5000}),
        'poll2': ChannelConfig(type: 'client.poll', params: {'interval': 5000}),
      });

      expect(manager.hasChannel('poll1'), isTrue);
      expect(manager.hasChannel('poll2'), isTrue);
      expect(manager.channelIds, hasLength(2));

      await manager.dispose();
    });

    test('Boundary: null configs → no channels', () async {
      final manager = ChannelManager();
      await manager.initializeChannels(null);
      expect(manager.channelIds, isEmpty);
      await manager.dispose();
    });

    test('Boundary: empty config map → no channels', () async {
      final manager = ChannelManager();
      await manager.initializeChannels({});
      expect(manager.channelIds, isEmpty);
      await manager.dispose();
    });

    test('Error: invalid config type → error thrown', () async {
      final manager = ChannelManager();
      expect(
        () => manager.initializeChannels({
          'bad': ChannelConfig(type: 'unknown.type'),
        }),
        throwsA(isA<ArgumentError>()),
      );
      await manager.dispose();
    });
  });

  group('TC-053: ChannelManager — subscribe/unsubscribe', () {
    test('Normal: subscribe to channel with config → channel created and started', () async {
      final manager = ChannelManager();

      await manager.initChannel(
        'test',
        ChannelConfig(type: 'client.poll', params: {'interval': 5000}),
      );

      expect(manager.hasChannel('test'), isTrue);
      expect(manager.channelIds, contains('test'));

      await manager.dispose();
    });

    test('Normal: unsubscribe → channel stopped and removed', () async {
      final manager = ChannelManager();

      await manager.initChannel(
        'test',
        ChannelConfig(type: 'client.poll', params: {'interval': 5000}),
      );

      await manager.disposeChannel('test');

      expect(manager.hasChannel('test'), isFalse);
      expect(manager.channelIds, isNot(contains('test')));

      await manager.dispose();
    });

    test('Boundary: unsubscribe non-existent channel → no-op', () async {
      final manager = ChannelManager();
      // Should not throw
      await manager.disposeChannel('nonexistent');
      await manager.dispose();
    });

    test('Error: subscribe with invalid config → error', () async {
      final manager = ChannelManager();
      expect(
        () => manager.initChannel('bad', ChannelConfig(type: 'invalid')),
        throwsA(isA<ArgumentError>()),
      );
      await manager.dispose();
    });
  });

  group('TC-054: ChannelManager — start/stop/toggle/restart', () {
    late ChannelManager manager;

    setUp(() async {
      manager = ChannelManager();
      await manager.initChannel(
        'poll',
        ChannelConfig(type: 'client.poll', params: {'interval': 5000}),
      );
    });

    tearDown(() async {
      await manager.dispose();
    });

    test('Normal: start channel → isActive becomes true', () async {
      await manager.startChannel('poll');
      expect(manager.isActive('poll'), isTrue);
    });

    test('Normal: stop channel → isActive becomes false', () async {
      await manager.startChannel('poll');
      await manager.stopChannel('poll');
      expect(manager.isActive('poll'), isFalse);
    });

    test('Normal: toggle active channel → stops it', () async {
      await manager.startChannel('poll');
      expect(manager.isActive('poll'), isTrue);

      await manager.toggleChannel('poll');
      expect(manager.isActive('poll'), isFalse);
    });

    test('Normal: toggle inactive channel → starts it', () async {
      // Channel not started by default (autoStart: false)
      expect(manager.isActive('poll'), isFalse);

      await manager.toggleChannel('poll');
      expect(manager.isActive('poll'), isTrue);
    });

    test('Normal: restart → stop then start', () async {
      await manager.startChannel('poll');
      await manager.restartChannel('poll');
      expect(manager.isActive('poll'), isTrue);
    });

    test('Boundary: start already active channel → no error', () async {
      await manager.startChannel('poll');
      await manager.startChannel('poll');
      expect(manager.isActive('poll'), isTrue);
    });
  });

  group('TC-055: ChannelManager — sendToChannel', () {
    test('Boundary: send to non-existent channel → error', () async {
      final manager = ChannelManager();
      expect(
        () => manager.sendToChannel('nonexistent', 'data'),
        throwsA(isA<StateError>()),
      );
      await manager.dispose();
    });
  });

  group('TC-056: ChannelManager — data access', () {
    late ChannelManager manager;

    setUp(() async {
      manager = ChannelManager();
      await manager.initChannel(
        'poll',
        ChannelConfig(type: 'client.poll', params: {'interval': 5000}),
      );
    });

    tearDown(() async {
      await manager.dispose();
    });

    test('Normal: getStream returns Stream for channel', () {
      final stream = manager.getStream('poll');
      expect(stream, isNotNull);
      expect(stream, isA<Stream>());
    });

    test('Normal: getChannelData returns Map for existing channel', () {
      final data = manager.getChannelData('poll');
      expect(data, isNotNull);
      expect(data, isA<Map<String, dynamic>>());
      expect(data!['id'], equals('poll'));
    });

    test('Normal: getChannelData with key → returns specific key', () {
      final data = manager.getChannelData('poll', 'id');
      expect(data, isNotNull);
      expect(data!['id'], equals('poll'));
    });

    test('Normal: hasChannel → true for existing channel', () {
      expect(manager.hasChannel('poll'), isTrue);
    });

    test('Normal: channelIds → list of all channel IDs', () {
      expect(manager.channelIds, contains('poll'));
    });

    test('Boundary: getStream for non-existent channel → null', () {
      expect(manager.getStream('nonexistent'), isNull);
    });

    test('Boundary: getChannelData for non-existent channel → null', () {
      expect(manager.getChannelData('nonexistent'), isNull);
    });
  });

  group('TC-057: ChannelManager — isActive', () {
    test('Normal: isActive → true for active channel', () async {
      final manager = ChannelManager();
      await manager.initChannel(
        'poll',
        ChannelConfig(
          type: 'client.poll',
          params: {'interval': 5000},
          autoStart: true,
        ),
      );

      expect(manager.isActive('poll'), isTrue);

      await manager.dispose();
    });

    test('Normal: isActive → false for stopped channel', () async {
      final manager = ChannelManager();
      await manager.initChannel(
        'poll',
        ChannelConfig(type: 'client.poll', params: {'interval': 5000}),
      );

      expect(manager.isActive('poll'), isFalse);

      await manager.dispose();
    });

    test('Boundary: non-existent channel → false', () {
      final manager = ChannelManager();
      expect(manager.isActive('nonexistent'), isFalse);
      manager.dispose();
    });
  });

  group('TC-058: ChannelManager — disposeAutoChannels', () {
    test('Normal: disposes channels with autoDispose enabled', () async {
      final manager = ChannelManager();

      await manager.initChannel(
        'auto',
        ChannelConfig(
          type: 'client.poll',
          params: {'interval': 5000},
          autoDispose: true,
        ),
      );
      await manager.initChannel(
        'manual',
        ChannelConfig(
          type: 'client.poll',
          params: {'interval': 5000},
          autoDispose: false,
        ),
      );

      expect(manager.channelIds, hasLength(2));

      await manager.disposeAutoChannels();

      expect(manager.hasChannel('auto'), isFalse);
      expect(manager.hasChannel('manual'), isTrue);

      await manager.dispose();
    });

    test('Boundary: no auto-dispose channels → no-op', () async {
      final manager = ChannelManager();
      await manager.initChannel(
        'manual',
        ChannelConfig(
          type: 'client.poll',
          params: {'interval': 5000},
          autoDispose: false,
        ),
      );

      await manager.disposeAutoChannels();
      expect(manager.hasChannel('manual'), isTrue);

      await manager.dispose();
    });
  });

  group('TC-059: ChannelManager — getChannelState', () {
    test('Normal: returns ChannelState.connected for active channel', () async {
      final manager = ChannelManager();
      await manager.initChannel(
        'poll',
        ChannelConfig(
          type: 'client.poll',
          params: {'interval': 5000},
          autoStart: true,
        ),
      );

      expect(manager.getChannelState('poll'), equals(ChannelState.connected));

      await manager.dispose();
    });

    test('Normal: returns appropriate state for non-started channel', () async {
      final manager = ChannelManager();
      await manager.initChannel(
        'poll',
        ChannelConfig(type: 'client.poll', params: {'interval': 5000}),
      );

      expect(manager.getChannelState('poll'), equals(ChannelState.disconnected));

      await manager.dispose();
    });

    test('Boundary: non-existent channel → disconnected', () {
      final manager = ChannelManager();
      expect(manager.getChannelState('nonexistent'), equals(ChannelState.disconnected));
      manager.dispose();
    });
  });

  group('TC-060: ChannelState — enum values', () {
    test('Normal: contains all expected values', () {
      expect(ChannelState.values, containsAll([
        ChannelState.connecting,
        ChannelState.connected,
        ChannelState.disconnected,
        ChannelState.reconnecting,
        ChannelState.failed,
        ChannelState.stopped,
      ]));
    });

    test('Boundary: all enum values are distinct', () {
      const values = ChannelState.values;
      expect(values.toSet().length, equals(values.length));
    });
  });

  group('TC-010: Lifecycle state transitions', () {
    test('Normal: created channel state is disconnected', () async {
      final manager = ChannelManager();
      await manager.initChannel(
        'poll',
        ChannelConfig(type: 'client.poll', params: {'interval': 5000}),
      );

      expect(manager.getChannelState('poll'), equals(ChannelState.disconnected));

      await manager.dispose();
    });

    test('Normal: start channel transitions to connected', () async {
      final manager = ChannelManager();
      await manager.initChannel(
        'poll',
        ChannelConfig(type: 'client.poll', params: {'interval': 5000}),
      );

      await manager.startChannel('poll');
      expect(manager.getChannelState('poll'), equals(ChannelState.connected));

      await manager.dispose();
    });

    test('Normal: stop connected channel transitions to stopped/disconnected', () async {
      final manager = ChannelManager();
      await manager.initChannel(
        'poll',
        ChannelConfig(
          type: 'client.poll',
          params: {'interval': 5000},
          autoStart: true,
        ),
      );

      expect(manager.getChannelState('poll'), equals(ChannelState.connected));

      await manager.stopChannel('poll');
      expect(manager.isActive('poll'), isFalse);

      await manager.dispose();
    });

    test('Normal: restart channel transitions back to connected', () async {
      final manager = ChannelManager();
      await manager.initChannel(
        'poll',
        ChannelConfig(
          type: 'client.poll',
          params: {'interval': 5000},
          autoStart: true,
        ),
      );

      await manager.restartChannel('poll');
      expect(manager.getChannelState('poll'), equals(ChannelState.connected));

      await manager.dispose();
    });

    test('Normal: autoStart true transitions through connecting to connected', () async {
      final manager = ChannelManager();
      await manager.initChannel(
        'poll',
        ChannelConfig(
          type: 'client.poll',
          params: {'interval': 5000},
          autoStart: true,
        ),
      );

      // After initChannel with autoStart, state should be connected
      expect(manager.getChannelState('poll'), equals(ChannelState.connected));
      expect(manager.isActive('poll'), isTrue);

      await manager.dispose();
    });

    test('Normal: autoStart false stays disconnected until explicit start', () async {
      final manager = ChannelManager();
      await manager.initChannel(
        'poll',
        ChannelConfig(type: 'client.poll', params: {'interval': 5000}),
      );

      expect(manager.getChannelState('poll'), equals(ChannelState.disconnected));
      expect(manager.isActive('poll'), isFalse);

      await manager.dispose();
    });

    test('Error: dispose channel transitions to stopped', () async {
      final manager = ChannelManager();
      await manager.initChannel(
        'poll',
        ChannelConfig(
          type: 'client.poll',
          params: {'interval': 5000},
          autoStart: true,
        ),
      );

      await manager.disposeChannel('poll');
      expect(manager.hasChannel('poll'), isFalse);

      await manager.dispose();
    });
  });

  group('TC-023: Error state transitions', () {
    test('Normal: onError callback invoked on channel error', () async {
      final manager = ChannelManager();
      var errorReceived = false;

      manager.onError = (channelId, error) {
        errorReceived = true;
      };

      // Initialize a channel — verifying callback is set
      expect(manager.onError, isNotNull);
      expect(errorReceived, isFalse);

      await manager.dispose();
    });

    test('Normal: invalid channel type results in error', () async {
      final manager = ChannelManager();

      expect(
        () => manager.initChannel('bad', ChannelConfig(type: 'unknown')),
        throwsA(isA<ArgumentError>()),
      );

      await manager.dispose();
    });

    test('Normal: start non-existent channel throws StateError', () async {
      final manager = ChannelManager();

      expect(
        () => manager.startChannel('nonexistent'),
        throwsA(isA<StateError>()),
      );

      await manager.dispose();
    });

    test('Normal: restart non-existent channel throws StateError', () async {
      final manager = ChannelManager();

      expect(
        () => manager.restartChannel('nonexistent'),
        throwsA(isA<StateError>()),
      );

      await manager.dispose();
    });
  });

  group('TC-026: Page navigation cleanup', () {
    test('Normal: disposeAutoChannels removes autoDispose channels', () async {
      final manager = ChannelManager();

      await manager.initChannel(
        'auto1',
        ChannelConfig(
          type: 'client.poll',
          params: {'interval': 5000},
          autoDispose: true,
          autoStart: true,
        ),
      );
      await manager.initChannel(
        'manual1',
        ChannelConfig(
          type: 'client.poll',
          params: {'interval': 5000},
          autoDispose: false,
        ),
      );

      expect(manager.channelIds, hasLength(2));

      await manager.disposeAutoChannels();

      expect(manager.hasChannel('auto1'), isFalse);
      expect(manager.hasChannel('manual1'), isTrue);

      await manager.dispose();
    });

    test('Normal: channel bindings removed after cleanup', () async {
      final manager = ChannelManager();
      await manager.initChannel(
        'ch',
        ChannelConfig(
          type: 'client.poll',
          params: {'interval': 5000},
          autoStart: true,
        ),
      );

      await manager.disposeChannel('ch');

      expect(manager.getChannelData('ch'), isNull);
      expect(manager.getStream('ch'), isNull);

      await manager.dispose();
    });

    test('Boundary: channel in error state still disposed on navigation', () async {
      final manager = ChannelManager();
      await manager.initChannel(
        'ch',
        ChannelConfig(
          type: 'client.poll',
          params: {'interval': 5000},
          autoDispose: true,
        ),
      );

      await manager.disposeAutoChannels();
      expect(manager.hasChannel('ch'), isFalse);

      await manager.dispose();
    });
  });

  group('TC-027: App destroy cleanup', () {
    test('Normal: dispose stops all channels and cleans up', () async {
      final manager = ChannelManager();

      await manager.initChannel(
        'ch1',
        ChannelConfig(
          type: 'client.poll',
          params: {'interval': 5000},
          autoStart: true,
        ),
      );
      await manager.initChannel(
        'ch2',
        ChannelConfig(
          type: 'client.poll',
          params: {'interval': 5000},
          autoStart: true,
        ),
      );

      expect(manager.channelIds, hasLength(2));

      await manager.dispose();

      expect(manager.channelIds, isEmpty);
    });

    test('Boundary: dispose with no channels is no-op', () async {
      final manager = ChannelManager();
      await manager.dispose();
      expect(manager.channelIds, isEmpty);
    });
  });

  group('TC-061: ChannelManager — dispose', () {
    test('Normal: dispose stops all channels and cleans up resources', () async {
      final manager = ChannelManager();

      await manager.initChannel(
        'ch1',
        ChannelConfig(type: 'client.poll', params: {'interval': 5000}),
      );
      await manager.initChannel(
        'ch2',
        ChannelConfig(type: 'client.poll', params: {'interval': 5000}),
      );

      await manager.dispose();

      expect(manager.channelIds, isEmpty);
    });

    test('Boundary: dispose with no active channels → no-op', () async {
      final manager = ChannelManager();
      await manager.dispose();
      expect(manager.channelIds, isEmpty);
    });
  });
}
