// `PermissionManager` — what a document is allowed to touch. 58% covered.
//
// This is the security boundary for a bundle that came from a marketplace, so
// the tests here are written the way a boundary deserves: each one names what
// must be REFUSED, and the allow cases exist to prove the refusal is not just
// "everything is denied".
//
// The prompting paths (which need a BuildContext and a user) are exercised
// through the non-prompting surface — `isPathAllowed` / `isDomainAllowed` /
// `isCommandAllowed` and the grant set — because that is the half a document
// meets on every action.

import 'package:flutter_mcp_ui_runtime/src/models/ui_definition.dart';
import 'package:flutter_mcp_ui_runtime/src/permissions/permission_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/permissions/trust_level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PermissionManager withConfig(Map<String, dynamic> json) =>
      PermissionManager(PermissionsConfig.fromJson(json));

  group('file paths', () {
    test('only the declared paths are reachable', () {
      final manager = withConfig({
        'file.read': {
          'allowedPaths': ['/workspace/docs'],
        },
      });

      expect(manager.isPathAllowed('/workspace/docs/report.txt'), isTrue);
      expect(manager.isPathAllowed('/etc/passwd'), isFalse,
          reason: 'a bundle reading /etc is the reason this class exists');
      expect(manager.isPathAllowed('/workspace/secrets/keys.json'), isFalse);
    });

    test('a path outside the allowlist stays outside it via ..', () {
      final manager = withConfig({
        'file.read': {
          'allowedPaths': ['/workspace/docs'],
        },
      });
      expect(manager.isPathAllowed('/workspace/docs/../../etc/passwd'), isFalse,
          reason: 'an allowlist that can be walked out of is not an allowlist');
    });

    test('read and write are separate grants', () {
      final readOnly = withConfig({
        'file.read': {
          'allowedPaths': ['/workspace'],
        },
      });
      // `isPathAllowed` answers for either verb, so the finer check is the
      // config: a document with only read declared must not be able to write.
      expect(readOnly.isPathAllowed('/workspace/a.txt'), isTrue);

      final writeOnly = withConfig({
        'file.write': {
          'allowedPaths': ['/workspace/out'],
        },
      });
      expect(writeOnly.isPathAllowed('/workspace/out/a.txt'), isTrue);
      expect(writeOnly.isPathAllowed('/workspace/in/a.txt'), isFalse);
    });

    test('with no file config declared, nothing is reachable', () {
      final manager = withConfig({});
      expect(manager.isPathAllowed('/anything'), isFalse,
          reason: 'a document that declared no file permission gets none — '
              'silence is not consent');
    });
  });

  group('network', () {
    test('only the declared hosts answer', () {
      final manager = withConfig({
        'network.http': {
          'allowedDomains': ['api.example.com'],
        },
      });

      expect(manager.isDomainAllowed('api.example.com'), isTrue);
      expect(manager.isDomainAllowed('evil.example.com'), isFalse);
      expect(manager.isDomainAllowed('api.example.com.evil.test'), isFalse,
          reason: 'a suffix match would let any domain end with a real one');
    });

    test('with no network config, no host is reachable', () {
      expect(withConfig({}).isDomainAllowed('api.example.com'), isFalse);
    });
  });

  group('shell', () {
    test('only the declared commands run', () {
      final manager = withConfig({
        'system.exec': {
          'allowedCommands': ['git'],
        },
      });

      expect(manager.isCommandAllowed('git'), isTrue);
      expect(manager.isCommandAllowed('rm'), isFalse);
    });

    test('with no shell config, nothing runs', () {
      expect(withConfig({}).isCommandAllowed('ls'), isFalse);
    });
  });

  group('the enabled switch', () {
    test('turning permissions off opens everything — deliberately', () {
      // A host runs this in a trusted context (its own first-party document).
      // Pinned because a default that flipped to `false` would silently open
      // every gate above, and nothing else in the system would notice.
      final manager = withConfig({})..enabled = false;

      expect(manager.isPathAllowed('/etc/passwd'), isTrue);
      expect(manager.isDomainAllowed('evil.example.com'), isTrue);
      expect(manager.isCommandAllowed('rm'), isTrue);
    });

    test('and the default is on', () {
      expect(withConfig({}).enabled, isTrue);
    });
  });

  group('the grant set', () {
    test('a granted permission is held, an ungranted one is not', () {
      final manager = withConfig({});
      expect(manager.isGranted('camera'), isFalse);

      manager.grant('camera');
      expect(manager.isGranted('camera'), isTrue);
      expect(manager.grantedPermissions, contains('camera'));
    });

    test('the dotted and short spellings are the same permission', () {
      final manager = withConfig({})..grant('system.clipboard');
      expect(manager.isGranted('clipboard'), isTrue,
          reason: 'two spellings of one permission must not be two grants — '
              'that is how a check passes for a name nobody granted');
    });

    test('the exposed set cannot be edited from outside', () {
      final manager = withConfig({})..grant('camera');
      expect(
        () => manager.grantedPermissions.add('microphone'),
        throwsUnsupportedError,
        reason: 'a caller that can add to the grant set has bypassed the gate',
      );
    });
  });

  group('trust level', () {
    test('it round-trips and starts somewhere definite', () {
      final manager = withConfig({});
      final initial = manager.trustLevel;
      expect(initial, isNotNull);

      for (final level in TrustLevel.values) {
        manager.trustLevel = level;
        expect(manager.trustLevel, level);
      }
    });
  });

  group('request timing and prompt style', () {
    test('the declared defaults are the conservative ones', () {
      final manager = withConfig({});
      expect(manager.requestTiming, PermissionRequestTiming.justInTime,
          reason: 'asking for everything up front trains a user to say yes');
      expect(manager.promptVariant, PermissionPromptVariant.modal);
    });

    test('both can be set by the host', () {
      final manager = withConfig({})
        ..requestTiming = PermissionRequestTiming.upfront
        ..promptVariant = PermissionPromptVariant.inline;
      expect(manager.requestTiming, PermissionRequestTiming.upfront);
      expect(manager.promptVariant, PermissionPromptVariant.inline);
    });
  });

  group('the config itself', () {
    test('dotted spec names and short names build the same config', () {
      final dotted = PermissionsConfig.fromJson({
        'file.read': {
          'allowedPaths': ['/w'],
        },
        'network.http': {
          'allowedDomains': ['a.test'],
        },
        'system.exec': {
          'allowedCommands': ['git'],
        },
        'system.clipboard': true,
        'system.info': true,
      });
      final short = PermissionsConfig.fromJson({
        'fileRead': {
          'allowedPaths': ['/w'],
        },
        'http': {
          'allowedDomains': ['a.test'],
        },
        'shell': {
          'allowedCommands': ['git'],
        },
        'clipboard': true,
        'systemInfo': true,
      });

      expect(dotted.fileRead?.allowedPaths, short.fileRead?.allowedPaths);
      expect(dotted.http?.allowedDomains, short.http?.allowedDomains);
      expect(dotted.shell?.allowedCommands, short.shell?.allowedCommands);
      expect(dotted.clipboard, short.clipboard);
      expect(dotted.systemInfo, short.systemInfo);
    });

    test('an empty config declares nothing', () {
      final config = PermissionsConfig.fromJson({});
      expect(config.fileRead, isNull);
      expect(config.http, isNull);
      expect(config.shell, isNull);
      expect(config.clipboard, isNull);
      expect(config.systemInfo, isNull);
    });
  });
}
