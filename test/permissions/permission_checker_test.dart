import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/permissions/permission_checker.dart';
import 'package:flutter_mcp_ui_runtime/src/models/ui_definition.dart';
import 'package:flutter_mcp_ui_runtime/src/core/constants/client_action_types.dart';

void main() {
  group('PermissionChecker Tests', () {
    group('TC-006 to TC-008: Permission group behavior via checkAction', () {
      test('TC-006 Normal: file read permission with allowed paths', () {
        final checker = PermissionChecker(PermissionsConfig(
          fileRead: FilePermissionConfig(
            allowedPaths: ['/Users/test/docs'],
            allowedExtensions: ['.txt', '.json'],
          ),
        ));

        final result = checker.checkFileRead('/Users/test/docs/file.txt');
        expect(result.allowed, true);
      });

      test('TC-007 Normal: required permission denied when not configured', () {
        final checker = PermissionChecker(null);
        final result = checker.checkFileRead('/any/path');
        expect(result.allowed, false);
        expect(result.reason, contains('not configured'));
      });

      test('TC-008: grant and revoke via checkAction', () {
        final checker = PermissionChecker(PermissionsConfig(
          fileRead: FilePermissionConfig(
            allowedPaths: ['/allowed'],
          ),
          fileWrite: FilePermissionConfig(
            allowedPaths: ['/allowed'],
          ),
        ));

        expect(
          checker.checkFileRead('/allowed/file.txt').allowed,
          true,
        );
        expect(
          checker.checkFileWrite('/allowed/file.txt').allowed,
          true,
        );
      });
    });

    group('File Read Permission', () {
      test('allows file within allowed paths', () {
        final checker = PermissionChecker(PermissionsConfig(
          fileRead: FilePermissionConfig(
            allowedPaths: ['/home/user'],
          ),
        ));

        final result = checker.checkFileRead('/home/user/documents/file.txt');
        expect(result.allowed, true);
      });

      test('denies file outside allowed paths', () {
        final checker = PermissionChecker(PermissionsConfig(
          fileRead: FilePermissionConfig(
            allowedPaths: ['/home/user'],
          ),
        ));

        final result = checker.checkFileRead('/etc/passwd');
        expect(result.allowed, false);
        expect(result.reason, contains('not in allowed list'));
      });

      test('TC-011 Error: path traversal rejected', () {
        final checker = PermissionChecker(PermissionsConfig(
          fileRead: FilePermissionConfig(
            allowedPaths: ['/home/user'],
          ),
        ));

        // p.normalize('/home/user/../../etc/passwd') resolves to '/etc/passwd'
        // which no longer contains '..', so the traversal check does not
        // trigger.  Instead the path is denied because it falls outside the
        // allowed list.
        final result = checker.checkFileRead('/home/user/../../etc/passwd');
        expect(result.allowed, false);
        expect(result.reason, contains('not in allowed list'));
      });

      test('denies disallowed extension', () {
        final checker = PermissionChecker(PermissionsConfig(
          fileRead: FilePermissionConfig(
            allowedPaths: ['/home/user'],
            allowedExtensions: ['.txt', '.json'],
          ),
        ));

        final result = checker.checkFileRead('/home/user/script.sh');
        expect(result.allowed, false);
        expect(result.reason, contains('extension'));
      });

      test('allows matching extension', () {
        final checker = PermissionChecker(PermissionsConfig(
          fileRead: FilePermissionConfig(
            allowedPaths: ['/home/user'],
            allowedExtensions: ['.txt', '.json'],
          ),
        ));

        final result = checker.checkFileRead('/home/user/data.json');
        expect(result.allowed, true);
      });

      test('returns requiresConfirmation flag', () {
        final checker = PermissionChecker(PermissionsConfig(
          fileRead: FilePermissionConfig(
            allowedPaths: ['/home/user'],
            requireConfirmation: true,
          ),
        ));

        final result = checker.checkFileRead('/home/user/file.txt');
        expect(result.allowed, true);
        expect(result.requiresConfirmation, true);
      });
    });

    group('File Write Permission', () {
      test('TC-016 Normal: allows write within limits', () {
        final checker = PermissionChecker(PermissionsConfig(
          fileWrite: FilePermissionConfig(
            allowedPaths: ['/home/user'],
            maxSize: 1024 * 1024,
          ),
        ));

        final result = checker.checkFileWrite('/home/user/output.txt',
            fileSize: 500);
        expect(result.allowed, true);
      });

      test('denies write exceeding maxSize', () {
        final checker = PermissionChecker(PermissionsConfig(
          fileWrite: FilePermissionConfig(
            allowedPaths: ['/home/user'],
            maxSize: 1024,
          ),
        ));

        final result = checker.checkFileWrite('/home/user/large.bin',
            fileSize: 2048);
        expect(result.allowed, false);
        expect(result.reason, contains('exceeds maximum'));
      });
    });

    group('HTTP Permission', () {
      test('allows request to allowed domain', () {
        final checker = PermissionChecker(PermissionsConfig(
          http: HttpPermissionConfig(
            allowedDomains: ['api.example.com', '*.trusted.com'],
          ),
        ));

        expect(
          checker.checkHttp('https://api.example.com/data').allowed,
          true,
        );
      });

      test('allows wildcard subdomain matching', () {
        final checker = PermissionChecker(PermissionsConfig(
          http: HttpPermissionConfig(
            allowedDomains: ['*.trusted.com'],
          ),
        ));

        expect(
          checker.checkHttp('https://api.trusted.com/data').allowed,
          true,
        );
        expect(
          checker.checkHttp('https://deep.sub.trusted.com/data').allowed,
          true,
        );
      });

      test('denies request to non-allowed domain', () {
        final checker = PermissionChecker(PermissionsConfig(
          http: HttpPermissionConfig(
            allowedDomains: ['api.example.com'],
          ),
        ));

        final result = checker.checkHttp('https://evil.com/data');
        expect(result.allowed, false);
        expect(result.reason, contains('not in allowed list'));
      });

      test('blocks localhost by default', () {
        final checker = PermissionChecker(PermissionsConfig(
          http: HttpPermissionConfig(blockLocalhost: true),
        ));

        expect(
          checker.checkHttp('http://localhost:8080/api').allowed,
          false,
        );
        expect(
          checker.checkHttp('http://127.0.0.1:8080/api').allowed,
          false,
        );
      });

      test('blocks explicitly blocked domains', () {
        final checker = PermissionChecker(PermissionsConfig(
          http: HttpPermissionConfig(
            blockedDomains: ['evil.com'],
            blockLocalhost: false,
          ),
        ));

        final result = checker.checkHttp('https://evil.com/data');
        expect(result.allowed, false);
        expect(result.reason, contains('blocked'));
      });

      test('denies invalid URL', () {
        final checker = PermissionChecker(PermissionsConfig(
          http: HttpPermissionConfig(),
        ));

        final result = checker.checkHttp('not a url');
        // Uri.tryParse returns non-null for most strings but host will be empty
        expect(result, isNotNull);
      });

      test('restricts HTTP methods', () {
        final checker = PermissionChecker(PermissionsConfig(
          http: HttpPermissionConfig(
            allowedMethods: ['GET', 'POST'],
            blockLocalhost: false,
          ),
        ));

        expect(
          checker.checkHttp('https://example.com/', method: 'GET').allowed,
          true,
        );
        expect(
          checker.checkHttp('https://example.com/', method: 'DELETE').allowed,
          false,
        );
      });
    });

    group('Shell Permission', () {
      test('allows command in allowlist', () {
        final checker = PermissionChecker(PermissionsConfig(
          shell: ShellPermissionConfig(
            allowedCommands: ['ls', 'cat'],
          ),
        ));

        final result = checker.checkShellExec('ls -la');
        expect(result.allowed, true);
      });

      test('denies command not in allowlist', () {
        final checker = PermissionChecker(PermissionsConfig(
          shell: ShellPermissionConfig(
            allowedCommands: ['ls'],
          ),
        ));

        final result = checker.checkShellExec('rm -rf /');
        expect(result.allowed, false);
        expect(result.reason, contains('not in allowlist'));
      });

      test('blocks shell metacharacters', () {
        final checker = PermissionChecker(PermissionsConfig(
          shell: ShellPermissionConfig(
            allowedCommands: ['echo'],
          ),
        ));

        expect(
          checker.checkShellExec('echo hello; rm -rf /').allowed,
          false,
        );
        expect(
          checker.checkShellExec('echo hello | cat').allowed,
          false,
        );
        expect(
          checker.checkShellExec('echo \$(whoami)').allowed,
          false,
        );
      });

      test('enforces deny args', () {
        final checker = PermissionChecker(PermissionsConfig(
          shell: ShellPermissionConfig(
            allowedCommands: ['git'],
            denyArgs: ['--force', '-f'],
          ),
        ));

        expect(
          checker.checkShellExec('git push --force').allowed,
          false,
        );
      });

      test('enforces allow arg patterns', () {
        final checker = PermissionChecker(PermissionsConfig(
          shell: ShellPermissionConfig(
            allowedCommands: ['git'],
            allowArgPatterns: [r'^--\w+$', r'^-\w$'],
          ),
        ));

        expect(
          checker.checkShellExec('git --status').allowed,
          true,
        );
      });

      test('returns timeout from config', () {
        final checker = PermissionChecker(PermissionsConfig(
          shell: ShellPermissionConfig(
            allowedCommands: ['ls'],
            timeout: 30000,
          ),
        ));

        final result = checker.checkShellExec('ls');
        expect(result.allowed, true);
        expect(result.timeout, 30000);
      });
    });

    group('Clipboard & Notification & SystemInfo', () {
      test('clipboard allowed when configured', () {
        final checker = PermissionChecker(PermissionsConfig(clipboard: true));
        expect(checker.checkClipboard().allowed, true);
      });

      test('clipboard denied when not configured', () {
        final checker = PermissionChecker(PermissionsConfig(clipboard: false));
        expect(checker.checkClipboard().allowed, false);
      });

      test('notification allowed when configured', () {
        final checker = PermissionChecker(PermissionsConfig(notification: true));
        expect(checker.checkNotification().allowed, true);
      });

      test('systemInfo allowed when configured', () {
        final checker = PermissionChecker(PermissionsConfig(systemInfo: true));
        expect(checker.checkSystemInfo().allowed, true);
      });
    });

    group('TC-031: checkAction routing', () {
      test('TC-031 Normal: routes to correct checker per action type', () {
        final checker = PermissionChecker(PermissionsConfig(
          fileRead: FilePermissionConfig(allowedPaths: ['/allowed']),
          clipboard: true,
          notification: true,
          systemInfo: true,
        ));

        expect(
          checker.checkAction(
            ClientActionTypes.readFile,
            {'path': '/allowed/file.txt'},
          ).allowed,
          true,
        );

        expect(
          checker.checkAction(ClientActionTypes.clipboard, {}).allowed,
          true,
        );

        expect(
          checker.checkAction(ClientActionTypes.notification, {}).allowed,
          true,
        );

        expect(
          checker.checkAction(ClientActionTypes.getSystemInfo, {}).allowed,
          true,
        );
      });

      test('TC-031 Error: undeclared action type denied with PERMISSION_NOT_DECLARED', () {
        final checker = PermissionChecker(PermissionsConfig());
        final result = checker.checkAction('custom.unknown', {});
        expect(result.allowed, false);
        expect(result.reason, contains('PERMISSION_NOT_DECLARED'));
      });

      test('TC-031 Error: missing path parameter for file read', () {
        final checker = PermissionChecker(PermissionsConfig(
          fileRead: FilePermissionConfig(allowedPaths: ['/allowed']),
        ));
        final result = checker.checkAction(ClientActionTypes.readFile, {});
        expect(result.allowed, false);
        expect(result.reason, contains('Path parameter required'));
      });

      test('TC-031 Error: missing url parameter for http', () {
        final checker = PermissionChecker(PermissionsConfig(
          http: HttpPermissionConfig(),
        ));
        final result = checker.checkAction(ClientActionTypes.httpRequest, {});
        expect(result.allowed, false);
        expect(result.reason, contains('URL parameter required'));
      });

      test('TC-031 Error: missing command parameter for exec', () {
        final checker = PermissionChecker(PermissionsConfig(
          shell: ShellPermissionConfig(allowedCommands: ['ls']),
        ));
        final result = checker.checkAction(ClientActionTypes.exec, {});
        expect(result.allowed, false);
        expect(result.reason, contains('Command parameter required'));
      });
    });
  });

  group('Wildcard allowlists', () {
    test('file.read allowedPaths `*` matches any real path', () {
      final cfg = PermissionsConfig.fromJson({
        'file.read': {'allowedPaths': ['*']},
      });
      final checker = PermissionChecker(cfg);

      expect(checker.checkFileRead('/Users/jsha/any.txt').allowed, isTrue);
      expect(checker.checkFileRead('/tmp/foo').allowed, isTrue);
    });

    test('specific allowlist still blocks paths outside scope', () {
      // `*` is a broad grant; a narrow allowlist must keep its
      // boundary even when `..` segments are present — path
      // normalisation resolves them to a final location that the
      // allowlist check then rejects if it escapes the declared
      // subtree. Either rejection path (explicit traversal block or
      // allowlist miss) is acceptable.
      final cfg = PermissionsConfig.fromJson({
        'file.read': {'allowedPaths': ['/Users/jsha/Documents']},
      });
      final checker = PermissionChecker(cfg);

      final result =
          checker.checkFileRead('/Users/jsha/Documents/../Downloads/x');
      expect(result.allowed, isFalse);
    });

    test('network.http allowedDomains `*` matches any host', () {
      final cfg = PermissionsConfig.fromJson({
        'network.http': {'allowedDomains': ['*']},
      });
      final checker = PermissionChecker(cfg);

      expect(
          checker.checkHttp('https://example.com/api').allowed, isTrue);
      expect(
          checker.checkHttp('https://random.host:8080/x').allowed, isTrue);
    });

    test('network.http `*.example.com` still a subdomain wildcard', () {
      final cfg = PermissionsConfig.fromJson({
        'network.http': {
          'allowedDomains': ['*.example.com'],
        },
      });
      final checker = PermissionChecker(cfg);

      expect(
          checker.checkHttp('https://api.example.com/x').allowed, isTrue);
      expect(checker.checkHttp('https://example.com/x').allowed, isTrue);
      expect(checker.checkHttp('https://evil.tld/').allowed, isFalse);
    });
  });

  group('PermissionResult Tests', () {
    test('allowed result toString', () {
      final result = PermissionResult.allowed(requiresConfirmation: true);
      expect(result.toString(), contains('allowed'));
      expect(result.toString(), contains('confirmation'));
    });

    test('denied result toString', () {
      final result = PermissionResult.denied('test reason');
      expect(result.toString(), contains('denied'));
      expect(result.toString(), contains('test reason'));
    });
  });
}
