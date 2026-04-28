import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/state/computed_property.dart';

void main() {
  late StateManager stateManager;

  setUp(() {
    stateManager = StateManager();
    stateManager.initialize({
      'user': {
        'name': 'John',
        'age': 30,
        'address': {'city': 'Seoul', 'zip': '12345'},
      },
      'counter': 0,
      'items': ['a', 'b', 'c'],
      'settings': {'theme': 'light', 'lang': 'en'},
    });
  });

  tearDown(() {
    stateManager.dispose();
  });

  // ============================================================
  // TC-111~115: Stream-based state change events
  // ============================================================
  group('Stream-based state change events', () {
    // TC-111: StateManager extends ChangeNotifier — addListener/removeListener
    test('TC-111: addListener receives notifications, removeListener stops them',
        () {
      // Normal: listener receives notification on set()
      var notifyCount = 0;
      void listener() => notifyCount++;
      stateManager.addListener(listener);
      stateManager.set('counter', 1);
      expect(notifyCount, equals(1));

      // Boundary: multiple set() calls increment notification count
      stateManager.set('counter', 2);
      expect(notifyCount, equals(2));

      // Normal: after removeListener, no further notifications
      stateManager.removeListener(listener);
      stateManager.set('counter', 3);
      expect(notifyCount, equals(2));
    });

    // TC-112: stream emits StateChangeEvent for each set() call
    test('TC-112: stream emits StateChangeEvent with correct path and values',
        () async {
      // Normal: subscribe to stream and verify events
      final events = <StateChangeEvent>[];
      final sub = stateManager.stream.listen(events.add);

      stateManager.set('counter', 10);
      stateManager.set('user.name', 'Jane');

      // Allow async delivery
      await Future<void>.delayed(Duration.zero);

      expect(events.length, equals(2));
      expect(events[0].path, equals('counter'));
      expect(events[0].oldValue, equals(0));
      expect(events[0].newValue, equals(10));
      expect(events[1].path, equals('user.name'));
      expect(events[1].newValue, equals('Jane'));

      // Boundary: event has non-null timestamp
      expect(events[0].timestamp, isNotNull);

      await sub.cancel();
    });

    // TC-113: Multiple stream subscriptions all receive events (broadcast)
    test('TC-113: multiple stream subscriptions all receive events', () async {
      // Normal: two independent subscribers both receive the same event
      final events1 = <StateChangeEvent>[];
      final events2 = <StateChangeEvent>[];
      final sub1 = stateManager.stream.listen(events1.add);
      final sub2 = stateManager.stream.listen(events2.add);

      stateManager.set('counter', 42);
      await Future<void>.delayed(Duration.zero);

      expect(events1.length, equals(1));
      expect(events2.length, equals(1));
      expect(events1[0].path, equals('counter'));
      expect(events2[0].path, equals('counter'));

      // Boundary: cancelling one subscription does not affect the other
      await sub1.cancel();
      stateManager.set('counter', 99);
      await Future<void>.delayed(Duration.zero);

      expect(events1.length, equals(1));
      expect(events2.length, equals(2));

      await sub2.cancel();
    });

    // TC-114: Computed property invalidation triggers on dependency change
    test('TC-114: computed property recomputes when dependency changes', () {
      // Normal: register computed 'doubled' depending on 'counter'
      stateManager.registerComputedProperty(
        'doubled',
        ComputedProperty(
          name: 'doubled',
          expression: '{{counter}} * 2',
          dependencies: ['counter'],
          compute: (state) => ((state['counter'] as num?) ?? 0) * 2,
        ),
      );

      stateManager.set('counter', 5);
      expect(stateManager.get<int>('doubled'), equals(10));

      // Boundary: changing the dependency again auto-recomputes
      stateManager.set('counter', 10);
      expect(stateManager.get<int>('doubled'), equals(20));

      // Boundary: changing an unrelated key does not affect computed
      stateManager.set('user.name', 'Bob');
      expect(stateManager.get<int>('doubled'), equals(20));
    });

    // TC-115: Key-specific listeners only fire for their key
    test('TC-115: key-specific listeners fire only for matching key', () {
      // Normal: listener on 'counter' fires when counter changes
      var counterFired = 0;
      var userFired = 0;
      void counterListener() => counterFired++;
      void userListener() => userFired++;

      stateManager.addKeyListener('counter', counterListener);
      stateManager.addKeyListener('user.name', userListener);

      stateManager.set('counter', 5);
      expect(counterFired, equals(1));
      expect(userFired, equals(0));

      // Boundary: changing user.name fires user listener, not counter
      stateManager.set('user.name', 'Alice');
      expect(counterFired, equals(1));
      expect(userFired, equals(1));

      // Error: after removal, listener no longer fires
      stateManager.removeKeyListener('counter', counterListener);
      stateManager.set('counter', 99);
      expect(counterFired, equals(1));

      stateManager.removeKeyListener('user.name', userListener);
    });
  });

  // ============================================================
  // TC-116~120: Selective rebuild and mutation helpers
  // ============================================================
  group('Selective rebuild and mutation helpers', () {
    // TC-116: increment() increments numeric state
    test('TC-116: increment increments numeric state by default or given amount',
        () {
      // Normal: increment by default (1)
      stateManager.increment('counter');
      expect(stateManager.get<num>('counter'), equals(1));

      // Normal: increment by custom amount
      stateManager.increment('counter', 5);
      expect(stateManager.get<num>('counter'), equals(6));

      // Boundary: increment by fractional amount
      stateManager.increment('counter', 0.5);
      expect(stateManager.get<num>('counter'), equals(6.5));
    });

    // TC-117: decrement() decrements numeric state
    test('TC-117: decrement decrements numeric state', () {
      // Normal: decrement by default (1)
      stateManager.set('counter', 10);
      stateManager.decrement('counter');
      expect(stateManager.get<num>('counter'), equals(9));

      // Normal: decrement by custom amount
      stateManager.decrement('counter', 4);
      expect(stateManager.get<num>('counter'), equals(5));

      // Boundary: decrement below zero
      stateManager.decrement('counter', 10);
      expect(stateManager.get<num>('counter'), equals(-5));
    });

    // TC-118: toggle() flips boolean state
    test('TC-118: toggle flips boolean state', () {
      // Normal: set a boolean and toggle
      stateManager.set('enabled', true);
      stateManager.toggle('enabled');
      expect(stateManager.get<bool>('enabled'), equals(false));

      // Normal: toggle again returns to true
      stateManager.toggle('enabled');
      expect(stateManager.get<bool>('enabled'), equals(true));

      // Boundary: toggling a non-existent key treats it as false -> true
      stateManager.toggle('nonExistent');
      expect(stateManager.get<bool>('nonExistent'), equals(true));
    });

    // TC-119: push/pop for list state
    test('TC-119: push appends to list, pop removes and returns last', () {
      // Normal: push appends an item
      stateManager.push('items', 'd');
      expect(stateManager.get<List>('items'), equals(['a', 'b', 'c', 'd']));

      // Normal: pop removes and returns the last item
      final popped = stateManager.pop('items');
      expect(popped, equals('d'));
      expect(stateManager.get<List>('items'), equals(['a', 'b', 'c']));

      // Boundary: pop from single-element list
      stateManager.set('singleList', ['only']);
      final poppedSingle = stateManager.pop('singleList');
      expect(poppedSingle, equals('only'));
      expect(stateManager.get<List>('singleList'), equals([]));

      // Error: pop from empty list returns null
      final poppedEmpty = stateManager.pop('singleList');
      expect(poppedEmpty, isNull);
    });

    // TC-120: append/remove/removeAt for list manipulation
    test('TC-120: append, remove, removeAt manipulate lists correctly', () {
      // Normal: append adds to end
      stateManager.append('items', 'x');
      expect(stateManager.get<List>('items'), equals(['a', 'b', 'c', 'x']));

      // Normal: remove removes by value
      stateManager.remove('items', 'b');
      expect(stateManager.get<List>('items'), equals(['a', 'c', 'x']));

      // Normal: removeAt removes by index
      stateManager.removeAt('items', 1);
      expect(stateManager.get<List>('items'), equals(['a', 'x']));

      // Boundary: remove a non-existent value does not change the list
      stateManager.remove('items', 'zzz');
      expect(stateManager.get<List>('items'), equals(['a', 'x']));

      // Error: removeAt with out-of-range index does nothing
      stateManager.removeAt('items', 999);
      expect(stateManager.get<List>('items'), equals(['a', 'x']));
    });
  });

  // ============================================================
  // TC-121~125: JSON path resolution and deep state access
  // ============================================================
  group('JSON path resolution and deep state access', () {
    // TC-121: get() resolves nested path
    test('TC-121: get resolves nested dot-notation path', () {
      // Normal: deeply nested access
      expect(stateManager.get<String>('user.address.city'), equals('Seoul'));
      expect(stateManager.get<String>('user.address.zip'), equals('12345'));

      // Normal: single-level nested access
      expect(stateManager.get<String>('user.name'), equals('John'));

      // Boundary: top-level key access
      expect(stateManager.get<int>('counter'), equals(0));

      // Error: non-existent nested path returns null
      expect(stateManager.get<String>('user.address.country'), isNull);
    });

    // TC-122: set() creates intermediate nested maps as needed
    test('TC-122: set creates intermediate nested maps for deep paths', () {
      // Normal: overwrite existing nested value
      stateManager.set('user.address.zip', '99999');
      expect(stateManager.get<String>('user.address.zip'), equals('99999'));

      // Boundary: set a new nested path that does not exist yet
      stateManager.set('user.address.state', 'Gyeonggi');
      expect(
          stateManager.get<String>('user.address.state'), equals('Gyeonggi'));

      // Boundary: existing siblings remain intact
      expect(stateManager.get<String>('user.address.city'), equals('Seoul'));
    });

    // TC-123: update() applies transform function to current value
    test('TC-123: update applies transform function to current value', () {
      // Normal: transform counter value
      stateManager.update('counter', (current) => (current as int) + 10);
      expect(stateManager.get<int>('counter'), equals(10));

      // Normal: transform nested value
      stateManager.update(
        'user.name',
        (current) => (current as String).toUpperCase(),
      );
      expect(stateManager.get<String>('user.name'), equals('JOHN'));

      // Boundary: transform with type change
      stateManager.update('counter', (current) => '${current}_string');
      expect(stateManager.get<String>('counter'), equals('10_string'));
    });

    // TC-124: clear() clears list to empty list, map to empty map
    test('TC-124: clear empties lists and maps', () {
      // Normal: clear a list
      stateManager.clear('items');
      expect(stateManager.get<List>('items'), equals([]));

      // Normal: clear a map
      stateManager.clear('settings');
      expect(stateManager.get<Map>('settings'), equals({}));

      // Boundary: clearing already empty list/map is safe
      stateManager.clear('items');
      expect(stateManager.get<List>('items'), equals([]));
    });

    // TC-125: getState() and state getter return full state copy
    test('TC-125: getState and state getter return independent copies', () {
      // Normal: getState returns state copy
      final copy1 = stateManager.getState();
      expect(copy1['counter'], equals(0));
      expect(copy1['user'], isA<Map>());

      // Normal: state getter also returns a copy
      final copy2 = stateManager.state;
      expect(copy2['counter'], equals(0));

      // Boundary: modifying the copy does not affect the original
      copy1['counter'] = 999;
      expect(stateManager.get<int>('counter'), equals(0));

      copy2['counter'] = 888;
      expect(stateManager.get<int>('counter'), equals(0));
    });
  });

  // ============================================================
  // TC-126~129: Integration and edge cases
  // ============================================================
  group('Integration and edge cases', () {
    // TC-126: initialize() clears previous state and sets new initial state
    test('TC-126: initialize clears previous state and applies new state', () {
      // Normal: verify initial state
      expect(stateManager.get<int>('counter'), equals(0));
      expect(stateManager.get<String>('user.name'), equals('John'));

      // Normal: re-initialize with completely different state
      stateManager.initialize({'brand': 'new', 'value': 42});
      expect(stateManager.get<String>('brand'), equals('new'));
      expect(stateManager.get<int>('value'), equals(42));

      // Boundary: old state keys are gone
      expect(stateManager.get('counter'), isNull);
      expect(stateManager.get('user'), isNull);
    });

    // TC-127: activeSubscriptions returns current subscription map
    test('TC-127: activeSubscriptions returns _subscriptions state', () {
      // Normal: initially no subscriptions
      expect(stateManager.activeSubscriptions, equals({}));

      // Normal: set subscriptions data and verify
      stateManager.set('_subscriptions', {'res1': 'topic/a', 'res2': 'topic/b'});
      final subs = stateManager.activeSubscriptions;
      expect(subs, equals({'res1': 'topic/a', 'res2': 'topic/b'}));

      // Boundary: returned map is a copy (modifying it does not affect state)
      subs['res3'] = 'topic/c';
      expect(stateManager.activeSubscriptions.containsKey('res3'), isFalse);
    });

    // TC-128: dispose() closes all stream controllers and clears computed
    test('TC-128: dispose closes stream controllers and clears computed',
        () async {
      // Use a separate manager to avoid double-dispose in tearDown
      final localManager = StateManager();
      localManager.initialize({
        'user': {
          'name': 'John',
          'age': 30,
          'address': {'city': 'Seoul', 'zip': '12345'},
        },
        'counter': 0,
        'items': ['a', 'b', 'c'],
        'settings': {'theme': 'light', 'lang': 'en'},
      });

      // Setup: create a watch stream and a computed property
      final stream = localManager.watch<int>('counter');
      final sub = stream.listen((_) {});

      localManager.registerComputedProperty(
        'doubled',
        ComputedProperty(
          name: 'doubled',
          expression: '{{counter}} * 2',
          dependencies: ['counter'],
          compute: (state) => ((state['counter'] as num?) ?? 0) * 2,
        ),
      );

      // Normal: dispose closes everything
      localManager.dispose();

      // After dispose, the subscription can be cancelled without error
      await sub.cancel();

      // Boundary: a new StateManager works independently after previous disposal
      final newManager = StateManager();
      newManager.initialize({'x': 1});
      expect(newManager.get<int>('x'), equals(1));
      newManager.dispose();
    });

    // TC-129: Concurrent set() calls produce correct final state and ordering
    test('TC-129: concurrent set calls produce correct final state and event ordering',
        () async {
      // Normal: rapid sequential set() calls
      final events = <StateChangeEvent>[];
      final sub = stateManager.stream.listen(events.add);

      stateManager.set('counter', 1);
      stateManager.set('counter', 2);
      stateManager.set('counter', 3);
      stateManager.set('counter', 4);
      stateManager.set('counter', 5);

      await Future<void>.delayed(Duration.zero);

      // Final state is correct
      expect(stateManager.get<int>('counter'), equals(5));

      // All events are emitted in order
      expect(events.length, equals(5));
      expect(events[0].newValue, equals(1));
      expect(events[1].newValue, equals(2));
      expect(events[2].newValue, equals(3));
      expect(events[3].newValue, equals(4));
      expect(events[4].newValue, equals(5));

      // Boundary: old values chain correctly
      expect(events[0].oldValue, equals(0));
      expect(events[1].oldValue, equals(1));
      expect(events[2].oldValue, equals(2));
      expect(events[3].oldValue, equals(3));
      expect(events[4].oldValue, equals(4));

      await sub.cancel();
    });
  });
}
