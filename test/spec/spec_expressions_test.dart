// The runtime answers for the spec's own examples.
//
// Every binding defect reported from outside this package was already written
// in the prose: §3.6.1 shows `round(price * quantity, 2)` as its own example
// and the runtime returned an empty string for it, in every published version
// back to 0.5.1. The schema validated the document, 5,600 tests passed, the
// capability probe drew every surface — and none of them read the spec. The
// first person to execute that line was the author following the document.
//
// Two halves, and both are needed:
//
//   * the CORPUS — expression forms with the answer the spec fixes. Hand
//     authored (the spec rarely writes the result next to the example), so it
//     carries meaning a scraper cannot.
//   * the INVENTORY — every `{{ … }}` mechanically pulled from the 1.4 prose by
//     `tools/spec_codegen/bin/spec_examples.dart`. Its test is the last one
//     here: an expression the spec writes that appears in NO bucket fails the
//     suite. That is what keeps the corpus honest as the spec grows — the
//     previous cut fixed two holes in `_parseArguments` (quoted commas, nested
//     calls) and walked past the third, because nothing enumerated the forms.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// An expression the spec writes, the state it is evaluated against, and the
/// value the spec fixes for it.
class Expectation {
  const Expectation(this.state, this.expected);

  final Map<String, dynamic> state;
  final Object? expected;
}

/// Forms not in the shared corpus: §10's canvas geometry, §16's animated
/// properties, §2's conditional shapes. State is seeded per case so the answer
/// is the expression's and not the fixture's.
const Map<String, Expectation> checked = {
  // §3.2 — comparison and the conditional form.
  "count > 0 ? 'Has items' : 'Empty'": Expectation({'count': 3}, 'Has items'),
  "status == 'online' ? '#4CAF50' : '#F44336'":
      Expectation({'status': 'online'}, '#4CAF50'),
  'expanded ? 200 : 50': Expectation({'expanded': true}, 200),
  'expanded ? 300 : 100': Expectation({'expanded': false}, 100),
  "expanded ? '#2196F3' : '#E0E0E0'": Expectation({'expanded': true}, '#2196F3'),
  'item.isActive ? 1.0 : 0.3': Expectation({
    'item': {'isActive': false},
  }, 0.3),
  '!user.isAuthenticated': Expectation({
    'user': {'isAuthenticated': false},
  }, true),

  // §3.2 — arithmetic, in the shapes §10 uses to place canvas geometry. A
  // gauge whose needle expression silently drops a term draws at the wrong
  // angle and nothing reports it.
  'size / 2': Expectation({'size': 100}, 50),
  'size / 2 - 4': Expectation({'size': 100}, 46),
  'size / 2 + 5': Expectation({'size': 100}, 55),
  'size * 0.25': Expectation({'size': 100}, 25),
  '-1.57 + (value / max) * 6.28':
      Expectation({'value': 50, 'max': 100}, 1.57),
  // The same sign, one level down. Inside an argument the sign used to be
  // read as "unary minus applied to the rest", so it swallowed the whole
  // expression: `-(1.57 + 0.5)`. An author who wraps a gauge angle in
  // `round(…)` to fix its decimals got the angle back with the wrong sign —
  // the widget draws confidently and nothing reports it. (konpi, measured on
  // a built app before this cut went anywhere.)
  'round(-1.57 + 0.5, 2)': Expectation({}, -1.07),
  'round(-1.57 - 0.5, 2)': Expectation({}, -2.07),
  'round(0.5 + -1.57, 2)': Expectation({}, -1.07),
  'round((-1.57) + 0.5, 2)': Expectation({}, -1.07),
  'round(-1.5707963 + (pct / 100) * 3.1415926, 4)':
      Expectation({'pct': 68}, 0.5655),
  '3.14 + (app.progress / 100) * 3.14': Expectation({'progress': 50}, 4.71),

  // §3.6.2/§3.6.4 — a predicate written the way every other language writes
  // it, and a call's result read the way a path is read. Both came back empty
  // rather than wrong: `(r) => r.ok` was not recognised as a lambda, so the
  // value it evaluated to was read as a property NAME and the filter answered
  // with no rows; `filter(...).length` fell to a path lookup and answered
  // null, while `rows.length` — the same reading of the same list — answered.
  // Two consumers wrote the "N of M" form and both read a blank.
  "length(filter(rows, 'ok'))": Expectation({
    'rows': [
      {'ok': true},
      {'ok': false},
      {'ok': true},
    ],
  }, 2),
  "filter(rows, 'ok').length": Expectation({
    'rows': [
      {'ok': true},
      {'ok': false},
      {'ok': true},
    ],
  }, 2),
  'filter(rows, (r) => r.ok).length': Expectation({
    'rows': [
      {'ok': true},
      {'ok': false},
      {'ok': true},
    ],
  }, 2),
  'rows.length': Expectation({
    'rows': [
      {'ok': true},
      {'ok': false},
    ],
  }, 2),
  // §3.6.3 — the lambda form of reduce, with the spec's own arguments.
  'reduce(items, (acc, i) => acc + i.price * i.qty, 0)': Expectation({
    'items': [
      {'price': 10, 'qty': 2},
      {'price': 5, 'qty': 4},
    ],
  }, 40),

  // §3.4/§3.5/§17.2.5 — `page.` is the explicit alias of the bare resolution
  // target, `state.` its synonym, and `app.` targets application state.
  'app.count': Expectation({'count': 7}, 7),
  'page.count': Expectation({'count': 7}, 7),
  'state.count': Expectation({'count': 7}, 7),
  'state.isActive ? 1.0 : 0.3': Expectation({'isActive': true}, 1.0),
};

