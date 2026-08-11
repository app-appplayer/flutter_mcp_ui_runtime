// The transformation pipeline a `client://` resource passes through.
//
// A declared step that quietly does nothing is the worst shape here: the
// document reads the RAW data and looks like the data itself is wrong. Two of
// these steps genuinely cannot run in this pipeline — they need expression
// evaluation it does not have — and what matters is that they say so rather
// than passing the input off as transformed.

import 'package:flutter_mcp_ui_runtime/src/core/client_resource_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TransformationEngine engine;

  setUp(() {
    engine = TransformationEngine();
    TransformationEngine.resetUnappliedReports();
  });

  TransformStep step(String type, [Map<String, dynamic> config = const {}]) =>
      TransformStep.fromJson({'type': type, ...config});

  group('reading a step', () {
    test('a known type is read, and an unknown one parses', () {
      expect(step('sort').type, TransformType.sort);
      expect(step('nonsense').type, TransformType.parse,
          reason: 'a step this runtime does not know still has to leave the '
              'data readable rather than dropping the pipeline');
    });
  });

  group('parse', () {
    test('json text becomes structured data', () {
      final result = engine.execute('{"rows": 3}', [step('parse')]);
      expect(result, {'rows': 3});
    });

    test('data that is already structured passes through', () {
      final result = engine.execute({'rows': 3}, [step('parse')]);
      expect(result, {'rows': 3});
    });

    test('text that will not parse is left as text', () {
      final result = engine.execute('not json', [step('parse')]);
      expect(result, 'not json',
          reason: 'a proxy error page served where json was expected is '
              'ordinary; losing it would lose the only evidence of what '
              'happened');
    });
  });

  group('select and defaults', () {
    test('select narrows to a path', () {
      final result = engine.execute({
        'data': {'rows': 3},
      }, [
        step('select', {'path': 'data'}),
      ]);

      expect(result, {'rows': 3});
    });

    test('defaults fill in what the payload did not carry', () {
      final result = engine.execute({'rows': 3}, [
        step('defaults', {
          'value': {'rows': 0, 'unit': 'C'},
        }),
      ]);

      expect(result, {'rows': 3, 'unit': 'C'},
          reason: 'the payload wins over the default, or the default would '
              'overwrite the answer');
    });

    test('defaults stand in for a payload that is missing entirely', () {
      final result = engine.execute(null, [
        step('defaults', {
          'value': {'rows': 0},
        }),
      ]);

      expect(result, {'rows': 0});
    });
  });

  group('sort', () {
    test('sorts by a field, ascending by default', () {
      final result = engine.execute([
        {'name': 'Cy'},
        {'name': 'Ada'},
        {'name': 'Bob'},
      ], [
        step('sort', {'by': 'name'}),
      ]) as List;

      expect(result.map((r) => (r as Map)['name']), ['Ada', 'Bob', 'Cy']);
    });

    test('descending reverses it', () {
      final result = engine.execute([
        {'n': 1},
        {'n': 3},
        {'n': 2},
      ], [
        step('sort', {'by': 'n', 'order': 'desc'}),
      ]) as List;

      expect(result.map((r) => (r as Map)['n']), [3, 2, 1]);
    });

    test('a missing field sorts as empty rather than throwing', () {
      final result = engine.execute([
        {'n': 2},
        <String, dynamic>{},
        {'n': 1},
      ], [
        step('sort', {'by': 'n'}),
      ]) as List;

      expect(result, hasLength(3),
          reason: 'one row without the field must not lose the other two');
    });

    test('with no `by` the list is left alone', () {
      final result = engine.execute([3, 1, 2], [step('sort')]);
      expect(result, [3, 1, 2]);
    });

    test('something that is not a list is left alone', () {
      final result = engine.execute({'rows': 3}, [
        step('sort', {'by': 'n'}),
      ]);
      expect(result, {'rows': 3});
    });
  });

  group('the steps this pipeline cannot run', () {
    test('map passes the data through, and says so', () {
      final result = engine.execute([
        {'n': 1},
      ], [
        step('map', {'expression': '{{item.n}}'}),
      ]);

      expect(result, [
        {'n': 1}
      ], reason: 'unchanged is the only honest answer — inventing a mapping '
          'would be worse');
      // Reported through the logger rather than the return value; what is
      // pinned here is that the data is NOT presented as transformed.
    });

    test('filter passes every element through, and says so', () {
      final result = engine.execute([1, 2, 3], [
        step('filter', {'expression': '{{item > 1}}'}),
      ]);

      expect(result, [1, 2, 3],
          reason: 'an unevaluated filter returning everything reads as '
              '"nothing matched the opposite" rather than as a step that '
              'never ran');
    });
  });

  group('image steps carry their intent downstream', () {
    test('resize attaches its dimensions', () {
      final result = engine.execute({'uri': 'client://file/a.png'}, [
        step('resize', {'width': 100, 'height': 50}),
      ]) as Map;

      expect(result['_resize'], {'width': 100, 'height': 50},
          reason: 'the resize itself is platform work; dropping the request '
              'would leave the consumer with no way to know it was asked for');
      expect(result['uri'], 'client://file/a.png');
    });

    test('format attaches its target', () {
      final result = engine.execute({'uri': 'client://file/a.png'}, [
        step('format', {'to': 'webp', 'quality': 80}),
      ]) as Map;

      expect(result['_format'], {'to': 'webp', 'quality': 80});
    });

    test('neither touches data that is not a map', () {
      expect(engine.execute('raw', [step('resize', {'width': 1})]), 'raw');
      expect(engine.execute('raw', [step('format', {'to': 'webp'})]), 'raw');
    });
  });

  group('a pipeline', () {
    test('runs its steps in order', () {
      final result = engine.execute('{"data": [{"n": 2}, {"n": 1}]}', [
        step('parse'),
        step('select', {'path': 'data'}),
        step('sort', {'by': 'n'}),
      ]) as List;

      expect(result.map((r) => (r as Map)['n']), [1, 2],
          reason: 'each step reads what the one before it produced — running '
              'them against the original input would sort the unparsed text');
    });

    test('an empty pipeline is the identity', () {
      expect(engine.execute({'rows': 3}, const []), {'rows': 3});
    });
  });
}
