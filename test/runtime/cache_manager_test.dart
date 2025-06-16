import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/cache_manager.dart';

void main() {
  group('CacheManager Tests', () {
    late CacheManager cacheManager;

    setUp(() {
      cacheManager = CacheManager(enableDebugMode: false);
    });

    test('caches and retrieves app successfully', () async {
      final definition = {
        'mcpRuntime': {
          'version': '1.0',
          'runtime': {
            'id': 'test_app',
            'domain': 'com.test.app',
            'version': '1.0.0',
          },
          'ui': {},
        },
      };

      final cachedApp = CachedApp.fromDefinition(definition);
      await cacheManager.cacheApp(cachedApp);

      final retrieved = cacheManager.getCachedApp('com.test.app', 'test_app');
      
      expect(retrieved, isNotNull);
      expect(retrieved!.id, 'test_app');
      expect(retrieved.domain, 'com.test.app');
      expect(retrieved.version, '1.0.0');
    });

    test('returns null for non-existent app', () {
      final retrieved = cacheManager.getCachedApp('com.test.missing', 'missing_app');
      expect(retrieved, isNull);
    });

    test('detects version updates correctly', () async {
      final definition = {
        'mcpRuntime': {
          'version': '1.0',
          'runtime': {
            'id': 'version_test',
            'domain': 'com.test.version',
            'version': '1.0.0',
          },
          'ui': {},
        },
      };

      final cachedApp = CachedApp.fromDefinition(definition);
      await cacheManager.cacheApp(cachedApp);

      // Same version - no update
      expect(
        cacheManager.isUpdateAvailable('com.test.version', 'version_test', '1.0.0'),
        isFalse,
      );

      // Newer version available
      expect(
        cacheManager.isUpdateAvailable('com.test.version', 'version_test', '0.9.0'),
        isTrue,
      );

      // Older version - no update
      expect(
        cacheManager.isUpdateAvailable('com.test.version', 'version_test', '1.1.0'),
        isFalse,
      );
    });

    test('caches and retrieves state successfully', () async {
      final state = {
        'counter': 42,
        'user': {'name': 'Test User'},
        'items': ['item1', 'item2'],
      };

      await cacheManager.cacheState('app:test', state);
      
      final retrieved = cacheManager.getCachedState('app:test');
      
      expect(retrieved, isNotNull);
      expect(retrieved!['counter'], 42);
      expect(retrieved['user']['name'], 'Test User');
      expect(retrieved['items'], ['item1', 'item2']);
    });

    test('caches and retrieves resources successfully', () async {
      final resource = {
        'data': 'test data',
        'timestamp': DateTime.now().toIso8601String(),
      };

      await cacheManager.cacheResource('resource:test', resource);
      
      final retrieved = cacheManager.getCachedResource('resource:test');
      
      expect(retrieved, isNotNull);
      expect(retrieved!['data'], 'test data');
      expect(retrieved['timestamp'], resource['timestamp']);
    });

    test('clears all caches', () async {
      // Add some data
      final definition = {
        'mcpRuntime': {
          'version': '1.0',
          'runtime': {
            'id': 'clear_test',
            'domain': 'com.test.clear',
            'version': '1.0.0',
          },
          'ui': {},
        },
      };

      await cacheManager.cacheApp(CachedApp.fromDefinition(definition));
      await cacheManager.cacheState('app:clear', {'test': true});
      await cacheManager.cacheResource('resource:clear', {'data': 'test'});

      // Verify data exists
      expect(cacheManager.getCachedApp('com.test.clear', 'clear_test'), isNotNull);
      expect(cacheManager.getCachedState('app:clear'), isNotNull);
      expect(cacheManager.getCachedResource('resource:clear'), isNotNull);

      // Clear all
      await cacheManager.clearAll();

      // Verify all cleared
      expect(cacheManager.getCachedApp('com.test.clear', 'clear_test'), isNull);
      expect(cacheManager.getCachedState('app:clear'), isNull);
      expect(cacheManager.getCachedResource('resource:clear'), isNull);
    });

    test('clears specific app cache', () async {
      // Add multiple apps
      final app1Definition = {
        'mcpRuntime': {
          'version': '1.0',
          'runtime': {
            'id': 'app1',
            'domain': 'com.test.app1',
            'version': '1.0.0',
          },
          'ui': {},
        },
      };

      final app2Definition = {
        'mcpRuntime': {
          'version': '1.0',
          'runtime': {
            'id': 'app2',
            'domain': 'com.test.app2',
            'version': '1.0.0',
          },
          'ui': {},
        },
      };

      await cacheManager.cacheApp(CachedApp.fromDefinition(app1Definition));
      await cacheManager.cacheApp(CachedApp.fromDefinition(app2Definition));
      await cacheManager.cacheState('com.test.app1:app1', {'test': 1});
      await cacheManager.cacheState('com.test.app2:app2', {'test': 2});

      // Clear only app1
      await cacheManager.clearApp('com.test.app1', 'app1');

      // Verify app1 cleared, app2 remains
      expect(cacheManager.getCachedApp('com.test.app1', 'app1'), isNull);
      expect(cacheManager.getCachedState('com.test.app1:app1'), isNull);
      expect(cacheManager.getCachedApp('com.test.app2', 'app2'), isNotNull);
      expect(cacheManager.getCachedState('com.test.app2:app2'), isNotNull);
    });

    test('gets cache statistics', () async {
      // Add some data
      final definition = {
        'mcpRuntime': {
          'version': '1.0',
          'runtime': {
            'id': 'stats_test',
            'domain': 'com.test.stats',
            'version': '1.0.0',
          },
          'ui': {},
        },
      };

      await cacheManager.cacheApp(CachedApp.fromDefinition(definition));
      await cacheManager.cacheState('app:stats', {'counter': 42});
      await cacheManager.cacheResource('resource:stats', {'data': 'test'});

      final stats = cacheManager.getStats();

      expect(stats.appCount, 1);
      expect(stats.stateCount, 1);
      expect(stats.resourceCount, 1);
      expect(stats.totalSize, greaterThan(0));
    });

    test('respects cache expiry', () async {
      // Create app with expired cache
      final definition = {
        'mcpRuntime': {
          'version': '1.0',
          'runtime': {
            'id': 'expired_app',
            'domain': 'com.test.expired',
            'version': '1.0.0',
          },
          'ui': {},
        },
      };

      final expiredApp = CachedApp(
        id: 'expired_app',
        domain: 'com.test.expired',
        version: '1.0.0',
        definition: definition,
        cachedAt: DateTime.now().subtract(const Duration(days: 2)),
        expiresAt: DateTime.now().subtract(const Duration(days: 1)), // Expired yesterday
      );

      await cacheManager.cacheApp(expiredApp);

      // Should return null because it's expired
      final retrieved = cacheManager.getCachedApp('com.test.expired', 'expired_app');
      expect(retrieved, isNull);
    });

    test('respects cache max age policy', () async {
      // Set a default policy with short max age
      cacheManager.defaultPolicy = const CachePolicy(
        enabled: true,
        maxAge: Duration(seconds: 1),
      );

      final definition = {
        'mcpRuntime': {
          'version': '1.0',
          'runtime': {
            'id': 'maxage_app',
            'domain': 'com.test.maxage',
            'version': '1.0.0',
          },
          'ui': {},
        },
      };

      final app = CachedApp(
        id: 'maxage_app',
        domain: 'com.test.maxage',
        version: '1.0.0',
        definition: definition,
        cachedAt: DateTime.now().subtract(const Duration(seconds: 2)), // Cached 2 seconds ago
      );

      await cacheManager.cacheApp(app);

      // Should return null because it exceeds max age
      final retrieved = cacheManager.getCachedApp('com.test.maxage', 'maxage_app');
      expect(retrieved, isNull);
    });
  });

  group('CachePolicy Tests', () {
    test('creates from JSON correctly', () {
      final json = {
        'enabled': true,
        'maxAge': 3600,
        'staleWhileRevalidate': true,
        'cacheState': false,
        'cacheResources': true,
        'offlineMode': 'full',
      };

      final policy = CachePolicy.fromJson(json);

      expect(policy.enabled, isTrue);
      expect(policy.maxAge, const Duration(seconds: 3600));
      expect(policy.staleWhileRevalidate, isTrue);
      expect(policy.cacheState, isFalse);
      expect(policy.cacheResources, isTrue);
      expect(policy.offlineMode, OfflineMode.full);
    });

    test('converts to JSON correctly', () {
      const policy = CachePolicy(
        enabled: true,
        maxAge: Duration(hours: 1),
        staleWhileRevalidate: true,
        cacheState: false,
        cacheResources: true,
        offlineMode: OfflineMode.partial,
      );

      final json = policy.toJson();

      expect(json['enabled'], isTrue);
      expect(json['maxAge'], 3600);
      expect(json['staleWhileRevalidate'], isTrue);
      expect(json['cacheState'], isFalse);
      expect(json['cacheResources'], isTrue);
      expect(json['offlineMode'], 'partial');
    });

    test('handles missing fields with defaults', () {
      final policy = CachePolicy.fromJson({});

      expect(policy.enabled, isTrue);
      expect(policy.maxAge, isNull);
      expect(policy.staleWhileRevalidate, isFalse);
      expect(policy.cacheState, isTrue);
      expect(policy.cacheResources, isTrue);
      expect(policy.offlineMode, OfflineMode.partial);
    });
  });

  group('UpdatePolicy Tests', () {
    test('creates from JSON correctly', () {
      final json = {
        'checkOnStartup': false,
        'checkInterval': 43200,
        'autoUpdate': true,
        'requireRestart': false,
      };

      final policy = UpdatePolicy.fromJson(json);

      expect(policy.checkOnStartup, isFalse);
      expect(policy.checkInterval, const Duration(seconds: 43200));
      expect(policy.autoUpdate, isTrue);
      expect(policy.requireRestart, isFalse);
    });

    test('converts to JSON correctly', () {
      const policy = UpdatePolicy(
        checkOnStartup: false,
        checkInterval: Duration(hours: 12),
        autoUpdate: true,
        requireRestart: false,
      );

      final json = policy.toJson();

      expect(json['checkOnStartup'], isFalse);
      expect(json['checkInterval'], 43200);
      expect(json['autoUpdate'], isTrue);
      expect(json['requireRestart'], isFalse);
    });
  });

  group('CachedApp Tests', () {
    test('creates from definition correctly', () {
      final definition = {
        'mcpRuntime': {
          'version': '1.0',
          'runtime': {
            'id': 'test_app',
            'domain': 'com.example.test',
            'version': '2.1.0',
            'cachePolicy': {
              'enabled': true,
              'maxAge': 7200,
            },
          },
          'ui': {},
        },
      };

      final cachedApp = CachedApp.fromDefinition(definition);

      expect(cachedApp.id, 'test_app');
      expect(cachedApp.domain, 'com.example.test');
      expect(cachedApp.version, '2.1.0');
      expect(cachedApp.definition, definition);
      expect(cachedApp.cachedAt.difference(DateTime.now()).inSeconds, lessThan(1));
      expect(cachedApp.cachePolicy, isNotNull);
      expect(cachedApp.cachePolicy!.enabled, isTrue);
      expect(cachedApp.cachePolicy!.maxAge, const Duration(seconds: 7200));
    });
  });
}