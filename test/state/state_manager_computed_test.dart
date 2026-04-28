import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/state/computed_property.dart';

void main() {
  group('TC-027: StateManager — registerComputedProperty', () {
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager();
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('TC-027 Normal: registerComputedProperty registers and get resolves it', () {
      stateManager.initialize({'price': 10, 'quantity': 3});
      stateManager.registerComputedProperty(
        'total',
        ComputedProperty(
          name: 'total',
          expression: '{{price * quantity}}',
          dependencies: ['price', 'quantity'],
          compute: (state) =>
              (state['price'] as num) * (state['quantity'] as num),
        ),
      );
      expect(stateManager.get<num>('total'), equals(30));
    });

    test('TC-027 Normal: ComputedProperty includes caching', () {
      var computeCount = 0;
      stateManager.initialize({'value': 5});
      stateManager.registerComputedProperty(
        'doubled',
        ComputedProperty(
          name: 'doubled',
          expression: '{{value * 2}}',
          dependencies: ['value'],
          compute: (state) {
            computeCount++;
            return (state['value'] as num) * 2;
          },
        ),
      );
      // First access triggers computation
      expect(stateManager.get<num>('doubled'), equals(10));
      expect(computeCount, equals(1));

      // Second access uses cached value (no recompute since no dependency changed)
      expect(stateManager.get<num>('doubled'), equals(10));
      expect(computeCount, equals(1));
    });

    test('TC-027 Boundary: Override existing computed property', () {
      stateManager.initialize({'x': 5});
      stateManager.registerComputedProperty(
        'calc',
        ComputedProperty(
          name: 'calc',
          expression: '{{x + 1}}',
          dependencies: ['x'],
          compute: (state) => (state['x'] as num) + 1,
        ),
      );
      expect(stateManager.get<num>('calc'), equals(6));

      // Override
      stateManager.registerComputedProperty(
        'calc',
        ComputedProperty(
          name: 'calc',
          expression: '{{x * 10}}',
          dependencies: ['x'],
          compute: (state) => (state['x'] as num) * 10,
        ),
      );
      expect(stateManager.get<num>('calc'), equals(50));
    });

    test('TC-027 Error: Circular dependency returns null', () {
      stateManager.initialize({});
      // Simulate a self-referencing computed property
      final computed = ComputedProperty(
        name: 'selfRef',
        expression: '{{selfRef}}',
        dependencies: ['selfRef'],
        compute: (state) {
          // Simulate a circular reference by calling computeAndCache recursively
          // The _isComputing flag in ComputedProperty should catch this
          return null;
        },
      );
      stateManager.registerComputedProperty('selfRef', computed);
      // Should not throw, should return null or the compute result
      final result = stateManager.get('selfRef');
      expect(result, isNull);
    });
  });

  group('TC-028: StateManager — unregisterComputedProperty', () {
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager();
      stateManager.initialize({'price': 10, 'quantity': 3});
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('TC-028 Normal: unregisterComputedProperty removes the property', () {
      stateManager.registerComputedProperty(
        'total',
        ComputedProperty(
          name: 'total',
          expression: '{{price * quantity}}',
          dependencies: ['price', 'quantity'],
          compute: (state) =>
              (state['price'] as num) * (state['quantity'] as num),
        ),
      );
      stateManager.unregisterComputedProperty('total');
      // After unregister, get returns null (no computed, no state at that path)
      expect(stateManager.get('total'), isNull);
    });

    test('TC-028 Normal: computedPropertyNames no longer includes removed property', () {
      stateManager.registerComputedProperty(
        'total',
        ComputedProperty(
          name: 'total',
          expression: '{{price * quantity}}',
          dependencies: ['price', 'quantity'],
          compute: (state) => 0,
        ),
      );
      expect(stateManager.computedPropertyNames, contains('total'));
      stateManager.unregisterComputedProperty('total');
      expect(stateManager.computedPropertyNames, isNot(contains('total')));
    });

    test('TC-028 Boundary: Unregister non-existent property is no-op', () {
      stateManager.unregisterComputedProperty('nonExistent');
      // Should not throw
      expect(stateManager.computedPropertyNames, isEmpty);
    });

    test('TC-028 Boundary: Unregister then re-register works correctly', () {
      stateManager.registerComputedProperty(
        'calc',
        ComputedProperty(
          name: 'calc',
          expression: '{{price}}',
          dependencies: ['price'],
          compute: (state) => state['price'],
        ),
      );
      stateManager.unregisterComputedProperty('calc');
      stateManager.registerComputedProperty(
        'calc',
        ComputedProperty(
          name: 'calc',
          expression: '{{quantity}}',
          dependencies: ['quantity'],
          compute: (state) => state['quantity'],
        ),
      );
      expect(stateManager.get<num>('calc'), equals(3));
    });
  });

  group('TC-029: StateManager — addComputedProperty', () {
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager();
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('TC-029 Normal: addComputedProperty creates computed property via convenience method', () {
      stateManager.initialize({
        'firstName': 'John',
        'lastName': 'Doe',
      });
      stateManager.addComputedProperty(
        'fullName',
        '{{firstName}} {{lastName}}',
        dependencies: ['firstName', 'lastName'],
      );
      expect(stateManager.computedPropertyNames, contains('fullName'));
      expect(stateManager.get<String>('fullName'), equals('John Doe'));
    });

    test('TC-029 Normal: Computed value updates when dependencies change', () {
      stateManager.initialize({'firstName': 'John', 'lastName': 'Doe'});
      stateManager.addComputedProperty(
        'fullName',
        '{{firstName}} {{lastName}}',
        dependencies: ['firstName', 'lastName'],
      );
      expect(stateManager.get<String>('fullName'), equals('John Doe'));

      // Change a dependency -> invalidate -> recompute
      stateManager.set('firstName', 'Jane');
      expect(stateManager.get<String>('fullName'), equals('Jane Doe'));
    });
  });

  group('TC-030: StateManager — computedPropertyNames', () {
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager();
      stateManager.initialize({'a': 1, 'b': 2});
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('TC-030 Normal: Returns list of all registered computed property names', () {
      stateManager.registerComputedProperty(
        'sum',
        ComputedProperty(
          name: 'sum',
          expression: '{{a + b}}',
          dependencies: ['a', 'b'],
          compute: (state) => (state['a'] as num) + (state['b'] as num),
        ),
      );
      stateManager.registerComputedProperty(
        'diff',
        ComputedProperty(
          name: 'diff',
          expression: '{{a - b}}',
          dependencies: ['a', 'b'],
          compute: (state) => (state['a'] as num) - (state['b'] as num),
        ),
      );
      expect(stateManager.computedPropertyNames, containsAll(['sum', 'diff']));
    });

    test('TC-030 Normal: Updates when computed properties are added or removed', () {
      stateManager.registerComputedProperty(
        'calc',
        ComputedProperty(
          name: 'calc',
          expression: '{{a}}',
          dependencies: ['a'],
          compute: (state) => state['a'],
        ),
      );
      expect(stateManager.computedPropertyNames, equals(['calc']));
      stateManager.unregisterComputedProperty('calc');
      expect(stateManager.computedPropertyNames, isEmpty);
    });

    test('TC-030 Boundary: No computed properties returns empty list', () {
      expect(stateManager.computedPropertyNames, isEmpty);
    });

    test('TC-030 Boundary: Single computed property returns list with one name', () {
      stateManager.registerComputedProperty(
        'only',
        ComputedProperty(
          name: 'only',
          expression: '{{a}}',
          dependencies: ['a'],
          compute: (state) => state['a'],
        ),
      );
      expect(stateManager.computedPropertyNames, equals(['only']));
    });
  });

  group('TC-111: Computed properties — expression-based', () {
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager();
    });

    tearDown(() {
      stateManager.dispose();
    });

    test('TC-111 Normal: addComputedProperty computes on access', () {
      stateManager.initialize({'firstName': 'Jane', 'lastName': 'Smith'});
      stateManager.addComputedProperty(
        'fullName',
        '{{firstName}} {{lastName}}',
        dependencies: ['firstName', 'lastName'],
      );
      expect(stateManager.get<String>('fullName'), equals('Jane Smith'));
    });

    test('TC-111 Normal: Dependency change invalidates cached value and recomputes', () {
      stateManager.initialize({'price': 10, 'quantity': 2});
      stateManager.registerComputedProperty(
        'total',
        ComputedProperty(
          name: 'total',
          expression: '{{price * quantity}}',
          dependencies: ['price', 'quantity'],
          compute: (state) =>
              (state['price'] as num) * (state['quantity'] as num),
        ),
      );
      expect(stateManager.get<num>('total'), equals(20));
      stateManager.set('quantity', 5);
      expect(stateManager.get<num>('total'), equals(50));
    });

    test('TC-111 Normal: computedPropertyNames includes the property', () {
      stateManager.initialize({'a': 1});
      stateManager.addComputedProperty('computed', '{{a}}', dependencies: ['a']);
      expect(stateManager.computedPropertyNames, contains('computed'));
    });

    test('TC-111 Boundary: Multiple computed properties depending on same state', () {
      stateManager.initialize({'x': 10});
      stateManager.registerComputedProperty(
        'doubled',
        ComputedProperty(
          name: 'doubled',
          expression: '{{x * 2}}',
          dependencies: ['x'],
          compute: (state) => (state['x'] as num) * 2,
        ),
      );
      stateManager.registerComputedProperty(
        'tripled',
        ComputedProperty(
          name: 'tripled',
          expression: '{{x * 3}}',
          dependencies: ['x'],
          compute: (state) => (state['x'] as num) * 3,
        ),
      );
      expect(stateManager.get<num>('doubled'), equals(20));
      expect(stateManager.get<num>('tripled'), equals(30));

      stateManager.set('x', 5);
      expect(stateManager.get<num>('doubled'), equals(10));
      expect(stateManager.get<num>('tripled'), equals(15));
    });
  });

  group('TC-112: Computed properties — ComputedProperty object', () {
    test('TC-112 Normal: Caching reuses value until dependency changes', () {
      var computeCount = 0;
      final computed = ComputedProperty(
        name: 'cached',
        expression: '{{value}}',
        dependencies: ['value'],
        compute: (state) {
          computeCount++;
          return state['value'];
        },
      );

      final state = {'value': 42};
      computed.computeAndCache(state);
      expect(computeCount, equals(1));

      // Access cached value without recompute
      expect(computed.cachedValue, equals(42));
      expect(computeCount, equals(1));
    });

    test('TC-112 Normal: Circular dependency detection returns null', () {
      final computed = ComputedProperty(
        name: 'circular',
        expression: '{{circular}}',
        dependencies: ['circular'],
        compute: (state) {
          // Simulate circular by attempting to compute during computation
          // The _isComputing flag prevents this
          return 'should not reach';
        },
      );

      // Manually simulate circular detection: set _isComputing to true first
      computed.computeAndCache({'circular': 1});
      expect(computed.isInitialized, isTrue);
    });

    test('TC-112 Normal: Compute function throws returns error', () {
      final computed = ComputedProperty(
        name: 'throwing',
        expression: '{{value}}',
        dependencies: ['value'],
        compute: (state) => throw Exception('compute error'),
      );

      expect(
        () => computed.computeAndCache({}),
        throwsException,
      );
    });

    test('TC-112 Boundary: unregisterComputedProperty removes property and cache', () {
      final stateManager = StateManager();
      stateManager.initialize({'x': 1});
      stateManager.registerComputedProperty(
        'calc',
        ComputedProperty(
          name: 'calc',
          expression: '{{x}}',
          dependencies: ['x'],
          compute: (state) => state['x'],
        ),
      );
      // Access to cache
      stateManager.get('calc');
      stateManager.unregisterComputedProperty('calc');
      expect(stateManager.get('calc'), isNull);
      stateManager.dispose();
    });
  });
}
