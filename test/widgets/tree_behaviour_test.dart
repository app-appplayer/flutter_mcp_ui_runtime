// `tree` — expand, collapse, select, check, and the slots that were declared
// and dropped.
//
// The factory was 65% covered and the uncovered third was everything a user
// does to a tree: opening a node, choosing one, ticking a checkbox, tapping a
// leaf. Several of those slots have comments in the factory saying they used
// to be read and discarded — a tree whose `onNodeTap` never fired, a
// `childrenKey` that showed only roots. This file drives them from the screen
// so the next one that stops being read fails here.

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

  Future<void> pumpTree(
    WidgetTester tester,
    Map<String, dynamic> definition,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: context.renderer.renderWidget(definition, context),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  List<dynamic> sampleData() => [
        {
          'id': 'root',
          'label': 'Root',
          'children': [
            {'id': 'leaf-a', 'label': 'Leaf A'},
            {'id': 'leaf-b', 'label': 'Leaf B'},
          ],
        },
        {'id': 'alone', 'label': 'Alone'},
      ];

  group('what is on screen', () {
    testWidgets('roots are shown and children stay hidden until opened',
        (tester) async {
      await pumpTree(tester, {'type': 'tree', 'data': sampleData()});

      expect(find.text('Root'), findsOneWidget);
      expect(find.text('Alone'), findsOneWidget);
      expect(find.text('Leaf A'), findsNothing,
          reason: 'a collapsed tree that renders its whole depth is not a '
              'tree, and on real data it is a scroll view of everything');
    });

    testWidgets('tapping a node opens it and tapping again closes it',
        (tester) async {
      await pumpTree(tester, {'type': 'tree', 'data': sampleData()});

      await tester.tap(find.text('Root'));
      await tester.pumpAndSettle();
      expect(find.text('Leaf A'), findsOneWidget);
      expect(find.text('Leaf B'), findsOneWidget);

      await tester.tap(find.text('Root'));
      await tester.pumpAndSettle();
      expect(find.text('Leaf A'), findsNothing);
    });

    testWidgets('initiallyExpanded opens everything up front', (tester) async {
      await pumpTree(tester, {
        'type': 'tree',
        'data': sampleData(),
        'initiallyExpanded': true,
      });

      expect(find.text('Leaf A'), findsOneWidget,
          reason: '§10.11 — a document that wants its tree open on arrival '
              'says so here; ignoring it shows an empty-looking panel');
    });

    testWidgets('the legacy `expandAll` spelling still opens it',
        (tester) async {
      await pumpTree(
          tester, {'type': 'tree', 'data': sampleData(), 'expandAll': true});
      expect(find.text('Leaf A'), findsOneWidget);
    });

    testWidgets('no data at all says so rather than drawing an empty box',
        (tester) async {
      await pumpTree(tester, {'type': 'tree', 'data': <dynamic>[]});
      expect(find.text('No tree data'), findsOneWidget,
          reason: 'an empty panel reads as a broken widget; the message reads '
              'as a query that returned nothing');
    });

    testWidgets('a data path that resolves to a scalar is empty, not a crash',
        (tester) async {
      stateManager.set('rows', 'still loading');
      await pumpTree(tester, {'type': 'tree', 'data': '{{rows}}'});
      expect(find.text('No tree data'), findsOneWidget);
    });

    testWidgets('deeper levels are indented further than their parent',
        (tester) async {
      await pumpTree(tester, {
        'type': 'tree',
        'data': sampleData(),
        'initiallyExpanded': true,
        'indentation': 40,
      });

      expect(tester.getTopLeft(find.text('Leaf A')).dx,
          greaterThan(tester.getTopLeft(find.text('Root')).dx),
          reason: 'without indentation a tree reads as a flat list and the '
              'hierarchy is invisible');
    });
  });

  group('the slots a document declares', () {
    testWidgets('childrenKey reads the shape the data actually has',
        (tester) async {
      // The factory comment: a tree over data keyed anything other than
      // `children` used to show only its roots.
      await pumpTree(tester, {
        'type': 'tree',
        'childrenKey': 'items',
        'initiallyExpanded': true,
        'data': [
          {
            'id': 'r',
            'label': 'Root',
            'items': [
              {'id': 'c', 'label': 'Nested by items'},
            ],
          },
        ],
      });

      expect(find.text('Nested by items'), findsOneWidget);
    });

    testWidgets('onNodeTap fires for a leaf', (tester) async {
      await pumpTree(tester, {
        'type': 'tree',
        'data': sampleData(),
        'onNodeTap': {
          'type': 'state',
          'action': 'set',
          'binding': 'tapped',
          'value': 'yes',
        },
      });

      await tester.tap(find.text('Alone'));
      await tester.pumpAndSettle();

      expect(stateManager.get('tapped'), 'yes',
          reason: 'onSelect only fires when `selectable` is on, so without '
              'this a plain tree had no working tap at all');
    });

    testWidgets('onSelect fires and the selection is visible', (tester) async {
      await pumpTree(tester, {
        'type': 'tree',
        'data': sampleData(),
        'selectable': true,
        'onSelect': {
          'type': 'state',
          'action': 'set',
          'binding': 'selected',
          'value': 'picked',
        },
      });

      await tester.tap(find.text('Alone'));
      await tester.pumpAndSettle();

      expect(stateManager.get('selected'), 'picked');
    });

    testWidgets('onExpand and onCollapse each fire once, at the right moment',
        (tester) async {
      await pumpTree(tester, {
        'type': 'tree',
        'data': sampleData(),
        'onExpand': {
          'type': 'state',
          'action': 'increment',
          'binding': 'opened',
        },
        'onCollapse': {
          'type': 'state',
          'action': 'increment',
          'binding': 'closed',
        },
      });
      stateManager.set('opened', 0);
      stateManager.set('closed', 0);

      await tester.tap(find.text('Root'));
      await tester.pumpAndSettle();
      expect(stateManager.get('opened'), 1);
      expect(stateManager.get('closed'), 0,
          reason: 'firing both on every toggle would make a lazy-load hook '
              'fetch and discard on the same tap');

      await tester.tap(find.text('Root'));
      await tester.pumpAndSettle();
      expect(stateManager.get('closed'), 1);
      expect(stateManager.get('opened'), 1);
    });

    testWidgets('an itemTemplate replaces the default row and sees the item',
        (tester) async {
      await pumpTree(tester, {
        'type': 'tree',
        'data': sampleData(),
        'initiallyExpanded': true,
        'itemTemplate': {
          'type': 'text',
          'content': 'row: {{item.label}}',
        },
      });

      expect(find.text('row: Root'), findsOneWidget);
      expect(find.text('row: Leaf A'), findsOneWidget,
          reason: 'the template has to be used at every depth, not only for '
              'the roots');
      expect(find.text('Root'), findsNothing);
    });

    testWidgets('checkable draws a box per node and reports the checked set',
        (tester) async {
      await pumpTree(tester, {
        'type': 'tree',
        'data': sampleData(),
        'checkable': true,
        'checkedKeys': '{{checked}}',
      });
      expect(find.byType(Checkbox), findsNWidgets(2));

      await tester.tap(find.byType(Checkbox).last);
      await tester.pumpAndSettle();

      expect(stateManager.get('checked'), contains('alone'),
          reason: 'the checked set is what a document submits; a checkbox '
              'that ticks on screen and writes nothing is worse than none');
    });

    testWidgets('a node already in checkedKeys starts ticked', (tester) async {
      stateManager.set('checked', ['alone']);
      await pumpTree(tester, {
        'type': 'tree',
        'data': sampleData(),
        'checkable': true,
        'checkedKeys': '{{checked}}',
      });

      final boxes = tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
      expect(boxes.last.value, isTrue,
          reason: 'state has to flow back into the widget, or a reopened '
              'panel loses what the user already ticked');
      expect(boxes.first.value, isFalse);
    });

    testWidgets('expandable: false shows the whole tree flat', (tester) async {
      await pumpTree(tester, {
        'type': 'tree',
        'data': sampleData(),
        'expandable': false,
      });

      expect(find.text('Leaf A'), findsOneWidget,
          reason: 'a tree that cannot be expanded has to show its children, '
              'or the data below the roots is unreachable');
    });

    testWidgets('an icon named on a node is drawn', (tester) async {
      await pumpTree(tester, {
        'type': 'tree',
        'data': [
          {'id': 'f', 'label': 'Folder', 'icon': 'folder'},
        ],
      });
      expect(find.byIcon(Icons.folder), findsOneWidget);
    });
  });
}
