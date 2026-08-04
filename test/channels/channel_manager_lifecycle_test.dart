// `channel_manager.dart` sat at 40.1% — the lowest ratio left. It owns the
// lifecycle of every §8.6 channel: which type gets built, when it starts, what
// state it reports, and whether disposing it actually lets go. A channel that
// silently fails to start looks exactly like a channel with nothing to say.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/channels/channel_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/models/ui_definition.dart';

void main() {
  late ChannelManager manager;

  setUp(() => manager = ChannelManager());
  tearDown(() async {
    for (final id in List<String>.from(manager.channelIds)) {
      await manager.disposeChannel(id);
    }
  });

  ChannelConfig poll({
    bool autoStart = false,
    bool autoDispose = true,
    Map<String, dynamic>? extraParams,
  }) =>
      ChannelConfig(
        type: 'client.poll',
        autoStart: autoStart,
        autoDispose: autoDispose,
        params: <String, dynamic>{
          'url': 'https://example.com/feed',
          'interval': 60000,
          ...?extraParams,
        },
      );

  group('creation', () {
    test('a known type is built and registered', () async {
      await manager.initChannel('feed', poll());

      expect(manager.hasChannel('feed'), isTrue);
      expect(manager.channelIds, contains('feed'));
      expect(manager.getConfig('feed'), isNotNull);
      expect(manager.getStream('feed'), isNotNull);
    });

    test('an unknown type is refused by name', () async {
      expect(
        () => manager.initChannel(
            'x', ChannelConfig(type: 'client.telepathy', autoStart: false)),
        throwsA(isA<ArgumentError>()),
        reason: 'a channel that cannot be built must say so at init — a null '
            'channel that registers anyway reports "connected, nothing yet"',
      );
      expect(manager.hasChannel('x'), isFalse);
    });

    test('initialising the same id twice keeps the first', () async {
      await manager.initChannel('feed', poll());
      final first = manager.getConfig('feed');
      await manager.initChannel(
          'feed', poll(extraParams: <String, dynamic>{'interval': 1}));

      expect(identical(manager.getConfig('feed'), first), isTrue);
    });

    test('every declared channel type in §8.6 can be built', () async {
      final types = <String, Map<String, dynamic>>{
        'client.watchFile': <String, dynamic>{'path': '/tmp/a.txt'},
        'client.watchDirectory': <String, dynamic>{'path': '/tmp'},
        'client.poll': <String, dynamic>{
          'url': 'https://example.com',
          'interval': 60000
        },
        'client.systemMonitor': <String, dynamic>{'metrics': <String>['cpu']},
        'client.websocket': <String, dynamic>{'url': 'wss://example.com'},
      };

      for (final entry in types.entries) {
        await manager.initChannel(
          entry.key,
          ChannelConfig(
              type: entry.key, autoStart: false, params: entry.value),
        );
        expect(manager.hasChannel(entry.key), isTrue, reason: entry.key);
      }
    });
  });

  group('state', () {
    test('a channel that has not started is disconnected', () async {
      await manager.initChannel('feed', poll());
      expect(manager.getChannelState('feed'), ChannelState.disconnected);
    });

    test('an unknown id reports disconnected rather than throwing', () {
      expect(manager.getChannelState('nope'), ChannelState.disconnected);
    });
  });

  group('disposal', () {
    test('disposing removes the channel and its stream', () async {
      await manager.initChannel('feed', poll());
      await manager.disposeChannel('feed');

      expect(manager.hasChannel('feed'), isFalse);
      expect(manager.getStream('feed'), isNull);
      expect(manager.channelIds, isEmpty);
    });

    test('disposing an unknown id is a no-op', () async {
      await manager.disposeChannel('nope');
      expect(manager.channelIds, isEmpty);
    });

    test('autoDispose: false survives disposeAutoChannels', () async {
      await manager.initChannel('kept', poll(autoDispose: false));
      await manager.initChannel('temp', poll());

      await manager.disposeAutoChannels();

      expect(manager.hasChannel('kept'), isTrue,
          reason: 'the flag exists so a channel can outlive a page');
      expect(manager.hasChannel('temp'), isFalse);
    });
  });

  group('backpressure config', () {
    test('a declared strategy is accepted at init', () async {
      await manager.initChannel(
        'bp',
        ChannelConfig(
          type: 'client.poll',
          autoStart: false,
          params: <String, dynamic>{
            'url': 'https://example.com',
            'interval': 60000,
          },
          backpressure: <String, dynamic>{
            'overflowStrategy': 'latest',
            'bufferSize': 10,
          },
        ),
      );
      expect(manager.hasChannel('bp'), isTrue);
    });

    test('an unknown strategy does not stop the channel being built',
        () async {
      await manager.initChannel(
        'bp2',
        ChannelConfig(
          type: 'client.poll',
          autoStart: false,
          params: <String, dynamic>{
            'url': 'https://example.com',
            'interval': 60000,
          },
          backpressure: <String, dynamic>{'overflowStrategy': 'nonsense'},
        ),
      );
      expect(manager.hasChannel('bp2'), isTrue);
    });
  });

  test('initializeChannels builds every entry, and null is a no-op', () async {
    await manager.initializeChannels(null);
    expect(manager.channelIds, isEmpty);

    await manager.initializeChannels(<String, ChannelConfig>{
      'a': poll(),
      'b': poll(),
    });
    expect(manager.channelIds, containsAll(<String>['a', 'b']));
  });
}
