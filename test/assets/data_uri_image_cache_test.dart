// The same `data:` URI yields the same image, not an equal one.
//
// `MemoryImage`'s cache key is the byte list's *identity*. Decoding a URI
// again produces a new `Uint8List`, so `PaintingBinding.imageCache` has never
// seen the resulting provider and both the base64 decode and the image decode
// run again — on every rebuild, for a picture that has not changed. konpi
// traced a stutter in AppPlayer to exactly this: a menu photo is 130 kB of
// base64 and two of them sit on one screen.
//
// `network` and `flutterAsset` never had the problem: their keys are the URL
// and the asset path. Only `data:` keys on the value.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/assets/asset_ref.dart';
import 'package:flutter_mcp_ui_runtime/src/assets/asset_resolver.dart';

/// A 1x1 PNG, the smallest thing that survives a decode.
const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
const _uri = 'data:image/png;base64,$_png';

void main() {
  const resolver = AssetResolver();

  test('the same uri returns the identical provider', () {
    final first = resolver.imageProviderFor(AssetRef.parse(_uri)!);
    final second = resolver.imageProviderFor(AssetRef.parse(_uri)!);
    expect(first, isA<MemoryImage>());
    expect(identical(first, second), isTrue,
        reason: 'a new provider each time is a cache miss each time');
  });

  test('the bytes are the identical list, which is what the key is', () {
    // Equality is not enough: `MemoryImage` compares `bytes` by identity.
    final a = resolver.imageProviderFor(AssetRef.parse(_uri)!) as MemoryImage;
    final b = resolver.imageProviderFor(AssetRef.parse(_uri)!) as MemoryImage;
    expect(identical(a.bytes, b.bytes), isTrue);
    expect(a == b, isTrue, reason: 'and so the providers compare equal');
  });

  test('a different uri is a different image', () {
    // The cache must key on the payload, not merely on the form.
    final other = base64Encode(<int>[1, 2, 3, 4]);
    final a = resolver.imageProviderFor(AssetRef.parse(_uri)!);
    final b = resolver
        .imageProviderFor(AssetRef.parse('data:image/png;base64,$other')!);
    expect(identical(a, b), isFalse);
  });

  test('a malformed payload still resolves to nothing', () {
    // §6.12.4: unresolvable takes the slot's fallback. Caching must not turn
    // a failure into a stored empty image.
    expect(
      resolver.imageProviderFor(AssetRef.parse('data:image/png;base64,!!!')!),
      isNull,
    );
  });

  test('the cache is bounded', () {
    // A document can name any number of data URIs; holding all of them trades
    // a stutter for a leak. Asking for many and then re-asking for the first
    // shows the bound is enforced by eviction rather than by growth.
    final first = resolver.imageProviderFor(AssetRef.parse(_uri)!);
    for (var i = 0; i < 80; i++) {
      final payload = base64Encode(List<int>.filled(8, i));
      resolver.imageProviderFor(AssetRef.parse('data:image/png;base64,$payload')!);
    }
    final afterEviction = resolver.imageProviderFor(AssetRef.parse(_uri)!);
    expect(identical(first, afterEviction), isFalse,
        reason: 'the oldest entry should have been evicted, not retained');
  });
}
