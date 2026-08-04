import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/client_resources/client_resource_resolver.dart';

void main() {
  group('CustomResourceProviderRegistry Tests', () {
    late CustomResourceProviderRegistry registry;

    setUp(() {
      registry = CustomResourceProviderRegistry();
    });

    group('TC-055: Custom provider registration', () {
      test('TC-055 Normal: register and resolve custom provider', () async {
        registry.register(CustomResourceProvider(
          scheme: 'database',
          handler: (path, config) async {
            return ResourceResult.success(
              content: '{"id": "$path"}',
              path: path,
              type: 'database',
            );
          },
        ));

        expect(registry.has('database'), true);
        final result = await registry.resolve('database', 'users/123');
        expect(result.success, true);
        expect(result.content, contains('users/123'));
      });

      test('TC-055 Boundary: provider with config passes config to handler', () async {
        Map<String, dynamic>? receivedConfig;
        registry.register(CustomResourceProvider(
          scheme: 'api',
          handler: (path, config) async {
            receivedConfig = config;
            return ResourceResult.success(
              content: 'data',
              path: path,
              type: 'api',
            );
          },
          config: {'baseUrl': 'https://api.example.com', 'timeout': 5000},
        ));

        await registry.resolve('api', 'resource');
        expect(receivedConfig, isNotNull);
        expect(receivedConfig!['baseUrl'], 'https://api.example.com');
        expect(receivedConfig!['timeout'], 5000);
      });

      test('TC-055 Error: provider not found returns error', () async {
        final result = await registry.resolve('unknown', 'path');
        expect(result.success, false);
        expect(result.error, contains('No provider registered'));
      });
    });

    group('TC-056: Custom provider permissions', () {
      test('TC-056 Normal: provider with permissions', () {
        registry.register(CustomResourceProvider(
          scheme: 'secure',
          handler: (path, config) async {
            return ResourceResult.success(
              content: 'secret',
              path: path,
              type: 'secure',
            );
          },
          permissions: ['system.database'],
        ));

        // The permissions are stored on the provider for external checking
        expect(registry.has('secure'), true);
      });
    });

    group('TC-057: Custom provider URI resolution', () {
      test('TC-057 Normal: custom handler receives correct path', () async {
        String? receivedPath;
        registry.register(CustomResourceProvider(
          scheme: 'mydb',
          handler: (path, config) async {
            receivedPath = path;
            return ResourceResult.success(
              content: '{"user": "found"}',
              path: path,
              type: 'mydb',
            );
          },
        ));

        await registry.resolve('mydb', 'users/123');
        expect(receivedPath, 'users/123');
      });

      test('TC-057 Error: custom handler throws - reported as a result',
          () async {
        registry.register(CustomResourceProvider(
          scheme: 'failing',
          handler: (path, config) async {
            throw Exception('Handler error');
          },
        ));

        // A provider is host code, and every caller here expects a result
        // envelope. Letting the exception escape turned a resource read into
        // an unhandled error at whatever call site asked for it.
        final result = await registry.resolve('failing', 'path');
        expect(result.success, isFalse);
        expect(result.error, contains('failing'));
        expect(result.error, contains('Handler error'));
      });
    });

    group('Registry management', () {
      test('unregister removes provider', () {
        registry.register(CustomResourceProvider(
          scheme: 'test',
          handler: (path, config) async =>
              ResourceResult.success(content: '', path: '', type: 'test'),
        ));
        expect(registry.has('test'), true);

        registry.unregister('test');
        expect(registry.has('test'), false);
      });

      test('registeredSchemes returns all schemes', () {
        registry.register(CustomResourceProvider(
          scheme: 'a',
          handler: (path, config) async =>
              ResourceResult.success(content: '', path: '', type: 'a'),
        ));
        registry.register(CustomResourceProvider(
          scheme: 'b',
          handler: (path, config) async =>
              ResourceResult.success(content: '', path: '', type: 'b'),
        ));

        expect(registry.registeredSchemes, containsAll(['a', 'b']));
      });

      test('re-registering same scheme replaces provider', () async {
        registry.register(CustomResourceProvider(
          scheme: 'test',
          handler: (path, config) async =>
              ResourceResult.success(content: 'v1', path: path, type: 'test'),
        ));
        registry.register(CustomResourceProvider(
          scheme: 'test',
          handler: (path, config) async =>
              ResourceResult.success(content: 'v2', path: path, type: 'test'),
        ));

        final result = await registry.resolve('test', 'path');
        expect(result.content, 'v2');
      });
    });
  });
}
