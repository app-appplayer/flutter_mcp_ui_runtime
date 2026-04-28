import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart'
    show TemplateDefinition;
import 'package:flutter_mcp_ui_runtime/src/templates/template_registry.dart';

void main() {
  late TemplateRegistry registry;
  late TemplateEngine engine;

  setUp(() {
    registry = TemplateRegistry();
    engine = TemplateEngine(registry: registry);
  });

  tearDown(() {
    registry.dispose();
  });

  group('TC-024: TemplateEngine — resolveUseDefinition', () {
    test('Normal: resolves use definition by extracting template name and delegating', () {
      registry.registerScoped(
        'card',
        {'body': {'type': 'box', 'padding': 8}},
      );

      final result = engine.resolveUseDefinition({
        'type': 'use',
        'template': 'card',
        'color': 'red',
      });

      expect(result, isNotNull);
      expect(result!['type'], equals('box'));
      // Override merged
      expect(result['color'], equals('red'));
    });

    test('Boundary: useDefinition missing template key → returns null', () {
      final result = engine.resolveUseDefinition({
        'type': 'use',
      });
      expect(result, isNull);
    });

    test('Error: template not found in registry → returns error placeholder', () {
      final result = engine.resolveUseDefinition({
        'type': 'use',
        'template': 'nonexistent',
      });
      // resolveByName returns error placeholder, not null
      expect(result, isNotNull);
      expect(result!['text'], contains('not found'));
    });
  });

  group('TC-025: TemplateEngine — resolveByName', () {
    test('Normal: resolves template by name, merging overrides', () {
      registry.registerScoped(
        'btn',
        {'body': {'type': 'button', 'label': 'Click', 'size': 'md'}},
      );

      final result = engine.resolveByName('btn', overrides: {'size': 'lg'});
      expect(result['type'], equals('button'));
      expect(result['label'], equals('Click'));
      expect(result['size'], equals('lg'));
    });

    test('Boundary: no overrides → template defaults used as-is', () {
      registry.registerScoped(
        'btn',
        {'body': {'type': 'button', 'label': 'Default'}},
      );

      final result = engine.resolveByName('btn');
      expect(result['label'], equals('Default'));
    });

    test('Error: unknown template → error placeholder returned', () {
      final result = engine.resolveByName('missing');
      expect(result['type'], equals('text'));
      expect(result['text'], contains('not found'));
    });
  });

  group('TC-026: TemplateEngine — expandAll', () {
    test('Normal: recursively expands all use references', () {
      registry.register(TemplateDefinition.fromJson({
        'name': 'badge',
        'body': {'type': 'chip', 'label': 'Badge'},
      }));

      final definition = {
        'type': 'row',
        'children': [
          {'type': 'use', 'template': 'badge'},
          {'type': 'text', 'content': 'Hello'},
        ],
      };

      final expanded = engine.expandAll(definition);
      final children = expanded['children'] as List;
      final first = children[0] as Map<String, dynamic>;
      expect(first['type'], equals('chip'));
      expect(first['label'], equals('Badge'));
    });

    test('Normal: nested templates expanded correctly', () {
      registry.register(TemplateDefinition.fromJson({
        'name': 'leaf',
        'body': {'type': 'text', 'content': 'Leaf'},
      }));
      registry.register(TemplateDefinition.fromJson({
        'name': 'branch',
        'body': {
          'type': 'box',
          'children': [
            {'type': 'use', 'template': 'leaf'},
          ],
        },
      }));

      final expanded = engine.expandAll({
        'type': 'use',
        'template': 'branch',
      });
      expect(expanded['type'], equals('box'));
      final children = expanded['children'] as List;
      final leaf = children[0] as Map<String, dynamic>;
      expect(leaf['type'], equals('text'));
      expect(leaf['content'], equals('Leaf'));
    });

    test('Boundary: maxNestingDepth reached → throws StateError', () {
      final shallow = TemplateEngine(registry: registry, maxNestingDepth: 1);

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
            {'type': 'use', 'template': 'c'},
          ],
        },
      }));
      registry.register(TemplateDefinition.fromJson({
        'name': 'c',
        'body': {'type': 'text', 'content': 'deep'},
      }));

      expect(
        () => shallow.expandAll({'type': 'use', 'template': 'a'}),
        throwsA(isA<StateError>()),
      );
    });

    test('Error: circular template reference → throws StateError', () {
      registry.register(TemplateDefinition.fromJson({
        'name': 'x',
        'body': {
          'type': 'box',
          'children': [
            {'type': 'use', 'template': 'y'},
          ],
        },
      }));
      registry.register(TemplateDefinition.fromJson({
        'name': 'y',
        'body': {
          'type': 'box',
          'children': [
            {'type': 'use', 'template': 'x'},
          ],
        },
      }));

      expect(
        () => engine.expandAll({'type': 'use', 'template': 'x'}),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('TC-027: TemplateEngine — isTemplateReference', () {
    test('Normal: node with type use → true', () {
      expect(
        engine.isTemplateReference({'type': 'use', 'template': 'card'}),
        isTrue,
      );
    });

    test('Normal: node with type template → true', () {
      expect(
        engine.isTemplateReference({'type': 'template', 'template': 'card'}),
        isTrue,
      );
    });

    test('Boundary: node with other type → false', () {
      expect(
        engine.isTemplateReference({'type': 'text', 'content': 'hello'}),
        isFalse,
      );
    });

    test('Boundary: node with type use but no template key → false', () {
      expect(
        engine.isTemplateReference({'type': 'use'}),
        isFalse,
      );
    });
  });
}
