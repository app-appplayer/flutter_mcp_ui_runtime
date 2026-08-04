import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/core/constants/client_action_types.dart';
import 'package:flutter_mcp_ui_runtime/src/client_resources/client_resource_resolver.dart';

void main() {
  group('Resource Type Tests', () {
    group('TC-004: File resource type', () {
      test('TC-004 Normal: file:// prefix identifies file resource', () {
        final parsed = ClientResourceSchemes.parse('client://file/home/user/data.txt');
        expect(parsed, isNotNull);
        expect(parsed!.scheme, 'file');
        expect(parsed.path, 'home/user/data.txt');
      });

      test('TC-004 Boundary: file resource with empty path', () {
        final parsed = ClientResourceSchemes.parse('client://file/');
        expect(parsed, isNotNull);
        expect(parsed!.scheme, 'file');
        expect(parsed.path, '');
      });

      test('TC-004 Error: non-client URI returns null', () {
        final parsed = ClientResourceSchemes.parse('http://example.com/file.txt');
        expect(parsed, isNull);
      });
    });

    group('TC-005: Workspace resource type', () {
      test('TC-005 Normal: workspace path resolution', () {
        final parsed = ClientResourceSchemes.parse('client://workspace/src/main.dart');
        expect(parsed, isNotNull);
        expect(parsed!.scheme, 'workspace');
        expect(parsed.path, 'src/main.dart');
      });

      test('TC-005 Boundary: workspace with nested path', () {
        final parsed = ClientResourceSchemes.parse(
            'client://workspace/a/b/c/d.json');
        expect(parsed, isNotNull);
        expect(parsed!.scheme, 'workspace');
        expect(parsed.path, 'a/b/c/d.json');
      });

      test('TC-005 Error: workspace with path traversal detected by resolver', () {
        // Path traversal is rejected at parse time by PathValidator
        final parsed = ClientResourceSchemes.parse(
            'client://workspace/../../../etc/passwd');
        expect(parsed, isNull);
      });
    });

    group('TC-006: Temp resource type', () {
      test('TC-006 Normal: temp directory path', () {
        final parsed = ClientResourceSchemes.parse('client://temp/session_data');
        expect(parsed, isNotNull);
        expect(parsed!.scheme, 'temp');
        expect(parsed.path, 'session_data');
      });

      test('TC-006 Boundary: temp with simple name', () {
        final parsed = ClientResourceSchemes.parse('client://temp/a');
        expect(parsed, isNotNull);
        expect(parsed!.scheme, 'temp');
        expect(parsed.path, 'a');
      });
    });

    group('TC-007: Cache resource type', () {
      test('TC-007 Normal: cache directory path', () {
        final parsed = ClientResourceSchemes.parse('client://cache/user-prefs');
        expect(parsed, isNotNull);
        expect(parsed!.scheme, 'cache');
        expect(parsed.path, 'user-prefs');
      });

      test('TC-007 Boundary: cache key with dots', () {
        final parsed = ClientResourceSchemes.parse('client://cache/app.config.v2');
        expect(parsed, isNotNull);
        expect(parsed!.scheme, 'cache');
        expect(parsed.path, 'app.config.v2');
      });
    });

    group('TC-008: Path normalization for resources', () {
      test('TC-008 Normal: path preserved as-is in parsing', () {
        final parsed = ClientResourceSchemes.parse(
            'client://file/Users/test/data.json');
        expect(parsed, isNotNull);
        expect(parsed!.path, 'Users/test/data.json');
      });

      test('TC-008 Boundary: path with special characters', () {
        final parsed = ClientResourceSchemes.parse(
            'client://file/path/to/my%20file.txt');
        expect(parsed, isNotNull);
        expect(parsed!.path, 'path/to/my%20file.txt');
      });

      test('TC-008 Boundary: content type detection from extension', () {
        final jsonType = ResourceContentType.fromExtension('json');
        expect(jsonType.isBinary, false);
        expect(jsonType.mimeType, 'application/json');

        final pngType = ResourceContentType.fromExtension('png');
        expect(pngType.isBinary, true);
        expect(pngType.mimeType, 'image/png');
      });
    });

    group('TC-009: Unknown resource type handling', () {
      test('TC-009 Normal: unknown scheme parsed successfully', () {
        final parsed = ClientResourceSchemes.parse('client://custom/data');
        expect(parsed, isNotNull);
        expect(parsed!.scheme, 'custom');
        expect(parsed.path, 'data');
      });

      test('TC-009 Error: unknown extension is binary octet-stream', () {
        final contentType = ResourceContentType.fromExtension('xyz');
        expect(contentType.isBinary, true,
            reason: 'the same object already declares application/octet-stream; '
                'reading those bytes as UTF-8 corrupts them without failing');
        expect(contentType.mimeType, 'application/octet-stream');
      });

      test('TC-009 Error: empty extension is binary octet-stream', () {
        final contentType = ResourceContentType.fromExtension('');
        expect(contentType.isBinary, true);
        expect(contentType.mimeType, 'application/octet-stream');
      });
    });

    group('TC-010: URI parsing for different resource schemes', () {
      test('TC-010 Normal: all built-in schemes parse correctly', () {
        final schemes = {
          'client://file/test.txt': 'file',
          'client://workspace/src/main.dart': 'workspace',
          'client://temp/session': 'temp',
          'client://cache/key': 'cache',
          'client://asset/icons/logo.png': 'asset',
        };

        for (final entry in schemes.entries) {
          final parsed = ClientResourceSchemes.parse(entry.key);
          expect(parsed, isNotNull, reason: 'Failed to parse: ${entry.key}');
          expect(parsed!.scheme, entry.value,
              reason: 'Wrong scheme for: ${entry.key}');
        }
      });

      test('TC-010 Boundary: URI with no path after scheme', () {
        final parsed = ClientResourceSchemes.parse('client://file');
        expect(parsed, isNotNull);
        expect(parsed!.scheme, 'file');
        expect(parsed.path, '');
      });

      test('TC-010 Error: empty string returns null', () {
        final parsed = ClientResourceSchemes.parse('');
        expect(parsed, isNull);
      });

      test('TC-010 Normal: toString reconstructs URI', () {
        const uri = ClientResourceUri(scheme: 'file', path: 'test.txt');
        expect(uri.toString(), 'client://file/test.txt');
      });
    });
  });
}
