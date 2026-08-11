// `checkCondition` and `format` on the render context — the two places a
// document's own words decide what a user sees, and both were half covered.
//
// A wrong condition does not throw: it shows the wrong branch. A wrong
// formatter does not throw either: it prints a number the reader believes.
// Both belong in the same file as everything else this week — failures that
// look like finished screens.

import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late RenderContext context;

  RenderContext contextWith(Map<String, dynamic> state) {
    final stateManager = StateManager()..initialize(Map.of(state));
    final engine = BindingEngine();
    final actionHandler = ActionHandler();
    return RenderContext(
      renderer: Renderer(
        widgetRegistry: WidgetRegistry(),
        bindingEngine: engine,
        actionHandler: actionHandler,
        stateManager: stateManager,
      ),
      stateManager: stateManager,
      actionHandler: actionHandler,
      themeManager: ThemeManager(),
      bindingEngine: engine,
      buildContext: null,
    );
  }

  setUp(() {
    context = contextWith({
      'count': 5,
      'name': 'Ada Lovelace',
      'role': 'admin',
      'tags': ['alpha', 'beta'],
      'profile': {'city': 'London'},
      'flag': true,
      'off': false,
      'blank': '',
      'nothing': null,
    });
  });

  group('a condition written as a value', () {
    test('null and a bare boolean', () {
      expect(context.checkCondition(null), isTrue,
          reason: 'no condition means always — a widget with no `visible` shows');
      expect(context.checkCondition(true), isTrue);
      expect(context.checkCondition(false), isFalse);
    });

    test('a binding that resolves to a boolean', () {
      expect(context.checkCondition('{{flag}}'), isTrue);
      expect(context.checkCondition('{{off}}'), isFalse);
    });

    test('a binding that resolves to a string', () {
      expect(context.checkCondition('{{name}}'), isTrue);
      expect(context.checkCondition('{{blank}}'), isFalse,
          reason: 'an empty string is the "nothing to show" case');
      expect(context.checkCondition('{{role}}'), isTrue);
    });

    test('the string "false" is false, whatever its case', () {
      final ctx = contextWith({'a': 'false', 'b': 'FALSE', 'c': 'False'});
      expect(ctx.checkCondition('{{a}}'), isFalse);
      expect(ctx.checkCondition('{{b}}'), isFalse);
      expect(ctx.checkCondition('{{c}}'), isFalse,
          reason: 'a form field or query string carries "false" as text, and a '
              'document that reads it must not show the true branch');
    });

    test('a missing path is false, not an error', () {
      expect(context.checkCondition('{{nothing}}'), isFalse);
      expect(context.checkCondition('{{absent}}'), isFalse);
    });
  });

  group('a condition written as an object', () {
    bool check(Map<String, dynamic> condition) =>
        context.checkCondition(condition);

    test('equality, both spellings', () {
      expect(check({'operator': '==', 'left': '{{count}}', 'right': 5}), isTrue);
      expect(check({'operator': 'equals', 'left': '{{role}}', 'right': 'admin'}),
          isTrue);
      expect(check({'operator': '!=', 'left': '{{count}}', 'right': 5}), isFalse);
      expect(
          check({'operator': 'notEquals', 'left': '{{role}}', 'right': 'guest'}),
          isTrue);
    });

    test('the four numeric comparisons, both spellings', () {
      expect(check({'operator': '>', 'left': '{{count}}', 'right': 3}), isTrue);
      expect(check({'operator': 'greaterThan', 'left': '{{count}}', 'right': 9}),
          isFalse);
      expect(check({'operator': '>=', 'left': '{{count}}', 'right': 5}), isTrue);
      expect(
          check({
            'operator': 'greaterThanOrEquals',
            'left': '{{count}}',
            'right': 6
          }),
          isFalse);
      expect(check({'operator': '<', 'left': '{{count}}', 'right': 9}), isTrue);
      expect(check({'operator': 'lessThan', 'left': '{{count}}', 'right': 2}),
          isFalse);
      expect(check({'operator': '<=', 'left': '{{count}}', 'right': 5}), isTrue);
      expect(
          check({
            'operator': 'lessThanOrEquals',
            'left': '{{count}}',
            'right': 4
          }),
          isFalse);
    });

    test('a numeric comparison against a numeric string still compares', () {
      final ctx = contextWith({'n': '7'});
      expect(
        ctx.checkCondition({'operator': '>', 'left': '{{n}}', 'right': 3}),
        isTrue,
        reason: 'a value that came from a text field is still a number to the '
            'person reading the screen',
      );
    });

    test('contains reads strings, lists and maps', () {
      expect(
          check({'operator': 'contains', 'left': '{{name}}', 'right': 'Ada'}),
          isTrue);
      expect(
          check({'operator': 'contains', 'left': '{{tags}}', 'right': 'beta'}),
          isTrue);
      expect(
          check({'operator': 'contains', 'left': '{{tags}}', 'right': 'gamma'}),
          isFalse);
      expect(
          check({'operator': 'contains', 'left': '{{profile}}', 'right': 'city'}),
          isTrue,
          reason: 'on a map it asks about keys');
      expect(check({'operator': 'contains', 'left': '{{count}}', 'right': 5}),
          isFalse,
          reason: 'a number contains nothing — false, not a crash');
    });

    test('startsWith, endsWith and matches', () {
      expect(
          check({'operator': 'startsWith', 'left': '{{name}}', 'right': 'Ada'}),
          isTrue);
      expect(
          check({
            'operator': 'endsWith',
            'left': '{{name}}',
            'right': 'Lovelace'
          }),
          isTrue);
      expect(
          check({'operator': 'matches', 'left': '{{name}}', 'right': r'^Ada\b'}),
          isTrue);
      expect(
        check({'operator': 'matches', 'left': '{{name}}', 'right': '([unclosed'}),
        isFalse,
        reason: 'a pattern that will not compile answers false rather than '
            'taking the page down with it',
      );
    });

    test('and / or over a list of conditions', () {
      expect(
        check({
          'operator': 'and',
          'conditions': [
            {'operator': '>', 'left': '{{count}}', 'right': 1},
            {'operator': 'equals', 'left': '{{role}}', 'right': 'admin'},
          ],
        }),
        isTrue,
      );
      expect(
        check({
          'operator': '&&',
          'conditions': [
            {'operator': '>', 'left': '{{count}}', 'right': 1},
            {'operator': 'equals', 'left': '{{role}}', 'right': 'guest'},
          ],
        }),
        isFalse,
      );
      expect(
        check({
          'operator': 'or',
          'conditions': [
            {'operator': 'equals', 'left': '{{role}}', 'right': 'guest'},
            {'operator': '>', 'left': '{{count}}', 'right': 1},
          ],
        }),
        isTrue,
      );
      expect(
        check({
          'operator': '||',
          'conditions': [
            {'operator': 'equals', 'left': '{{role}}', 'right': 'guest'},
            {'operator': '<', 'left': '{{count}}', 'right': 1},
          ],
        }),
        isFalse,
      );
    });

    test('and / or over left and right when no list is given', () {
      expect(
          check({'operator': 'and', 'left': '{{flag}}', 'right': '{{role}}'}),
          isTrue);
      expect(check({'operator': 'and', 'left': '{{flag}}', 'right': '{{off}}'}),
          isFalse);
      expect(check({'operator': 'or', 'left': '{{off}}', 'right': '{{flag}}'}),
          isTrue);
    });

    test('not, both spellings and both shapes', () {
      expect(check({'operator': 'not', 'left': '{{off}}'}), isTrue);
      expect(check({'operator': '!', 'left': '{{flag}}'}), isFalse);
      expect(check({'operator': 'not', 'condition': '{{off}}'}), isTrue,
          reason: 'the `condition` key is the spelling a document reads more '
              'naturally, and it has to work too');
    });

    test('an operator nobody implemented shows the widget', () {
      // Chosen deliberately: hiding content because a runtime did not know an
      // operator would make a newer document lose parts of itself silently on
      // an older host.
      expect(check({'operator': 'teleports', 'left': 1, 'right': 2}), isTrue);
    });
  });

  group('format', () {
    test('the string formatters', () {
      expect(context.format('hello world', 'uppercase'), 'HELLO WORLD');
      expect(context.format('HELLO', 'lowercase'), 'hello');
      expect(context.format('hELLO', 'capitalize'), 'Hello');
      expect(context.format('  padded  ', 'trim'), 'padded');
      expect(context.format('', 'capitalize'), '',
          reason: 'an empty string has no first letter to raise');
    });

    test('currency and percent', () {
      expect(context.format(12.5, 'currency'), r'$12.50');
      expect(context.format(0.256, 'percent'), '25.6%');
    });

    test('date, time and datetime', () {
      final moment = DateTime(2026, 8, 8, 9, 5);
      expect(context.format(moment, 'date'), '2026-08-08');
      expect(context.format(moment, 'time'), '09:05');
      expect(context.format(moment, 'datetime'), contains('2026-08-08'));
      expect(context.format(moment, 'datetime'), contains('09:05'));
    });

    test('a formatter applied to the wrong type falls back to the plain value',
        () {
      // Not an exception and not a made-up number: `currency` on a string
      // shows the string, so the mistake is visible without breaking the page.
      expect(context.format('not a number', 'currency'), 'not a number');
      expect(context.format('not a date', 'date'), 'not a date');
      expect(context.format(5, 'unknownFormatter'), '5');
      expect(context.format(5, null), '5');
    });
  });

  group('list-scope paths', () {
    test('an indexed path reads the item the iteration is on', () {
      final scoped = context.createChildContext(variables: {'index': 1});
      expect(scoped.getValue('tags[index]'), 'beta');
    });

    test('and a property inside that item', () {
      final ctx = contextWith({
        'rows': [
          {'user': {'name': 'Ada'}},
          {'user': {'name': 'Bob'}},
        ],
      });
      final scoped = ctx.createChildContext(variables: {'index': 1});
      expect(scoped.getValue('rows[index].user.name'), 'Bob');
    });

    test('an index past the end is null rather than a range error', () {
      final scoped = context.createChildContext(variables: {'index': 9});
      expect(scoped.getValue('tags[index]'), isNull);
    });
  });
}
