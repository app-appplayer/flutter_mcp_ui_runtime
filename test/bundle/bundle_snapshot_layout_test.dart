// The SNAPSHOT layout of `BundleUiReadAdapter` — a bundle whose UI lives in
// `ui/app.json` and `ui/pages/*.json` on disk.
//
// The sibling file covers the embedded layout (UI inline in `manifest.json`).
// The snapshot path — the canonical AppPlayer shape, and the one every
// installed bundle actually uses — was uncovered: reading app.json, collecting
// the pages, merging the manifest defaults underneath, and what happens when
// one of those files is malformed.
//
// Real files through `McpBundleLoader.loadDirectory`, because the adapter's
// whole contract is "all I/O goes through mcp_bundle" and a hand-built
// in-memory bundle takes the other branch.

@TestOn('mac-os || linux')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart'
    hide PageDefinition;
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_bundle/mcp_bundle.dart';

class _Storage implements BundleStoragePort {
  final Map<String, Uint8List> assets = {};

  @override
  Future<Uint8List> readAsset(Uri uri) async {
    final key = uri.toString();
    if (assets.containsKey(key)) return assets[key]!;
    throw Exception('Asset not found: $uri');
  }

  @override
  Future<Map<String, dynamic>> readBundle(Uri uri) async => {};
  @override
  Future<void> writeBundle(Uri uri, Map<String, dynamic> data) async {}
  @override
  Future<void> writeAsset(Uri uri, Uint8List data) async {}
  @override
  Future<bool> exists(Uri uri) async => false;
  @override
  Future<void> delete(Uri uri) async {}
  @override
  Future<List<Uri>> list(Uri directoryUri) async => [];
  @override
  Stream<BundleChangeEvent>? watch(Uri uri) => null;
}

