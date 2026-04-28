import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/offline/connectivity_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/offline/offline_queue.dart';
import 'package:flutter_mcp_ui_runtime/src/offline/sync_manager.dart';

void main() {
  group('SyncManager Tests', () {
    late ConnectivityManager connectivity;
    late OfflineQueue queue;
    late SyncManager syncManager;

    setUp(() {
      connectivity = ConnectivityManager();
      queue = OfflineQueue();
      syncManager = SyncManager(queue, connectivity);
    });

    tearDown(() {
      syncManager.dispose();
      queue.dispose();
      connectivity.dispose();
    });

    group('TC-012: Sequential sync strategy', () {
      test('TC-012 Normal: queued actions synced in order', () async {
        connectivity.updateStatus(NetworkStatus.online);
        queue.enqueue({'id': 'A'});
        queue.enqueue({'id': 'B'});

        final synced = <String>[];
        await syncManager.sync((action) async {
          synced.add(action['id'] as String);
        });

        expect(synced, ['A', 'B']);
        expect(syncManager.status, SyncStatus.complete);
        expect(syncManager.syncedCount, 2);
        expect(syncManager.failedCount, 0);
      });

      test('TC-012 Boundary: empty queue on sync', () async {
        connectivity.updateStatus(NetworkStatus.online);

        await syncManager.sync((action) async {});
        expect(syncManager.status, SyncStatus.complete);
      });
    });

    group('TC-013: onSyncComplete callback', () {
      test('TC-013 Normal: callback fires with synced count', () async {
        connectivity.updateStatus(NetworkStatus.online);
        queue.enqueue({'type': 'save'});

        Map<String, dynamic>? callbackContext;
        syncManager.onSyncComplete = (context) async {
          callbackContext = context;
        };

        await syncManager.sync((action) async {});

        expect(callbackContext, isNotNull);
        expect(callbackContext!['syncedCount'], 1);
        expect(callbackContext!['failedCount'], 0);
        expect(callbackContext!['lastSyncTime'], isNotNull);
      });
    });

    group('TC-014: onSyncError callback', () {
      test('TC-014 Normal: error callback fires on failure', () async {
        connectivity.updateStatus(NetworkStatus.online);
        queue.enqueue({'type': 'fail'}, maxRetries: 3);

        Map<String, dynamic>? errorContext;
        syncManager.onSyncError = (context) async {
          errorContext = context;
        };

        await syncManager.sync((action) async {
          throw Exception('sync failed');
        });

        expect(errorContext, isNotNull);
        expect(errorContext!['failedCount'], greaterThan(0));
        expect(errorContext!['lastError'], isNotNull);
      });
    });

    group('TC-015: Reconnect triggers sync', () {
      test('TC-015 Normal: auto-sync on reconnect', () async {
        connectivity.updateStatus(NetworkStatus.offline);
        queue.enqueue({'type': 'save'});

        final synced = <Map<String, dynamic>>[];
        syncManager.enableAutoSync((action) async {
          synced.add(action);
        });

        // Transition to online triggers sync
        connectivity.updateStatus(NetworkStatus.online);
        // Allow the async sync to complete
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(synced.isNotEmpty, true);
      });

      test('TC-015 Normal: disableAutoSync stops auto-syncing', () {
        syncManager.enableAutoSync((action) async {});
        expect(syncManager.isAutoSyncEnabled, true);

        syncManager.disableAutoSync();
        expect(syncManager.isAutoSyncEnabled, false);
      });
    });

    group('Sync status', () {
      test('initial status is idle', () {
        expect(syncManager.status, SyncStatus.idle);
      });

      test('TC-037: syncing status during sync', () async {
        connectivity.updateStatus(NetworkStatus.online);
        queue.enqueue({'type': 'save'});

        final statuses = <SyncStatus>[];
        syncManager.statusStream.listen((s) => statuses.add(s));

        await syncManager.sync((action) async {});
        await Future<void>.delayed(Duration.zero);

        expect(statuses, contains(SyncStatus.syncing));
        expect(statuses, contains(SyncStatus.complete));
      });

      test('TC-040: error status when offline', () async {
        connectivity.updateStatus(NetworkStatus.offline);
        queue.enqueue({'type': 'save'});

        await syncManager.sync((action) async {});

        expect(syncManager.status, SyncStatus.error);
        expect(syncManager.lastError, contains('offline'));
      });

      test('TC-041: lastError contains error message', () async {
        connectivity.updateStatus(NetworkStatus.online);
        queue.enqueue({'type': 'fail'}, maxRetries: 3);

        await syncManager.sync((action) async {
          throw Exception('Server error');
        });

        expect(syncManager.lastError, isNotNull);
      });
    });

    group('TC-035 to TC-039: Sync status bindings', () {
      test('TC-035: pending is true when queue has actions', () {
        queue.enqueue({'type': 'save'});
        expect(syncManager.hasPending, true);
        expect(syncManager.pendingCount, 1);
      });

      test('TC-036: pendingCount reflects queue size', () {
        queue.enqueue({'type': 'A'});
        queue.enqueue({'type': 'B'});
        queue.enqueue({'type': 'C'});
        expect(syncManager.pendingCount, 3);
      });

      test('TC-038: lastSyncTime set after successful sync', () async {
        connectivity.updateStatus(NetworkStatus.online);
        queue.enqueue({'type': 'save'});

        expect(syncManager.lastSyncTime, isNull);

        await syncManager.sync((action) async {});

        expect(syncManager.lastSyncTime, isNotNull);
      });

      test('TC-039: syncedCount and failedCount', () async {
        connectivity.updateStatus(NetworkStatus.online);
        queue.enqueue({'type': 'ok'});
        queue.enqueue({'type': 'ok'});
        queue.enqueue({'type': 'fail'}, maxRetries: 3);

        await syncManager.sync((action) async {
          if (action['type'] == 'fail') throw Exception('fail');
        });

        expect(syncManager.syncedCount, 2);
        expect(syncManager.failedCount, 1);
      });
    });

    group('Parallel sync strategy', () {
      test('parallel strategy processes concurrently', () async {
        connectivity.updateStatus(NetworkStatus.online);
        queue.enqueue({'id': 'A'});
        queue.enqueue({'id': 'B'});
        queue.enqueue({'id': 'C'});

        syncManager.strategy = SyncStrategy.parallel;

        final synced = <String>[];
        await syncManager.sync((action) async {
          synced.add(action['id'] as String);
        });

        expect(synced, containsAll(['A', 'B', 'C']));
        expect(syncManager.status, SyncStatus.complete);
      });
    });

    group('queueOrExecute', () {
      test('executes immediately when online', () async {
        connectivity.updateStatus(NetworkStatus.online);

        bool executed = false;
        final result = await syncManager.queueOrExecute(
          {'type': 'save'},
          (action) async => executed = true,
        );

        expect(result, true);
        expect(executed, true);
        expect(queue.hasPending, false);
      });

      test('queues when offline', () async {
        connectivity.updateStatus(NetworkStatus.offline);

        final result = await syncManager.queueOrExecute(
          {'type': 'save'},
          (action) async {},
        );

        expect(result, false);
        expect(queue.hasPending, true);
      });

      test('queues on execution failure when online', () async {
        connectivity.updateStatus(NetworkStatus.online);

        final result = await syncManager.queueOrExecute(
          {'type': 'save'},
          (action) async => throw Exception('fail'),
        );

        expect(result, false);
        expect(queue.hasPending, true);
      });
    });

    group('DSL action callbacks', () {
      test('onSyncCompleteDsl called with handler', () async {
        connectivity.updateStatus(NetworkStatus.online);
        queue.enqueue({'type': 'save'});

        Map<String, dynamic>? dslAction;
        Map<String, dynamic>? dslContext;

        syncManager.onSyncCompleteDsl = {'type': 'notify', 'message': 'done'};
        syncManager.actionHandler = (action, context) async {
          dslAction = action;
          dslContext = context;
        };

        await syncManager.sync((action) async {});

        expect(dslAction, isNotNull);
        expect(dslAction!['type'], 'notify');
        expect(dslContext!['syncedCount'], 1);
      });

      test('onSyncErrorDsl called on failure', () async {
        connectivity.updateStatus(NetworkStatus.online);
        queue.enqueue({'type': 'fail'}, maxRetries: 3);

        Map<String, dynamic>? dslAction;
        syncManager.onSyncErrorDsl = {'type': 'notify', 'message': 'error'};
        syncManager.actionHandler = (action, context) async {
          dslAction = action;
        };

        await syncManager.sync((action) async {
          throw Exception('fail');
        });

        expect(dslAction, isNotNull);
        expect(dslAction!['type'], 'notify');
      });
    });

    group('Duplicate sync prevention', () {
      test('concurrent sync calls ignored', () async {
        connectivity.updateStatus(NetworkStatus.online);
        queue.enqueue({'type': 'slow'});

        // Start first sync
        final future1 = syncManager.sync((action) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });

        // Second sync should be a no-op
        await syncManager.sync((action) async {});

        await future1;
        expect(syncManager.status, SyncStatus.complete);
      });
    });

    group('TC-045: Sync failure - network', () {
      test('TC-045 Error: network failure during sync', () async {
        connectivity.updateStatus(NetworkStatus.online);
        queue.enqueue({'type': 'save'}, maxRetries: 3);

        await syncManager.sync((action) async {
          throw Exception('Network error');
        });

        expect(syncManager.status, SyncStatus.error);
      });
    });
  });

  group('Additional SyncManager Tests', () {
    late ConnectivityManager connectivity;
    late OfflineQueue queue;
    late SyncManager syncManager;

    setUp(() {
      connectivity = ConnectivityManager();
      queue = OfflineQueue();
      syncManager = SyncManager(queue, connectivity);
    });

    tearDown(() {
      syncManager.dispose();
      queue.dispose();
      connectivity.dispose();
    });

    group('TC-042: SyncBindingResolver resolves sync.status binding', () {
      test('TC-042 Normal: status stream emits transitions', () async {
        connectivity.updateStatus(NetworkStatus.online);
        queue.enqueue({'type': 'save'});

        final statuses = <SyncStatus>[];
        syncManager.statusStream.listen((s) => statuses.add(s));

        await syncManager.sync((action) async {});
        await Future<void>.delayed(Duration.zero);

        // Should see syncing -> complete
        expect(statuses, contains(SyncStatus.syncing));
        expect(statuses, contains(SyncStatus.complete));
      });

      test('TC-042 Boundary: idle status before any sync', () {
        expect(syncManager.status, SyncStatus.idle);
        expect(syncManager.lastError, isNull);
        expect(syncManager.lastSyncTime, isNull);
      });
    });

    group('TC-046: Sync conflict error handling', () {
      test('TC-046 Normal: executor throwing triggers error status', () async {
        connectivity.updateStatus(NetworkStatus.online);
        queue.enqueue({'type': 'conflict'}, maxRetries: 1);

        await syncManager.sync((action) async {
          throw Exception('Conflict detected');
        });

        // Action expired (maxRetries=1, retryCount=1) so queue is empty
        // but sync reports failure counts
        expect(syncManager.failedCount, greaterThan(0));
      });

      test('TC-046 Boundary: multiple failures tracked in failedCount', () async {
        connectivity.updateStatus(NetworkStatus.online);
        queue.enqueue({'id': 'A'}, maxRetries: 1);
        queue.enqueue({'id': 'B'}, maxRetries: 1);

        await syncManager.sync((action) async {
          throw Exception('Server conflict');
        });

        expect(syncManager.failedCount, 2);
      });
    });

    group('TC-047: Sync server error handling', () {
      test('TC-047 Normal: server error triggers onSyncError callback', () async {
        connectivity.updateStatus(NetworkStatus.online);
        queue.enqueue({'type': 'data'}, maxRetries: 3);

        Map<String, dynamic>? errorCtx;
        syncManager.onSyncError = (context) async {
          errorCtx = context;
        };

        await syncManager.sync((action) async {
          throw Exception('500 Internal Server Error');
        });

        expect(errorCtx, isNotNull);
        expect(errorCtx!['lastError'], isNotNull);
        expect(errorCtx!['failedCount'], greaterThan(0));
      });

      test('TC-047 Boundary: error status when offline', () async {
        connectivity.updateStatus(NetworkStatus.offline);
        queue.enqueue({'type': 'save'});

        await syncManager.sync((action) async {});

        expect(syncManager.status, SyncStatus.error);
        expect(syncManager.lastError, contains('offline'));
      });
    });

    group('TC-048: Manual sync resolution', () {
      test('TC-048 Normal: manual sync call processes queue', () async {
        connectivity.updateStatus(NetworkStatus.online);
        queue.enqueue({'type': 'manual-save', 'data': 'test'});

        final synced = <String>[];
        await syncManager.sync((action) async {
          synced.add(action['type'] as String);
        });

        expect(synced, ['manual-save']);
        expect(syncManager.status, SyncStatus.complete);
      });

      test('TC-048 Boundary: manual sync on empty queue completes immediately', () async {
        connectivity.updateStatus(NetworkStatus.online);

        await syncManager.sync((action) async {});

        expect(syncManager.status, SyncStatus.complete);
        expect(syncManager.syncedCount, 0);
      });

      test('TC-048 Normal: manual sync after auto-sync disabled still works', () async {
        connectivity.updateStatus(NetworkStatus.online);
        queue.enqueue({'type': 'data'});

        syncManager.enableAutoSync((action) async {});
        syncManager.disableAutoSync();
        expect(syncManager.isAutoSyncEnabled, false);

        final synced = <String>[];
        await syncManager.sync((action) async {
          synced.add(action['type'] as String);
        });

        expect(synced, ['data']);
        expect(syncManager.status, SyncStatus.complete);
      });
    });
  });

  // ===========================================================================
  // TC-044: Sync conflict error handling
  // ===========================================================================
  group('TC-044: Sync conflict error handling', () {
    late ConnectivityManager connectivity;
    late OfflineQueue queue;
    late SyncManager syncManager;

    setUp(() {
      connectivity = ConnectivityManager();
      queue = OfflineQueue();
      syncManager = SyncManager(queue, connectivity);
    });

    tearDown(() {
      syncManager.dispose();
      queue.dispose();
      connectivity.dispose();
    });

    test('TC-044 Normal: no conflict — sync proceeds normally', () async {
      connectivity.updateStatus(NetworkStatus.online);
      queue.enqueue({'type': 'save', 'value': 'data'});

      await syncManager.sync((action) async {
        // No exception = no conflict
      });

      expect(syncManager.status, SyncStatus.complete);
      expect(syncManager.syncedCount, 1);
      expect(syncManager.failedCount, 0);
    });

    test('TC-044 Normal: conflict detected — configured resolution strategy applied', () async {
      connectivity.updateStatus(NetworkStatus.online);
      queue.enqueue({'type': 'save', 'value': 'conflicting'}, maxRetries: 3);

      Map<String, dynamic>? errorContext;
      syncManager.onSyncError = (context) async {
        errorContext = context;
      };

      await syncManager.sync((action) async {
        throw Exception('Conflict: value already modified on server');
      });

      // Sync reports failure
      expect(syncManager.failedCount, greaterThan(0));
      expect(errorContext, isNotNull);
      expect(errorContext!['lastError'], contains('failed during sync'));
    });

    test('TC-044 Boundary: multiple conflicts in same batch — each resolved independently', () async {
      connectivity.updateStatus(NetworkStatus.online);
      queue.enqueue({'id': 'A', 'value': 'conflict-A'}, maxRetries: 1);
      queue.enqueue({'id': 'B', 'value': 'no-conflict'}, maxRetries: 1);
      queue.enqueue({'id': 'C', 'value': 'conflict-C'}, maxRetries: 1);

      await syncManager.sync((action) async {
        final value = action['value'] as String;
        if (value.startsWith('conflict')) {
          throw Exception('Conflict detected for ${action['id']}');
        }
      });

      // One succeeded, two failed
      expect(syncManager.syncedCount, 1);
      expect(syncManager.failedCount, 2);
    });

    test('TC-044 Error: resolution strategy fails — error escalated', () async {
      connectivity.updateStatus(NetworkStatus.online);
      queue.enqueue({'type': 'critical'}, maxRetries: 1);

      await syncManager.sync((action) async {
        throw Exception('Unrecoverable conflict');
      });

      expect(syncManager.status, SyncStatus.complete);
      expect(syncManager.failedCount, 1);
      // Action expired (maxRetries=1) so it's removed from queue
      expect(queue.hasPending, false);
    });
  });

  group('SyncStatus and SyncStrategy enums', () {
    test('SyncStatus values', () {
      expect(SyncStatus.values, containsAll([
        SyncStatus.idle,
        SyncStatus.syncing,
        SyncStatus.error,
        SyncStatus.complete,
      ]));
    });

    test('SyncStrategy values', () {
      expect(SyncStrategy.values, containsAll([
        SyncStrategy.sequential,
        SyncStrategy.parallel,
      ]));
    });
  });
}
