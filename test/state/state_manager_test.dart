import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/state/computed_property.dart';

void main() {
  group('TC-001: StateManager — constructor and initialize', () {
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager();
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('TC-001 Normal: StateManager extends ChangeNotifier', () {
      expect(stateManager, isA<ChangeNotifier>());
    });

    test('TC-001 Normal: initialize sets initial state correctly', () {
      stateManager.initialize({'counter': 0, 'name': 'test'});
      expect(stateManager.get<int>('counter'), equals(0));
      expect(stateManager.get<String>('name'), equals('test'));
    });

    test('TC-001 Boundary: Initialize with empty map', () {
      stateManager.initialize({});
      expect(stateManager.getState(), isEmpty);
    });

    test('TC-001 Boundary: Initialize overwrites existing state completely', () {
      stateManager.initialize({'a': 1, 'b': 2});
      stateManager.initialize({'c': 3});
      expect(stateManager.get('a'), isNull);
      expect(stateManager.get('b'), isNull);
      expect(stateManager.get<int>('c'), equals(3));
    });

    test('TC-001 Error: Initialize with null values in map', () {
      stateManager.initialize({'key': null, 'other': 'value'});
      expect(stateManager.get('key'), isNull);
      expect(stateManager.get<String>('other'), equals('value'));
    });
  });

  group('TC-002: StateManager — get', () {
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager();
      stateManager.initialize({
        'counter': 42,
        'user': {
          'profile': {'name': 'John'}
        },
      });
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('TC-002 Normal: get<int> returns stored integer value', () {
      expect(stateManager.get<int>('counter'), equals(42));
    });

    test('TC-002 Normal: Dot notation path returns nested value', () {
      expect(
        stateManager.get<String>('user.profile.name'),
        equals('John'),
      );
    });

    test('TC-002 Normal: Resolves computed properties when path matches', () {
      stateManager.initialize({'price': 10, 'quantity': 3});
      stateManager.registerComputedProperty(
        'total',
        _createComputedProperty(
          'total',
          '{{price * quantity}}',
          ['price', 'quantity'],
          (state) => (state['price'] as num) * (state['quantity'] as num),
        ),
      );
      expect(stateManager.get<num>('total'), equals(30));
    });

    test('TC-002 Boundary: Non-existent path returns null', () {
      expect(stateManager.get('nonExistent'), isNull);
    });

    test('TC-002 Error: Deeply nested non-existent path returns null', () {
      expect(stateManager.get('a.b.c.d'), isNull);
    });
  });

  group('TC-003: StateManager — set', () {
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager();
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('TC-003 Normal: set updates state and notifies listeners', () {
      var notified = false;
      stateManager.addListener(() => notified = true);
      stateManager.set('counter', 5);
      expect(stateManager.get<int>('counter'), equals(5));
      expect(notified, isTrue);
    });

    test('TC-003 Normal: Dot notation sets nested path', () {
      stateManager.set('user.name', 'John');
      expect(stateManager.get<String>('user.name'), equals('John'));
    });

    test('TC-003 Normal: Optional source parameter recorded in StateChangeEvent', () async {
      StateChangeEvent? receivedEvent;
      stateManager.stream.listen((event) => receivedEvent = event);
      stateManager.set('counter', 5, source: 'user');
      await Future.delayed(const Duration(milliseconds: 10));
      expect(receivedEvent?.source, equals('user'));
    });

    test('TC-003 Boundary: Set null value', () {
      stateManager.set('key', 'value');
      stateManager.set('key', null);
      expect(stateManager.get('key'), isNull);
    });

    test('TC-003 Boundary: Set to non-existent nested path creates intermediates', () {
      stateManager.set('a.b.c', 'deep');
      expect(stateManager.get<String>('a.b.c'), equals('deep'));
    });
  });

  group('TC-015: StateManager — setAppState and getAppState', () {
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager();
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('TC-015 Normal: setAppState equivalent to set("app.key", value)', () {
      stateManager.setAppState('theme', 'dark');
      expect(stateManager.get<String>('app.theme'), equals('dark'));
    });

    test('TC-015 Normal: getAppState equivalent to get("app.key")', () {
      stateManager.set('app.theme', 'light');
      expect(stateManager.getAppState<String>('theme'), equals('light'));
    });

    test('TC-015 Boundary: getAppState for non-existent key returns null', () {
      expect(stateManager.getAppState('nonExistent'), isNull);
    });

    test('TC-015 Boundary: setAppState with null value', () {
      stateManager.setAppState('key', null);
      expect(stateManager.getAppState('key'), isNull);
    });
  });

  group('TC-016: StateManager — setPageState and getPageState', () {
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager();
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('TC-016 Normal: setPageState equivalent to set("page.key", value)', () {
      stateManager.setPageState('counter', 0);
      expect(stateManager.get<int>('page.counter'), equals(0));
    });

    test('TC-016 Normal: getPageState equivalent to get("page.key")', () {
      stateManager.set('page.counter', 10);
      expect(stateManager.getPageState<int>('counter'), equals(10));
    });

    test('TC-016 Boundary: getPageState for non-existent key returns null', () {
      expect(stateManager.getPageState('missing'), isNull);
    });
  });

  group('TC-017: StateManager — setRouteParams and getRouteParam', () {
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager();
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('TC-017 Normal: setRouteParams sets route params', () {
      stateManager.setRouteParams({'id': '123', 'from': 'home'});
      expect(stateManager.getRouteParam('id'), equals('123'));
      expect(stateManager.getRouteParam('from'), equals('home'));
    });

    test('TC-017 Boundary: Non-existent param returns null', () {
      stateManager.setRouteParams({'id': '123'});
      expect(stateManager.getRouteParam('missing'), isNull);
    });

    test('TC-017 Boundary: Empty params map clears all route params', () {
      stateManager.setRouteParams({'id': '123'});
      stateManager.setRouteParams({});
      expect(stateManager.getRouteParam('id'), isNull);
    });
  });

  group('TC-018: StateManager — activeSubscriptions', () {
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager();
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('TC-018 Boundary: No subscriptions returns empty map', () {
      expect(stateManager.activeSubscriptions, isEmpty);
    });

    test('TC-018 Normal: Returns map of subscriptions when set', () {
      stateManager.set('_subscriptions', {'data://temp': 'temperature'});
      expect(stateManager.activeSubscriptions,
          equals({'data://temp': 'temperature'}));
    });
  });

  group('TC-022: StateManager — state getter', () {
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager();
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('TC-022 Normal: Returns copy of full state', () {
      stateManager.initialize({'counter': 0, 'name': 'test'});
      final state = stateManager.state;
      expect(state['counter'], equals(0));
      expect(state['name'], equals('test'));
    });

    test('TC-022 Normal: Modifications to returned map do not affect internal state', () {
      stateManager.initialize({'counter': 0});
      final state = stateManager.state;
      state['counter'] = 999;
      expect(stateManager.get<int>('counter'), equals(0));
    });

    test('TC-022 Boundary: Empty state returns empty map', () {
      expect(stateManager.state, isEmpty);
    });
  });

  group('TC-023: StateManager — stream getter', () {
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager();
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('TC-023 Normal: Returns Stream<StateChangeEvent>', () {
      expect(stateManager.stream, isA<Stream<StateChangeEvent>>());
    });

    test('TC-023 Normal: Each event contains path, oldValue, newValue, timestamp', () async {
      StateChangeEvent? event;
      stateManager.stream.listen((e) => event = e);
      stateManager.set('counter', 5);
      await Future.delayed(const Duration(milliseconds: 10));
      expect(event, isNotNull);
      expect(event!.path, equals('counter'));
      expect(event!.oldValue, isNull);
      expect(event!.newValue, equals(5));
      expect(event!.timestamp, isA<DateTime>());
    });

    test('TC-023 Normal: Emits for every state change', () async {
      final events = <StateChangeEvent>[];
      stateManager.stream.listen(events.add);
      stateManager.set('a', 1);
      stateManager.set('b', 2);
      stateManager.set('c', 3);
      await Future.delayed(const Duration(milliseconds: 10));
      expect(events.length, equals(3));
    });
  });

  group('TC-024: StateManager — getState', () {
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager();
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('TC-024 Normal: Returns full state snapshot', () {
      stateManager.initialize({'test': 'value'});
      final state = stateManager.getState();
      expect(state, equals({'test': 'value'}));
    });

    test('TC-024 Normal: Returns same data as state property', () {
      stateManager.initialize({'key': 42});
      expect(stateManager.getState(), equals(stateManager.state));
    });

    test('TC-024 Boundary: Empty state returns empty map', () {
      expect(stateManager.getState(), isEmpty);
    });

    test('TC-024 Boundary: After multiple mutations reflects all changes', () {
      stateManager.set('a', 1);
      stateManager.set('b', 2);
      final state = stateManager.getState();
      expect(state['a'], equals(1));
      expect(state['b'], equals(2));
    });
  });

  group('TC-025: StateManager — setState', () {
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager();
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('TC-025 Normal: Replaces entire state', () {
      stateManager.initialize({'old': 'data'});
      stateManager.setState({'new': 'data'});
      expect(stateManager.get('old'), isNull);
      expect(stateManager.get<String>('new'), equals('data'));
    });

    test('TC-025 Normal: All listeners notified', () {
      var notified = false;
      stateManager.addListener(() => notified = true);
      stateManager.setState({'key': 'value'});
      expect(notified, isTrue);
    });

    test('TC-025 Boundary: setState with empty map', () {
      stateManager.initialize({'key': 'value'});
      stateManager.setState({});
      expect(stateManager.getState(), isEmpty);
    });
  });

  group('TC-026: StateManager — clearState', () {
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager();
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('TC-026 Normal: Clears all state and computed properties', () {
      stateManager.initialize({'counter': 5});
      stateManager.addComputedProperty('total', '{{counter}}',
          dependencies: ['counter']);
      stateManager.clearState();
      expect(stateManager.getState(), isEmpty);
      expect(stateManager.computedPropertyNames, isEmpty);
    });

    test('TC-026 Normal: All listeners notified', () {
      var notified = false;
      stateManager.addListener(() => notified = true);
      stateManager.clearState();
      expect(notified, isTrue);
    });

    test('TC-026 Boundary: clearState on already empty state', () {
      stateManager.clearState();
      expect(stateManager.getState(), isEmpty);
    });
  });
}

/// Helper to create a ComputedProperty for testing
ComputedProperty _createComputedProperty(
  String name,
  String expression,
  List<String> dependencies,
  dynamic Function(Map<String, dynamic>) compute,
) {
  return ComputedProperty(
    name: name,
    expression: expression,
    dependencies: dependencies,
    compute: compute,
  );
}
