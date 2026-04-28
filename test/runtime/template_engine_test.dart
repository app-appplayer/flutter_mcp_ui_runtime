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

  group('TC-073: TemplateEngine — constructor', () {
    test('Normal: created with required TemplateRegistry', () {
      expect(engine, isNotNull);
      expect(engine, isA<TemplateEngine>());
    });

    test('Boundary: registry with no templates', () {
      final emptyEngine = TemplateEngine(registry: TemplateRegistry());
      expect(emptyEngine, isNotNull);
    });
  });

  group('TC-074: TemplateEngine — resolve', () {
    test('Normal: resolve template name → returns template definition map', () {
      registry.registerScoped(
        'greeting',
        {'body': {'type': 'text', 'content': 'Hello World'}},
      );

      final result = engine.resolveByName('greeting');
      expect(result['type'], equals('text'));
      expect(result['content'], equals('Hello World'));
    });

    test('Normal: with overrides → template properties overridden (merged)', () {
      registry.registerScoped(
        'card',
        {
          'body': {
            'type': 'box',
            'padding': 16,
            'color': 'blue',
          },
        },
      );

      final result = engine.resolveByName('card', overrides: {'color': 'red'});
      expect(result['color'], equals('red'));
      expect(result['padding'], equals(16));
    });

    test('Boundary: unknown template name → error placeholder', () {
      final result = engine.resolveByName('unknown');
      expect(result['type'], equals('text'));
      expect(result['text'], contains('not found'));
    });
  });

  group('TC-075: TemplateEngine — isTemplateReference and expandAll', () {
    test('Normal: detect template reference → true', () {
      final ref = {'type': 'use', 'template': 'myCard'};
      expect(engine.isTemplateReference(ref), isTrue);
    });

    test('Normal: non-reference → false', () {
      final def = {'type': 'text', 'content': 'hello'};
      expect(engine.isTemplateReference(def), isFalse);
    });

    test('Normal: expandAll recursively expands template references', () {
      registry.register(TemplateDefinition.fromJson({
        'name': 'innerCard',
        'body': {'type': 'box', 'children': [
          {'type': 'text', 'content': 'Inside card'},
        ]},
      }));

      final definition = {
        'type': 'linear',
        'children': [
          {'type': 'use', 'template': 'innerCard'},
          {'type': 'text', 'content': 'After card'},
        ],
      };

      final expanded = engine.expandAll(definition);

      expect(expanded['type'], equals('linear'));
      final children = expanded['children'] as List;
      expect(children, hasLength(2));
      // First child should be expanded from template
      final firstChild = children[0] as Map<String, dynamic>;
      expect(firstChild['type'], equals('box'));
    });

    test('Boundary: no template references → definition unchanged', () {
      final definition = {
        'type': 'text',
        'content': 'Hello',
      };

      final expanded = engine.expandAll(definition);
      expect(expanded['type'], equals('text'));
      expect(expanded['content'], equals('Hello'));
    });
  });
}
