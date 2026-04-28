import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/client_resources/client_resource_resolver.dart';

void main() {
  group('ResourceContentType Tests', () {
    group('TC-020: Text file encoding detection', () {
      test('TC-020 Normal: .txt detected as text', () {
        final ct = ResourceContentType.fromExtension('txt');
        expect(ct.isBinary, false);
        expect(ct.mimeType, 'text/plain');
      });

      test('TC-020 Normal: .json detected as text', () {
        final ct = ResourceContentType.fromExtension('json');
        expect(ct.isBinary, false);
        expect(ct.mimeType, 'application/json');
      });

      test('TC-020 Normal: .md detected as text', () {
        final ct = ResourceContentType.fromExtension('md');
        expect(ct.isBinary, false);
        expect(ct.mimeType, 'text/markdown');
      });

      test('TC-020 Normal: .csv detected as text', () {
        final ct = ResourceContentType.fromExtension('csv');
        expect(ct.isBinary, false);
        expect(ct.mimeType, 'text/csv');
      });

      test('TC-020 Normal: .yaml detected as text', () {
        final ct = ResourceContentType.fromExtension('yaml');
        expect(ct.isBinary, false);
        expect(ct.mimeType, 'text/yaml');
      });

      test('TC-020 Normal: .yml detected as text', () {
        final ct = ResourceContentType.fromExtension('yml');
        expect(ct.isBinary, false);
        expect(ct.mimeType, 'text/yaml');
      });

      test('TC-020 Normal: .xml detected as text', () {
        final ct = ResourceContentType.fromExtension('xml');
        expect(ct.isBinary, false);
        expect(ct.mimeType, 'application/xml');
      });

      test('TC-020 Normal: .html detected as text', () {
        final ct = ResourceContentType.fromExtension('html');
        expect(ct.isBinary, false);
        expect(ct.mimeType, 'text/html');
      });

      test('TC-020 Normal: .css detected as text', () {
        final ct = ResourceContentType.fromExtension('css');
        expect(ct.isBinary, false);
        expect(ct.mimeType, 'text/css');
      });

      test('TC-020 Normal: .dart detected as text', () {
        final ct = ResourceContentType.fromExtension('dart');
        expect(ct.isBinary, false);
        expect(ct.mimeType, 'text/x-dart');
      });

      test('TC-020 Normal: .svg detected as text (not binary)', () {
        final ct = ResourceContentType.fromExtension('svg');
        expect(ct.isBinary, false);
        expect(ct.mimeType, 'image/svg+xml');
      });
    });

    group('TC-021: Binary file encoding detection', () {
      test('TC-021 Normal: .png detected as binary', () {
        final ct = ResourceContentType.fromExtension('png');
        expect(ct.isBinary, true);
        expect(ct.mimeType, 'image/png');
      });

      test('TC-021 Normal: .jpg detected as binary', () {
        final ct = ResourceContentType.fromExtension('jpg');
        expect(ct.isBinary, true);
        expect(ct.mimeType, 'image/jpeg');
      });

      test('TC-021 Normal: .pdf detected as binary', () {
        final ct = ResourceContentType.fromExtension('pdf');
        expect(ct.isBinary, true);
        expect(ct.mimeType, 'application/pdf');
      });

      test('TC-021 Normal: .zip detected as binary', () {
        final ct = ResourceContentType.fromExtension('zip');
        expect(ct.isBinary, true);
        expect(ct.mimeType, 'application/zip');
      });

      test('TC-021 Normal: .gif detected as binary', () {
        final ct = ResourceContentType.fromExtension('gif');
        expect(ct.isBinary, true);
        expect(ct.mimeType, 'image/gif');
      });

      test('TC-021 Normal: .webp detected as binary', () {
        final ct = ResourceContentType.fromExtension('webp');
        expect(ct.isBinary, true);
        expect(ct.mimeType, 'image/webp');
      });

      test('TC-021 Normal: .mp3 detected as binary', () {
        final ct = ResourceContentType.fromExtension('mp3');
        expect(ct.isBinary, true);
        expect(ct.mimeType, 'audio/mpeg');
      });

      test('TC-021 Normal: .mp4 detected as binary', () {
        final ct = ResourceContentType.fromExtension('mp4');
        expect(ct.isBinary, true);
        expect(ct.mimeType, 'video/mp4');
      });
    });

    group('TC-022: Unknown content type', () {
      test('TC-022 Normal: unknown extension defaults to non-binary', () {
        final ct = ResourceContentType.fromExtension('xyz');
        expect(ct.isBinary, false);
        expect(ct.mimeType, 'application/octet-stream');
      });

      test('TC-022 Normal: case-insensitive extension matching', () {
        final ct = ResourceContentType.fromExtension('PNG');
        expect(ct.isBinary, true);
        expect(ct.mimeType, 'image/png');
      });
    });
  });

  group('ResourceSizeLimits Tests', () {
    group('TC-015 to TC-019: Size limit constants', () {
      test('TC-015: text file max is 10 MB', () {
        expect(ResourceSizeLimits.textMaxBytes, 10 * 1024 * 1024);
      });

      test('TC-016: binary file max is 50 MB', () {
        expect(ResourceSizeLimits.binaryMaxBytes, 50 * 1024 * 1024);
      });

      test('TC-018: temp file max is 100 MB', () {
        expect(ResourceSizeLimits.tempMaxBytes, 100 * 1024 * 1024);
      });

      test('TC-019: cache entry max is 5 MB', () {
        expect(ResourceSizeLimits.cacheMaxBytes, 5 * 1024 * 1024);
      });
    });
  });
}
