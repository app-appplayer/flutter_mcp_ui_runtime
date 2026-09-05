// Findings measured on real documents, each with the property that a
// document could declare, and the effect it would ask for.
//
// A `dataTable` that says `editable` has editable cells on whatever render
// path it takes, and keeps its sort tap and its column alignment there. A
// `gantt` that says `showDependencies` draws them. A `tree` that says
// `draggable` lets a group be dragged and dropped into. A `calendar` reports
// an ISO date, as its own `events[].date` is written.

import 'dart:ui' as ui;

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
  }) async {
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
        home: Scaffold(body: KeyedSubtree(key: key, child: runtime.buildUI())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    return runtime;
  }

  /// The editable cell at [row], [column] of the hand-laid grid — by
  /// position, the way a finger finds it. Fields are laid out row-major.
  Finder cellField(WidgetTester tester,
          {required int row, required int column, int perRow = 3}) =>
      find.byType(TextFormField).at(row * perRow + column);

  Map<String, dynamic> table({
    bool editable = true,
    bool virtualScroll = false,
    Map<String, dynamic>? onSort,
    Map<String, dynamic>? onCellEdit,
    String? sortColumn,
  }) =>
      {
        'type': 'dataTable',
        'columns': [
          {'key': 'item', 'label': 'Item', 'sortable': true},
          {'key': 'qty', 'label': 'Qty', 'align': 'center'},
          {'key': 'rate', 'label': 'Rate', 'align': 'end'},
        ],
        'rows': [
          {'item': 'Carcass', 'qty': '12', 'rate': '480'},
          {'item': 'Hood', 'qty': '1', 'rate': '1900'},
        ],
        'editable': editable,
        if (virtualScroll) 'virtualScroll': true,
        if (virtualScroll) 'rowHeight': 46,
        if (sortColumn != null) 'sortColumn': sortColumn,
        if (onSort != null) 'onSort': onSort,
        if (onCellEdit != null) 'onCellEdit': onCellEdit,
      };

  group('dataTable editable on the default render path', () {
    testWidgets('editable alone gives editable cells', (tester) async {
      await pump(tester, table());
      // Six cells, six fields — not a Material DataTable of plain text.
      expect(find.byType(TextFormField), findsNWidgets(6));
      expect(find.byType(DataTable), findsNothing);
    });

    testWidgets(
        'a committed edit fires onCellEdit with row, column, value, previous',
        (tester) async {
      final runtime = await pump(
        tester,
        table(onCellEdit: {
          'type': 'state',
          'action': 'set',
          'binding': 'edit',
          'value': '{{event.column}}:{{event.previous}}>{{event.value}}',
        }),
        initialState: {'edit': ''},
      );
      final field = cellField(tester, row: 0, column: 1);
      await tester.enterText(field, '14');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 100));
      expect(runtime.stateManager.get<String>('edit'), 'qty:12>14');
    });

    testWidgets('a sortable header still sorts when the table is editable',
        (tester) async {
      final runtime = await pump(
        tester,
        table(
          sortColumn: 'item',
          onSort: {
            'type': 'state',
            'action': 'set',
            'binding': 'sort',
            'value': '{{event.column}}:{{event.ascending}}',
          },
        ),
        initialState: {'sort': ''},
      );
      await tester.tap(find.text('Item'));
      await tester.pump(const Duration(milliseconds: 100));
      // The item column is already the sort column, ascending, so the tap
      // toggles — the same rule DataTable applies.
      expect(runtime.stateManager.get<String>('sort'), 'item:false');
    });

    testWidgets('a header that is not sortable does nothing', (tester) async {
      final runtime = await pump(
        tester,
        table(onSort: {
          'type': 'state',
          'action': 'set',
          'binding': 'sort',
          'value': 'fired',
        }),
        initialState: {'sort': ''},
      );
      await tester.tap(find.text('Qty'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(runtime.stateManager.get<String>('sort'), '');
    });

    testWidgets('columns[].align reaches the editable grid', (tester) async {
      await pump(tester, table());
      TextAlign alignOf(int column) => tester
          .widget<EditableText>(find.descendant(
            of: cellField(tester, row: 0, column: column),
            matching: find.byType(EditableText),
          ))
          .textAlign;
      expect(alignOf(0), TextAlign.start);
      expect(alignOf(1), TextAlign.center);
      expect(alignOf(2), TextAlign.end);
    });

    testWidgets('columns[].align reaches the non-editable grid too',
        (tester) async {
      await pump(tester, table(editable: false, virtualScroll: true));
      final centered = find.ancestor(
        of: find.text('12'),
        matching: find.byWidgetPredicate(
            (w) => w is Align && w.alignment == Alignment.center),
      );
      expect(centered, findsOneWidget);
    });

    testWidgets('an editable table without virtualScroll lays out every row',
        (tester) async {
      await pump(tester, {
        ...table(),
        'rows': [
          for (var i = 0; i < 9; i++)
            {'item': 'Line $i', 'qty': '$i', 'rate': '1'},
        ],
      });
      // No inner list viewport: every row is materialised, as a DataTable's
      // would be — the document decides how the table scrolls.
      expect(find.byType(ListView), findsNothing);
      expect(find.byType(TextFormField), findsNWidgets(27));
    });
  });

  group('dataTable sort then edit', () {
    // The finding measured on 0.7.8 before it went out: after a header tap
    // re-sorted the data, the fields kept the text they were built with and
    // an edit reported the row now at that position — one row on screen,
    // another in the event.
    Map<String, dynamic> sortable() => {
          'type': 'dataTable',
          'columns': [
            {'key': 'item', 'label': 'Item', 'sortable': true},
            {'key': 'amount', 'label': 'Amount', 'sortable': true},
          ],
          'rows': [
            {'item': 'Demolition', 'amount': 900},
            {'item': 'Electrical', 'amount': 100},
            {'item': 'Tiling', 'amount': 500},
          ],
          'editable': true,
          'sortColumn': '{{sortColumn}}',
          'sortAscending': true,
          'onSort': {
            'type': 'state',
            'action': 'set',
            'binding': 'sortColumn',
            'value': '{{event.column}}',
          },
          'onCellEdit': {
            'type': 'state',
            'action': 'set',
            'binding': 'edit',
            'value': '{{event.row.item}}:{{event.previous}}>{{event.value}}',
          },
        };

    testWidgets('the rows on screen reorder, and the field follows its row',
        (tester) async {
      final runtime = await pump(tester, sortable(),
          initialState: {'sortColumn': '', 'edit': ''});
      String textAt(int row, int column) => tester
          .widget<EditableText>(find.descendant(
            of: cellField(tester, row: row, column: column, perRow: 2),
            matching: find.byType(EditableText),
          ))
          .controller
          .text;
      expect(textAt(0, 0), 'Demolition');

      await tester.tap(find.text('Amount'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(runtime.stateManager.get<String>('sortColumn'), 'amount');
      // Ascending by amount: Electrical 100, Tiling 500, Demolition 900.
      expect(textAt(0, 0), 'Electrical');
      expect(textAt(0, 1), '100');
      expect(textAt(2, 0), 'Demolition');

      // Editing the field now at the top reports the row that is there.
      await tester.enterText(
          cellField(tester, row: 0, column: 1, perRow: 2), '120');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 100));
      expect(runtime.stateManager.get<String>('edit'), 'Electrical:100>120');
      expect(textAt(0, 1), '120',
          reason: 'the typed number stays in the line it was typed in');
    });
  });

  group('dataTable sort compares numbers as numbers', () {
    testWidgets('an int and a double in one column sort numerically',
        (tester) async {
      await pump(
        tester,
        {
          'type': 'dataTable',
          'columns': [
            {'key': 'item', 'label': 'Item'},
            {'key': 'amount', 'label': 'Amount', 'sortable': true},
          ],
          'rows': [
            {'item': 'Carcasses', 'amount': 2160},
            {'item': 'Tiling', 'amount': 617.5},
            {'item': 'Demolition', 'amount': 1302},
            {'item': 'Paint', 'amount': 240},
          ],
          'editable': true,
          'sortColumn': 'amount',
          'sortAscending': true,
        },
      );
      String textAt(int row) => tester
          .widget<EditableText>(find.descendant(
            of: cellField(tester, row: row, column: 0, perRow: 2),
            matching: find.byType(EditableText),
          ))
          .controller
          .text;
      expect([
        for (var r = 0; r < 4; r++) textAt(r)
      ], [
        'Paint',
        'Tiling',
        'Demolition',
        'Carcasses'
      ], reason: '617.5 sorted last: the int/double pair compared as strings');
    });
  });

  group('kanban optimistic move', () {
    Map<String, dynamic> board({bool optimistic = true}) => {
          'type': 'kanban',
          'columns': '{{board}}',
          'itemKey': 'id',
          'optimistic': optimistic,
          'itemTemplate': {'type': 'text', 'content': '{{item.title}}'},
          'onCardMove': {
            'type': 'state',
            'action': 'set',
            'binding': 'planMove',
            'value':
                '{{event.item.title}}: {{event.from.column}} #{{event.from.index}} -> {{event.to.column}} #{{event.to.index}}',
          },
        };
    List<Map<String, dynamic>> columns() => [
          {
            'key': 'todo',
            'title': 'To do',
            'items': [
              {'id': 'g', 'title': 'Order glass'},
              {'id': 'h', 'title': 'Hang doors'},
            ],
          },
          {
            'key': 'doing',
            'title': 'In progress',
            'items': [
              {'id': 'c', 'title': 'Carcasses'},
            ],
          },
        ];

    /// The column a card's text currently sits in, by x position.
    String columnOf(WidgetTester tester, String text) {
      final x = tester.getCenter(find.text(text)).dx;
      final todo = tester.getCenter(find.text('To do')).dx;
      final doing = tester.getCenter(find.text('In progress')).dx;
      return (x - todo).abs() < (x - doing).abs() ? 'todo' : 'doing';
    }

    Future<void> dragTo(WidgetTester tester, String text, Offset to) async {
      final gesture =
          await tester.startGesture(tester.getCenter(find.text(text)));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(to);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('the placement survives the state write the report makes',
        (tester) async {
      final runtime = await pump(tester, board(),
          initialState: {'board': columns(), 'planMove': ''});
      expect(columnOf(tester, 'Order glass'), 'todo');
      // Onto the gap above the first card of In progress.
      final target =
          tester.getTopLeft(find.text('Carcasses')) + const Offset(20, -6);
      await dragTo(tester, 'Order glass', target);
      expect(runtime.stateManager.get<String>('planMove'),
          'Order glass: todo #0 -> doing #0');
      await tester.pump(const Duration(seconds: 1));
      expect(columnOf(tester, 'Order glass'), 'doing',
          reason: 'the state write rebuilt the page and the optimistic '
              'placement was reset to the unchanged bound data');
    });

    testWidgets('changed data replaces the placement', (tester) async {
      final runtime = await pump(tester, board(),
          initialState: {'board': columns(), 'planMove': ''});
      final target =
          tester.getTopLeft(find.text('Carcasses')) + const Offset(20, -6);
      await dragTo(tester, 'Order glass', target);
      expect(columnOf(tester, 'Order glass'), 'doing');
      // The server answers with its truth — different data: the move was
      // refused and a card was added meanwhile. Identical data would be
      // "nothing changed", and the placement would stand; a document that
      // wants a refusal to show sends the data the server holds.
      final truth = columns();
      (truth[1]['items'] as List).add({'id': 'p', 'title': 'Paint'});
      runtime.stateManager.set('board', truth);
      await tester.pump(const Duration(milliseconds: 100));
      expect(columnOf(tester, 'Order glass'), 'todo');
      expect(find.text('Paint'), findsOneWidget);
    });

    testWidgets('without optimistic the board waits for the data',
        (tester) async {
      await pump(tester, board(optimistic: false),
          initialState: {'board': columns(), 'planMove': ''});
      final target =
          tester.getTopLeft(find.text('Carcasses')) + const Offset(20, -6);
      await dragTo(tester, 'Order glass', target);
      expect(columnOf(tester, 'Order glass'), 'todo');
    });

    testWidgets('a drop on a card body lands after it by the lower half',
        (tester) async {
      final runtime = await pump(tester, board(),
          initialState: {'board': columns(), 'planMove': ''});
      final card = tester.getRect(find.text('Carcasses'));
      await dragTo(
          tester, 'Order glass', Offset(card.center.dx, card.bottom - 1));
      expect(runtime.stateManager.get<String>('planMove'),
          'Order glass: todo #0 -> doing #1');
    });

    testWidgets('a drop on a card body lands before it by the upper half',
        (tester) async {
      final runtime = await pump(tester, board(),
          initialState: {'board': columns(), 'planMove': ''});
      final card = tester.getRect(find.text('Carcasses'));
      await dragTo(tester, 'Order glass', Offset(card.center.dx, card.top + 1));
      expect(runtime.stateManager.get<String>('planMove'),
          'Order glass: todo #0 -> doing #0');
    });

    testWidgets('a drop in the space below the last card appends',
        (tester) async {
      final runtime = await pump(tester, board(),
          initialState: {'board': columns(), 'planMove': ''});
      final card = tester.getRect(find.text('Carcasses'));
      await dragTo(
          tester, 'Order glass', Offset(card.center.dx, card.bottom + 120));
      expect(runtime.stateManager.get<String>('planMove'),
          'Order glass: todo #0 -> doing #1');
    });
  });

  group('gantt axis labels', () {
    Finder axis() => find.byWidgetPredicate((w) =>
        w is CustomPaint && w.painter.runtimeType.toString() == '_AxisPainter');

    Map<String, dynamic> chart(String viewMode) => {
          'type': 'gantt',
          'viewMode': viewMode,
          'showDependencies': false,
          'tasks': [
            {
              'id': 'a',
              'label': 'A',
              'start': '2026-09-01T00:00:00',
              'end': '2026-09-04T00:00:00'
            },
          ],
        };

    testWidgets('a day label is centred in its cell, over the bar it dates',
        (tester) async {
      await pump(tester, chart('day'));
      // Cells are 40 px wide; the first label's centre sits at 20.
      expect(
        axis(),
        paints
          ..something((method, args) {
            if (method != #drawParagraph) return false;
            final paragraph = args[0] as ui.Paragraph;
            final offset = args[1] as Offset;
            final centre = offset.dx + paragraph.longestLine / 2;
            return (centre - 20).abs() < 1.5;
          }),
      );
    });

    testWidgets('an hour label sits beside its tick, and reads the hour',
        (tester) async {
      await pump(tester, chart('hour'));
      expect(
        axis(),
        paints
          ..something((method, args) =>
              method == #drawParagraph && (args[1] as Offset).dx == 2),
      );
    });
  });

  group('gantt dependencies', () {
    Map<String, dynamic> plan({bool showDependencies = true}) => {
          'type': 'gantt',
          'viewMode': 'day',
          'showDependencies': showDependencies,
          'tasks': [
            {
              'id': 'a',
              'label': 'Carcasses',
              'start': '2026-09-01',
              'end': '2026-09-04',
              'progress': 0.3
            },
            {
              'id': 'b',
              'label': 'Doors',
              'start': '2026-09-05',
              'end': '2026-09-08',
              'dependsOn': ['a']
            },
            {
              'id': 'c',
              'label': 'Hood',
              'start': '2026-09-03',
              'end': '2026-09-06',
              'dependsOn': ['a']
            },
          ],
        };

    Finder arrows() => find.byWidgetPredicate((w) =>
        w is CustomPaint &&
        w.painter.runtimeType.toString() == '_DependencyPainter');

    testWidgets('showDependencies draws a dependency layer', (tester) async {
      await pump(tester, plan());
      expect(arrows(), findsOneWidget);
    });

    testWidgets('showDependencies: false draws none', (tester) async {
      await pump(tester, plan(showDependencies: false));
      expect(arrows(), findsNothing);
    });

    testWidgets('the layer does not intercept a bar tap', (tester) async {
      final runtime = await pump(
        tester,
        {
          ...plan(),
          'onTaskClick': {
            'type': 'state',
            'action': 'set',
            'binding': 'clicked',
            'value': '{{event.id}}',
          },
        },
        initialState: {'clicked': ''},
      );
      // The bar's row is the row of its label; tap in the chart column.
      final labelY = tester.getCenter(find.text('Doors')).dy;
      final chart = tester.getRect(arrows());
      await tester.tapAt(Offset(chart.left + chart.width * 0.6, labelY));
      await tester.pump(const Duration(milliseconds: 100));
      expect(runtime.stateManager.get<String>('clicked'), 'b');
    });

    testWidgets('the progress fill is the bar colour; the remainder is lighter',
        (tester) async {
      await pump(tester, {
        ...plan(),
        'tasks': [
          {
            'id': 'a',
            'label': 'Only',
            'start': '2026-09-01',
            'end': '2026-09-04',
            'progress': 0.3,
            'color': '#FF0000'
          },
        ],
      });
      final fill = tester
          .widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
      expect(fill.widthFactor, 0.3);
      final inner = fill.child! as Container;
      final innerColor = (inner.decoration! as BoxDecoration).color!;
      final outer = tester.widget<Container>(find
          .ancestor(
            of: find.byType(FractionallySizedBox),
            matching: find.byType(Container),
          )
          .first);
      final outerColor = (outer.decoration! as BoxDecoration).color!;
      expect(innerColor, const Color(0xFFFF0000),
          reason: 'done is the bar colour');
      expect(outerColor.computeLuminance(),
          greaterThan(innerColor.computeLuminance()),
          reason: 'the remainder is the lighter tint');
    });
  });

  group('tree groups drag and receive drops', () {
    Map<String, dynamic> tree(Map<String, dynamic> onDrop) => {
          'type': 'tree',
          'draggable': true,
          'initiallyExpanded': true,
          'data': [
            {
              'id': 'cabinet',
              'label': 'Cabinet run',
              'children': [
                {'id': 'carcasses', 'label': 'Carcasses'},
              ],
            },
            {'id': 'hood', 'label': 'Extractor hood'},
          ],
          'onDrop': onDrop,
        };

    const report = {
      'type': 'state',
      'action': 'set',
      'binding': 'moved',
      'value': '{{event.item.id}}->{{event.target.id}}:{{event.position}}',
    };

    Future<void> drag(WidgetTester tester, Finder from, Offset to) async {
      final gesture = await tester.startGesture(tester.getCenter(from));
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(to);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('a leaf dropped on a group lands inside it', (tester) async {
      final runtime =
          await pump(tester, tree(report), initialState: {'moved': ''});
      await drag(tester, find.text('Extractor hood'),
          tester.getCenter(find.text('Cabinet run')));
      expect(runtime.stateManager.get<String>('moved'), 'hood->cabinet:inside',
          reason:
              'the expandable row was not a drop target; reparenting was unreachable');
    });

    testWidgets('a group can be dragged', (tester) async {
      final runtime =
          await pump(tester, tree(report), initialState: {'moved': ''});
      await drag(tester, find.text('Cabinet run'),
          tester.getCenter(find.text('Extractor hood')));
      expect(runtime.stateManager.get<String>('moved'),
          startsWith('cabinet->hood:'));
    });

    testWidgets('the drop edge is measured against the target row',
        (tester) async {
      final runtime =
          await pump(tester, tree(report), initialState: {'moved': ''});
      final row = tester.getRect(find.text('Cabinet run'));
      // The pointer decides the edge: the top of the target row reads as
      // `before`, the middle as `inside`.
      await drag(tester, find.text('Extractor hood'),
          Offset(row.center.dx, row.top + 2));
      expect(runtime.stateManager.get<String>('moved'), 'hood->cabinet:before');
    });

    testWidgets('a group cannot be dropped into its own subtree',
        (tester) async {
      final runtime =
          await pump(tester, tree(report), initialState: {'moved': ''});
      await drag(tester, find.text('Cabinet run'),
          tester.getCenter(find.text('Carcasses')));
      expect(runtime.stateManager.get<String>('moved'), '');
    });
  });

  group('calendar reports an ISO date', () {
    testWidgets('onChange event.value has no time component', (tester) async {
      final runtime = await pump(
        tester,
        {
          'type': 'calendar',
          'selectedDate': '2026-09-01',
          'onChange': {
            'type': 'state',
            'action': 'set',
            'binding': 'picked',
            'value': '{{event.value}}',
          },
        },
        initialState: {'picked': ''},
      );
      await tester.tap(find.text('18').first);
      await tester.pump(const Duration(milliseconds: 100));
      expect(runtime.stateManager.get<String>('picked'), '2026-09-18');
    });
  });
}
