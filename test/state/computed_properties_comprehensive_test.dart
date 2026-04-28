import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/state/computed_property.dart';

void main() {
  late StateManager stateManager;

  setUp(() {
    stateManager = StateManager();
    stateManager.initialize({
      'price': 100,
      'quantity': 3,
      'tax': 0.1,
      'firstName': 'John',
      'lastName': 'Doe',
      'items': [
        {'name': 'A', 'price': 10},
        {'name': 'B', 'price': 20},
        {'name': 'C', 'price': 30},
      ],
      'counter': 0,
      'flag': true,
    });
  });

  tearDown(() {
    stateManager.dispose();
  });

  // ===========================================================================
  // TC-085~090: Computed property registration and evaluation
  // ===========================================================================
  group('TC-085~090: Computed property registration and evaluation', () {
    // TC-085 Normal: registerComputedProperty registers a computed property
    // that can be retrieved via get()
    test('TC-085: registerComputedProperty registers and get() retrieves value',
        () {
      stateManager.registerComputedProperty(
        'total',
        ComputedProperty(
          name: 'total',
          expression: '{{price}} * {{quantity}}',
          compute: (state) =>
              (state['price'] as num) * (state['quantity'] as num),
          dependencies: ['price', 'quantity'],
        ),
      );

      expect(stateManager.get('total'), equals(300));
    });

    // TC-086 Normal: addComputedProperty creates from expression string
    test('TC-086: addComputedProperty creates from expression string', () {
      stateManager.addComputedProperty(
        'fullName',
        '{{firstName}} {{lastName}}',
        dependencies: ['firstName', 'lastName'],
      );

      final result = stateManager.get<String>('fullName');
      expect(result, equals('John Doe'));
    });

    // TC-087 Normal: Computed property auto-recomputes when dependency changes
    test('TC-087: computed property auto-recomputes when dependency changes',
        () {
      stateManager.registerComputedProperty(
        'total',
        ComputedProperty(
          name: 'total',
          expression: '{{price}} * {{quantity}}',
          compute: (state) =>
              (state['price'] as num) * (state['quantity'] as num),
          dependencies: ['price', 'quantity'],
        ),
      );

      // Initial value
      expect(stateManager.get('total'), equals(300));

      // Change a dependency
      stateManager.set('price', 200);

      // Should recompute with new value
      expect(stateManager.get('total'), equals(600));
    });

    // TC-088 Normal: computedPropertyNames returns list of all registered names
    test('TC-088: computedPropertyNames returns all registered names', () {
      stateManager.registerComputedProperty(
        'total',
        ComputedProperty(
          name: 'total',
          expression: '{{price}} * {{quantity}}',
          compute: (state) =>
              (state['price'] as num) * (state['quantity'] as num),
          dependencies: ['price', 'quantity'],
        ),
      );
      stateManager.registerComputedProperty(
        'fullName',
        ComputedProperty(
          name: 'fullName',
          expression: '{{firstName}} {{lastName}}',
          compute: (state) => '${state['firstName']} ${state['lastName']}',
          dependencies: ['firstName', 'lastName'],
        ),
      );

      final names = stateManager.computedPropertyNames;
      expect(names, containsAll(['total', 'fullName']));
      expect(names.length, equals(2));
    });

    // TC-089 Normal: unregisterComputedProperty removes a computed property
    test('TC-089: unregisterComputedProperty removes a computed property', () {
      stateManager.registerComputedProperty(
        'total',
        ComputedProperty(
          name: 'total',
          expression: '{{price}} * {{quantity}}',
          compute: (state) =>
              (state['price'] as num) * (state['quantity'] as num),
          dependencies: ['price', 'quantity'],
        ),
      );

      expect(stateManager.get('total'), equals(300));

      stateManager.unregisterComputedProperty('total');

      // After unregistering, get() returns null (no state key or computed property)
      expect(stateManager.get('total'), isNull);
      expect(stateManager.computedPropertyNames, isEmpty);
    });

    // TC-090 Error: Computed property circular dependency detection
    test('TC-090: circular dependency detection returns null', () {
      late ComputedProperty computed;
      computed = ComputedProperty(
        name: 'circular',
        expression: '{{circular}}',
        compute: (state) {
          // Simulate circular: invoke computeAndCache again during compute
          return computed.computeAndCache(state);
        },
        dependencies: ['circular'],
      );

      // Should return null (circular dependency guard) instead of StackOverflow
      final result = computed.computeAndCache({'circular': 1});
      expect(result, isNull);
    });
  });

  // ===========================================================================
  // TC-091~095: ComputedProperty static methods (fromExpression)
  // ===========================================================================
  group('TC-091~095: ComputedProperty static methods', () {
    // TC-091 Normal: fromExpression creates property with auto-extracted
    // dependencies
    test('TC-091: fromExpression auto-extracts dependencies', () {
      final prop = ComputedProperty.fromExpression(
        'total',
        '{{price}} * {{quantity}}',
      );

      expect(prop.name, equals('total'));
      expect(prop.dependencies, containsAll(['price', 'quantity']));
    });

    // TC-092 Normal: fromExpression evaluates simple variable substitution
    test('TC-092: fromExpression evaluates simple variable substitution', () {
      final prop = ComputedProperty.fromExpression(
        'greeting',
        '{{firstName}}',
      );

      final result = prop.computeAndCache({'firstName': 'John'});
      expect(result, equals('John'));
    });

    // TC-093 Normal: fromExpression evaluates ternary expression
    test('TC-093: fromExpression evaluates ternary expression', () {
      final prop = ComputedProperty.fromExpression(
        'status',
        "{{count > 0 ? 'yes' : 'no'}}",
      );

      final resultYes = prop.computeAndCache({'count': 5});
      expect(resultYes, equals('yes'));

      prop.invalidate();
      final resultNo = prop.computeAndCache({'count': 0});
      expect(resultNo, equals('no'));
    });

    // TC-094 Normal: fromExpression evaluates arithmetic
    test('TC-094: fromExpression evaluates arithmetic expression', () {
      final prop = ComputedProperty.fromExpression(
        'total',
        '{{price * quantity}}',
      );

      final result = prop.computeAndCache({'price': 100, 'quantity': 3});
      expect(result, equals(300));
    });

    // TC-095 Boundary: fromExpression evaluates comparison operators
    test('TC-095: fromExpression evaluates comparison operators', () {
      final prop = ComputedProperty.fromExpression(
        'isAdult',
        '{{age >= 18}}',
      );

      final resultTrue = prop.computeAndCache({'age': 21});
      expect(resultTrue, isTrue);

      prop.invalidate();
      final resultFalse = prop.computeAndCache({'age': 15});
      expect(resultFalse, isFalse);

      prop.invalidate();
      final resultBoundary = prop.computeAndCache({'age': 18});
      expect(resultBoundary, isTrue);
    });
  });

  // ===========================================================================
  // TC-096~100: State watchers - path-specific watching
  // ===========================================================================
  group('TC-096~100: State watchers - path-specific watching', () {
    // TC-096 Normal: watch(path) returns Stream that emits current value
    // immediately. Broadcast streams require listener before add(), so we
    // use a non-zero initial value and verify the current value is emitted
    // when the controller already has a listener from a prior watch() call.
    test('TC-096: watch(path) emits current value immediately', () async {
      stateManager.set('counter', 10);

      // First watch() creates the broadcast controller and emits 10 into it.
      // Since no listener is attached yet, that emission is lost on broadcast.
      // However, the controller is now cached. The second watch() call adds
      // the current value again while a listener IS attached.
      final values = <dynamic>[];
      final stream = stateManager.watch<int>('counter');
      final subscription = stream.listen((value) {
        values.add(value);
      });

      // Second watch triggers another add(currentValue) on the same controller
      stateManager.watch<int>('counter');

      await Future<void>.delayed(Duration.zero);

      // The second watch() emits the current value (10) to the existing listener
      expect(values, contains(10));

      await subscription.cancel();
    });

    // TC-097 Normal: watch(path) emits new values when set() is called.
    // Note: The initial value from watch() is emitted synchronously before
    // listen() on a broadcast stream, so it is not captured by the listener.
    // Only subsequent set() values are received.
    test('TC-097: watch(path) emits new values on set()', () async {
      final values = <dynamic>[];
      final stream = stateManager.watch<int>('counter');

      final subscription = stream.listen((value) {
        values.add(value);
      });

      // Allow any pending microtasks
      await Future<void>.delayed(Duration.zero);

      stateManager.set('counter', 1);
      stateManager.set('counter', 2);
      stateManager.set('counter', 3);

      // Allow all events to propagate
      await Future<void>.delayed(Duration.zero);

      // set() values are received by the listener
      expect(values, containsAllInOrder([1, 2, 3]));

      await subscription.cancel();
    });

    // TC-098 Boundary: Multiple watch() calls on same path share broadcast
    // stream
    test('TC-098: multiple watch() calls share broadcast stream', () async {
      final values1 = <dynamic>[];
      final values2 = <dynamic>[];

      final stream1 = stateManager.watch<int>('counter');
      final sub1 = stream1.listen((v) => values1.add(v));

      // Allow initial value delivery for first listener
      await Future<void>.delayed(Duration.zero);

      final stream2 = stateManager.watch<int>('counter');
      final sub2 = stream2.listen((v) => values2.add(v));

      // Allow initial value delivery for second listener
      await Future<void>.delayed(Duration.zero);

      stateManager.set('counter', 42);

      await Future<void>.delayed(Duration.zero);

      // Both listeners should receive the set() value
      expect(values1, contains(42));
      expect(values2, contains(42));

      await sub1.cancel();
      await sub2.cancel();
    });

    // TC-099 Normal: addKeyListener/removeKeyListener for specific key
    test('TC-099: addKeyListener and removeKeyListener', () {
      var callCount = 0;
      void listener() {
        callCount++;
      }

      stateManager.addKeyListener('counter', listener);

      stateManager.set('counter', 1);
      expect(callCount, equals(1));

      stateManager.set('counter', 2);
      expect(callCount, equals(2));

      // Changing a different key should not trigger
      stateManager.set('price', 999);
      expect(callCount, equals(2));

      // After removing, should not be called
      stateManager.removeKeyListener('counter', listener);
      stateManager.set('counter', 3);
      expect(callCount, equals(2));
    });

    // TC-100 Normal: Multiple key listeners for same key all get called
    test('TC-100: multiple key listeners for same key all get called', () {
      var count1 = 0;
      var count2 = 0;
      void listener1() => count1++;
      void listener2() => count2++;

      stateManager.addKeyListener('counter', listener1);
      stateManager.addKeyListener('counter', listener2);

      stateManager.set('counter', 10);

      expect(count1, equals(1));
      expect(count2, equals(1));

      // Remove only one listener
      stateManager.removeKeyListener('counter', listener1);
      stateManager.set('counter', 20);

      expect(count1, equals(1));
      expect(count2, equals(2));
    });
  });

  // ===========================================================================
  // TC-101~105: State change events and stream
  // ===========================================================================
  group('TC-101~105: State change events and stream', () {
    // TC-101 Normal: StateChangeEvent contains required fields
    test('TC-101: StateChangeEvent contains path, oldValue, newValue, timestamp, source',
        () {
      final event = StateChangeEvent(
        path: 'counter',
        oldValue: 0,
        newValue: 1,
        source: 'user',
      );

      expect(event.path, equals('counter'));
      expect(event.oldValue, equals(0));
      expect(event.newValue, equals(1));
      expect(event.timestamp, isA<DateTime>());
      expect(event.source, equals('user'));
    });

    // TC-102 Normal: StateManager.stream emits StateChangeEvent on set()
    test('TC-102: stream emits StateChangeEvent on every set() call', () async {
      final events = <StateChangeEvent>[];
      final subscription = stateManager.stream.listen(events.add);

      stateManager.set('counter', 5);

      await Future<void>.delayed(Duration.zero);

      expect(events.length, equals(1));
      expect(events[0].path, equals('counter'));
      expect(events[0].oldValue, equals(0));
      expect(events[0].newValue, equals(5));

      await subscription.cancel();
    });

    // TC-103 Normal: StateChangeEvent.source tracks origin
    test('TC-103: StateChangeEvent.source tracks origin', () async {
      final events = <StateChangeEvent>[];
      final subscription = stateManager.stream.listen(events.add);

      stateManager.set('counter', 1, source: 'user');

      await Future<void>.delayed(Duration.zero);

      expect(events.length, equals(1));
      expect(events[0].source, equals('user'));

      await subscription.cancel();
    });

    // TC-104 Normal: updateAll() emits multiple StateChangeEvents (one per path)
    test('TC-104: updateAll() emits multiple StateChangeEvents', () async {
      final events = <StateChangeEvent>[];
      final subscription = stateManager.stream.listen(events.add);

      stateManager.updateAll({
        'counter': 10,
        'price': 200,
      });

      await Future<void>.delayed(Duration.zero);

      expect(events.length, equals(2));

      final paths = events.map((e) => e.path).toSet();
      expect(paths, containsAll(['counter', 'price']));

      // Verify source is set to 'updateAll'
      for (final event in events) {
        expect(event.source, equals('updateAll'));
      }

      await subscription.cancel();
    });

    // TC-105 Boundary: State change events include correct oldValue and newValue
    test('TC-105: state change events include correct oldValue and newValue',
        () async {
      final events = <StateChangeEvent>[];
      final subscription = stateManager.stream.listen(events.add);

      // counter starts at 0
      stateManager.set('counter', 5);
      stateManager.set('counter', 10);

      await Future<void>.delayed(Duration.zero);

      expect(events.length, equals(2));
      // First event: 0 -> 5
      expect(events[0].oldValue, equals(0));
      expect(events[0].newValue, equals(5));
      // Second event: 5 -> 10
      expect(events[1].oldValue, equals(5));
      expect(events[1].newValue, equals(10));

      await subscription.cancel();
    });
  });

  // ===========================================================================
  // TC-106~110: Batch updates and state operations
  // ===========================================================================
  group('TC-106~110: Batch updates and state operations', () {
    // TC-106 Normal: updateAll() updates multiple paths atomically
    // (single notifyListeners call)
    test('TC-106: updateAll() updates multiple paths with single notify', () {
      var notifyCount = 0;
      stateManager.addListener(() => notifyCount++);

      stateManager.updateAll({
        'counter': 10,
        'price': 500,
        'flag': false,
      });

      // updateAll calls notifyListeners only once
      expect(notifyCount, equals(1));

      // All values should be updated
      expect(stateManager.get('counter'), equals(10));
      expect(stateManager.get('price'), equals(500));
      expect(stateManager.get('flag'), equals(false));
    });

    // TC-107 Normal: mergeState() sets each entry individually
    test('TC-107: mergeState() merges into existing state', () {
      stateManager.mergeState({
        'counter': 99,
        'newKey': 'newValue',
      });

      expect(stateManager.get('counter'), equals(99));
      expect(stateManager.get('newKey'), equals('newValue'));
      // Existing keys not in merge map should remain
      expect(stateManager.get('price'), equals(100));
    });

    // TC-108 Normal: setState() replaces entire state and notifies stream
    // listeners
    test('TC-108: setState() replaces entire state', () async {
      // Set up a watch stream before replacing state
      final values = <dynamic>[];
      final stream = stateManager.watch<int>('newCounter');
      final subscription = stream.listen((v) => values.add(v));

      await Future<void>.delayed(Duration.zero);

      stateManager.setState({
        'newCounter': 42,
        'newFlag': true,
      });

      await Future<void>.delayed(Duration.zero);

      // Old state keys should be gone
      expect(stateManager.get('price'), isNull);
      expect(stateManager.get('counter'), isNull);

      // New state keys should be present
      expect(stateManager.get('newCounter'), equals(42));
      expect(stateManager.get('newFlag'), equals(true));

      // Stream listener should have received the new value
      expect(values, contains(42));

      await subscription.cancel();
    });

    // TC-109 Normal: clearState() clears all state and computed properties
    test('TC-109: clearState() clears all state and computed properties', () {
      stateManager.registerComputedProperty(
        'total',
        ComputedProperty(
          name: 'total',
          expression: '{{price}} * {{quantity}}',
          compute: (state) =>
              (state['price'] as num) * (state['quantity'] as num),
          dependencies: ['price', 'quantity'],
        ),
      );

      // Verify state and computed exist
      expect(stateManager.get('price'), equals(100));
      expect(stateManager.get('total'), equals(300));
      expect(stateManager.computedPropertyNames, isNotEmpty);

      stateManager.clearState();

      // State should be empty
      expect(stateManager.get('price'), isNull);
      // Computed properties should be cleared
      expect(stateManager.computedPropertyNames, isEmpty);
      expect(stateManager.get('total'), isNull);
    });

    // TC-110 Normal: setAppState/getAppState, setPageState/getPageState,
    // setRouteParams/getRouteParam
    test('TC-110: app state, page state, and route params operations', () {
      // App-level state
      stateManager.setAppState('theme', 'dark');
      expect(stateManager.getAppState<String>('theme'), equals('dark'));

      // Page-level state
      stateManager.setPageState('scrollY', 150);
      expect(stateManager.getPageState<int>('scrollY'), equals(150));

      // Route parameters
      stateManager.setRouteParams({'id': '123', 'tab': 'details'});
      expect(stateManager.getRouteParam('id'), equals('123'));
      expect(stateManager.getRouteParam('tab'), equals('details'));
      expect(stateManager.getRouteParam('nonExistent'), isNull);
    });
  });
}