void main() {
  late Directory root;
  late BundleUiReadAdapter adapter;
  late _Storage storage;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mcp_bundle_ui_');
    storage = _Storage();
    adapter = BundleUiReadAdapter(
      assetProvider: BundleAssetProvider(storage: storage),
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  void writeJson(String relative, Object content) {
    final file = File('${root.path}/$relative')
      ..parent.createSync(recursive: true);
    file.writeAsStringSync(jsonEncode(content));
  }

  void writeRaw(String relative, String content) {
    File('${root.path}/$relative')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  /// Writes a minimal manifest and returns the loaded bundle.
  Future<McpBundle> bundle({Map<String, dynamic>? manifest}) async {
    writeJson('manifest.json', {
      'schemaVersion': '1.0.0',
      'manifest': {
        'id': 'com.example.app',
        'name': 'Snapshot App',
        'version': '2.1.0',
        ...?manifest,
      },
    });
    return McpBundleLoader.loadDirectory(root.path);
  }

  group('the snapshot layout is taken when ui/app.json exists', () {
    test('app.json becomes the application root', () async {
      writeJson('ui/app.json', {
        'type': 'application',
        'title': 'From app.json',
        'initialRoute': '/home',
        'routes': {'/home': '/pages/home'},
      });

      final result = await adapter.toDefinition(await bundle());

      expect(result.success, isTrue, reason: result.error?.message);
      expect(result.data!['title'], 'From app.json',
          reason: 'app.json wins over the manifest name — it is the document '
              'the author wrote, and the manifest is packaging metadata');
      expect(result.data!['routes'], {'/home': '/pages/home'});
    });

    test('the manifest fills only what app.json left out', () async {
      writeJson('ui/app.json', {'type': 'application'});

      final result = await adapter.toDefinition(await bundle(manifest: {
        'description': 'from the manifest',
        'category': 'productivity',
      }));

      expect(result.data!['title'], 'Snapshot App');
      expect(result.data!['version'], '2.1.0');
      expect(result.data!['id'], 'com.example.app');
      expect(result.data!['description'], 'from the manifest');
      expect(result.data!['category'], 'productivity',
          reason: 'a store listing reads these; leaving them empty because '
              'app.json did not repeat them is the whole point of the merge');
    });

    test('the listing fields the manifest carries are merged too', () async {
      writeJson('ui/app.json', {'type': 'application'});

      final result = await adapter.toDefinition(await bundle(manifest: {
        'icon': 'assets/icon.png',
        'publisher': {'name': 'Makemind', 'url': 'https://example.com'},
        'createdAt': '2026-01-01T00:00:00Z',
        'updatedAt': '2026-03-01T00:00:00Z',
        'screenshots': ['assets/one.png', 'assets/two.png'],
      }));

      expect(result.success, isTrue, reason: result.error?.message);
      expect(result.data!['icon'], 'assets/icon.png');
      expect((result.data!['publisher'] as Map)['name'], 'Makemind',
          reason: 'a store listing without a publisher is a listing nobody '
              'can attribute — and the snapshot path had never merged one');
      expect((result.data!['timestamps'] as Map)['createdAt'],
          contains('2026-01-01'));
      expect(result.data!['screenshots'],
          ['assets/one.png', 'assets/two.png']);
    });

    test('app.json still wins over every one of them', () async {
      writeJson('ui/app.json', {
        'type': 'application',
        'icon': 'assets/mine.png',
        'publisher': {'name': 'The author'},
      });

      final result = await adapter.toDefinition(await bundle(manifest: {
        'icon': 'assets/packaged.png',
        'publisher': {'name': 'The packager'},
      }));

      expect(result.data!['icon'], 'assets/mine.png');
      expect((result.data!['publisher'] as Map)['name'], 'The author',
          reason: 'the merge fills gaps; overwriting what the document says '
              'would make app.json advisory');
    });

    test('every ui/pages/*.json is collected under its file stem', () async {
      writeJson('ui/app.json', {'type': 'application'});
      writeJson('ui/pages/home.json', {
        'type': 'page',
        'content': {'type': 'text', 'content': 'home'},
      });
      writeJson('ui/pages/settings.json', {
        'type': 'page',
        'content': {'type': 'text', 'content': 'settings'},
      });

      final result = await adapter.toDefinition(await bundle());
      final pages = result.data!['pages'] as Map<String, dynamic>;

      expect(pages.keys, unorderedEquals(['home', 'settings']),
          reason: 'the page id is the file stem — a route pointing at '
              '/pages/settings finds nothing if the key is the whole path');
      expect((pages['home'] as Map)['content'], isNotNull);
    });

    test('json files outside pages/ are not mistaken for pages', () async {
      writeJson('ui/app.json', {'type': 'application'});
      writeJson('ui/theme.json', {'colors': <String, dynamic>{}});
      writeJson('ui/pages/home.json', {'type': 'page'});

      final result = await adapter.toDefinition(await bundle());
      final pages = result.data!['pages'] as Map<String, dynamic>;

      expect(pages.keys, ['home']);
    });

    test('a bundle with app.json and no pages emits no pages key', () async {
      writeJson('ui/app.json', {'type': 'application'});

      final result = await adapter.toDefinition(await bundle());
      expect(result.data!.containsKey('pages'), isFalse,
          reason: 'an empty pages map would read as "this app has zero '
              'pages", which is a different claim from "the pages are '
              'declared inline"');
    });
  });

  group('malformed files', () {
    test('an app.json that is not an object fails the whole read', () async {
      writeJson('ui/app.json', [1, 2, 3]);

      final result = await adapter.toDefinition(await bundle());

      expect(result.success, isFalse);
      expect(result.error!.code, 'INVALID_APP_JSON',
          reason: 'the application root is not optional — carrying on with '
              'manifest defaults would show an app the author never wrote');
    });

    test('an app.json that is not json at all fails with its path', () async {
      writeRaw('ui/app.json', '{ this is not json');

      final result = await adapter.toDefinition(await bundle());

      expect(result.success, isFalse);
      expect(result.error!.code, 'INVALID_APP_JSON');
      expect(result.error!.path, 'ui/app.json');
    });

    test('a bad page is a WARNING — the rest of the app still opens',
        () async {
      writeJson('ui/app.json', {'type': 'application'});
      writeJson('ui/pages/good.json', {'type': 'page'});
      writeRaw('ui/pages/broken.json', '{ nope');

      final result = await adapter.toDefinition(await bundle());

      expect(result.success, isTrue,
          reason: 'one unreadable page must not take the whole application '
              'down — the other pages are still navigable');
      expect(result.warnings!.single.code, 'INVALID_PAGE_JSON');
      expect(result.warnings!.single.path, 'ui/pages/broken.json');
      expect((result.data!['pages'] as Map).keys, ['good']);
    });

    test('a page whose json is not an object is warned about too', () async {
      writeJson('ui/app.json', {'type': 'application'});
      writeJson('ui/pages/list.json', [1, 2]);

      final result = await adapter.toDefinition(await bundle());

      expect(result.success, isTrue);
      expect(result.warnings!.single.code, 'INVALID_PAGE_JSON');
      expect(result.data!.containsKey('pages'), isFalse);
    });
  });

  group('bundle:// metadata in the snapshot path', () {
    test('an icon uri is resolved through the asset provider', () async {
      storage.assets['bundle://com.example.app/assets/icon.png'] =
          Uint8List.fromList([137, 80, 78, 71]);
      writeJson('ui/app.json', {'type': 'application'});

      final result = await adapter.toDefinition(await bundle(manifest: {
        'icon': 'bundle://com.example.app/assets/icon.png',
      }));

      expect(result.success, isTrue);
      expect(result.data!['icon'], isNotNull);
      expect(result.data!['icon'].toString(), startsWith('data:'),
          reason: 'the runtime cannot open a bundle:// uri — resolving it to '
              'a data uri is what makes the icon drawable');
    });

    test('an icon that is not in the bundle is a warning, not a failure',
        () async {
      writeJson('ui/app.json', {'type': 'application'});

      final result = await adapter.toDefinition(await bundle(manifest: {
        'icon': 'bundle://com.example.app/assets/missing.png',
      }));

      expect(result.success, isTrue,
          reason: 'an app with no icon still runs; refusing to open it over a '
              'missing image would be worse than the blank square');
      expect(result.warnings, isNotNull);
    });
  });

  group('a bundle that cannot be read at all', () {
    test('an empty manifest id, name or version is refused', () async {
      // Built in memory rather than loaded: the LOADER refuses this manifest
      // outright, so the adapter's own guard is only reachable for a bundle
      // handed to it programmatically — which is exactly the case the guard
      // is there for.
      final bare = McpBundle(
        manifest: BundleManifest(id: '', name: '', version: ''),
      );

      expect((await adapter.toDefinition(bare)).error!.code,
          'INVALID_MANIFEST');
      expect((await adapter.toAppInfo(bare)).error!.code, 'INVALID_MANIFEST',
          reason: 'a listing built from a nameless bundle would show a blank '
              'row in the store');
    });

    test('toAppInfo answers the store fields without touching ui/', () async {
      writeRaw('ui/app.json', 'not json at all');

      final result = await adapter.toAppInfo(await bundle(manifest: {
        'description': 'A test app',
        'category': 'productivity',
      }));

      expect(result.success, isTrue,
          reason: 'a listing has to render for a bundle whose UI is broken — '
              'that is how a user finds out it needs updating');
      expect(result.data!['id'], 'com.example.app');
      expect(result.data!['name'], 'Snapshot App');
      expect(result.data!['version'], '2.1.0');
      expect(result.data!['description'], 'A test app');
      expect(result.data!['category'], 'productivity');
    });
  });
}
