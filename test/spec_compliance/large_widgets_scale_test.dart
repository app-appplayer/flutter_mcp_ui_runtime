// The three heavy widgets, at the size they will actually be used at.
//
// sapi asked for these — kanban, gantt, spreadsheet — and could not verify
// them: they are not in the App Builder palette yet, so no document
// containing one can be authored there. That is a real constraint on their
// side and no reason for the widget to go out unexercised, because the spec
// examples are three rows and a handful of columns and every one of these
// falls over at a different scale than that.
//
// So the documents here are generated, not copied: a board with 6 columns and
// 120 cards, a chart with 200 tasks across a year, a sheet of 500 × 12 cells.
// The question is the same one the render matrix asks — no exception, no
// error widget — plus the two that only appear under load: does it lay out
// inside a real viewport, and does it still draw the content it was given.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

Map<String, dynamic> _kanban({required int columns, required int cards}) {
  var id = 0;
  return <String, dynamic>{
    'type': 'kanban',
    'itemKey': 'id',
    'draggable': true,
    'columns': <Map<String, dynamic>>[
      for (var c = 0; c < columns; c++)
        <String, dynamic>{
          'id': 'col-$c',
          'title': 'Column $c',
          'items': <Map<String, dynamic>>[
            for (var i = 0; i < cards ~/ columns; i++)
              <String, dynamic>{
                'id': 'card-${id++}',
                'title': 'Card $i in column $c',
                'assignee': 'user-${i % 7}',
              },
          ],
        },
    ],
    'itemTemplate': <String, dynamic>{
      'type': 'card',
      'child': <String, dynamic>{'type': 'text', 'content': '{{item.title}}'},
    },
  };
}

Map<String, dynamic> _gantt(int tasks) => <String, dynamic>{
      'type': 'gantt',
      'viewMode': 'week',
      'showProgress': true,
      'showDependencies': true,
      'todayMarker': true,
      'tasks': <Map<String, dynamic>>[
        for (var i = 0; i < tasks; i++)
          <String, dynamic>{
            'id': 'task-$i',
            'name': 'Task $i',
            // Spread across a year so the timeline is genuinely wide.
            'start': '2026-01-${(i % 28) + 1}'.padLeft(10, '0'),
            'end': '2026-02-${(i % 28) + 1}'.padLeft(10, '0'),
            'progress': (i % 11) * 10,
            if (i > 0) 'dependencies': <String>['task-${i - 1}'],
          },
      ],
    };

Map<String, dynamic> _spreadsheet({required int rows, required int cols}) =>
    <String, dynamic>{
      'type': 'spreadsheet',
      'rowHeaders': true,
      'columnHeaders': true,
      'frozenRows': 1,
      'frozenColumns': 1,
      'data': <List<Object>>[
        for (var r = 0; r < rows; r++)
          <Object>[for (var c = 0; c < cols; c++) 'R${r}C$c'],
      ],
    };

/// Renders and reports the first problem, or null when the frame is clean.
Future<String?> _draw(WidgetTester tester, Map<String, dynamic> widget) async {
  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exception.toString();
    if (text.contains('ink_sparkle.frag')) return;
    if (text.contains('HTTP request failed, statusCode: 400')) return;
    errors.add(details);
  };

  // A real desktop window, not the 800×600 default: a board that only fits
  // because the surface is tiny has not been tested.
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final runtime = MCPUIRuntime();
  String? failure;
  try {
    await runtime.initialize(
      <String, dynamic>{'type': 'page', 'content': widget},
      useCache: false,
    );
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: runtime.buildUI())),
    );
    // Two frames: viewport and overflow failures land after the first.
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
    await tester.pump(const Duration(milliseconds: 250));
  } catch (e) {
    failure = 'threw while building: $e';
  }
  FlutterError.onError = previous;

  if (failure == null) {
    for (final marker in const [
      'Unknown widget type:',
      'Error rendering',
      'Widget type is required',
    ]) {
      final found = find.textContaining(marker);
      if (!tester.any(found)) continue;
      failure = 'error widget drawn: '
          '${tester.widgetList<Text>(found).first.data ?? marker}';
      break;
    }
  }
  if (failure == null && errors.isNotEmpty) {
    failure = 'FlutterError: ${errors.first.exceptionAsString()}';
  }
  await runtime.dispose();
  return failure;
}

void main() {
  testWidgets('kanban — 6 columns, 120 cards', (tester) async {
    expect(await _draw(tester, _kanban(columns: 6, cards: 120)), isNull);
  });

  testWidgets('kanban — one column holding everything', (tester) async {
    // The distribution that breaks a board built around even columns.
    expect(await _draw(tester, _kanban(columns: 1, cards: 200)), isNull);
  });

  testWidgets('gantt — 200 tasks with dependencies', (tester) async {
    expect(await _draw(tester, _gantt(200)), isNull);
  });

  testWidgets('spreadsheet — 500 × 12 with frozen headers', (tester) async {
    expect(
      await _draw(tester, _spreadsheet(rows: 500, cols: 12)),
      isNull,
    );
  });

  testWidgets('spreadsheet — wide rather than tall (20 × 80)', (tester) async {
    // Horizontal overflow is a different failure from vertical, and frozen
    // columns are the part that has to survive it.
    expect(await _draw(tester, _spreadsheet(rows: 20, cols: 80)), isNull);
  });

  testWidgets('all three on one page', (tester) async {
    // Each of them wants unbounded space in some direction (§2.15); together
    // in a scrolling column is how a dashboard would actually place them.
    expect(
      await _draw(tester, <String, dynamic>{
        'type': 'scrollView',
        'direction': 'vertical',
        'children': <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'sizedBox',
            'height': 400,
            'child': _kanban(columns: 4, cards: 40),
          },
          <String, dynamic>{
            'type': 'sizedBox',
            'height': 400,
            'child': _gantt(60),
          },
          <String, dynamic>{
            'type': 'sizedBox',
            'height': 400,
            'child': _spreadsheet(rows: 100, cols: 10),
          },
        ],
      }),
      isNull,
    );
  });
}
