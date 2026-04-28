import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/client_resources/client_resource_resolver.dart';

void main() {
  group('ResourceTransformer Tests', () {
    group('TC-035: parse transform', () {
      test('TC-035 Normal: parse JSON string to object', () {
        final result = ResourceTransformer.applyTransforms(
          '{"name": "test", "value": 42}',
          [
            {'type': 'parse', 'format': 'json'},
          ],
        );
        expect(result, isA<Map>());
        expect((result as Map)['name'], 'test');
        expect(result['value'], 42);
      });

      test('TC-035 Error: invalid JSON content', () {
        // Invalid JSON keeps the original string
        final result = ResourceTransformer.applyTransforms(
          'not valid json',
          [
            {'type': 'parse', 'format': 'json'},
          ],
        );
        expect(result, 'not valid json');
      });

      test('TC-035 Error: unsupported parse format', () {
        expect(
          () => ResourceTransformer.applyTransforms(
            '<xml/>',
            [
              {'type': 'parse', 'format': 'xml'},
            ],
          ),
          throwsA(isA<UnsupportedError>()),
        );
      });

      test('TC-035 Error: yaml parse not yet supported', () {
        expect(
          () => ResourceTransformer.applyTransforms(
            'key: value',
            [
              {'type': 'parse', 'format': 'yaml'},
            ],
          ),
          throwsA(isA<UnsupportedError>()),
        );
      });

      test('TC-035 Error: csv parse not yet supported', () {
        expect(
          () => ResourceTransformer.applyTransforms(
            'a,b,c',
            [
              {'type': 'parse', 'format': 'csv'},
            ],
          ),
          throwsA(isA<UnsupportedError>()),
        );
      });

      test('TC-035 Error: completely unknown format', () {
        expect(
          () => ResourceTransformer.applyTransforms(
            'data',
            [
              {'type': 'parse', 'format': 'protobuf'},
            ],
          ),
          throwsA(isA<UnsupportedError>()),
        );
      });
    });

    group('TC-036: select transform', () {
      test('TC-036 Normal: select nested value at dot-notation path', () {
        final result = ResourceTransformer.applyTransforms(
          {'settings': {'ui': {'theme': 'dark'}}},
          [
            {'type': 'select', 'path': 'settings.ui'},
          ],
        );
        expect(result, isA<Map>());
        expect((result as Map)['theme'], 'dark');
      });

      test('TC-036 Boundary: path to leaf value returns primitive', () {
        final result = ResourceTransformer.applyTransforms(
          {'settings': {'ui': {'theme': 'dark'}}},
          [
            {'type': 'select', 'path': 'settings.ui.theme'},
          ],
        );
        expect(result, 'dark');
      });

      test('TC-036 Error: non-existent path returns null', () {
        final result = ResourceTransformer.applyTransforms(
          {'settings': {'ui': {}}},
          [
            {'type': 'select', 'path': 'settings.missing'},
          ],
        );
        expect(result, isNull);
      });
    });

    group('TC-037: defaults transform', () {
      test('TC-037 Normal: merges with defaults, data takes precedence', () {
        final result = ResourceTransformer.applyTransforms(
          {'theme': 'dark'},
          [
            {
              'type': 'defaults',
              'value': {'theme': 'light', 'language': 'en'},
            },
          ],
        );
        expect(result, isA<Map>());
        expect((result as Map)['theme'], 'dark');
        expect(result['language'], 'en');
      });

      test('TC-037 Boundary: empty data returns full defaults', () {
        final result = ResourceTransformer.applyTransforms(
          <String, dynamic>{},
          [
            {
              'type': 'defaults',
              'value': {'theme': 'light', 'language': 'en'},
            },
          ],
        );
        expect((result as Map)['theme'], 'light');
        expect(result['language'], 'en');
      });
    });

    group('TC-038: map transform', () {
      test('TC-038 Normal: maps list elements with expression', () {
        final result = ResourceTransformer.applyTransforms(
          [
            {'name': 'Alice', 'age': 30},
            {'name': 'Bob', 'age': 25},
          ],
          [
            {'type': 'map', 'expression': 'item.name'},
          ],
        );
        expect(result, ['Alice', 'Bob']);
      });

      test('TC-038 Boundary: empty array returns empty', () {
        final result = ResourceTransformer.applyTransforms(
          [],
          [
            {'type': 'map', 'expression': 'item.name'},
          ],
        );
        expect(result, isEmpty);
      });
    });

    group('TC-039: filter transform', () {
      test('TC-039 Normal: filters array elements by equality condition', () {
        final result = ResourceTransformer.applyTransforms(
          [
            {'name': 'Alice', 'active': 'true'},
            {'name': 'Bob', 'active': 'false'},
          ],
          [
            {'type': 'filter', 'condition': 'active == true'},
          ],
        );
        expect(result, isA<List>());
        expect((result as List).length, 1);
        expect(result[0]['name'], 'Alice');
      });

      test('TC-039 Boundary: no elements match returns empty', () {
        final result = ResourceTransformer.applyTransforms(
          [
            {'name': 'Alice', 'active': 'false'},
          ],
          [
            {'type': 'filter', 'condition': 'active == true'},
          ],
        );
        expect(result, isEmpty);
      });
    });

    group('TC-040: sort transform', () {
      test('TC-040 Normal: sorts ascending by field', () {
        final result = ResourceTransformer.applyTransforms(
          [
            {'name': 'Charlie'},
            {'name': 'Alice'},
            {'name': 'Bob'},
          ],
          [
            {'type': 'sort', 'by': 'name', 'order': 'asc'},
          ],
        );
        expect(result, isA<List>());
        expect((result as List)[0]['name'], 'Alice');
        expect(result[1]['name'], 'Bob');
        expect(result[2]['name'], 'Charlie');
      });

      test('TC-040 Normal: sorts descending by field', () {
        final result = ResourceTransformer.applyTransforms(
          [
            {'name': 'Alice'},
            {'name': 'Charlie'},
            {'name': 'Bob'},
          ],
          [
            {'type': 'sort', 'by': 'name', 'order': 'desc'},
          ],
        );
        expect((result as List)[0]['name'], 'Charlie');
        expect(result[1]['name'], 'Bob');
        expect(result[2]['name'], 'Alice');
      });
    });

    group('TC-043: Transform pipeline chaining', () {
      test('TC-043 Normal: parse then select then defaults', () {
        final result = ResourceTransformer.applyTransforms(
          '{"settings": {"ui": {"theme": "dark"}}}',
          [
            {'type': 'parse', 'format': 'json'},
            {'type': 'select', 'path': 'settings.ui'},
            {
              'type': 'defaults',
              'value': {'theme': 'light', 'language': 'en'},
            },
          ],
        );
        expect(result, isA<Map>());
        expect((result as Map)['theme'], 'dark');
        expect(result['language'], 'en');
      });

      test('TC-043 Boundary: empty transform array returns raw data', () {
        final result = ResourceTransformer.applyTransforms('raw data', []);
        expect(result, 'raw data');
      });

      test('TC-043 Error: transform in middle fails halts pipeline', () {
        expect(
          () => ResourceTransformer.applyTransforms(
            'raw data',
            [
              {'type': 'parse', 'format': 'json'},
              // This will not fail because invalid json keeps original string
              // Use xml which throws UnsupportedError
              {'type': 'parse', 'format': 'xml'},
            ],
          ),
          throwsA(isA<UnsupportedError>()),
        );
      });
    });
  });

  group('Image Transform Tests', () {
    group('TC-041: Image transform resize operation', () {
      test('TC-041 Normal: resize transform type accepted in pipeline', () {
        // The resize transform is a placeholder that passes through data
        final result = ResourceTransformer.applyTransforms(
          'base64ImageData',
          [
            {'type': 'resize', 'width': 100, 'height': 100},
          ],
        );
        // Resize is a no-op placeholder; data passes through unchanged
        expect(result, 'base64ImageData');
      });

      test('TC-041 Boundary: resize with only width specified', () {
        final result = ResourceTransformer.applyTransforms(
          'imageBytes',
          [
            {'type': 'resize', 'width': 200},
          ],
        );
        expect(result, 'imageBytes');
      });

      test('TC-041 Error: resize on non-image data passes through', () {
        final result = ResourceTransformer.applyTransforms(
          {'key': 'value'},
          [
            {'type': 'resize', 'width': 50, 'height': 50},
          ],
        );
        expect(result, isA<Map>());
        expect((result as Map)['key'], 'value');
      });
    });

    group('TC-042: Image transform format conversion', () {
      test('TC-042 Normal: format transform converts to string', () {
        final result = ResourceTransformer.applyTransforms(
          42,
          [
            {'type': 'format', 'format': 'string'},
          ],
        );
        expect(result, '42');
      });

      test('TC-042 Boundary: format string on already-string data', () {
        final result = ResourceTransformer.applyTransforms(
          'already a string',
          [
            {'type': 'format', 'format': 'string'},
          ],
        );
        expect(result, 'already a string');
      });

      test('TC-042 Error: format with null format parameter is no-op', () {
        final result = ResourceTransformer.applyTransforms(
          'data',
          [
            {'type': 'format'},
          ],
        );
        expect(result, 'data');
      });
    });
  });

  group('ResourceResult Tests', () {
    test('success result has correct properties', () {
      final result = ResourceResult.success(
        content: 'test content',
        path: '/test/path',
        type: 'file',
        mimeType: 'text/plain',
        encoding: 'utf-8',
      );
      expect(result.success, true);
      expect(result.content, 'test content');
      expect(result.path, '/test/path');
      expect(result.type, 'file');
      expect(result.mimeType, 'text/plain');
      expect(result.error, isNull);
      expect(result.isBinary, false);
    });

    test('error result has correct properties', () {
      final result = ResourceResult.error('Something failed');
      expect(result.success, false);
      expect(result.error, 'Something failed');
      expect(result.content, isNull);
    });

    test('isBinary is true when encoding is base64', () {
      final result = ResourceResult.success(
        content: 'base64data',
        path: '/test.png',
        type: 'file',
        encoding: 'base64',
      );
      expect(result.isBinary, true);
    });

    test('jsonContent parses JSON string', () {
      final result = ResourceResult.success(
        content: '{"key": "value"}',
        path: '/test.json',
        type: 'file',
      );
      expect(result.jsonContent, isA<Map>());
      expect((result.jsonContent as Map)['key'], 'value');
    });

    test('jsonContent returns original for non-JSON', () {
      final result = ResourceResult.success(
        content: 'plain text',
        path: '/test.txt',
        type: 'file',
      );
      expect(result.jsonContent, 'plain text');
    });

    test('toString for success', () {
      final result = ResourceResult.success(
        content: 'data',
        path: '/test.txt',
        type: 'file',
      );
      expect(result.toString(), contains('success'));
    });

    test('toString for error', () {
      final result = ResourceResult.error('failed');
      expect(result.toString(), contains('error'));
      expect(result.toString(), contains('failed'));
    });
  });
}
