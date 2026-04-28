import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/templates/template_registry.dart';

void main() {
  group('TC-001: TemplateParamDefinition — type validation', () {
    test('Normal: type string with string value → null (valid)', () {
      final param = TemplateParamDefinition(
        name: 'title',
        type: TemplateParamType.string,
      );
      expect(param.validate('hello'), isNull);
    });

    test('Normal: type integer with int value → null (valid)', () {
      final param = TemplateParamDefinition(
        name: 'count',
        type: TemplateParamType.integer,
      );
      expect(param.validate(42), isNull);
    });

    test('Normal: type number with num value → null (valid)', () {
      final param = TemplateParamDefinition(
        name: 'price',
        type: TemplateParamType.number,
      );
      expect(param.validate(3.14), isNull);
      expect(param.validate(42), isNull);
    });

    test('Normal: type boolean with bool value → null (valid)', () {
      final param = TemplateParamDefinition(
        name: 'active',
        type: TemplateParamType.boolean,
      );
      expect(param.validate(true), isNull);
      expect(param.validate(false), isNull);
    });

    test('Normal: type map with Map value → null (valid)', () {
      final param = TemplateParamDefinition(
        name: 'config',
        type: TemplateParamType.map,
      );
      expect(param.validate({'key': 'value'}), isNull);
    });

    test('Normal: type list with List value → null (valid)', () {
      final param = TemplateParamDefinition(
        name: 'items',
        type: TemplateParamType.list,
      );
      expect(param.validate([1, 2, 3]), isNull);
    });

    test('Error: type string with int value → error message', () {
      final param = TemplateParamDefinition(
        name: 'title',
        type: TemplateParamType.string,
      );
      final result = param.validate(42);
      expect(result, isNotNull);
      expect(result, contains('title'));
      expect(result, contains('string'));
    });

    test('Error: type number with string value → error message', () {
      final param = TemplateParamDefinition(
        name: 'price',
        type: TemplateParamType.number,
      );
      final result = param.validate('not a number');
      expect(result, isNotNull);
      expect(result, contains('price'));
      expect(result, contains('number'));
    });
  });

  group('TC-002: TemplateParamDefinition — required validation', () {
    test('Normal: required true with value supplied → null (valid)', () {
      final param = TemplateParamDefinition(
        name: 'title',
        type: TemplateParamType.string,
        required: true,
      );
      expect(param.validate('hello'), isNull);
    });

    test('Normal: required false with no value → null (valid)', () {
      final param = TemplateParamDefinition(
        name: 'subtitle',
        type: TemplateParamType.string,
        required: false,
        defaultValue: 'default text',
      );
      expect(param.validate(null), isNull);
    });

    test('Error: required true with no value → error message', () {
      final param = TemplateParamDefinition(
        name: 'title',
        type: TemplateParamType.string,
        required: true,
      );
      final result = param.validate(null);
      expect(result, isNotNull);
      expect(result, contains('required'));
      expect(result, contains('title'));
    });
  });

  group('TC-003: TemplateParamDefinition — default values', () {
    test('Normal: parameter with default, no value → default used', () {
      final param = TemplateParamDefinition(
        name: 'variant',
        type: TemplateParamType.string,
        defaultValue: 'outlined',
      );
      // validate(null) should pass because defaultValue exists
      expect(param.validate(null), isNull);
      expect(param.defaultValue, equals('outlined'));
    });

    test('Normal: parameter with default true, value false → false used (explicit overrides)', () {
      final param = TemplateParamDefinition(
        name: 'enabled',
        type: TemplateParamType.boolean,
        defaultValue: true,
      );
      // Explicit value false should validate successfully
      expect(param.validate(false), isNull);
    });

    test('Boundary: default null → null used when not supplied', () {
      final param = TemplateParamDefinition(
        name: 'optional',
        type: TemplateParamType.string,
        required: false,
        defaultValue: null,
      );
      expect(param.validate(null), isNull);
    });
  });

  group('TC-004: TemplateParamDefinition — enum constraints', () {
    test('Normal: enum [a, b, c] with value b → null (valid)', () {
      final param = TemplateParamDefinition(
        name: 'size',
        type: TemplateParamType.string,
        enumValues: ['a', 'b', 'c'],
      );
      expect(param.validate('b'), isNull);
    });

    test('Error: enum [a, b, c] with value d → error message listing allowed values', () {
      final param = TemplateParamDefinition(
        name: 'size',
        type: TemplateParamType.string,
        enumValues: ['a', 'b', 'c'],
      );
      final result = param.validate('d');
      expect(result, isNotNull);
      expect(result, contains('size'));
      expect(result, contains('a'));
      expect(result, contains('b'));
      expect(result, contains('c'));
    });

    test('Boundary: enum null (no constraint) → any value of correct type accepted', () {
      final param = TemplateParamDefinition(
        name: 'label',
        type: TemplateParamType.string,
        enumValues: null,
      );
      expect(param.validate('anything'), isNull);
    });
  });

  group('TemplateParamDefinition — fromJson', () {
    test('Normal: fromJson parses all fields correctly', () {
      final param = TemplateParamDefinition.fromJson('color', {
        'type': 'string',
        'required': true,
        'default': 'blue',
        'enum': ['red', 'green', 'blue'],
      });
      expect(param.name, equals('color'));
      expect(param.type, equals(TemplateParamType.string));
      expect(param.required, isTrue);
      expect(param.defaultValue, equals('blue'));
      expect(param.enumValues, equals(['red', 'green', 'blue']));
    });

    test('Normal: fromJson with type aliases (boolean, array, object)', () {
      expect(
        TemplateParamDefinition.fromJson('a', {'type': 'boolean'}).type,
        equals(TemplateParamType.boolean),
      );
      expect(
        TemplateParamDefinition.fromJson('b', {'type': 'array'}).type,
        equals(TemplateParamType.list),
      );
      expect(
        TemplateParamDefinition.fromJson('c', {'type': 'object'}).type,
        equals(TemplateParamType.map),
      );
    });
  });
}
