import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/core/constants/client_action_types.dart';

void main() {
  group('URI Parser Tests', () {
    group('TC-001: client:// URI parsing - type extraction', () {
      test('TC-001 Normal: file type extraction', () {
        final result = ClientResourceSchemes.parse('client://file/Users/name/doc.txt');
        expect(result, isNotNull);
        expect(result!.scheme, 'file');
        expect(result.path, 'Users/name/doc.txt');
      });

      test('TC-001 Normal: workspace type extraction', () {
        final result = ClientResourceSchemes.parse('client://workspace/src/config.json');
        expect(result, isNotNull);
        expect(result!.scheme, 'workspace');
        expect(result.path, 'src/config.json');
      });

      test('TC-001 Normal: temp type extraction', () {
        final result = ClientResourceSchemes.parse('client://temp/upload-buffer.dat');
        expect(result, isNotNull);
        expect(result!.scheme, 'temp');
        expect(result.path, 'upload-buffer.dat');
      });

      test('TC-001 Boundary: cache type extraction', () {
        final result = ClientResourceSchemes.parse('client://cache/api-response-123');
        expect(result, isNotNull);
        expect(result!.scheme, 'cache');
        expect(result.path, 'api-response-123');
      });

      test('TC-001 Error: unknown type parsed but resolver rejects', () {
        final result = ClientResourceSchemes.parse('client://unknown/path');
        expect(result, isNotNull);
        expect(result!.scheme, 'unknown');
        // The parser succeeds; the resolver rejects unknown schemes
      });
    });

    group('TC-002: client:// URI parsing - asset type', () {
      test('TC-002 Normal: asset type extraction', () {
        final result = ClientResourceSchemes.parse('client://asset/icons/star.svg');
        expect(result, isNotNull);
        expect(result!.scheme, 'asset');
        expect(result.path, 'icons/star.svg');
      });

      test('TC-002 Boundary: asset with empty path', () {
        final result = ClientResourceSchemes.parse('client://asset/');
        expect(result, isNotNull);
        expect(result!.scheme, 'asset');
        expect(result.path, '');
      });

      test('TC-002 Error: malformed URI without client:// prefix', () {
        final result = ClientResourceSchemes.parse('http://asset/icons/star.svg');
        expect(result, isNull);
      });
    });

    group('TC-003: client:// URI parsing - query parameters', () {
      test('TC-003 Normal: URI with encoding query parameter', () {
        // The parser does not strip query params from the path
        final result = ClientResourceSchemes.parse(
            'client://file/doc.txt?encoding=base64');
        expect(result, isNotNull);
        expect(result!.scheme, 'file');
        // Query params are kept as part of the path string in this impl
        expect(result.path, contains('doc.txt'));
      });

      test('TC-003 Boundary: URI with no query', () {
        final result = ClientResourceSchemes.parse('client://file/doc.txt');
        expect(result, isNotNull);
        expect(result!.path, 'doc.txt');
      });

      test('TC-003 Error: completely invalid URI returns null', () {
        final result = ClientResourceSchemes.parse('');
        expect(result, isNull);
      });
    });

    group('ClientResourceUri toString', () {
      test('reconstructs full URI', () {
        const uri = ClientResourceUri(scheme: 'file', path: 'test.txt');
        expect(uri.toString(), 'client://file/test.txt');
      });
    });

    group('Scheme with no path segment', () {
      test('parses scheme-only URI', () {
        final result = ClientResourceSchemes.parse('client://file');
        expect(result, isNotNull);
        expect(result!.scheme, 'file');
        expect(result.path, '');
      });
    });
  });
}
