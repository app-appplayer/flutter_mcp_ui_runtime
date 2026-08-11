// Four small controls, each about half covered: `contextMenu`, `progress`,
// `pagination` and `numberStepper`.
//
// They are small enough that the whole widget is its properties, which is
// exactly why the gaps hide: nobody looks at a stepper twice. A stepper that
// ignores `min` lets an order go negative; a pagination that ignores
// `siblingCount` renders a different control from the one declared.

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
        body: Center(
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

  group('contextMenu', () {
    Map<String, dynamic> menu({Map<String, dynamic> extra = const {}}) => {
          'type': 'contextMenu',
          'child': {'type': 'text', 'content': 'Right-click me'},
          'items': [
            {'key': 'copy', 'label': 'Copy'},
            {'key': 'paste', 'label': 'Paste'},
          ],
          'onSelect': {
            'type': 'state',
            'action': 'set',
            'binding': 'chosen',
            'value': '{{event.value}}',
          },
          ...extra,
        };

    testWidgets('the child is drawn and the menu stays closed', (tester) async {
      await pump(tester, menu());

      expect(find.text('Right-click me'), findsOneWidget);
      expect(find.text('Copy'), findsNothing);
    });

    testWidgets('a long press opens it and choosing reports the value',
        (tester) async {
      await pump(tester, menu());

      await tester.longPress(find.text('Right-click me'));
      await tester.pumpAndSettle();
      expect(find.text('Copy'), findsOneWidget);

      await tester.tap(find.text('Paste'));
      await tester.pumpAndSettle();

      expect(stateManager.get('chosen'), 'paste',
          reason: 'a context menu that opens and reports nothing is a list of '
              'words');
    });

    testWidgets('a disabled menu does not open', (tester) async {
      await pump(tester, menu(extra: {'enabled': false}));

      await tester.longPress(find.text('Right-click me'));
      await tester.pumpAndSettle();

      expect(find.text('Copy'), findsNothing);
    });

    testWidgets('with no items there is nothing to open', (tester) async {
      await pump(tester, menu(extra: {'items': <dynamic>[]}));

      await tester.longPress(find.text('Right-click me'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('with no child it still builds', (tester) async {
      await pump(tester, {
        'type': 'contextMenu',
        'items': [
          {'key': 'copy', 'label': 'Copy'},
        ],
      });

      expect(tester.takeException(), isNull);
    });
  });

  group('progress', () {
    // §2.5.14: one widget under several names, `indicatorType` chooses the
    // shape. The property is reachable only under that alias — the widget
    // type and the spec's `type` property are the same key, and
    // `extractProperties` strips it. (Same collision as `mediaPlayer` and
    // `dialog`, recorded there.)
    testWidgets('circular is the undeclared shape, and takes a value',
        (tester) async {
      await pump(tester, {'type': 'progressBar', 'value': 0.4});

      expect(
          tester
              .widget<CircularProgressIndicator>(
                  find.byType(CircularProgressIndicator))
              .value,
          0.4);
    });

    testWidgets('every alias is the same widget', (tester) async {
      for (final name in const [
        'progressBar',
        'progress',
        'loadingIndicator',
        'linearProgressIndicator',
        'circularProgressIndicator',
        'progress-bar',
        'loading-indicator',
      ]) {
        await pump(tester, {'type': name, 'indicatorType': 'linear', 'value': 0.4});
        expect(find.byType(LinearProgressIndicator), findsOneWidget,
            reason: '$name is an alias of progressBar (§17.3.1); an alias that '
                'ignores the declared shape is a different widget');
      }
    });

    testWidgets('a name that states the shape draws that shape',
        (tester) async {
      // The `type` property §2.5.14 defines cannot be written at the top
      // level — the widget type shadows the key — so the widget type is the
      // other way a document names the shape.
      await pump(tester, {'type': 'linearProgressIndicator', 'value': 0.4});
      expect(find.byType(LinearProgressIndicator), findsOneWidget,
          reason: 'a widget called linearProgressIndicator that draws a '
              'spinner is a name that lies');

      await pump(tester, {'type': 'circularProgressIndicator', 'value': 0.4});
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('a declared indicatorType still wins over the name',
        (tester) async {
      await pump(tester, {
        'type': 'linearProgressIndicator',
        'indicatorType': 'circular',
        'value': 0.4,
      });

      expect(find.byType(CircularProgressIndicator), findsOneWidget,
          reason: 'the name is a default, not a lock — otherwise the two '
              'spellings would be different widgets rather than one');
    });

    testWidgets('indicatorType linear draws the bar form', (tester) async {
      await pump(tester,
          {'type': 'progress', 'indicatorType': 'linear', 'value': 0.6});

      expect(
          tester
              .widget<LinearProgressIndicator>(
                  find.byType(LinearProgressIndicator))
              .value,
          0.6);
    });

    testWidgets('with no value it is indeterminate', (tester) async {
      // Bounded pumps, not pumpAndSettle: an indeterminate indicator animates
      // forever, which is the point of it.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child:
                context.renderer.renderWidget({'type': 'progress'}, context),
          ),
        ),
      ));
      await tester.pump();

      expect(
          tester
              .widget<CircularProgressIndicator>(
                  find.byType(CircularProgressIndicator))
              .value,
          isNull,
          reason: 'an indicator pinned at zero reads as stuck; indeterminate '
              'is what "working, length unknown" looks like');
    });

    testWidgets('the circular colours, stroke and size are applied',
        (tester) async {
      await pump(tester, {
        'type': 'progress',
        'indicatorType': 'circular',
        'value': 0.5,
        'color': '#FF0000',
        'backgroundColor': '#00FF00',
        'strokeWidth': 8,
        'size': 60,
      });

      final indicator = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator));
      expect(indicator.valueColor?.value, const Color(0xFFFF0000),
          reason: 'the declared colour is the PROGRESS colour, which Material '
              'takes as an animation rather than a plain colour');
      expect(indicator.backgroundColor, const Color(0xFF00FF00));
      expect(indicator.strokeWidth, 8);

      final box = tester.getSize(find.byType(CircularProgressIndicator));
      expect(box.width, 60);
    });

    testWidgets('the linear colours and height are applied', (tester) async {
      await pump(tester, {
        'type': 'progressBar',
        'indicatorType': 'linear',
        'value': 0.5,
        'color': '#FF0000',
        'backgroundColor': '#00FF00',
        'minHeight': 12,
      });

      final indicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(indicator.valueColor?.value, const Color(0xFFFF0000));
      expect(indicator.backgroundColor, const Color(0xFF00FF00));
      expect(indicator.minHeight, 12,
          reason: 'a declared bar thickness that is dropped leaves every bar '
              'the same 4dp hairline');
    });

    testWidgets('a hidden progress bar draws nothing', (tester) async {
      await pump(tester, {
        'type': 'progressBar',
        'indicatorType': 'linear',
        'value': 0.5,
        'visible': false,
      });

      expect(find.byType(LinearProgressIndicator), findsNothing,
          reason: 'the common wrappers apply to every widget (§2.2); a form '
              'that skips them ignores `visible`, `tooltip` and `click`');
    });

    testWidgets('a bound value follows state', (tester) async {
      stateManager.set('done', 0.25);
      await pump(tester, {
        'type': 'progressBar',
        'indicatorType': 'linear',
        'value': '{{done}}',
      });

      expect(
          tester
              .widget<LinearProgressIndicator>(
                  find.byType(LinearProgressIndicator))
              .value,
          0.25);

      stateManager.set('done', 0.75);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<LinearProgressIndicator>(
                  find.byType(LinearProgressIndicator))
              .value,
          0.75);
    });
  });

  group('pagination', () {
    Map<String, dynamic> pager({Map<String, dynamic> extra = const {}}) => {
          'type': 'pagination',
          'binding': 'page',
          'total': 95,
          'pageSize': 10,
          ...extra,
        };

    testWidgets('draws the pages it has, and the current one', (tester) async {
      stateManager.set('page', 1);
      await pump(tester, pager());

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('choosing a page writes it back', (tester) async {
      stateManager.set('page', 1);
      await pump(tester, pager());

      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();

      expect(stateManager.get('page'), 2);
    });

    testWidgets('onChange reports the page too', (tester) async {
      stateManager.set('page', 1);
      await pump(tester, pager(extra: {
        'onChange': {
          'type': 'state',
          'action': 'set',
          'binding': 'reported',
          'value': '{{event.value}}',
        },
      }));

      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();

      expect(stateManager.get('reported'), 2,
          reason: 'the page number is what the next query needs; a control '
              'that only moves its own highlight fetches nothing');
    });

    testWidgets('showTotal says how many there are', (tester) async {
      stateManager.set('page', 1);
      await pump(tester, pager(extra: {'showTotal': true}));

      expect(find.textContaining('95'), findsOneWidget);
    });

    testWidgets('a size changer offers the declared page sizes',
        (tester) async {
      stateManager.set('page', 1);
      await pump(tester, pager(extra: {
        'showSizeChanger': true,
        'pageSizeOptions': [10, 25],
      }));

      expect(find.byType(DropdownButton<int>), findsOneWidget,
          reason: 'a declared size changer that draws nothing is a property '
              'with no effect at all');
    });

    testWidgets('choosing a page size reports it, and goes back to page one',
        (tester) async {
      stateManager.set('page', 4);
      await pump(tester, pager(extra: {
        'showSizeChanger': true,
        'pageSizeOptions': [10, 25],
        'onChange': {
          'type': 'batch',
          'actions': [
            {
              'type': 'state',
              'action': 'set',
              'binding': 'reportedPage',
              'value': '{{event.value}}',
            },
            {
              'type': 'state',
              'action': 'set',
              'binding': 'reportedSize',
              'value': '{{event.pageSize}}',
            },
          ],
        },
      }));

      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('25 / page').last);
      await tester.pumpAndSettle();

      expect(stateManager.get('reportedSize'), 25,
          reason: 'the size changer exists so the document can refetch with '
              'the new page size; a change nobody is told about leaves the '
              'list showing ten rows and claiming twenty-five');
      expect(stateManager.get('reportedPage'), 1,
          reason: 'page four of a ten-row paging is past the end of a '
              'twenty-five-row one — staying there shows an empty list');
    });

    testWidgets('a page given inline rather than bound is still the current '
        'one', (tester) async {
      await pump(tester, {
        'type': 'pagination',
        'total': 95,
        'pageSize': 10,
        'current': 3,
      });

      // The current page is the one drawn as selected; without reading
      // `current` the control always opens on page one.
      expect(find.text('3'), findsWidgets);
    });

    testWidgets('with nothing to page through it does not offer pages',
        (tester) async {
      await pump(tester, pager(extra: {'total': 0}));

      expect(tester.takeException(), isNull);
    });
  });

  group('numberStepper', () {
    Map<String, dynamic> stepper({Map<String, dynamic> extra = const {}}) => {
          'type': 'numberStepper',
          'binding': 'count',
          'value': 2,
          ...extra,
        };

    testWidgets('shows its value and steps up and down', (tester) async {
      stateManager.set('count', 2);
      await pump(tester, stepper());

      expect(find.text('2'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(stateManager.get('count'), 3);

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();
      expect(stateManager.get('count'), 2);
    });

    testWidgets('a declared step is the amount it moves by', (tester) async {
      stateManager.set('count', 2);
      await pump(tester, stepper(extra: {'step': 5}));

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(stateManager.get('count'), 7);
    });

    testWidgets('it will not go past min or max', (tester) async {
      stateManager.set('count', 1);
      await pump(tester, stepper(extra: {'min': 1, 'max': 2}));

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();
      expect(stateManager.get('count'), anyOf(isNull, 1),
          reason: 'a stepper that steps below its minimum lets an order go '
              'negative, and the refusal comes later from a server');

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(stateManager.get('count'), 2);
    });

    testWidgets('onChange reports the new value', (tester) async {
      stateManager.set('count', 2);
      await pump(tester, stepper(extra: {
        'onChange': {
          'type': 'state',
          'action': 'set',
          'binding': 'reported',
          'value': '{{event.value}}',
        },
      }));

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(stateManager.get('reported'), 3);
    });

    testWidgets('a label is drawn beside it', (tester) async {
      await pump(tester, stepper(extra: {'label': 'Quantity'}));

      expect(find.text('Quantity'), findsOneWidget);
    });

    testWidgets('disabled refuses both directions', (tester) async {
      stateManager.set('count', 2);
      await pump(tester, stepper(extra: {'enabled': false}));

      await tester.tap(find.byIcon(Icons.add), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(stateManager.get('count'), 2);
    });

    testWidgets('every size builds', (tester) async {
      for (final size in const ['small', 'medium', 'large']) {
        await pump(tester, stepper(extra: {'size': size}));
        expect(find.byIcon(Icons.add), findsOneWidget, reason: size);
      }
    });
  });
}
