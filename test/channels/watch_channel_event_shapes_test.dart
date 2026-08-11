// The watch events a real filesystem will not produce on demand.
//
// `watch_channels_test.dart` drives these channels against real files, which
// is the right test for "does watching work". What it cannot produce is the
// rest of the alphabet: a modification distinguished from a creation on a
// platform that coalesces them, a deletion, and the watcher's own failure.
// Those arms decide what a bound document is told, and until now nothing had
// seen them — a `deleted` reported as `modified` leaves a file on screen that
// is no longer there.
//
// The channels take their watcher from a replaceable factory for exactly this
// reason; here the test is the watcher.

import 'dart:async';
import 'dart:io';

import 'package:flutter_mcp_ui_runtime/src/channels/channel_types/directory_watch_channel.dart';
import 'package:flutter_mcp_ui_runtime/src/channels/channel_types/file_watch_channel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watcher/watcher.dart';

/// A watcher the test drives, standing in for the OS.
class _ScriptedWatcher implements Watcher {
  _ScriptedWatcher(this.path);

  @override
  final String path;

  final _events = StreamController<WatchEvent>.broadcast();

  @override
  Stream<WatchEvent> get events => _events.stream;

  @override
  bool get isReady => true;

  @override
  Future<void> get ready async {}

  void emit(ChangeType type, String at) => _events.add(WatchEvent(type, at));

  void fail(Object error) => _events.addError(error);

  Future<void> close() => _events.close();
}

void main() {
  late Directory temp;
  late _ScriptedWatcher watcher;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('watch_shapes');
    watcher = _ScriptedWatcher(temp.path);
  });

  tearDown(() async {
    FileWatchChannel.watcherFactory = FileWatcher.new;
    DirectoryWatchChannel.watcherFactory = DirectoryWatcher.new;
    await watcher.close();
    if (temp.existsSync()) await temp.delete(recursive: true);
  });

  group('FileWatchChannel', () {
    late File file;
    late FileWatchChannel channel;

    setUp(() async {
      file = File('${temp.path}/watched.txt')..writeAsStringSync('start');
      FileWatchChannel.watcherFactory = (_) => watcher;
      channel = FileWatchChannel(path: file.path);
      await channel.start();
    });

    tearDown(() => channel.stop());

    test('every change type keeps its own name', () async {
      final seen = <FileWatchEvent>[];
      channel.stream.listen((e) => seen.add(e as FileWatchEvent));

      watcher
        ..emit(ChangeType.ADD, file.path)
        ..emit(ChangeType.MODIFY, file.path)
        ..emit(ChangeType.REMOVE, file.path);
      await Future<void>.delayed(Duration.zero);

      expect(seen.map((e) => e.type), <FileWatchEventType>[
        FileWatchEventType.created,
        FileWatchEventType.modified,
        FileWatchEventType.deleted,
      ], reason: 'a document that reloads on `modified` and clears on '
          '`deleted` behaves oppositely for the two; collapsing them leaves '
          'a deleted file on screen');
      expect(seen.every((e) => e.path == file.path), isTrue);
    });

    test('the watcher failing reaches the document, not the console',
        () async {
      final errors = <Object>[];
      channel.stream.listen((_) {}, onError: errors.add);

      // A watch can die under the app — the volume unmounts, the descriptor
      // limit is hit. Swallowing that leaves a screen that has quietly
      // stopped updating and says nothing.
      watcher.fail(const FileSystemException('watch failed'));
      await Future<void>.delayed(Duration.zero);

      expect(errors, hasLength(1));
      expect(errors.single, isA<FileSystemException>());
    });
  });

  group('DirectoryWatchChannel', () {
    late DirectoryWatchChannel channel;

    setUp(() async {
      DirectoryWatchChannel.watcherFactory = (_) => watcher;
      channel = DirectoryWatchChannel(path: temp.path);
      await channel.start();
    });

    tearDown(() => channel.stop());

    test('every change type keeps its own name', () async {
      final seen = <DirectoryWatchEvent>[];
      channel.stream.listen((e) => seen.add(e as DirectoryWatchEvent));

      final child = '${temp.path}/a.txt';
      watcher
        ..emit(ChangeType.ADD, child)
        ..emit(ChangeType.MODIFY, child)
        ..emit(ChangeType.REMOVE, child);
      await Future<void>.delayed(Duration.zero);

      expect(seen.map((e) => e.type), <DirectoryWatchEventType>[
        DirectoryWatchEventType.created,
        DirectoryWatchEventType.modified,
        DirectoryWatchEventType.deleted,
      ]);
    });

    test('a rename arrives as a removal and an addition', () async {
      final seen = <DirectoryWatchEvent>[];
      channel.stream.listen((e) => seen.add(e as DirectoryWatchEvent));

      watcher
        ..emit(ChangeType.REMOVE, '${temp.path}/old.txt')
        ..emit(ChangeType.ADD, '${temp.path}/new.txt');
      await Future<void>.delayed(Duration.zero);

      expect(seen.map((e) => '${e.type.name}:${e.path.split('/').last}'),
          <String>['deleted:old.txt', 'created:new.txt'],
          reason: 'a file browser bound to this has to drop one row and add '
              'another; one event with the wrong path leaves a ghost');
    });

    test('the watcher failing reaches the document', () async {
      final errors = <Object>[];
      channel.stream.listen((_) {}, onError: errors.add);

      watcher.fail(const FileSystemException('watch failed'));
      await Future<void>.delayed(Duration.zero);

      expect(errors, hasLength(1));
    });
  });
}
