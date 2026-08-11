// The tabular and board family: dataTable, table, spreadsheet, kanban,
// calendar.
//
// Same questions as the chart family. These widgets carry a document's actual
// data, so the failure that matters is the quiet one: a column that renders
// with the wrong label, a sort that never fires, an edit that goes nowhere, a
// day that draws no event. Each test asks what an author would ask after
// writing the property.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  final live = <MCPUIRuntime>[];
  tearDown(() {
    for (final r in live) {
      r.destroy();
    }
    live.clear();
  });

  var seq = 0;

  Future<MCPUIRuntime> pump(
    WidgetTester tester,
    Map<String, dynamic> content, {
    Map<String, dynamic>? initialState,
    Size size = const Size(800, 600),
  }) async {
    // A distinct key per render: without it a second render inside one test
    // reuses the first one's elements and comes back empty.
    final key = ValueKey('page-${seq++}');
    final runtime = MCPUIRuntime();
    live.add(runtime);
    final definition = <String, dynamic>{'type': 'page', 'content': content};
    if (initialState != null) {
      definition['runtime'] = {
        'services': {
          'state': {'initialState': initialState},
        },
      };
    }
    await runtime.initialize(definition);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: size.width,
            height: size.height,
            child: KeyedSubtree(key: key, child: runtime.buildUI()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return runtime;
  }

  group('dataTable', () {
    Map<String, dynamic> table({Map<String, dynamic> extra = const {}}) => {
          'type': 'dataTable',
          'columns': [
            {'key': 'name', 'label': 'Name', 'sortable': true},
            {'key': 'qty', 'label': 'Quantity', 'align': 'end'},
          ],
          'rows': [
            {'name': 'Bolt', 'qty': 12},
            {'name': 'Nut', 'qty': 3},
          ],
          ...extra,
        };

    testWidgets('the declared labels and cells are what is drawn',
        (tester) async {
      await pump(tester, table());
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Quantity'), findsOneWidget,
          reason: 'the column header printed the key instead of the label');
      expect(find.text('Bolt'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('rows fed from state are drawn', (tester) async {
      await pump(
        tester,
        table(extra: {'rows': '{{items}}'}),
        initialState: {
          'items': [
            {'name': 'FromState', 'qty': 1},
          ],
        },
      );
      expect(find.text('FromState'), findsOneWidget);
    });

    testWidgets('onSort fires with the column and direction', (tester) async {
      final runtime = await pump(
        tester,
        table(extra: {
          'onSort': {
            'type': 'state',
            'action': 'set',
            'binding': 'sorted',
            'value': '{{event.column}}:{{event.ascending}}',
          },
        }),
        initialState: {'sorted': ''},
      );
      await tester.tap(find.text('Name'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(runtime.stateManager.get<String>('sorted'), startsWith('name:'),
          reason: 'a sortable column that reports nothing cannot be sorted '
              'by the document');
    });

    testWidgets('onRowTap says which row', (tester) async {
      final runtime = await pump(
        tester,
        table(extra: {
          'onRowTap': {
            'type': 'state',
            'action': 'set',
            'binding': 'tapped',
            'value': '{{event.row.name}}',
          },
        }),
        initialState: {'tapped': ''},
      );
      await tester.tap(find.text('Bolt'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(runtime.stateManager.get<String>('tapped'), 'Bolt');
    });

    testWidgets('sortColumn and sortAscending decide the initial order',
        (tester) async {
      await pump(
        tester,
        table(extra: {'sortColumn': 'qty', 'sortAscending': true}),
      );
      final ascendingFirst = tester.getCenter(find.text('Nut')).dy;
      final ascendingSecond = tester.getCenter(find.text('Bolt')).dy;
      expect(ascendingFirst, lessThan(ascendingSecond),
          reason: 'qty ascending puts 3 above 12');

      await pump(
        tester,
        table(extra: {'sortColumn': 'qty', 'sortAscending': false}),
      );
      expect(tester.getCenter(find.text('Bolt')).dy,
          lessThan(tester.getCenter(find.text('Nut')).dy),
          reason: 'sortAscending: false was ignored');
    });

    testWidgets('editable cells report the edit through onCellEdit',
        (tester) async {
      final runtime = await pump(
        tester,
        table(extra: {
          // `virtualScroll` puts the rows through the widget's own body
          // renderer, which is where editing lives.
          'virtualScroll': true,
          'editable': true,
          'onCellEdit': {
            'type': 'state',
            'action': 'set',
            'binding': 'edit',
            'value': '{{event.column}}={{event.value}} was {{event.previous}}',
          },
        }),
        initialState: {'edit': ''},
      );

      final field = find.byType(TextFormField).first;
      expect(field, findsOneWidget,
          reason: 'editable: true offered no editable cell');
      await tester.enterText(field, 'Screw');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 300));
      expect(runtime.stateManager.get<String>('edit'),
          'name=Screw was Bolt',
          reason: 'the edit must say what changed and what it was');
    });

    testWidgets('a row missing the sort column sinks, whichever way it sorts',
        (tester) async {
      Map<String, dynamic> withGap({required bool ascending}) => table(extra: {
            'sortColumn': 'qty',
            'sortAscending': ascending,
            'rows': [
              {'name': 'Bolt', 'qty': 12},
              {'name': 'Missing'},
              {'name': 'Nut', 'qty': 3},
            ],
          });

      await pump(tester, withGap(ascending: true));
      expect(tester.getCenter(find.text('Missing')).dy,
          lessThan(tester.getCenter(find.text('Nut')).dy),
          reason: 'a live feed carries gaps; comparing null against a number '
              'throws, and catching that would drop the sort entirely');

      await pump(tester, withGap(ascending: false));
      expect(tester.getCenter(find.text('Missing')).dy,
          greaterThan(tester.getCenter(find.text('Bolt')).dy),
          reason: 'the gap goes to the other end when the direction flips, '
              'the same as every other value');
    });

    testWidgets('mixed types are compared as text rather than throwing',
        (tester) async {
      await pump(
        tester,
        table(extra: {
          'sortColumn': 'qty',
          'sortAscending': true,
          'rows': [
            {'name': 'Bolt', 'qty': 12},
            {'name': 'Text', 'qty': '3 pallets'},
          ],
        }),
      );

      expect(find.text('Bolt'), findsOneWidget);
      expect(find.text('Text'), findsOneWidget,
          reason: 'a column that is a number for most rows and a string for '
              'one is what a live feed produces; throwing there takes the '
              'whole table down');
    });

    testWidgets('a virtual-scrolled table still draws its rows and filters',
        (tester) async {
      await pump(
        tester,
        table(extra: {
          'virtualScroll': true,
          'filterable': true,
          'rowHeight': 40,
        }),
      );

      expect(find.text('Bolt'), findsOneWidget,
          reason: 'the hand-laid grid is a second renderer for the same data; '
              'a table that scrolls and shows nothing is the failure it was '
              'added to avoid');
      expect(find.byType(TextField), findsWidgets,
          reason: 'a filter row that is declared and not drawn leaves the '
              'user with no way to narrow a long table');
    });

    testWidgets('a row tap in the virtual-scrolled grid reports the row too',
        (tester) async {
      final runtime = await pump(
        tester,
        table(extra: {
          'virtualScroll': true,
          'rowHeight': 40,
          'onRowTap': {
            'type': 'state',
            'action': 'set',
            'binding': 'picked',
            'value': '{{event.row.name}}',
          },
        }),
      );

      await tester.tap(find.text('Nut'));
      await tester.pumpAndSettle();

      expect(runtime.stateManager.get<String>('picked'), 'Nut',
          reason: 'the same document works on both renderers, so a tap that '
              'reports on one and not the other is a table that behaves '
              'differently depending on a performance flag');
    });

    testWidgets('selectable offers a selection control', (tester) async {
      await pump(tester, table(extra: {'selectable': true}));
      expect(find.byType(Checkbox), findsWidgets,
          reason: 'selectable: true with nothing to select is a no-op');
    });
  });

  group('spreadsheet', () {
    testWidgets('cells, headers and a formula all reach the grid',
        (tester) async {
      // §10.32 is explicit that a formula is a runtime expression under the
      // §7.1 sandbox, not a spreadsheet language of the DSL's own — so this
      // is what a formula looks like, and an unevaluable one must render its
      // last value rather than being interpreted loosely.
      await pump(tester, {
        'type': 'spreadsheet',
        'columnHeaders': true,
        'rowHeaders': true,
        'formulas': true,
        'data': [
          [
            {'value': 2},
            {'value': 3},
          ],
          [
            {'formula': '2 + 3'},
            {'value': 7, 'formula': 'not an expression'},
          ],
        ],
      });
      expect(find.text('2'), findsWidgets);
      expect(find.text('A'), findsWidgets,
          reason: 'columnHeaders: true drew no column gutter');
      expect(find.text('5'), findsOneWidget,
          reason: 'formulas: true and `2 + 3` shows something other than 5');
      expect(find.text('7'), findsOneWidget,
          reason: 'an unevaluable formula must fall back to the last value, '
              'not print the formula or blank the cell');
    });

    testWidgets('formulas: false leaves the value alone', (tester) async {
      await pump(tester, {
        'type': 'spreadsheet',
        'formulas': false,
        'data': [
          [
            {'value': 9, 'formula': '2 + 3'},
          ],
        ],
      });
      expect(find.text('9'), findsOneWidget);
      expect(find.text('5'), findsNothing,
          reason: 'evaluation is off by default and was performed anyway');
    });

    testWidgets('onCellSelect reports the cell', (tester) async {
      final runtime = await pump(
        tester,
        {
          'type': 'spreadsheet',
          'data': [
            [
              {'value': 1},
              {'value': 2},
            ],
          ],
          'onCellSelect': {
            'type': 'state',
            'action': 'set',
            'binding': 'cell',
            'value': '{{event.row}}:{{event.column}}',
          },
        },
        initialState: {'cell': ''},
      );
      await tester.tap(find.text('2'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(runtime.stateManager.get<String>('cell'), '0:1');
    });
  });

  group('table', () {
    testWidgets('columnWidths sizes the column it names', (tester) async {
      Map<String, dynamic> layout(Object first) => {
            'type': 'table',
            'columnWidths': {'0': first, '1': 'flex'},
            'rows': [
              {
                'cells': [
                  {'type': 'text', 'text': 'left'},
                  {'type': 'text', 'text': 'right'},
                ],
              },
            ],
          };
      await pump(tester, layout(120));
      final narrow = tester.getCenter(find.text('right')).dx;
      await pump(tester, layout(400));
      final wide = tester.getCenter(find.text('right')).dx;
      expect(wide, greaterThan(narrow + 100),
          reason: 'the declared column width was ignored — a bare number fell '
              'through to flex');
    });
  });

  group('kanban', () {
    Map<String, dynamic> board({Map<String, dynamic> extra = const {}}) => {
          'type': 'kanban',
          'itemTemplate': {
            'type': 'text',
            'content': '{{item.title}}',
          },
          'columns': [
            {
              'key': 'todo',
              'title': 'To do',
              'items': [
                {'id': '1', 'title': 'Write spec'},
              ],
            },
            {
              'key': 'done',
              'title': 'Done',
              'items': [
                {'id': '2', 'title': 'Ship it'},
              ],
            },
          ],
          ...extra,
        };

    testWidgets('columns and their cards are drawn', (tester) async {
      await pump(tester, board());
      expect(find.text('To do'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Write spec'), findsOneWidget);
      expect(find.text('Ship it'), findsOneWidget);
    });

    testWidgets('onCardClick reports the card', (tester) async {
      final runtime = await pump(
        tester,
        board(extra: {
          'onCardClick': {
            'type': 'state',
            'action': 'set',
            'binding': 'clicked',
            'value': '{{event.item.title}}',
          },
        }),
        initialState: {'clicked': ''},
      );
      await tester.tap(find.text('Write spec'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(runtime.stateManager.get<String>('clicked'), 'Write spec');
    });

    testWidgets('dragging a card to another column moves it and reports the '
        'move', (tester) async {
      final runtime = await pump(
        tester,
        board(extra: {
          'draggable': true,
          'optimistic': true,
          'onCardMove': {
            'type': 'state',
            'action': 'set',
            'binding': 'moved',
            'value': '{{event}}',
          },
        }),
        initialState: {'moved': null},
      );

      final card = find.text('Write spec');
      final target = find.text('Ship it');
      expect(card, findsOneWidget);

      final gesture =
          await tester.startGesture(tester.getCenter(card));
      await tester.pump(const Duration(milliseconds: 400));
      // The drop zones are the thin gaps between cards, so the drop lands
      // just below the card in the destination column rather than on it.
      await gesture.moveTo(tester.getCenter(target) + const Offset(0, 14));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(target) + const Offset(0, 16));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      final moved = runtime.stateManager.get<dynamic>('moved');
      expect(moved, isNotNull,
          reason: 'the move is the only thing the document can persist; a '
              'board that rearranges itself and tells nobody loses the change '
              'on the next load');
      expect((moved as Map)['to']['column'], 'done',
          reason: 'the destination is the whole point of the event');
      expect(moved['from']['column'], 'todo');
      expect(moved['item']['title'], 'Write spec');
      expect(moved['type'], 'cardMove');

      // `optimistic` means the board shows the move before the document
      // confirms it — the card has to be in its new column already.
      expect(find.text('Write spec'), findsOneWidget);
    });

    testWidgets('columnWidth is the width the columns take', (tester) async {
      await pump(tester, board(extra: {'columnWidth': 320}));
      final wide = tester.getSize(find.ancestor(
        of: find.text('To do'),
        matching: find.byType(SizedBox),
      ).first);
      expect(wide.width, closeTo(320, 24),
          reason: 'the declared column width was ignored');
    });

    testWidgets('a board fed from state is drawn', (tester) async {
      await pump(
        tester,
        {
          'type': 'kanban',
          'itemTemplate': {'type': 'text', 'content': '{{item.title}}'},
          'columns': '{{board}}',
        },
        initialState: {
          'board': [
            {
              'key': 'todo',
              'title': 'Backlog',
              'items': [
                {'id': '9', 'title': 'From state'},
              ],
            },
          ],
        },
      );
      expect(find.text('Backlog'), findsOneWidget);
      expect(find.text('From state'), findsOneWidget);
    });
  });

  group('calendar', () {
    testWidgets('a declared event is marked on its day', (tester) async {
      await pump(tester, {
        'type': 'calendar',
        'selectedDate': '2026-03-10',
        'eventColor': '#FF0000',
        'events': [
          {'date': '2026-03-12', 'title': 'Review'},
        ],
      });
      // The day itself must be there, and something must mark it: a calendar
      // that accepts events and draws a plain month is the silence §6.13.1
      // forbids.
      expect(find.text('12'), findsOneWidget);
      final marks = find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color == const Color(0xFFFF0000));
      expect(marks, findsWidgets,
          reason: 'the declared eventColor never appeared');
    });

    testWidgets('showHeader and showWeekNumbers decide what is drawn',
        (tester) async {
      await pump(tester, {
        'type': 'calendar',
        'selectedDate': '2026-03-10',
        'showWeekNumbers': true,
      });
      expect(find.textContaining('March'), findsWidgets,
          reason: 'the header is on by default');

      await pump(tester, {
        'type': 'calendar',
        'selectedDate': '2026-03-10',
        'showHeader': false,
      });
      expect(find.textContaining('March'), findsNothing,
          reason: 'showHeader: false still drew the month header');
    });

    testWidgets('tapping a day reports it', (tester) async {
      final runtime = await pump(
        tester,
        {
          'type': 'calendar',
          'selectedDate': '2026-03-10',
          'onChange': {
            'type': 'state',
            'action': 'set',
            'binding': 'picked',
            'value': '{{event.value}}',
          },
        },
        initialState: {'picked': ''},
      );
      await tester.tap(find.text('17'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(runtime.stateManager.get<String>('picked') ?? '',
          contains('2026-03-17'),
          reason: 'a calendar whose taps report nothing cannot drive a page');
    });

    testWidgets('the whole month is laid out, not the part that fits',
        (tester) async {
      await pump(tester, {
        'type': 'calendar',
        'selectedDate': '2026-03-10',
      });
      expect(find.text('31'), findsOneWidget,
          reason: 'square cells made the grid taller than any box it is given, '
              'so the month ended wherever the scroll did');
    });

    testWidgets('a month beginning on the week start has no leading week',
        (tester) async {
      // 1 March 2026 is a Sunday. With the week starting on Sunday the grid
      // opens on the 1st; the old code mixed Dart weekdays (Monday 1, Sunday
      // 7) with the spec's numbering (Sunday 0) and pushed seven cells of
      // February in front of it.
      await pump(tester, {
        'type': 'calendar',
        'selectedDate': '2026-03-10',
        'firstDayOfWeek': 0,
      });
      final firstOfMarch = tester.getCenter(find.text('1').first).dx;
      final fifteenth = tester.getCenter(find.text('15')).dx;
      expect(firstOfMarch, closeTo(fifteenth, 1),
          reason: 'the 1st and the 15th are both Sundays and must share a '
              'column');
      expect(find.text('28'), findsOneWidget,
          reason: 'a leading week of February puts a second 28 on the grid');
    });

    testWidgets('firstDayOfWeek moves the columns', (tester) async {
      await pump(tester, {
        'type': 'calendar',
        'selectedDate': '2026-03-10',
        'firstDayOfWeek': 0,
      });
      // The 15th, not the 1st: a month grid also shows the neighbouring
      // months' 1st, and a finder that matches two cells measures neither.
      // 15 March 2026 is a Sunday, so it moves from the first column to the
      // last when the week starts on Monday.
      final sundayFirst = tester.getCenter(find.text('15')).dx;

      await pump(tester, {
        'type': 'calendar',
        'selectedDate': '2026-03-10',
        'firstDayOfWeek': 1,
      });
      final mondayFirst = tester.getCenter(find.text('15')).dx;
      expect(mondayFirst, greaterThan(sundayFirst + 100),
          reason: 'the first day of the week was declared and ignored');
    });
  });
}
