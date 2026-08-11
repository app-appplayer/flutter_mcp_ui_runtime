// `splitter` — a fixed area divided between siblings.
//
// The invariant is the whole widget: dragging a gutter takes space from one
// pane and gives it to the next, so the total never changes and neither pane
// can be squeezed past its minimum. None of that had run — a splitter that
// draws its gutters and does not move them looks like a layout with a stray
// divider in it.

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
          width: 400,
          height: 300,
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

  Map<String, dynamic> splitter({Map<String, dynamic> extra = const {}}) => {
        'type': 'splitter',
        'children': [
          {'type': 'text', 'content': 'left'},
          {'type': 'text', 'content': 'right'},
        ],
        ...extra,
      };

  group('what it draws', () {
    testWidgets('two panes and a gutter between them', (tester) async {
      await pump(tester, splitter());

      expect(find.text('left'), findsOneWidget);
      expect(find.text('right'), findsOneWidget);
      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('with one child there is nothing to divide, and it is drawn',
        (tester) async {
      await pump(tester, {
        'type': 'splitter',
        'children': [
          {'type': 'text', 'content': 'alone'},
        ],
      });

      expect(find.text('alone'), findsOneWidget,
          reason: 'dropping the single pane would lose content because the '
              'author had not added the second one yet');
    });

    testWidgets('with no children it draws nothing', (tester) async {
      await pump(tester, {'type': 'splitter', 'children': <dynamic>[]});
      expect(tester.takeException(), isNull);
    });

    testWidgets('the declared sizes decide the split', (tester) async {
      await pump(tester, splitter(extra: {
        'sizes': [0.75, 0.25],
      }));

      final left = tester.getSize(find.text('left'));
      final right = tester.getSize(find.text('right'));
      expect(left.width, greaterThan(right.width),
          reason: 'a declared split that renders 50/50 is a property the '
              'document may as well not have written');
    });

    testWidgets('sizes that do not match the pane count fall back to even',
        (tester) async {
      await pump(tester, splitter(extra: {
        'sizes': [0.75],
      }));

      expect(tester.takeException(), isNull,
          reason: 'a half-edited document must not fail to lay out');
    });

    testWidgets('a vertical splitter stacks its panes', (tester) async {
      await pump(tester, splitter(extra: {'orientation': 'vertical'}));

      expect(tester.getTopLeft(find.text('left')).dy,
          lessThan(tester.getTopLeft(find.text('right')).dy));
    });
  });

  group('dragging a gutter', () {
    testWidgets('moves space from one pane to the next, and reports it',
        (tester) async {
      stateManager.set('panes', [0.5, 0.5]);
      await pump(tester, splitter(extra: {'sizes': 'panes'}));

      final before = tester.getSize(find.text('left')).width;
      await tester.drag(find.byType(GestureDetector).first, const Offset(80, 0));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.text('left')).width, greaterThan(before));

      final written = stateManager.get<List<dynamic>>('panes')!;
      expect(written.first, greaterThan(0.5));
      expect(written.first + written.last, closeTo(1.0, 0.001),
          reason: 'the total is the invariant: a drag that grows one pane '
              'without shrinking the other overflows the area');
    });

    testWidgets('a pane cannot be squeezed past its minimum', (tester) async {
      stateManager.set('panes', [0.5, 0.5]);
      await pump(tester, splitter(extra: {
        'sizes': 'panes',
        'minSizes': [0.2, 0.4],
      }));

      await tester.drag(
          find.byType(GestureDetector).first, const Offset(400, 0));
      await tester.pumpAndSettle();

      final written = stateManager.get<List<dynamic>>('panes')!;
      expect(written.last, greaterThanOrEqualTo(0.4 - 0.001),
          reason: 'a minimum that can be dragged through is a minimum in name '
              'only — the pane collapses and its content is unreachable');
      expect(written.first + written.last, closeTo(1.0, 0.001));
    });

    testWidgets('onDragEnd reports the final split once', (tester) async {
      await pump(tester, splitter(extra: {
        'onDragEnd': {
          'type': 'state',
          'action': 'set',
          'binding': 'settled',
          'value': '{{event.value}}',
        },
      }));

      await tester.drag(find.byType(GestureDetector).first, const Offset(40, 0));
      await tester.pumpAndSettle();

      final settled = stateManager.get<List<dynamic>>('settled')!;
      expect(settled, hasLength(2),
          reason: '§10.28 — the document persists the split its user chose, '
              'and it can only do that if it is told what it was');
      expect(settled.first, greaterThan(0.5));
    });

    testWidgets('a vertical gutter drags on the other axis', (tester) async {
      stateManager.set('panes', [0.5, 0.5]);
      await pump(tester, splitter(extra: {
        'orientation': 'vertical',
        'sizes': 'panes',
      }));

      await tester.drag(find.byType(GestureDetector).first, const Offset(0, 60));
      await tester.pumpAndSettle();

      expect(stateManager.get<List<dynamic>>('panes')!.first, greaterThan(0.5));
    });

    testWidgets('with no binding the split still moves on screen',
        (tester) async {
      await pump(tester, splitter());

      final before = tester.getSize(find.text('left')).width;
      await tester.drag(find.byType(GestureDetector).first, const Offset(60, 0));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.text('left')).width, greaterThan(before),
          reason: 'a splitter with nowhere to persist its split is still a '
              'splitter');
    });
  });
}
