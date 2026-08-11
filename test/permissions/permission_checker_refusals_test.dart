// `PermissionChecker` — the refusals.
//
// Every branch here is the line between a document doing what it declared and
// a document reaching past it. A shell allowlist that lets an argument
// through, a path check that follows `..`, an extension filter that never
// runs: each one is the check the user agreed to, not happening.

import 'package:flutter_mcp_ui_runtime/src/models/ui_definition.dart';
import 'package:flutter_mcp_ui_runtime/src/permissions/permission_checker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PermissionChecker checkerFor(Map<String, dynamic> json) =>
      PermissionChecker(PermissionsConfig.fromJson(json));

  group('the file picker', () {
    test('is refused when file read was never declared', () {
      final checker = checkerFor(<String, dynamic>{});

      final result = checker.checkAction(
          'client.selectFile', <String, dynamic>{});

      expect(result.allowed, isFalse,
          reason: 'opening the OS picker is the first half of reading a file; '
              'allowing it for a document that never declared file access '
              'puts a chooser in front of the user for nothing');
      expect(result.reason, contains('not configured'));
    });

    test('is allowed when it was, without naming a path', () {
      final checker = checkerFor(<String, dynamic>{
        'file.read': <String, dynamic>{'allowedPaths': <dynamic>['/data']},
      });

      final result = checker.checkAction(
          'client.selectFile', <String, dynamic>{});

      expect(result.allowed, isTrue,
          reason: 'the path is not known until the user picks one; the read '
              'that follows re-validates it against the same allowlist');
    });
  });

  // The WRITE side has its own copy of every check the read side has, which is
  // exactly why it needs its own tests: a filter wired in one and missed in
  // the other is invisible until a document writes a file.
  group('file write', () {
    test('an extension outside the declared list is refused on write too', () {
      final checker = checkerFor(<String, dynamic>{
        'file.write': <String, dynamic>{
          'allowedPaths': <dynamic>['/data'],
          'allowedExtensions': <dynamic>['.csv'],
        },
      });

      expect(checker.checkFileWrite('/data/out.csv').allowed, isTrue);

      final refused = checker.checkFileWrite('/data/out.exe');
      expect(refused.allowed, isFalse);
      expect(refused.reason, contains('.exe'),
          reason: 'naming the extension is what tells an author their file '
              'type was the problem rather than the folder');
    });

    test('with no write permission declared at all, nothing is written', () {
      final checker = checkerFor(<String, dynamic>{});

      final refused = checker.checkFileWrite('/data/out.csv');
      expect(refused.allowed, isFalse);
      expect(refused.reason, contains('not configured'));
    });
  });

  group('file access', () {
    test('an extension outside the declared list is refused', () {
      final checker = checkerFor(<String, dynamic>{
        'file.read': <String, dynamic>{
          'allowedPaths': <dynamic>['/data'],
          'allowedExtensions': <dynamic>['.csv', '.json'],
        },
      });

      expect(checker.checkFileRead('/data/report.csv').allowed, isTrue);
      final refused = checker.checkFileRead('/data/report.exe');
      expect(refused.allowed, isFalse);
      expect(refused.reason, contains('.exe'),
          reason: 'naming the extension is what tells an author which line '
              'of their manifest to change');
    });

    test('a relative escape is refused even under a wildcard allowlist', () {
      final checker = checkerFor(<String, dynamic>{
        'file.read': <String, dynamic>{
          'allowedPaths': <dynamic>['*'],
        },
      });

      expect(checker.checkFileRead('../../etc/passwd').allowed, isFalse,
          reason: 'the wildcard means "any path the user picks", not "any '
              'path a relative segment can climb to"');
      expect(checker.checkFileRead('/data/report.csv').allowed, isTrue);
    });

    test('a traversal that resolves outside the allowlist is refused there',
        () {
      final checker = checkerFor(<String, dynamic>{
        'file.read': <String, dynamic>{
          'allowedPaths': <dynamic>['/data'],
        },
      });

      expect(checker.checkFileRead('/data/../etc/passwd').allowed, isFalse,
          reason: 'normalising first is what makes the prefix check mean '
              'something — comparing the raw string would let the segment '
              'through');
      expect(checker.checkFileRead('/data/report.csv').allowed, isTrue);
    });

    test('with no paths declared nothing is readable', () {
      final checker = checkerFor(<String, dynamic>{
        'file.read': <String, dynamic>{'allowedExtensions': <dynamic>['.csv']},
      });

      expect(checker.checkFileRead('/data/report.csv').reason,
          contains('No paths in allowlist'));
    });

    test('an unconfigured permission is refused by name', () {
      final checker = checkerFor(<String, dynamic>{});

      expect(checker.checkFileRead('/data/a.csv').reason,
          contains('not configured'));
      expect(checker.checkFileWrite('/data/a.csv').reason,
          contains('not configured'));
      expect(checker.checkHttp('https://example.com').reason,
          contains('not configured'));
      expect(checker.checkShellExec('ls').reason, contains('not configured'));
    });
  });

  group('http', () {
    test('a url that will not parse is refused rather than guessed at', () {
      final checker = checkerFor(<String, dynamic>{
        'network.http': <String, dynamic>{
          'allowedDomains': <dynamic>['example.com'],
        },
      });

      expect(checker.checkHttp('http://[::1').reason,
          contains('Invalid URL format'));
    });

    test('localhost is blocked when the manifest says so', () {
      final checker = checkerFor(<String, dynamic>{
        'network.http': <String, dynamic>{
          'allowedDomains': <dynamic>['*'],
          'blockLocalhost': true,
        },
      });

      expect(checker.checkHttp('http://localhost:8080/x').allowed, isFalse);
      expect(checker.checkHttp('http://127.0.0.1/x').allowed, isFalse,
          reason: 'the loopback address is the same destination under a '
              'different name');
    });
  });

  group('shell execution', () {
    PermissionChecker shell(Map<String, dynamic> config) =>
        checkerFor(<String, dynamic>{'system.exec': config});

    test('with an empty allowlist nothing runs', () {
      expect(
          shell(<String, dynamic>{'allowedCommands': <dynamic>[]})
              .checkShellExec('ls')
              .reason,
          contains('No commands in allowlist'));
    });

    test('a command outside the allowlist is named', () {
      final checker = shell(<String, dynamic>{
        'allowedCommands': <dynamic>['ls'],
      });

      expect(checker.checkShellExec('ls -la').allowed, isTrue);
      expect(checker.checkShellExec('rm -rf /').reason, contains('rm'));
    });

    test('shell metacharacters are refused even inside an allowed command',
        () {
      final checker = shell(<String, dynamic>{
        'allowedCommands': <dynamic>['ls'],
      });

      expect(checker.checkShellExec('ls; rm -rf /').allowed, isFalse,
          reason: 'the allowlist checks the first word; a metacharacter turns '
              'one allowed command into two arbitrary ones');
    });

    test('a denied argument is refused by name', () {
      final checker = shell(<String, dynamic>{
        'allowedCommands': <dynamic>['git'],
        'denyArgs': <dynamic>['--exec'],
      });

      expect(checker.checkShellExec('git status').allowed, isTrue);
      expect(checker.checkShellExec('git --exec').reason, contains('--exec'));
    });

    test('an argument matching no allowed pattern is refused', () {
      final checker = shell(<String, dynamic>{
        'allowedCommands': <dynamic>['git'],
        'allowArgPatterns': <dynamic>[r'^--?[a-z]+$', r'^status$'],
      });

      expect(checker.checkShellExec('git status').allowed, isTrue);
      expect(checker.checkShellExec('git /etc/passwd').reason,
          contains('does not match any allowed pattern'),
          reason: 'an allowlist of commands with no control over arguments is '
              'an allowlist of one command and every path on the disk');
    });

    test('a working directory outside the allowed ones is refused', () {
      final checker = shell(<String, dynamic>{
        'allowedCommands': <dynamic>['ls'],
        'allowedWorkingDirs': <dynamic>['/workspace'],
      });

      expect(checker.checkShellExec('ls', workingDir: '/workspace').allowed,
          isTrue);
      expect(checker.checkShellExec('ls', workingDir: '/etc').reason,
          contains('Working directory'));
    });
  });

  group('the simple grants', () {
    test('clipboard, notification and system info answer what was declared',
        () {
      final granted = checkerFor(<String, dynamic>{
        'system.clipboard': true,
        'notification': true,
        'system.info': true,
      });
      expect(granted.checkClipboard().allowed, isTrue);
      expect(granted.checkNotification().allowed, isTrue);
      expect(granted.checkSystemInfo().allowed, isTrue);

      final withheld = checkerFor(<String, dynamic>{});
      expect(withheld.checkClipboard().allowed, isFalse);
      expect(withheld.checkNotification().allowed, isFalse);
      expect(withheld.checkSystemInfo().allowed, isFalse);
    });
  });
}
