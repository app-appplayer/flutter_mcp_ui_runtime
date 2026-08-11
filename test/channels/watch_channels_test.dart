// The two filesystem watch channels.
//
// A watch channel is how a document follows a file it does not own, so the
// refusals matter as much as the events: starting on a path that is not there
// must say so rather than sitting silently, and stopping has to release the
// watcher — a channel left running after its page is gone keeps a directory
// handle open for the life of the process.

import 'dart:async';
import 'dart:io';

import 'package:flutter_mcp_ui_runtime/src/channels/channel_types/directory_watch_channel.dart';
import 'package:flutter_mcp_ui_runtime/src/platform/host_platform.dart';
import 'package:flutter_mcp_ui_runtime/src/channels/channel_types/file_watch_channel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mcp_watch_');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  group('FileWatchChannel', () {
    test('a file that is not there is refused by name', () async {
      final channel = FileWatchChannel(path: '${root.path}/missing.txt');

      await expectLater(channel.start(), throwsA(isA<FileSystemException>()),
          reason: 'a watch that starts on nothing reports no events, which '
              'reads exactly like a file that never changes');
      expect(channel.isActive, isFalse);
    });

    test('before it starts the stream is empty rather than null', () async {
      final channel = FileWatchChannel(path: '${root.path}/a.txt');

      expect(await channel.stream.isEmpty, isTrue);
    });

    test('a modification is reported, and stopping releases the watcher',
        () async {
      final file = File('${root.path}/a.txt')..writeAsStringSync('one');
      final channel = FileWatchChannel(path: file.path);

      await channel.start();
      expect(channel.isActive, isTrue);

      final events = <FileWatchEvent>[];
      final subscription =
          channel.stream.cast<FileWatchEvent>().listen(events.add);

      file.writeAsStringSync('two');
      // The watcher polls, so give it a few real cycles rather than a frame.
      for (var i = 0; i < 40 && events.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      expect(events, isNotEmpty,
          reason: 'a document bound to this channel shows the file as it was '
              'first read, forever, if the change is not reported');
      expect(events.first.path, file.path);
      expect(events.first.type, FileWatchEventType.modified);

      await subscription.cancel();
      await channel.stop();
      expect(channel.isActive, isFalse);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('starting twice does not open a second watcher', () async {
      final file = File('${root.path}/a.txt')..writeAsStringSync('one');
      final channel = FileWatchChannel(path: file.path);

      await channel.start();
      var closed = false;
      final subscription =
          channel.stream.listen((_) {}, onDone: () => closed = true);

      await channel.start();

      expect(closed, isFalse,
          reason: 'a second start that rebuilt the controller would strand '
              'the first watcher, still running, with nobody listening');
      expect(channel.isActive, isTrue);

      await subscription.cancel();
      await channel.stop();
    });

    test('stopping a channel that never started is not an error', () async {
      await FileWatchChannel(path: '${root.path}/a.txt').stop();
    });

    test('an event carries a shape a document can bind to', () {
      final event = FileWatchEvent(
        type: FileWatchEventType.created,
        path: '/tmp/a.txt',
        timestamp: DateTime.utc(2026, 3, 15, 9, 30),
      );

      expect(event.toJson(), {
        'type': 'created',
        'path': '/tmp/a.txt',
        'timestamp': '2026-03-15T09:30:00.000Z',
      });
      expect(event.toString(), contains('/tmp/a.txt'));
    });
  });

  // A browser has no filesystem, and these two channels say so rather than
  // sitting there looking subscribed. The check reads the host port, so it is
  // reachable from a VM test — with `kIsWeb` it could only have been seen by
  // running the whole suite in a browser.
  group('on the web', () {
    setUp(() => HostPlatform.override(name: 'web'));
    tearDown(HostPlatform.clearOverride);

    test('watching a file is refused by name', () async {
      final channel = FileWatchChannel(path: '/tmp/whatever.txt');

      await expectLater(
        channel.start(),
        throwsA(isA<UnsupportedError>().having(
            (e) => e.toString(), 'message', contains('not supported on web'))),
        reason: 'a channel that starts and never emits is indistinguishable '
            'from a file nobody is touching',
      );
    });

    test('watching a directory is refused by name', () async {
      final channel = DirectoryWatchChannel(path: '/tmp');

      await expectLater(
        channel.start(),
        throwsA(isA<UnsupportedError>().having(
            (e) => e.toString(), 'message', contains('not supported on web'))),
      );
    });
  });

  group('DirectoryWatchChannel', () {
    test('a directory that is not there is refused by name', () async {
      final channel = DirectoryWatchChannel(path: '${root.path}/missing');

      await expectLater(channel.start(), throwsA(isA<FileSystemException>()));
      expect(channel.isActive, isFalse);
    });

    test('a new file in the directory is reported', () async {
      final channel = DirectoryWatchChannel(path: root.path);
      await channel.start();

      final events = <DirectoryWatchEvent>[];
      final subscription =
          channel.stream.cast<DirectoryWatchEvent>().listen(events.add);

      File('${root.path}/new.txt').writeAsStringSync('x');
      for (var i = 0; i < 40 && events.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      expect(events, isNotEmpty);
      expect(events.first.type, DirectoryWatchEventType.created);
      expect(events.first.path, endsWith('new.txt'));

      await subscription.cancel();
      await channel.stop();
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('a recursive watch is declared as such', () {
      expect(DirectoryWatchChannel(path: root.path, recursive: true).recursive,
          isTrue);
      expect(DirectoryWatchChannel(path: root.path).recursive, isFalse);
    });

    test('before it starts the stream is empty rather than null', () async {
      expect(
          await DirectoryWatchChannel(path: root.path).stream.isEmpty, isTrue);
    });

    test('starting twice does not open a second watcher', () async {
      final channel = DirectoryWatchChannel(path: root.path);

      await channel.start();
      var closed = false;
      final subscription =
          channel.stream.listen((_) {}, onDone: () => closed = true);

      await channel.start();

      expect(closed, isFalse);
      expect(channel.isActive, isTrue);

      await subscription.cancel();
      await channel.stop();
    });

    test('an event carries a shape a document can bind to', () {
      final event = DirectoryWatchEvent(
        type: DirectoryWatchEventType.deleted,
        path: '/tmp/gone.txt',
        timestamp: DateTime.utc(2026, 3, 15, 9, 30),
      );

      expect(event.toJson(), {
        'type': 'deleted',
        'path': '/tmp/gone.txt',
        'timestamp': '2026-03-15T09:30:00.000Z',
      });
      expect(event.toString(), contains('deleted'));
    });
  });
}
