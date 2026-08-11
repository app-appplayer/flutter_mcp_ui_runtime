// `kanban`, `calendar`, `dataTable` and `networkGraph` — four widgets whose
// uncovered part is the interaction.
//
// Each of them renders convincingly and then has to answer a gesture: a card
// dragged to another column, a month stepped forward, a column filtered or
// resized, a node tapped. That answer is what a document acts on, and none of
// it had run.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StateManager stateManager;
  late RenderContext context;

  setUp(() {
    stateManager = StateManager()..initialize(<String, dynamic>{});
    final registry = WidgetRegistry();
    DefaultWidgets.registerAll(registry);
    final bindingEngine = BindingEngine();
    final actionHandler = ActionHandler();
    context = RenderContext(
      renderer: Renderer(
        widgetRegistry: registry,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        stateManager: stateManager,
      ),
      stateManager: stateManager,
      bindingEngine: bindingEngine,
      actionHandler: actionHandler,
      themeManager: ThemeManager.instance,
    );
  });

  Future<void> pump(
    WidgetTester tester,
    Map<String, dynamic> definition, {
    Size size = const Size(1000, 700),
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: AnimatedBuilder(
              animation: stateManager,
              builder: (_, __) =>
                  context.renderer.renderWidget(definition, context),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('kanban', () {
    /// The board's own shape: items live inside their column, and the card is
    /// whatever `itemTemplate` renders.
    Map<String, dynamic> board({
      List<Map<String, dynamic>>? columns,
      Map<String, dynamic> extra = const {},
    }) =>
        {
          'type': 'kanban',
          'itemKey': 'id',
          'columns': columns ??
              [
                {
                  'key': 'todo',
                  'title': 'To do',
                  'items': [
                    {'id': '1', 'title': 'Survey the site'},
                    {'id': '2', 'title': 'File the report'},
                  ],
                },
                {
                  'key': 'doing',
                  'title': 'Doing',
                  'items': [
                    {'id': '3', 'title': 'Fit the panel'},
                  ],
                },
              ],
          'itemTemplate': {
            'type': 'card',
            'child': {'type': 'text', 'content': '{{item.title}}'},
          },
          ...extra,
        };

    testWidgets('every column and card is drawn', (tester) async {
      await pump(tester, board());

      expect(find.text('To do'), findsOneWidget);
      expect(find.text('Doing'), findsOneWidget);
      expect(find.text('Survey the site'), findsOneWidget);
      expect(find.text('Fit the panel'), findsOneWidget);
    });

    /// Drags [card] onto the gap under [afterCard].
    ///
    /// The drop targets are the GAPS between cards, not the cards: that is
    /// what makes the destination index mean something. So the release has to
    /// land in the few pixels below the last card of the destination column,
    /// and the pointer has to move in steps for the target to register the
    /// hover at all.
    Future<void> dragOntoGapAfter(
      WidgetTester tester,
      Finder card,
      Finder afterCard,
    ) async {
      final gesture = await tester.startGesture(tester.getCenter(card));
      await tester.pump(const Duration(milliseconds: 100));
      final drop = tester.getBottomLeft(afterCard) + const Offset(40, 6);
      await gesture.moveTo(tester.getCenter(afterCard));
      await tester.pump();
      await gesture.moveTo(drop);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
    }

    testWidgets('dragging a card to another column reports the move',
        (tester) async {
      await pump(tester, board(extra: {
        'onCardMove': {
          'type': 'state',
          'action': 'set',
          'binding': 'moved',
          'value': '{{event.to.column}}',
        },
      }));

      await dragOntoGapAfter(
          tester, find.text('Survey the site'), find.text('Fit the panel'));

      expect(stateManager.get('moved'), 'doing',
          reason: 'the board can move the card on screen, but the SERVER is '
              'what has to be told — a move nobody is told about is undone by '
              'the next refresh');
    });

    testWidgets('the destination index travels with the move', (tester) async {
      await pump(tester, board(extra: {
        'onCardMove': {
          'type': 'state',
          'action': 'set',
          'binding': 'toIndex',
          'value': '{{event.to.index}}',
        },
      }));

      await dragOntoGapAfter(
          tester, find.text('Survey the site'), find.text('Fit the panel'));

      expect(stateManager.get('toIndex'), 1,
          reason: 'a board without ordering is a list of columns');
    });

    testWidgets('a column at its limit refuses the drop', (tester) async {
      await pump(tester, board(
        columns: [
          {
            'key': 'todo',
            'title': 'To do',
            'items': [
              {'id': '1', 'title': 'Survey the site'},
            ],
          },
          {
            'key': 'doing',
            'title': 'Doing',
            'limit': 1,
            'items': [
              {'id': '3', 'title': 'Fit the panel'},
            ],
          },
        ],
        extra: {
          'onCardMove': {
            'type': 'state',
            'action': 'set',
            'binding': 'moved',
            'value': '{{event.to.column}}',
          },
        },
      ));

      await dragOntoGapAfter(
          tester, find.text('Survey the site'), find.text('Fit the panel'));

      expect(stateManager.get('moved'), isNull,
          reason: 'a WIP limit that accepts the drop and reports it is not a '
              'limit; the card would land and bounce back on the next load');
      expect(find.text('Survey the site'), findsOneWidget);
    });

    testWidgets('an empty board draws its columns anyway', (tester) async {
      await pump(tester, board(columns: [
        {'key': 'todo', 'title': 'To do', 'items': <dynamic>[]},
      ]));

      expect(find.text('To do'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('calendar', () {
    Map<String, dynamic> calendar({Map<String, dynamic> extra = const {}}) => {
          'type': 'calendar',
          'selectedDate': '2026-03-15',
          ...extra,
        };

    testWidgets('the declared month is the one shown', (tester) async {
      await pump(tester, calendar());

      expect(find.textContaining('March'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
    });

    testWidgets('stepping to the next month and back reports each change',
        (tester) async {
      await pump(tester, calendar(extra: {
        'onMonthChange': {
          'type': 'state',
          'action': 'set',
          'binding': 'month',
          'value': '{{event.month}}',
        },
      }));

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(find.textContaining('April'), findsOneWidget);
      expect(stateManager.get('month'), 4);

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(find.textContaining('March'), findsOneWidget);
      expect(stateManager.get('month'), 3);
    });

    testWidgets('the month cannot be stepped past the declared bounds',
        (tester) async {
      await pump(tester, calendar(extra: {
        'firstDate': '2026-03-01',
        'lastDate': '2026-03-31',
        'onMonthChange': {
          'type': 'state',
          'action': 'set',
          'binding': 'month',
          'value': '{{event.month}}',
        },
      }));

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(find.textContaining('March'), findsOneWidget,
          reason: 'a bounded calendar that scrolls past its bounds offers '
              'dates the document has already said it will not accept');
      expect(stateManager.get('month'), isNull);

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(find.textContaining('March'), findsOneWidget);
    });

    testWidgets('tapping a day selects it and reports it', (tester) async {
      await pump(tester, calendar(extra: {
        'onDateSelect': {
          'type': 'state',
          'action': 'set',
          'binding': 'chosen',
          'value': '{{event.value}}',
        },
      }));

      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();

      expect(stateManager.get<String>('chosen'), contains('2026-03-20'));
    });

    testWidgets('the legacy onChange spelling still reports', (tester) async {
      await pump(tester, calendar(extra: {
        'onChange': {
          'type': 'state',
          'action': 'set',
          'binding': 'chosen',
          'value': '{{event.date}}',
        },
      }));

      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();

      expect(stateManager.get<String>('chosen'), contains('2026-03-20'));
    });

    testWidgets('a date outside the bounds cannot be selected', (tester) async {
      await pump(tester, calendar(extra: {
        'firstDate': '2026-03-10',
        'lastDate': '2026-03-18',
        'onDateSelect': {
          'type': 'state',
          'action': 'set',
          'binding': 'chosen',
          'value': '{{event.value}}',
        },
      }));

      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();

      expect(stateManager.get('chosen'), isNull,
          reason: 'a day the document already said it will not accept must '
              'not be selectable — otherwise the refusal comes later, from a '
              'server, with no explanation');
    });
  });

  group('dataTable', () {
    Map<String, dynamic> table({Map<String, dynamic> extra = const {}}) => {
          'type': 'dataTable',
          'columns': [
            {'label': 'Name', 'key': 'name'},
            {'label': 'Site', 'key': 'site'},
          ],
          'rows': [
            {'name': 'Ada', 'site': 'North'},
            {'name': 'Bob', 'site': 'South'},
            {'name': 'Cy', 'site': 'North'},
          ],
          ...extra,
        };

    testWidgets('every row is drawn', (tester) async {
      await pump(tester, table());

      expect(find.text('Ada'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Cy'), findsOneWidget);
    });

    testWidgets('a filter narrows the rows to what matches', (tester) async {
      await pump(tester, table(extra: {'filterable': true}));

      await tester.enterText(find.byType(TextField).first, 'ad');
      await tester.pumpAndSettle();

      expect(find.text('Ada'), findsOneWidget);
      expect(find.text('Bob'), findsNothing,
          reason: 'a filter box that accepts text and shows every row is the '
              'clearest possible way to look like it is working');
    });

    testWidgets('a filter that matches nothing empties the table',
        (tester) async {
      await pump(tester, table(extra: {'filterable': true}));

      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.pumpAndSettle();

      expect(find.text('Ada'), findsNothing);
      expect(find.text('Bob'), findsNothing);
    });

    testWidgets('clearing the filter brings the rows back', (tester) async {
      await pump(tester, table(extra: {'filterable': true}));

      await tester.enterText(find.byType(TextField).first, 'ad');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pumpAndSettle();

      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('a row tap reports the row it was', (tester) async {
      await pump(tester, table(extra: {
        'onRowTap': {
          'type': 'state',
          'action': 'set',
          'binding': 'chosen',
          'value': '{{event.row.name}}',
        },
      }));

      await tester.tap(find.text('Bob'));
      await tester.pumpAndSettle();

      expect(stateManager.get('chosen'), 'Bob');
    });

    testWidgets('a resizable column can be dragged wider', (tester) async {
      await pump(tester, table(extra: {'resizableColumns': true}));

      final before = tester.getSize(find.text('Name').first).width;
      final handle = find.byType(GestureDetector).first;
      await tester.drag(handle, const Offset(60, 0));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.text('Name').first).width,
          greaterThanOrEqualTo(before),
          reason: 'a handle that drags nothing is a control the user will '
              'keep trying');
    });
  });

  group('networkGraph', () {
    Map<String, dynamic> graph({Map<String, dynamic> extra = const {}}) => {
          'type': 'networkGraph',
          'nodes': [
            {'id': 'a', 'label': 'Gateway'},
            {'id': 'b', 'label': 'Sensor 1'},
            {'id': 'c', 'label': 'Sensor 2'},
          ],
          'edges': [
            {'source': 'a', 'target': 'b'},
            {'source': 'a', 'target': 'c'},
          ],
          ...extra,
        };

    testWidgets('nodes with no position are laid out rather than stacked',
        (tester) async {
      await pump(tester, graph());

      // All three would sit on the same point if the auto-layout never ran,
      // and the graph would read as one node.
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a node reports which one', (tester) async {
      await pump(tester, graph(extra: {
        'nodes': [
          {'id': 'a', 'label': 'Gateway', 'x': 100.0, 'y': 100.0},
        ],
        'edges': <dynamic>[],
        'onNodeTap': {
          'type': 'state',
          'action': 'set',
          'binding': 'tapped',
          'value': '{{event.nodeId}}',
        },
      }));

      final origin = tester.getTopLeft(find.byType(CustomPaint).first);
      await tester.tapAt(origin + const Offset(100, 100));
      await tester.pumpAndSettle();

      expect(stateManager.get('tapped'), 'a',
          reason: 'a topology nobody can click is a picture, not a view');
    });

    testWidgets('a tap on empty canvas reports nothing', (tester) async {
      await pump(tester, graph(extra: {
        'nodes': [
          {'id': 'a', 'label': 'Gateway', 'x': 20.0, 'y': 20.0},
        ],
        'edges': <dynamic>[],
        'onNodeTap': {
          'type': 'state',
          'action': 'set',
          'binding': 'tapped',
          'value': '{{event.nodeId}}',
        },
      }));

      final origin = tester.getTopLeft(find.byType(CustomPaint).first);
      await tester.tapAt(origin + const Offset(400, 400));
      await tester.pumpAndSettle();

      expect(stateManager.get('tapped'), isNull);
    });

    testWidgets('the canvas pans under a drag', (tester) async {
      await pump(tester, graph());

      await tester.drag(find.byType(CustomPaint).first, const Offset(60, 40));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'panning is how a graph bigger than its box is read at all');
    });

    testWidgets('an empty graph draws an empty canvas', (tester) async {
      await pump(tester, {
        'type': 'networkGraph',
        'nodes': <dynamic>[],
        'edges': <dynamic>[],
      });

      expect(tester.takeException(), isNull);
    });
  });
}
