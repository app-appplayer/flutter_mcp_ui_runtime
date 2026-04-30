import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/templates/template_registry.dart';

void main() {
  group('ExtendedTemplateDefinition — fromJson and validateParams', () {
    test('Normal: fromJson parses params, slots, defaults', () {
      final ext = ExtendedTemplateDefinition.fromJson({
        'name': 'card',
        'content': {'type': 'box'},
        'params': {
          'title': {'type': 'string', 'required': true},
          'variant': {'type': 'string', 'default': 'outlined'},
        },
        'slots': [
          {'name': 'header', 'required': false},
          {'name': 'body', 'required': true},
        ],
        'scopedStyles': true,
      });

      expect(ext.name, equals('card'));
      expect(ext.paramDefinitions, hasLength(2));
      expect(ext.slotDefinitions, hasLength(2));
      expect(ext.scopedStyles, isTrue);
      expect(ext.defaults['variant'], equals('outlined'));
    });

    test('Normal: validateParams with valid params → empty errors', () {
      final ext = ExtendedTemplateDefinition.fromJson({
        'name': 'card',
        'content': {'type': 'box'},
        'params': {
          'title': {'type': 'string', 'required': true},
        },
      });

      final errors = ext.validateParams({'title': 'Hello'});
      expect(errors, isEmpty);
    });

    test('Error: validateParams with missing required → error list', () {
      final ext = ExtendedTemplateDefinition.fromJson({
        'name': 'card',
        'content': {'type': 'box'},
        'params': {
          'title': {'type': 'string', 'required': true},
        },
      });

      final errors = ext.validateParams(<String, dynamic>{});
      expect(errors, isNotEmpty);
      expect(errors.first, contains('title'));
    });

    test('Normal: validateSlots with required slot provided → empty', () {
      final ext = ExtendedTemplateDefinition.fromJson({
        'name': 'card',
        'content': {'type': 'box'},
        'slots': [
          {'name': 'content', 'required': true},
        ],
      });

      final errors = ext.validateSlots({
        'content': {'type': 'text', 'content': 'hello'},
      });
      expect(errors, isEmpty);
    });

    test('Error: validateSlots with required slot missing → error', () {
      final ext = ExtendedTemplateDefinition.fromJson({
        'name': 'card',
        'content': {'type': 'box'},
        'slots': [
          {'name': 'content', 'required': true},
        ],
      });

      final errors = ext.validateSlots(<String, dynamic>{});
      expect(errors, isNotEmpty);
      expect(errors.first, contains('content'));
    });
  });

  group('TC-016: resolve — required slot not filled (via ExtendedTemplateDefinition)', () {
    test('Error: required slot with no default and no caller content → error', () {
      final ext = ExtendedTemplateDefinition.fromJson({
        'name': 'card',
        'content': {'type': 'box'},
        'slots': [
          {'name': 'main', 'required': true},
        ],
      });

      final errors = ext.validateSlots(<String, dynamic>{});
      expect(errors, isNotEmpty);
    });

    test('Normal: required slot with fallback and no caller content → no error', () {
      final ext = ExtendedTemplateDefinition.fromJson({
        'name': 'card',
        'content': {'type': 'box'},
        'slots': [
          {
            'name': 'main',
            'required': true,
            'fallback': {'type': 'text', 'content': 'default'},
          },
        ],
      });

      final errors = ext.validateSlots(<String, dynamic>{});
      expect(errors, isEmpty);
    });
  });

  group('ContentSlotDefinition', () {
    test('Normal: fromJson parses correctly', () {
      final slot = ContentSlotDefinition.fromJson({
        'name': 'header',
        'required': true,
        'fallback': {'type': 'text', 'content': 'default'},
      });
      expect(slot.name, equals('header'));
      expect(slot.required, isTrue);
      expect(slot.fallback, isNotNull);
    });

    test('Normal: toJson round-trip', () {
      final slot = ContentSlotDefinition.fromJson({
        'name': 'footer',
        'required': false,
      });
      final json = slot.toJson();
      expect(json['name'], equals('footer'));
      expect(json['type'], equals('slot'));
    });
  });
}
