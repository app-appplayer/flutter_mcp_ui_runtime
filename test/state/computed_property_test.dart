import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/state/computed_property.dart';

void main() {
  group('ComputedProperty Tests', () {
    group('Basic Functionality', () {
      test('should create computed property with expression', () {
        final computed = ComputedProperty(
          name: 'total',
          expression: 'total',
          compute: (state) => (state['price'] ?? 0) * (state['quantity'] ?? 0),
          dependencies: ['price', 'quantity'],
        );

        expect(computed.expression, equals('total'));
        expect(computed.dependencies, equals(['price', 'quantity']));
        expect(computed.isInitialized, isFalse);
      });

      test('should compute and cache value', () {
        final computed = ComputedProperty(
          name: 'fullName',
          expression: 'fullName',
          compute: (state) => '${state['firstName']} ${state['lastName']}',
          dependencies: ['firstName', 'lastName'],
        );

        final state = {
          'firstName': 'John',
          'lastName': 'Doe',
        };

        final result = computed.computeAndCache(state);
        expect(result, equals('John Doe'));
        expect(computed.cachedValue, equals('John Doe'));
        expect(computed.isInitialized, isTrue);
      });

      test('should invalidate cached value', () {
        final computed = ComputedProperty(
          name: 'sum',
          expression: 'sum',
          compute: (state) => state['a'] + state['b'],
          dependencies: ['a', 'b'],
        );

        final state = {'a': 5, 'b': 3};
        computed.computeAndCache(state);
        expect(computed.cachedValue, equals(8));

        computed.invalidate();
        expect(computed.isInitialized, isFalse);
      });

      test('should handle compute errors', () {
        final computed = ComputedProperty(
          name: 'error',
          expression: 'error',
          compute: (state) => throw Exception('Compute error'),
          dependencies: [],
        );

        expect(
          () => computed.computeAndCache({}),
          throwsException,
        );
      });
    });

    group('Dependency Detection', () {
      test('should detect when dependencies change', () {
        final computed = ComputedProperty(
          name: 'value',
          expression: 'value',
          compute: (state) => state['value'],
          dependencies: ['user.name', 'user.age', 'settings.theme'],
        );

        expect(computed.shouldRecompute({'user.name': 'old'}), isTrue);
        expect(computed.shouldRecompute({'user.age': 'old'}), isTrue);
        expect(computed.shouldRecompute({'settings.theme': 'old'}), isTrue);
        expect(computed.shouldRecompute({'other.field': 'old'}), isFalse);
      });

      test('should detect nested path changes', () {
        final computed = ComputedProperty(
          name: 'userInfo',
          expression: 'userInfo',
          compute: (state) => state['user'],
          dependencies: ['user'],
        );

        // Should recompute when child paths change
        expect(computed.shouldRecompute({'user.name': 'old'}), isTrue);
        expect(computed.shouldRecompute({'user.profile.avatar': 'old'}), isTrue);
        
        // Should not recompute for unrelated paths
        expect(computed.shouldRecompute({'settings.theme': 'old'}), isFalse);
      });

      test('should detect parent path changes', () {
        final computed = ComputedProperty(
          name: 'userName',
          expression: 'userName',
          compute: (state) => state['user']?['name'],
          dependencies: ['user.name'],
        );

        // Should recompute when parent path changes
        expect(computed.shouldRecompute({'user': 'old'}), isTrue);
        
        // Should not recompute for sibling paths
        expect(computed.shouldRecompute({'user.age': 'old'}), isFalse);
      });
    });


    group('Factory Method', () {
      test('should create from expression', () {
        final computed = ComputedProperty.fromExpression(
          'fullName',
          '{{firstName}} {{lastName}}',
        );

        expect(computed.expression, equals('{{firstName}} {{lastName}}'));
        expect(computed.dependencies, contains('firstName'));
        expect(computed.dependencies, contains('lastName'));

        final state = {
          'firstName': 'John',
          'lastName': 'Doe',
        };

        final result = computed.computeAndCache(state);
        expect(result, equals('John Doe'));
      });

      test('should create with complex expression', () {
        final computed = ComputedProperty.fromExpression(
          'itemStatus',
          '{{items.length > 0 ? "Has items" : "Empty"}}',
        );

        expect(computed.dependencies, contains('items.length'));

        final state1 = {'items': ['a', 'b', 'c']};
        expect(computed.computeAndCache(state1), equals('Has items'));

        final state2 = {'items': []};
        computed.invalidate();
        expect(computed.computeAndCache(state2), equals('Empty'));
      });
    });

    group('Edge Cases', () {
      test('should handle complex expressions through fromExpression', () {
        // Test string concatenation
        final computed1 = ComputedProperty.fromExpression(
          'fullName',
          '{{firstName + " " + lastName}}',
        );
        
        final state1 = {
          'firstName': 'John',
          'lastName': 'Doe',
        };
        
        expect(computed1.computeAndCache(state1), equals('John Doe'));

        // Test with array length
        final computed2 = ComputedProperty.fromExpression(
          'itemCount',
          '{{items.length}}',
        );
        
        final state2 = {
          'items': [1, 2, 3, 4, 5],
        };
        
        expect(computed2.computeAndCache(state2), equals(5));
      });

      test('toString should provide useful debug info', () {
        final computed = ComputedProperty(
          name: 'test',
          expression: 'test',
          compute: (state) => 'value',
          dependencies: ['a', 'b'],
        );

        final str = computed.toString();
        expect(str, contains('test'));
        expect(str, contains('[a, b]'));
        expect(str, contains('false')); // not initialized
      });
    });
  });
}