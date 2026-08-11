// `gantt` — a schedule that can be read, and edited by dragging.
//
// The uncovered part is the editing: dragging a bar moves the task and has to
// report the new dates, because the chart is a view of a plan the server owns.
// A bar that moves on screen and tells nobody is a change the next refresh
// silently undoes.

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

  Future<void> pump(WidgetTester tester, Map<String, dynamic> definition) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 400,
          child: AnimatedBuilder(
            animation: stateManager,
            builder: (_, __) =>
                context.renderer.renderWidget(definition, context),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> gantt({Map<String, dynamic> extra = const {}}) => {
        'type': 'gantt',
        'tasks': [
          {
            'id': 'survey',
            'label': 'Site survey',
            'start': '2026-03-02',
            'end': '2026-03-06',
            'progress': 0.5,
          },
          {
            'id': 'fit',
            'label': 'Fit the panel',
            'start': '2026-03-09',
            'end': '2026-03-13',
            'dependsOn': ['survey'],
          },
        ],
        'range': {'start': '2026-03-01', 'end': '2026-03-20'},
        ...extra,
      };

  group('what it draws', () {
    testWidgets('a row per task, labelled', (tester) async {
      await pump(tester, gantt());

      expect(find.text('Site survey'), findsOneWidget);
      expect(find.text('Fit the panel'), findsOneWidget);
    });

    testWidgets('a task with no dates is skipped rather than misplaced',
        (tester) async {
      await pump(tester, gantt(extra: {
        'tasks': [
          {'id': 'a', 'label': 'Dated', 'start': '2026-03-02', 'end': '2026-03-06'},
          {'id': 'b', 'label': 'Undated'},
        ],
      }));

      expect(find.text('Dated'), findsOneWidget);
      expect(find.text('Undated'), findsNothing,
          reason: 'a bar with no dates would have to be placed somewhere, and '
              'anywhere is a date the plan does not contain');
    });

    testWidgets('with no usable task it draws nothing', (tester) async {
      await pump(tester, gantt(extra: {'tasks': <dynamic>[]}));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a declared task colour is used', (tester) async {
      await pump(tester, gantt(extra: {
        'tasks': [
          {
            'id': 'a',
            'label': 'Coloured',
            'start': '2026-03-02',
            'end': '2026-03-06',
            'color': '#FF0000',
          },
        ],
      }));

      expect(tester.takeException(), isNull,
          reason: '§10 declares `color` per task; every bar in the scheme '
              'primary makes two teams look like one');
    });

    testWidgets('grouped tasks are drawn under their group', (tester) async {
      await pump(tester, gantt(extra: {
        'tasks': [
          {
            'id': 'a',
            'label': 'North job',
            'group': 'North',
            'start': '2026-03-02',
            'end': '2026-03-06',
          },
          {
            'id': 'b',
            'label': 'South job',
            'group': 'South',
            'start': '2026-03-09',
            'end': '2026-03-13',
          },
        ],
      }));

      expect(find.text('North'), findsOneWidget);
      expect(find.text('South'), findsOneWidget);
    });

    testWidgets('the settings each change the picture', (tester) async {
      for (final setting in const [
        'showProgress',
        'showDependencies',
        'todayMarker',
      ]) {
        await pump(tester, gantt(extra: {setting: false}));
        expect(tester.takeException(), isNull, reason: setting);
      }
    });

    testWidgets('every view mode lays out', (tester) async {
      for (final mode in const ['day', 'week', 'month']) {
        await pump(tester, gantt(extra: {'viewMode': mode}));
        expect(find.text('Site survey'), findsOneWidget, reason: mode);
      }
    });
  });

  group('interaction', () {
    testWidgets('tapping a bar reports which task', (tester) async {
      await pump(tester, gantt(extra: {
        'onTaskClick': {
          'type': 'state',
          'action': 'set',
          'binding': 'tapped',
          'value': '{{event.id}}',
        },
      }));

      // The bar is the only gesture target in the chart area; finding it by
      // geometry rather than by guessing at the label column's width.
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      expect(stateManager.get('tapped'), 'survey',
          reason: 'a schedule nobody can select from is a picture of a plan');
    });

    testWidgets('dragging a bar reports the new dates when editable',
        (tester) async {
      await pump(tester, gantt(extra: {
        'editable': true,
        'onTaskChange': {
          'type': 'state',
          'action': 'set',
          'binding': 'movedTo',
          'value': '{{event.start}}',
        },
      }));

      await tester.drag(find.byType(GestureDetector).first, const Offset(120, 0));
      await tester.pumpAndSettle();

      final moved = stateManager.get<String>('movedTo');
      expect(moved, isNotNull,
          reason: 'the chart is a view of a plan the server owns — a bar that '
              'moves and tells nobody is undone by the next refresh');
      expect(DateTime.parse(moved!).isAfter(DateTime(2026, 3, 2)), isTrue);
    });

    testWidgets('a chart that is not editable does not move', (tester) async {
      await pump(tester, gantt(extra: {
        'onTaskChange': {
          'type': 'state',
          'action': 'set',
          'binding': 'movedTo',
          'value': '{{event.start}}',
        },
      }));

      await tester.drag(find.byType(GestureDetector).first, const Offset(120, 0));
      await tester.pumpAndSettle();

      expect(stateManager.get('movedTo'), isNull,
          reason: 'a read-only schedule that can be dragged invites a change '
              'the document has already refused');
    });
  });
}
