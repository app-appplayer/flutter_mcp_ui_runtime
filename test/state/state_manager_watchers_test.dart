import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';

void main() {
  group('TC-019: StateManager — addKeyListener and removeKeyListener', () {
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager();
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('TC-019 Normal: Add listener for key, called when key changes', () {
      stateManager.set('counter', 0);
      var listenerCalled = false;
      stateManager.addKeyListener('counter', () => listenerCalled = true);
      stateManager.set('counter', 1);
      expect(listenerCalled, isTrue);
    });

    test('TC-019 Normal: Remove listener, no longer called on changes', () {
      stateManager.set('counter', 0);
      var callCount = 0;
      void listener() => callCount++;
      stateManager.addKeyListener('counter', listener);
      stateManager.set('counter', 1);
      expect(callCount, equals(1));

      stateManager.removeKeyListener('counter', listener);
      stateManager.set('counter', 2);
      expect(callCount, equals(1));
    });

    test('TC-019 Normal: Multiple listeners for same key, all called', () {
      stateManager.set('counter', 0);
      var count1 = 0;
      var count2 = 0;
      stateManager.addKeyListener('counter', () => count1++);
      stateManager.addKeyListener('counter', () => count2++);
      stateManager.set('counter', 5);
      expect(count1, equals(1));
      expect(count2, equals(1));
    });

    test('TC-019 Boundary: Remove non-existent listener is no-op', () {
      stateManager.removeKeyListener('counter', () {});
      // Should not throw
    });
  });

  group('TC-020: StateManager — watch', () {
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager();
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('TC-020 Normal: watch returns Stream that emits on changes', () async {
      stateManager.set('counter', 0);
      final stream = stateManager.watch<int>('counter');
      final values = <int>[];
      final sub = stream.listen(values.add);

      await Future.delayed(const Duration(milliseconds: 10));

      stateManager.set('counter', 1);
      await Future.delayed(const Duration(milliseconds: 10));

      stateManager.set('counter', 2);
      await Future.delayed(const Duration(milliseconds: 10));

      // Should contain current value (0) plus changes (1, 2)
      expect(values, contains(1));
      expect(values, contains(2));
      await sub.cancel();
    });

    test('TC-020 Normal: Multiple changes, stream emits each value', () async {
      final stream = stateManager.watch<String>('name');
      final values = <String>[];
      final sub = stream.listen(values.add);

      stateManager.set('name', 'Alice');
      await Future.delayed(const Duration(milliseconds: 10));
      stateManager.set('name', 'Bob');
      await Future.delayed(const Duration(milliseconds: 10));

      expect(values, contains('Alice'));
      expect(values, contains('Bob'));
      await sub.cancel();
    });

    test('TC-020 Boundary: Watch non-existent path, emits when created', () async {
      final stream = stateManager.watch<String>('future.value');
      final values = <String>[];
      final sub = stream.listen(values.add);

      await Future.delayed(const Duration(milliseconds: 10));
      stateManager.set('future.value', 'created');
      await Future.delayed(const Duration(milliseconds: 10));

      expect(values, contains('created'));
      await sub.cancel();
    });
  });

  group('TC-031: StateChangeEvent — construction', () {
    test('TC-031 Normal: Created with path, oldValue, newValue, auto timestamp', () {
      final event = StateChangeEvent(
        path: 'counter',
        oldValue: 0,
        newValue: 5,
      );
      expect(event.path, equals('counter'));
      expect(event.oldValue, equals(0));
      expect(event.newValue, equals(5));
      expect(event.timestamp, isA<DateTime>());
    });

    test('TC-031 Normal: Optional source parameter', () {
      final event = StateChangeEvent(
        path: 'counter',
        oldValue: 0,
        newValue: 1,
        source: 'user',
      );
      expect(event.source, equals('user'));
    });

    test('TC-031 Boundary: oldValue and newValue can be null', () {
      final event = StateChangeEvent(
        path: 'nullable',
        oldValue: null,
        newValue: null,
      );
      expect(event.oldValue, isNull);
      expect(event.newValue, isNull);
    });

    test('TC-031 Boundary: source can be null', () {
      final event = StateChangeEvent(
        path: 'test',
        oldValue: 'a',
        newValue: 'b',
      );
      expect(event.source, isNull);
    });
  });
}
