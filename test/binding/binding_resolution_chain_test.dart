// Where a bare path is looked up, and what a binding becomes on the way into
// a string.
//
// The lookup order is lexical — local, then page, then app, then theme — and
// each step is a separate branch. A path resolved from the wrong scope reads
// as a stale value rather than as a missing one, which is the harder failure
// to see.

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
    ThemeManager.instance.reset();
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

  dynamic read(String expression, [RenderContext? ctx]) =>
      engine.resolve<dynamic>(expression, ctx ?? context);

  group('the lookup order', () {
    test('a local variable shadows everything', () {
      stateManager.set('page.title', 'from page');
      stateManager.set('app.title', 'from app');
      final child = context.createChildContext(variables: {'title': 'local'});

      expect(read('{{title}}', child), 'local',
          reason: 'the inner scope wins, or a template parameter could not '
              'shadow the page it is used on');
    });

    test('page state is read before app state', () {
      stateManager.set('page.title', 'from page');
      stateManager.set('app.title', 'from app');

      expect(read('{{title}}'), 'from page');
    });

    test('app state answers when the page has nothing', () {
      stateManager.set('app.title', 'from app');

      expect(read('{{title}}'), 'from app');
    });

    test('the theme answers when neither does', () {
      ThemeManager.instance.setTheme({
        'colors': {'primary': '#FF0000'},
      });

      expect(read('{{color.primary}}'), isNotNull,
          reason: 'a theme value named without the `theme.` prefix is how the '
              'shorthand in the spec\'s examples resolves; answering null '
              'would send the widget to its default with nothing said');
    });

    test('the scope prefixes are aliases of the one store, not key paths', () {
      // §3.5 / §17.2.5 — `app.`, `page.` and `state.` NAME the scope; they do
      // not address a key literally called `app.title`. A runtime that read
      // them literally answered null for every document written in the
      // explicit form, and the widget drew its default without a word.
      stateManager.set('title', 'the one store');

      expect(read('{{app.title}}'), 'the one store');
      expect(read('{{page.title}}'), 'the one store');
      expect(read('{{state.title}}'), 'the one store');
    });

    test('a path nobody has is null', () {
      expect(read('{{nothing.at.all}}'), isNull);
    });
  });

  group('a binding inside a string', () {
    test('is replaced in place, with the rest of the string kept', () {
      stateManager.set('name', 'Ada');

      expect(engine.resolve<String>('Hello {{name}}, welcome', context),
          'Hello Ada, welcome');
    });

    test('a null resolves to an empty string rather than the word null', () {
      expect(engine.resolve<String>('Hello {{missing}}', context), 'Hello ',
          reason: 'the literal "null" on a label is worse than a blank — it '
              'reads as content');
    });

    test('a whole number prints without a decimal point', () {
      stateManager.set('count', 3.0);

      expect(engine.resolve<String>('{{count}} items', context), '3 items',
          reason: '"3.0 items" is a number that came from a computation, and '
              'the reader did not ask about the computation');
    });

    test('a fractional number keeps its decimals', () {
      stateManager.set('total', 3.5);

      expect(engine.resolve<String>('{{total}} kg', context), '3.5 kg');
    });

    test('several bindings in one string are all replaced', () {
      stateManager.set('first', 'Ada');
      stateManager.set('last', 'Lovelace');

      expect(engine.resolve<String>('{{first}} {{last}}', context),
          'Ada Lovelace');
    });

    test('a transform applies to the interpolated value', () {
      stateManager.set('total', 1234.5);

      expect(engine.resolve<String>('{{total | currency}}', context),
          r'$1234.50');
    });
  });

  group('type conversion', () {
    test('a missing value takes the empty default for its type', () {
      expect(engine.resolve<String>('{{missing}}', context), '');
      expect(engine.resolve<int>('{{missing}}', context), 0);
      expect(engine.resolve<double>('{{missing}}', context), 0.0);
      expect(engine.resolve<bool>('{{missing}}', context), isFalse);
    });

    test('a nullable type gets the null', () {
      expect(engine.resolve<String?>('{{missing}}', context), isNull);
    });

    test('a type with no empty value is refused rather than guessed at', () {
      expect(
        () => engine.resolve<List<dynamic>>('{{missing}}', context),
        throwsA(isA<Exception>()),
        reason: 'inventing an empty list here would hide a path that never '
            'resolved behind a widget that legitimately has no rows',
      );
    });
  });

  group('collection methods in their call form', () {
    test('length, isEmpty and isNotEmpty on a map', () {
      stateManager.set('row', {'a': 1, 'b': 2});
      stateManager.set('empty', <String, dynamic>{});

      expect(read('{{row.length()}}'), 2);
      expect(read('{{empty.isEmpty()}}'), isTrue);
      expect(read('{{row.isNotEmpty()}}'), isTrue);
    });

    test('the same methods on a list and a string', () {
      stateManager.set('rows', [1, 2, 3]);
      stateManager.set('name', 'ada');

      expect(read('{{rows.length()}}'), 3);
      expect(read('{{name.length()}}'), 3);
      expect(read('{{rows.isNotEmpty()}}'), isTrue);
    });

    test('a method on something that has none answers the empty case', () {
      stateManager.set('count', 7);

      expect(read('{{count.length()}}'), 0);
      expect(read('{{count.isEmpty()}}'), isTrue);
      expect(read('{{count.isNotEmpty()}}'), isFalse);
    });
  });
}
