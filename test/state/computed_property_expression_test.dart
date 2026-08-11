// `ComputedProperty`'s own expression evaluator — a second, older evaluator
// living beside the binding engine, at 58% covered.
//
// Two evaluators for one language is a standing hazard: an author writes one
// expression and gets two answers depending on where it is declared. So these
// tests do double duty — they cover the evaluator, and each one states the
// answer the spec fixes, so the day the two are merged the difference is
// already written down.

import 'package:flutter_mcp_ui_runtime/src/state/computed_property.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  dynamic evaluate(String expression, Map<String, dynamic> state) =>
      ComputedProperty.fromExpression('probe', expression).compute(state);

  group('paths and literals', () {
    test('a plain path, a nested path and a missing one', () {
      final state = {
        'count': 3,
        'user': {'name': 'Ada'},
      };
      expect(evaluate('{{count}}', state), 3);
      expect(evaluate('{{user.name}}', state), 'Ada');
      expect(evaluate('{{user.missing}}', state), isNull);
      expect(evaluate('{{nothing}}', state), isNull);
    });

    test('literals evaluate to themselves', () {
      expect(evaluate('{{true}}', {}), isTrue);
      expect(evaluate('{{false}}', {}), isFalse);
      expect(evaluate('{{null}}', {}), isNull);
      expect(evaluate('{{42}}', {}), 42);
      expect(evaluate("{{'hello'}}", {}), 'hello');
    });
  });

  group('arithmetic', () {
    final state = {'a': 7, 'b': 2, 'price': 12.5};

    test('the four operations and the remainder', () {
      expect(evaluate('{{a + b}}', state), 9);
      expect(evaluate('{{a - b}}', state), 5);
      expect(evaluate('{{a * b}}', state), 14);
      expect(evaluate('{{a / b}}', state), 3.5);
      expect(evaluate('{{a % b}}', state), 1);
    });

    test('a decimal keeps its decimals', () {
      expect(evaluate('{{price * 2}}', state), 25.0);
    });

    test('string concatenation is NOT supported here, unlike the binding engine',
        () {
      // `{{'a' + 'b'}}` answers 'ab' through the binding engine and the raw
      // text through this one. Pinned as a divergence rather than quietly
      // fixed: two evaluators for one language is the standing hazard, and the
      // day they are merged this line is the list of what has to agree.
      expect(evaluate("{{'a' + 'b'}}", {}), "a' + 'b");
    });
  });

  group('comparison', () {
    final state = {'n': 5, 'name': 'Ada'};

    test('each operator answers a boolean', () {
      expect(evaluate('{{n == 5}}', state), isTrue);
      expect(evaluate('{{n != 5}}', state), isFalse);
      expect(evaluate('{{n > 3}}', state), isTrue);
      expect(evaluate('{{n < 3}}', state), isFalse);
      expect(evaluate('{{n >= 5}}', state), isTrue);
      expect(evaluate('{{n <= 4}}', state), isFalse);
    });

    test('strings compare too', () {
      expect(evaluate("{{name == 'Ada'}}", state), isTrue);
      expect(evaluate("{{name != 'Bob'}}", state), isTrue);
    });
  });

  group('logical and conditional', () {
    final state = {'yes': true, 'no': false, 'n': 5};

    test('&& and || read both sides', () {
      expect(evaluate('{{yes && yes}}', state), isTrue);
      expect(evaluate('{{yes && no}}', state), isFalse);
      expect(evaluate('{{no || yes}}', state), isTrue);
      expect(evaluate('{{no || no}}', state), isFalse);
    });

    test('a comparison inside a logical expression', () {
      expect(evaluate('{{n > 3 && n < 10}}', state), isTrue);
      expect(evaluate('{{n > 10 || n == 5}}', state), isTrue);
    });

    test('the ternary picks a branch', () {
      expect(evaluate("{{yes ? 'on' : 'off'}}", state), 'on');
      expect(evaluate("{{no ? 'on' : 'off'}}", state), 'off');
      expect(evaluate("{{n > 3 ? 'many' : 'few'}}", state), 'many');
    });
  });

  group('functions and access', () {
    final state = {
      'items': [1, 2, 3, 4],
      'names': ['a', 'b'],
      'text': 'hello',
    };

    test('length, sum and the rest of the built-ins', () {
      expect(evaluate('{{length(items)}}', state), 4);
      expect(evaluate('{{sum(items)}}', state), 10);
      expect(evaluate('{{length(text)}}', state), 5);
    });

    test('array access by index, and out of range', () {
      expect(evaluate('{{items[0]}}', state), 1);
      expect(evaluate('{{items[3]}}', state), 4);
      expect(evaluate('{{items[9]}}', state), isNull,
          reason: 'out of range is null, not a crash on a page');
      expect(evaluate('{{names[-1]}}', state), isNull);
    });

    test('a pipe transform shapes the value', () {
      expect(evaluate('{{text | uppercase}}', state), 'HELLO');
    });

    test('an unknown function answers null rather than throwing', () {
      expect(evaluate('{{somersault(items)}}', state), isNull);
    });
  });

  group('caching and invalidation', () {
    test('a computed value is cached until it is invalidated', () {
      final property = ComputedProperty.fromExpression('total', '{{a + b}}');
      expect(property.isInitialized, isFalse);

      expect(property.computeAndCache({'a': 1, 'b': 2}), 3);
      expect(property.isInitialized, isTrue);
      expect(property.cachedValue, 3);

      // The cache is what makes a computed property cheap; a cache that never
      // invalidates is what makes it wrong.
      property.invalidate();
      expect(property.isInitialized, isFalse);
      expect(property.computeAndCache({'a': 10, 'b': 5}), 15);
    });

    test('a self-referencing property answers null instead of recursing', () {
      // A page that computes `total` from `total` must render — a stack
      // overflow here takes the whole app down, and an author who writes a
      // cycle by accident is not rare.
      late ComputedProperty property;
      property = ComputedProperty(
        name: 'total',
        expression: '{{total}}',
        compute: (state) => property.computeAndCache(state),
      );
      expect(property.computeAndCache({'total': 1}), isNull);
    });

    test('an expression that throws is reported, not propagated', () {
      final property = ComputedProperty(
        name: 'boom',
        expression: '{{boom}}',
        compute: (_) => throw StateError('inside the expression'),
      );
      expect(() => property.computeAndCache({}), throwsA(isA<StateError>()),
          reason: 'a compute function that throws is the host\'s to handle; '
              'what must not happen is a silent wrong value');
    });
  });

  group('the expression as written', () {
    test('a string with no braces is a literal, not a path', () {
      // Same rule as §3.1: "A string with no `{{ }}` is a literal."
      expect(evaluate('count', {'count': 7}), 'count');
    });

    test('text around an expression is kept', () {
      expect(evaluate('Total: {{count}}', {'count': 7}), 'Total: 7');
    });

    test('two expressions in one string are both replaced', () {
      expect(evaluate('{{a}}/{{b}}', {'a': 1, 'b': 2}), '1/2');
    });
  });

  group('comparison across types', () {
    test('strings compare lexically, numbers numerically', () {
      expect(evaluate('{{a > b}}', <String, dynamic>{'a': 3, 'b': 2}), isTrue);
      expect(evaluate('{{a > b}}', <String, dynamic>{'a': 'b', 'b': 'a'}),
          isTrue,
          reason: 'a status compared against another status is an ordinary '
              'thing for a document to write');
      expect(evaluate('{{a < b}}', <String, dynamic>{'a': 'a', 'b': 'b'}),
          isTrue);
    });

    test('mixed types fall back to comparing their text', () {
      // '10' vs '9' as text: '1' sorts before '9'.
      expect(evaluate('{{a >= b}}', <String, dynamic>{'a': '10', 'b': 9}),
          isFalse,
          reason: 'comparing a number against a string compares their text, '
              'which is the only ordering that exists between them');
      expect(evaluate('{{a <= b}}', <String, dynamic>{'a': 1, 'b': '1'}),
          isTrue);
    });
  });

  group('truthiness', () {
    test('the empty forms are false and everything else is true', () {
      dynamic truthy(dynamic value) => evaluate(
            '{{flag ? "yes" : "no"}}',
            <String, dynamic>{'flag': value},
          );

      expect(truthy(true), 'yes');
      expect(truthy(false), 'no');
      expect(truthy(null), 'no');
      expect(truthy(1), 'yes');
      expect(truthy(0), 'no',
          reason: 'a count of zero is the empty case; treating it as true '
              'shows "1 result" over an empty list');
      expect(truthy('text'), 'yes');
      expect(truthy(''), 'no');
      expect(truthy(<dynamic>[1]), 'yes');
      expect(truthy(<dynamic>[]), 'no');
      expect(truthy(<String, dynamic>{'a': 1}), 'yes');
      expect(truthy(<String, dynamic>{}), 'no');
    });
  });

  group('a function called with no arguments', () {
    test('is evaluated rather than treated as a path', () {
      expect(evaluate('{{length()}}', <String, dynamic>{}), 0,
          reason: 'an empty argument list is a call, not a typo — reading it '
              'as a state path would answer null instead of a length');
    });

    test('a function nobody implements answers null', () {
      expect(evaluate('{{nonesuch(1)}}', <String, dynamic>{}), isNull);
    });
  });

  group('an expression that cannot be evaluated', () {
    test('answers null rather than taking the page down', () {
      expect(
          evaluate('{{items[}}', <String, dynamic>{
            'items': <dynamic>[1],
          }),
          isNull,
          reason: 'a malformed expression is an authoring slip; the computed '
              'value is simply absent');
    });
  });
}
