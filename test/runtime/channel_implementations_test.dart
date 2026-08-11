import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/channels/channel_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/channels/channel_types/file_watch_channel.dart';
import 'package:flutter_mcp_ui_runtime/src/channels/channel_types/directory_watch_channel.dart';
import 'package:flutter_mcp_ui_runtime/src/channels/channel_types/poll_channel.dart';
import 'package:flutter_mcp_ui_runtime/src/channels/channel_types/system_monitor_channel.dart';
import 'package:flutter_mcp_ui_runtime/src/channels/channel_types/websocket_channel.dart';

void main() {
  group('TC-062: Channel — abstract interface', () {
    test('Normal: Channel defines start/stop/stream/isActive contract', () {
      // PollChannel is a concrete implementation of Channel
      final channel = PollChannel(interval: 5000);

      expect(channel, isA<Channel>());
      expect(channel.isActive, isFalse);
      expect(channel.stream, isA<Stream>());
    });

    test('Normal: start → async start, stop → async stop', () async {
      final channel = PollChannel(interval: 5000);

      await channel.start();
      expect(channel.isActive, isTrue);

      await channel.stop();
      expect(channel.isActive, isFalse);
    });
  });

  // A poll channel exists to fire on a schedule. Asserting that the object is
  // a `Channel` says nothing about that: one that starts, never emits, and
  // reports `isActive` passes it while the document bound to it refreshes
  // never.
  group('PollChannel', () {
    test('the first poll arrives without waiting for the interval', () async {
      final channel = PollChannel(interval: 5000, action: <String, dynamic>{
        'type': 'tool',
        'tool': 'refresh',
      });
      await channel.start();
      // The order every consumer uses: start, then listen.
      final seen = <PollEvent>[];
      channel.stream.listen((event) => seen.add(event as PollEvent));
      await Future<void>.delayed(Duration.zero);

      expect(seen, hasLength(1),
          reason: 'a document refreshing on a thirty-second poll that waits '
              'the whole interval for its first update reads as a slow '
              'server, not as a dropped event');
      expect(seen.single.count, 1);
      expect(seen.single.action, <String, dynamic>{
        'type': 'tool',
        'tool': 'refresh',
      }, reason: 'the action is what the consumer runs on each tick; an event '
          'without it is a tick nobody can act on');

      await channel.stop();
    });

    test('it keeps polling, and the count climbs', () {
      fakeAsync((async) {
        final channel = PollChannel(interval: 2000);
        channel.start();
        final seen = <PollEvent>[];
        channel.stream.listen((event) => seen.add(event as PollEvent));
        async.elapse(Duration.zero);

        expect(seen.map((e) => e.count), <int>[1]);

        async.elapse(const Duration(milliseconds: 5000));
        expect(seen.map((e) => e.count), <int>[1, 2, 3],
            reason: 'the count is how a document notices a gap; repeating or '
                'skipping numbers makes it useless');

        channel.stop();
        async.elapse(const Duration(milliseconds: 5000));
        expect(seen, hasLength(3),
            reason: 'a stopped poll that keeps calling holds a server request '
                'open for the life of the process');
      });
    });

    test('an interval below the floor is raised to it', () {
      fakeAsync((async) {
        final channel = PollChannel(interval: 1);
        channel.start();
        final seen = <dynamic>[];
        channel.stream.listen(seen.add);
        async.elapse(const Duration(milliseconds: 900));

        expect(seen, hasLength(1),
            reason: 'a document asking for a millisecond poll would call a '
                'thousand times a second; the floor is what stops it');

        async.elapse(const Duration(milliseconds: 200));
        expect(seen, hasLength(2));

        channel.stop();
      });
    });

    test('the count can be reset without restarting the channel', () {
      fakeAsync((async) {
        final channel = PollChannel(interval: 1000);
        channel.start();
        final seen = <PollEvent>[];
        channel.stream.listen((event) => seen.add(event as PollEvent));
        async.elapse(const Duration(milliseconds: 2500));

        expect(channel.pollCount, 3);

        channel.resetCount();
        expect(channel.pollCount, 0,
            reason: 'a host that reconnects wants the count to start again '
                'without tearing the subscription down');

        async.elapse(const Duration(milliseconds: 1000));
        expect(seen.last.count, 1);

        channel.stop();
      });
    });

    test('an event carries a shape a document can bind to', () {
      final event = PollEvent(
        count: 4,
        timestamp: DateTime.utc(2026, 1, 2, 3, 4, 5),
        action: <String, dynamic>{'type': 'tool'},
      );

      expect(event.toJson(), <String, dynamic>{
        'count': 4,
        'timestamp': '2026-01-02T03:04:05.000Z',
        'action': <String, dynamic>{'type': 'tool'},
      });
      expect(PollEvent(count: 1, timestamp: DateTime.utc(2026)).toJson(),
          isNot(contains('action')),
          reason: 'a null action written into the payload makes every '
              'consumer check for it');
      expect(event.toString(), contains('count: 4'));
    });
  });

  group('TC-063: FileWatchChannel', () {
    test('Normal: creates FileWatchChannel with path', () {
      final channel = FileWatchChannel(path: '/tmp/test.txt');
      expect(channel, isA<Channel>());
      expect(channel.isActive, isFalse);
    });

    test('Normal: start → isActive true, stop → isActive false', () async {
      // Create the file before watching
      final file = File('/tmp/test_watch_file.txt');
      await file.writeAsString('test');

      try {
        final channel = FileWatchChannel(path: '/tmp/test_watch_file.txt');

        await channel.start();
        expect(channel.isActive, isTrue);

        await channel.stop();
        expect(channel.isActive, isFalse);
      } finally {
        await file.delete();
      }
    });

    test('Normal: stream getter returns Stream', () {
      final channel = FileWatchChannel(path: '/tmp/test.txt');
      expect(channel.stream, isA<Stream>());
    });
  });

  group('TC-064: DirectoryWatchChannel', () {
    test('Normal: creates with path and recursive option', () {
      final channel = DirectoryWatchChannel(
        path: '/tmp',
        recursive: true,
      );
      expect(channel, isA<Channel>());
      expect(channel.isActive, isFalse);
    });

    test('Normal: start → begins watching, stop → stops watching', () async {
      final channel = DirectoryWatchChannel(path: '/tmp');

      await channel.start();
      expect(channel.isActive, isTrue);

      await channel.stop();
      expect(channel.isActive, isFalse);
    });

    test('Boundary: empty directory path', () {
      final channel = DirectoryWatchChannel(path: '');
      expect(channel, isA<Channel>());
    });
  });

  group('TC-065: PollChannel', () {
    test('Normal: periodically executes at specified interval', () async {
      // minInterval is 1000ms, so use >= 1000
      final channel = PollChannel(interval: 1000);

      await channel.start();
      // The first poll fires on the next turn of the event loop, not inside
      // `start` — a broadcast controller created inside `start` has no
      // listeners yet, so an event emitted there reaches nobody.
      await Future<void>.delayed(Duration.zero);

      expect(channel.pollCount, greaterThanOrEqualTo(1));

      await channel.stop();
    });

    test('Normal: isActive reflects running state', () async {
      final channel = PollChannel(interval: 5000);

      expect(channel.isActive, isFalse);
      await channel.start();
      expect(channel.isActive, isTrue);
      await channel.stop();
      expect(channel.isActive, isFalse);
    });

    test('Boundary: very short interval (100ms)', () {
      final channel = PollChannel(interval: 100);
      expect(channel, isA<Channel>());
    });
  });

  group('TC-066: WebSocketChannel', () {
    test('Normal: creates with url and options', () {
      final channel = WebSocketChannel(
        url: 'ws://localhost:8080',
        protocols: ['graphql-ws'],
        autoReconnect: true,
        maxReconnectAttempts: 5,
        reconnectDelay: 1000,
      );

      expect(channel, isA<Channel>());
      expect(channel.isActive, isFalse);
    });

    test('Normal: stream getter returns Stream', () {
      final channel = WebSocketChannel(url: 'ws://localhost:8080');
      expect(channel.stream, isA<Stream>());
    });

    test('Boundary: optional subprotocols', () {
      final channel = WebSocketChannel(url: 'ws://localhost:8080');
      expect(channel, isA<Channel>());
    });
  });

  // A monitor channel is only worth having if something actually arrives on
  // it. Asserting that the object is a `Channel` says nothing about that: a
  // channel that starts, never emits, and reports `isActive` passes it while
  // the dashboard bound to it shows the same reading forever.
  group('SystemMonitorChannel', () {
    test('the first reading arrives without waiting for the interval',
        () async {
      final channel = SystemMonitorChannel(metrics: ['memory']);
      await channel.start();
      // The order every consumer uses: start, then listen.
      final seen = <dynamic>[];
      channel.stream.listen(seen.add);
      await Future<void>.delayed(Duration.zero);

      expect(seen, hasLength(1),
          reason: 'a dashboard that waits a full interval for its first '
              'number looks broken for those seconds');
      final data = (seen.single as SystemMetrics).data;
      expect(data['memory'], isA<Map<String, dynamic>>());
      expect((data['memory'] as Map)['rss'], isA<int>());
      expect(data['timestamp'], isA<String>());

      await channel.stop();
    });

    test('only the metrics that were asked for are collected', () async {
      final channel = SystemMonitorChannel(metrics: ['cpu', 'platform']);
      await channel.start();
      final seen = <SystemMetrics>[];
      channel.stream.listen((event) => seen.add(event as SystemMetrics));
      await Future<void>.delayed(Duration.zero);

      final data = seen.single.data;
      expect(data.containsKey('memory'), isFalse,
          reason: 'collecting what nobody asked for is work done on a timer '
              'for the life of the page');
      expect((data['cpu'] as Map)['processors'], isA<int>());
      expect((data['platform'] as Map)['os'], isNotEmpty);

      await channel.stop();
    });

    test('it keeps reading on its interval, and stopping ends it', () {
      fakeAsync((async) {
        final channel = SystemMonitorChannel(
          metrics: ['memory'],
          interval: 2000,
        );
        channel.start();
        final seen = <dynamic>[];
        channel.stream.listen(seen.add);
        async.elapse(Duration.zero);

        expect(seen, hasLength(1));

        async.elapse(const Duration(milliseconds: 5000));
        expect(seen.length, 3,
            reason: 'the whole point is a repeating reading; one value and '
                'silence is a snapshot pretending to be a monitor');

        channel.stop();
        async.elapse(const Duration(milliseconds: 5000));
        expect(seen.length, 3,
            reason: 'a stopped channel that keeps sampling holds the page '
                'alive after it is gone');
      });
    });

    test('an interval below the floor is raised to it', () {
      fakeAsync((async) {
        final channel = SystemMonitorChannel(metrics: ['memory'], interval: 1);
        channel.start();
        final seen = <dynamic>[];
        channel.stream.listen(seen.add);
        async.elapse(Duration.zero);

        async.elapse(const Duration(milliseconds: 900));
        expect(seen, hasLength(1),
            reason: 'a document asking for a millisecond poll would sample a '
                'thousand times a second; the floor is what stops it');

        async.elapse(const Duration(milliseconds: 200));
        expect(seen, hasLength(2));

        channel.stop();
      });
    });

    test('starting twice does not double the readings', () {
      fakeAsync((async) {
        final channel = SystemMonitorChannel(
          metrics: ['memory'],
          interval: 1000,
        );
        channel.start();
        channel.start();
        final seen = <dynamic>[];
        channel.stream.listen(seen.add);
        async.elapse(Duration.zero);

        async.elapse(const Duration(milliseconds: 2500));
        expect(seen, hasLength(3),
            reason: 'a second timer on the same channel doubles the sampling '
                'cost invisibly');

        channel.stop();
      });
    });

    test('before it starts the stream is empty rather than null', () async {
      final channel = SystemMonitorChannel();

      expect(await channel.stream.isEmpty, isTrue);
    });

    test('a reading carries itself as JSON and reads back', () async {
      final channel = SystemMonitorChannel(metrics: ['memory']);
      await channel.start();
      final seen = <SystemMetrics>[];
      channel.stream.listen((event) => seen.add(event as SystemMetrics));
      await Future<void>.delayed(Duration.zero);

      final metrics = seen.single;
      expect(metrics.toJson(), same(metrics.data),
          reason: 'the payload a document binds to is the JSON form');
      expect(metrics.toString(), contains('SystemMetrics('));

      await channel.stop();
    });
  });
}
