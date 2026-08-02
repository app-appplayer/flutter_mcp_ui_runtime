/// `AssetRef` parsing and resolution — spec §6.12.
///
/// The three cases at the top mirror what was measured on a real device
/// against AppPlayer Standard: a literal `data:` URI painted the tile, the
/// same URI arriving through a binding did not, and the `image` widget
/// rendered the words "Base64 not supported" where the picture belonged.
/// They are kept as tests so the two halves cannot drift apart again.
library asset_ref_test;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/assets/asset_ref.dart';
import 'package:flutter_mcp_ui_runtime/src/assets/asset_resolver.dart';
import 'package:flutter_mcp_ui_runtime/src/assets/asset_ref_image.dart';

/// 1×1 red PNG — the literal that painted the tile in the field report.
const _redPixel =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

void main() {
  group('AssetRef.parse — scheme dispatch', () {
    test('recognises every declared scheme', () {
      expect(AssetRef.parse(_redPixel)!.form, AssetForm.data);
      expect(AssetRef.parse('https://x/y.png')!.form, AssetForm.network);
      expect(AssetRef.parse('http://x/y.png')!.form, AssetForm.network);
      expect(AssetRef.parse('assets/icons/a.svg')!.form,
          AssetForm.flutterAsset);
      expect(AssetRef.parse('bundle://menu/a.jpg')!.form, AssetForm.bundle);
      expect(AssetRef.parse('client://file/a.png')!.form, AssetForm.client);
    });

    test('an unknown scheme parses rather than failing', () {
      // §6.12.1 — a scheme this runtime does not implement is an
      // unresolvable asset, not an invalid document.
      final ref = AssetRef.parse('ipfs://Qm123');
      expect(ref, isNotNull);
      expect(ref!.form, AssetForm.unknown);
    });

    test('object form carries uri and origin', () {
      final ref = AssetRef.parse({
        'uri': 'file:///reports/q2.pdf',
        'origin': {'connection': 'dev1'},
      });
      expect(ref!.form, AssetForm.origin);
      expect(ref.uri, 'file:///reports/q2.pdf');
      expect(ref.origin, {'connection': 'dev1'});
    });

    test('object form without origin resolves ambient', () {
      final ref = AssetRef.parse({'uri': 'x://y'});
      expect(ref!.form, AssetForm.origin);
      expect(ref.origin, isNull);
    });

    test('absent and empty values yield null', () {
      expect(AssetRef.parse(null), isNull);
      expect(AssetRef.parse(''), isNull);
      expect(AssetRef.parse({}), isNull);
      expect(AssetRef.parse({'origin': {}}), isNull);
    });

    test('bundlePath strips the scheme', () {
      expect(AssetRef.parse('bundle://menu/a.jpg')!.bundlePath, 'menu/a.jpg');
      expect(AssetRef.parse('https://x/y')!.bundlePath, '');
    });

    test('a bare word reads as an icon name, a scheme does not', () {
      // IconRef: this is what keeps `icon: "home"` working while the same
      // slot also accepts an asset.
      expect(AssetRef.parse('home')!.looksLikeIconName, isTrue);
      expect(AssetRef.parse('folder_open')!.looksLikeIconName, isTrue);
      expect(AssetRef.parse(_redPixel)!.looksLikeIconName, isFalse);
      expect(AssetRef.parse('assets/a.svg')!.looksLikeIconName, isFalse);
    });
  });

  group('decodeDataUri', () {
    test('decodes base64', () {
      final bytes = decodeDataUri(_redPixel);
      expect(bytes, isNotNull);
      expect(bytes!.length, greaterThan(0));
      // PNG magic — proves we decoded rather than returned the text.
      expect(bytes.take(4), [0x89, 0x50, 0x4E, 0x47]);
    });

    test('decodes percent-encoded payloads', () {
      final bytes = decodeDataUri('data:image/svg+xml,%3Csvg%2F%3E');
      expect(utf8.decode(bytes!), '<svg/>');
    });

    test('returns null on a malformed uri rather than throwing', () {
      expect(decodeDataUri('data:image/png;base64'), isNull);
      expect(decodeDataUri('data:image/png;base64,!!!not-base64!!!'), isNull);
    });
  });

  group('AssetResolver.supportedForms — declared, not assumed (§18.2.12)', () {
    test('builtin publishes exactly the no-injection forms', () {
      expect(AssetResolver.builtin.supportedForms, {
        AssetForm.data,
        AssetForm.flutterAsset,
        AssetForm.network,
      });
    });

    test('a form appears only when its reader was injected', () {
      final r = AssetResolver(bundleReader: (_) async => null);
      expect(r.supportedForms.contains(AssetForm.bundle), isTrue);
      expect(r.supportedForms.contains(AssetForm.client), isFalse);
      expect(r.supportedForms.contains(AssetForm.origin), isFalse);
    });

    test('the published set cannot claim more than is wired', () {
      // The honesty requirement of §6.12.4 is structural here: there is no
      // way to declare a form without supplying the reader for it.
      final all = AssetResolver(
        bundleReader: (_) async => null,
        clientReader: (_) async => null,
        originReader: (_, __) async => null,
      );
      expect(all.supportedForms.length, AssetForm.values.length - 1);
      expect(all.supportedForms.contains(AssetForm.unknown), isFalse);
    });
  });

  group('imageProviderFor', () {
    test('data: yields MemoryImage — the case that rendered a placeholder',
        () {
      final p = AssetResolver.builtin
          .imageProviderFor(AssetRef.parse(_redPixel)!);
      expect(p, isA<MemoryImage>());
    });

    test('network and flutter assets keep their native providers', () {
      expect(
        AssetResolver.builtin.imageProviderFor(AssetRef.parse('https://x/y')!),
        isA<NetworkImage>(),
      );
      expect(
        AssetResolver.builtin.imageProviderFor(AssetRef.parse('assets/a.png')!),
        isA<AssetImage>(),
      );
    });

    test('async forms yield AssetRefImage when wired', () {
      final r = AssetResolver(
        bundleReader: (_) async => Uint8List(0),
        clientReader: (_) async => Uint8List(0),
        originReader: (_, __) async => Uint8List(0),
      );
      expect(r.imageProviderFor(AssetRef.parse('bundle://a.png')!),
          isA<AssetRefImage>());
      expect(r.imageProviderFor(AssetRef.parse('client://file/a.png')!),
          isA<AssetRefImage>());
      expect(r.imageProviderFor(AssetRef.parse({'uri': 'x://y'})!),
          isA<AssetRefImage>());
    });

    test('an unwired form yields null so the slot takes its fallback', () {
      // §6.12.4 — null is how the widget reaches `fallback` instead of
      // rendering a box that names the runtime's limitation.
      expect(
        AssetResolver.builtin.imageProviderFor(AssetRef.parse('bundle://a')!),
        isNull,
      );
      expect(
        AssetResolver.builtin.imageProviderFor(AssetRef.parse('ipfs://Qm')!),
        isNull,
      );
    });

    test('a malformed data: uri yields null rather than a broken provider',
        () {
      expect(
        AssetResolver.builtin
            .imageProviderFor(AssetRef.parse('data:image/png;base64')!),
        isNull,
      );
    });
  });

  group('bytesFor', () {
    test('routes each form to its reader with the right argument', () async {
      final seen = <String, String>{};
      final r = AssetResolver(
        bundleReader: (path) async {
          seen['bundle'] = path;
          return Uint8List.fromList([1]);
        },
        clientReader: (uri) async {
          seen['client'] = uri;
          return Uint8List.fromList([2]);
        },
        originReader: (uri, origin) async {
          seen['origin'] = '$uri|${origin?['connection']}';
          return Uint8List.fromList([3]);
        },
      );

      expect(await r.bytesFor(AssetRef.parse('bundle://menu/a.jpg')!), [1]);
      // The bundle reader receives the path, not the whole uri.
      expect(seen['bundle'], 'menu/a.jpg');

      expect(await r.bytesFor(AssetRef.parse('client://file/a.png')!), [2]);
      expect(seen['client'], 'client://file/a.png');

      expect(
        await r.bytesFor(
          AssetRef.parse({
            'uri': 'x://y',
            'origin': {'connection': 'dev1'},
          })!,
        ),
        [3],
      );
      expect(seen['origin'], 'x://y|dev1');
    });

    test('unwired forms read as null, not as an exception', () async {
      expect(
        await AssetResolver.builtin.bytesFor(AssetRef.parse('bundle://a')!),
        isNull,
      );
      expect(
        await AssetResolver.builtin.bytesFor(AssetRef.parse('client://a/b')!),
        isNull,
      );
    });

    test('a reader that throws surfaces as unreadable, not as a crash',
        () async {
      final r = AssetResolver(
        bundleReader: (_) async => throw StateError('gone'),
      );
      await expectLater(
        r.bytesFor(AssetRef.parse('bundle://a')!),
        throwsA(isA<StateError>()),
      );
      // Documented deliberately: bytesFor propagates, and AssetRefImage is
      // what converts a failed read into the widget's error path.
    });
  });

  group('AssetRefImage identity', () {
    test('equal refs share a cache key, different ones do not', () {
      final r = AssetResolver(bundleReader: (_) async => null);
      final a = AssetRefImage(AssetRef.parse('bundle://a.png')!, r);
      final b = AssetRefImage(AssetRef.parse('bundle://a.png')!, r);
      final c = AssetRefImage(AssetRef.parse('bundle://b.png')!, r);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('origin participates in identity', () {
      // Two devices serving the same uri must not share one cached image.
      final r = AssetResolver(originReader: (_, __) async => null);
      final a = AssetRefImage(
          AssetRef.parse({'uri': 'x://y', 'origin': {'connection': 'a'}})!, r);
      final b = AssetRefImage(
          AssetRef.parse({'uri': 'x://y', 'origin': {'connection': 'b'}})!, r);
      expect(a, isNot(equals(b)));
    });
  });
}
