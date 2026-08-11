// The transform kinds a resource declaration can chain, and the filter
// language behind `filter`.
//
// A transform runs between the bytes and the binding, so one that quietly
// passes its input through is a screen showing raw server shapes — and a
// filter that reads a condition wrongly shows the user rows that should have
// been left out.

import 'package:flutter_mcp_ui_runtime/src/client_resources/client_resource_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  dynamic apply(dynamic data, List<Map<String, dynamic>> transforms) =>
      ResourceTransformer.applyTransforms(data, transforms);

  group('rename', () {
    test('remaps the keys a document asked for', () {
      final result = apply(<String, dynamic>{
        'user_name': 'Ada',
        'user_age': 36,
      }, <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'rename',
          'mapping': <String, dynamic>{
            'name': 'user_name',
            'age': 'user_age',
          },
        },
      ]);

      expect(result, {'name': 'Ada', 'age': 36});
    });

    test('a source key that is absent leaves the mapping literal behind', () {
      final result = apply(<String, dynamic>{'user_name': 'Ada'},
          <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'rename',
              'mapping': <String, dynamic>{'name': 'user_name', 'age': '30'},
            },
          ]);

      expect(result, {'name': 'Ada', 'age': '30'},
          reason: 'the mapping value doubles as the default; dropping the key '
              'would leave a binding pointing at nothing');
    });

    test('a rename over a list is left alone', () {
      final data = <dynamic>[1, 2];
      expect(
          apply(data, <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'rename',
              'mapping': <String, dynamic>{'a': 'b'},
            },
          ]),
          same(data));
    });

    test('a rename with no mapping is a no-op', () {
      final data = <String, dynamic>{'a': 1};
      expect(
          apply(data, <Map<String, dynamic>>[
            <String, dynamic>{'type': 'rename'},
          ]),
          same(data));
    });
  });

  group('filter', () {
    final rows = <dynamic>[
      <String, dynamic>{'name': 'Ada', 'status': 'open', 'done': false},
      <String, dynamic>{'name': 'Bob', 'status': 'closed', 'done': true},
      <String, dynamic>{'name': 'Cy', 'status': 'open', 'done': true},
      'not a row',
    ];

    List<dynamic> filtered(String condition) => apply(rows,
        <Map<String, dynamic>>[
          <String, dynamic>{'type': 'filter', 'condition': condition},
        ]) as List<dynamic>;

    test('an equality condition keeps only the matching rows', () {
      expect(filtered('status == open').whereType<Map<String, dynamic>>()
          .map((r) => r['name']), ['Ada', 'Cy']);
    });

    test('an inequality condition drops the matching rows', () {
      expect(filtered('status != open').whereType<Map<String, dynamic>>()
          .map((r) => r['name']), ['Bob']);
    });

    test('a bare field is a truthy test', () {
      expect(filtered('done').whereType<Map<String, dynamic>>()
          .map((r) => r['name']), ['Bob', 'Cy'],
          reason: 'a bare field that always passed would show every row and '
              'read as "the filter is not applied"');
    });

    test('a missing field is false rather than an error', () {
      expect(filtered('archived').whereType<Map<String, dynamic>>(), isEmpty);
    });

    test('an empty string and an empty list are false', () {
      final data = <dynamic>[
        <String, dynamic>{'tags': <dynamic>[], 'note': ''},
        <String, dynamic>{
          'tags': <dynamic>['a'],
          'note': 'x',
        },
      ];

      expect(
          (apply(data, <Map<String, dynamic>>[
            <String, dynamic>{'type': 'filter', 'condition': 'tags'},
          ]) as List<dynamic>)
              .length,
          1);
      expect(
          (apply(data, <Map<String, dynamic>>[
            <String, dynamic>{'type': 'filter', 'condition': 'note'},
          ]) as List<dynamic>)
              .length,
          1);
    });

    test('a nested field is reachable by dot path', () {
      final data = <dynamic>[
        <String, dynamic>{
          'meta': <String, dynamic>{'state': 'open'},
        },
        <String, dynamic>{
          'meta': <String, dynamic>{'state': 'closed'},
        },
      ];

      expect(
          (apply(data, <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'filter',
              'condition': 'meta.state == open',
            },
          ]) as List<dynamic>)
              .length,
          1);
    });

    test('a non-map entry is kept rather than dropped silently', () {
      expect(filtered('status == open'), contains('not a row'),
          reason: 'the condition has nothing to say about a scalar row; '
              'dropping it would delete data the filter never judged');
    });

    test('a filter with no condition is a no-op', () {
      expect(
          apply(rows, <Map<String, dynamic>>[
            <String, dynamic>{'type': 'filter'},
          ]),
          same(rows));
    });
  });

  group('hasKey', () {
    test('keeps only the rows carrying the key', () {
      final data = <dynamic>[
        <String, dynamic>{'name': 'Ada', 'email': 'a@example.com'},
        <String, dynamic>{'name': 'Bob'},
        'not a row',
      ];

      final result = apply(data, <Map<String, dynamic>>[
        <String, dynamic>{'type': 'hasKey', 'condition': 'email'},
      ]) as List<dynamic>;

      expect(result.whereType<Map<String, dynamic>>().map((r) => r['name']),
          ['Ada']);
      expect(result, contains('not a row'));
    });
  });

  group('map', () {
    test('projects each row to one of its fields', () {
      final result = apply(<dynamic>[
        <String, dynamic>{'name': 'Ada'},
        <String, dynamic>{'name': 'Bob'},
      ], <Map<String, dynamic>>[
        <String, dynamic>{'type': 'map', 'expression': 'item.name'},
      ]);

      expect(result, ['Ada', 'Bob']);
    });

    test('a bare field name works as well as the `item.` form', () {
      expect(
          apply(<dynamic>[
            <String, dynamic>{'name': 'Ada'},
          ], <Map<String, dynamic>>[
            <String, dynamic>{'type': 'map', 'expression': 'name'},
          ]),
          ['Ada']);
    });

    test('a row missing the field keeps the row rather than becoming null', () {
      final result = apply(<dynamic>[
        <String, dynamic>{'other': 1},
        'scalar',
      ], <Map<String, dynamic>>[
        <String, dynamic>{'type': 'map', 'expression': 'item.name'},
      ]) as List<dynamic>;

      expect(result.first, {'other': 1},
          reason: 'a list of nulls is worse than the original rows — the '
              'screen shows blanks with nothing to explain them');
      expect(result.last, 'scalar');
    });
  });

  group('defaults and select', () {
    test('defaults fill only the keys that are absent', () {
      expect(
          apply(<String, dynamic>{'name': 'Ada'}, <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'defaults',
              'value': <String, dynamic>{'name': 'Anon', 'role': 'viewer'},
            },
          ]),
          {'name': 'Ada', 'role': 'viewer'});
    });

    test('select narrows to a nested path', () {
      expect(
          apply(<String, dynamic>{
            'data': <String, dynamic>{
              'rows': <dynamic>[1, 2],
            },
          }, <Map<String, dynamic>>[
            <String, dynamic>{'type': 'select', 'path': 'data.rows'},
          ]),
          [1, 2]);
    });

    test('a select that names nothing yields nothing', () {
      expect(
          apply(<String, dynamic>{'data': 1}, <Map<String, dynamic>>[
            <String, dynamic>{'type': 'select', 'path': 'data.missing.deeper'},
          ]),
          isNull);
    });
  });

  group('chaining', () {
    test('the transforms run in the order they are declared', () {
      final result = apply(
        '{"data": {"rows": ['
        '{"name": "Ada", "status": "open"},'
        '{"name": "Bob", "status": "closed"}]}}',
        <Map<String, dynamic>>[
          <String, dynamic>{'type': 'parse', 'format': 'json'},
          <String, dynamic>{'type': 'select', 'path': 'data.rows'},
          <String, dynamic>{'type': 'filter', 'condition': 'status == open'},
          <String, dynamic>{'type': 'map', 'expression': 'item.name'},
        ],
      );

      expect(result, ['Ada']);
    });

    test('an unknown transform kind leaves the data as it was', () {
      final data = <String, dynamic>{'a': 1};
      expect(
          apply(data, <Map<String, dynamic>>[
            <String, dynamic>{'type': 'flatten'},
          ]),
          same(data));
    });
  });
}