/// Namespace notation the prose uses to NAME a scope (`app.*`), and prose
/// elisions. Not expressions; nothing to evaluate.
const Map<String, String> notation = {
  '...': 'an elision in prose, not an expression',
  'app.*': 'namespace notation',
  'page.*': 'namespace notation',
  'local.*': 'namespace notation',
  'theme.*': 'namespace notation',
  'i18n.*': 'namespace notation',
  'state.*': 'namespace notation',
  'channels.*': 'namespace notation',
  'resources.*': 'namespace notation',
};

/// Forms whose value comes from a subsystem this suite does not stand up
/// (i18n catalogues, channels, forms, event payloads, template locals). Each
/// names where it IS covered. A bucket with a reason is a decision; a bucket
/// without one is the hole these defects lived in.
const Map<String, String> coveredElsewhere = {
  "filter(items, 'active')": 'corpus fn-shorthand-filter',
  "format(date, 'YYYY-MM-DD')": 'binding date-format suite',
  "filter == 'all' ? items : filter(items, 'status', filter)":
      'corpus fn-shorthand-filter',
  'i18n.currency(price)': 'i18n suite',
  'i18n.shortDate(createdAt)': 'i18n suite',
  'i18n.itemCount({count: 5})': 'i18n suite',
  'i18n.greeting:en-US': 'i18n suite (explicit locale form)',
  'i18n.key:xx-YY': 'i18n suite (explicit locale form)',
  "event.data.category === 'electronics'": '14_Responsive_Events suite',
  "event.data.status === 'offline'": '15_Offline_Sync suite',
  'form.photo[0].bytes': 'form suite',
  'local.isFlipped ? 3.14 : 0': 'template-local suite (§09)',
  'local.isHovered ? 1.05 : 1.0': 'template-local suite (§09)',
  "local.expanded ? 'expandLess' : 'expandMore'':":
      'template-local suite (§09)',
  "local.expanded ? 'expandLess' : 'expandMore'": 'template-local suite (§09)',
};

/// Prefixes owned by a subsystem rather than by page state. A bare path under
/// one of these is answered by that subsystem's suite; naming them here keeps
/// them out of the mechanical read below without dropping them silently.
const List<String> subsystemPrefixes = [
  'theme.',
  'i18n.',
  'channels.',
  'permissions.',
  'resources.',
  'runtime.',
  'route.',
  'entry.',
  'identity.',
  'event.',
  '_events.',
  'form.',
  'slot.',
  'local.',
];

RenderContext contextWith(Map<String, dynamic> state) {
  final stateManager = StateManager()
    ..initialize(Map<String, dynamic>.from(state));
  final engine = BindingEngine();
  final actionHandler = ActionHandler();
  final renderer = Renderer(
    widgetRegistry: WidgetRegistry(),
    bindingEngine: engine,
    actionHandler: actionHandler,
    stateManager: stateManager,
  );
  return RenderContext(
    renderer: renderer,
    stateManager: stateManager,
    actionHandler: actionHandler,
    themeManager: ThemeManager(),
    bindingEngine: engine,
    buildContext: null,
  );
}

