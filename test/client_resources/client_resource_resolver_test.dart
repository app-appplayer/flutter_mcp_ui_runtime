// `client_resource_resolver.dart` sat at 54.8%. It is the §8.3 `client://`
// side of the wire — the one that spends a user's `file.read` grant — so its
// refusals matter as much as its successes: an unknown scheme that resolves,
// or a fallback that hides a real failure, both end with a document reading
// something nobody agreed to hand it.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/client_resources/client_resource_resolver.dart';

void main() {
  late ClientResourceResolver resolver;

  setUp(() => resolver = ClientResourceResolver());

  group('what counts as a client resource', () {
    test('only the client:// scheme does', () {
      expect(resolver.isClientResource('client://file/a.txt'), isTrue);
      expect(resolver.isClientResource('https://example.com/a.txt'), isFalse);
      expect(resolver.isClientResource('bundle://a.txt'), isFalse);
      expect(resolver.isClientResource(''), isFalse);
    });

    test('a non-client URI is refused by name, not silently', () async {
      final result = await resolver.resolve('https://example.com/a.txt');
      expect(result.success, isFalse);
      expect(result.error, contains('Invalid client resource URI'));
    });

    test('an unknown scheme is refused by name', () async {
      final result = await resolver.resolve('client://telepathy/thoughts');
      expect(result.success, isFalse);
      expect(result.error, contains('Unknown scheme'));
    });
  });

  group('content type by extension', () {
    test('text formats are not binary', () {
      for (final ext in const ['txt', 'json', 'md', 'csv', 'yaml', 'xml']) {
        expect(ResourceContentType.fromExtension(ext).isBinary, isFalse,
            reason: ext);
      }
      expect(ResourceContentType.fromExtension('json').mimeType,
          'application/json');
    });

    test('image and archive formats are binary', () {
      for (final ext in const ['png', 'jpg', 'pdf', 'zip']) {
        expect(ResourceContentType.fromExtension(ext).isBinary, isTrue,
            reason: ext);
      }
    });

    test('an unknown extension is treated as binary, which is the safe way '
        'round', () {
      final type = ResourceContentType.fromExtension('nonsense');
      expect(type.isBinary, isTrue,
          reason: 'decoding unknown bytes as text corrupts them silently; '
              'handing back bytes does not');
    });
  });

  group('custom providers (§Custom Resource Providers)', () {
    test('a registered scheme is dispatched to its handler', () async {
      resolver.customProviders.register(CustomResourceProvider(
        scheme: 'inventory',
        handler: (path, config) async => ResourceResult.success(
          content: 'rows for $path',
          path: path,
          type: 'inventory',
          mimeType: 'text/plain',
        ),
      ));

      expect(resolver.customProviders.has('inventory'), isTrue);
      expect(resolver.customProviders.registeredSchemes, contains('inventory'));

      final result = await resolver.resolve('client://inventory/warehouse-1');
      expect(result.success, isTrue);
      expect(result.content, 'rows for warehouse-1');
    });

    test('unregistering puts the scheme back to unknown', () async {
      resolver.customProviders.register(CustomResourceProvider(
        scheme: 'inventory',
        handler: (path, config) async => ResourceResult.success(
            content: 'x', path: path, type: 'inventory'),
      ));
      resolver.customProviders.unregister('inventory');

      expect(resolver.customProviders.has('inventory'), isFalse);
      final result = await resolver.resolve('client://inventory/a');
      expect(result.success, isFalse);
      expect(result.error, contains('Unknown scheme'));
    });

    test('a provider that throws is reported, not swallowed', () async {
      resolver.customProviders.register(CustomResourceProvider(
        scheme: 'broken',
        handler: (path, config) async => throw StateError('provider down'),
      ));

      final result = await resolver.resolve('client://broken/a');
      expect(result.success, isFalse,
          reason: 'a provider failure that returns success leaves the '
              'document rendering an empty value it believes is real');
    });
  });

  group('fallback', () {
    test('a fallback resolves when the primary fails', () async {
      resolver.customProviders.register(CustomResourceProvider(
        scheme: 'backup',
        handler: (path, config) async => ResourceResult.success(
            content: 'from backup', path: path, type: 'backup'),
      ));

      final result = await resolver.resolve(
        'client://telepathy/nope',
        fallback: 'client://backup/a',
      );
      expect(result.success, isTrue);
      expect(result.content, 'from backup');
    });

    test('a failing fallback returns the original failure', () async {
      final result = await resolver.resolve(
        'client://telepathy/nope',
        fallback: 'client://alsonothing/x',
      );
      expect(result.success, isFalse);
      expect(result.error, contains('telepathy'),
          reason: 'reporting the fallback\'s failure would send the author to '
              'debug the wrong URI');
    });

    test('an empty fallback is not attempted', () async {
      final result =
          await resolver.resolve('client://telepathy/nope', fallback: '');
      expect(result.success, isFalse);
    });
  });
}
