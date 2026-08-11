// Extended templates — the typed-parameter form of `use`.
//
// A template is a contract between the author who wrote it and every document
// that uses it, and the enforcement of that contract — required parameters,
// enums, slot validation, fallbacks — was the uncovered part. A registry that
// stops validating expands the wrong tree instead of naming the mistake, and
// what arrives on screen is a widget with a missing label rather than an error
// anyone can act on.

import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart'
    show TemplateDefinition;
import 'package:flutter_mcp_ui_runtime/src/templates/template_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TemplateRegistry registry;

  setUp(() => registry = TemplateRegistry());

  Map<String, dynamic> cardTemplate({
    Map<String, dynamic>? params,
    List<Map<String, dynamic>>? slots,
    Map<String, dynamic>? defaults,
    bool scopedStyles = false,
  }) =>
      {
        'name': 'card',
        'content': {
          'type': 'column',
          'children': [
            {'type': 'text', 'content': '{{title}}'},
            {'type': 'slot', 'name': 'body'},
          ],
        },
        if (params != null) 'params': params,
        if (slots != null) 'slots': slots,
        if (defaults != null) 'defaults': defaults,
        if (scopedStyles) 'scopedStyles': true,
      };

  group('registering', () {
    test('a template registered from json can be read back', () {
      registry.registerExtendedFromJson(cardTemplate(params: {
        'title': {'type': 'string', 'required': true},
      }));

      final template = registry.getExtended('card')!;
      expect(template.name, 'card');
      expect(template.paramDefinitions['title']!.required, isTrue);
    });

    test('an unregistered name reads back as null', () {
      expect(registry.getExtended('nothing'), isNull);
    });

    test('it round-trips through json', () {
      registry.registerExtendedFromJson(cardTemplate(
        params: {
          'title': {'type': 'string', 'required': true},
          'variant': {
            'type': 'string',
            'default': 'plain',
            'enum': ['plain', 'raised'],
          },
        },
        slots: [
          {'name': 'body', 'required': false},
        ],
        defaults: {'title': 'Untitled'},
        scopedStyles: true,
      ));

      final json = registry.getExtended('card')!.toJson();

      expect(json['name'], 'card');
      expect((json['params']! as Map)['title'], isNotNull);
      expect((json['slots']! as List), hasLength(1));
      expect(json['scopedStyles'], isTrue);
      expect((json['defaults']! as Map)['title'], 'Untitled',
          reason: 'a registry a host cannot serialise cannot be forwarded to '
              'another runtime, which is what the json form is for');
    });
  });

  group('parameters', () {
    setUp(() {
      registry.registerExtendedFromJson(cardTemplate(params: {
        'title': {'type': 'string', 'required': true},
        'variant': {
          'type': 'string',
          'default': 'plain',
          'enum': ['plain', 'raised'],
        },
        'count': {'type': 'number'},
        'visible': {'type': 'boolean'},
        'anything': {'type': 'any'},
      }));
    });

    test('a declared parameter is substituted into the body', () {
      final expanded =
          registry.resolveExtended({'template': 'card', 'params': {'title': 'Ada'}})!;

      final children = (expanded['children']! as List).cast<Map>();
      expect(children.first['content'], 'Ada');
    });

    test('a default fills in for a parameter nobody passed', () {
      registry.registerExtendedFromJson({
        'name': 'labelled',
        'content': {'type': 'text', 'content': '{{variant}}'},
        'params': {
          'variant': {'type': 'string', 'default': 'plain'},
        },
      });

      final expanded = registry.resolveExtended({'template': 'labelled'})!;
      expect(expanded['content'], 'plain');
    });

    test('a missing required parameter is refused, not expanded', () {
      expect(registry.resolveExtended({'template': 'card'}), isNull,
          reason: 'expanding without it puts an unresolved binding on screen, '
              'which reads as a bug in the template rather than in the call');
    });

    test('a value outside the declared enum is refused', () {
      expect(
        registry.resolveExtended({
          'template': 'card',
          'params': {'title': 'Ada', 'variant': 'neon'},
        }),
        isNull,
      );
    });

    test('a value of the wrong type is refused', () {
      expect(
        registry.resolveExtended({
          'template': 'card',
          'params': {'title': 'Ada', 'count': 'many'},
        }),
        isNull,
      );
    });

    test('a boolean parameter is checked too', () {
      expect(
        registry.resolveExtended({
          'template': 'card',
          'params': {'title': 'Ada', 'visible': 'yes'},
        }),
        isNull,
      );
    });

    test('an `any` parameter accepts whatever it is given', () {
      final expanded = registry.resolveExtended({
        'template': 'card',
        'params': {
          'title': 'Ada',
          'anything': [1, 'two', true],
        },
      });

      expect(expanded, isNotNull,
          reason: '`any` is how a template takes a payload it only forwards');
    });

    test('a binding passes validation whatever its declared type', () {
      final expanded = registry.resolveExtended({
        'template': 'card',
        'params': {'title': 'Ada', 'count': '{{rows.length}}'},
      });

      expect(expanded, isNotNull,
          reason: 'the value is not known until render; refusing it here '
              'would make every bound parameter unusable');
    });
  });

  group('slots', () {
    setUp(() {
      registry.registerExtendedFromJson(cardTemplate(
        params: {
          'title': {'type': 'string', 'required': true},
        },
        slots: [
          {
            'name': 'body',
            'required': false,
            'fallback': {'type': 'text', 'content': 'nothing here'},
          },
          {'name': 'footer', 'required': true},
        ],
      ));
    });

    test('a provided slot is substituted', () {
      final expanded = registry.resolveExtended({
        'template': 'card',
        'params': {'title': 'Ada'},
        'slots': {
          'body': {'type': 'text', 'content': 'the body'},
          'footer': {'type': 'text', 'content': 'the footer'},
        },
      })!;

      final children = (expanded['children']! as List).cast<Map>();
      expect(children[1]['content'], 'the body');
    });

    test('an unprovided slot falls back to its declared content', () {
      final expanded = registry.resolveExtended({
        'template': 'card',
        'params': {'title': 'Ada'},
        'slots': {
          'footer': {'type': 'text', 'content': 'the footer'},
        },
      })!;

      final children = (expanded['children']! as List).cast<Map>();
      expect(children[1]['content'], 'nothing here',
          reason: 'a fallback that is declared and never used leaves a hole '
              'in the layout where the template promised content');
    });

    test('a missing required slot is refused', () {
      expect(
        registry.resolveExtended({
          'template': 'card',
          'params': {'title': 'Ada'},
        }),
        isNull,
      );
    });
  });

  group('the instance cache', () {
    setUp(() {
      registry.registerExtendedFromJson(cardTemplate(params: {
        'title': {'type': 'string', 'required': true},
      }));
    });

    test('the same parameters expand once and are cloned after', () {
      final first = registry
          .resolveExtended({'template': 'card', 'params': {'title': 'Ada'}})!;
      final second = registry
          .resolveExtended({'template': 'card', 'params': {'title': 'Ada'}})!;

      expect(second, equals(first));
      expect(identical(first, second), isFalse,
          reason: 'handing out the same map twice lets one instance\'s '
              'mutation reach the other');
    });

    test('different parameters expand separately', () {
      final ada = registry
          .resolveExtended({'template': 'card', 'params': {'title': 'Ada'}})!;
      final bob = registry
          .resolveExtended({'template': 'card', 'params': {'title': 'Bob'}})!;

      expect((ada['children']! as List).first, isNot((bob['children']! as List).first));
    });
  });

  group('what cannot be resolved', () {
    test('a use with no template name is refused', () {
      expect(registry.resolveExtended(<String, dynamic>{}), isNull);
      expect(registry.resolve(<String, dynamic>{}), isNull);
    });

    test('an unknown template falls through to the standard registry', () {
      registry.register(TemplateDefinition(
        name: 'plain',
        content: {'type': 'text', 'content': '{{label}}'},
        defaults: {'label': 'from the standard registry'},
      ));

      final expanded = registry.resolveExtended({'template': 'plain'})!;
      expect(expanded['content'], 'from the standard registry',
          reason: 'the two registries are one vocabulary to a document; a '
              'template declared the simple way must still resolve through '
              'the extended path');
    });

    test('a name in neither registry is refused', () {
      expect(registry.resolveExtended({'template': 'nothing'}), isNull);
    });
  });

  group('scoped styles', () {
    test('a scoped template marks its expansion', () {
      registry.registerExtendedFromJson(cardTemplate(
        params: {
          'title': {'type': 'string', 'required': true},
        },
        slots: [
          {'name': 'body', 'required': false},
        ],
        scopedStyles: true,
      ));

      final expanded = registry
          .resolveExtended({'template': 'card', 'params': {'title': 'Ada'}})!;

      expect(expanded['_scopedStyles'], isTrue);
      expect(expanded['_templateName'], 'card',
          reason: 'the marker is what lets a style apply to one template\'s '
              'expansion and not to every widget of the same type');
    });
  });
}