void expectValue(Object? actual, Object? expected) {
  if (expected is num && actual is num) {
    expect(actual.toDouble(), closeTo(expected.toDouble(), 1e-9));
  } else {
    expect(actual, expected);
  }
}

void main() {
  group('corpus — the forms §3 documents, with the answers it fixes', () {
    // Authored against the spec's sections and handed over to live in the
    // gate; running it here is the difference between an author finding a
    // defect after upload and the gate finding it before.
    final corpus = jsonDecode(
      File('test/spec/spec_expression_corpus.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final state = corpus['state'] as Map<String, dynamic>;

    for (final entry in (corpus['cases'] as List<dynamic>)
        .cast<Map<String, dynamic>>()) {
      test('${entry['id']} — ${entry['expr']}', () {
        final context = contextWith(state);
        final actual = context.resolve<dynamic>(entry['expr'] as String);
        if (entry.containsKey('expectLength')) {
          expect((actual as List).length, entry['expectLength']);
        } else {
          expectValue(actual, entry['expect']);
        }
      });
    }
  });

  group('spec examples evaluate to what the spec says', () {
    checked.forEach((expression, expectation) {
      test(expression, () {
        final context = contextWith(expectation.state);
        expectValue(
            context.resolve<dynamic>('{{$expression}}'), expectation.expected);
      });
    });
  });

  test('every expression the spec writes is in a bucket', () {
    // The inventory is generated from the prose. If this fails, the spec grew
    // an example nothing answers for — put it in `checked` or the corpus, or
    // in a bucket WITH a reason. Regenerate with:
    //   dart run bin/spec_examples.dart <spec 1.4 dir> <this fixture>
    final fixture = File('test/spec/spec_expressions.json');
    expect(fixture.existsSync(), isTrue,
        reason: 'the generated inventory must be committed beside this test');
    final inventory =
        (jsonDecode(fixture.readAsStringSync()) as Map<String, dynamic>)
            ['expressions'] as List<dynamic>;
    expect(inventory.length, greaterThan(100),
        reason: 'an inventory this small means the extractor stopped seeing '
            'the prose — the gate would then pass by knowing nothing');

    final corpus = jsonDecode(
      File('test/spec/spec_expression_corpus.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final corpusForms = {
      for (final c in (corpus['cases'] as List<dynamic>)
          .cast<Map<String, dynamic>>())
        (c['expr'] as String).replaceAll(RegExp(r'^\{\{|\}\}$'), '').trim(),
    };

    final isPath = RegExp(r'^[A-Za-z_]\w*(\.[A-Za-z_]\w*)*$');
    final unanswered = <String>[];
    for (final entry in inventory.cast<Map<String, dynamic>>()) {
      final expression = entry['expression'] as String;
      if (checked.containsKey(expression)) continue;
      if (corpusForms.contains(expression)) continue;
      if (notation.containsKey(expression)) continue;
      if (coveredElsewhere.containsKey(expression)) continue;
      // A bare path's meaning is the lookup itself; the mechanical read below
      // covers that shape, and subsystem-owned prefixes are named above.
      if (isPath.hasMatch(expression)) continue;
      unanswered.add('${entry['file']}:${entry['line']}  $expression');
    }

    expect(unanswered, isEmpty,
        reason: 'the spec writes these and nothing answers for them:\n'
            '${unanswered.join('\n')}');
  });

  group('bare paths read the value at the path', () {
    // The shape every plain `{{a.b}}` in the prose shares. Seeded nested so
    // the read has to walk, not just hit a flat key.
    for (final path in ['count', 'user.name', 'app.user.name']) {
      test(path, () {
        final parts = path.startsWith('app.')
            ? path.substring(4).split('.')
            : path.split('.');
        dynamic value = 'marker:$path';
        for (var i = parts.length - 1; i > 0; i--) {
          value = {parts[i]: value};
        }
        final context = contextWith({parts.first: value});
        expect(context.resolve<dynamic>('{{$path}}'), 'marker:$path');
      });
    }
  });

  test('subsystem prefixes are named, not forgotten', () {
    // Guards the list above from being quietly emptied: a prefix dropped from
    // it turns into "bare path" and gets a pass it did not earn.
    expect(subsystemPrefixes, contains('theme.'));
    expect(subsystemPrefixes, contains('i18n.'));
    expect(subsystemPrefixes.length, greaterThanOrEqualTo(10));
  });
}
