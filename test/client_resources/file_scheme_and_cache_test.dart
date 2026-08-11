// `client://file`, `client://cache`, `client://asset`, and the binary path.
//
// The workspace and temp schemes already had a round-trip test; the file
// scheme — the one that can read anything the process can reach — did not, and
// neither did the binary branch, the size limits, or the symlink checks. Those
// checks are the difference between a document reading its own data file and a
// document reading `~/.ssh/id_rsa` through a link it planted, so leaving them
// unexecuted was the least defensible gap in this package.
//
// Real files on disk throughout: a fake filesystem cannot have a symlink that
// escapes, which is the thing being tested.

@TestOn('mac-os || linux')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_ui_runtime/src/client_resources/client_resource_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late ClientResourceResolver resolver;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    root = await Directory.systemTemp.createTemp('mcp_file_');
    resolver = ClientResourceResolver()..setWorkingDirectory(root.path);
    await resolver.init();
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  /// `client://file` + an ABSOLUTE path.
  ///
  /// Worth spelling out once: the parser takes everything after the first `/`
  /// as the path, so `client://file/etc/hosts` asks for `etc/hosts` — relative
  /// to the process working directory, not the root. An absolute path is
  /// written with the doubled slash, `client://file//etc/hosts`, which
  /// normalises back to `/etc/hosts`. A document that writes the single-slash
  /// form for an absolute path silently reads somewhere else; see the pair of
  /// tests at the end of the first group.
  String uriFor(String absolutePath) => 'client://file/$absolutePath';

  group('client://file — reading text', () {
    test('a file reads back with its mime type', () async {
      final file = File('${root.path}/notes.txt')..writeAsStringSync('hello');

      final result = await resolver.resolve(uriFor(file.path));

      expect(result.success, isTrue, reason: result.error);
      expect(result.content, 'hello');
      expect(result.type, 'file');
      expect(result.mimeType, 'text/plain');
      expect(result.encoding, isNull,
          reason: 'text is returned as text; an encoding of base64 here would '
              'make every consumer decode a string that was never encoded');
    });

    test('the mime type follows the extension', () async {
      File('${root.path}/data.json').writeAsStringSync('{}');
      final result = await resolver.resolve(uriFor('${root.path}/data.json'));
      expect(result.mimeType, 'application/json');
    });

    test('a file that is not there is reported with its path', () async {
      final result = await resolver.resolve(uriFor('${root.path}/absent.txt'));
      expect(result.success, isFalse);
      expect(result.error, contains('absent.txt'));
    });

    test('a single-slash path is relative to the process, not the root',
        () async {
      // Pinned rather than changed: `client://file/etc/hosts` names
      // `etc/hosts`. It resolves against the process working directory, so on
      // a normal host it simply is not found — which is the safe direction,
      // but it means the obvious spelling of an absolute path does not do
      // what it looks like it does.
      final result = await resolver.resolve('client://file/etc/hosts');
      expect(result.success, isFalse);
      expect(result.error, contains('etc/hosts'));
      expect(result.error, isNot(contains('/etc/hosts')),
          reason: 'the leading slash is gone — that is the whole point of '
              'this test');
    });

    test('a traversal in the path is refused before anything is opened',
        () async {
      final result = await resolver.resolve('client://file//etc/../etc/hosts');
      expect(result.success, isFalse,
          reason: 'the URI parser rejects `..` outright — a normalised path '
              'that still contained one would be a way to reach outside any '
              'later boundary check');
    });

    test('a non-client URI is refused', () async {
      final result = await resolver.resolve('https://example.com/a.txt');
      expect(result.success, isFalse);
      expect(result.error, contains('Invalid client resource URI'));
    });

    test('a scheme nobody implements is named in the error', () async {
      final result = await resolver.resolve('client://telepathy/thought');
      expect(result.success, isFalse);
      expect(result.error, contains('telepathy'));
    });
  });

  group('client://file — binary', () {
    test('a binary extension comes back base64-encoded, and decodes to the '
        'original bytes', () async {
      final bytes = List<int>.generate(512, (i) => i % 256);
      File('${root.path}/image.png').writeAsBytesSync(bytes);

      final result = await resolver.resolve(uriFor('${root.path}/image.png'));

      expect(result.success, isTrue, reason: result.error);
      expect(result.encoding, 'base64');
      expect(result.mimeType, 'image/png');
      expect(base64Decode(result.content!), bytes,
          reason: 'a document displaying this decodes it — content that does '
              'not round-trip renders as a broken image with no error');
    });

    test('a file larger than one chunk is read whole', () async {
      // The reader loops in 1 MB chunks; a bug in the loop shows up only past
      // the first chunk boundary.
      final bytes = List<int>.generate(1024 * 1024 + 4096, (i) => i % 256);
      File('${root.path}/big.png').writeAsBytesSync(bytes);

      final result = await resolver.resolve(uriFor('${root.path}/big.png'));

      expect(result.success, isTrue, reason: result.error);
      expect(base64Decode(result.content!).length, bytes.length,
          reason: 'a truncated read is silent: the image just renders wrong');
    });

    test('a text file over the text limit is refused with both numbers',
        () async {
      final big = File('${root.path}/huge.txt')
        ..writeAsStringSync('x' * (10 * 1024 * 1024 + 1));

      final result = await resolver.resolve(uriFor(big.path));

      expect(result.success, isFalse);
      expect(result.error, contains('size limit'));
      expect(result.error, contains('${big.lengthSync()}'),
          reason: 'the actual size and the limit both belong in the message, '
              'or the author cannot tell how far over they are');
    });
  });

  group('client://file — symlinks', () {
    test('a link is followed and its target is read', () async {
      final target = File('${root.path}/target.txt')
        ..writeAsStringSync('through the link');
      final link = Link('${root.path}/link.txt')..createSync(target.path);

      final result = await resolver.resolve(uriFor(link.path));

      expect(result.success, isTrue, reason: result.error);
      expect(result.content, 'through the link');
    });

    test('a dangling link is reported, not treated as empty', () async {
      Link('${root.path}/dangling.txt').createSync('${root.path}/gone.txt');

      final result =
          await resolver.resolve(uriFor('${root.path}/dangling.txt'));

      expect(result.success, isFalse);
    });
  });

  group('client://workspace — the symlink boundary', () {
    test('a link inside the workspace pointing outside it is refused',
        () async {
      // The check this exercises exists because a document can WRITE into its
      // workspace: planting a link and then reading it back would otherwise
      // turn a workspace grant into a read of any file on the machine.
      final outside = await Directory.systemTemp.createTemp('mcp_outside_');
      addTearDown(() => outside.delete(recursive: true));
      final secret = File('${outside.path}/secret.txt')
        ..writeAsStringSync('not yours');
      Link('${root.path}/innocent.txt').createSync(secret.path);

      final result = await resolver.resolve('client://workspace/innocent.txt');

      expect(result.success, isFalse,
          reason: 'the link resolves outside the workspace root, which is '
              'exactly the escape the check is there to catch');
      expect(result.content, isNot('not yours'));
    });

    test('a link inside the workspace pointing inside it is fine', () async {
      File('${root.path}/real.txt').writeAsStringSync('mine');
      Link('${root.path}/alias.txt').createSync('${root.path}/real.txt');

      final result = await resolver.resolve('client://workspace/alias.txt');

      expect(result.success, isTrue, reason: result.error);
      expect(result.content, 'mine');
    });

    test('a workspace file over the limit is refused', () async {
      File('${root.path}/huge.txt')
          .writeAsStringSync('x' * (10 * 1024 * 1024 + 1));

      final result = await resolver.resolve('client://workspace/huge.txt');

      expect(result.success, isFalse);
      expect(result.error, contains('size limit'));
    });

    test('a binary workspace file is base64-encoded too', () async {
      final bytes = List<int>.generate(64, (i) => i);
      File('${root.path}/icon.png').writeAsBytesSync(bytes);

      final result = await resolver.resolve('client://workspace/icon.png');

      expect(result.encoding, 'base64');
      expect(base64Decode(result.content!), bytes);
    });

    test('with no working directory set, the scheme says so', () async {
      final bare = ClientResourceResolver();
      await bare.init();

      final result = await bare.resolve('client://workspace/a.txt');

      expect(result.success, isFalse);
      expect(result.error, contains('Working directory'),
          reason: 'a host that forgot to set it needs to be told which piece '
              'is missing');
    });
  });

  group('client://file — writing', () {
    test('a write creates missing directories and reads back', () async {
      final path = '${root.path}/made/up/path/out.txt';

      final written = await resolver.write(uriFor(path), 'written through');
      expect(written.success, isTrue, reason: written.error);
      expect(File(path).readAsStringSync(), 'written through');

      final read = await resolver.resolve(uriFor(path));
      expect(read.content, 'written through');
    });

    test('a write overwrites rather than appending', () async {
      final path = '${root.path}/twice.txt';
      await resolver.write(uriFor(path), 'first');
      await resolver.write(uriFor(path), 'second');

      expect(File(path).readAsStringSync(), 'second');
    });

    test('a traversal is refused and nothing lands outside', () async {
      final outside = '${root.parent.path}/escaped-${root.uri.pathSegments.last}';
      addTearDown(() {
        final f = File(outside);
        if (f.existsSync()) f.deleteSync();
      });

      final result =
          await resolver.write('client://file/${root.path}/../a/../b.txt', 'x');

      expect(result.success, isFalse);
      expect(File(outside).existsSync(), isFalse);
    });
  });

  group('client://cache', () {
    test('a value round-trips through the cache', () async {
      final written = await resolver.write('client://cache/session', 'token-1');
      expect(written.success, isTrue, reason: written.error);

      final read = await resolver.resolve('client://cache/session');
      expect(read.success, isTrue);
      expect(read.content, 'token-1');
      expect(read.type, 'cache');
    });

    test('a key nobody wrote is reported as missing, by name', () async {
      final read = await resolver.resolve('client://cache/never-written');
      expect(read.success, isFalse);
      expect(read.error, contains('never-written'));
    });

    test('deleting a key removes it', () async {
      await resolver.write('client://cache/temp-key', 'value');
      expect(await resolver.deleteCache('temp-key'), isTrue);

      final read = await resolver.resolve('client://cache/temp-key');
      expect(read.success, isFalse);
    });

    test('clearing removes every cache entry and leaves other prefs alone',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'unrelated_host_setting': 'keep me',
      });
      final fresh = ClientResourceResolver();
      await fresh.init();
      await fresh.write('client://cache/a', '1');
      await fresh.write('client://cache/b', '2');

      await fresh.clearCache();

      expect((await fresh.resolve('client://cache/a')).success, isFalse);
      expect((await fresh.resolve('client://cache/b')).success, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('unrelated_host_setting'), 'keep me',
          reason: 'the cache shares a preferences store with the host — '
              'clearing it must not wipe the host\'s own keys');
    });

    test('cache works without an explicit init', () async {
      // `init()` is lazy on this path; a host that never called it should get
      // a working cache rather than a null-check failure.
      final lazy = ClientResourceResolver();
      final written = await lazy.write('client://cache/lazy', 'ok');
      expect(written.success, isTrue, reason: written.error);
      expect((await lazy.resolve('client://cache/lazy')).content, 'ok');
    });
  });

  group('client://asset', () {
    test('an asset that is not in the bundle is reported, not thrown',
        () async {
      // There is no asset bundle in a unit test, so this is the failure path —
      // which is the one worth having: it must come back as a result rather
      // than as an exception out of whatever bound to the resource.
      final result = await resolver.resolve('client://asset/logo.png');

      expect(result.success, isFalse);
      expect(result.error, contains('Failed to load asset'));
    });
  });

  group('fallback', () {
    test('a failing primary falls back to the second uri', () async {
      File('${root.path}/backup.txt').writeAsStringSync('from the fallback');

      final result = await resolver.resolve(
        uriFor('${root.path}/missing.txt'),
        fallback: uriFor('${root.path}/backup.txt'),
      );

      expect(result.success, isTrue);
      expect(result.content, 'from the fallback');
    });

    test('when both fail the PRIMARY error is reported', () async {
      final result = await resolver.resolve(
        uriFor('${root.path}/missing.txt'),
        fallback: uriFor('${root.path}/also-missing.txt'),
      );

      expect(result.success, isFalse);
      expect(result.error, contains('missing.txt'));
      expect(result.error, isNot(contains('also-missing')),
          reason: 'the author asked for the first one; naming the fallback '
              'sends them looking at the wrong path');
    });

    test('an empty fallback is ignored rather than resolved', () async {
      final result = await resolver
          .resolve(uriFor('${root.path}/missing.txt'), fallback: '');
      expect(result.success, isFalse);
    });

    test('a successful primary never consults the fallback', () async {
      File('${root.path}/primary.txt').writeAsStringSync('primary');
      File('${root.path}/fallback.txt').writeAsStringSync('fallback');

      final result = await resolver.resolve(
        uriFor('${root.path}/primary.txt'),
        fallback: uriFor('${root.path}/fallback.txt'),
      );

      expect(result.content, 'primary');
    });
  });

  group('custom providers', () {
    test('a registered scheme is dispatched to its handler with the path',
        () async {
      final asked = <String>[];
      resolver.customProviders.register(CustomResourceProvider(
        scheme: 'database',
        config: const {'table': 'users'},
        handler: (path, config) async {
          asked.add(path);
          return ResourceResult.success(
            content: 'row for $path from ${config?['table']}',
            path: path,
            type: 'database',
          );
        },
      ));

      final result = await resolver.resolve('client://database/42');

      expect(asked, ['42']);
      expect(result.content, 'row for 42 from users',
          reason: 'the static config declared with the provider has to reach '
              'the handler, or every call has to re-derive it');
    });

    test('a handler that throws is turned into a reported failure', () async {
      resolver.customProviders.register(CustomResourceProvider(
        scheme: 'flaky',
        handler: (path, config) async => throw StateError('provider broke'),
      ));

      final result = await resolver.resolve('client://flaky/thing');

      expect(result.success, isFalse);
      expect(result.error, contains('flaky'));
      expect(result.error, contains('provider broke'),
          reason: 'host code failing is a fact the document can act on; an '
              'unhandled exception out of a resource read is not');
    });

    test('unregistering puts the scheme back to unknown', () async {
      resolver.customProviders.register(CustomResourceProvider(
        scheme: 'gone',
        handler: (path, config) async =>
            ResourceResult.success(content: 'x', path: path, type: 'gone'),
      ));
      expect((await resolver.resolve('client://gone/a')).success, isTrue);

      resolver.customProviders.unregister('gone');

      final result = await resolver.resolve('client://gone/a');
      expect(result.success, isFalse);
      expect(result.error, contains('Unknown scheme'));
    });
  });
}
