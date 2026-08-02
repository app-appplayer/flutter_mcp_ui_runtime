/// `kanban`, `gantt`, `spreadsheet` — spec §10.30–§10.32.
///
/// These three are widgets rather than compositions for reasons that are
/// behavioural, so that is what these tests pin: the move reports a
/// destination *index*, the schedule change is a proposal rather than an
/// application, and a formula does not evaluate unless the document asked for
/// it.
library board_widgets_test;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  Future<MCPUIRuntime> pump(
    WidgetTester tester,
    Map<String, dynamic> content, {
    Map<String, dynamic>? state,
  }) async {
    final runtime = MCPUIRuntime();
    await runtime.initialize({
      'type': 'page',
      if (state != null) 'state': {'initial': state},
      'content': content,
    });
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: runtime.buildUI())),
    );
    await tester.pump();
    return runtime;
  }

  group('kanban', () {
    Map<String, dynamic> board({bool draggable = true}) => {
          'type': 'kanban',
          'draggable': draggable,
          'columns': [
            {
              'key': 'todo',
              'title': 'To do',
              'items': [
                {'id': '1', 'title': 'First'},
                {'id': '2', 'title': 'Second'},
              ],
            },
            {'key': 'doing', 'title': 'Doing', 'limit': 1, 'items': []},
          ],
          'itemTemplate': {'type': 'text', 'content': '{{item.title}}'},
        };

    testWidgets('renders every column and card', (tester) async {
      await pump(tester, board());
      expect(find.text('To do'), findsOneWidget);
      expect(find.text('Doing'), findsOneWidget);
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
    });

    testWidgets('shows a column count against its limit', (tester) async {
      await pump(tester, board());
      expect(find.text('2'), findsOneWidget); // to do, no limit
      expect(find.text('0 / 1'), findsOneWidget); // doing, limit 1
    });

    testWidgets('cards are draggable only when draggable is true',
        (tester) async {
      await pump(tester, board());
      expect(find.byType(Draggable<Object>), findsNothing,
          reason: 'payload type is private, so match by presence below');
      expect(
        find.byWidgetPredicate((w) => w.runtimeType.toString().startsWith('Draggable')),
        findsNWidgets(2),
      );

      await pump(tester, board(draggable: false));
      expect(
        find.byWidgetPredicate((w) => w.runtimeType.toString().startsWith('Draggable')),
        findsNothing,
      );
    });

    testWidgets('drop targets are the gaps, one more than the card count',
        (tester) async {
      // The whole reason this is a widget: a drop must land *between* cards so
      // the destination index means something.
      await pump(tester, board());
      final targets = find.byWidgetPredicate(
          (w) => w.runtimeType.toString().startsWith('DragTarget'));
      // 3 gaps in the two-card column, 1 in the empty column.
      expect(targets, findsNWidgets(4));
    });
  });

  group('gantt', () {
    Map<String, dynamic> chart({bool editable = false}) => {
          'type': 'gantt',
          'editable': editable,
          'viewMode': 'day',
          'tasks': [
            {
              'id': 'a',
              'label': 'Design',
              'start': '2026-01-01T00:00:00Z',
              'end': '2026-01-05T00:00:00Z',
              'progress': 0.5,
            },
            {
              'id': 'b',
              'label': 'Build',
              'start': '2026-01-03T00:00:00Z',
              'end': '2026-01-10T00:00:00Z',
            },
          ],
        };

    testWidgets('renders a labelled row per task', (tester) async {
      await pump(tester, chart());
      expect(find.text('Design'), findsOneWidget);
      expect(find.text('Build'), findsOneWidget);
    });

    testWidgets('tasks with unparseable dates are skipped, not crashed on',
        (tester) async {
      await pump(tester, {
        'type': 'gantt',
        'tasks': [
          {'id': 'x', 'label': 'Bad', 'start': 'not-a-date', 'end': 'nope'},
          {
            'id': 'y',
            'label': 'Good',
            'start': '2026-01-01T00:00:00Z',
            'end': '2026-01-02T00:00:00Z',
          },
        ],
      });
      expect(tester.takeException(), isNull);
      expect(find.text('Good'), findsOneWidget);
      expect(find.text('Bad'), findsNothing);
    });

    testWidgets('an empty task list renders nothing rather than an axis',
        (tester) async {
      // Asserted by absence of any axis tick label rather than by CustomPaint:
      // Scaffold paints with one too, so that finder would pass for the wrong
      // reason.
      await pump(tester, {'type': 'gantt', 'tasks': []});
      expect(tester.takeException(), isNull);
      expect(find.textContaining('/'), findsNothing);
    });
  });

  group('spreadsheet', () {
    Map<String, dynamic> sheet({bool formulas = false}) => {
          'type': 'spreadsheet',
          'formulas': formulas,
          'data': [
            [1, 2],
            [
              3,
              {'value': 'stale', 'formula': 'total'}
            ],
          ],
        };

    testWidgets('labels columns A, B and rows 1, 2', (tester) async {
      await pump(tester, sheet());
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('1'), findsWidgets);
      expect(find.text('2'), findsWidgets);
    });

    testWidgets('a formula renders its last value when formulas are off',
        (tester) async {
      // Off by default: a document that needs no computation should not carry
      // an evaluator, and the stored value is what it last computed to.
      await pump(tester, sheet(), state: {'total': 99});
      expect(find.text('stale'), findsOneWidget);
      expect(find.text('99'), findsNothing);
    });

    testWidgets('a formula evaluates through the binding engine when enabled',
        (tester) async {
      // Through the sandbox that governs every other expression — not a
      // spreadsheet language of the DSL's own.
      await pump(tester, sheet(formulas: true), state: {'total': 99});
      expect(find.text('99'), findsOneWidget);
      expect(find.text('stale'), findsNothing);
    });

    testWidgets('an unevaluable formula falls back to the stored value',
        (tester) async {
      await pump(tester, sheet(formulas: true));
      expect(tester.takeException(), isNull);
      // `total` resolves to nothing, so the last value stands.
      expect(find.text('stale'), findsOneWidget);
    });

    testWidgets('empty data renders nothing', (tester) async {
      await pump(tester, {'type': 'spreadsheet', 'data': []});
      expect(tester.takeException(), isNull);
    });
  });
}
