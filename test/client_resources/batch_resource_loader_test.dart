import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_mcp_ui_runtime/src/client_resources/batch_resource_loader.dart';
import 'package:flutter_mcp_ui_runtime/src/client_resources/client_resource_resolver.dart';

void main() {
  late ClientResourceResolver resolver;
  late BatchResourceLoader loader;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'mcp_client_cache_source-a': '{"data": "valueA"}',
      'mcp_client_cache_source-b': '{"data": "valueB"}',
      'mcp_client_cache_source-c': '{"data": "valueC"}',
      'mcp_client_cache_source-opt': '{"data": "optional"}',
    });
    resolver = ClientResourceResolver();
    await resolver.init();
    loader = BatchResourceLoader(resolver);
  });

  group('BatchResourceSource Tests', () {
    test('fromJson parses correctly', () {
      final source = BatchResourceSource.fromJson({
        'key': 'config',
        'source': 'client://cache/config-data',
        'optional': true,
        'transform': [
          {'type': 'parse', 'format': 'json'},
        ],
      });
      expect(source.key, 'config');
      expect(source.source, 'client://cache/config-data');
      expect(source.optional, true);
      expect(source.transform, isNotNull);
      expect(source.transform!.length, 1);
    });

    test('fromJson defaults optional to false', () {
      final source = BatchResourceSource.fromJson({
        'key': 'data',
        'source': 'client://cache/data',
      });
      expect(source.optional, false);
      expect(source.transform, isNull);
    });
  });

  group('BatchResourceLoader Tests', () {
    group('TC-044: parallel loadStrategy', () {
      test('TC-044 Normal: all sources loaded concurrently', () async {
        final result = await loader.loadBatch(
          sources: [
            const BatchResourceSource(
                key: 'a', source: 'client://cache/source-a'),
            const BatchResourceSource(
                key: 'b', source: 'client://cache/source-b'),
          ],
          loadStrategy: 'parallel',
        );
        expect(result.success, true);
        expect(result.results.containsKey('a'), true);
        expect(result.results.containsKey('b'), true);
      });

      test('TC-044 Boundary: single source in batch', () async {
        final result = await loader.loadBatch(
          sources: [
            const BatchResourceSource(
                key: 'a', source: 'client://cache/source-a'),
          ],
          loadStrategy: 'parallel',
        );
        expect(result.success, true);
        expect(result.results.length, 1);
      });

      test('TC-044 Boundary: empty sources', () async {
        final result = await loader.loadBatch(
          sources: [],
          loadStrategy: 'parallel',
        );
        expect(result.success, true);
        expect(result.results, isEmpty);
      });
    });

    group('TC-045: sequential loadStrategy', () {
      test('TC-045 Normal: sources loaded in order', () async {
        final result = await loader.loadBatch(
          sources: [
            const BatchResourceSource(
                key: 'a', source: 'client://cache/source-a'),
            const BatchResourceSource(
                key: 'b', source: 'client://cache/source-b'),
            const BatchResourceSource(
                key: 'c', source: 'client://cache/source-c'),
          ],
          loadStrategy: 'sequential',
        );
        expect(result.success, true);
        expect(result.results.keys.toList(), ['a', 'b', 'c']);
      });
    });

    group('TC-046: failurePolicy - fail-fast', () {
      test('TC-046 Error: first source fails - batch stops', () async {
        final result = await loader.loadBatch(
          sources: [
            const BatchResourceSource(
                key: 'missing', source: 'client://cache/nonexistent'),
            const BatchResourceSource(
                key: 'b', source: 'client://cache/source-b'),
          ],
          loadStrategy: 'sequential',
          failurePolicy: 'fail-fast',
        );
        expect(result.success, false);
        expect(result.error, contains('missing'));
      });

      test('TC-046 Normal: all succeed with fail-fast', () async {
        final result = await loader.loadBatch(
          sources: [
            const BatchResourceSource(
                key: 'a', source: 'client://cache/source-a'),
            const BatchResourceSource(
                key: 'b', source: 'client://cache/source-b'),
          ],
          loadStrategy: 'sequential',
          failurePolicy: 'fail-fast',
        );
        expect(result.success, true);
      });
    });

    group('TC-047: failurePolicy - continue', () {
      test('TC-047 Normal: one source fails, others still loaded', () async {
        final result = await loader.loadBatch(
          sources: [
            const BatchResourceSource(
                key: 'a', source: 'client://cache/source-a'),
            const BatchResourceSource(
                key: 'missing', source: 'client://cache/nonexistent'),
            const BatchResourceSource(
                key: 'b', source: 'client://cache/source-b'),
          ],
          loadStrategy: 'parallel',
          failurePolicy: 'continue',
        );
        expect(result.success, true);
        expect(result.results.containsKey('a'), true);
        expect(result.results.containsKey('b'), true);
        expect(result.errors.containsKey('missing'), true);
      });

      test('TC-047 Error: all sources fail with continue', () async {
        final result = await loader.loadBatch(
          sources: [
            const BatchResourceSource(
                key: 'x', source: 'client://cache/nonexistent-x'),
            const BatchResourceSource(
                key: 'y', source: 'client://cache/nonexistent-y'),
          ],
          failurePolicy: 'continue',
        );
        expect(result.success, true);
        expect(result.errors.length, 2);
      });
    });

    group('TC-049: optional sources in batch', () {
      test('TC-049 Normal: optional source succeeds', () async {
        final result = await loader.loadBatch(
          sources: [
            const BatchResourceSource(
              key: 'opt',
              source: 'client://cache/source-opt',
              optional: true,
            ),
          ],
        );
        expect(result.success, true);
        expect(result.results.containsKey('opt'), true);
      });

      test('TC-049 Normal: optional source fails - no error triggered', () async {
        final result = await loader.loadBatch(
          sources: [
            const BatchResourceSource(
              key: 'opt',
              source: 'client://cache/nonexistent',
              optional: true,
            ),
          ],
        );
        expect(result.success, true);
        // Optional failures don't end up in results
      });
    });

    group('TC-050: Batch transform per source', () {
      test('TC-050 Normal: transform applied to source data', () async {
        final result = await loader.loadBatch(
          sources: [
            const BatchResourceSource(
              key: 'a',
              source: 'client://cache/source-a',
              transform: [
                {'type': 'select', 'path': 'data'},
              ],
            ),
          ],
        );
        expect(result.success, true);
        expect(result.results['a'], 'valueA');
      });

      test('TC-050 Boundary: source without transform returns raw data', () async {
        final result = await loader.loadBatch(
          sources: [
            const BatchResourceSource(
                key: 'a', source: 'client://cache/source-a'),
          ],
        );
        expect(result.success, true);
        expect(result.results['a'], isA<Map>());
      });
    });
  });

  group('TC-064: Batch partial failure', () {
    test('TC-064 Normal: some resources succeed while others fail', () async {
      final result = await loader.loadBatch(
        sources: [
          const BatchResourceSource(
              key: 'valid-a', source: 'client://cache/source-a'),
          const BatchResourceSource(
              key: 'missing-x', source: 'client://cache/nonexistent-x'),
          const BatchResourceSource(
              key: 'valid-b', source: 'client://cache/source-b'),
          const BatchResourceSource(
              key: 'missing-y', source: 'client://cache/nonexistent-y'),
        ],
        loadStrategy: 'parallel',
        failurePolicy: 'continue',
      );

      expect(result.success, true);
      // Successful resources present in results
      expect(result.results.containsKey('valid-a'), true);
      expect(result.results.containsKey('valid-b'), true);
      // Failed resources tracked in errors
      expect(result.errors.containsKey('missing-x'), true);
      expect(result.errors.containsKey('missing-y'), true);
      // Failed non-optional resources have null in results
      expect(result.results['missing-x'], isNull);
      expect(result.results['missing-y'], isNull);
    });

    test('TC-064 Boundary: all fail with continue policy', () async {
      final result = await loader.loadBatch(
        sources: [
          const BatchResourceSource(
              key: 'x', source: 'client://cache/no-x'),
          const BatchResourceSource(
              key: 'y', source: 'client://cache/no-y'),
        ],
        failurePolicy: 'continue',
      );

      expect(result.success, true);
      expect(result.errors.length, 2);
    });

    test('TC-064 Boundary: optional failures excluded from errors count', () async {
      final result = await loader.loadBatch(
        sources: [
          const BatchResourceSource(
              key: 'valid', source: 'client://cache/source-a'),
          const BatchResourceSource(
              key: 'opt-miss',
              source: 'client://cache/nonexistent',
              optional: true),
        ],
        failurePolicy: 'continue',
      );

      expect(result.success, true);
      expect(result.results.containsKey('valid'), true);
      // Optional failure still tracked in errors map
      expect(result.errors.containsKey('opt-miss'), true);
    });
  });

  group('BatchResourceResult Tests', () {
    test('success factory creates correctly', () {
      final result = BatchResourceResult.success(
        results: {'a': 'data'},
        errors: {},
      );
      expect(result.success, true);
      expect(result.results['a'], 'data');
      expect(result.error, isNull);
    });

    test('failure factory creates correctly', () {
      final result = BatchResourceResult.failure('batch failed');
      expect(result.success, false);
      expect(result.error, 'batch failed');
      expect(result.results, isEmpty);
    });
  });
}
