import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart'
    show TemplateDefinition;
import 'package:flutter_mcp_ui_runtime/src/templates/template_registry.dart';

/// TC-020 and TC-021: Slot resolution tests
///
/// No standalone SlotResolver class exists in the source.
/// Slot resolution is handled by TemplateRegistry._substituteValue (private).
/// These tests exercise slot resolution through the public resolve() API.
void main() {
  late TemplateRegistry registry;

  setUp(() {
    registry = TemplateRegistry();
  });

  tearDown(() {
    registry.dispose();
  });

  group('TC-020: SlotResolver — resolveSlots (via TemplateRegistry.resolve)', () {
    test('Normal: content tree with two slot references, both provided → both replaced', () {
      registry.register(TemplateDefinition.fromJson({
        'name': 'layout',
        'body': {
          'type': 'column',
          'children': [
            {'type': 'slot', 'name': 'header'},
            {'type': 'slot', 'name': 'footer'},
          ],
        },
      }));

      final result = registry.resolve({
        'type': 'use',
        'template': 'layout',
        'slots': {
          'header': {'type': 'text', 'content': 'Header Content'},
          'footer': {'type': 'text', 'content': 'Footer Content'},
        },
      });

      expect(result, isNotNull);
      final children = result!['children'] as List;
      expect(children, hasLength(2));
      final header = children[0] as Map<String, dynamic>;
      final footer = children[1] as Map<String, dynamic>;
      expect(header['content'], equals('Header Content'));
      expect(footer['content'], equals('Footer Content'));
    });

    test('Normal: content tree with no slot references → returned unchanged', () {
      registry.register(TemplateDefinition.fromJson({
        'name': 'simple',
        'body': {
          'type': 'text',
          'content': 'No slots here',
        },
      }));

      final result = registry.resolve({
        'type': 'use',
        'template': 'simple',
      });

      expect(result, isNotNull);
      expect(result!['type'], equals('text'));
      expect(result['content'], equals('No slots here'));
    });

    test('Boundary: nested slot reference inside children array → resolved at correct depth', () {
      registry.register(TemplateDefinition.fromJson({
        'name': 'nested',
        'body': {
          'type': 'column',
          'children': [
            {
              'type': 'box',
              'children': [
                {'type': 'slot', 'name': 'deep'},
              ],
            },
          ],
        },
      }));

      final result = registry.resolve({
        'type': 'use',
        'template': 'nested',
        'slots': {
          'deep': {'type': 'text', 'content': 'Deep Content'},
        },
      });

      expect(result, isNotNull);
      final outerChildren = result!['children'] as List;
      final box = outerChildren[0] as Map<String, dynamic>;
      final innerChildren = box['children'] as List;
      final slot = innerChildren[0] as Map<String, dynamic>;
      expect(slot['content'], equals('Deep Content'));
    });
  });

  group('TC-021: SlotResolver — resolveSlot fallback chain (via resolve)', () {
    test('Normal: caller content provided → caller content returned', () {
      registry.register(TemplateDefinition.fromJson({
        'name': 'card',
        'body': {
          'type': 'box',
          'children': [
            {
              'type': 'slot',
              'name': 'content',
              'fallback': {'type': 'text', 'content': 'Fallback'},
            },
          ],
        },
      }));

      final result = registry.resolve({
        'type': 'use',
        'template': 'card',
        'slots': {
          'content': {'type': 'text', 'content': 'Caller Content'},
        },
      });

      final children = result!['children'] as List;
      final content = children[0] as Map<String, dynamic>;
      expect(content['content'], equals('Caller Content'));
    });

    test('Normal: no caller content, default defined → default returned', () {
      registry.register(TemplateDefinition.fromJson({
        'name': 'card',
        'body': {
          'type': 'box',
          'children': [
            {
              'type': 'slot',
              'name': 'content',
              'fallback': {'type': 'text', 'content': 'Fallback'},
            },
          ],
        },
      }));

      final result = registry.resolve({
        'type': 'use',
        'template': 'card',
      });

      final children = result!['children'] as List;
      final content = children[0] as Map<String, dynamic>;
      expect(content['type'], equals('text'));
      expect(content['content'], equals('Fallback'));
    });

    test('Normal: no caller content, no default, not required → slot node returned as-is', () {
      registry.register(TemplateDefinition.fromJson({
        'name': 'card',
        'body': {
          'type': 'box',
          'children': [
            {'type': 'slot', 'name': 'optional'},
          ],
        },
      }));

      final result = registry.resolve({
        'type': 'use',
        'template': 'card',
      });

      final children = result!['children'] as List;
      final slot = children[0] as Map<String, dynamic>;
      // Slot remains as slot node since no content and no fallback
      expect(slot['type'], equals('slot'));
      expect(slot['name'], equals('optional'));
    });
  });
}
