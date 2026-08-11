// The transforms and functions on `ComputedProperty`'s own evaluator.
//
// Its sibling file covers the expression grammar; this covers what comes after
// the pipe, and the two functions the evaluator carries. Same standing hazard:
// there are two evaluators for one language, so each answer here is written
// down as the answer, not as whatever this one happens to do.

import 'package:flutter_mcp_ui_runtime/src/state/computed_property.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  dynamic evaluate(String expression, [Map<String, dynamic> state = const {}]) =>
      ComputedProperty.fromExpression('probe', expression).compute(state);

  group('pipe transforms', () {
    test('uppercase, lowercase and capitalize', () {
      const state = {'name': 'ada lovelace'};

      expect(evaluate('{{name | uppercase}}', state), 'ADA LOVELACE');
      expect(evaluate('{{name | lowercase}}', {'name': 'ADA'}), 'ada');
      expect(evaluate('{{name | capitalize}}', state), 'Ada lovelace');
    });

    test('capitalize on an empty string is an empty string, not a crash', () {
      expect(evaluate('{{name | capitalize}}', {'name': ''}), '');
    });

    test('round, floor, ceil and abs', () {
      const state = {'value': -2.6};

      expect(evaluate('{{value | round}}', state), -3);
      expect(evaluate('{{value | floor}}', state), -3);
      expect(evaluate('{{value | ceil}}', state), -2);
      expect(evaluate('{{value | abs}}', state), 2.6);
    });

    test('a numeric transform parses a numeric string', () {
      expect(evaluate('{{value | round}}', {'value': '2.4'}), 2,
          reason: 'a number that arrived from a text field or a JSON string '
              'is still a number to the author');
    });

    test('a numeric transform on something that is not a number is null', () {
      expect(evaluate('{{value | round}}', {'value': 'ada'}), isNull);
    });

    test('an unknown transform leaves the value alone', () {
      expect(evaluate('{{name | reverse}}', {'name': 'ada'}), 'ada');
    });

    test('transforms chain left to right', () {
      expect(evaluate('{{name | uppercase | lowercase}}', {'name': 'Ada'}),
          'ada');
    });
  });

  group('functions', () {
    test('length counts a list, a map and a string', () {
      expect(evaluate('{{length(rows)}}', {
        'rows': [1, 2, 3],
      }), 3);
      expect(evaluate('{{length(row)}}', {
        'row': {'a': 1, 'b': 2},
      }), 2);
      expect(evaluate('{{length(name)}}', {'name': 'ada'}), 3);
    });

    test('length of something with no length is zero', () {
      expect(evaluate('{{length(count)}}', {'count': 7}), 0);
    });

    test('sum adds the numbers in a list', () {
      expect(evaluate('{{sum(values)}}', {
        'values': [1, 2, 3.5],
      }), 6.5);
    });

    test('sum ignores what is not a number rather than failing', () {
      expect(evaluate('{{sum(values)}}', {
        'values': [1, 'two', 3],
      }), 4.0,
          reason: 'one bad row in a fetched list must not blank the total');
    });

    test('sum by property adds one field across the rows', () {
      expect(evaluate('{{sum(rows, "price")}}', {
        'rows': [
          {'price': 10},
          {'price': 5.5},
          {'price': 'free'},
        ],
      }), 15.5);
    });

    test('sum of something that is not a list is zero', () {
      expect(evaluate('{{sum(total)}}', {'total': 7}), 0);
    });

    test('an unknown function answers null rather than the literal text', () {
      expect(evaluate('{{median(values)}}', {
        'values': [1, 2, 3],
      }), isNull);
    });
  });

  group('caching and recomputation', () {
    test('a property computes once and serves the cached value', () {
      var computations = 0;
      final property = ComputedProperty(
        name: 'doubled',
        expression: '{{count * 2}}',
        dependencies: const ['count'],
        compute: (state) {
          computations++;
          return (state['count'] as int) * 2;
        },
      );

      expect(property.isInitialized, isFalse);
      expect(property.computeAndCache({'count': 2}), 4);
      expect(property.cachedValue, 4);
      expect(property.isInitialized, isTrue);
      expect(computations, 1);
    });

    test('invalidating makes it compute again', () {
      var computations = 0;
      final property = ComputedProperty(
        name: 'doubled',
        expression: '{{count * 2}}',
        compute: (state) {
          computations++;
          return (state['count'] as int) * 2;
        },
      );

      property.computeAndCache({'count': 2});
      property.invalidate();
      property.computeAndCache({'count': 5});

      expect(property.cachedValue, 10);
      expect(computations, 2,
          reason: 'a cache that never invalidates is a value frozen at the '
              'first render');
    });

    test('a self-referencing property answers null instead of recursing', () {
      late ComputedProperty property;
      property = ComputedProperty(
        name: 'loop',
        expression: '{{loop}}',
        compute: (state) => property.computeAndCache(state),
      );

      expect(property.computeAndCache(<String, dynamic>{}), isNull,
          reason: 'the alternative is a stack overflow with the document\'s '
              'own property name nowhere in it');
    });

    test('a compute that throws is logged and passed on, not swallowed', () {
      // The expression evaluator is defensive on its own, so a throw here can
      // only come from a compute function the HOST supplied — and swallowing
      // that would hide a host bug behind a blank value.
      final property = ComputedProperty(
        name: 'bad',
        expression: '{{missing.deep}}',
        compute: (state) => (state['missing'] as Map)['deep'],
      );

      expect(() => property.computeAndCache(<String, dynamic>{}), throwsA(anything));
      expect(property.isInitialized, isFalse,
          reason: 'a failed computation must not leave a half-written value '
              'behind for the next reader');
    });

    test('a throw does not leave the property stuck as "computing"', () {
      var attempts = 0;
      final property = ComputedProperty(
        name: 'flaky',
        expression: '{{count}}',
        compute: (state) {
          attempts++;
          if (attempts == 1) throw StateError('first attempt fails');
          return state['count'];
        },
      );

      expect(() => property.computeAndCache({'count': 1}), throwsStateError);
      expect(property.computeAndCache({'count': 2}), 2,
          reason: 'the in-progress flag is cleared in a finally; without that '
              'every later read would be answered as a circular dependency');
    });
  });
}
