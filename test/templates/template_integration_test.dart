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

  group('TC-030: Full template rendering pipeline', () {
    test('Normal: register → resolve via use → correct widget tree with params and slots', () {
      // Register a card template with params and a slot
      registry.register(TemplateDefinition.fromJson({
        'name': 'card',
        'params': {
          'title': {'type': 'string', 'required': true},
          'subtitle': {'type': 'string', 'required': false},
        },
        'defaults': {'subtitle': 'Default subtitle'},
        'body': {
          'type': 'column',
          'children': [
            {'type': 'text', 'content': '{{title}}'},
            {'type': 'text', 'content': '{{subtitle}}'},
            {'type': 'slot', 'name': 'actions'},
          ],
        },
      }));

      // Resolve via use definition
      final result = registry.resolve({
        'type': 'use',
        'template': 'card',
        'params': {'title': 'My Card'},
        'slots': {
          'actions': {'type': 'button', 'label': 'OK'},
        },
      });

      expect(result, isNotNull);
      expect(result!['type'], equals('column'));

      final children = result['children'] as List;
      expect(children, hasLength(3));

      // Parameter substitution applied
      final titleWidget = children[0] as Map<String, dynamic>;
      expect(titleWidget['content'], equals('My Card'));

      // Default parameter applied
      final subtitleWidget = children[1] as Map<String, dynamic>;
      expect(subtitleWidget['content'], equals('Default subtitle'));

      // Slot filled with caller content
      final actionsWidget = children[2] as Map<String, dynamic>;
      expect(actionsWidget['type'], equals('button'));
      expect(actionsWidget['label'], equals('OK'));
    });

    test('Normal: nested template expansion via engine', () {
      // Register inner and outer templates
      registry.register(TemplateDefinition.fromJson({
        'name': 'badge',
        'params': {
          'label': {'type': 'string', 'required': true},
        },
        'body': {'type': 'chip', 'text': '{{label}}'},
      }));

      registry.register(TemplateDefinition.fromJson({
        'name': 'card',
        'params': {
          'title': {'type': 'string', 'required': true},
        },
        'body': {
          'type': 'column',
          'children': [
            {'type': 'text', 'content': '{{title}}'},
            {
              'type': 'use',
              'template': 'badge',
              'params': {'label': 'New'},
            },
          ],
        },
      }));

      // Full pipeline via engine expandAll
      final result = engine.expandAll({
        'type': 'use',
        'template': 'card',
        'params': {'title': 'Featured'},
      });

      expect(result['type'], equals('column'));
      final children = result['children'] as List;
      expect(children, hasLength(2));

      // Nested template resolved
      final badge = children[1] as Map<String, dynamic>;
      expect(badge['type'], equals('chip'));
      expect(badge['text'], equals('New'));
    });
  });

  group('TC-031: Template with conditional slot rendering', () {
    test('Normal: showFooter true → footer slot rendered', () {
      registry.register(TemplateDefinition.fromJson({
        'name': 'page',
        'params': {
          'showFooter': {'type': 'boolean', 'required': false},
        },
        'defaults': {'showFooter': true},
        'body': {
          'type': 'column',
          'children': [
            {'type': 'text', 'content': 'Body'},
            {'type': 'slot', 'name': 'footer'},
          ],
        },
      }));

      final result = registry.resolve({
        'type': 'use',
        'template': 'page',
        'params': {'showFooter': true},
        'slots': {
          'footer': {'type': 'text', 'content': 'Footer Content'},
        },
      });

      expect(result, isNotNull);
      final children = result!['children'] as List;
      final footer = children[1] as Map<String, dynamic>;
      expect(footer['type'], equals('text'));
      expect(footer['content'], equals('Footer Content'));
    });

    test('Normal: showFooter false → footer slot uses fallback (empty)', () {
      registry.register(TemplateDefinition.fromJson({
        'name': 'page',
        'params': {
          'showFooter': {'type': 'boolean', 'required': false},
        },
        'defaults': {'showFooter': false},
        'body': {
          'type': 'column',
          'children': [
            {'type': 'text', 'content': 'Body'},
            {
              'type': 'slot',
              'name': 'footer',
              'fallback': {'type': 'sizedBox', 'width': 0, 'height': 0},
            },
          ],
        },
      }));

      // No slot provided → fallback used
      final result = registry.resolve({
        'type': 'use',
        'template': 'page',
        'params': {'showFooter': false},
      });

      expect(result, isNotNull);
      final children = result!['children'] as List;
      final footer = children[1] as Map<String, dynamic>;
      expect(footer['type'], equals('sizedBox'));
    });
  });

  group('TC-032: Multiple template instances on same page', () {
    test('Normal: two card instances with different params → both render correctly', () {
      registry.register(TemplateDefinition.fromJson({
        'name': 'card',
        'params': {
          'title': {'type': 'string', 'required': true},
          'color': {'type': 'string', 'required': false},
        },
        'defaults': {'color': 'blue'},
        'body': {
          'type': 'box',
          'color': '{{color}}',
          'children': [
            {'type': 'text', 'content': '{{title}}'},
          ],
        },
      }));

      final card1 = registry.resolve({
        'type': 'use',
        'template': 'card',
        'params': {'title': 'Card One', 'color': 'red'},
      });

      final card2 = registry.resolve({
        'type': 'use',
        'template': 'card',
        'params': {'title': 'Card Two', 'color': 'green'},
      });

      expect(card1, isNotNull);
      expect(card2, isNotNull);

      // Each card has its own parameter values
      expect(card1!['color'], equals('red'));
      expect(card2!['color'], equals('green'));

      final children1 = card1['children'] as List;
      final children2 = card2['children'] as List;
      expect(
        (children1[0] as Map<String, dynamic>)['content'],
        equals('Card One'),
      );
      expect(
        (children2[0] as Map<String, dynamic>)['content'],
        equals('Card Two'),
      );
    });

    test('Normal: style changes in one instance do not affect the other', () {
      // Register with scoped styles via extended definition
      registry.registerExtended(ExtendedTemplateDefinition.fromJson({
        'name': 'styledCard',
        'body': {
          'type': 'box',
          'style': {'padding': 8},
          'children': [
            {'type': 'text', 'content': '{{title}}'},
          ],
        },
        'params': {
          'title': {'type': 'string', 'required': true},
        },
        'scopedStyles': true,
      }));

      final card1 = registry.resolveExtended({
        'type': 'use',
        'template': 'styledCard',
        'params': {'title': 'First'},
      });

      final card2 = registry.resolveExtended({
        'type': 'use',
        'template': 'styledCard',
        'params': {'title': 'Second'},
      });

      expect(card1, isNotNull);
      expect(card2, isNotNull);

      // Both have independent scoped style markers
      expect(card1!['_scopedStyles'], isTrue);
      expect(card2!['_scopedStyles'], isTrue);

      // Modifying one result does not affect the other
      card1['style'] = {'padding': 16};
      final card2Style = card2['style'] as Map<String, dynamic>;
      expect(card2Style['padding'], equals(8));
    });
  });
}
