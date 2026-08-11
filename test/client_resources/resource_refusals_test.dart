// `client://` resources — what the resolver refuses, and why.
//
// Nearly every uncovered line in this file was a refusal: a traversal attempt,
// a file outside the workspace, an entry past its size limit, a write to a
// path the document does not own. They are the security surface of the whole
// scheme, and none of them had ever been exercised — a resolver that had
// quietly stopped checking would have passed the suite unchanged.
//
// The reads and writes here are real, on real temp directories, because a
// traversal check is only meaningful against a filesystem that would have
// answered.

import 'dart:io';

import 'package:flutter_mcp_ui_runtime/src/client_resources/client_resource_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ClientResourceResolver resolver;
  late Directory workspace;
  late Directory outside;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    resolver = ClientResourceResolver();
    await resolver.init();
    workspace = Directory.systemTemp.createTempSync('resource_ws_');
    outside = Directory.systemTemp.createTempSync('resource_out_');
    File('${outside.path}/secret.txt').writeAsStringSync('not yours');
  });

  tearDown(() {
    workspace.deleteSync(recursive: true);
    outside.deleteSync(recursive: true);
  });

  group('what the scheme is', () {
    test('a client:// uri is recognised and anything else is not', () {
      expect(resolver.isClientResource('client://file/tmp/a.txt'), isTrue);
      expect(resolver.isClientResource('https://example.test'), isFalse);
    });

    test('an unknown scheme is named rather than guessed at', () async {
      final result = await resolver.resolve('client://teleport/somewhere');

      expect(result.success, isFalse);
      expect(result.error, contains('teleport'));
    });
  });

  group('client://file', () {
    test('reads a file that is there', () async {
      final file = File('${workspace.path}/note.txt')
        ..writeAsStringSync('hello');

      final result = await resolver.resolve('client://file/${file.path}');

      expect(result.success, isTrue);
      expect(result.content, 'hello');
      expect(result.type, 'file');
    });

    test('a missing file is reported by path', () async {
      final result =
          await resolver.resolve('client://file/${workspace.path}/nope.txt');

      expect(result.success, isFalse);
      expect(result.error, contains('not found'));
    });

    test('a traversal segment is refused before anything is read', () async {
      final result = await resolver
          .resolve('client://file/${workspace.path}/../${outside.path}/secret.txt');

      expect(result.success, isFalse);
      expect(result.error, contains('traversal'),
          reason: 'this is the check that keeps a document reading its own '
              'directory rather than the disk — and it is refused at the URI '
              'layer, before any path is built');
    });

    test('a directory read is refused rather than returning nothing',
        () async {
      final result = await resolver.resolve('client://file/${workspace.path}');

      expect(result.success, isFalse);
    });
  });

  group('client://workspace', () {
    test('with no working directory set, nothing resolves', () async {
      final result = await resolver.resolve('client://workspace/note.txt');

      expect(result.success, isFalse);
      expect(result.error, contains('Working directory'),
          reason: 'resolving against the process\'s own cwd would read '
              'whatever the host happened to be started in');
    });

    test('reads a file inside the workspace', () async {
      File('${workspace.path}/note.txt').writeAsStringSync('inside');
      resolver.setWorkingDirectory(workspace.path);

      final result = await resolver.resolve('client://workspace/note.txt');

      expect(result.success, isTrue);
      expect(result.content, 'inside');
    });

    test('a traversal segment is refused', () async {
      resolver.setWorkingDirectory(workspace.path);

      final result =
          await resolver.resolve('client://workspace/../out/secret.txt');

      expect(result.success, isFalse);
      expect(result.error, contains('traversal'));
    });

    test('an absolute path that leaves the workspace is refused', () async {
      resolver.setWorkingDirectory(workspace.path);

      final result = await resolver
          .resolve('client://workspace/${outside.path}/secret.txt');

      expect(result.success, isFalse,
          reason: 'joining an absolute path onto the workspace root has to '
              'stay inside it or be refused — otherwise `workspace` means '
              '"anywhere"');
    });

    test('a missing file inside the workspace is reported', () async {
      resolver.setWorkingDirectory(workspace.path);

      final result = await resolver.resolve('client://workspace/nope.txt');
      expect(result.success, isFalse);
      expect(result.error, contains('not found'));
    });
  });

  group('client://temp', () {
    test('writes and reads back through the same name', () async {
      final written =
          await resolver.write('client://temp/scratch.txt', 'scratch');
      expect(written.success, isTrue);

      final read = await resolver.resolve('client://temp/scratch.txt');
      expect(read.success, isTrue);
      expect(read.content, 'scratch');
      expect(read.type, 'temp');

      File(written.path!).deleteSync();
    });

    test('a name carrying a path is reduced to its basename', () async {
      // The document cannot choose WHERE in temp: everything lands under the
      // resolver's own prefix, so a name with directories in it cannot walk
      // out of the temp directory.
      final written =
          await resolver.write('client://temp/sub/dir/escape.txt', 'scratch');

      expect(written.success, isTrue);
      expect(written.path, contains('mcp_escape.txt'),
          reason: 'the document names a file, not a place: everything lands '
              'directly under the resolver\'s own temp prefix');
      expect(written.path, isNot(contains('sub')));
      File(written.path!).deleteSync();

      // And a `..` never reaches that reduction at all — the URI layer
      // refuses it first.
      final refused = await resolver.write('client://temp/../escape.txt', 'x');
      expect(refused.success, isFalse);
      expect(refused.error, contains('traversal'));
    });

    test('a temp file that was never written is reported', () async {
      final result = await resolver.resolve('client://temp/never-written.txt');

      expect(result.success, isFalse);
      expect(result.error, contains('not found'));
    });
  });

  group('client://cache', () {
    test('writes and reads back', () async {
      final written = await resolver.write('client://cache/rows', 'cached');
      expect(written.success, isTrue);

      final read = await resolver.resolve('client://cache/rows');
      expect(read.success, isTrue);
      expect(read.content, 'cached');
      expect(read.type, 'cache');
    });

    test('a key that was never written is reported', () async {
      final result = await resolver.resolve('client://cache/nothing');

      expect(result.success, isFalse);
      expect(result.error, contains('not found'));
    });

    test('an entry past the size limit is refused rather than returned',
        () async {
      SharedPreferences.setMockInitialValues({
        'mcp_client_cache_huge': 'x' * (ResourceSizeLimits.cacheMaxBytes + 1),
      });
      final fresh = ClientResourceResolver();
      await fresh.init();

      final result = await fresh.resolve('client://cache/huge');

      expect(result.success, isFalse);
      expect(result.error, contains('size limit'),
          reason: 'handing a document a five-megabyte string it asked for by '
              'accident is how a screen locks up');
    });
  });

  group('writing', () {
    test('a file write lands on disk', () async {
      final path = '${workspace.path}/written.txt';
      final result = await resolver.write('client://file/$path', 'from a document');

      expect(result.success, isTrue);
      expect(File(path).readAsStringSync(), 'from a document');
    });

    test('a file write with a traversal segment is refused', () async {
      final result = await resolver.write(
          'client://file/${workspace.path}/../escape.txt', 'nope');

      expect(result.success, isFalse);
      expect(result.error, contains('traversal'));
    });

    test('a workspace write stays inside the workspace', () async {
      resolver.setWorkingDirectory(workspace.path);

      final result =
          await resolver.write('client://workspace/note.txt', 'inside');

      expect(result.success, isTrue);
      expect(File('${workspace.path}/note.txt').readAsStringSync(), 'inside');
    });

    test('a workspace write with no working directory is refused', () async {
      final result =
          await resolver.write('client://workspace/note.txt', 'inside');

      expect(result.success, isFalse);
      expect(result.error, contains('Working directory'));
    });

    test('a workspace write that would leave it is refused', () async {
      resolver.setWorkingDirectory(workspace.path);

      final result =
          await resolver.write('client://workspace/../escape.txt', 'nope');

      expect(result.success, isFalse);
      expect(result.error, contains('traversal'));
    });

    test('an unknown scheme cannot be written to', () async {
      final result = await resolver.write('client://teleport/x', 'nope');

      expect(result.success, isFalse);
    });
  });

  group('the fallback', () {
    test('a failing primary falls back to the second uri', () async {
      File('${workspace.path}/backup.txt').writeAsStringSync('the backup');

      final result = await resolver.resolve(
        'client://file/${workspace.path}/missing.txt',
        fallback: 'client://file/${workspace.path}/backup.txt',
      );

      expect(result.success, isTrue);
      expect(result.content, 'the backup');
    });

    test('when both fail, the primary\'s error is the one reported',
        () async {
      final result = await resolver.resolve(
        'client://file/${workspace.path}/missing.txt',
        fallback: 'client://file/${workspace.path}/also-missing.txt',
      );

      expect(result.success, isFalse);
      expect(result.error, contains('missing.txt'),
          reason: 'reporting the fallback\'s failure would send the author '
              'looking at the wrong path');
    });

    test('a successful primary never reaches the fallback', () async {
      File('${workspace.path}/main.txt').writeAsStringSync('the main one');

      final result = await resolver.resolve(
        'client://file/${workspace.path}/main.txt',
        fallback: 'client://file/${workspace.path}/backup.txt',
      );

      expect(result.content, 'the main one');
    });
  });

  group('custom providers', () {
    test('a registered scheme is dispatched to its handler', () async {
      resolver.customProviders.register(CustomResourceProvider(
        scheme: 'device',
        handler: (path, config) async => ResourceResult.success(
          content: 'reading for $path',
          path: path,
          type: 'device',
        ),
      ));

      final result = await resolver.resolve('client://device/sensor-1');

      expect(result.success, isTrue);
      expect(result.content, 'reading for sensor-1');
    });

    test('an unregistered scheme is still refused by name', () async {
      resolver.customProviders.register(CustomResourceProvider(
        scheme: 'device',
        handler: (path, config) async =>
            ResourceResult.success(content: 'x', path: path, type: 'device'),
      ));

      final result = await resolver.resolve('client://other/thing');
      expect(result.success, isFalse);
    });
  });
}
