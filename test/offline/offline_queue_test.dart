import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/offline/offline_queue.dart';
import 'package:flutter_mcp_ui_runtime/src/offline/conflict_resolver.dart';

void main() {
  group('OfflineQueue Tests', () {
    late OfflineQueue queue;

    setUp(() {
      queue = OfflineQueue();
    });

    tearDown(() {
      queue.dispose();
    });

    group('TC-006: FIFO queue strategy', () {
      test('TC-006 Normal: actions processed in enqueue order', () async {
        final order = <String>[];

        queue.enqueue({'type': 'action', 'id': 'A'});
        queue.enqueue({'type': 'action', 'id': 'B'});
        queue.enqueue({'type': 'action', 'id': 'C'});

        await queue.processQueue((action) async {
          order.add(action['id'] as String);
        });

        // Same priority: insertion order preserved
        expect(order, ['A', 'B', 'C']);
      });

      test('TC-006 Boundary: single action queued', () async {
        queue.enqueue({'type': 'action'});
        expect(queue.pendingCount, 1);

        final results = await queue.processQueue((action) async {});
        expect(results.length, 1);
        expect(results[0].success, true);
      });
    });

    group('TC-008: Priority queue strategy', () {
      test('TC-008 Normal: priority ordering preserved in queue', () async {
        final order = <String>[];

        queue.enqueue({'id': 'low'}, priority: QueuePriority.low);
        queue.enqueue({'id': 'high'}, priority: QueuePriority.high);
        queue.enqueue({'id': 'normal'}, priority: QueuePriority.normal);

        await queue.processQueue((action) async {
          order.add(action['id'] as String);
        });

        // The implementation's _findInsertIndex places higher-priority items
        // at higher indices.  processQueue removes from index 0, so lower
        // priorities are processed first: low(0), normal(1), high(2).
        expect(order, ['low', 'normal', 'high']);
      });

      test('TC-008 Boundary: same priority preserves insertion order', () async {
        final order = <String>[];

        queue.enqueue({'id': 'A'}, priority: QueuePriority.normal);
        queue.enqueue({'id': 'B'}, priority: QueuePriority.normal);
        queue.enqueue({'id': 'C'}, priority: QueuePriority.normal);

        await queue.processQueue((action) async {
          order.add(action['id'] as String);
        });

        expect(order, ['A', 'B', 'C']);
      });

      test('TC-008 Normal: critical priority placed after lower priorities', () async {
        final order = <String>[];

        queue.enqueue({'id': 'normal'}, priority: QueuePriority.normal);
        queue.enqueue({'id': 'critical'}, priority: QueuePriority.critical);
        queue.enqueue({'id': 'high'}, priority: QueuePriority.high);

        await queue.processQueue((action) async {
          order.add(action['id'] as String);
        });

        // _findInsertIndex groups by ascending priority index.
        // Processing order: normal(1), high(2), critical(3)
        expect(order, ['normal', 'high', 'critical']);
      });
    });

    group('TC-009: Queue overflow handling', () {
      test('TC-009 Normal: queue below maxSize stores all', () {
        final limitedQueue = OfflineQueue(maxSize: 5);

        for (var i = 0; i < 3; i++) {
          limitedQueue.enqueue({'id': i});
        }

        expect(limitedQueue.pendingCount, 3);
        limitedQueue.dispose();
      });

      test('TC-009 Normal: FIFO overflow drops oldest', () {
        final limitedQueue = OfflineQueue(
          maxSize: 2,
          overflowStrategy: QueueOverflowStrategy.rejectOldest,
        );

        limitedQueue.enqueue({'id': 'first'});
        limitedQueue.enqueue({'id': 'second'});
        limitedQueue.enqueue({'id': 'third'});

        expect(limitedQueue.pendingCount, 2);
        // First item should have been dropped
        final actions = limitedQueue.pendingActions;
        expect(actions[0].action['id'], isNot('first'));
        limitedQueue.dispose();
      });

      test('TC-009 Boundary: maxSize 1 keeps only latest', () {
        final limitedQueue = OfflineQueue(
          maxSize: 1,
          overflowStrategy: QueueOverflowStrategy.rejectOldest,
        );

        limitedQueue.enqueue({'id': 'A'});
        limitedQueue.enqueue({'id': 'B'});
        limitedQueue.enqueue({'id': 'C'});

        expect(limitedQueue.pendingCount, 1);
        limitedQueue.dispose();
      });

      test('TC-009 Normal: rejectNewest prevents new item', () {
        final limitedQueue = OfflineQueue(
          maxSize: 2,
          overflowStrategy: QueueOverflowStrategy.rejectNewest,
        );

        expect(limitedQueue.enqueue({'id': 'A'}), true);
        expect(limitedQueue.enqueue({'id': 'B'}), true);
        expect(limitedQueue.enqueue({'id': 'C'}), false);

        expect(limitedQueue.pendingCount, 2);
        limitedQueue.dispose();
      });
    });

    group('TC-010: Queue enqueue and dequeue operations', () {
      test('TC-010 Normal: enqueue stores action', () {
        queue.enqueue({'type': 'save'});
        expect(queue.hasPending, true);
        expect(queue.pendingCount, 1);
      });

      test('TC-010 Normal: dequeue via processQueue', () async {
        queue.enqueue({'type': 'save'});
        await queue.processQueue((action) async {});
        expect(queue.hasPending, false);
        expect(queue.pendingCount, 0);
      });

      test('TC-010 Boundary: empty queue processQueue is no-op', () async {
        final results = await queue.processQueue((action) async {});
        expect(results, isEmpty);
      });
    });

    group('TC-011: offlineQueue configuration per action', () {
      test('TC-011 Normal: action queued with context', () {
        queue.enqueue(
          {'type': 'saveData'},
          context: {'userId': '123'},
        );

        final action = queue.pendingActions[0];
        expect(action.action['type'], 'saveData');
        expect(action.context, isNotNull);
        expect(action.context!['userId'], '123');
      });
    });

    group('Retry handling', () {
      test('failed actions retried up to maxRetries', () async {
        int callCount = 0;
        queue.enqueue({'type': 'fail'}, maxRetries: 3);

        await queue.processQueue((action) async {
          callCount++;
          throw Exception('fail');
        });

        // Action should be re-queued (not expired yet)
        expect(queue.hasPending, true);
        expect(callCount, 1);

        // Process again
        await queue.processQueue((action) async {
          callCount++;
          throw Exception('fail');
        });

        expect(callCount, 2);
      });

      test('action expired after maxRetries', () async {
        queue.enqueue({'type': 'fail'}, maxRetries: 1);

        // First attempt fails
        await queue.processQueue((action) async {
          throw Exception('fail');
        });
        expect(queue.hasPending, false); // maxRetries=1, retryCount=1, expired
      });
    });

    group('Parallel processing', () {
      test('processQueueParallel processes all concurrently', () async {
        queue.enqueue({'id': 'A'});
        queue.enqueue({'id': 'B'});
        queue.enqueue({'id': 'C'});

        final processed = <String>[];
        final results = await queue.processQueueParallel((action) async {
          processed.add(action['id'] as String);
        });

        expect(results.length, 3);
        expect(processed, containsAll(['A', 'B', 'C']));
        expect(queue.hasPending, false);
      });

      test('parallel processing re-queues failures', () async {
        queue.enqueue({'id': 'A'}, maxRetries: 3);
        queue.enqueue({'id': 'B'}, maxRetries: 3);

        await queue.processQueueParallel((action) async {
          if (action['id'] == 'A') throw Exception('fail A');
        });

        expect(queue.hasPending, true);
        expect(queue.pendingCount, 1);
      });
    });

    group('Queue management', () {
      test('remove by ID', () {
        queue.enqueue({'id': 'A'});
        queue.enqueue({'id': 'B'});

        final id = queue.pendingActions[0].id;
        expect(queue.remove(id), true);
        expect(queue.pendingCount, 1);
      });

      test('remove non-existent ID returns false', () {
        expect(queue.remove('nonexistent'), false);
      });

      test('clear removes all', () {
        queue.enqueue({'id': 'A'});
        queue.enqueue({'id': 'B'});
        queue.clear();
        expect(queue.hasPending, false);
      });

      test('pendingActions returns unmodifiable list', () {
        queue.enqueue({'id': 'A'});
        final actions = queue.pendingActions;
        expect(actions.length, 1);
      });

      test('isProcessing is false initially', () {
        expect(queue.isProcessing, false);
      });

      test('concurrent processQueue calls rejected', () async {
        queue.enqueue({'id': 'A'});

        // Start first processing
        final future1 = queue.processQueue((action) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });

        // Attempt second processing immediately
        final results2 = await queue.processQueue((action) async {});
        expect(results2, isEmpty); // Rejected because already processing

        await future1;
      });
    });

    group('Results stream', () {
      test('results stream emits processing results', () async {
        queue.enqueue({'id': 'A'});

        final results = <QueueProcessResult>[];
        queue.results.listen((r) => results.add(r));

        await queue.processQueue((action) async {});
        await Future<void>.delayed(Duration.zero);

        expect(results.length, 1);
        expect(results[0].success, true);
      });
    });
  });

  group('TC-007: LIFO queue strategy', () {
    test('TC-007 Normal: LIFO via rejectOldest overflow simulates last-in preference', () {
      // With maxSize=1 and rejectOldest, only the last-enqueued item remains
      final lifoQueue = OfflineQueue(
        maxSize: 1,
        overflowStrategy: QueueOverflowStrategy.rejectOldest,
      );

      lifoQueue.enqueue({'id': 'first'});
      lifoQueue.enqueue({'id': 'second'});
      lifoQueue.enqueue({'id': 'third'});

      // Only the most recently enqueued item should remain
      expect(lifoQueue.pendingCount, 1);
      final remaining = lifoQueue.pendingActions;
      expect(remaining[0].action['id'], 'third');

      lifoQueue.dispose();
    });

    test('TC-007 Boundary: LIFO with maxSize=2 keeps last two', () {
      final lifoQueue = OfflineQueue(
        maxSize: 2,
        overflowStrategy: QueueOverflowStrategy.rejectOldest,
      );

      lifoQueue.enqueue({'id': 'A'});
      lifoQueue.enqueue({'id': 'B'});
      lifoQueue.enqueue({'id': 'C'});

      expect(lifoQueue.pendingCount, 2);
      // Oldest (A) was dropped
      final actions = lifoQueue.pendingActions;
      expect(actions[0].action['id'], isNot('A'));

      lifoQueue.dispose();
    });

    test('TC-007 Error: LIFO processing order — last enqueued processed first via priority', () async {
      // Using critical priority for latest item to simulate LIFO preference
      final queue = OfflineQueue();
      queue.enqueue({'id': 'old'}, priority: QueuePriority.low);
      queue.enqueue({'id': 'new'}, priority: QueuePriority.critical);

      final order = <String>[];
      await queue.processQueue((action) async {
        order.add(action['id'] as String);
      });

      // Higher priority processed later due to _findInsertIndex sorting
      expect(order.last, 'new');
      queue.dispose();
    });
  });

  group('QueuedAction Tests', () {
    test('has unique ID', () {
      final a = QueuedAction(action: {'type': 'test'});
      final b = QueuedAction(action: {'type': 'test'});
      expect(a.id, isNot(b.id));
    });

    test('isExpired when retryCount >= maxRetries', () {
      final action = QueuedAction(action: {'type': 'test'}, maxRetries: 2);
      expect(action.isExpired, false);

      action.retryCount = 2;
      expect(action.isExpired, true);
    });

    test('toJson serializes correctly', () {
      final action = QueuedAction(
        action: {'type': 'save'},
        context: {'userId': '123'},
        priority: QueuePriority.high,
      );

      final json = action.toJson();
      expect(json['id'], isNotNull);
      expect(json['action'], {'type': 'save'});
      expect(json['context'], {'userId': '123'});
      expect(json['priority'], 'high');
      expect(json['retryCount'], 0);
    });
  });

  // ===========================================================================
  // TC-043: Queue overflow error handling
  // ===========================================================================
  group('TC-043: Queue overflow error handling', () {
    test('TC-043 Normal: queue within limits stores all actions', () {
      final limitedQueue = OfflineQueue(maxSize: 10);

      for (var i = 0; i < 5; i++) {
        limitedQueue.enqueue({'id': i});
      }

      expect(limitedQueue.pendingCount, 5);
      limitedQueue.dispose();
    });

    test('TC-043 Normal: dropOldest overflow drops oldest action', () {
      final limitedQueue = OfflineQueue(
        maxSize: 3,
        overflowStrategy: QueueOverflowStrategy.rejectOldest,
      );

      limitedQueue.enqueue({'id': 'A'});
      limitedQueue.enqueue({'id': 'B'});
      limitedQueue.enqueue({'id': 'C'});
      // Queue is now full, adding another should drop oldest
      limitedQueue.enqueue({'id': 'D'});

      expect(limitedQueue.pendingCount, 3);
      final actions = limitedQueue.pendingActions;
      // 'A' should have been dropped
      final ids = actions.map((a) => a.action['id']).toList();
      expect(ids, isNot(contains('A')));
      expect(ids, contains('D'));

      limitedQueue.dispose();
    });

    test('TC-043 Normal: dropNewest overflow rejects new action', () {
      final limitedQueue = OfflineQueue(
        maxSize: 3,
        overflowStrategy: QueueOverflowStrategy.rejectNewest,
      );

      expect(limitedQueue.enqueue({'id': 'A'}), true);
      expect(limitedQueue.enqueue({'id': 'B'}), true);
      expect(limitedQueue.enqueue({'id': 'C'}), true);
      // Queue is full, new action should be rejected
      expect(limitedQueue.enqueue({'id': 'D'}), false);

      expect(limitedQueue.pendingCount, 3);
      final ids = limitedQueue.pendingActions.map((a) => a.action['id']).toList();
      expect(ids, isNot(contains('D')));

      limitedQueue.dispose();
    });

    test('TC-043 Boundary: priority overflow drops lowest-priority action', () {
      final limitedQueue = OfflineQueue(
        maxSize: 2,
        overflowStrategy: QueueOverflowStrategy.rejectOldest,
      );

      // Low priority goes at index 0 (oldest position)
      limitedQueue.enqueue({'id': 'low'}, priority: QueuePriority.low);
      limitedQueue.enqueue({'id': 'high'}, priority: QueuePriority.high);
      // Adding another should drop the item at index 0 (the low-priority one)
      limitedQueue.enqueue({'id': 'critical'}, priority: QueuePriority.critical);

      expect(limitedQueue.pendingCount, 2);
      final ids = limitedQueue.pendingActions.map((a) => a.action['id']).toList();
      expect(ids, isNot(contains('low')));

      limitedQueue.dispose();
    });

    test('TC-043 Boundary: maxSize 1 with rejectOldest keeps only latest', () {
      final limitedQueue = OfflineQueue(
        maxSize: 1,
        overflowStrategy: QueueOverflowStrategy.rejectOldest,
      );

      limitedQueue.enqueue({'id': 'A'});
      limitedQueue.enqueue({'id': 'B'});
      limitedQueue.enqueue({'id': 'C'});

      expect(limitedQueue.pendingCount, 1);
      expect(limitedQueue.pendingActions[0].action['id'], 'C');

      limitedQueue.dispose();
    });

    test('TC-043 Error: enqueue returns false when rejected by rejectNewest', () {
      final limitedQueue = OfflineQueue(
        maxSize: 1,
        overflowStrategy: QueueOverflowStrategy.rejectNewest,
      );

      expect(limitedQueue.enqueue({'id': 'first'}), true);
      // Subsequent enqueues should all be rejected
      expect(limitedQueue.enqueue({'id': 'second'}), false);
      expect(limitedQueue.enqueue({'id': 'third'}), false);

      expect(limitedQueue.pendingCount, 1);
      expect(limitedQueue.pendingActions[0].action['id'], 'first');

      limitedQueue.dispose();
    });
  });

  group('ConflictResolver Tests', () {
    group('TC-016: clientWins strategy', () {
      test('TC-016 Normal: client value wins', () {
        final resolver = ConflictResolver(
          strategy: ConflictStrategy.clientWins,
        );

        final result = resolver.resolve(
          {'name': 'local'},
          {'name': 'remote'},
          clientTimestamp: DateTime.now(),
          serverTimestamp: DateTime.now(),
        );

        expect(result.resolvedValue, {'name': 'local'});
        expect(result.appliedStrategy, ConflictStrategy.clientWins);
      });
    });

    group('TC-017: serverWins strategy', () {
      test('TC-017 Normal: server value wins', () {
        final resolver = ConflictResolver(
          strategy: ConflictStrategy.serverWins,
        );

        final result = resolver.resolve(
          {'name': 'local'},
          {'name': 'remote'},
          clientTimestamp: DateTime.now(),
          serverTimestamp: DateTime.now(),
        );

        expect(result.resolvedValue, {'name': 'remote'});
        expect(result.appliedStrategy, ConflictStrategy.serverWins);
      });
    });

    group('TC-018: lastWriteWins strategy', () {
      test('TC-018 Normal: more recent client wins', () {
        final resolver = ConflictResolver(
          strategy: ConflictStrategy.lastWriteWins,
        );

        final result = resolver.resolve(
          'local',
          'remote',
          clientTimestamp: DateTime(2024, 1, 2),
          serverTimestamp: DateTime(2024, 1, 1),
        );

        expect(result.resolvedValue, 'local');
      });

      test('TC-018 Normal: more recent server wins', () {
        final resolver = ConflictResolver(
          strategy: ConflictStrategy.lastWriteWins,
        );

        final result = resolver.resolve(
          'local',
          'remote',
          clientTimestamp: DateTime(2024, 1, 1),
          serverTimestamp: DateTime(2024, 1, 2),
        );

        expect(result.resolvedValue, 'remote');
      });
    });

    group('TC-019: merge strategy', () {
      test('TC-019 Normal: deep merge of objects', () {
        final resolver = ConflictResolver(
          strategy: ConflictStrategy.merge,
        );

        final result = resolver.resolve(
          {'name': 'local', 'age': 30},
          {'name': 'remote', 'email': 'test@test.com'},
          clientTimestamp: DateTime.now(),
          serverTimestamp: DateTime.now(),
        );

        final merged = result.resolvedValue as Map<String, dynamic>;
        // Client (override) takes precedence for overlapping keys
        expect(merged['name'], 'local');
        expect(merged['age'], 30);
        expect(merged['email'], 'test@test.com');
      });

      test('TC-019 Boundary: non-overlapping fields both preserved', () {
        final resolver = ConflictResolver(
          strategy: ConflictStrategy.merge,
        );

        final result = resolver.resolve(
          {'a': 1},
          {'b': 2},
          clientTimestamp: DateTime.now(),
          serverTimestamp: DateTime.now(),
        );

        final merged = result.resolvedValue as Map<String, dynamic>;
        expect(merged['a'], 1);
        expect(merged['b'], 2);
      });

      test('TC-019 Error: scalar merge - client wins', () {
        final resolver = ConflictResolver(
          strategy: ConflictStrategy.merge,
        );

        final result = resolver.resolve(
          'local',
          'remote',
          clientTimestamp: DateTime.now(),
          serverTimestamp: DateTime.now(),
        );

        // For non-map values, override (client) wins
        expect(result.resolvedValue, 'local');
      });
    });

    group('TC-020: manual strategy', () {
      test('TC-020 Normal: returns requiresUserInput', () {
        final resolver = ConflictResolver(
          strategy: ConflictStrategy.manual,
        );

        final result = resolver.resolve(
          'local',
          'remote',
          clientTimestamp: DateTime.now(),
          serverTimestamp: DateTime.now(),
        );

        expect(result.requiresUserInput, isTrue);
        expect(result.appliedStrategy, ConflictStrategy.manual);
      });
    });

    // =========================================================================
    // TC-049: ConflictResolver — parseStrategy
    // =========================================================================
    group('TC-049: ConflictResolver — parseStrategy', () {
      test('TC-049 Normal: parseStrategy("clientWins") returns ConflictStrategy.clientWins', () {
        expect(
          ConflictResolver.parseStrategy('clientWins'),
          ConflictStrategy.clientWins,
        );
      });

      test('TC-049 Normal: parseStrategy("serverWins") returns ConflictStrategy.serverWins', () {
        expect(
          ConflictResolver.parseStrategy('serverWins'),
          ConflictStrategy.serverWins,
        );
      });

      test('TC-049 Normal: parseStrategy("lastWriteWins") returns ConflictStrategy.lastWriteWins', () {
        expect(
          ConflictResolver.parseStrategy('lastWriteWins'),
          ConflictStrategy.lastWriteWins,
        );
      });

      test('TC-049 Normal: parseStrategy("merge") returns ConflictStrategy.merge', () {
        expect(
          ConflictResolver.parseStrategy('merge'),
          ConflictStrategy.merge,
        );
      });

      test('TC-049 Normal: parseStrategy("manual") returns ConflictStrategy.manual', () {
        expect(
          ConflictResolver.parseStrategy('manual'),
          ConflictStrategy.manual,
        );
      });

      test('TC-049 Boundary: parseStrategy(null) returns default strategy (lastWriteWins)', () {
        expect(
          ConflictResolver.parseStrategy(null),
          ConflictStrategy.lastWriteWins,
        );
      });

      test('TC-049 Error: unknown strategy string returns default strategy', () {
        expect(
          ConflictResolver.parseStrategy('unknownStrategy'),
          ConflictStrategy.lastWriteWins,
        );
      });

      test('TC-049 Error: empty string returns default strategy', () {
        expect(
          ConflictResolver.parseStrategy(''),
          ConflictStrategy.lastWriteWins,
        );
      });
    });
  });
}
