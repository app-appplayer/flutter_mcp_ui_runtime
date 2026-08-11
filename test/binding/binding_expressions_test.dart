// The corners of the binding language: transforms, the list and map methods,
// the formatting functions, and the reserved prefixes.
//
// These are the expressions a document writes once and reads a hundred times.
// Each one that answers null answers it silently — a label that shows nothing,
// a total that never appears — so the assertions here are on the value, never
// on "it did not throw".

import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/i18n/i18n_manager.dart';
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

  dynamic read(String expression) => engine.resolve<dynamic>(expression, context);

  group('transforms', () {
    test('truncate drops the fraction without rounding', () {
      stateManager.set('n', 7.9);
      expect(read('{{n | truncate}}'), 7,
          reason: 'truncate that rounds is `round` under another name');
    });

    test('padLeft pads to two with zeroes', () {
      stateManager.set('n', 7);
      expect(read('{{n | padLeft}}'), '07');
    });

    test('padRight pads to two with spaces', () {
      stateManager.set('n', 7);
      expect(read('{{n | padRight}}'), '7 ');
    });

    test('json encodes a whole object', () {
      stateManager.set('row', {'a': 1});
      expect(read('{{row | json}}'), '{"a":1}');
    });

    test('json falls back to a string for something it cannot encode', () {
      stateManager.set('row', DateTime.utc(2026));
      expect(read('{{row | json}}'), contains('2026'),
          reason: 'a value the encoder refuses must still print as something');
    });

    test('an unknown transform leaves the value alone', () {
      stateManager.set('n', 5);
      expect(read('{{n | notATransform}}'), 5);
    });
  });

  group('list and map methods', () {
    test('indexOf on a list', () {
      stateManager.set('rows', ['a', 'b', 'c']);
      expect(read('{{rows.indexOf("b")}}'), 1);
    });

    test('indexOf on a string', () {
      stateManager.set('s', 'abcabc');
      expect(read('{{s.indexOf("c")}}'), 2);
    });

    test('length of a map counts its keys', () {
      stateManager.set('row', {'a': 1, 'b': 2});
      expect(read('{{row.length}}'), 2,
          reason: 'the same spelling answers on a list; answering null on an '
              'object is the collection-property defect one type over');
    });

    test('a real key called `length` still wins over the count', () {
      stateManager.set('row', {'length': 'ten metres'});
      expect(read('{{row.length}}'), 'ten metres',
          reason: 'the object\'s own data is not shadowed by a convenience');
    });

    test('isEmpty and isNotEmpty on a map', () {
      stateManager.set('empty', <String, dynamic>{});
      stateManager.set('full', {'a': 1});

      expect(read('{{empty.isEmpty}}'), isTrue);
      expect(read('{{full.isNotEmpty}}'), isTrue);
      expect(read('{{full.isEmpty}}'), isFalse);
    });

    test('replace on a string, method form', () {
      stateManager.set('s', 'a-b-c');
      expect(read('{{s.replace("-", "+")}}'), 'a+b+c');
    });

    test('add appends to the list in state', () {
      stateManager.set('rows', ['a']);
      final result = read('{{rows.add("b")}}') as List;

      expect(result, ['a', 'b']);
      expect(stateManager.get('rows'), ['a', 'b'],
          reason: 'the method mutates the bound list, so the screen bound to '
              'it has to see the same content');
    });

    test('remove drops the entry', () {
      stateManager.set('rows', ['a', 'b']);
      expect(read('{{rows.remove("a")}}'), ['b']);
    });

    test('clear empties the list', () {
      stateManager.set('rows', ['a', 'b']);
      expect(read('{{rows.clear()}}'), isEmpty);
    });

    test('a map is indexed by a bracket expression', () {
      stateManager.set('row', {'name': 'Ada'});
      stateManager.set('key', 'name');
      expect(read('{{row[key]}}'), 'Ada');
    });

    test('a map indexed by a non-string key falls back to its text form', () {
      stateManager.set('byId', {'7': 'Ada'});
      stateManager.set('id', 7);
      expect(read('{{byId[id]}}'), 'Ada',
          reason: 'a JSON object keyed by a numeric id is ordinary, and the '
              'key arrives as a number from state');
    });

    test('a list index past the end is null, not a range error', () {
      stateManager.set('rows', ['a']);
      expect(read('{{rows[5]}}'), isNull);
    });
  });

  group('reduce', () {
    test('the accumulator form threads the running total (§3.6.3)', () {
      stateManager.set('rows', [1, 2, 3]);
      expect(read('{{rows.reduce((acc, i) => acc + i, 10)}}'), 16,
          reason: 'this is the spelling the spec\'s own example uses; it used '
              'to answer the seed unchanged, which reads as "no data" rather '
              'than as a broken expression');
    });

    test('the accumulator form reduces objects by a field', () {
      stateManager.set('rows', [
        {'price': 3},
        {'price': 4},
      ]);
      expect(read('{{rows.reduce((acc, item) => acc + item.price, 0)}}'), 7);
    });

    test('the map-then-sum form still sums each mapped item', () {
      stateManager.set('rows', [
        {'price': 3},
        {'price': 4},
      ]);
      expect(read('{{rows.reduce((item) => item.price, 10)}}'), 17,
          reason: 'the single-parameter form is the other half of §3.6.3 and '
              'must not change meaning');
    });

    test('reduces an empty list to the initial value', () {
      stateManager.set('rows', <dynamic>[]);
      expect(read('{{rows.reduce((acc, i) => acc + i, 10)}}'), 10);
    });
  });

  group('format(value, pattern)', () {
    test('formats an ISO date by pattern', () {
      stateManager.set('at', '2026-03-09T14:05:00');
      expect(read('{{format(at, "YYYY-MM-DD")}}'), '2026-03-09');
    });

    test('formats a number by pattern', () {
      stateManager.set('total', 1234.5);
      expect(read('{{format(total, "#,##0.00")}}'), '1,234.50');
    });

    test('a value that is neither prints as itself', () {
      stateManager.set('v', true);
      expect(read('{{format(v, "YYYY")}}'), 'true');
    });

    test('a string that is not a date prints as itself', () {
      stateManager.set('v', 'not a date');
      expect(read('{{format(v, "YYYY-MM-DD")}}'), 'not a date');
    });
  });

  group('format.number and format.date', () {
    test('currency uses the symbol for the code', () {
      stateManager.set('total', 1234.5);
      expect(read('{{format.number(total, "currency", "USD")}}'), r'$1,234.50');
    });

    test('an unknown currency code is used as its own symbol', () {
      stateManager.set('total', 10);
      expect(read('{{format.number(total, "currency", "XYZ")}}'),
          'XYZ10.00',
          reason: 'a currency this runtime has no symbol for must still be '
              'named, not dropped');
    });

    test('percent multiplies by a hundred', () {
      stateManager.set('rate', 0.256);
      expect(read('{{format.number(rate, "percent")}}'), '26%');
    });

    test('decimal is the default style', () {
      stateManager.set('total', 1234.5);
      expect(read('{{format.number(total, "decimal")}}'), '1,234.5');
      expect(read('{{format.number(total)}}'), '1,234.5');
    });

    test('a numeric string is parsed first', () {
      stateManager.set('total', '1234.5');
      expect(read('{{format.number(total, "decimal")}}'), '1,234.5');
    });

    test('a value that is not a number prints as itself', () {
      stateManager.set('total', 'not a number');
      expect(read('{{format.number(total)}}'), 'not a number');
    });

    test('every date style has its own shape', () {
      stateManager.set('at', '2026-03-09T14:05:06.789');

      expect(read('{{format.date(at, "short")}}'), '03/09/26');
      expect(read('{{format.date(at, "medium")}}'), '2026-03-09');
      expect(read('{{format.date(at)}}'), '2026-03-09');
      expect(read('{{format.date(at, "long")}}'), '2026-03-09 14:05:06');
      expect(read('{{format.date(at, "full")}}'), '2026-03-09 14:05:06.789');
    });

    test('a value that is not a date prints as itself', () {
      stateManager.set('at', 'sometime');
      expect(read('{{format.date(at, "short")}}'), 'sometime');
    });

    // §3 names two members of this namespace. A document that reaches for a
    // third — `format.currency`, `format.time`, a typo — is asking for
    // something that does not exist, and the value it was formatting still
    // has to reach the screen: printing nothing there would blank a label
    // whose data was fine.
    test('a member of the namespace that does not exist prints the value', () {
      stateManager.set('total', 1234.5);

      expect(read('{{format.currency(total)}}'), '1234.5');
      expect(read('{{format.time(total)}}'), '1234.5');
    });
  });

  group('calculateDuration', () {
    const start = '2026-03-01T00:00:00';
    const end = '2026-03-03T06:30:15';

    setUp(() {
      stateManager.set('from', start);
      stateManager.set('to', end);
    });

    test('days is the default unit', () {
      expect(read('{{calculateDuration(from, to)}}'), 2);
      expect(read('{{calculateDuration(from, to, "days")}}'), 2);
    });

    test('hours, minutes, seconds and milliseconds each answer their own unit',
        () {
      expect(read('{{calculateDuration(from, to, "hours")}}'), 54);
      expect(read('{{calculateDuration(from, to, "minutes")}}'), 3270);
      expect(read('{{calculateDuration(from, to, "seconds")}}'), 196215);
      expect(read('{{calculateDuration(from, to, "milliseconds")}}'), 196215000,
          reason: 'a unit that silently answers days would be off by a factor '
              'of 86,400,000 and still look like a number');
    });

    test('an unparseable end is null rather than a wrong number', () {
      stateManager.set('to', 'not a date');
      expect(read('{{calculateDuration(from, to)}}'), isNull);
    });
  });

  group('reserved prefixes', () {
    test('i18n.* resolves through the translator', () async {
      I18nManager.instance.clear();
      addTearDown(I18nManager.instance.clear);
      await I18nManager.instance.loadTranslations({
        'fallbackLocale': 'en',
        'translations': {
          'en': {'greeting': 'Hello'},
        },
      });
      I18nManager.instance.setLocale('en');

      expect(read('{{i18n.greeting}}'), 'Hello');
    });

    test('an untranslated i18n key answers with the key itself', () async {
      I18nManager.instance.clear();
      addTearDown(I18nManager.instance.clear);
      await I18nManager.instance.loadTranslations({
        'fallbackLocale': 'en',
        'translations': {'en': <String, dynamic>{}},
      });
      I18nManager.instance.setLocale('en');

      expect(read('{{i18n.missing.key}}'), contains('missing'),
          reason: 'a blank label is harder to diagnose than the key');
    });

    test('event.* with no event in scope is null, not an error', () {
      expect(read('{{event.value}}'), isNull);
    });

    test('event.* resolves from the child context that published it', () {
      final child = context.createChildContext(variables: {
        'event': {'value': 'chosen', 'nested': {'deep': 1}},
      });

      expect(engine.resolve<dynamic>('{{event.value}}', child), 'chosen');
      expect(engine.resolve<dynamic>('{{event.nested.deep}}', child), 1);
    });

    test('route.params.* reads the current route parameters', () {
      stateManager.set('route.params', {'id': '42'});
      expect(read('{{route.params.id}}'), '42');
    });

    test('route.params.* with no route is null', () {
      expect(read('{{route.params.id}}'), isNull);
    });

    test('an empty expression is left as written rather than throwing', () {
      expect(read('{{}}'), '{{}}',
          reason: 'a stray `{{}}` in a label is a typo in the document; '
              'printing it is how the author finds it');
    });
  });

  // State does not have to be JSON. `stateManager.set` takes a `dynamic`, and
  // a tool executor that hands back an object of its own puts that object in
  // state. Two things followed from that, and both were measured here rather
  // than reasoned about.
  group('what reading and writing state costs', () {
    test('a read does not stringify what it reads, or the whole state', () {
      final counted = _CountingValue();
      stateManager.set('big', counted);
      stateManager.set('name', 'Ada');
      final beforeReads = counted.toStringCalls;

      for (var i = 0; i < 50; i++) {
        read('{{name}}');
        stateManager.get<dynamic>('name');
      }

      expect(counted.toStringCalls, beforeReads,
          reason: 'the debug line used to interpolate the ENTIRE state map on '
              'every get and every set — built whether or not logging is on, '
              'because the message is a String argument. Reads happen on every '
              'binding of every frame, so the size of a document\'s state '
              'became the speed of its screens');
    });

    test('a write does not stringify the value it is given', () {
      final counted = _CountingValue();

      stateManager.set('slot', counted);
      final afterFirst = counted.toStringCalls;
      stateManager.set('other', 1);

      expect(afterFirst, 0,
          reason: 'a host object whose `toString` throws took the write down '
              'with it, before any binding was involved');
      expect(counted.toStringCalls, 0);
    });
  });

  group('interpolating a value that misbehaves', () {
    test('a value whose toString throws does not take the line down', () {
      stateManager.set('name', 'Ada');
      stateManager.set('broken', _HostileValue());

      final line = context.resolve<dynamic>('Hi {{name}} - {{broken}}');

      expect(line, startsWith('Hi Ada'),
          reason: 'the part of the sentence that resolved is still the '
              'author\'s screen; losing it because a neighbour blew up is the '
              'expensive failure');
    });
  });
}

/// Counts how many times something asks it to become a string.
class _CountingValue {
  int toStringCalls = 0;

  @override
  String toString() {
    toStringCalls++;
    return 'counted';
  }
}

/// A value that refuses to be printed — what a host object with its own
/// `toString` can do to a document that interpolates it.
class _HostileValue {
  @override
  String toString() => throw StateError('cannot render this');
}
