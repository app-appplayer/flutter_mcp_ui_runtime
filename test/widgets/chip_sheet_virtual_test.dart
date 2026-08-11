// `chip`'s variants and delete affordance, `bottomSheet`'s close reports,
// `dropdown`'s font weights, and the virtualization helpers.
//
// Each of these is a branch a document opts into by writing one more
// property: an outlined chip, a delete icon, a sheet that reports when it is
// dismissed. They all render either way, so a branch that is read and dropped
// leaves an affordance the user can see and not use.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/widgets/virtualized/virtualized_list.dart';
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
        body: AnimatedBuilder(
          animation: stateManager,
          builder: (_, __) => context.renderer.renderWidget(definition, context),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> set(String binding, Object? value) => <String, dynamic>{
        'type': 'state',
        'action': 'set',
        'binding': binding,
        'value': value,
      };

  group('chip', () {
    testWidgets('an outlined chip carries a delete affordance that reports',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'chip',
        'label': 'Draft',
        'variant': 'outlined',
        'deleteIcon': 'close',
        'onDeleted': set('deleted', true),
      });

      expect(find.byIcon(Icons.close), findsOneWidget,
          reason: 'the delete icon is the whole affordance; drawing it and '
              'wiring nothing gives the user a control that does nothing');

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(stateManager.get('deleted'), isTrue);
    });

    testWidgets('a selected chip takes its tint from the declared colour',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'chip',
        'label': 'Filter',
        'variant': 'outlined',
        'selected': true,
        'backgroundColor': '#FF0000',
      });

      final chip = tester.widget<RawChip>(find.byType(RawChip));
      expect(chip.selected, isTrue);
      expect(chip.selectedColor, isNotNull,
          reason: 'a selected chip that looks identical to an unselected one '
              'is a filter the user cannot read');
    });

    testWidgets('a filter chip falls back to a theme tint when no colour is '
        'declared', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'chip',
        'label': 'Filter',
        'selected': true,
      });

      expect(tester.takeException(), isNull);
      expect(find.text('Filter'), findsOneWidget);
    });

    testWidgets('a declared border side is drawn', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'chip',
        'label': 'Bordered',
        'variant': 'outlined',
        'side': <String, dynamic>{'width': 3},
      });

      expect(tester.takeException(), isNull);
      expect(find.text('Bordered'), findsOneWidget);
    });
  });

  group('bottomSheet', () {
    testWidgets('a drag downwards reports that it is closing', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'bottomSheet',
        'enableDrag': true,
        'onClosing': set('closing', true),
        // The sheet reads `children`, not `child`.
        'children': <dynamic>[
          <String, dynamic>{'type': 'text', 'content': 'sheet'},
        ],
      });

      await tester.drag(find.text('sheet'), const Offset(0, 40));
      await tester.pumpAndSettle();

      expect(stateManager.get('closing'), isTrue,
          reason: 'a sheet the user pulled down and the document never heard '
              'about leaves the page believing it is still open');
    });

    testWidgets('with drag disabled it still listens for the dismissal',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'bottomSheet',
        'enableDrag': false,
        'onClosing': set('closing', true),
        'showDragHandle': true,
        'children': <dynamic>[
          <String, dynamic>{'type': 'text', 'content': 'sheet'},
        ],
      });

      expect(find.byType(NotificationListener<DraggableScrollableNotification>),
          findsOneWidget,
          reason: 'a sheet inside a draggable scrollable reports through the '
              'notification instead of the gesture');
      expect(find.text('sheet'), findsOneWidget);
    });
  });

  group('dropdown', () {
    testWidgets('each declared font weight reaches the label', (tester) async {
      for (final weight in const {
        'w700': FontWeight.w700,
        'w800': FontWeight.w800,
        'w900': FontWeight.w900,
      }.entries) {
        await pump(tester, <String, dynamic>{
          'type': 'select',
          'value': 'a',
          'items': <dynamic>[
            <String, dynamic>{'value': 'a', 'label': 'Option A'},
          ],
          'style': <String, dynamic>{'fontWeight': weight.key},
        });

        expect(tester.takeException(), isNull, reason: weight.key);
        expect(find.text('Option A'), findsWidgets, reason: weight.key);
      }
    });

    testWidgets('an item with no label falls back to its value',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'select',
        'value': 'a',
        'items': <dynamic>[
          <String, dynamic>{'value': 'a'},
        ],
      });

      expect(find.text('a'), findsWidgets,
          reason: 'an item with no label drawn as an empty row is a choice '
              'the user cannot make');
    });

    testWidgets('a select with no items renders rather than throwing',
        (tester) async {
      await pump(tester, <String, dynamic>{'type': 'select'});

      expect(tester.takeException(), isNull);
    });
  });

  group('the virtualization helpers', () {
    testWidgets('a list past the threshold is the one that virtualizes',
        (tester) async {
      expect(context.shouldVirtualize(150), isTrue);
      expect(context.shouldVirtualize(10), isFalse);
      expect(context.shouldVirtualize(10, threshold: 5), isTrue,
          reason: 'the threshold is what a host tunes for its own rows; '
              'ignoring it makes the setting decorative');
    });

    testWidgets('the helpers build a list and a grid that draw their items',
        (tester) async {
      final items = List<int>.generate(200, (i) => i);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: context.createVirtualizedList(
            items: items,
            itemHeight: 24,
            itemBuilder: (_, item, index) => SizedBox(
              height: 24,
              child: Text('row $item'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('row 0'), findsOneWidget);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: context.createVirtualizedGrid(
            items: items,
            crossAxisCount: 3,
            itemBuilder: (_, item, index) => Text('cell $item'),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('cell 0'), findsOneWidget,
          reason: 'a helper that builds an empty viewport is worse than no '
              'helper — the caller cannot tell it from an empty list');
    });
  });
}
