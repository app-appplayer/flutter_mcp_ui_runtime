// `JsonPath` — the write, delete and search side.
//
// Every `state.set` a document performs lands here, so a path form that reads
// correctly and writes to the wrong place is a value the user entered and the
// document never sees. The list forms matter most: `items[2].name` is how a
// row is edited, and growing a list to reach an index is the part nothing
// else in the runtime does.

import 'package:flutter_mcp_ui_runtime/src/utils/json_path.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('get — the collection properties', () {
    test('a list answers length, emptiness and its ends', () {
      final data = <String, dynamic>{
        'rows': <dynamic>[1, 2, 3],
        'empty': <dynamic>[],
      };

      expect(JsonPath.get(data, 'rows.length'), 3);
      expect(JsonPath.get(data, 'rows.isEmpty'), isFalse);
      expect(JsonPath.get(data, 'rows.isNotEmpty'), isTrue);
      expect(JsonPath.get(data, 'rows.first'), 1);
      expect(JsonPath.get(data, 'rows.last'), 3);
      expect(JsonPath.get(data, 'empty.first'), isNull);
      expect(JsonPath.get(data, 'empty.last'), isNull);
      expect(JsonPath.get(data, 'empty.isEmpty'), isTrue);
    });

    test('a real key always beats a collection property', () {
      final data = <String, dynamic>{
        'form': <String, dynamic>{'length': 'A4', 'isEmpty': 'no'},
      };

      expect(JsonPath.get(data, 'form.length'), 'A4',
          reason: 'a document that stores a field called `length` must read '
              'its own value back, not the map size');
      expect(JsonPath.get(data, 'form.isEmpty'), 'no');
    });

    test('an object with no such key answers the collection property', () {
      final data = <String, dynamic>{
        'form': <String, dynamic>{'name': 'Ada'},
        'blank': <String, dynamic>{},
      };

      expect(JsonPath.get(data, 'form.length'), 1);
      expect(JsonPath.get(data, 'blank.isEmpty'), isTrue);
      expect(JsonPath.get(data, 'form.isNotEmpty'), isTrue);
    });

    test('a string answers its length and emptiness', () {
      final data = <String, dynamic>{'name': 'Ada', 'blank': ''};

      expect(JsonPath.get(data, 'name.length'), 3);
      expect(JsonPath.get(data, 'blank.isEmpty'), isTrue);
      expect(JsonPath.get(data, 'name.isNotEmpty'), isTrue);
      expect(JsonPath.get(data, 'name.upper'), isNull);
    });

    test('indexes work with and without brackets, and out of range is null',
        () {
      final data = <String, dynamic>{
        'rows': <dynamic>[
          <String, dynamic>{'name': 'Ada'},
          <String, dynamic>{'name': 'Bob'},
        ],
      };

      expect(JsonPath.get(data, 'rows[1].name'), 'Bob');
      expect(JsonPath.get(data, 'rows.1.name'), 'Bob');
      expect(JsonPath.get(data, 'rows[5]'), isNull);
      expect(JsonPath.get(data, 'rows.5'), isNull);
      expect(JsonPath.get(data, 'rows[-1]'), isNull);
      expect(JsonPath.get(data, 'name[0]'), isNull);
    });

    test('an empty path is the whole document', () {
      final data = <String, dynamic>{'a': 1};
      expect(JsonPath.get(data, ''), same(data));
    });
  });

  // The one path form the parser refuses, pinned so the refusal stays a
  // refusal: every bracket has to follow a property name. `matrix[0][1]` is
  // the shape a document reaches for a grid, and answering it with a wrong
  // cell would be worse than saying no.
  group('the path forms the parser will not take', () {
    test('two brackets in a row are named as the problem', () {
      final data = <String, dynamic>{
        'matrix': <dynamic>[
          <dynamic>['a', 'b'],
        ],
      };

      expect(
          () => JsonPath.get(data, 'matrix[0][1]'),
          throwsA(isA<FormatException>().having((e) => e.message, 'message',
              contains('without property name'))),
          reason: 'a silent null here would read as "no such cell" for a cell '
              'that is right there');
    });

    test('a bracket with no property in front of it is refused too', () {
      expect(() => JsonPath.get(<String, dynamic>{'a': 1}, '[0]'),
          throwsA(isA<FormatException>()));
    });
  });

  group('set', () {
    test('creates the objects along the way', () {
      final data = <String, dynamic>{};

      JsonPath.set(data, 'user.profile.name', 'Ada');

      expect(data, {
        'user': {
          'profile': {'name': 'Ada'}
        }
      });
    });

    test('creates a list when the next segment is an index', () {
      final data = <String, dynamic>{};

      JsonPath.set(data, 'rows[0].name', 'Ada');

      expect(data['rows'], isA<List<dynamic>>());
      expect(data['rows'][0], {'name': 'Ada'});
    });

    test('grows a list to reach the index, padding with nulls', () {
      final data = <String, dynamic>{
        'rows': <dynamic>[1],
      };

      JsonPath.set(data, 'rows[3]', 'four');

      expect(data['rows'], [1, null, null, 'four'],
          reason: 'a write to row 3 of a one-row list has to say something '
              'about rows 1 and 2; dropping the write loses the value');
    });

    test('grows a list addressed without brackets too', () {
      final data = <String, dynamic>{
        'rows': <dynamic>[],
      };

      JsonPath.set(data, 'rows.2', 'three');

      expect(data['rows'], [null, null, 'three']);
    });

    test('builds a container inside a grown list', () {
      final data = <String, dynamic>{
        'rows': <dynamic>[],
      };

      JsonPath.set(data, 'rows.2.name', 'Ada');

      expect(data['rows'][2], {'name': 'Ada'});
      expect(data['rows'][0], isNull);
    });

    test('an index straight after an index is refused by name', () {
      expect(() => JsonPath.set(<String, dynamic>{}, 'grid[1][2]', 'x'),
          throwsFormatException,
          reason: 'the form is unsupported; silently writing somewhere else '
              'would leave the author looking for the value later');
    });

    test('an unclosed bracket is refused by name', () {
      expect(() => JsonPath.set(<String, dynamic>{}, 'rows[1', 'x'),
          throwsFormatException);
      expect(() => JsonPath.get(<String, dynamic>{}, 'rows[1'),
          throwsFormatException);
    });

    test('a non-numeric index reads and writes as a miss, not a crash', () {
      final data = <String, dynamic>{
        'rows': <dynamic>['a'],
      };

      expect(JsonPath.get(data, 'rows[i]'), isNull,
          reason: 'a stale index after a row was removed is ordinary; taking '
              'the page down over it is not');
      JsonPath.set(data, 'rows[i]', 'x');
      expect(data['rows'], ['a']);
      JsonPath.delete(data, 'rows[i]');
      expect(data['rows'], ['a']);
    });

    test('overwrites what is already there', () {
      final data = <String, dynamic>{
        'rows': <dynamic>['a', 'b'],
      };

      JsonPath.set(data, 'rows[1]', 'B');

      expect(data['rows'], ['a', 'B']);
    });

    test('a scalar in the middle of the path is not written through', () {
      final data = <String, dynamic>{'user': 'Ada'};

      JsonPath.set(data, 'user.name', 'Bob');

      expect(data['user'], 'Ada',
          reason: 'the parent holds a scalar, so there is nowhere to put this '
              '— replacing the scalar with a map would discard it');
    });

    test('an empty path writes nothing', () {
      final data = <String, dynamic>{'a': 1};
      JsonPath.set(data, '', 'x');
      expect(data, {'a': 1});
    });
  });

  group('delete', () {
    test('removes a nested key, and a list entry by index', () {
      final data = <String, dynamic>{
        'user': <String, dynamic>{'name': 'Ada', 'age': 36},
        'rows': <dynamic>['a', 'b', 'c'],
      };

      JsonPath.delete(data, 'user.age');
      JsonPath.delete(data, 'rows[1]');

      expect(data['user'], {'name': 'Ada'});
      expect(data['rows'], ['a', 'c']);
    });

    test('a path that does not exist is left alone', () {
      final data = <String, dynamic>{
        'user': <String, dynamic>{'name': 'Ada'},
        'rows': <dynamic>['a'],
      };

      JsonPath.delete(data, 'user.missing.deeper');
      JsonPath.delete(data, 'rows[9]');
      JsonPath.delete(data, 'nothing.here');
      JsonPath.delete(data, '');

      expect(data, {
        'user': {'name': 'Ada'},
        'rows': ['a'],
      });
    });
  });

  group('exists', () {
    test('answers for present, absent and null-valued paths', () {
      final data = <String, dynamic>{
        'user': <String, dynamic>{'name': 'Ada', 'nickname': null},
        'rows': <dynamic>['a'],
      };

      expect(JsonPath.exists(data, 'user.name'), isTrue);
      expect(JsonPath.exists(data, 'user.missing'), isFalse);
      expect(JsonPath.exists(data, 'rows[0]'), isTrue);
      expect(JsonPath.exists(data, 'rows[1]'), isFalse);
    });
  });

  group('findPaths', () {
    test('walks objects and lists, and matches by wildcard', () {
      final data = <String, dynamic>{
        'user': <String, dynamic>{'name': 'Ada'},
        'rows': <dynamic>[
          <String, dynamic>{'name': 'Bob'},
        ],
      };

      expect(JsonPath.findPaths(data, '*'), isNotEmpty);
      expect(JsonPath.findPaths(data, 'user.name'), ['user.name']);
      expect(JsonPath.findPaths(data, 'rows.*.name'), ['rows.0.name'],
          reason: 'a list is walked by index, so a wildcard has to match the '
              'index segment as well as an object key');
      expect(JsonPath.findPaths(data, 'nothing.*'), isEmpty);
    });
  });
  // A path that walks INTO a list — `rows[0].name`, or a root that is itself
  // a list — is how a document edits one row of a table. Each of these forms
  // reads or writes a different branch, and a form that quietly does nothing
  // leaves the edit on screen and out of state.
  group('paths that walk through a list', () {
    test('an indexed element is read, and an index past the end is not',
        () {
      final data = <String, dynamic>{
        'rows': <dynamic>[
          <String, dynamic>{'name': 'Ada'},
          <String, dynamic>{'name': 'Bob'},
        ],
      };

      expect(JsonPath.get(data, 'rows[1].name'), 'Bob');
      expect(JsonPath.get(data, 'rows[5].name'), isNull,
          reason: 'a row that is not there has no name; inventing one would '
              'let a stale index render as real data');
      expect(JsonPath.get(data, 'rows[-1].name'), isNull);
    });

    test('two brackets in a row are refused, and say why', () {
      final data = <String, dynamic>{
        'matrix': <dynamic>[
          <dynamic>['a', 'b'],
        ],
      };

      // A nested index needs a property name between the brackets; the
      // refusal is explicit rather than a silent null, which is what tells an
      // author the path is wrong rather than the data missing.
      expect(() => JsonPath.get(data, 'matrix[0][1]'),
          throwsA(isA<FormatException>()));
      expect(() => JsonPath.set(data, 'matrix[0][1]', 'z'),
          throwsA(isA<FormatException>()));
    });

    test('writing to a list key that does not exist yet creates it', () {
      final data = <String, dynamic>{};

      JsonPath.set(data, 'rows[1]', 'second');

      expect(data['rows'], <dynamic>[null, 'second']);
    });

    test('deleting inside a list element leaves the list itself alone', () {
      final data = <String, dynamic>{
        'rows': <dynamic>[
          <String, dynamic>{'name': 'Ada', 'draft': 'x'},
        ],
      };

      JsonPath.delete(data, 'rows.0.draft');

      expect(data['rows'], hasLength(1));
      expect((data['rows'][0] as Map).containsKey('draft'), isFalse);
      expect((data['rows'][0] as Map)['name'], 'Ada');
    });

    test('deleting through an index that is not there does nothing', () {
      final data = <String, dynamic>{
        'rows': <dynamic>[
          <String, dynamic>{'name': 'Ada'},
        ],
      };

      JsonPath.delete(data, 'rows.4.name');

      expect((data['rows'][0] as Map)['name'], 'Ada');
    });
  });
}
