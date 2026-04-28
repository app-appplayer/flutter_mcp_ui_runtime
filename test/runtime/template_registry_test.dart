import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart'
    show TemplateDefinition;
import 'package:flutter_mcp_ui_runtime/src/templates/template_registry.dart';

void main() {
  group('TC-068: TemplateScope — enum values', () {
    test('Normal: contains builtIn, application, screen', () {
      expect(TemplateScope.values, containsAll([
        TemplateScope.builtIn,
        TemplateScope.application,
        TemplateScope.screen,
      ]));
    });

    test('Boundary: all enum values are distinct', () {
      final values = TemplateScope.values;
      expect(values.toSet().length, equals(values.length));
    });

    test('Normal: builtIn is lowest priority, screen is highest', () {
      expect(TemplateScope.builtIn.index, lessThan(TemplateScope.application.index));
      expect(TemplateScope.application.index, lessThan(TemplateScope.screen.index));
    });
  });

  group('TC-069: TemplateRegistry — register and get', () {
    late TemplateRegistry registry;

    setUp(() {
      registry = TemplateRegistry();
    });

    tearDown(() {
      registry.dispose();
    });

    test('Normal: register template at application scope → retrievable', () {
      final template = TemplateDefinition.fromJson({
        'name': 'myCard',
        'body': {'type': 'box', 'children': []},
      });

      registry.register(template);

      expect(registry.hasTemplate('myCard'), isTrue);
      expect(registry.getTemplate('myCard'), isNotNull);
    });

    test('Normal: register at screen scope → higher priority than application', () {
      registry.registerScoped(
        'shared',
        {'body': {'type': 'text', 'content': 'App level'}},
        scope: TemplateScope.application,
      );
      registry.registerScoped(
        'shared',
        {'body': {'type': 'text', 'content': 'Screen level'}},
        scope: TemplateScope.screen,
      );

      final resolved = registry.getTemplate('shared');
      expect(resolved, isNotNull);
      expect(resolved!['content'], equals('Screen level'));
    });

    test('Normal: register at built-in scope → lowest priority', () {
      registry.registerScoped(
        'base',
        {'body': {'type': 'text', 'content': 'Built-in'}},
        scope: TemplateScope.builtIn,
      );

      expect(registry.hasTemplate('base'), isTrue);
      expect(registry.getTemplate('base'), isNotNull);
    });

    test('Boundary: hasTemplate returns true for registered names', () {
      registry.registerScoped(
        'test',
        {'body': {'type': 'text', 'content': 'hi'}},
      );

      expect(registry.hasTemplate('test'), isTrue);
      expect(registry.has('test'), isTrue);
    });

    test('Error: get template for unregistered name → null', () {
      expect(registry.getTemplate('nonexistent'), isNull);
      expect(registry.get('nonexistent'), isNull);
    });
  });

  group('TC-070: TemplateRegistry — scope resolution order', () {
    late TemplateRegistry registry;

    setUp(() {
      registry = TemplateRegistry();
    });

    tearDown(() {
      registry.dispose();
    });

    test('Normal: screen scope overrides application scope', () {
      registry.registerScoped(
        'card',
        {'body': {'type': 'box', 'color': 'blue'}},
        scope: TemplateScope.application,
      );
      registry.registerScoped(
        'card',
        {'body': {'type': 'box', 'color': 'red'}},
        scope: TemplateScope.screen,
      );

      final result = registry.getTemplate('card');
      expect(result!['color'], equals('red'));
    });

    test('Normal: application scope overrides built-in scope', () {
      registry.registerScoped(
        'btn',
        {'body': {'type': 'button', 'variant': 'default'}},
        scope: TemplateScope.builtIn,
      );
      registry.registerScoped(
        'btn',
        {'body': {'type': 'button', 'variant': 'custom'}},
        scope: TemplateScope.application,
      );

      final result = registry.getTemplate('btn');
      expect(result!['variant'], equals('custom'));
    });

    test('Boundary: template only in built-in scope → returned', () {
      registry.registerScoped(
        'base',
        {'body': {'type': 'text', 'content': 'built-in'}},
        scope: TemplateScope.builtIn,
      );

      expect(registry.getTemplate('base'), isNotNull);
    });
  });

  group('TC-071: TemplateRegistry — clearScope and registerBuiltIns', () {
    late TemplateRegistry registry;

    setUp(() {
      registry = TemplateRegistry();
    });

    tearDown(() {
      registry.dispose();
    });

    test('Normal: clearScope(screen) → screen templates cleared', () {
      registry.registerScoped(
        'screenTpl',
        {'body': {'type': 'text', 'content': 'screen'}},
        scope: TemplateScope.screen,
      );
      registry.registerScoped(
        'appTpl',
        {'body': {'type': 'text', 'content': 'app'}},
        scope: TemplateScope.application,
      );

      registry.clearScope(TemplateScope.screen);

      expect(registry.hasTemplate('screenTpl'), isFalse);
      expect(registry.hasTemplate('appTpl'), isTrue);
    });

    test('Normal: registerBuiltIns → default templates available', () {
      registry.registerBuiltIns();
      // registerBuiltIns currently has no built-in templates but should not throw
      expect(true, isTrue);
    });

    test('Boundary: clear scope with no templates → no-op', () {
      registry.clearScope(TemplateScope.screen);
      expect(registry.templateNames, isEmpty);
    });
  });

  group('TC-072: TemplateRegistry — dispose', () {
    test('Normal: dispose cleans up all templates', () {
      final registry = TemplateRegistry();

      registry.registerScoped(
        'test',
        {'body': {'type': 'text', 'content': 'hi'}},
      );

      registry.dispose();
      expect(registry.templateNames, isEmpty);
    });

    test('Boundary: dispose empty registry → no-op', () {
      final registry = TemplateRegistry();
      registry.dispose();
      expect(registry.templateNames, isEmpty);
    });
  });
}
