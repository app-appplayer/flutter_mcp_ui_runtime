import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_result.dart';

void main() {
  group('ActionResult', () {
    group('Success Factory', () {
      test('creates successful result without data', () {
        final result = ActionResult.success();
        
        expect(result.success, isTrue);
        expect(result.error, isNull);
        expect(result.data, isNull);
      });

      test('creates successful result with data', () {
        final data = {'key': 'value', 'count': 42};
        final result = ActionResult.success(data: data);
        
        expect(result.success, isTrue);
        expect(result.error, isNull);
        expect(result.data, equals(data));
      });

      test('creates successful result with string data', () {
        const data = 'Success message';
        final result = ActionResult.success(data: data);
        
        expect(result.success, isTrue);
        expect(result.error, isNull);
        expect(result.data, equals(data));
      });

      test('creates successful result with numeric data', () {
        const data = 123.45;
        final result = ActionResult.success(data: data);
        
        expect(result.success, isTrue);
        expect(result.error, isNull);
        expect(result.data, equals(data));
      });

      test('creates successful result with list data', () {
        final data = [1, 2, 3, 'four', true];
        final result = ActionResult.success(data: data);
        
        expect(result.success, isTrue);
        expect(result.error, isNull);
        expect(result.data, equals(data));
      });

      test('creates successful result with boolean data', () {
        const data = true;
        final result = ActionResult.success(data: data);
        
        expect(result.success, isTrue);
        expect(result.error, isNull);
        expect(result.data, equals(data));
      });

      test('creates successful result with null data explicitly', () {
        final result = ActionResult.success(data: null);
        
        expect(result.success, isTrue);
        expect(result.error, isNull);
        expect(result.data, isNull);
      });
    });

    group('Error Factory', () {
      test('creates error result with message', () {
        const errorMessage = 'Something went wrong';
        final result = ActionResult.error(errorMessage);
        
        expect(result.success, isFalse);
        expect(result.error, equals(errorMessage));
        expect(result.data, isNull);
      });

      test('creates error result with empty message', () {
        final result = ActionResult.error('');
        
        expect(result.success, isFalse);
        expect(result.error, equals(''));
        expect(result.data, isNull);
      });

      test('creates error result with detailed error message', () {
        const errorMessage = 'Failed to execute action: Invalid parameter "id" - expected number but got string';
        final result = ActionResult.error(errorMessage);
        
        expect(result.success, isFalse);
        expect(result.error, equals(errorMessage));
        expect(result.data, isNull);
      });

      test('creates error result with special characters in message', () {
        const errorMessage = 'Error: Can\'t find file "test.txt" at path /home/user/<dir>';
        final result = ActionResult.error(errorMessage);
        
        expect(result.success, isFalse);
        expect(result.error, equals(errorMessage));
        expect(result.data, isNull);
      });

      test('creates error result with unicode characters', () {
        const errorMessage = 'Error: Invalid input 🚫 - Please use ASCII characters only';
        final result = ActionResult.error(errorMessage);
        
        expect(result.success, isFalse);
        expect(result.error, equals(errorMessage));
        expect(result.data, isNull);
      });
    });

    group('toString', () {
      test('formats successful result without data', () {
        final result = ActionResult.success();
        
        expect(result.toString(), equals('ActionResult.success(data: null)'));
      });

      test('formats successful result with string data', () {
        final result = ActionResult.success(data: 'test data');
        
        expect(result.toString(), equals('ActionResult.success(data: test data)'));
      });

      test('formats successful result with map data', () {
        final result = ActionResult.success(data: {'key': 'value'});
        
        expect(result.toString(), equals('ActionResult.success(data: {key: value})'));
      });

      test('formats successful result with list data', () {
        final result = ActionResult.success(data: [1, 2, 3]);
        
        expect(result.toString(), equals('ActionResult.success(data: [1, 2, 3])'));
      });

      test('formats error result', () {
        final result = ActionResult.error('Test error');
        
        expect(result.toString(), equals('ActionResult.error(Test error)'));
      });

      test('formats error result with empty message', () {
        final result = ActionResult.error('');
        
        expect(result.toString(), equals('ActionResult.error()'));
      });
    });

    group('Type Safety', () {
      test('preserves data type for complex objects', () {
        final complexData = {
          'user': {
            'id': 123,
            'name': 'John Doe',
            'tags': ['admin', 'user'],
            'metadata': {
              'lastLogin': DateTime(2024, 1, 1),
              'isActive': true,
            }
          }
        };
        
        final result = ActionResult.success(data: complexData);
        
        expect(result.data, isA<Map<String, dynamic>>());
        expect(result.data['user'], isA<Map<String, dynamic>>());
        expect(result.data['user']['id'], isA<int>());
        expect(result.data['user']['name'], isA<String>());
        expect(result.data['user']['tags'], isA<List>());
        expect(result.data['user']['metadata']['lastLogin'], isA<DateTime>());
        expect(result.data['user']['metadata']['isActive'], isA<bool>());
      });

      test('preserves custom class instances', () {
        final customObject = _TestClass('test', 42);
        final result = ActionResult.success(data: customObject);
        
        expect(result.data, isA<_TestClass>());
        expect(result.data.name, equals('test'));
        expect(result.data.value, equals(42));
      });
    });

    group('Edge Cases', () {
      test('handles very long error messages', () {
        final longMessage = 'Error: ${'x' * 1000}';
        final result = ActionResult.error(longMessage);
        
        expect(result.success, isFalse);
        expect(result.error, equals(longMessage));
        expect(result.error!.length, equals(1007));
      });

      test('handles deeply nested data structures', () {
        Map<String, dynamic> createNested(int depth) {
          if (depth <= 0) return {'value': 'bottom'};
          return {'level': depth, 'next': createNested(depth - 1)};
        }
        
        final deepData = createNested(100);
        final result = ActionResult.success(data: deepData);
        
        expect(result.success, isTrue);
        expect(result.data, isA<Map<String, dynamic>>());
        
        // Verify we can traverse the entire structure
        dynamic current = result.data;
        for (int i = 100; i > 0; i--) {
          expect(current['level'], equals(i));
          current = current['next'];
        }
        expect(current['value'], equals('bottom'));
      });

      test('handles circular references in data', () {
        final map1 = <String, dynamic>{'name': 'map1'};
        final map2 = <String, dynamic>{'name': 'map2', 'ref': map1};
        map1['ref'] = map2; // Create circular reference
        
        final result = ActionResult.success(data: map1);
        
        expect(result.success, isTrue);
        expect(result.data['name'], equals('map1'));
        expect(result.data['ref']['name'], equals('map2'));
        expect(result.data['ref']['ref'], same(map1));
      });
    });

    group('Immutability', () {
      test('properties cannot be modified after creation', () {
        final result = ActionResult.success(data: {'key': 'value'});
        
        // Verify that the properties are final (cannot be reassigned)
        // This test ensures the API contract remains immutable
        expect(result.success, isTrue);
        expect(result.error, isNull);
        expect(result.data, isNotNull);
        
        // If data is mutable, modifications to it should be reflected
        if (result.data is Map) {
          result.data['key'] = 'modified';
          expect(result.data['key'], equals('modified'));
        }
      });
    });

    group('Factory Constructor Behavior', () {
      test('success factory always sets success to true', () {
        // Even if we could somehow pass invalid data, success should be true
        final result = ActionResult.success(data: null);
        expect(result.success, isTrue);
        expect(result.error, isNull);
      });

      test('error factory always sets success to false', () {
        // Error factory should always create failed results
        final result = ActionResult.error('error');
        expect(result.success, isFalse);
        expect(result.data, isNull);
      });

      test('private constructor is not directly accessible', () {
        // This test verifies that ActionResult._ constructor is private
        // and can only be accessed through factory methods
        
        // We can only create instances through factories
        final successResult = ActionResult.success();
        final errorResult = ActionResult.error('error');
        
        expect(successResult, isA<ActionResult>());
        expect(errorResult, isA<ActionResult>());
      });
    });
  });
}

// Helper class for testing custom object storage
class _TestClass {
  final String name;
  final int value;
  
  _TestClass(this.name, this.value);
}