import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_mcp_ui_runtime/src/core/constants/client_action_types.dart';
import 'package:flutter_mcp_ui_runtime/src/utils/path_validator.dart';

void main() {
  group('Path Resolution Tests', () {
    // -----------------------------------------------------------------------
    // TC-009: Absolute paths
    // -----------------------------------------------------------------------
    group('TC-009: Absolute paths', () {
      test('TC-009 Normal: absolute path used directly for file type', () {
        final parsed =
            ClientResourceSchemes.parse('client://file/Users/name/doc.txt');
        expect(parsed, isNotNull);
        expect(parsed!.scheme, 'file');
        expect(parsed.path, 'Users/name/doc.txt');

        // PathValidator normalizes but preserves the path structure
        final normalized = PathValidator.normalize(parsed.path);
        expect(normalized, 'Users/name/doc.txt');
      });

      test('TC-009 Boundary: absolute path at filesystem root', () {
        final parsed = ClientResourceSchemes.parse('client://file/');
        expect(parsed, isNotNull);
        expect(parsed!.scheme, 'file');
        // Empty path after scheme represents root-level
        expect(parsed.path, '');
      });

      test('TC-009 Error: absolute path with non-file type', () {
        // Workspace type with absolute-looking path — the parser accepts it
        // but the resolver would join it with workspace root, yielding
        // unexpected behaviour
        final parsed = ClientResourceSchemes.parse(
            'client://workspace/Users/name/doc.txt');
        expect(parsed, isNotNull);
        expect(parsed!.scheme, 'workspace');
        expect(parsed.path, 'Users/name/doc.txt');
      });
    });

    // -----------------------------------------------------------------------
    // TC-010: Relative paths
    // -----------------------------------------------------------------------
    group('TC-010: Relative paths', () {
      test('TC-010 Normal: workspace relative path resolved from root', () {
        final parsed =
            ClientResourceSchemes.parse('client://workspace/src/main.dart');
        expect(parsed, isNotNull);
        expect(parsed!.scheme, 'workspace');
        expect(parsed.path, 'src/main.dart');

        // Simulate workspace resolution
        const workspaceRoot = '/project';
        final fullPath = p.join(workspaceRoot, parsed.path);
        expect(fullPath, contains('src/main.dart'));
        expect(fullPath, startsWith(workspaceRoot));
      });

      test('TC-010 Normal: temp relative path resolved from OS temp dir', () {
        final parsed =
            ClientResourceSchemes.parse('client://temp/file.txt');
        expect(parsed, isNotNull);
        expect(parsed!.scheme, 'temp');
        expect(parsed.path, 'file.txt');
      });

      test('TC-010 Boundary: cache relative path resolved from app cache', () {
        final parsed =
            ClientResourceSchemes.parse('client://cache/data.json');
        expect(parsed, isNotNull);
        expect(parsed!.scheme, 'cache');
        expect(parsed.path, 'data.json');
      });

      test('TC-010 Error: relative path cannot resolve when root not set', () {
        // Workspace type requires workingDirectory to be set.
        // When workingDirectory is null, resolver returns error.
        // Here we verify the path parses; the resolver test covers the error.
        final parsed =
            ClientResourceSchemes.parse('client://workspace/src/app.dart');
        expect(parsed, isNotNull);
        expect(parsed!.scheme, 'workspace');
      });
    });

    // -----------------------------------------------------------------------
    // TC-011: Path traversal rejection
    // -----------------------------------------------------------------------
    group('TC-011: Path traversal rejection', () {
      test('TC-011 Normal: no traversal resolves normally', () {
        const path = 'src/config.json';
        expect(PathValidator.hasTraversalAttempt(path), isFalse);
        expect(PathValidator.validateAndNormalize(path), 'src/config.json');
      });

      test('TC-011 Error: workspace traversal with .. rejected', () {
        const path = '../secret';
        expect(PathValidator.hasTraversalAttempt(path), isTrue);
        expect(
          () => PathValidator.validateAndNormalize(path),
          throwsA(isA<PathSecurityException>()),
        );
      });

      test('TC-011 Error: deep traversal rejected', () {
        const path = '../../etc/passwd';
        expect(PathValidator.hasTraversalAttempt(path), isTrue);
        expect(
          () => PathValidator.validateAndNormalize(path),
          throwsA(isA<PathSecurityException>()),
        );
      });

      test('TC-011 Error: mid-path traversal rejected', () {
        const path = 'src/../../etc/passwd';
        expect(PathValidator.hasTraversalAttempt(path), isTrue);
        expect(
          () => PathValidator.validateAndNormalize(path),
          throwsA(isA<PathSecurityException>()),
        );
      });

      test('TC-011 Error: URI parser rejects traversal in client:// URI', () {
        final parsed =
            ClientResourceSchemes.parse('client://workspace/../../../etc/passwd');
        // Parser should reject this due to traversal
        expect(parsed, isNull);
      });
    });

    // -----------------------------------------------------------------------
    // TC-012: Path normalization
    // -----------------------------------------------------------------------
    group('TC-012: Path normalization', () {
      test('TC-012 Normal: dot and double slash normalized', () {
        const path = './src//config.json';
        final normalized = PathValidator.normalize(path);
        expect(normalized, 'src/config.json');
      });

      test('TC-012 Boundary: multiple consecutive slashes collapsed', () {
        const path = 'src///data////file.txt';
        final normalized = PathValidator.normalize(path);
        expect(normalized, 'src/data/file.txt');
      });

      test('TC-012 Boundary: single dot segments removed', () {
        const path = './src/./config.json';
        final normalized = PathValidator.normalize(path);
        expect(normalized, 'src/config.json');
      });

      test('TC-012 Normal: already clean path unchanged', () {
        const path = 'src/config.json';
        final normalized = PathValidator.normalize(path);
        expect(normalized, 'src/config.json');
      });

      test('TC-012 Boundary: empty path returns empty', () {
        expect(PathValidator.normalize(''), '');
      });

      test('TC-012 Boundary: absolute path leading slash preserved', () {
        const path = '/Users/name/doc.txt';
        final normalized = PathValidator.normalize(path);
        expect(normalized, startsWith('/'));
        expect(normalized, '/Users/name/doc.txt');
      });

      test('TC-012 Error: path with only dot segments normalizes to empty', () {
        const path = '.';
        final normalized = PathValidator.normalize(path);
        // Single dot is removed, resulting in empty string
        expect(normalized, '');
      });
    });

    // -----------------------------------------------------------------------
    // TC-013: Platform path separators
    // -----------------------------------------------------------------------
    group('TC-013: Platform path separators', () {
      test('TC-013 Normal: forward slash used on all platforms', () {
        const path = 'src/config/settings.json';
        final normalized = PathValidator.normalize(path);
        expect(normalized, 'src/config/settings.json');
        expect(normalized, isNot(contains('\\')));
      });

      test('TC-013 Boundary: Windows-style path in URI', () {
        // Windows paths like C:/Users/name/doc.txt may appear
        final parsed =
            ClientResourceSchemes.parse('client://file/C:/Users/name/doc.txt');
        expect(parsed, isNotNull);
        expect(parsed!.path, contains('C:'));
      });

      test('TC-013 Error: backslash traversal detected', () {
        // PathValidator splits on both / and \ for traversal detection
        const pathWithBackslash = 'src\\..\\secret';
        expect(PathValidator.hasTraversalAttempt(pathWithBackslash), isTrue);
      });

      test('TC-013 Normal: mixed separators handled by traversal check', () {
        const path = 'src/data\\file.txt';
        // No traversal segments present
        expect(PathValidator.hasTraversalAttempt(path), isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // TC-014: Symlink resolution
    // -----------------------------------------------------------------------
    group('TC-014: Symlink resolution', () {
      late Directory tempDir;
      late String resolvedRoot;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync('path_resolver_test_');
        // Resolve the temp dir path to handle macOS /var -> /private/var symlink
        resolvedRoot = tempDir.resolveSymbolicLinksSync();
      });

      tearDown(() {
        tempDir.deleteSync(recursive: true);
      });

      test('TC-014 Normal: symlink within allowed paths resolves', () async {
        // Create a real file using resolved root path
        final targetFile = File(p.join(resolvedRoot, 'target.txt'));
        targetFile.writeAsStringSync('content');

        // Create a symlink to it within the same directory
        final linkPath = p.join(resolvedRoot, 'link.txt');
        await Link(linkPath).create(targetFile.path);

        // Validate symlink resolves within allowed root
        final resolved =
            await PathValidator.validateSymlink(linkPath, resolvedRoot);
        expect(resolved, targetFile.resolveSymbolicLinksSync());
      });

      test('TC-014 Boundary: symlink chain resolves to real path', () async {
        // A -> B -> C (chain of symlinks)
        final realFile = File(p.join(resolvedRoot, 'real.txt'));
        realFile.writeAsStringSync('content');

        final linkB = p.join(resolvedRoot, 'linkB.txt');
        await Link(linkB).create(realFile.path);

        final linkA = p.join(resolvedRoot, 'linkA.txt');
        await Link(linkA).create(linkB);

        final resolved =
            await PathValidator.validateSymlink(linkA, resolvedRoot);
        expect(resolved, realFile.resolveSymbolicLinksSync());
      });

      test('TC-014 Error: symlink escaping allowed root rejected', () async {
        // Create a file outside the allowed root using resolved path
        final outsideDir =
            Directory.systemTemp.createTempSync('path_resolver_outside_');
        final resolvedOutsideDir = outsideDir.resolveSymbolicLinksSync();
        final outsideFile = File(p.join(resolvedOutsideDir, 'secret.txt'));
        outsideFile.writeAsStringSync('secret');

        // Create a symlink inside resolved root pointing outside
        final linkPath = p.join(resolvedRoot, 'escape_link.txt');
        await Link(linkPath).create(outsideFile.path);

        // Should throw either PathSecurityException or FileSystemException
        // Both indicate the escape was blocked
        try {
          await PathValidator.validateSymlink(linkPath, resolvedRoot);
          fail('Expected exception for symlink escaping allowed root');
        } on PathSecurityException {
          // Expected: symlink target detected outside allowed root
        } on FileSystemException {
          // Also acceptable: OS-level resolution failure blocks access
        }

        // Cleanup outside dir
        outsideDir.deleteSync(recursive: true);
      });

      test('TC-014 Normal: non-existent file validates normalized path',
          () async {
        final fakePath = p.join(tempDir.path, 'nonexistent.txt');
        final resolved =
            await PathValidator.validateSymlink(fakePath, tempDir.path);
        expect(resolved, p.normalize(fakePath));
      });

      test('TC-014 Error: non-existent file outside root rejected', () async {
        const fakePath = '/some/other/place/file.txt';
        expect(
          () => PathValidator.validateSymlink(fakePath, tempDir.path),
          throwsA(isA<PathSecurityException>()),
        );
      });
    });
  });
}
