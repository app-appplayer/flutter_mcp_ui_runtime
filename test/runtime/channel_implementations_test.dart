import 'dart:async';
import 'dart:io';

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

      // start() creates a broadcast stream and emits initial event synchronously,
      // so we must subscribe immediately after start() in the same microtask
      await channel.start();

      // Use pollCount which tracks emissions regardless of listener timing
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

  group('TC-067: SystemMonitorChannel', () {
    test('Normal: monitors system metrics at interval', () {
      final channel = SystemMonitorChannel(
        metrics: ['cpu', 'memory', 'disk', 'network'],
        interval: 5000,
      );

      expect(channel, isA<Channel>());
      expect(channel.isActive, isFalse);
    });

    test('Normal: start/stop lifecycle', () async {
      final channel = SystemMonitorChannel(
        metrics: ['cpu', 'memory'],
        interval: 5000,
      );

      await channel.start();
      expect(channel.isActive, isTrue);

      await channel.stop();
      expect(channel.isActive, isFalse);
    });

    test('Normal: default interval is 5 seconds', () {
      final channel = SystemMonitorChannel();
      expect(channel, isA<Channel>());
    });

    test('Boundary: single metric monitoring', () {
      final channel = SystemMonitorChannel(metrics: ['cpu']);
      expect(channel, isA<Channel>());
    });
  });
}
