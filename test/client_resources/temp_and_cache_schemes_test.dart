// The `temp://` and `cache://` halves of `client://`, and the refusals in
// front of every scheme.
//
// These two are the ones a document reaches for when it wants to keep
// something between screens, so the round trip has to work — and the guards
// around them are what stop a name from reaching outside the directory the
// grant covers.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_mcp_ui_runtime/src/client_resources/client_resource_resolver.dart';
import 'package:flutter_mcp_ui_runtime/src/platform/host_platform.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ClientResourceResolver resolver;
  late Directory workspace;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    workspace = await Directory.systemTemp.createTemp('mcp_ws_');
    resolver = ClientResourceResolver()..setWorkingDirectory(workspace.path);
    await resolver.init();
  });

  tearDown(() async {
    await resolver.clearCache();
    if (await workspace.exists()) {
      await workspace.delete(recursive: true);
    }
  });

  group('cache://', () {
    test('a written entry reads back, and survives a second resolver', () async {
      final written = await resolver.write('client://cache/session', 'token-1');
      expect(written.success, isTrue);
      expect(written.type, 'cache');

      final read = await resolver.resolve('client://cache/session');
      expect(read.success, isTrue);
      expect(read.content, 'token-1');
      expect(read.type, 'cache');

      final second = ClientResourceResolver();
      await second.init();
      expect((await second.resolve('client://cache/session')).content, 'token-1',
          reason: 'the cache is what a document keeps across screens; a copy '
              'that lives in one resolver is a variable, not a cache');
    });

    test('a key that was never written is a miss, said plainly', () async {
      final read = await resolver.resolve('client://cache/nothing');

      expect(read.success, isFalse);
      expect(read.error, contains('Cache key not found'));
      expect(read.content, isNull);
    });

    test('an entry can be replaced', () async {
      await resolver.write('client://cache/session', 'token-1');
      await resolver.write('client://cache/session', 'token-2');

      expect((await resolver.resolve('client://cache/session')).content,
          'token-2');
    });

    test('deleting removes it, and deleting again says nothing was there',
        () async {
      await resolver.write('client://cache/session', 'token-1');

      expect(await resolver.deleteCache('session'), isTrue);
      expect((await resolver.resolve('client://cache/session')).success, isFalse);
    });

    test('clearing removes every entry this resolver owns', () async {
      await resolver.write('client://cache/a', '1');
      await resolver.write('client://cache/b', '2');

      await resolver.clearCache();

      expect((await resolver.resolve('client://cache/a')).success, isFalse);
      expect((await resolver.resolve('client://cache/b')).success, isFalse);
    });

    test('an uninitialised resolver initialises itself on first use', () async {
      final fresh = ClientResourceResolver();

      final written = await fresh.write('client://cache/lazy', 'x');
      expect(written.success, isTrue,
          reason: 'a document that reads the cache before the host called '
              'init() must get its value, not an error about wiring');
      expect((await fresh.resolve('client://cache/lazy')).content, 'x');
      expect(await fresh.deleteCache('lazy'), isTrue);
      await fresh.clearCache();
    });
  });

  group('temp://', () {
    test('a written file reads back under its sanitised name', () async {
      final written = await resolver.write('client://temp/report.txt', 'hello');
      expect(written.success, isTrue);
      expect(written.type, 'temp');
      addTearDown(() {
        final file = File(written.path!);
        if (file.existsSync()) file.deleteSync();
      });

      final read = await resolver.resolve('client://temp/report.txt');
      expect(read.success, isTrue);
      expect(read.content, 'hello');
      expect(read.type, 'temp');
    });

    test('a traversal in a temp name is refused before it is sanitised',
        () async {
      final written =
          await resolver.write('client://temp/../../escape.txt', 'hello');

      expect(written.success, isFalse,
          reason: '§8.3.3 — the URI is refused at the parse, which is earlier '
              'than the basename sanitising behind it and does not depend on '
              'it');
      expect(written.error, startsWith('Path traversal not allowed'));
    });

    test('a nested name is reduced to its last segment', () async {
      final written =
          await resolver.write('client://temp/reports/june.txt', 'hello');
      expect(written.success, isTrue);
      addTearDown(() {
        final file = File(written.path!);
        if (file.existsSync()) file.deleteSync();
      });

      expect(written.path, contains('mcp_june.txt'),
          reason: 'a temp name is a name, not a path — the leading segments '
              'are dropped rather than creating directories in temp');
      expect((await resolver.resolve('client://temp/reports/june.txt')).content,
          'hello',
          reason: 'reading has to sanitise the same way, or a document cannot '
              'read back what it just wrote');
    });

    test('reading a temp file that was never written is a miss', () async {
      final read = await resolver.resolve('client://temp/never-written.txt');

      expect(read.success, isFalse);
      expect(read.error, contains('Temp file not found'));
    });

    test('with no temp directory discovered the scheme refuses', () async {
      // `init()` is what discovers it; a resolver that skipped init has no
      // directory, and writing "somewhere" would be worse than refusing.
      final uninitialised = ClientResourceResolver();

      expect((await uninitialised.write('client://temp/a.txt', 'x')).error,
          contains('Temp directory not available'));
      expect((await uninitialised.resolve('client://temp/a.txt')).error,
          contains('Temp directory not available'));
    });
  });

  group('the refusals every scheme shares', () {
    test('a traversal segment is refused on read and on write', () async {
      for (final uri in const [
        'client://file/etc/../../../secrets',
        'client://workspace/notes/../../secrets',
      ]) {
        expect((await resolver.resolve(uri)).error,
            startsWith('Path traversal not allowed'),
            reason: '$uri reads outside the grant');
        expect((await resolver.write(uri, 'x')).error,
            startsWith('Path traversal not allowed'),
            reason: '$uri writes outside the grant');
      }
    });

    test('an unknown scheme is named rather than guessed at', () async {
      expect((await resolver.resolve('client://ftp/thing')).error,
          contains('Unknown scheme'));
      expect((await resolver.write('client://ftp/thing', 'x')).error,
          contains('Unknown scheme'));
    });

    test('workspace access with no working directory refuses', () async {
      final noWorkspace = ClientResourceResolver();
      await noWorkspace.init();

      expect((await noWorkspace.resolve('client://workspace/a.txt')).error,
          contains('Working directory not set'));
      expect((await noWorkspace.write('client://workspace/a.txt', 'x')).error,
          contains('Working directory not set'));
    });

    test('a directory in place of a file fails rather than returning empty',
        () async {
      Directory('${workspace.path}/folder').createSync();

      final read = await resolver.resolve('client://workspace/folder');
      expect(read.success, isFalse,
          reason: 'an empty string for a directory is indistinguishable from '
              'an empty file');
    });

    test('a file path that names a directory fails the same way', () async {
      final read = await resolver.resolve('client://file${workspace.path}');
      expect(read.success, isFalse);
    });
  });
  group('a resolver nobody initialised', () {
    test('reads and writes the cache anyway', () async {
      final lazy = ClientResourceResolver();

      final written = await lazy.write('client://cache/token', 'abc');
      expect(written.success, isTrue,
          reason: 'the store opens on first use; requiring an explicit init '
              'makes the first write of every session vanish');

      final read = await lazy.resolve('client://cache/token');
      expect(read.content, 'abc');

      expect(await lazy.deleteCache('token'), isTrue);
      expect((await lazy.resolve('client://cache/token')).success, isFalse);
    });

    test('deletes without an explicit init', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'mcp_client_cache_stale': 'from a previous session',
      });
      final lazy = ClientResourceResolver();

      expect(await lazy.deleteCache('stale'), isTrue,
          reason: 'a host clearing one key at startup should not have to '
              'open the store first');
      expect((await lazy.resolve('client://cache/stale')).success, isFalse);
    });

    test('clears without an explicit init', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'mcp_client_cache_a': '1',
      });
      final lazy = ClientResourceResolver();

      await lazy.clearCache();

      expect((await lazy.resolve('client://cache/a')).success, isFalse,
          reason: 'a sign-out that leaves the previous session readable is '
              'the failure this exists to prevent');
    });

    test('clears the cache anyway, leaving other keys alone', () async {
      final lazy = ClientResourceResolver();
      await lazy.write('client://cache/a', '1');
      await lazy.write('client://cache/b', '2');

      await lazy.clearCache();

      expect((await lazy.resolve('client://cache/a')).success, isFalse);
      expect((await lazy.resolve('client://cache/b')).success, isFalse);
    });
  });

  group('a temp name that points somewhere else', () {
    test('a symlink out of the temp directory is refused', () async {
      // Written the way an attacker would: a legitimate-looking temp name
      // whose entry is a link to a file the grant never covered.
      // Outside the temp tree entirely — the workspace fixture itself lives
      // under systemTemp, so a file there would not be an escape.
      final outside = File('${Directory.current.path}/.dart_tool/mcp_symlink_probe.txt')
        ..writeAsStringSync('the private one');
      addTearDown(() {
        if (outside.existsSync()) outside.deleteSync();
      });
      final tempDir = Directory.systemTemp.path;
      final link = Link('$tempDir/mcp_symlink_probe.txt');
      if (link.existsSync()) link.deleteSync();
      link.createSync(outside.path);
      addTearDown(() {
        if (link.existsSync()) link.deleteSync();
      });

      final read = await resolver.resolve('client://temp/symlink_probe.txt');

      expect(read.success, isFalse,
          reason: 'the name stayed inside temp and the file did not; reading '
              'it would hand the document a file outside its grant');
      expect(read.error, contains('escapes temp directory'));
      expect(read.content, isNull);
    });
  });
  // On a browser there is no filesystem to reach, so every scheme that names
  // one has to refuse by name. A silent null there reads as "the file is
  // empty" — which is how a document ends up showing a blank where it should
  // be telling the user this cannot work here.
  group('on a browser', () {
    setUp(() => HostPlatform.override(name: 'web'));
    tearDown(HostPlatform.clearOverride);

    test('every filesystem scheme refuses to read, and says which', () async {
      final refusals = <String, String>{
        'client://file/tmp/a.txt': 'File access',
        'client://workspace/a.txt': 'Workspace access',
        'client://temp/a.txt': 'Temp access',
      };

      for (final entry in refusals.entries) {
        final read = await resolver.resolve(entry.key);
        expect(read.success, isFalse, reason: entry.key);
        expect(read.error, contains(entry.value),
            reason: '${entry.key} has to name the scheme that cannot work '
                'here; "failed" alone sends an author looking at their path');
        expect(read.error, contains('web'));
      }
    });

    test('every filesystem scheme refuses to write too', () async {
      for (final uri in const [
        'client://file/tmp/a.txt',
        'client://workspace/a.txt',
        'client://temp/a.txt',
      ]) {
        final written = await resolver.write(uri, 'x');
        expect(written.success, isFalse, reason: uri);
        expect(written.error, contains('web'), reason: uri);
      }
    });

    test('the cache still works, because it is not a filesystem', () async {
      expect((await resolver.write('client://cache/token', 'abc')).success,
          isTrue);
      expect((await resolver.resolve('client://cache/token')).content, 'abc',
          reason: 'a browser has storage; refusing the cache there would take '
              'away the one scheme that does work');
    });
  });
  // The failure paths. Each of these is a real filesystem or store failure —
  // a file that turns out to be a directory, an entry too big to hand over, a
  // store nobody opened yet. The refusal has to name what went wrong: a null
  // content with no error reads as an empty file, and a document renders a
  // blank where it should be telling the user the read failed.
  group('when the read itself fails', () {
    test('a text file that is not text is refused, not read as empty',
        () async {
      // A binary payload behind a `.txt` name — what a mislabelled download
      // looks like. The decode throws, and the throw has to become a refusal.
      final broken = File('${workspace.path}/broken.txt')
        ..writeAsBytesSync(<int>[0xC3, 0x28, 0xA0, 0xA1]);
      expect(broken.existsSync(), isTrue);

      final read = await resolver.resolve('client://file/${broken.path}');

      expect(read.success, isFalse);
      expect(read.error, contains('Failed to read file'),
          reason: 'an empty string for an undecodable file is '
              'indistinguishable from an empty file');
    });

    test('a workspace file that will not decode is refused the same way',
        () async {
      File('${workspace.path}/wbroken.txt')
          .writeAsBytesSync(<int>[0xC3, 0x28, 0xA0, 0xA1]);

      final read = await resolver.resolve('client://workspace/wbroken.txt');

      expect(read.success, isFalse);
      expect(read.error, contains('Failed to read workspace file'));
    });

    test('a temp file that will not decode is refused too', () async {
      final tempDir = Directory.systemTemp.path;
      final broken = File('$tempDir/mcp_broken_probe')
        ..writeAsBytesSync(<int>[0xC3, 0x28, 0xA0, 0xA1]);
      addTearDown(() {
        if (broken.existsSync()) broken.deleteSync();
      });

      final read = await resolver.resolve('client://temp/broken_probe');

      expect(read.success, isFalse);
      expect(read.error, contains('Failed to read temp file'));
    });

    test('a temp file past the size ceiling is refused by size', () async {
      // Sparse: the bytes are never written, so this costs nothing on disk
      // and still reports a size over the limit.
      final tempDir = Directory.systemTemp.path;
      final big = File('$tempDir/mcp_big_probe');
      final raf = big.openSync(mode: FileMode.write);
      raf.setPositionSync(ResourceSizeLimits.tempMaxBytes + 1);
      raf.writeByteSync(0);
      raf.closeSync();
      addTearDown(() {
        if (big.existsSync()) big.deleteSync();
      });

      final read = await resolver.resolve('client://temp/big_probe');

      expect(read.success, isFalse);
      expect(read.error, contains('exceeds size limit'),
          reason: 'a hundred-megabyte read handed to a document is a hang, '
              'not a resource; the ceiling has to say why it refused');
      expect(read.error, contains('bytes'));
    });

    test('a cache entry past the size ceiling is refused by size', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'mcp_client_cache_oversized': 'x' * (ResourceSizeLimits.cacheMaxBytes + 1),
      });
      final fresh = ClientResourceResolver();
      await fresh.init();

      final read = await fresh.resolve('client://cache/oversized');

      expect(read.success, isFalse);
      expect(read.error, contains('exceeds size limit'));
    });

    test('a read before init opens the store on the way through', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'mcp_client_cache_seeded': 'from a previous session',
      });
      // No `init()` — the read is the first thing this resolver does.
      final lazy = ClientResourceResolver();

      final read = await lazy.resolve('client://cache/seeded');

      expect(read.content, 'from a previous session',
          reason: 'what a previous session cached is what a restart shows; '
              'requiring an explicit init makes the first read of every '
              'session come back empty');
      expect(read.type, 'cache');
    });
  });

  group('client://asset', () {
    test('a bundled asset is read through the app bundle', () async {
      // The asset bundle answers over a platform channel; standing in for it
      // is how a test reaches the branch a packaged app takes.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (message) async {
        final key = utf8.decode(message!.buffer.asUint8List());
        if (key != 'assets/greeting.txt') return null;
        final bytes = utf8.encode('hello from the bundle');
        return Uint8List.fromList(bytes).buffer.asByteData();
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null));

      final read = await resolver.resolve('client://asset/greeting.txt');

      expect(read.success, isTrue);
      expect(read.content, 'hello from the bundle');
      expect(read.type, 'asset');
    });

    test('an asset that is not in the bundle is refused by name', () async {
      final read = await resolver.resolve('client://asset/missing.txt');

      expect(read.success, isFalse);
      expect(read.error, contains('Failed to load asset'),
          reason: 'a document naming an asset the build did not include has '
              'to hear about it; an empty string reads as an empty file');
    });
  });

  group('when the write itself fails', () {
    test('a file:// write where a directory already sits is reported',
        () async {
      // The write creates missing parents, so the way this fails in the field
      // is a name already taken by a directory.
      Directory('${workspace.path}/taken').createSync();

      final written =
          await resolver.write('client://file/${workspace.path}/taken', 'x');

      expect(written.success, isFalse);
      expect(written.error, contains('Failed to write file'),
          reason: 'a write that reports success and stores nothing is how a '
              'document loses what the user typed');
    });

    test('a workspace write where a directory already sits is reported',
        () async {
      Directory('${workspace.path}/wstaken').createSync();

      final written = await resolver.write('client://workspace/wstaken', 'x');

      expect(written.success, isFalse);
      expect(written.error, contains('Failed to write workspace file'));
    });

    test('a temp write where a directory already sits is reported', () async {
      final dir = Directory('${Directory.systemTemp.path}/mcp_taken_probe');
      if (!dir.existsSync()) dir.createSync();
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });

      final written = await resolver.write('client://temp/taken_probe', 'x');

      expect(written.success, isFalse);
      expect(written.error, contains('Failed to write temp file'));
    });
  });
}
