import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart'
    show TemplateDefinition;
import 'package:flutter_mcp_ui_runtime/src/templates/template_registry.dart';

void main() {
  late TemplateRegistry registry;

  setUp(() {
    registry = TemplateRegistry();
  });

  tearDown(() {
    registry.dispose();
  });

  TemplateDefinition _makeDef(String name, {Map<String, dynamic>? body}) {
    return TemplateDefinition.fromJson({
      'name': name,
      'body': body ?? {'type': 'text', 'content': name},
    });
  }

  group('TC-005: TemplateRegistry — constructor', () {
    test('Normal: constructor creates empty registry', () {
      final r = TemplateRegistry();
      expect(r.templateNames, isEmpty);
      r.dispose();
    });
  });

  group('TC-006: TemplateRegistry — register and hasTemplate', () {
    test('Normal: register template → hasTemplate returns true', () {
      registry.register(_makeDef('card'));
      expect(registry.hasTemplate('card'), isTrue);
    });

    test('Normal: hasTemplate for unknown → false', () {
      expect(registry.hasTemplate('unknown'), isFalse);
    });

    test('Boundary: register same name twice → overwrites previous', () {
      registry.register(_makeDef('card', body: {'type': 'text', 'content': 'v1'}));
      registry.register(_makeDef('card', body: {'type': 'text', 'content': 'v2'}));

      expect(registry.hasTemplate('card'), isTrue);
      final resolved = registry.getTemplate('card');
      expect(resolved!['content'], equals('v2'));
    });
  });

  group('TC-007: TemplateRegistry — registerAll', () {
    test('Normal: registerAll registers multiple templates', () {
      registry.registerAll([_makeDef('a'), _makeDef('b')]);
      expect(registry.hasTemplate('a'), isTrue);
      expect(registry.hasTemplate('b'), isTrue);
    });

    test('Boundary: registerAll with empty list → no-op', () {
      registry.registerAll([]);
      expect(registry.templateNames, isEmpty);
    });
  });

  group('TC-008: TemplateRegistry — unregister and clear', () {
    test('Normal: unregister removes template', () {
      registry.register(_makeDef('card'));
      registry.unregister('card');
      expect(registry.hasTemplate('card'), isFalse);
    });

    test('Normal: clear removes all templates', () {
      registry.register(_makeDef('a'));
      registry.register(_makeDef('b'));
      registry.clear();
      expect(registry.templateNames, isEmpty);
      expect(registry.hasTemplate('a'), isFalse);
      expect(registry.hasTemplate('b'), isFalse);
    });

    test('Boundary: unregister unknown name → no-op', () {
      registry.register(_makeDef('card'));
      registry.unregister('unknown');
      expect(registry.hasTemplate('card'), isTrue);
    });
  });

  group('TC-010: resolve — template not found', () {
    test('Error: resolve nonexistent template → null', () {
      final result = registry.resolve({
        'type': 'use',
        'template': 'nonexistent',
      });
      expect(result, isNull);
    });
  });

  group('TC-011: resolve — parameter validation success', () {
    test('Normal: all required params supplied → expanded result', () {
      final template = TemplateDefinition.fromJson({
        'name': 'greeting',
        'params': {
          'name': {'type': 'string', 'required': true},
        },
        'body': {'type': 'text', 'content': 'Hello {{name}}'},
      });
      registry.register(template);

      final result = registry.resolve({
        'type': 'use',
        'template': 'greeting',
        'params': {'name': 'World'},
      });
      expect(result, isNotNull);
      expect(result!['content'], equals('Hello World'));
    });

    test('Normal: optional params omitted → defaults applied', () {
      final template = TemplateDefinition.fromJson({
        'name': 'card',
        'params': {
          'title': {'type': 'string', 'required': false},
        },
        'defaults': {'title': 'Default Title'},
        'body': {'type': 'text', 'content': '{{title}}'},
      });
      registry.register(template);

      final result = registry.resolve({
        'type': 'use',
        'template': 'card',
      });
      expect(result, isNotNull);
      expect(result!['content'], equals('Default Title'));
    });
  });

  group('TC-012: resolve — required parameter missing', () {
    test('Error: required param not provided → null (validation failure)', () {
      final template = TemplateDefinition.fromJson({
        'name': 'greeting',
        'params': {
          'name': {'type': 'string', 'required': true},
        },
        'body': {'type': 'text', 'content': 'Hello {{name}}'},
      });
      registry.register(template);

      final result = registry.resolve({
        'type': 'use',
        'template': 'greeting',
        'params': <String, dynamic>{},
      });
      expect(result, isNull);
    });
  });

  group('TC-013: resolve — parameter type mismatch', () {
    test('Error: string param given number → null (validation failure)', () {
      final template = TemplateDefinition.fromJson({
        'name': 'greeting',
        'params': {
          'name': {'type': 'string', 'required': true},
        },
        'body': {'type': 'text', 'content': 'Hello {{name}}'},
      });
      registry.register(template);

      final result = registry.resolve({
        'type': 'use',
        'template': 'greeting',
        'params': {'name': 42},
      });
      expect(result, isNull);
    });
  });

  group('TC-015: resolve — slot resolution with caller content', () {
    test('Normal: caller provides slot content → slot filled', () {
      final template = TemplateDefinition.fromJson({
        'name': 'card',
        'body': {
          'type': 'box',
          'children': [
            {'type': 'slot', 'name': 'header'},
          ],
        },
      });
      registry.register(template);

      final result = registry.resolve({
        'type': 'use',
        'template': 'card',
        'slots': {
          'header': {'type': 'text', 'content': 'My Header'},
        },
      });
      expect(result, isNotNull);
      final children = result!['children'] as List;
      expect(children, hasLength(1));
      final header = children[0] as Map<String, dynamic>;
      expect(header['type'], equals('text'));
      expect(header['content'], equals('My Header'));
    });

    test('Normal: slot with fallback, no caller content → fallback used', () {
      final template = TemplateDefinition.fromJson({
        'name': 'card',
        'body': {
          'type': 'box',
          'children': [
            {
              'type': 'slot',
              'name': 'footer',
              'fallback': {'type': 'text', 'content': 'Default Footer'},
            },
          ],
        },
      });
      registry.register(template);

      final result = registry.resolve({
        'type': 'use',
        'template': 'card',
      });
      expect(result, isNotNull);
      final children = result!['children'] as List;
      final footer = children[0] as Map<String, dynamic>;
      expect(footer['type'], equals('text'));
      expect(footer['content'], equals('Default Footer'));
    });
  });

  group('TC-018: resolve — nested template expansion (via TemplateEngine)', () {
    test('Normal: template content with use reference → resolved by engine', () {
      registry.register(TemplateDefinition.fromJson({
        'name': 'inner',
        'body': {'type': 'text', 'content': 'inner content'},
      }));
      registry.register(TemplateDefinition.fromJson({
        'name': 'outer',
        'body': {
          'type': 'box',
          'children': [
            {'type': 'use', 'template': 'inner'},
          ],
        },
      }));

      final engine = TemplateEngine(registry: registry);
      final result = engine.expandAll({
        'type': 'use',
        'template': 'outer',
      });
      expect(result['type'], equals('box'));
      final children = result['children'] as List;
      final inner = children[0] as Map<String, dynamic>;
      expect(inner['type'], equals('text'));
      expect(inner['content'], equals('inner content'));
    });
  });

  group('TC-019: resolve — nesting depth exceeded', () {
    test('Error: circular template reference → throws StateError', () {
      // A references B, B references A
      registry.register(TemplateDefinition.fromJson({
        'name': 'a',
        'body': {
          'type': 'box',
          'children': [
            {'type': 'use', 'template': 'b'},
          ],
        },
      }));
      registry.register(TemplateDefinition.fromJson({
        'name': 'b',
        'body': {
          'type': 'box',
          'children': [
            {'type': 'use', 'template': 'a'},
          ],
        },
      }));

      final engine = TemplateEngine(registry: registry);
      expect(
        () => engine.expandAll({'type': 'use', 'template': 'a'}),
        throwsA(isA<StateError>()),
      );
    });

    test('Error: nesting exceeds maxNestingDepth → throws StateError', () {
      final engine = TemplateEngine(registry: registry, maxNestingDepth: 2);

      // Create 4-level chain: t1 -> t2 -> t3 -> t4
      for (var i = 1; i <= 3; i++) {
        registry.register(TemplateDefinition.fromJson({
          'name': 't$i',
          'body': {
            'type': 'box',
            'children': [
              {'type': 'use', 'template': 't${i + 1}'},
            ],
          },
        }));
      }
      registry.register(TemplateDefinition.fromJson({
        'name': 't4',
        'body': {'type': 'text', 'content': 'leaf'},
      }));

      expect(
        () => engine.expandAll({'type': 'use', 'template': 't1'}),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('TC-028: TemplateRegistry — registerFromJson', () {
    test('Normal: registers templates from JSON list', () {
      registry.registerFromJson([
        {
          'name': 'card',
          'body': {'type': 'box', 'children': []},
        },
        {
          'name': 'button',
          'body': {'type': 'button', 'label': 'Click'},
        },
      ]);
      expect(registry.hasTemplate('card'), isTrue);
      expect(registry.hasTemplate('button'), isTrue);
    });

    test('Boundary: empty list → no templates registered', () {
      registry.registerFromJson([]);
      expect(registry.templateNames, isEmpty);
    });
  });

  group('TC-009: TemplateRegistry — getCacheStatistics', () {
    test('Boundary: no templates resolved → zeroed counts', () {
      final stats = registry.getCacheStatistics();
      expect(stats['instanceCacheSize'], equals(0));
      expect(stats['instanceCacheHits'], equals(0));
      expect(stats['instanceCacheMisses'], equals(0));
      expect(stats['definitionCacheHits'], equals(0));
      expect(stats['definitionCacheMisses'], equals(0));
    });

    test('Normal: after resolving templates → statistics reflect cache state', () {
      final template = TemplateDefinition.fromJson({
        'name': 'greeting',
        'params': {
          'name': {'type': 'string', 'required': true},
        },
        'body': {'type': 'text', 'content': 'Hello {{name}}'},
      });
      registry.register(template);

      // First resolve → cache miss
      registry.resolve({
        'type': 'use',
        'template': 'greeting',
        'params': {'name': 'World'},
      });

      var stats = registry.getCacheStatistics();
      expect(stats['instanceCacheSize'], equals(1));
      expect(stats['instanceCacheMisses'], equals(1));
      expect(stats['instanceCacheHits'], equals(0));

      // Second resolve with same params → cache hit
      registry.resolve({
        'type': 'use',
        'template': 'greeting',
        'params': {'name': 'World'},
      });

      stats = registry.getCacheStatistics();
      expect(stats['instanceCacheHits'], equals(1));
      expect(stats['instanceCacheMisses'], equals(1));
    });
  });

  group('TC-014: resolve — enum constraint violation', () {
    test('Error: value not in enum list → resolveExtended returns null', () {
      registry.registerExtended(ExtendedTemplateDefinition.fromJson({
        'name': 'card',
        'body': {'type': 'box', 'variant': '{{variant}}'},
        'params': {
          'variant': {
            'type': 'string',
            'required': true,
            'enum': ['outlined', 'filled', 'elevated'],
          },
        },
      }));

      final result = registry.resolveExtended({
        'type': 'use',
        'template': 'card',
        'params': {'variant': 'unknown'},
      });
      expect(result, isNull);
    });

    test('Normal: value in enum list → resolveExtended succeeds', () {
      registry.registerExtended(ExtendedTemplateDefinition.fromJson({
        'name': 'card',
        'body': {'type': 'box', 'variant': '{{variant}}'},
        'params': {
          'variant': {
            'type': 'string',
            'required': true,
            'enum': ['outlined', 'filled', 'elevated'],
          },
        },
      }));

      final result = registry.resolveExtended({
        'type': 'use',
        'template': 'card',
        'params': {'variant': 'filled'},
      });
      expect(result, isNotNull);
      expect(result!['variant'], equals('filled'));
    });
  });

  group('TC-017: resolve — scoped style isolation', () {
    test('Normal: resolveExtended with scopedStyles → adds scope markers', () {
      registry.registerExtended(ExtendedTemplateDefinition.fromJson({
        'name': 'styledCard',
        'body': {'type': 'box', 'style': {'padding': 8}},
        'scopedStyles': true,
      }));

      final result1 = registry.resolveExtended({
        'type': 'use',
        'template': 'styledCard',
      });
      final result2 = registry.resolveExtended({
        'type': 'use',
        'template': 'styledCard',
      });

      // Both instances should have scoped style markers
      expect(result1, isNotNull);
      expect(result1!['_scopedStyles'], isTrue);
      expect(result1['_templateName'], equals('styledCard'));
      expect(result2, isNotNull);
      expect(result2!['_scopedStyles'], isTrue);
    });

    test('Normal: non-scoped template → no scope markers', () {
      registry.registerExtended(ExtendedTemplateDefinition.fromJson({
        'name': 'plain',
        'body': {'type': 'box'},
        'scopedStyles': false,
      }));

      final result = registry.resolveExtended({
        'type': 'use',
        'template': 'plain',
      });
      expect(result, isNotNull);
      expect(result!.containsKey('_scopedStyles'), isFalse);
    });
  });

  group('TC-022: Parsed definition caching', () {
    test('Normal: same template resolved twice → definition parsed once', () {
      final template = TemplateDefinition.fromJson({
        'name': 'cached',
        'body': {'type': 'text', 'content': 'cached content'},
      });
      registry.register(template);

      // Resolve twice
      registry.resolve({
        'type': 'use',
        'template': 'cached',
        'params': <String, dynamic>{},
      });
      registry.resolve({
        'type': 'use',
        'template': 'cached',
        'params': <String, dynamic>{},
      });

      final stats = registry.getCacheStatistics();
      // Second call should be a cache hit
      expect(stats['instanceCacheHits'], greaterThanOrEqualTo(1));
    });

    test('Normal: unregister → cache entry removed', () {
      final template = TemplateDefinition.fromJson({
        'name': 'removable',
        'body': {'type': 'text', 'content': 'temp'},
      });
      registry.register(template);

      registry.resolve({
        'type': 'use',
        'template': 'removable',
        'params': <String, dynamic>{},
      });

      registry.unregister('removable');

      // Template should no longer be available
      expect(registry.hasTemplate('removable'), isFalse);

      // Attempting to resolve should return null
      final result = registry.resolve({
        'type': 'use',
        'template': 'removable',
        'params': <String, dynamic>{},
      });
      expect(result, isNull);
    });
  });

  group('TC-023: Parameterized instance caching', () {
    test('Normal: same template + same params → cache hit', () {
      final template = TemplateDefinition.fromJson({
        'name': 'greeting',
        'params': {
          'name': {'type': 'string', 'required': true},
        },
        'body': {'type': 'text', 'content': 'Hello {{name}}'},
      });
      registry.register(template);

      registry.resolve({
        'type': 'use',
        'template': 'greeting',
        'params': {'name': 'Alice'},
      });
      registry.resolve({
        'type': 'use',
        'template': 'greeting',
        'params': {'name': 'Alice'},
      });

      final stats = registry.getCacheStatistics();
      expect(stats['instanceCacheHits'], equals(1));
      expect(stats['instanceCacheMisses'], equals(1));
    });

    test('Normal: same template + different params → cache miss', () {
      final template = TemplateDefinition.fromJson({
        'name': 'greeting',
        'params': {
          'name': {'type': 'string', 'required': true},
        },
        'body': {'type': 'text', 'content': 'Hello {{name}}'},
      });
      registry.register(template);

      registry.resolve({
        'type': 'use',
        'template': 'greeting',
        'params': {'name': 'Alice'},
      });
      registry.resolve({
        'type': 'use',
        'template': 'greeting',
        'params': {'name': 'Bob'},
      });

      final stats = registry.getCacheStatistics();
      expect(stats['instanceCacheHits'], equals(0));
      expect(stats['instanceCacheMisses'], equals(2));
      expect(stats['instanceCacheSize'], equals(2));
    });

    test('Boundary: slots excluded from cache key — different slots with same params → cache hit', () {
      final template = TemplateDefinition.fromJson({
        'name': 'card',
        'body': {
          'type': 'box',
          'children': [
            {'type': 'slot', 'name': 'header'},
          ],
        },
      });
      registry.register(template);

      registry.resolve({
        'type': 'use',
        'template': 'card',
        'params': <String, dynamic>{},
        'slots': {
          'header': {'type': 'text', 'content': 'Header A'},
        },
      });
      registry.resolve({
        'type': 'use',
        'template': 'card',
        'params': <String, dynamic>{},
        'slots': {
          'header': {'type': 'text', 'content': 'Header B'},
        },
      });

      final stats = registry.getCacheStatistics();
      // Slots are excluded from cache key, so same params → cache hit
      expect(stats['instanceCacheHits'], equals(1));
    });
  });

  group('TC-029: TemplateRegistry — registerBuiltIns', () {
    test('Normal: registerBuiltIns does not throw', () {
      expect(() => registry.registerBuiltIns(), returnsNormally);
    });

    test('Boundary: called twice → no error', () {
      registry.registerBuiltIns();
      expect(() => registry.registerBuiltIns(), returnsNormally);
    });
  });
}
