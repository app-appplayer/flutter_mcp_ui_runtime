// `PermissionsConfig` and its four sub-configs, read and written.
//
// This is what a document declares it is allowed to do, and what a host stores
// or forwards. Both directions matter: reading has to accept the dotted spec
// spelling AND the short one, because bundles in the field use both; writing
// has to produce something the reader accepts, or a config survives one hop
// and loses a rule on the next.

import 'package:flutter_mcp_ui_runtime/src/models/ui_definition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the dotted spelling and the short one mean the same thing', () {
    test('file.read / fileRead', () {
      final dotted = PermissionsConfig.fromJson({
        'file.read': {
          'allowedPaths': ['/tmp'],
        },
      });
      final short = PermissionsConfig.fromJson({
        'fileRead': {
          'allowedPaths': ['/tmp'],
        },
      });

      expect(dotted.fileRead!.allowedPaths, ['/tmp']);
      expect(short.fileRead!.allowedPaths, ['/tmp'],
          reason: 'a bundle written against either spelling has to keep its '
              'permissions — silently reading none is a document that can do '
              'nothing, with no error to explain it');
    });

    test('network.http / http', () {
      final dotted = PermissionsConfig.fromJson({
        'network.http': {
          'allowedDomains': ['example.test'],
        },
      });
      final short = PermissionsConfig.fromJson({
        'http': {
          'allowedDomains': ['example.test'],
        },
      });

      expect(dotted.http!.allowedDomains, ['example.test']);
      expect(short.http!.allowedDomains, ['example.test']);
    });

    test('system.exec / shell', () {
      final dotted = PermissionsConfig.fromJson({
        'system.exec': {
          'allowedCommands': ['echo'],
        },
      });
      final short = PermissionsConfig.fromJson({
        'shell': {
          'allowedCommands': ['echo'],
        },
      });

      expect(dotted.shell!.allowedCommands, ['echo']);
      expect(short.shell!.allowedCommands, ['echo']);
    });

    test('system.clipboard / clipboard and system.info / systemInfo', () {
      final dotted = PermissionsConfig.fromJson({
        'system.clipboard': true,
        'system.info': true,
      });
      final short = PermissionsConfig.fromJson({
        'clipboard': true,
        'systemInfo': true,
      });

      expect(dotted.clipboard, isTrue);
      expect(dotted.systemInfo, isTrue);
      expect(short.clipboard, isTrue);
      expect(short.systemInfo, isTrue);
    });

    test('an empty config declares nothing', () {
      final config = PermissionsConfig.fromJson(<String, dynamic>{});

      expect(config.fileRead, isNull);
      expect(config.fileWrite, isNull);
      expect(config.http, isNull);
      expect(config.shell, isNull);
      expect(config.clipboard, isNull);
      expect(config.systemInfo, isNull);
    });
  });

  group('the file rules', () {
    test('every declared field is read', () {
      final config = FilePermissionConfig.fromJson({
        'allowedPaths': ['/tmp', '/var'],
        'allowedExtensions': ['.txt'],
        'maxSize': 1024,
        'requireConfirmation': true,
      });

      expect(config.allowedPaths, ['/tmp', '/var']);
      expect(config.allowedExtensions, ['.txt']);
      expect(config.maxSize, 1024);
      expect(config.requireConfirmation, isTrue);
    });

    test('it survives a round trip', () {
      final source = {
        'allowedPaths': ['/tmp'],
        'allowedExtensions': ['.txt'],
        'maxSize': 1024,
        'requireConfirmation': true,
      };

      final round = FilePermissionConfig.fromJson(
          FilePermissionConfig.fromJson(source).toJson());

      expect(round.allowedPaths, ['/tmp']);
      expect(round.allowedExtensions, ['.txt']);
      expect(round.maxSize, 1024);
      expect(round.requireConfirmation, isTrue,
          reason: 'a rule that is read but not written is a rule that is lost '
              'the first time a host stores the config it was given');
    });
  });

  group('the http rules', () {
    test('every declared field is read', () {
      final config = HttpPermissionConfig.fromJson({
        'allowedDomains': ['example.test'],
        'blockedDomains': ['evil.test'],
        'allowedMethods': ['GET', 'POST'],
        'blockLocalhost': false,
      });

      expect(config.allowedDomains, ['example.test']);
      expect(config.blockedDomains, ['evil.test']);
      expect(config.allowedMethods, ['GET', 'POST']);
      expect(config.blockLocalhost, isFalse);
    });

    test('localhost is blocked unless the document says otherwise', () {
      final config = HttpPermissionConfig.fromJson(<String, dynamic>{});

      expect(config.blockLocalhost, isTrue,
          reason: 'a document reaching the host\'s own loopback is reaching '
              'services the user never exposed; the default has to be the '
              'safe one');
    });

    test('it survives a round trip, including the default', () {
      final round = HttpPermissionConfig.fromJson(
          HttpPermissionConfig.fromJson({
            'allowedDomains': ['example.test'],
            'blockedDomains': ['evil.test'],
            'allowedMethods': ['GET'],
          }).toJson());

      expect(round.allowedDomains, ['example.test']);
      expect(round.blockedDomains, ['evil.test']);
      expect(round.allowedMethods, ['GET']);
      expect(round.blockLocalhost, isTrue,
          reason: 'a default that is not written is a default the next reader '
              'has to guess');
    });
  });

  group('the shell rules', () {
    test('every declared field is read, including the argument rules', () {
      final config = ShellPermissionConfig.fromJson({
        'allowedCommands': ['echo'],
        'allowedWorkingDirs': ['/tmp'],
        'timeout': 5000,
        'requireConfirmation': false,
        'args': {
          'deny': ['--force'],
          'allowPatterns': [r'^-{1,2}\w+$'],
        },
      });

      expect(config.allowedCommands, ['echo']);
      expect(config.allowedWorkingDirs, ['/tmp']);
      expect(config.timeout, 5000);
      expect(config.requireConfirmation, isFalse);
      expect(config.denyArgs, ['--force']);
      expect(config.allowArgPatterns, [r'^-{1,2}\w+$']);
    });

    test('confirmation is required unless the document says otherwise', () {
      final config = ShellPermissionConfig.fromJson({
        'allowedCommands': ['echo'],
      });

      expect(config.requireConfirmation, isTrue,
          reason: 'running a command on the user\'s machine without asking is '
              'the one default that cannot be permissive');
    });

    test('it survives a round trip, arguments included', () {
      final round = ShellPermissionConfig.fromJson(
          ShellPermissionConfig.fromJson({
            'allowedCommands': ['echo'],
            'allowedWorkingDirs': ['/tmp'],
            'timeout': 5000,
            'args': {
              'deny': ['--force'],
              'allowPatterns': ['^-'],
            },
          }).toJson());

      expect(round.allowedCommands, ['echo']);
      expect(round.timeout, 5000);
      expect(round.denyArgs, ['--force'],
          reason: 'the argument deny-list is the difference between `rm` on a '
              'file and `rm -rf` on a tree');
      expect(round.allowArgPatterns, ['^-']);
    });
  });

  group('the whole config', () {
    test('round-trips every section', () {
      final source = PermissionsConfig.fromJson({
        'file.read': {
          'allowedPaths': ['/tmp'],
        },
        'file.write': {
          'allowedPaths': ['/tmp/out'],
        },
        'network.http': {
          'allowedDomains': ['example.test'],
        },
        'system.exec': {
          'allowedCommands': ['echo'],
        },
        'system.clipboard': true,
        'notification': true,
        'system.info': true,
      });

      final json = source.toJson();
      final round = PermissionsConfig.fromJson(json);

      expect(round.fileRead!.allowedPaths, ['/tmp']);
      expect(round.fileWrite!.allowedPaths, ['/tmp/out']);
      expect(round.http!.allowedDomains, ['example.test']);
      expect(round.shell!.allowedCommands, ['echo'],
          reason: 'toJson writes `shell` and fromJson reads either spelling; '
              'a mismatch here loses the whole section on the first hop');
      expect(round.clipboard, isTrue);
      expect(round.notification, isTrue);
      expect(round.systemInfo, isTrue);
    });

    test('an empty config writes nothing rather than nulls', () {
      final json = PermissionsConfig.fromJson(<String, dynamic>{}).toJson();

      expect(json, isEmpty,
          reason: 'a config full of explicit nulls reads as "declared and '
              'empty" to anything merging two of them');
    });
  });
}
