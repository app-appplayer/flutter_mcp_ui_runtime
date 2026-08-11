// `AssetRefImage` — the image provider behind every asynchronous asset form,
// and the byte reads it sits on.
//
// §6.12.5 is why it exists: a runtime whose asset path is synchronous can
// only serve the forms needing no I/O while looking as though it implements
// the whole contract. What this reads is the wait, and the failure: an asset
// that cannot be resolved has to fail loudly enough for the cache to drop it,
// or a bundle asset that arrives a second late is never shown at all.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/assets/asset_ref.dart';
import 'package:flutter_mcp_ui_runtime/src/assets/asset_ref_image.dart';
import 'package:flutter_mcp_ui_runtime/src/assets/asset_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

/// A 1×1 transparent PNG — the smallest thing a decoder will accept.
final Uint8List _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmM'
  'IQAAAABJRU5ErkJggg==',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AssetRef refFor(String uri) => AssetRef.parse(uri)!;

  group('bytesFor', () {
    test('a data: URI is decoded inline', () async {
      final resolver = AssetResolver();
      final uri = 'data:image/png;base64,${base64Encode(_pixel)}';

      expect(await resolver.bytesFor(refFor(uri)), _pixel);
    });

    test('a bundle reference goes through the reader the host wired',
        () async {
      final asked = <String>[];
      final resolver = AssetResolver(
        bundleReader: (path) async {
          asked.add(path);
          return _pixel;
        },
      );

      expect(await resolver.bytesFor(refFor('bundle://logo.png')), _pixel);
      expect(asked, ['logo.png'],
          reason: 'the reader is handed the path inside the bundle, not the '
              'whole URI');
    });

    test('with no reader wired the form reads as unavailable', () async {
      final resolver = AssetResolver();

      expect(await resolver.bytesFor(refFor('bundle://logo.png')), isNull);
      expect(await resolver.bytesFor(refFor('client://file/logo.png')), isNull);
    });

    test('a client reference goes through the client reader', () async {
      final resolver = AssetResolver(clientReader: (uri) async => _pixel);

      expect(await resolver.bytesFor(refFor('client://file/logo.png')), _pixel);
    });

    test('a flutter asset reads through the overridable loader', () async {
      AssetResolver.rootBundleLoader = (key) async => _pixel;
      addTearDown(() => AssetResolver.rootBundleLoader =
          AssetResolver.rootBundleLoader);

      expect(await AssetResolver().bytesFor(refFor('assets/logo.png')),
          _pixel);
    });

    test('a loader that throws reads as unavailable rather than crashing',
        () async {
      final previous = AssetResolver.rootBundleLoader;
      AssetResolver.rootBundleLoader =
          (key) async => throw StateError('no bundle');
      addTearDown(() => AssetResolver.rootBundleLoader = previous);

      expect(await AssetResolver().bytesFor(refFor('assets/logo.png')), isNull,
          reason: 'a missing asset is an ordinary authoring slip; taking the '
              'page down over it helps nobody');
    });

    test('network bytes are left to Flutter', () async {
      expect(
          await AssetResolver().bytesFor(refFor('https://example.com/a.png')),
          isNull,
          reason: 'fetching one here would duplicate Flutter\'s own image '
              'cache and lose its de-duplication');
    });
  });

  group('AssetRefImage', () {
    testWidgets('resolves through the resolver and paints', (tester) async {
      final resolver = AssetResolver(bundleReader: (path) async => _pixel);
      final provider = AssetRefImage(refFor('bundle://logo.png'), resolver);

      await tester.pumpWidget(MaterialApp(
        home: Image(image: provider, width: 8, height: 8),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('an unresolvable asset fails, and is evicted so a later '
        'attempt re-reads', (tester) async {
      var reads = 0;
      final resolver = AssetResolver(bundleReader: (path) async {
        reads++;
        return reads == 1 ? null : _pixel;
      });

      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = previous);

      Widget build() => MaterialApp(
            home: Image(
              image: AssetRefImage(refFor('bundle://late.png'), resolver),
              width: 8,
              height: 8,
            ),
          );

      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      expect(errors, isNotEmpty,
          reason: 'the failure has to be reported; a silently blank slot is '
              'indistinguishable from an asset that is still loading');

      // The evict runs on a microtask, so the second mount re-reads.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      expect(reads, greaterThan(1),
          reason: 'a bundle asset can arrive after first paint; caching the '
              'failure would leave the slot empty for the session');
    });

    test('two references to the same asset are the same key', () {
      final resolver = AssetResolver();
      final ref = refFor('bundle://logo.png');

      expect(AssetRefImage(ref, resolver),
          AssetRefImage(refFor('bundle://logo.png'), resolver),
          reason: 'the image cache keys on this; a provider that never '
              'compares equal re-decodes the same bytes for every widget');
      expect(AssetRefImage(ref, resolver).hashCode,
          AssetRefImage(refFor('bundle://logo.png'), resolver).hashCode);
      expect(AssetRefImage(ref, resolver),
          isNot(AssetRefImage(ref, resolver, scale: 2)));
      expect(AssetRefImage(ref, resolver).toString(), contains('logo.png'));
    });

    test('the key is available without any I/O', () async {
      final provider = AssetRefImage(refFor('bundle://logo.png'),
          AssetResolver());

      expect(await provider.obtainKey(ImageConfiguration.empty),
          same(provider));
    });
  });

  // The default loader itself — the one every test replaces. It is the only
  // path a shipped app takes for `assets/…`, so leaving it unrun means the
  // seam was tested and the thing it stands in for was not.
  group('the default root-bundle loader', () {
    test('reads a key the bundle carries', () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      // Every Flutter bundle carries its own manifest, so this is a key that
      // exists without the test having to package an asset of its own.
      final bytes = await AssetResolver.rootBundleLoader('AssetManifest.json');

      expect(bytes, isNotNull);
      expect(bytes!.isNotEmpty, isTrue,
          reason: 'a loader that answers empty for an asset that is there '
              'makes every `assets/` reference render its fallback, with '
              'nothing said');
    });
  });
}
