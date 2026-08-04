// The remaining list-function shapes and the sandbox guards around them.
//
// These are the forms a document reaches for when it derives one collection
// from another, plus the caps that stop a runaway expression from taking the
// frame with it. Both fail quietly: a shorthand that is not recognised returns
// the input, and a cap that never triggers is only visible as a hang.

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
      'nums': <dynamic>[3, 1, 2],
      'rows': <dynamic>[
        <String, dynamic>{'name': 'a', 'status': 'active', 'qty': 2},
        <String, dynamic>{'name': 'b', 'status': 'done', 'qty': 5},
        <String, dynamic>{'name': 'c', 'status': 'active', 'qty': 9},
      ],
      'empty': <dynamic>[],
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

  group('method-call forms on a list', () {
    test('filter with a property/value pair selects matching rows', () {
      final result =
          resolve('{{filter(rows, "status", "active")}}') as List;
      expect(result.map((e) => e['name']), <String>['a', 'c']);
    });

    test('filter with a lambda selects the same rows', () {
      final result = resolve('{{rows.filter(r => r.qty > 4)}}') as List;
      expect(result.map((e) => e['name']), <String>['b', 'c']);
    });

    test('map extracts a property from each row', () {
      expect(resolve('{{rows.map("name")}}'), <dynamic>['a', 'b', 'c']);
    });

    test('an empty list stays empty through every form', () {
      expect(resolve('{{empty.filter(x => true)}}'), isEmpty);
      expect(resolve('{{empty.map("name")}}'), isEmpty);
    });
  });

  group('reduce', () {
    test('sums the lambda result from an explicit initial value', () {
      expect(resolve('{{reduce(nums, n => n, 10)}}'), 16);
    });

    test('defaults the accumulator to zero', () {
      expect(resolve('{{reduce(nums, n => n)}}'), 6);
    });

    test('non-numeric mappings are skipped rather than throwing', () {
      expect(resolve('{{reduce(rows, r => r.name, 0)}}'), 0,
          reason: 'a reduce over strings has nothing to add; throwing would '
              'take the frame down for a document that merely asked oddly');
    });
  });

  group('§3.6.1 Core built-ins — all sixteen are required', () {
    test('string functions', () {
      state.set('s', ' Hello World ');
      expect(resolve('{{toUpperCase("ab")}}'), 'AB');
      expect(resolve('{{toLowerCase("AB")}}'), 'ab');
      expect(resolve('{{trim(s)}}'), 'Hello World');
      expect(resolve('{{contains("hello", "ell")}}'), isTrue);
      expect(resolve('{{replace("a-b-c", "-", "+")}}'), 'a+b+c');
      expect(resolve('{{split("a,b", ",")}}'), <dynamic>['a', 'b']);
      expect(resolve('{{join(nums, "-")}}'), '3-1-2');
    });

    test('numeric functions', () {
      expect(resolve('{{round(2.567, 2)}}'), 2.57);
      expect(resolve('{{floor(2.9)}}'), 2);
      expect(resolve('{{ceil(2.1)}}'), 3);
      expect(resolve('{{max(1, 9, 4)}}'), 9);
      expect(resolve('{{min(1, 9, 4)}}'), 1);
    });

    test('length reads a string and an array', () {
      expect(resolve('{{length(nums)}}'), 3);
      expect(resolve('{{length("abcd")}}'), 4);
    });

    test('format is the polymorphic formatter the table names', () {
      expect(resolve('{{format(1234.5, "#,##0.00")}}'), contains('1,234.5'));
    });

    test('filter and reduce compose, as §3.6.1 shows them', () {
      expect(resolve('{{length(filter(rows, r => r.status == "active"))}}'), 2);
    });
  });

  group('guards', () {
    test('a very large list is capped rather than iterated forever', () {
      state.set('big', List<int>.generate(50000, (i) => i));
      final result = resolve('{{map(big, n => n)}}') as List;
      expect(result.length, lessThanOrEqualTo(50000));
      expect(result, isNotEmpty,
          reason: 'the cap exists to bound work, not to return nothing');
    });

    test('an unknown function resolves to null rather than throwing', () {
      expect(resolve('{{levitate(nums)}}'), isNull);
    });

    test('a malformed expression does not take the caller down', () {
      expect(() => resolve('{{filter(}}'), returnsNormally);
    });
  });
}
