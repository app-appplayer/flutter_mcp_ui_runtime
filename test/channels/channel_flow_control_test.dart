// Flow control and backpressure on a live channel.
//
// These are the parts of `channel_manager.dart` that only exist under load:
// the rate limiter that drops or delays inbound payloads, the backpressure
// strategy that decides which ones survive a burst, and the sequence counter
// a document uses to notice a gap. Each is invisible until a stream actually
// pushes, and each fails by silently delivering the wrong subset.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/channels/channel_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/models/ui_definition.dart';

void main() {
  late ChannelManager manager;
  late StreamController<dynamic> source;

  setUp(() {
    source = StreamController<dynamic>.broadcast();
    manager = ChannelManager()
      ..streamSourceResolver = (uri, params) => source.stream;
  });

  tearDown(() async {
    for (final id in List<String>.from(manager.channelIds)) {
      await manager.disposeChannel(id);
    }
    await source.close();
  });

  ChannelConfig streamWith({
    Map<String, dynamic>? backpressure,
    Map<String, dynamic>? flowControl,
  }) =>
      ChannelConfig(
        type: 'client.mcpStream',
        autoStart: true,
        backpressure: backpressure,
        params: <String, dynamic>{
          'uri': 'mcp://server/feed',
          if (flowControl != null) 'flowControl': flowControl,
        },
      );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('without backpressure every payload is delivered', () async {
    final seen = <dynamic>[];
    await manager.initChannel('feed', streamWith());
    manager.getStream('feed')!.listen(seen.add);

    for (var i = 0; i < 5; i++) {
      source.add(i);
    }
    await settle();

    expect(seen, <dynamic>[0, 1, 2, 3, 4]);
  });

  test('the latest strategy keeps the newest value', () async {
    final seen = <dynamic>[];
    await manager.initChannel(
      'feed',
      streamWith(backpressure: <String, dynamic>{
        'overflowStrategy': 'latest',
        'bufferSize': 1,
      }),
    );
    manager.getStream('feed')!.listen(seen.add);

    for (var i = 0; i < 5; i++) {
      source.add(i);
    }
    await settle();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(seen, isNotEmpty,
        reason: 'a strategy that drops everything is indistinguishable from a '
            'channel that never connected');
    expect(seen.last, 4,
        reason: '"latest" means the newest value survives the burst');
  });

  test('an inbound rate limit is accepted and the channel still delivers',
      () async {
    final seen = <dynamic>[];
    await manager.initChannel(
      'feed',
      streamWith(flowControl: <String, dynamic>{
        'inbound': <String, dynamic>{
          'maxPerSecond': 100,
          'burst': 10,
        },
      }),
    );
    manager.getStream('feed')!.listen(seen.add);

    source.add('a');
    await settle();

    expect(seen, <dynamic>['a']);
  });

  test('sending to a channel that has no sink is reported, not swallowed',
      () async {
    await manager.initChannel('feed', streamWith());

    // `client.mcpStream` is inbound only; a document that tries to send on it
    // must find out rather than watch its message disappear.
    Object? error;
    try {
      await manager.sendToChannel('feed', 'ping');
    } catch (e) {
      error = e;
    }
    expect(error, isNotNull);
  });

  test('two channels are independent', () async {
    final a = <dynamic>[];
    final b = <dynamic>[];
    await manager.initChannel('a', streamWith());
    await manager.initChannel('b', streamWith());
    manager.getStream('a')!.listen(a.add);
    manager.getStream('b')!.listen(b.add);

    source.add('x');
    await settle();

    expect(a, <dynamic>['x']);
    expect(b, <dynamic>['x']);

    await manager.stopChannel('a');
    source.add('y');
    await settle();

    expect(a, <dynamic>['x'], reason: 'stopping one must not stop the other');
    expect(b, <dynamic>['x', 'y']);
  });
  test('an outbound limit drops what the document sends too fast', () async {
    await manager.initChannel(
      'feed',
      streamWith(flowControl: <String, dynamic>{
        'outbound': <String, dynamic>{
          'maxRate': 1,
          'window': 1000,
          'onExceeded': 'drop',
        },
      }),
    );

    // The channel is inbound-only, so a send that reaches the transport
    // throws; a send the limiter drops returns quietly. That difference is
    // what tells us the limiter ran.
    Object? first;
    try {
      await manager.sendToChannel('feed', 'one');
    } catch (e) {
      first = e;
    }
    expect(first, isNotNull, reason: 'the first send is within the limit');

    Object? second;
    try {
      await manager.sendToChannel('feed', 'two');
    } catch (e) {
      second = e;
    }
    expect(second, isNull,
        reason: 'the second is over the limit and must be dropped before it '
            'reaches the transport at all');
  });

  test('sending to a channel that was never opened names it', () async {
    expect(() => manager.sendToChannel('nobody', 'x'),
        throwsA(isA<StateError>()),
        reason: 'a send into a channel id nobody declared is a typo in the '
            'document; swallowing it makes the typo invisible');
  });

  test('toggling a channel that was never opened names it', () async {
    expect(() => manager.toggleChannel('nobody'), throwsA(isA<StateError>()));
  });

  group('the backpressure strategies each behave differently', () {
    Future<List<dynamic>> burstUnder(String strategy) async {
      final seen = <dynamic>[];
      await manager.initChannel(
        strategy,
        streamWith(backpressure: <String, dynamic>{
          'strategy': strategy,
          'highWaterMark': 2,
          'windowMs': 1000,
        }),
      );
      manager.getStream(strategy)!.listen(seen.add);

      for (final value in <String>['a', 'b', 'c', 'd']) {
        source.add(value);
      }
      await settle();
      return seen;
    }

    test('throttle lets the first of a burst through and holds the rest',
        () async {
      final seen = await burstUnder('throttle');

      expect(seen, isNot(hasLength(4)),
          reason: 'throttling that delivers everything is not throttling — a '
              'chart under a fast feed would repaint on every tick');
      expect(seen.first, 'a');
    });

    test('debounce delivers nothing until the burst stops', () async {
      final seen = await burstUnder('debounce');

      expect(seen, isEmpty,
          reason: 'debouncing exists so a document sees the settled value, '
              'not each keystroke on the way to it');
    });

    test('`highWaterMark` is read where `bufferSize` is absent', () async {
      final seen = await burstUnder('buffer');

      expect(seen, <dynamic>['a', 'b', 'c', 'd'],
          reason: 'buffering keeps the order and the whole burst');
    });
  });
}
