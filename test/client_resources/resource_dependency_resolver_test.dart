import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_mcp_ui_runtime/src/client_resources/resource_dependency_resolver.dart';
import 'package:flutter_mcp_ui_runtime/src/client_resources/client_resource_resolver.dart';

void main() {
  late ClientResourceResolver resolver;
  late ResourceDependencyResolver depResolver;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'mcp_client_cache_config': '{"themeName": "dark-theme"}',
      'mcp_client_cache_dark-theme': '{"color": "black"}',
      'mcp_client_cache_theme-data': '{"primary": "#000"}',
      'mcp_client_cache_independent': '"standalone"',
    });
    resolver = ClientResourceResolver();
    await resolver.init();
    depResolver = ResourceDependencyResolver(resolver);
  });

  group('ResourceDeclaration Tests', () {
    test('fromJson parses correctly', () {
      final decl = ResourceDeclaration.fromJson('config', {
        'source': 'client://cache/config',
        'dependsOn': ['other'],
        'optional': true,
        'transform': [
          {'type': 'parse', 'format': 'json'},
        ],
      });
      expect(decl.key, 'config');
      expect(decl.source, 'client://cache/config');
      expect(decl.dependsOn, ['other']);
      expect(decl.optional, true);
      expect(decl.transform, isNotNull);
    });

    test('fromJson defaults', () {
      final decl = ResourceDeclaration.fromJson('data', {
        'source': 'client://cache/data',
      });
      expect(decl.dependsOn, isEmpty);
      expect(decl.optional, false);
      expect(decl.transform, isNull);
    });
  });

  group('ResourceDependencyResolver Tests', () {
    group('TC-051: dependsOn - basic dependency', () {
      test('TC-051 Normal: resources with dependencies load in order', () async {
        final declarations = [
          const ResourceDeclaration(
            key: 'config',
            source: 'client://cache/config',
          ),
          const ResourceDeclaration(
            key: 'theme',
            source: 'client://cache/theme-data',
            dependsOn: ['config'],
          ),
        ];

        final result = await depResolver.resolve(declarations);
        expect(result.resources.containsKey('config'), true);
        expect(result.resources.containsKey('theme'), true);
        expect(result.errors, isEmpty);
      });

      test('TC-051 Boundary: resource with no dependsOn loads independently', () async {
        final declarations = [
          const ResourceDeclaration(
            key: 'independent',
            source: 'client://cache/independent',
          ),
        ];

        final result = await depResolver.resolve(declarations);
        expect(result.resources.containsKey('independent'), true);
      });

      test('TC-051 Error: dependency fails - dependent receives error', () async {
        final declarations = [
          const ResourceDeclaration(
            key: 'missing',
            source: 'client://cache/nonexistent',
          ),
          const ResourceDeclaration(
            key: 'dependent',
            source: 'client://cache/config',
            dependsOn: ['missing'],
          ),
        ];

        final result = await depResolver.resolve(declarations);
        expect(result.errors.containsKey('missing'), true);
        expect(result.errors.containsKey('dependent'), true);
      });
    });

    group('TC-052: Circular dependency detection', () {
      test('TC-052 Normal: no cycle - validates successfully', () {
        final declarations = [
          const ResourceDeclaration(
            key: 'a',
            source: 'client://cache/a',
          ),
          const ResourceDeclaration(
            key: 'b',
            source: 'client://cache/b',
            dependsOn: ['a'],
          ),
        ];

        // Should not throw
        depResolver.validate(declarations);
      });

      test('TC-052 Boundary: chain A -> B -> C resolves in order', () async {
        final declarations = [
          const ResourceDeclaration(
            key: 'a',
            source: 'client://cache/config',
          ),
          const ResourceDeclaration(
            key: 'b',
            source: 'client://cache/config',
            dependsOn: ['a'],
          ),
          const ResourceDeclaration(
            key: 'c',
            source: 'client://cache/config',
            dependsOn: ['b'],
          ),
        ];

        depResolver.validate(declarations);
        final result = await depResolver.resolve(declarations);
        expect(result.resources.containsKey('a'), true);
        expect(result.resources.containsKey('b'), true);
        expect(result.resources.containsKey('c'), true);
      });

      test('TC-052 Error: A depends on B, B depends on A - circular dependency', () {
        final declarations = [
          const ResourceDeclaration(
            key: 'a',
            source: 'client://cache/a',
            dependsOn: ['b'],
          ),
          const ResourceDeclaration(
            key: 'b',
            source: 'client://cache/b',
            dependsOn: ['a'],
          ),
        ];

        expect(
          () => depResolver.validate(declarations),
          throwsA(isA<ResourceCircularDependencyException>()),
        );
      });

      test('TC-052 Error: circular dependency has correct cycle info', () {
        final declarations = [
          const ResourceDeclaration(
            key: 'a',
            source: 'client://cache/a',
            dependsOn: ['b'],
          ),
          const ResourceDeclaration(
            key: 'b',
            source: 'client://cache/b',
            dependsOn: ['a'],
          ),
        ];

        try {
          depResolver.validate(declarations);
          fail('Should have thrown');
        } on ResourceCircularDependencyException catch (e) {
          expect(e.message, contains('CIRCULAR_DEPENDENCY'));
          expect(e.cycle, isNotEmpty);
          expect(e.toString(), contains('CIRCULAR_DEPENDENCY'));
        }
      });
    });

    group('TC-053: Optional dependency failure', () {
      test('TC-053 Normal: optional dependency fails - dependent gets null', () async {
        final declarations = [
          const ResourceDeclaration(
            key: 'missing',
            source: 'client://cache/nonexistent',
            optional: true,
          ),
          const ResourceDeclaration(
            key: 'dependent',
            source: 'client://cache/config',
            dependsOn: ['missing'],
          ),
        ];

        final result = await depResolver.resolve(declarations);
        // Optional resource resolves to null
        expect(result.resources['missing'], isNull);
        // Dependent should still load since missing is optional
        expect(result.resources.containsKey('dependent'), true);
      });
    });

    group('TC-063: Circular dependency error', () {
      test('TC-063 Boundary: deep chain without cycle resolves', () async {
        final declarations = [
          const ResourceDeclaration(key: 'a', source: 'client://cache/config'),
          const ResourceDeclaration(
              key: 'b', source: 'client://cache/config', dependsOn: ['a']),
          const ResourceDeclaration(
              key: 'c', source: 'client://cache/config', dependsOn: ['b']),
          const ResourceDeclaration(
              key: 'd', source: 'client://cache/config', dependsOn: ['c']),
        ];

        depResolver.validate(declarations);
        final result = await depResolver.resolve(declarations);
        expect(result.resources.length, 4);
      });
    });

    group('Unknown dependency key', () {
      test('validate rejects dependency on unknown key', () {
        final declarations = [
          const ResourceDeclaration(
            key: 'a',
            source: 'client://cache/a',
            dependsOn: ['unknown'],
          ),
        ];

        expect(
          () => depResolver.validate(declarations),
          throwsA(isA<ArgumentError>()),
        );
      });
    });
  });

  group('a source built from a dependency', () {
    test('the dependency\'s value is substituted into the URI', () async {
      final result = await depResolver.resolve(<ResourceDeclaration>[
        const ResourceDeclaration(
          key: 'config',
          source: 'client://cache/config',
        ),
        const ResourceDeclaration(
          key: 'theme',
          source: 'client://cache/{{resources.config.themeName}}',
          dependsOn: <String>['config'],
        ),
      ]);

      expect(result.errors, isEmpty);
      expect((result.resources['theme'] as Map)['color'], 'black',
          reason: 'the second resource names the first in its own URI; that '
              'substitution is the entire reason dependencies exist');
    });

    test('a path into nothing substitutes empty rather than the expression',
        () async {
      final result = await depResolver.resolve(<ResourceDeclaration>[
        const ResourceDeclaration(
          key: 'config',
          source: 'client://cache/config',
        ),
        const ResourceDeclaration(
          key: 'theme',
          source: 'client://cache/{{resources.config.missing.deeper}}',
          dependsOn: <String>['config'],
          optional: true,
        ),
      ]);

      expect(result.resources['theme'], isNull);
      expect(result.errors, isEmpty,
          reason: 'an optional resource that cannot be built is absent, not '
              'a failure of the page');
    });

    test('a transform runs on what was loaded', () async {
      final result = await depResolver.resolve(<ResourceDeclaration>[
        const ResourceDeclaration(
          key: 'config',
          source: 'client://cache/config',
          transform: <Map<String, dynamic>>[
            <String, dynamic>{'type': 'select', 'path': 'themeName'},
          ],
        ),
      ]);

      expect(result.resources['config'], 'dark-theme',
          reason: 'the pipeline runs between the bytes and the binding; '
              'skipping it hands the page the raw server shape');
    });
  });

  group('failure propagation', () {
    test('a required dependant fails when its dependency does', () async {
      final result = await depResolver.resolve(<ResourceDeclaration>[
        const ResourceDeclaration(
          key: 'missing',
          source: 'client://cache/not-there',
        ),
        const ResourceDeclaration(
          key: 'dependant',
          source: 'client://cache/independent',
          dependsOn: <String>['missing'],
        ),
      ]);

      expect(result.errors['missing'], isNotNull);
      expect(result.errors['dependant'], contains('missing'),
          reason: 'naming which dependency failed is what turns a blank '
              'panel into something an author can fix');
    });

    test('an optional dependant resolves to null instead', () async {
      final result = await depResolver.resolve(<ResourceDeclaration>[
        const ResourceDeclaration(
          key: 'missing',
          source: 'client://cache/not-there',
        ),
        const ResourceDeclaration(
          key: 'dependant',
          source: 'client://cache/independent',
          dependsOn: <String>['missing'],
          optional: true,
        ),
      ]);

      expect(result.resources.containsKey('dependant'), isTrue);
      expect(result.resources['dependant'], isNull);
      expect(result.errors.containsKey('dependant'), isFalse);
    });

    test('a dependency that was itself optional does not fail the dependant',
        () async {
      final result = await depResolver.resolve(<ResourceDeclaration>[
        const ResourceDeclaration(
          key: 'missing',
          source: 'client://cache/not-there',
          optional: true,
        ),
        const ResourceDeclaration(
          key: 'dependant',
          source: 'client://cache/independent',
          dependsOn: <String>['missing'],
        ),
      ]);

      expect(result.errors, isEmpty,
          reason: 'an optional resource is declared as "carry on without '
              'this"; failing everything behind it says the opposite');
      expect(result.resources['dependant'], 'standalone');
    });
  });
}
