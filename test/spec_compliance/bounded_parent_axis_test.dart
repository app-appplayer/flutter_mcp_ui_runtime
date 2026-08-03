// §2.15's list, checked against what actually happens.
//
// Some widgets measure themselves against the space a parent offers rather
// than against their own content. Under a shrink-wrapping ancestor — a
// scrolling page, which is the ordinary authoring shape — they throw a layout
// exception and the subtree stops drawing. §2.15 collects them, because no
// property table reveals it.
//
// That list was hand-written and had already fallen behind: `kanban` grew
// per-column scrolling in this cut, which is exactly what makes a widget need
// a bounded height, and nothing added the row.
//
// **Why the documents here are hand-written.** The first attempt drove this
// from the spec's own examples, and it reported every listed widget as fine —
// including `kanban`, which had just been reproduced failing. The examples
// bind their data (`"columns": "{{board.columns}}"`), so with no state behind
// them they render *empty*, and an empty board needs no height. A layout
// axis needs content; an example-driven one silently measures nothing. Each
// document below therefore carries literal data.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:path/path.dart' as p;

/// Documents with enough literal content to have a size to argue about.
/// Keyed by widget type; the value is placed inside a scrolling page.
const _needsBounds = <String, Map<String, dynamic>>{
  'kanban': <String, dynamic>{
    'type': 'kanban',
    'columns': <Object>[
      <String, dynamic>{
        'id': 'todo',
        'title': 'Todo',
        'items': <Object>[
          <String, dynamic>{'id': '1', 'title': 'a'},
        ],
      },
    ],
    'itemKey': 'id',
    'itemTemplate': <String, dynamic>{
      'type': 'card',
      'child': <String, dynamic>{'type': 'text', 'content': '{{item.title}}'},
    },
  },
  'tabBarView': <String, dynamic>{
    'type': 'tabBarView',
    'children': <Object>[
      <String, dynamic>{'type': 'text', 'content': 'one'},
      <String, dynamic>{'type': 'text', 'content': 'two'},
    ],
  },
  'pageView': <String, dynamic>{
    'type': 'pageView',
    'children': <Object>[
      <String, dynamic>{'type': 'text', 'content': 'one'},
      <String, dynamic>{'type': 'text', 'content': 'two'},
    ],
  },
  'expanded': <String, dynamic>{
    'type': 'linear',
    'direction': 'vertical',
    'children': <Object>[
      <String, dynamic>{
        'type': 'expanded',
        'child': <String, dynamic>{'type': 'text', 'content': 'fills'},
      },
    ],
  },
  'flexible': <String, dynamic>{
    'type': 'linear',
    'direction': 'vertical',
    'children': <Object>[
      <String, dynamic>{
        'type': 'flexible',
        'fit': 'tight',
        'child': <String, dynamic>{'type': 'text', 'content': 'fills'},
      },
    ],
  },
};

/// Widgets that size themselves from their content in the same position.
/// A control group: without it, a harness that reported *everything* as
/// unbounded would look like it was working.
const _selfSizing = <String, Map<String, dynamic>>{
  'text': <String, dynamic>{'type': 'text', 'content': 'hello'},
  'card': <String, dynamic>{
    'type': 'card',
    'child': <String, dynamic>{'type': 'text', 'content': 'hello'},
  },
  'gantt': <String, dynamic>{
    'type': 'gantt',
    'tasks': <Object>[
      <String, dynamic>{
        'id': 't1',
        'name': 'one',
        'start': '2026-01-01',
        'end': '2026-01-05',
      },
    ],
  },
  'spreadsheet': <String, dynamic>{
    'type': 'spreadsheet',
    'data': <Object>[
      <Object>['a', 'b'],
      <Object>['c', 'd'],
    ],
  },
  'table': <String, dynamic>{
    'type': 'table',
    'rows': <Object>[
      <String, dynamic>{
        'cells': <Object>[
          <String, dynamic>{'type': 'text', 'content': 'a'},
        ],
      },
    ],
  },
};

