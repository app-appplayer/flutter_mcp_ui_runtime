// The expression parser's literals, unary operators, parentheses and
// method-on-call chains.
//
// These are the forms an author writes without thinking about them: a
// negation, a boolean, a parenthesised sum, `list.where(…).length`. A form
// the parser mishandles produces a number with the wrong sign or a condition
// that is inverted — both of which render perfectly.

import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StateManager stateManager;
  late BindingEngine engine;
  late RenderContext context;

  setUp(() {
    stateManager = StateManager()..initialize(<String, dynamic>{});
    engine = BindingEngine();
    final actionHandler = ActionHandler();
    context = RenderContext(
      renderer: Renderer(
        widgetRegistry: WidgetRegistry(),
        bindingEngine: engine,
        actionHandler: actionHandler,
        stateManager: stateManager,
      ),
      stateManager: stateManager,
      bindingEngine: engine,
      actionHandler: actionHandler,
      themeManager: ThemeManager.instance,
    );
  });

  dynamic evaluate(String expression) =>
      engine.resolve<dynamic>('{{$expression}}', context);

  group('literals', () {
    test('booleans and null are values, not paths', () {
      expect(evaluate('true'), isTrue);
      expect(evaluate('false'), isFalse);
      expect(evaluate('null'), isNull,
          reason: 'reading these as state paths would answer null for `true` '
              'as well, and every condition written that way would be false');
    });

    test('numbers and strings are read as themselves', () {
      expect(evaluate('42'), 42);
      expect(evaluate('4.5'), 4.5);
      expect(evaluate("'hello'"), 'hello');
      expect(evaluate('"hello"'), 'hello');
    });
  });

  group('unary operators', () {
    test('a negation inverts what it wraps', () {
      stateManager.set('ready', true);

      expect(evaluate('!ready'), isFalse);
      expect(evaluate('!!ready'), isTrue);
    });

    test('a negative literal is a number, not a subtraction', () {
      expect(evaluate('-5'), -5);
      expect(evaluate('+5'), 5);
    });

    test('a unary sign in front of a path is arithmetic against zero', () {
      stateManager.set('balance', 30);

      expect(evaluate('-balance'), -30,
          reason: 'a debit shown as a credit is the kind of sign error that '
              'reads as correct until someone adds it up');
      expect(evaluate('+balance'), 30);
    });

    test('a unary sign in front of a parenthesised sum', () {
      stateManager.set('a', 2);
      stateManager.set('b', 3);

      expect(evaluate('-(a + b)'), -5);
    });
  });

  group('parentheses', () {
    test('a wrapping pair is stripped, and an inner one is not', () {
      stateManager.set('a', 2);
      stateManager.set('b', 3);
      stateManager.set('c', 4);

      expect(evaluate('(a + b)'), 5);
      expect(evaluate('(a + b) * c'), 20,
          reason: 'stripping the pair here would leave `a + b) * c`, which is '
              'not the expression the author wrote');
      expect(evaluate('a + (b * c)'), 14);
      expect(evaluate('((a + b))'), 5);
    });
  });

  group('a method on the result of a call', () {
    test('the receiver may itself be an expression', () {
      stateManager.set('rows', <dynamic>[
        <String, dynamic>{'done': true},
        <String, dynamic>{'done': false},
        <String, dynamic>{'done': true},
      ]);

      expect(evaluate("rows.where('done').length"), 2,
          reason: 'this is the shape a document writes for a count of '
              'matching rows; a parser that only accepts a path as the '
              'receiver rejects it');
    });

    test('a property tail on a call also resolves', () {
      stateManager.set('rows', <dynamic>[3, 1, 2]);

      expect(evaluate('rows.length'), 3);
    });
  });

  group('the ternary', () {
    test('picks a branch, and nests', () {
      stateManager.set('count', 0);

      expect(evaluate("count > 0 ? 'some' : 'none'"), 'none');

      stateManager.set('count', 5);
      expect(evaluate("count > 0 ? 'some' : 'none'"), 'some');
      expect(evaluate("count > 10 ? 'many' : count > 3 ? 'some' : 'none'"),
          'some',
          reason: 'a nested ternary has to find its own colon; taking the '
              'first one would split the expression in the wrong place');
    });
    test('a ternary nested in the TRUE branch keeps its own colon', () {
      stateManager.set('count', 5);
      stateManager.set('urgent', true);

      expect(
        evaluate("count > 0 ? urgent ? 'now' : 'later' : 'none'"),
        'now',
        reason: 'the scan has to count the inner `?` and skip the colon that '
            'closes it; stopping at the first colon splits the expression '
            'between the inner branches and the whole label comes out wrong',
      );

      stateManager.set('urgent', false);
      expect(evaluate("count > 0 ? urgent ? 'now' : 'later' : 'none'"),
          'later');

      stateManager.set('count', 0);
      expect(evaluate("count > 0 ? urgent ? 'now' : 'later' : 'none'"),
          'none');
    });
  });

  // Arguments are parsed by their own reader, so a literal in an argument
  // position is a different code path from the same literal standing alone.
  // A boolean read as a property NAME filters on a column that does not
  // exist and answers an empty list — which reads as "no rows match".
  group('literals in an argument position', () {
    setUp(() {
      stateManager.set('rows', <dynamic>[
        <String, dynamic>{'name': 'Ada', 'done': true, 'note': null},
        <String, dynamic>{'name': 'Bob', 'done': false, 'note': 'later'},
      ]);
    });

    List<dynamic> names(String expression) =>
        (evaluate(expression) as List<dynamic>)
            .map((row) => (row as Map)['name'])
            .toList();

    test('a boolean argument compares as a boolean', () {
      expect(names("filter(rows, 'done', true)"), <dynamic>['Ada']);
      expect(names("filter(rows, 'done', false)"), <dynamic>['Bob']);
    });

    test('a null argument matches the rows that hold nothing', () {
      expect(names("filter(rows, 'note', null)"), <dynamic>['Ada'],
          reason: 'reading `null` as a path would compare against a missing '
              'variable and match every row');
    });

    test('a negated flag can be passed straight in', () {
      stateManager.set('showAll', true);

      expect(names('filter(rows, "done", !showAll)'), <dynamic>['Bob'],
          reason: 'the shortest way to write "the ones still open unless we '
              'are showing everything" is a negation in the argument');
    });

    test('a signed number literal keeps its sign', () {
      expect(evaluate('max(-3, -5)'), -3,
          reason: 'a sign lost in an argument turns a floor into a ceiling');
      expect(evaluate('round(-1.5)'), -2);
    });

    test('a sign in front of a path is applied to what it resolves to', () {
      stateManager.set('offset', 4);

      expect(evaluate('max(-offset, 0)'), 0);
      expect(evaluate('min(-offset, 0)'), -4);
    });

    test('a quoted string keeps the comma inside it', () {
      expect(evaluate("join(rows, ', ') != null"), isTrue);
    });
  });

  group('a call whose receiver is another call', () {
    test('the tail method takes arguments of its own', () {
      stateManager.set('rows', <dynamic>[
        <String, dynamic>{'name': 'Ada', 'done': true},
        <String, dynamic>{'name': 'Bob', 'done': false},
      ]);

      expect(evaluate("join(map(filter(rows, 'done'), 'name'), '; ')"), 'Ada');
      expect(evaluate("filter(rows, 'done').map('name').join('; ')"), 'Ada',
          reason: '§3.6.4 makes the method form equivalent to the function '
              'form; an author who chains reads a blank otherwise');
      expect(evaluate("filter(rows, 'done').map('name').length"), 1,
          reason: 'the tail of a chain may be a property as well as a call');
    });
  });

  group('an unknown transform', () {
    test('prints the value rather than swallowing it', () {
      stateManager.set('price', 12);

      expect(engine.resolve<String>('{{format(price, "bogus")}}', context),
          '12',
          reason: 'a transform name the runtime does not know is a typo in '
              'the document; the number still has to appear');
    });
  });
}
