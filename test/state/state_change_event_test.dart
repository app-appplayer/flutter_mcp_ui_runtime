import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';

void main() {
  group('TC-031: StateChangeEvent — construction', () {
    test('TC-031 Normal: Created with path, oldValue, newValue, auto timestamp', () {
      final before = DateTime.now();
      final event = StateChangeEvent(
        path: 'counter',
        oldValue: 0,
        newValue: 5,
      );
      final after = DateTime.now();

      expect(event.path, equals('counter'));
      expect(event.oldValue, equals(0));
      expect(event.newValue, equals(5));
      expect(event.timestamp.isAfter(before.subtract(const Duration(milliseconds: 1))), isTrue);
      expect(event.timestamp.isBefore(after.add(const Duration(milliseconds: 1))), isTrue);
    });

    test('TC-031 Normal: Optional source parameter with valid values', () {
      for (final source in ['user', 'action', 'binding', 'computed', 'system']) {
        final event = StateChangeEvent(
          path: 'test',
          oldValue: null,
          newValue: 1,
          source: source,
        );
        expect(event.source, equals(source));
      }
    });

    test('TC-031 Normal: All fields accessible after construction', () {
      final event = StateChangeEvent(
        path: 'user.name',
        oldValue: 'Alice',
        newValue: 'Bob',
        source: 'action',
      );
      expect(event.path, isNotNull);
      expect(event.oldValue, isNotNull);
      expect(event.newValue, isNotNull);
      expect(event.source, isNotNull);
      expect(event.timestamp, isNotNull);
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

    test('TC-031 Normal: Custom timestamp can be provided', () {
      final customTimestamp = DateTime(2024, 1, 1);
      final event = StateChangeEvent(
        path: 'test',
        oldValue: null,
        newValue: 'value',
        timestamp: customTimestamp,
      );
      expect(event.timestamp, equals(customTimestamp));
    });
  });

  group('TC-031: StateChangeEvent — integration with StateManager', () {
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager();
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('TC-031 Normal: StateManager emits StateChangeEvent on set', () async {
      StateChangeEvent? received;
      stateManager.stream.listen((event) => received = event);

      stateManager.set('counter', 42);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(received, isNotNull);
      expect(received!.path, equals('counter'));
      expect(received!.newValue, equals(42));
    });

    test('TC-031 Normal: set with source records source in event', () async {
      StateChangeEvent? received;
      stateManager.stream.listen((event) => received = event);

      stateManager.set('counter', 1, source: 'user');
      await Future.delayed(const Duration(milliseconds: 10));

      expect(received!.source, equals('user'));
    });

    test(
        'TC-031 Normal: updateAll emits events with canonical source per spec §3.11',
        () async {
      // Spec §3.11 enumerates `action / tool / subscription / system`.
      // `updateAll` previously emitted the non-canonical literal `'updateAll'`
      // which was outside the enum; the runtime now defaults to `'system'`
      // and accepts an explicit override via the named [source] parameter.
      final events = <StateChangeEvent>[];
      stateManager.stream.listen(events.add);

      stateManager.updateAll({'a': 1, 'b': 2});
      await Future.delayed(const Duration(milliseconds: 10));

      expect(events.length, equals(2));
      expect(events[0].source, equals('system'));
      expect(events[1].source, equals('system'));
    });

    test('TC-031 Normal: updateAll honors explicit source override', () async {
      final events = <StateChangeEvent>[];
      stateManager.stream.listen(events.add);

      stateManager.updateAll({'a': 1}, source: 'action');
      await Future.delayed(const Duration(milliseconds: 10));

      expect(events.length, equals(1));
      expect(events.single.source, equals('action'));
    });

    test('TC-031 Normal: Event contains correct oldValue', () async {
      stateManager.set('counter', 10);
      StateChangeEvent? received;
      stateManager.stream.listen((event) => received = event);

      stateManager.set('counter', 20);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(received!.oldValue, equals(10));
      expect(received!.newValue, equals(20));
    });
  });
}
