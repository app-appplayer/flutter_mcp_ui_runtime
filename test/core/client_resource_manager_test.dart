// `client_resource_manager.dart` had 0 of 258 lines covered — the whole
// `client://` surface: URI parsing, cache lifecycle, size limits, the
// transform pipeline, and the fetch strategies. Nothing here had ever run.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/core/client_resource_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/utils/mcp_logger.dart';

void main() {
  setUp(ClientResourceManager.resetInstance);

  group('ClientResourceUri.parse', () {
    test('splits scheme, type and path', () {
      final uri = ClientResourceUri.parse('client://asset/images/logo.png')!;
      expect(uri.scheme, 'client');
      expect(uri.resourceType, 'asset');
      expect(uri.path, 'images/logo.png',
          reason: 'the leading slash belongs to the URI syntax, not the path');
      expect(uri.isAsset, isTrue);
      expect(uri.toString(), 'client://asset/images/logo.png');
    });

    test('carries query parameters', () {
      final uri = ClientResourceUri.parse('client://config/theme?mode=dark')!;
      expect(uri.resourceType, 'config');
      expect(uri.queryParams['mode'], 'dark');
    });

    test('a missing scheme or type is not a resource', () {
      expect(ClientResourceUri.parse('asset/logo.png'), isNull);
      expect(ClientResourceUri.parse('client:///nohost'), isNull);
      expect(ClientResourceUri.parse(''), isNull);
    });

    test('identity is the URI string', () {
      final a = ClientResourceUri.parse('client://state/user.name')!;
      final b = ClientResourceUri.parse('client://state/user.name')!;
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.isAsset, isFalse);
    });
  });

  group('CachedResource lifecycle', () {
    ClientResourceUri uri() => ClientResourceUri.parse('client://config/a')!;

    test('only ready and stale are usable', () {
      expect(
          CachedResource(
                  resourceUri: uri(), state: ResourceLifecycleState.ready)
              .isUsable,
          isTrue);
      expect(
          CachedResource(
                  resourceUri: uri(), state: ResourceLifecycleState.stale)
              .isUsable,
          isTrue,
          reason: 'stale data is old, not absent — that is the point of '
              'stale-while-revalidate');
      expect(
          CachedResource(
                  resourceUri: uri(), state: ResourceLifecycleState.loading)
              .isUsable,
          isFalse);
    });

    test('no expiry set means it never expires', () {
      expect(CachedResource(resourceUri: uri()).isExpired, isFalse);
    });

    test('an expired ready entry becomes stale, and stays stale', () {
      final entry = CachedResource(
        resourceUri: uri(),
        state: ResourceLifecycleState.ready,
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      );
      expect(entry.isExpired, isTrue);
      entry.checkExpiration();
      expect(entry.state, ResourceLifecycleState.stale);
      entry.checkExpiration();
      expect(entry.state, ResourceLifecycleState.stale);
    });

    test('a loading entry is not promoted by expiry', () {
      final entry = CachedResource(
        resourceUri: uri(),
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      );
      entry.checkExpiration();
      expect(entry.state, ResourceLifecycleState.loading);
    });
  });

  group('ResourceSizeLimits', () {
    ClientResourceUri u(String s) => ClientResourceUri.parse(s)!;

    test('the limit follows the resource type, then the extension', () {
      expect(ResourceSizeLimits.limitFor(u('client://temp/big.bin')),
          ResourceSizeLimits.tempFile);
      expect(ResourceSizeLimits.limitFor(u('client://cache/entry')),
          ResourceSizeLimits.cacheEntry);
      expect(ResourceSizeLimits.limitFor(u('client://asset/photo.png')),
          ResourceSizeLimits.binaryFile);
      expect(ResourceSizeLimits.limitFor(u('client://asset/readme.txt')),
          ResourceSizeLimits.textFile);
    });

    test('data under the limit validates', () {
      expect(ResourceSizeLimits.validate(u('client://asset/a.txt'), 'small'),
          isNull);
    });

    test('data over the limit is named, with both sizes', () {
      final oversized = 'x' * (ResourceSizeLimits.textFile + 1);
      final message =
          ResourceSizeLimits.validate(u('client://asset/a.txt'), oversized);
      expect(message, isNotNull);
      expect(message, contains('exceeds size limit'));
      expect(message, contains('client://asset/a.txt'));
    });

    test('an unmeasurable value is not rejected on a guess', () {
      expect(
          ResourceSizeLimits.validate(
              u('client://config/a'), <String, dynamic>{'k': 'v'}),
          isNull);
    });
  });

  group('TransformationEngine', () {
    final engine = TransformationEngine();

    test('parse json produces structured data', () {
      final result = engine.execute(
        '{"a": 1, "b": [2, 3]}',
        const [
          TransformStep(
              type: TransformType.parse, config: {'format': 'json'}),
        ],
      );
      expect(result, isA<Map<String, dynamic>>(),
          reason: 'a document asking for a json parse and getting its own '
              'string back has no way to tell');
      expect((result as Map)['a'], 1);
    });

    test('malformed json is returned as-is rather than thrown', () {
      final result = engine.execute(
        'not json',
        const [
          TransformStep(type: TransformType.parse, config: {'format': 'json'}),
        ],
      );
      expect(result, 'not json');
    });

    test('parse csv uses the header row as keys', () {
      final result = engine.execute(
        'name,qty\napple,3\npear,5\n',
        const [
          TransformStep(type: TransformType.parse, config: {'format': 'csv'}),
        ],
      ) as List;
      expect(result, hasLength(2));
      expect(result.first, <String, String>{'name': 'apple', 'qty': '3'});
    });

    test('csv rows shorter than the header fill with empty strings', () {
      final result = engine.execute(
        'a,b,c\n1,2\n',
        const [
          TransformStep(type: TransformType.parse, config: {'format': 'csv'}),
        ],
      ) as List;
      expect(result.first, <String, String>{'a': '1', 'b': '2', 'c': ''});
    });

    test('select walks a dot path, and stops at a non-map', () {
      const step =
          TransformStep(type: TransformType.select, config: {'path': 'a.b'});
      expect(
        engine.execute(<String, dynamic>{
          'a': <String, dynamic>{'b': 42}
        }, const [step]),
        42,
      );
      expect(
        engine.execute(<String, dynamic>{'a': 7}, const [step]),
        isNull,
        reason: 'a path that runs past a leaf resolves to nothing, not to the '
            'leaf',
      );
    });

    test('defaults fill only what the data omits', () {
      final result = engine.execute(
        <String, dynamic>{'b': 2},
        const [
          TransformStep(type: TransformType.defaults, config: {
            'value': <String, dynamic>{'a': 1, 'b': 99}
          }),
        ],
      ) as Map;
      expect(result['a'], 1);
      expect(result['b'], 2, reason: 'data wins over a default');
    });

    test('defaults supply the whole value when data is null', () {
      final result = engine.execute(
        null,
        const [
          TransformStep(
              type: TransformType.defaults, config: {'value': 'fallback'}),
        ],
      );
      expect(result, 'fallback');
    });

    test('sort orders by a field, ascending and descending', () {
      final data = <dynamic>[
        <String, dynamic>{'n': 3},
        <String, dynamic>{'n': 1},
        <String, dynamic>{'n': 2},
      ];
      final asc = engine.execute(data, const [
        TransformStep(type: TransformType.sort, config: {'by': 'n'}),
      ]) as List;
      expect(asc.map((e) => e['n']), <int>[1, 2, 3]);

      final desc = engine.execute(data, const [
        TransformStep(
            type: TransformType.sort, config: {'by': 'n', 'order': 'desc'}),
      ]) as List;
      expect(desc.map((e) => e['n']), <int>[3, 2, 1]);
      expect(data.map((e) => e['n']), <int>[3, 1, 2],
          reason: 'sorting returns a new list; mutating the caller\'s data '
              'would surprise a pipeline that reuses it');
    });

    test('rows of mixed types are ordered as text rather than throwing', () {
      // A field that is a number in some rows and a string in others is
      // ordinary — a server sending `"12"` for one record and `12` for the
      // next. Comparing them directly throws, and one bad row used to take
      // the whole fetch down.
      final data = <dynamic>[
        <String, dynamic>{'n': 3},
        <String, dynamic>{'n': '10'},
        <String, dynamic>{'n': 2},
      ];

      final sorted = engine.execute(data, const [
        TransformStep(type: TransformType.sort, config: {'by': 'n'}),
      ]) as List;

      expect(sorted.map((e) => e['n']).toList(), <dynamic>['10', 2, 3],
          reason: 'as TEXT, which is why "10" comes first — an ordering that '
              'is a little wrong beats a list that does not arrive');
    });

    test('a row missing the field sorts to one end, both ways', () {
      final data = <dynamic>[
        <String, dynamic>{'n': 2},
        <String, dynamic>{'other': true},
        <String, dynamic>{'n': 1},
      ];

      final asc = engine.execute(data, const [
        TransformStep(type: TransformType.sort, config: {'by': 'n'}),
      ]) as List;
      expect(asc.first['n'], isNull,
          reason: 'a missing field is not an empty string; comparing it as '
              'one threw next to a number');

      final desc = engine.execute(data, const [
        TransformStep(
            type: TransformType.sort, config: {'by': 'n', 'order': 'desc'}),
      ]) as List;
      expect(desc.last['n'], isNull);
    });

    test('sort without a field leaves the list alone', () {
      final data = <dynamic>[3, 1, 2];
      expect(
        engine.execute(
            data, const [TransformStep(type: TransformType.sort, config: {})]),
        data,
      );
    });

    test('steps compose in order', () {
      final result = engine.execute(
        '{"rows": [{"n": 2}, {"n": 1}]}',
        const [
          TransformStep(type: TransformType.parse, config: {'format': 'json'}),
          TransformStep(type: TransformType.select, config: {'path': 'rows'}),
          TransformStep(type: TransformType.sort, config: {'by': 'n'}),
        ],
      ) as List;
      expect(result.map((e) => e['n']), <int>[1, 2]);
    });
  });

  group('steps that cannot run say so', () {
    test('map and filter report instead of passing data through in silence',
        () {
      TransformationEngine.resetUnappliedReports();
      final logs = <String>[];
      MCPLogger.onRecord = (r) => logs.add(r.message);
      addTearDown(() => MCPLogger.onRecord = null);

      final engine = TransformationEngine();
      final data = <dynamic>[1, 2, 3];
      final result = engine.execute(data, const [
        TransformStep(type: TransformType.filter, config: {'where': 'x > 1'}),
      ]);

      expect(result, data, reason: 'the data still passes through');
      expect(logs.where((m) => m.contains('"filter" was not applied')),
          hasLength(1),
          reason: 'an unevaluated filter returns every element, which reads '
              'as a filter that matched everything');
    });
  });

  group('ClientResourceManager.fetch', () {
    test('an unparseable URI yields the fallback rather than throwing',
        () async {
      final result = await ClientResourceManager.instance.fetch(
        const ResourceFetchConfig(
          uri: 'not a uri at all',
          fallback: ResourceFallback(value: 'fallback'),
        ),
      );
      expect(result, 'fallback');
    });

    test('the fetcher is called and the value is cached', () async {
      var calls = 0;
      final manager = ClientResourceManager.instance
        ..setFetcher((uri) async {
          calls++;
          return 'value for ${uri.path}';
        });

      const config = ResourceFetchConfig(uri: 'client://config/theme');
      expect(await manager.fetch(config), 'value for theme');
      expect(await manager.fetch(config), 'value for theme');
      expect(calls, 1, reason: 'cacheFirst must not ask twice for a live '
          'entry — the cache is the whole point of the strategy');
    });

    test('forceRefresh asks again', () async {
      var calls = 0;
      final manager = ClientResourceManager.instance
        ..setFetcher((uri) async => 'v${++calls}');

      expect(
          await manager.fetch(const ResourceFetchConfig(uri: 'client://config/a')),
          'v1');
      expect(
          await manager.fetch(const ResourceFetchConfig(
              uri: 'client://config/a', forceRefresh: true)),
          'v2');
    });

    test('networkOnly never reads the cache', () async {
      var calls = 0;
      final manager = ClientResourceManager.instance
        ..setFetcher((uri) async => 'v${++calls}');

      const config = ResourceFetchConfig(
          uri: 'client://config/b', strategy: CachingStrategy.networkOnly);
      expect(await manager.fetch(config), 'v1');
      expect(await manager.fetch(config), 'v2');
    });
  });
}
