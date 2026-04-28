import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/client_resources/client_resource_resolver.dart';

void main() {
  group('ResourceCacheManager Tests', () {
    late ResourceCacheManager cacheManager;

    setUp(() {
      cacheManager = ResourceCacheManager();
    });

    ResourceResult makeSuccessResult(String content) {
      return ResourceResult.success(
        content: content,
        path: '/test',
        type: 'file',
      );
    }

    group('TC-029: network-first strategy', () {
      test('TC-029 Normal: network available - fetch from source', () async {
        final result = await cacheManager.resolveWithCache(
          'client://file/test.txt',
          'networkFirst',
          () async => makeSuccessResult('from network'),
        );
        expect(result.success, true);
        expect(result.content, 'from network');
      });

      test('TC-029 Normal: network fails - fall back to cache', () async {
        // First populate cache
        await cacheManager.resolveWithCache(
          'client://file/test.txt',
          'networkFirst',
          () async => makeSuccessResult('cached content'),
        );

        // Now network fails
        final result = await cacheManager.resolveWithCache(
          'client://file/test.txt',
          'networkFirst',
          () async => throw Exception('Network error'),
        );
        expect(result.success, true);
        expect(result.content, 'cached content');
      });

      test('TC-029 Boundary: cache empty and network fails', () async {
        expect(
          () => cacheManager.resolveWithCache(
            'client://file/test.txt',
            'networkFirst',
            () async => throw Exception('Network error'),
          ),
          throwsException,
        );
      });
    });

    group('TC-030: cache-first strategy', () {
      test('TC-030 Normal: cache available - use cached data', () async {
        // Populate cache first using networkFirst
        await cacheManager.resolveWithCache(
          'client://file/test.txt',
          'networkFirst',
          () async => makeSuccessResult('cached'),
        );

        // Now use cache-first; fetcher should not be called
        int fetcherCalled = 0;
        final result = await cacheManager.resolveWithCache(
          'client://file/test.txt',
          'cacheFirst',
          () async {
            fetcherCalled++;
            return makeSuccessResult('from network');
          },
        );
        expect(result.content, 'cached');
        expect(fetcherCalled, 0);
      });

      test('TC-030 Normal: cache missing - fetch from source', () async {
        final result = await cacheManager.resolveWithCache(
          'client://file/new.txt',
          'cacheFirst',
          () async => makeSuccessResult('fetched'),
        );
        expect(result.content, 'fetched');
      });
    });

    group('TC-031: stale-while-revalidate strategy', () {
      test('TC-031 Normal: cached data returned immediately', () async {
        // Populate cache
        await cacheManager.resolveWithCache(
          'client://file/test.txt',
          'networkFirst',
          () async => makeSuccessResult('old data'),
        );

        // stale-while-revalidate returns cached data immediately
        final result = await cacheManager.resolveWithCache(
          'client://file/test.txt',
          'staleWhileRevalidate',
          () async => makeSuccessResult('new data'),
        );
        expect(result.content, 'old data');
      });

      test('TC-031 Boundary: no cache - behaves like network-first', () async {
        final result = await cacheManager.resolveWithCache(
          'client://file/new.txt',
          'staleWhileRevalidate',
          () async => makeSuccessResult('fetched'),
        );
        expect(result.content, 'fetched');
      });
    });

    group('TC-032: network-only strategy', () {
      test('TC-032 Normal: always fetches from source', () async {
        final result = await cacheManager.resolveWithCache(
          'client://file/test.txt',
          'networkOnly',
          () async => makeSuccessResult('always network'),
        );
        expect(result.content, 'always network');
      });
    });

    group('TC-033: cache-only strategy', () {
      test('TC-033 Normal: returns cached data', () async {
        // Populate cache
        await cacheManager.resolveWithCache(
          'client://file/test.txt',
          'networkFirst',
          () async => makeSuccessResult('cached'),
        );

        final result = await cacheManager.resolveWithCache(
          'client://file/test.txt',
          'cacheOnly',
          () async => makeSuccessResult('should not use'),
        );
        expect(result.content, 'cached');
      });

      test('TC-033 Error: cache missing - error returned', () async {
        final result = await cacheManager.resolveWithCache(
          'client://file/missing.txt',
          'cacheOnly',
          () async => makeSuccessResult('should not use'),
        );
        expect(result.success, false);
        expect(result.error, contains('not in cache'));
      });
    });

    group('TC-034: Cache configuration', () {
      test('TC-034 Normal: kebab-case strategy names normalized', () async {
        final result = await cacheManager.resolveWithCache(
          'client://file/test.txt',
          'cache-first',
          () async => makeSuccessResult('data'),
        );
        expect(result.success, true);
      });

      test('TC-034 Normal: network-first kebab-case', () async {
        final result = await cacheManager.resolveWithCache(
          'client://file/test.txt',
          'network-first',
          () async => makeSuccessResult('data'),
        );
        expect(result.success, true);
      });

      test('TC-034 Normal: stale-while-revalidate kebab-case', () async {
        final result = await cacheManager.resolveWithCache(
          'client://file/test.txt',
          'stale-while-revalidate',
          () async => makeSuccessResult('data'),
        );
        expect(result.success, true);
      });
    });

    group('Cache management', () {
      test('clear removes all entries', () async {
        await cacheManager.resolveWithCache(
          'client://file/test.txt',
          'cacheFirst',
          () async => makeSuccessResult('data'),
        );
        cacheManager.clear();

        final result = await cacheManager.resolveWithCache(
          'client://file/test.txt',
          'cacheOnly',
          () async => makeSuccessResult('unused'),
        );
        expect(result.success, false);
      });

      test('remove removes a specific entry', () async {
        await cacheManager.resolveWithCache(
          'client://file/test.txt',
          'cacheFirst',
          () async => makeSuccessResult('data'),
        );
        cacheManager.remove('client://file/test.txt');

        final result = await cacheManager.resolveWithCache(
          'client://file/test.txt',
          'cacheOnly',
          () async => makeSuccessResult('unused'),
        );
        expect(result.success, false);
      });
    });
  });

  group('ResolverCachedEntry Tests', () {
    test('isExpired returns false for fresh entry', () {
      final entry = ResolverCachedEntry(
        content: 'test',
        path: '/test',
        type: 'file',
        cachedAt: DateTime.now(),
        ttl: const Duration(minutes: 5),
      );
      expect(entry.isExpired, false);
    });

    test('isExpired returns true for old entry', () {
      final entry = ResolverCachedEntry(
        content: 'test',
        path: '/test',
        type: 'file',
        cachedAt: DateTime.now().subtract(const Duration(minutes: 10)),
        ttl: const Duration(minutes: 5),
      );
      expect(entry.isExpired, true);
    });
  });
}
