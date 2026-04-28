import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';

void main() {
  group('TC-004: StateManager — increment', () {
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager();
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('TC-004 Normal: increment by 1 (default)', () {
      stateManager.set('counter', 5);
      stateManager.increment('counter');
      expect(stateManager.get<num>('counter'), equals(6));
    });

    test('TC-004 Normal: increment by custom amount', () {
      stateManager.set('counter', 5);
      stateManager.increment('counter', 5);
      expect(stateManager.get<num>('counter'), equals(10));
    });

    test('TC-004 Normal: Notifies listeners after increment', () {
      stateManager.set('counter', 0);
      var notified = false;
      stateManager.addListener(() => notified = true);
      stateManager.increment('counter');
      expect(notified, isTrue);
    });

    test('TC-004 Boundary: Increment null value treated as 0 + amount', () {
      stateManager.increment('unset');
      expect(stateManager.get<num>('unset'), equals(1));
    });

    test('TC-004 Boundary: Increment with amount = 0', () {
      stateManager.set('counter', 5);
      stateManager.increment('counter', 0);
      expect(stateManager.get<num>('counter'), equals(5));
    });
  });

  group('TC-005: StateManager — decrement', () {
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager();
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('TC-005 Normal: decrement by 1 (default)', () {
      stateManager.set('counter', 10);
      stateManager.decrement('counter');
      expect(stateManager.get<num>('counter'), equals(9));
    });

    test('TC-005 Normal: decrement by custom amount', () {
      stateManager.set('counter', 10);
      stateManager.decrement('counter', 3);
      expect(stateManager.get<num>('counter'), equals(7));
    });

    test('TC-005 Normal: Notifies listeners after decrement', () {
      stateManager.set('counter', 10);
      var notified = false;
      stateManager.addListener(() => notified = true);
      stateManager.decrement('counter');
      expect(notified, isTrue);
    });

    test('TC-005 Boundary: Decrement null value treated as 0 - amount', () {
      stateManager.decrement('unset');
      expect(stateManager.get<num>('unset'), equals(-1));
    });

    test('TC-005 Boundary: Decrement resulting in negative number allowed', () {
      stateManager.set('counter', 3);
      stateManager.decrement('counter', 10);
      expect(stateManager.get<num>('counter'), equals(-7));
    });
  });

  group('TC-006: StateManager — toggle', () {
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager();
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('TC-006 Normal: toggle changes true to false', () {
      stateManager.set('isVisible', true);
      stateManager.toggle('isVisible');
      expect(stateManager.get<bool>('isVisible'), isFalse);
    });

    test('TC-006 Normal: toggle changes false to true', () {
      stateManager.set('isVisible', false);
      stateManager.toggle('isVisible');
      expect(stateManager.get<bool>('isVisible'), isTrue);
    });

    test('TC-006 Normal: Notifies listeners after toggle', () {
      stateManager.set('flag', true);
      var notified = false;
      stateManager.addListener(() => notified = true);
      stateManager.toggle('flag');
      expect(notified, isTrue);
    });

    test('TC-006 Boundary: Toggle null becomes true', () {
      stateManager.toggle('unset');
      expect(stateManager.get<bool>('unset'), isTrue);
    });

    test('TC-006 Boundary: Toggle twice returns to original value', () {
      stateManager.set('flag', true);
      stateManager.toggle('flag');
      stateManager.toggle('flag');
      expect(stateManager.get<bool>('flag'), isTrue);
    });
  });

  group('TC-007: StateManager — append', () {
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager();
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('TC-007 Normal: append adds item to end of list', () {
      stateManager.set('items', [1, 2, 3]);
      stateManager.append('items', 4);
      expect(stateManager.get<List>('items'), equals([1, 2, 3, 4]));
    });

    test('TC-007 Normal: Appending preserves existing items', () {
      stateManager.set('items', ['a', 'b']);
      stateManager.append('items', 'c');
      final items = stateManager.get<List>('items')!;
      expect(items[0], equals('a'));
      expect(items[1], equals('b'));
      expect(items[2], equals('c'));
    });

    test('TC-007 Normal: Notifies listeners after append', () {
      stateManager.set('items', []);
      var notified = false;
      stateManager.addListener(() => notified = true);
      stateManager.append('items', 'new');
      expect(notified, isTrue);
    });

    test('TC-007 Boundary: Append to null creates new list with item', () {
      stateManager.append('items', 'first');
      expect(stateManager.get<List>('items'), equals(['first']));
    });

    test('TC-007 Boundary: Append to empty list', () {
      stateManager.set('items', []);
      stateManager.append('items', 'only');
      expect(stateManager.get<List>('items'), equals(['only']));
    });
  });

  group('TC-008: StateManager — push', () {
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager();
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('TC-008 Normal: push adds item to end of list (alias for append)', () {
      stateManager.set('items', [1, 2]);
      stateManager.push('items', 3);
      expect(stateManager.get<List>('items'), equals([1, 2, 3]));
    });

    test('TC-008 Boundary: Push to null creates new list with item', () {
      stateManager.push('items', 'first');
      expect(stateManager.get<List>('items'), equals(['first']));
    });
  });

  group('TC-009: StateManager — remove', () {
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager();
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('TC-009 Normal: remove matching item from list', () {
      stateManager.set('items', ['a', 'b', 'c']);
      stateManager.remove('items', 'b');
      expect(stateManager.get<List>('items'), equals(['a', 'c']));
    });

    test('TC-009 Normal: Removes first occurrence of value', () {
      stateManager.set('items', [1, 2, 3, 2]);
      stateManager.remove('items', 2);
      expect(stateManager.get<List>('items'), equals([1, 3, 2]));
    });

    test('TC-009 Boundary: Remove non-existent value is no-op', () {
      stateManager.set('items', [1, 2, 3]);
      stateManager.remove('items', 99);
      expect(stateManager.get<List>('items'), equals([1, 2, 3]));
    });

    test('TC-009 Boundary: Remove from empty list is no-op', () {
      stateManager.set('items', []);
      stateManager.remove('items', 'x');
      expect(stateManager.get<List>('items'), equals([]));
    });
  });

  group('TC-010: StateManager — pop', () {
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager();
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('TC-010 Normal: pop removes and returns last element', () {
      stateManager.set('items', [1, 2, 3]);
      final popped = stateManager.pop('items');
      expect(popped, equals(3));
      expect(stateManager.get<List>('items'), equals([1, 2]));
    });

    test('TC-010 Boundary: Pop from single-item list returns item, leaves empty list', () {
      stateManager.set('items', ['only']);
      final popped = stateManager.pop('items');
      expect(popped, equals('only'));
      expect(stateManager.get<List>('items'), equals([]));
    });

    test('TC-010 Boundary: Pop from empty list returns null', () {
      stateManager.set('items', []);
      final popped = stateManager.pop('items');
      expect(popped, isNull);
    });
  });

  group('TC-011: StateManager — removeAt', () {
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager();
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('TC-011 Normal: removeAt removes element at index', () {
      stateManager.set('items', ['a', 'b', 'c', 'd']);
      stateManager.removeAt('items', 2);
      expect(stateManager.get<List>('items'), equals(['a', 'b', 'd']));
    });

    test('TC-011 Boundary: removeAt index 0 removes first element', () {
      stateManager.set('items', ['a', 'b', 'c']);
      stateManager.removeAt('items', 0);
      expect(stateManager.get<List>('items'), equals(['b', 'c']));
    });

    test('TC-011 Boundary: removeAt last valid index removes last element', () {
      stateManager.set('items', ['a', 'b', 'c']);
      stateManager.removeAt('items', 2);
      expect(stateManager.get<List>('items'), equals(['a', 'b']));
    });

    test('TC-011 Error: removeAt with out-of-bounds index is no-op', () {
      stateManager.set('items', ['a', 'b']);
      stateManager.removeAt('items', 5);
      expect(stateManager.get<List>('items'), equals(['a', 'b']));
    });
  });

  group('TC-012: StateManager — update (read-modify-write)', () {
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager();
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('TC-012 Normal: update reads, applies updater, writes', () {
      stateManager.set('counter', 10);
      stateManager.update('counter', (current) => (current as int) + 10);
      expect(stateManager.get<int>('counter'), equals(20));
    });

    test('TC-012 Normal: Notifies listeners after update', () {
      stateManager.set('value', 1);
      var notified = false;
      stateManager.addListener(() => notified = true);
      stateManager.update('value', (v) => (v as int) + 1);
      expect(notified, isTrue);
    });

    test('TC-012 Boundary: Current value null passed to updater', () {
      stateManager.update('missing', (current) => current ?? 'default');
      expect(stateManager.get<String>('missing'), equals('default'));
    });

    test('TC-012 Boundary: Updater returns same value still sets and notifies', () {
      stateManager.set('value', 42);
      var notified = false;
      stateManager.addListener(() => notified = true);
      stateManager.update('value', (v) => v);
      expect(notified, isTrue);
    });
  });

  group('TC-013: StateManager — mergeState', () {
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager();
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('TC-013 Normal: mergeState sets both keys in state', () {
      stateManager.mergeState({'a': 1, 'b': 2});
      expect(stateManager.get<int>('a'), equals(1));
      expect(stateManager.get<int>('b'), equals(2));
    });

    test('TC-013 Boundary: Empty map is no-op', () {
      stateManager.set('existing', 'value');
      stateManager.mergeState({});
      expect(stateManager.get<String>('existing'), equals('value'));
    });

    test('TC-013 Boundary: Merge overwrites existing keys', () {
      stateManager.set('key', 'old');
      stateManager.mergeState({'key': 'new'});
      expect(stateManager.get<String>('key'), equals('new'));
    });

    test('TC-013 Error: Merge with conflicting types replaces old value', () {
      stateManager.set('value', 42);
      stateManager.mergeState({'value': 'string now'});
      expect(stateManager.get<String>('value'), equals('string now'));
    });
  });

  group('TC-014: StateManager — updateAll', () {
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager();
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('TC-014 Normal: updateAll updates multiple paths at once', () {
      stateManager.updateAll({'x': 1, 'y': 2});
      expect(stateManager.get<int>('x'), equals(1));
      expect(stateManager.get<int>('y'), equals(2));
    });

    test('TC-014 Normal: All paths updated and listeners notified', () {
      var notifyCount = 0;
      stateManager.addListener(() => notifyCount++);
      stateManager.updateAll({'a': 1, 'b': 2, 'c': 3});
      // updateAll calls notifyListeners once for the batch
      expect(notifyCount, equals(1));
    });

    test('TC-014 Boundary: Empty map is no-op', () {
      stateManager.set('existing', 'value');
      stateManager.updateAll({});
      expect(stateManager.get<String>('existing'), equals('value'));
    });

    test('TC-014 Boundary: Single entry map same as single set', () {
      stateManager.updateAll({'single': 'value'});
      expect(stateManager.get<String>('single'), equals('value'));
    });
  });

  group('TC-021: StateManager — clear', () {
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager();
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('TC-021 Normal: clear list becomes empty list', () {
      stateManager.set('items', [1, 2, 3]);
      stateManager.clear('items');
      expect(stateManager.get<List>('items'), equals([]));
    });

    test('TC-021 Normal: clear map becomes empty map', () {
      stateManager.set('data', {'key': 'value'});
      stateManager.clear('data');
      expect(stateManager.get<Map>('data'), equals({}));
    });

    test('TC-021 Normal: Notifies listeners after clear', () {
      stateManager.set('items', [1, 2]);
      var notified = false;
      stateManager.addListener(() => notified = true);
      stateManager.clear('items');
      expect(notified, isTrue);
    });

    test('TC-021 Boundary: Clear non-existent path is no-op', () {
      stateManager.clear('nonExistent');
      // Should not throw
      expect(stateManager.get('nonExistent'), isNull);
    });

    test('TC-021 Boundary: Clear already empty list is no-op', () {
      stateManager.set('items', []);
      stateManager.clear('items');
      expect(stateManager.get<List>('items'), equals([]));
    });
  });
}