void main() {
  test('§2.15 names every widget this file exercises', () {
    final prose = _documentedFromSpec();
    expect(prose, isNotEmpty, reason: '§2.15 table could not be read');
    final missing = _needsBounds.keys.toSet().difference(prose);
    expect(missing, isEmpty,
        reason: 'these fail under a scrolling page and §2.15 does not say so: '
            '$missing');
    final claimedButUntested =
        _selfSizing.keys.toSet().intersection(prose);
    expect(claimedButUntested, isEmpty,
        reason: '§2.15 lists widgets that size themselves here: '
            '$claimedButUntested');
  });

  for (final entry in _needsBounds.entries) {
    testWidgets('${entry.key} needs a bounded parent', (tester) async {
      expect(await _failsUnbounded(tester, entry.value), isTrue,
          reason: '${entry.key} drew fine without a bound — if that is now '
              'true, §2.15 should drop the row rather than keep warning');
    });

    testWidgets('${entry.key} draws inside a sizedBox', (tester) async {
      // The remedy §2.15 prescribes has to actually work, or the section
      // sends authors somewhere that does not help.
      final bounded = <String, dynamic>{
        'type': 'sizedBox',
        'height': 400,
        'child': entry.value,
      };
      expect(await _failsUnbounded(tester, bounded), isFalse);
    });
  }

  for (final entry in _selfSizing.entries) {
    testWidgets('${entry.key} sizes itself', (tester) async {
      expect(await _failsUnbounded(tester, entry.value), isFalse,
          reason: '${entry.key} started needing a bounded parent — §2.15 '
              'needs a row for it');
    });
  }
}

/// Renders [fragment] inside a vertically scrolling page — every ancestor
/// shrink-wraps — and reports whether layout failed for want of a bound.
Future<bool> _failsUnbounded(
  WidgetTester tester,
  Map<String, dynamic> fragment,
) async {
  await tester.binding.setSurfaceSize(const Size(1280, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  // Installed rather than read back afterwards: a layout assertion raised
  // during `pump` is printed by the framework and `takeException` returns
  // nothing, so a harness that only drains the queue reports every one of
  // these as clean — which is exactly how the first version of this file
  // agreed that `kanban` was fine.
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) => errors.add(details.exceptionAsString());

  final runtime = MCPUIRuntime();
  try {
    await runtime.initialize(<String, dynamic>{
      'type': 'page',
      'content': <String, dynamic>{
        'type': 'scrollView',
        'children': <Object>[fragment],
      },
    });
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: runtime.buildUI())),
    );
    // Settle rather than pump a fixed slice: a widget that materializes from
    // a post-frame callback reaches its failure after the frame a single 50 ms
    // pump produces. `pumpAndSettle` throws on a scene that never settles (an
    // indeterminate progress indicator animates forever), so the fixed wait
    // stays as the fallback for those.
    try {
      // Capped: an indeterminate progress indicator never settles, and the
      // default budget grinds for ten minutes before saying so.
      await tester.pumpAndSettle(
        const Duration(milliseconds: 16),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 1),
      );
    } catch (_) {
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
  } finally {
    FlutterError.onError = previous;
  }

  final unbounded = errors.any((text) =>
      text.contains('infinite') ||
      text.contains('unbounded') ||
      text.contains('non-zero flex'));

  // Anything the framework did queue is drained so it does not fail teardown
  // for a failure this test has already accounted for.
  while (tester.takeException() != null) {}

  await runtime.dispose();
  return unbounded;
}

/// Widget names appearing in the first column of §2.15's table.
Set<String> _documentedFromSpec() {
  final file = File(
    p.join(_repoRoot(), 'specs', 'mcp_ui_dsl', 'spec', '1.4', '02_Widgets.md'),
  );
  if (!file.existsSync()) return const <String>{};
  final lines = file.readAsLinesSync();
  final start = lines.indexWhere(
      (l) => l.startsWith('## 2.15 Widgets that require a bounded parent'));
  if (start < 0) return const <String>{};

  final names = <String>{};
  for (var i = start + 1; i < lines.length; i++) {
    final line = lines[i];
    if (line.startsWith('## ')) break;
    if (!line.startsWith('| `')) continue;
    final cell = line.split('|')[1];
    for (final match in RegExp(r'`([a-zA-Z]+)`').allMatches(cell)) {
      names.add(match.group(1)!);
    }
  }
  return names;
}

String _repoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 12; i++) {
    if (Directory(p.join(dir.path, 'specs', 'mcp_ui_dsl')).existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return Directory.current.path;
}
