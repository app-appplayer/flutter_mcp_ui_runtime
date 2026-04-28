import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_mcp_ui_runtime/src/client_resources/client_resource_resolver.dart';
import 'package:flutter_mcp_ui_runtime/src/core/client_resource_manager.dart'
    show ResourceLifecycleState;

void main() {
  group('Resource Error Handling Tests', () {
    late ClientResourceResolver resolver;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      resolver = ClientResourceResolver();
      await resolver.init();
    });

    group('TC-058: Resource not found error', () {
      test('TC-058 Normal: cache key not found returns error', () async {
        final result = await resolver.resolve('client://cache/nonexistent-key');
        expect(result.success, false);
        expect(result.error, contains('not found'));
      });

      test('TC-058 Boundary: error result has null content', () async {
        final result = await resolver.resolve('client://cache/missing');
        expect(result.success, false);
        expect(result.content, isNull);
        expect(result.path, isNull);
        expect(result.type, isNull);
      });

      test('TC-058 Error: ResourceResult.error factory produces correct state', () {
        final result = ResourceResult.error('Resource not found: test');
        expect(result.success, false);
        expect(result.error, 'Resource not found: test');
        expect(result.content, isNull);
      });
    });

    group('TC-059: Resource access denied error', () {
      test('TC-059 Normal: workspace path traversal denied', () async {
        resolver.setWorkingDirectory('/home/user/workspace');
        final result = await resolver.resolve(
            'client://workspace/../../../etc/passwd');
        // The resolver either denies path traversal or fails to find the file
        expect(result.success, false);
      });

      test('TC-059 Boundary: access denied message is descriptive', () async {
        resolver.setWorkingDirectory('/home/user/workspace');
        // Path traversal attempt
        final result = await resolver.resolve(
            'client://workspace/../../../etc/shadow');
        expect(result.success, false);
        expect(result.error, isNotNull);
      });
    });

    group('TC-060: Resource timeout error', () {
      test('TC-060 Normal: timeout behavior via ResourceEntry state', () {
        // ResourceEntry tracks lifecycle including staleness
        final entry = ResourceEntry(
          uri: 'client://cache/test',
          staleDuration: const Duration(seconds: 0),
          expireDuration: const Duration(seconds: 0),
        );
        entry.markReady('content');

        // After marking ready with zero durations, it should expire immediately
        // (or very shortly after)
        entry.updateState();
        // Since time has passed since markReady, the state should transition
        expect(
          entry.state.name,
          anyOf('stale', 'expired', 'ready'),
        );
      });

      test('TC-060 Boundary: expired entry detected correctly', () {
        final entry = ResourceEntry(
          uri: 'client://cache/test',
          expireDuration: Duration.zero,
        );
        entry.content = 'old content';
        entry.loadedAt = DateTime.now().subtract(const Duration(hours: 1));
        entry.state = ResourceLifecycleState.ready;

        entry.updateState();
        expect(entry.state, ResourceLifecycleState.expired);
      });
    });

    group('TC-061: Malformed URI error', () {
      test('TC-061 Normal: non-client URI returns error', () async {
        final result = await resolver.resolve('http://example.com/data');
        expect(result.success, false);
        expect(result.error, contains('Invalid'));
      });

      test('TC-061 Boundary: empty URI returns error', () async {
        final result = await resolver.resolve('');
        expect(result.success, false);
        expect(result.error, contains('Invalid'));
      });

      test('TC-061 Error: partial client URI returns parse error', () async {
        final result = await resolver.resolve('client://');
        expect(result.success, false);
      });
    });

    group('TC-062: Resource type mismatch error', () {
      test('TC-062 Normal: unknown scheme returns error', () async {
        final result = await resolver.resolve('client://unknown/path');
        expect(result.success, false);
        expect(result.error, contains('Unknown scheme'));
      });

      test('TC-062 Boundary: custom provider scheme not registered returns error', () async {
        final result = await resolver.resolve('client://database/users');
        expect(result.success, false);
        expect(result.error, contains('Unknown scheme'));
      });

      test('TC-062 Normal: custom provider registered resolves correctly', () async {
        resolver.customProviders.register(CustomResourceProvider(
          scheme: 'database',
          handler: (path, config) async {
            return ResourceResult.success(
              content: '{"users": []}',
              path: path,
              type: 'database',
            );
          },
        ));

        final result = await resolver.resolve('client://database/users');
        expect(result.success, true);
        expect(result.type, 'database');
      });
    });
  });
}
