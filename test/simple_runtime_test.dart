import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/runtime_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/cache_manager.dart';

void main() {
  group('Simple Runtime Engine Tests', () {
    test('creates runtime engine', () {
      final engine = RuntimeEngine(enableDebugMode: false);
      expect(engine, isNotNull);
      expect(engine.isInitialized, isFalse);
    });

    test('initializes with definition', () async {
      final engine = RuntimeEngine(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {
          'title': 'Test Page',
        },
        'content': {
          'type': 'text',
          'content': 'Test',
        },
      };

      await engine.initialize(definition: definition);
      expect(engine.isInitialized, isTrue);
    });
  });

  group('CacheManager Basic Tests', () {
    test('creates cache manager', () {
      final cacheManager = CacheManager(enableDebugMode: false);
      expect(cacheManager, isNotNull);
    });

    test('caches and retrieves apps', () async {
      final cacheManager = CacheManager(enableDebugMode: false);
      
      final app = CachedApp(
        id: 'test_app',
        domain: 'com.test',
        version: '1.0.0',
        definition: {'test': true},
        cachedAt: DateTime.now(),
      );

      await cacheManager.cacheApp(app);
      
      final retrieved = cacheManager.getCachedApp('com.test', 'test_app');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, 'test_app');
    });

    test('cache stats work', () {
      final cacheManager = CacheManager(enableDebugMode: false);
      final stats = cacheManager.getStats();
      
      expect(stats.appCount, 0);
      expect(stats.stateCount, 0);
      expect(stats.resourceCount, 0);
    });
  });
}