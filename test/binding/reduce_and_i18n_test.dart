// The remaining reduce shapes, and the binding families a document reads
// without calling a function: `i18n.*`, `theme.*`, and the arithmetic /
// comparison paths. Each returns a value a screen prints directly, so a wrong
// answer here is a wrong number in front of a user with nothing logged.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';

void main() {
  late StateManager state;
  late BindingEngine binding;
  late RenderContext context;

  setUp(() {
    state = StateManager();
    state.initialize(<String, dynamic>{
      'nums': <dynamic>[1, 2, 3],
      'mixed': <dynamic>[1, 'two', 3],
      'lines': <dynamic>[
        <String, dynamic>{'qty': 2, 'price': 5},
        <String, dynamic>{'qty': 1, 'price': 20},
        <String, dynamic>{'name': 'no numbers here'},
      ],
      'a': 7,
      'b': 3,
      'flag': true,
      'name': 'cherry',
      'nothing': null,
    });
    binding = BindingEngine();
    context = RenderContext(
      renderer: Renderer(
        widgetRegistry: WidgetRegistry(),
        bindingEngine: binding,
        actionHandler: ActionHandler(),
        stateManager: state,
      ),
      stateManager: state,
      bindingEngine: binding,
      actionHandler: ActionHandler(),
      themeManager: ThemeManager.instance,
    );
  });

  dynamic resolve(String expr) => binding.resolve<dynamic>(expr, context);

  group('reduce shapes', () {
    test('a bare list of numbers sums', () {
      expect(resolve('{{reduce(nums, n => n)}}'), 6);
    });

    test('non-numeric members are skipped, not fatal', () {
      expect(resolve('{{reduce(mixed, n => n)}}'), 4,
          reason: 'one bad row must not take the whole total down');
    });

    test('reduce by property sums that column', () {
      expect(resolve('{{reduce(lines, "price")}}'), 25);
    });

    test('rows missing the property contribute nothing', () {
      expect(resolve('{{reduce(lines, "qty")}}'), 3);
    });
  });

  group('arithmetic and comparison', () {
    test('the four operations resolve', () {
      expect(resolve('{{a + b}}'), 10);
      expect(resolve('{{a - b}}'), 4);
      expect(resolve('{{a * b}}'), 21);
      expect(resolve('{{a / b}}'), closeTo(2.333, 0.01));
    });

    test('comparisons resolve to booleans', () {
      expect(resolve('{{a > b}}'), isTrue);
      expect(resolve('{{a == 7}}'), isTrue);
      expect(resolve('{{a != 7}}'), isFalse);
      expect(resolve('{{a <= b}}'), isFalse);
    });

    test('logical operators short-circuit sensibly', () {
      expect(resolve('{{flag && a > b}}'), isTrue);
      expect(resolve('{{!flag}}'), isFalse);
      expect(resolve('{{flag || nothing}}'), isTrue);
    });

    test('a ternary picks a branch', () {
      expect(resolve('{{a > b ? "high" : "low"}}'), 'high');
    });
  });

  group('missing values', () {
    test('an unknown path is null rather than the literal text', () {
      expect(resolve('{{no.such.path}}'), isNull,
          reason: 'printing the expression back is how `{{user.name}}` ends '
              'up on screen verbatim');
    });

    test('arithmetic on a null operand does not throw', () {
      expect(() => resolve('{{nothing + 1}}'), returnsNormally);
    });

    test('mixed literal text keeps the surrounding characters', () {
      expect(binding.resolveText('Hi {{name}}!', context), 'Hi cherry!');
      expect(binding.resolveText('no bindings', context), 'no bindings');
    });
  });

  group('dependency extraction', () {
    test('names every path an expression reads', () {
      final deps = binding.extractDependencies('{{a}} + {{b}}');
      expect(deps, containsAll(<String>['a', 'b']));
    });

    test('a literal expression depends on nothing', () {
      expect(binding.extractDependencies('plain text'), isEmpty);
    });
  });
}
