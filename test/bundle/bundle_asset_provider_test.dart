import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_bundle/mcp_bundle.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

/// In-memory storage for testing bundle:// URI resolution.
class _TestStoragePort implements BundleStoragePort {
  final Map<String, Uint8List> assets = {};

  @override
  Future<Uint8List> readAsset(Uri uri) async {
    final key = uri.toString();
    if (assets.containsKey(key)) return assets[key]!;
    throw Exception('Asset not found: $uri');
  }

  @override
  Future<Map<String, dynamic>> readBundle(Uri uri) async => {};
  @override
  Future<void> writeBundle(Uri uri, Map<String, dynamic> data) async {}
  @override
  Future<void> writeAsset(Uri uri, Uint8List data) async {}
  @override
  Future<bool> exists(Uri uri) async => false;
  @override
  Future<void> delete(Uri uri) async {}
  @override
  Future<List<Uri>> list(Uri directoryUri) async => [];
  @override
  Stream<BundleChangeEvent>? watch(Uri uri) => null;
}

void main() {
  // ==========================================================================
  // isBundleUri (TC-V12-033)
  // ==========================================================================
  group('BundleAssetProvider.isBundleUri()', () {
    // TC-V12-033: isBundleUri — static helper
    test('returns true for bundle:// URIs', () {
      expect(BundleAssetProvider.isBundleUri('bundle://assets/icon.png'),
          isTrue);
    });

    test('returns false for non-bundle URIs', () {
      expect(BundleAssetProvider.isBundleUri('https://example.com/icon.png'),
          isFalse);
    });

    test('returns false for null', () {
      expect(BundleAssetProvider.isBundleUri(null), isFalse);
    });

    test('returns false for empty string', () {
      expect(BundleAssetProvider.isBundleUri(''), isFalse);
    });
  });

  // ==========================================================================
  // resolve — non-bundle URI passthrough (TC-V12-028 ~ TC-V12-030)
  // ==========================================================================
  group('resolve() non-bundle URIs', () {
    // TC-V12-029: resolve — non-bundle URI passthrough (HTTPS)
    test('returns HTTPS URI as-is', () async {
      final storage = _TestStoragePort();
      final provider = BundleAssetProvider(storage: storage);
      final result = await provider.resolve('https://example.com/icon.png');
      expect(result, equals('https://example.com/icon.png'));
    });

    // TC-V12-028: resolve — non-bundle URI passthrough (HTTP)
    test('returns HTTP URI as-is', () async {
      final storage = _TestStoragePort();
      final provider = BundleAssetProvider(storage: storage);
      final result =
          await provider.resolve('http://cdn.example.com/image.png');
      expect(result, equals('http://cdn.example.com/image.png'));
    });

    // TC-V12-030: resolve — non-bundle URI passthrough (data URI)
    test('returns data URI as-is', () async {
      final storage = _TestStoragePort();
      final provider = BundleAssetProvider(storage: storage);
      const dataUri = 'data:image/png;base64,iVBORw0KGgo=';
      final result = await provider.resolve(dataUri);
      expect(result, equals(dataUri));
    });
  });

  // ==========================================================================
  // resolve — local mode (TC-V12-027)
  // ==========================================================================
  group('resolve() local mode', () {
    // TC-V12-027: resolve — bundle:// URI in local mode
    test('returns local file path', () async {
      final storage = _TestStoragePort();
      final provider = BundleAssetProvider(
        storage: storage,
        basePath: '/data/bundles/com.example.app',
      );

      final result =
          await provider.resolve('bundle://assets/icon.png');
      expect(result, equals('/data/bundles/com.example.app/assets/icon.png'));
    });
  });

  // ==========================================================================
  // resolve — online mode (TC-V12-026, TC-V12-031)
  // ==========================================================================
  group('resolve() online mode', () {
    // TC-V12-026: resolve — bundle:// URI in online mode
    test('returns data URI with correct MIME type for PNG', () async {
      final storage = _TestStoragePort();
      final pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
      storage.assets['bundle://assets/icon.png'] = pngBytes;

      final provider = BundleAssetProvider(storage: storage);
      final result = await provider.resolve('bundle://assets/icon.png');

      expect(result, isNotNull);
      expect(result!, startsWith('data:image/png;base64,'));
      final base64Part = result.split(',').last;
      expect(base64Decode(base64Part), equals(pngBytes));
    });

    test('returns data URI with JPEG MIME type', () async {
      final storage = _TestStoragePort();
      final jpegBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF]);
      storage.assets['bundle://photos/photo.jpg'] = jpegBytes;

      final provider = BundleAssetProvider(storage: storage);
      final result = await provider.resolve('bundle://photos/photo.jpg');

      expect(result, isNotNull);
      expect(result!, startsWith('data:image/jpeg;base64,'));
    });

    // TC-V12-031: resolve — missing asset in bundle
    test('returns null when asset not found', () async {
      final storage = _TestStoragePort();
      final provider = BundleAssetProvider(storage: storage);
      final result = await provider.resolve('bundle://missing/asset.png');
      expect(result, isNull);
    });

    test('handles SVG MIME type', () async {
      final storage = _TestStoragePort();
      final svgBytes = Uint8List.fromList(
          '<svg></svg>'.codeUnits);
      storage.assets['bundle://assets/logo.svg'] = svgBytes;

      final provider = BundleAssetProvider(storage: storage);
      final result = await provider.resolve('bundle://assets/logo.svg');

      expect(result, isNotNull);
      expect(result!, startsWith('data:image/svg+xml;base64,'));
    });

    test('uses octet-stream for unknown extension', () async {
      final storage = _TestStoragePort();
      final bytes = Uint8List.fromList([1, 2, 3]);
      storage.assets['bundle://assets/data.xyz'] = bytes;

      final provider = BundleAssetProvider(storage: storage);
      final result = await provider.resolve('bundle://assets/data.xyz');

      expect(result, isNotNull);
      expect(result!, startsWith('data:application/octet-stream;base64,'));
    });

    // TC-V12-032: Large asset — falls back to URL reference instead of
    // inline data URI when asset exceeds maxInlineBytes (512 KB)
    test('large asset falls back to original URI', () async {
      final storage = _TestStoragePort();
      // Create a byte array larger than 512 KB (maxInlineBytes)
      final largeBytes = Uint8List(512 * 1024 + 1);
      storage.assets['bundle://assets/large-image.png'] = largeBytes;

      final provider = BundleAssetProvider(storage: storage);
      final result =
          await provider.resolve('bundle://assets/large-image.png');

      expect(result, isNotNull);
      // Large assets should NOT be inlined as data URI;
      // instead the original bundle:// URI is returned as-is
      expect(result, equals('bundle://assets/large-image.png'));
      expect(result!, isNot(startsWith('data:')));
    });
  });

  // ==========================================================================
  // Constructor — dependency injection (TC-V12-034)
  // ==========================================================================
  group('Constructor dependency injection', () {
    // TC-V12-034: Constructor with basePath (local mode)
    test('creates provider in local mode with basePath', () async {
      final storage = _TestStoragePort();
      final provider = BundleAssetProvider(
        storage: storage,
        basePath: '/path/to/bundle',
      );

      final result = await provider.resolve('bundle://assets/icon.png');
      expect(result, equals('/path/to/bundle/assets/icon.png'));
    });

    // TC-V12-034: Constructor without basePath (online mode)
    test('creates provider in online mode without basePath', () async {
      final storage = _TestStoragePort();
      final pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
      storage.assets['bundle://assets/icon.png'] = pngBytes;

      final provider = BundleAssetProvider(storage: storage);
      final result = await provider.resolve('bundle://assets/icon.png');
      expect(result, startsWith('data:'));
    });
  });
}
