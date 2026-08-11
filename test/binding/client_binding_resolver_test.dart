// `client.*` — what a document may learn about the machine it is running on.
// 31% covered before this file, and the uncovered part included the allowlist
// that decides which environment variables a bundle can read.
//
// That last one is the reason this file exists rather than a coverage number:
// a marketplace bundle is someone else's code running on a user's machine, and
// `{{client.env.AWS_SECRET_ACCESS_KEY}}` is a one-line exfiltration if the
// gate is wrong. An untested allowlist is an allowlist nobody has watched say
// no.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/client_binding_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ClientBindingResolver resolver;

  setUp(() => resolver = ClientBindingResolver());

  group('what counts as a client binding', () {
    test('only a fully wrapped client expression', () {
      expect(resolver.isClientBinding('{{client.platform}}'), isTrue);
      expect(resolver.isClientBinding('{{clientele.platform}}'), isFalse);
      expect(resolver.isClientBinding('{{app.platform}}'), isFalse);
      expect(resolver.isClientBinding('{{client.platform'), isFalse,
          reason: 'an unterminated expression is not a binding');
      expect(resolver.isClientBinding('client.platform'), isFalse);
    });

    test('the path is what sits between the braces', () {
      expect(resolver.extractPath('{{client.theme.primary}}'), 'theme.primary');
      expect(resolver.extractPath('{{app.count}}'), isNull);
    });
  });

  group('platform facts', () {
    test('the OS is named, and the category is coarser', () {
      final os = resolver.resolve('{{client.platform.os}}');
      final category = resolver.resolve('{{client.platform}}');

      // The test runs on a desktop host; asserting the exact string would pin
      // the machine rather than the behaviour.
      expect(os, isIn(const ['android', 'ios', 'macos', 'windows', 'linux', 'fuchsia', 'web', 'unknown']));
      expect(category, isIn(const ['mobile', 'desktop', 'web', 'tablet', 'unknown']));
      expect(resolver.resolve('{{client.system.os}}'), os,
          reason: '`system.os` is the same fact under the spec name');
    });

    test('build-mode flags are mutually exclusive', () {
      final flags = [
        resolver.resolve('{{client.isDebug}}'),
        resolver.resolve('{{client.isRelease}}'),
        resolver.resolve('{{client.isProfile}}'),
      ];
      expect(flags.where((f) => f == true).length, 1,
          reason: 'a document that branches on these needs exactly one true');
      expect(resolver.resolve('{{client.isWeb}}'), isFalse);
    });

    test('locale, separator and version answer something usable', () {
      expect(resolver.resolve('{{client.locale}}'), isNotEmpty);
      expect(resolver.resolve('{{client.file.separator}}'),
          Platform.pathSeparator);
      expect(resolver.resolve('{{client.system.version}}'), isNotNull);
      expect(resolver.resolve('{{client.workingDirectory}}'), isNotEmpty);
    });

    test('an unknown path is null, not an exception', () {
      expect(resolver.resolve('{{client.nonsense}}'), isNull);
      expect(resolver.resolve('{{client.theme.notAColor}}'), isNull);
    });
  });

  group('client.env.* is gated', () {
    test('nothing is readable until system.info is granted', () {
      // PATH is on the allowlist, so this isolates the permission from the
      // allowlist: same variable, different answer.
      resolver.setSystemInfoPermission(false);
      expect(resolver.resolve('{{client.env.PATH}}'), isNull);

      resolver.clearCache();
      resolver.setSystemInfoPermission(true);
      expect(resolver.resolve('{{client.env.PATH}}'), isNotNull,
          reason: 'the grant is what opens the namespace');
    });

    test('a granted permission still refuses what is not on the allowlist', () {
      resolver.setSystemInfoPermission(true);
      for (final name in const [
        'AWS_SECRET_ACCESS_KEY',
        'GITHUB_TOKEN',
        'DATABASE_PASSWORD',
        'MY_API_KEY',
        'SESSION_SECRET',
        'PRIVATE_KEY',
        'NPM_AUTH_TOKEN',
      ]) {
        resolver.clearCache();
        expect(resolver.resolve('{{client.env.$name}}'), isNull,
            reason: '$name must never reach a document');
      }
    });

    test('the gate is case-insensitive; the lookup is the platform\'s', () {
      // The allowlist upper-cases before matching, so `path` is not refused as
      // "not on the list" — but the read itself goes to the platform, and POSIX
      // environments are case-sensitive, so `path` simply does not exist. Both
      // halves matter: a lower-case spelling must not be a bypass, and must not
      // be answered with a value the OS never had.
      resolver.setSystemInfoPermission(true);
      expect(resolver.resolve('{{client.env.PATH}}'), isNotNull);
      resolver.clearCache();
      expect(resolver.resolve('{{client.env.path}}'), isNull);

      resolver.clearCache();
      resolver.setSystemInfoPermission(false);
      expect(resolver.resolve('{{client.env.path}}'), isNull,
          reason: 'and it is still refused without the grant');
    });

    test('a variable that is allowed but unset is null', () {
      resolver.setSystemInfoPermission(true);
      expect(resolver.resolve('{{client.env.NO_SUCH_ALLOWED_VAR}}'), isNull);
    });
  });

  group('host theme colours', () {
    test('without a host theme, the colour paths answer null', () {
      expect(resolver.resolve('{{client.theme.primary}}'), isNull);
    });

    test('with one, each documented slot answers a hex string', () {
      resolver.setHostTheme(ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF112233),
          secondary: Color(0xFF445566),
          surface: Color(0xFF778899),
          error: Color(0xFFAABBCC),
        ),
      ));

      for (final path in const [
        'theme.primary',
        'theme.secondary',
        'theme.surface',
        'theme.error',
        'theme.background',
        'theme.foreground',
        'theme.textOnPrimary',
        'theme.textOnSecondary',
        'theme.textOnSurface',
        'theme.textOnError',
        'theme.textOnBackground',
      ]) {
        resolver.clearCache();
        final value = resolver.resolve('{{client.$path}}');
        expect(value, isA<String>(), reason: '$path answered ${value.runtimeType}');
        expect(value as String, matches(RegExp(r'^#[0-9a-fA-F]{6,8}$')),
            reason: '$path must be a colour a document can put in a style');
      }
    });

    test('the mode follows the host theme, not the OS preference', () {
      // Every other `client.theme.*` path reads the host theme, and this one
      // read the platform — so an app running dark on a light OS reported
      // `mode: light` beside dark colours, and a document choosing an asset by
      // mode chose the wrong one.
      resolver.setHostTheme(ThemeData.dark());
      expect(resolver.resolve('{{client.theme}}'), 'dark');

      resolver.clearCache();
      resolver.setHostTheme(ThemeData.light());
      expect(resolver.resolve('{{client.theme.mode}}'), 'light');
    });
  });

  group('cache', () {
    test('a resolved value is served from the cache while it is valid', () {
      resolver.setSystemInfoPermission(true);
      final first = resolver.resolve('{{client.env.PATH}}');

      // Revoking the permission does not change the cached answer — which is
      // the point of pinning it: the cache is a read-through, and a host that
      // revokes must clear it.
      resolver.setSystemInfoPermission(false);
      expect(resolver.resolve('{{client.env.PATH}}'), first);

      resolver.clearCache();
      expect(resolver.resolve('{{client.env.PATH}}'), isNull,
          reason: 'after a clear the revoked permission is what answers');
    });

    test('caching can be turned off', () {
      resolver
        ..cacheEnabled = false
        ..setSystemInfoPermission(true);
      expect(resolver.resolve('{{client.env.PATH}}'), isNotNull);

      resolver.setSystemInfoPermission(false);
      expect(resolver.resolve('{{client.env.PATH}}'), isNull,
          reason: 'with the cache off, every read asks again');
    });

    test('an expired cache is refreshed', () async {
      resolver
        ..cacheDurationSeconds = 0
        ..setSystemInfoPermission(true);
      expect(resolver.resolve('{{client.env.PATH}}'), isNotNull);

      resolver.setSystemInfoPermission(false);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(resolver.resolve('{{client.env.PATH}}'), isNull);
    });
  });

  group('the catalogue', () {
    test('every advertised path resolves without throwing', () {
      // `supportedPaths` is what a host or an authoring tool offers. A path on
      // that list that throws is worse than one that is missing.
      for (final path in ClientBindingResolver.supportedPaths) {
        if (path.endsWith('*')) continue; // a family, not a path
        expect(() => resolver.resolve('{{client.$path}}'), returnsNormally,
            reason: '$path is advertised');
      }
    });

    test('getAllValues answers the same as resolving each path', () {
      resolver.setHostTheme(ThemeData(brightness: Brightness.light));
      final all = resolver.getAllValues();
      expect(all, isNotEmpty);
      for (final entry in all.entries) {
        if (entry.key.startsWith('env')) continue;
        resolver.clearCache();
        expect(resolver.resolve('{{client.${entry.key}}}'), entry.value,
            reason: '${entry.key} disagreed between the two readers');
      }
    });
  });
}
