// Writing through `client://`, and the boundary that keeps it inside the
// workspace.
//
// `write` and the workspace/temp/cache paths were uncovered. This is the
// surface that spends a user's `file.write` grant, so the refusals are the
// point: a traversal that resolves lets a document write anywhere the process
// can reach, and it does so while looking like an ordinary relative path.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/client_resources/client_resource_resolver.dart';

void main() {
  late Directory workspace;
  late ClientResourceResolver resolver;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('mcp_ws_');
    resolver = ClientResourceResolver()..setWorkingDirectory(workspace.path);
    // `init()` is what discovers the temp / cache directories; without it the
    // temp scheme reports "not available" rather than writing somewhere
    // arbitrary, which is the right refusal but not what these exercise.
    await resolver.init();
  });

  tearDown(() async {
    if (await workspace.exists()) {
      await workspace.delete(recursive: true);
    }
  });

  group('workspace round-trip', () {
    test('a written file reads back', () async {
      final written =
          await resolver.write('client://workspace/notes/a.txt', 'hello');
      expect(written.error, isNull);
      expect(written.success, isTrue);

      final read = await resolver.resolve('client://workspace/notes/a.txt');
      expect(read.success, isTrue);
      expect(read.content, 'hello');
      expect(read.isBinary, isFalse);
    });

    test('nested directories are created on the way', () async {
      final written = await resolver.write(
          'client://workspace/deep/deeper/deepest.txt', 'x');
      expect(written.success, isTrue);
      expect(
        File('${workspace.path}/deep/deeper/deepest.txt').existsSync(),
        isTrue,
      );
    });

    test('reading something that is not there fails rather than empty',
        () async {
      final read = await resolver.resolve('client://workspace/missing.txt');
      expect(read.success, isFalse,
          reason: 'an empty string for a missing file is indistinguishable '
              'from a file that is genuinely empty');
    });
  });

  group('the workspace boundary', () {
    test('a traversal is refused on write', () async {
      final result =
          await resolver.write('client://workspace/../escape.txt', 'x');
      expect(result.success, isFalse);
      // The URI parser rejects `..` before the path check sees it; either
      // refusal is fine as long as nothing lands outside.
      expect(File('${workspace.parent.path}/escape.txt').existsSync(), isFalse);
    });

    test('a traversal is refused on read', () async {
      final result = await resolver.resolve('client://workspace/../../etc/hosts');
      expect(result.success, isFalse);
    });

    // `..` is not the only way out. An ABSOLUTE path carries no `..` at all,
    // so it passes every traversal check — and `p.join(workspace, '/etc/x')`
    // answers `/etc/x`, discarding the workspace entirely. The containment
    // check after the join is the only thing standing between a document and
    // the rest of the disk, and it was the one line here nothing had run.
    test('an absolute path does not escape the workspace on write', () async {
      final outside = File('${workspace.parent.path}/mcp_abs_escape_probe.txt');
      if (outside.existsSync()) outside.deleteSync();

      final result = await resolver.write(
          'client://workspace/${outside.path}', 'x');

      expect(result.success, isFalse);
      expect(result.error, contains('traversal'));
      expect(outside.existsSync(), isFalse,
          reason: 'a path with no `..` in it still leaves the workspace once '
              'it is absolute; only the resolved-path check catches that');
      if (outside.existsSync()) outside.deleteSync();
    });

    test('an absolute path does not escape the workspace on read', () async {
      final result =
          await resolver.resolve('client://workspace//etc/hosts');
      expect(result.success, isFalse);
      expect(result.error, contains('traversal'));
    });

    test('a deep traversal buried mid-path is refused too', () async {
      final result = await resolver
          .write('client://workspace/notes/../../escape.txt', 'x');
      expect(result.success, isFalse,
          reason: 'checking only the first segment is how a traversal gets '
              'through — the whole path has to normalise inside');
    });
  });

  group('other write schemes', () {
    test('temp accepts a write and reads it back', () async {
      final written = await resolver.write('client://temp/scratch.txt', 'tmp');
      expect(written.error, isNull);
      expect(written.success, isTrue);

      final read = await resolver.resolve('client://temp/scratch.txt');
      expect(read.error, isNull);
      expect(read.content, 'tmp');
    });

    test('an unknown scheme is refused by name on write', () async {
      final result = await resolver.write('client://telepathy/a', 'x');
      expect(result.success, isFalse);
      expect(result.error, contains('Unknown scheme'));
    });

    test('a non-client URI is refused on write', () async {
      final result = await resolver.write('https://example.com/a', 'x');
      expect(result.success, isFalse);
      expect(result.error, contains('Invalid client resource URI'));
    });
  });
}
