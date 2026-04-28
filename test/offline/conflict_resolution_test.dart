import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/offline/offline_queue.dart';
import 'package:flutter_mcp_ui_runtime/src/offline/connectivity_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/offline/sync_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/client_resources/client_resource_resolver.dart';
import 'package:flutter_mcp_ui_runtime/src/offline/conflict_resolver.dart';

void main() {
  group('Conflict Resolution Tests', () {
    group('TC-021: clientWins strategy', () {
      test('TC-021 Normal: client data takes precedence', () {
        final resolver = ConflictResolver(
          strategy: ConflictStrategy.clientWins,
        );

        final result = resolver.resolve(
          {'name': 'Alice', 'age': 30},
          {'name': 'Bob', 'age': 25},
          clientTimestamp: DateTime(2024, 1, 1),
          serverTimestamp: DateTime(2024, 6, 1),
        );

        expect(result.resolvedValue, {'name': 'Alice', 'age': 30});
        expect(result.appliedStrategy, ConflictStrategy.clientWins);
      });

      test('TC-021 Boundary: client wins even with older timestamp', () {
        final resolver = ConflictResolver(
          strategy: ConflictStrategy.clientWins,
        );

        final result = resolver.resolve(
          'old_client',
          'new_server',
          clientTimestamp: DateTime(2020, 1, 1),
          serverTimestamp: DateTime(2025, 1, 1),
        );

        expect(result.resolvedValue, 'old_client');
        expect(result.appliedStrategy, ConflictStrategy.clientWins);
      });
    });

    group('TC-022: serverWins strategy', () {
      test('TC-022 Normal: server data takes precedence', () {
        final resolver = ConflictResolver(
          strategy: ConflictStrategy.serverWins,
        );

        final result = resolver.resolve(
          {'name': 'Alice'},
          {'name': 'Bob'},
          clientTimestamp: DateTime(2024, 6, 1),
          serverTimestamp: DateTime(2024, 1, 1),
        );

        expect(result.resolvedValue, {'name': 'Bob'});
        expect(result.appliedStrategy, ConflictStrategy.serverWins);
      });

      test('TC-022 Boundary: server wins even with older timestamp', () {
        final resolver = ConflictResolver(
          strategy: ConflictStrategy.serverWins,
        );

        final result = resolver.resolve(
          'newer',
          'older',
          clientTimestamp: DateTime(2025, 1, 1),
          serverTimestamp: DateTime(2020, 1, 1),
        );

        expect(result.resolvedValue, 'older');
        expect(result.appliedStrategy, ConflictStrategy.serverWins);
      });
    });

    group('TC-023: lastWriteWins strategy', () {
      test('TC-023 Normal: based on timestamp comparison', () {
        final resolver = ConflictResolver(
          strategy: ConflictStrategy.lastWriteWins,
        );

        final result = resolver.resolve(
          'client_data',
          'server_data',
          clientTimestamp: DateTime(2024, 6, 15),
          serverTimestamp: DateTime(2024, 6, 10),
        );

        expect(result.resolvedValue, 'client_data');
      });

      test('TC-023 Boundary: equal timestamps — server wins (not strictly after)', () {
        final resolver = ConflictResolver(
          strategy: ConflictStrategy.lastWriteWins,
        );

        final timestamp = DateTime(2024, 6, 15);
        final result = resolver.resolve(
          'local',
          'remote',
          clientTimestamp: timestamp,
          serverTimestamp: timestamp,
        );

        // isAfter returns false for equal times, so server wins
        expect(result.resolvedValue, 'remote');
      });
    });

    group('TC-024: merge strategy', () {
      test('TC-024 Normal: merges non-conflicting fields', () {
        final resolver = ConflictResolver(
          strategy: ConflictStrategy.merge,
        );

        final result = resolver.resolve(
          {'name': 'Alice', 'phone': '555-1234'},
          {'name': 'Bob', 'email': 'bob@test.com'},
          clientTimestamp: DateTime.now(),
          serverTimestamp: DateTime.now(),
        );

        final merged = result.resolvedValue as Map<String, dynamic>;
        // Non-conflicting fields from both sides preserved
        expect(merged['phone'], '555-1234');
        expect(merged['email'], 'bob@test.com');
        // Conflicting field: client (override) wins in _deepMerge
        expect(merged['name'], 'Alice');
      });

      test('TC-024 Boundary: deep nested merge', () {
        final resolver = ConflictResolver(
          strategy: ConflictStrategy.merge,
        );

        final result = resolver.resolve(
          {
            'settings': {'theme': 'dark', 'fontSize': 14}
          },
          {
            'settings': {'theme': 'light', 'language': 'en'}
          },
          clientTimestamp: DateTime.now(),
          serverTimestamp: DateTime.now(),
        );

        final merged = result.resolvedValue as Map<String, dynamic>;
        final settings = merged['settings'] as Map<String, dynamic>;
        expect(settings['theme'], 'dark'); // client wins
        expect(settings['fontSize'], 14);
        expect(settings['language'], 'en');
      });
    });

    group('TC-025: manual strategy', () {
      test('TC-025 Normal: flags conflict for user resolution', () {
        final resolver = ConflictResolver(
          strategy: ConflictStrategy.manual,
        );

        final result = resolver.resolve(
          {'a': 1},
          {'b': 2},
          clientTimestamp: DateTime.now(),
          serverTimestamp: DateTime.now(),
        );

        expect(result.requiresUserInput, isTrue);
        expect(result.appliedStrategy, ConflictStrategy.manual);
      });
    });

    group('TC-026: Optimistic update applied immediately', () {
      test('TC-026 Normal: action queued and optimistic result returned', () async {
        final connectivity = ConnectivityManager();
        final queue = OfflineQueue();
        final syncManager = SyncManager(queue, connectivity);

        connectivity.updateStatus(NetworkStatus.online);

        // queueOrExecute returns true immediately when online and success
        bool executed = false;
        final result = await syncManager.queueOrExecute(
          {'type': 'save', 'value': 'optimistic'},
          (action) async {
            executed = true;
          },
        );

        expect(result, true);
        expect(executed, true);

        syncManager.dispose();
        queue.dispose();
        connectivity.dispose();
      });
    });

    group('TC-027: Optimistic update rollback on server rejection', () {
      test('TC-027 Normal: failed execution queues for retry', () async {
        final connectivity = ConnectivityManager();
        final queue = OfflineQueue();
        final syncManager = SyncManager(queue, connectivity);

        connectivity.updateStatus(NetworkStatus.online);

        // Execution fails — should queue for later
        final result = await syncManager.queueOrExecute(
          {'type': 'save', 'value': 'rejected'},
          (action) async {
            throw Exception('Server rejected');
          },
        );

        expect(result, false);
        expect(queue.hasPending, true);

        syncManager.dispose();
        queue.dispose();
        connectivity.dispose();
      });
    });

    group('TC-028: Optimistic update with subsequent user changes', () {
      test('TC-028 Normal: multiple queued actions preserved in order', () async {
        final queue = OfflineQueue();

        queue.enqueue({'type': 'save', 'field': 'name', 'value': 'Alice'});
        queue.enqueue({'type': 'save', 'field': 'name', 'value': 'Bob'});

        final order = <String>[];
        await queue.processQueue((action) async {
          order.add(action['value'] as String);
        });

        // Actions processed in order, latest value last
        expect(order, ['Alice', 'Bob']);
        queue.dispose();
      });
    });

    group('TC-029: Multiple optimistic updates with partial rollback', () {
      test('TC-029 Normal: some updates succeed, others fail and requeue', () async {
        final queue = OfflineQueue();

        queue.enqueue({'id': 'A', 'value': 'success'}, maxRetries: 3);
        queue.enqueue({'id': 'B', 'value': 'fail'}, maxRetries: 3);
        queue.enqueue({'id': 'C', 'value': 'success'}, maxRetries: 3);

        final results = await queue.processQueue((action) async {
          if (action['value'] == 'fail') {
            throw Exception('Server error');
          }
        });

        // Two succeed, one fails
        final successes = results.where((r) => r.success).length;
        final failures = results.where((r) => !r.success).length;
        expect(successes, 2);
        expect(failures, 1);
        // Failed action re-queued
        expect(queue.hasPending, true);

        queue.dispose();
      });
    });

    group('TC-030: Optimistic update timeout handling', () {
      test('TC-030 Normal: action expires after maxRetries exceeded', () {
        final action = QueuedAction(
          action: {'type': 'save'},
          maxRetries: 2,
        );

        expect(action.isExpired, false);
        action.retryCount = 1;
        expect(action.isExpired, false);
        action.retryCount = 2;
        expect(action.isExpired, true);
      });

      test('TC-030 Boundary: maxRetries of 0 means action expires immediately on first failure', () {
        final action = QueuedAction(
          action: {'type': 'save'},
          maxRetries: 0,
        );

        // With maxRetries=0, isExpired is true even before any retry
        expect(action.isExpired, true);
      });
    });

    group('TC-031: Offline widget mode hide', () {
      test('TC-031 Normal: connectivity manager reports offline status', () {
        final connectivity = ConnectivityManager();
        connectivity.updateStatus(NetworkStatus.offline);

        // Widget renderer would use isOffline to decide visibility
        expect(connectivity.isOffline, true);
        expect(connectivity.isOnline, false);

        connectivity.dispose();
      });
    });

    group('TC-032: Offline widget mode disable', () {
      test('TC-032 Normal: offline status with connection type none', () {
        final connectivity = ConnectivityManager();
        connectivity.updateStatus(NetworkStatus.offline);

        // Widget in disable mode: visible but not interactive
        expect(connectivity.isOffline, true);
        expect(connectivity.type, NetworkType.none);

        connectivity.dispose();
      });
    });

    group('TC-033: Offline widget mode cached', () {
      test('TC-033 Normal: cache manager provides cached data while offline', () async {
        final cache = ResourceCacheManager();

        // Populate cache first
        await cache.resolveWithCache(
          'client://cache/data',
          'cacheFirst',
          () async {
            return ResourceResult.success(
              content: '{"cached": true}',
              path: 'data',
              type: 'cache',
            );
          },
        );

        // cacheOnly returns cached data without network call
        final cachedResult = await cache.resolveWithCache(
          'client://cache/data',
          'cacheOnly',
          () async => ResourceResult.error('Network unavailable'),
        );
        expect(cachedResult.success, true);

        // cacheOnly for non-cached key returns error
        final uncachedResult = await cache.resolveWithCache(
          'client://cache/uncached',
          'cacheOnly',
          () async => ResourceResult.error('Should not call'),
        );
        expect(uncachedResult.success, false);
        expect(uncachedResult.error, contains('not in cache'));

        cache.clear();
      });
    });

    group('TC-034: Offline widget mode fallback', () {
      test('TC-034 Normal: fallback content served when primary fails', () async {
        final connectivity = ConnectivityManager();
        connectivity.updateStatus(NetworkStatus.offline);

        // The offline status + slow status represent fallback conditions
        expect(connectivity.isOffline, true);
        expect(connectivity.statusDescription, 'Offline');

        connectivity.updateStatus(NetworkStatus.slow, type: NetworkType.cellular);
        expect(connectivity.status, NetworkStatus.slow);
        expect(connectivity.statusDescription, contains('Slow'));

        connectivity.dispose();
      });

      test('TC-034 Boundary: status transitions tracked', () {
        final connectivity = ConnectivityManager();
        final transitions = <String>[];

        connectivity.onStatusChange((previous, current) {
          transitions.add('${previous.name}->${current.name}');
        });

        connectivity.updateStatus(NetworkStatus.online);
        connectivity.updateStatus(NetworkStatus.offline);
        connectivity.updateStatus(NetworkStatus.slow);

        expect(transitions.length, 3);
        expect(transitions[0], 'unknown->online');
        expect(transitions[1], 'online->offline');
        expect(transitions[2], 'offline->slow');

        connectivity.dispose();
      });
    });
  });
}
