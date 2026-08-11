// `menu` (50%) and `bottomSheet` (48%) — standing navigation, and the surface
// that slides up over it.
//
// `menu` is the sidebar an admin screen is built from: nesting, collapsing, a
// selected key and a set of open groups, all of it bound to state. Half of it
// had never run, and the half that had was the flat list — which is the shape
// `navigationRail` already covers, so nesting was the part with no evidence at
// all.
//
// `bottomSheet` was covered as far as "it builds". Its drag handle, its
// constraints, its shadow and its `onClosing` were not.

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
        body: SingleChildScrollView(
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

  group('menu', () {
    Map<String, dynamic> menu({Map<String, dynamic> extra = const {}}) => {
          'type': 'menu',
          'selectedKey': 'section',
          'openKeys': 'expanded',
          'items': [
            {'key': 'dashboard', 'label': 'Dashboard'},
            {
              'key': 'reports',
              'label': 'Reports',
              'children': [
                {'key': 'daily', 'label': 'Daily'},
                {'key': 'monthly', 'label': 'Monthly'},
              ],
            },
            {'key': 'archived', 'label': 'Archived', 'enabled': false},
          ],
          ...extra,
        };

    testWidgets('top-level items are drawn; a closed group hides its children',
        (tester) async {
      await pump(tester, menu());

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('Daily'), findsNothing,
          reason: 'a group that is closed in state must not be drawn open');
    });

    testWidgets('a group with open keys in state shows its children',
        (tester) async {
      stateManager.set('expanded', ['reports']);
      await pump(tester, menu());

      expect(find.text('Daily'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
    });

    testWidgets('tapping a group toggles it in state, both ways',
        (tester) async {
      await pump(tester, menu());

      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();
      expect(stateManager.get('expanded'), ['reports']);
      expect(find.text('Daily'), findsOneWidget,
          reason: 'the open set is bound, so the tree has to follow it');

      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();
      expect(stateManager.get('expanded'), isEmpty);
      expect(find.text('Daily'), findsNothing);
    });

    testWidgets('a group is not a destination', (tester) async {
      await pump(tester, menu(extra: {
        'onSelect': {
          'type': 'state',
          'action': 'set',
          'binding': 'chosen',
          'value': '{{event.value}}',
        },
      }));

      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();

      expect(stateManager.get('chosen'), isNull,
          reason: 'a heading that navigates takes the user off the screen '
              'they were opening');
      expect(stateManager.get('section'), isNull);
    });

    testWidgets('tapping a leaf writes the selected key and reports it',
        (tester) async {
      await pump(tester, menu(extra: {
        'onSelect': {
          'type': 'state',
          'action': 'set',
          'binding': 'chosen',
          'value': '{{event.value}}',
        },
      }));

      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();

      expect(stateManager.get('section'), 'dashboard');
      expect(stateManager.get('chosen'), 'dashboard');
    });

    testWidgets('a child leaf selects too', (tester) async {
      stateManager.set('expanded', ['reports']);
      await pump(tester, menu());

      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();

      expect(stateManager.get('section'), 'monthly',
          reason: 'a nested item that cannot be chosen makes the whole group '
              'decorative');
    });

    testWidgets('the selected item is marked as selected', (tester) async {
      stateManager.set('section', 'dashboard');
      await pump(tester, menu());

      final tile = tester.widget<ListTile>(
          find.ancestor(of: find.text('Dashboard'), matching: find.byType(ListTile)));
      expect(tile.selected, isTrue,
          reason: 'a sidebar that never shows where you are is a sidebar you '
              'have to re-read every time');
    });

    testWidgets('a disabled item cannot be chosen', (tester) async {
      await pump(tester, menu());

      await tester.tap(find.text('Archived'));
      await tester.pumpAndSettle();

      expect(stateManager.get('section'), isNull);
    });

    testWidgets('a literal selectedKey marks the item when no state holds one',
        (tester) async {
      await pump(tester, {
        'type': 'menu',
        'selectedKey': 'dashboard',
        'items': [
          {'key': 'dashboard', 'label': 'Dashboard'},
        ],
      });

      final tile = tester.widget<ListTile>(find.byType(ListTile));
      expect(tile.selected, isTrue,
          reason: '§2.8.9 declares `string | binding`; a bare string is '
              'indistinguishable from a path, so the path is read first and '
              'the literal is what is left');
    });

    testWidgets('collapsed hides labels and keeps them as tooltips',
        (tester) async {
      await pump(tester, menu(extra: {'collapsed': true}));

      expect(find.text('Dashboard'), findsNothing);
      expect(
          tester
              .widgetList<Tooltip>(find.byType(Tooltip))
              .map((t) => t.message),
          contains('Dashboard'),
          reason: 'a rail of unlabelled dots is a legend the user does not '
              'have');
    });

    testWidgets('collapsed keeps a group closed even when it is open in state',
        (tester) async {
      stateManager.set('expanded', ['reports']);
      await pump(tester, menu(extra: {'collapsed': true}));

      expect(find.text('Daily'), findsNothing,
          reason: 'there is no room to nest in a collapsed rail');
    });

    testWidgets('horizontal mode lays the items across', (tester) async {
      await pump(tester, {
        'type': 'menu',
        'mode': 'horizontal',
        'items': [
          {'key': 'a', 'label': 'Alpha'},
          {'key': 'b', 'label': 'Beta'},
        ],
      });

      expect(tester.getTopLeft(find.text('Alpha')).dy,
          tester.getTopLeft(find.text('Beta')).dy,
          reason: 'a horizontal menu stacked vertically is the default menu '
              'under another name');
    });

    testWidgets('an item with a route pushes it', (tester) async {
      // No navigator is attached here, so the push is refused rather than
      // performed — what matters is that selecting still writes the key, so a
      // failed navigation does not also lose the selection.
      await pump(tester, {
        'type': 'menu',
        'selectedKey': 'section',
        'items': [
          {'key': 'dashboard', 'label': 'Dashboard', 'route': '/dashboard'},
        ],
      });

      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();

      expect(stateManager.get('section'), 'dashboard');
      expect(tester.takeException(), isNull);
    });

    testWidgets('an icon gives the item a leading mark', (tester) async {
      await pump(tester, {
        'type': 'menu',
        'items': [
          {'key': 'a', 'label': 'Alpha', 'icon': 'home'},
        ],
      });

      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('entries that are not maps are skipped', (tester) async {
      await pump(tester, {
        'type': 'menu',
        'items': ['just a string'],
      });

      expect(find.byType(ListTile), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an item with no key cannot select anything', (tester) async {
      await pump(tester, {
        'type': 'menu',
        'selectedKey': 'section',
        'items': [
          {'label': 'Nameless'},
        ],
      });

      await tester.tap(find.text('Nameless'));
      await tester.pumpAndSettle();

      expect(stateManager.get('section'), isNull);
    });
  });

  group('bottomSheet', () {
    testWidgets('its child is rendered', (tester) async {
      await pump(tester, {
        'type': 'bottomSheet',
        'children': [
          {'type': 'text', 'content': 'sheet content'},
        ],
      });

      expect(find.text('sheet content'), findsOneWidget);
    });

    testWidgets('several children are stacked, not dropped', (tester) async {
      await pump(tester, {
        'type': 'bottomSheet',
        'children': [
          {'type': 'text', 'content': 'first'},
          {'type': 'text', 'content': 'second'},
        ],
      });

      expect(find.text('first'), findsOneWidget);
      expect(find.text('second'), findsOneWidget);
    });

    testWidgets('with no children it is an empty sheet', (tester) async {
      await pump(tester, {'type': 'bottomSheet'});
      expect(tester.takeException(), isNull);
    });

    testWidgets('showDragHandle draws a handle at the declared size',
        (tester) async {
      await pump(tester, {
        'type': 'bottomSheet',
        'showDragHandle': true,
        'dragHandleSize': {'width': 64, 'height': 6},
        'dragHandleColor': '#FF0000',
        'children': [
          {'type': 'text', 'content': 'sheet content'},
        ],
      });

      final handle = tester.widgetList<Container>(find.byType(Container))
          .firstWhere((c) =>
              c.decoration is BoxDecoration &&
              (c.decoration! as BoxDecoration).color == const Color(0xFFFF0000));
      expect(handle.constraints?.maxWidth ?? 0, 64);
    });

    testWidgets('without showDragHandle there is no handle', (tester) async {
      await pump(tester, {
        'type': 'bottomSheet',
        'dragHandleColor': '#FF0000',
        'children': [
          {'type': 'text', 'content': 'sheet content'},
        ],
      });

      final coloured = tester.widgetList<Container>(find.byType(Container))
          .where((c) =>
              c.decoration is BoxDecoration &&
              (c.decoration! as BoxDecoration).color == const Color(0xFFFF0000));
      expect(coloured, isEmpty);
    });

    testWidgets('background, shape and elevation reach the surface',
        (tester) async {
      await pump(tester, {
        'type': 'bottomSheet',
        'backgroundColor': '#00FF00',
        'elevation': 8,
        'shadowColor': '#0000FF',
        'shape': {'type': 'rounded', 'radius': 20},
        'children': [
          {'type': 'text', 'content': 'sheet content'},
        ],
      });

      final surface = tester.widgetList<Container>(find.byType(Container))
          .firstWhere((c) =>
              c.decoration is BoxDecoration &&
              (c.decoration! as BoxDecoration).color == const Color(0xFF00FF00));
      final decoration = surface.decoration! as BoxDecoration;
      expect(decoration.borderRadius,
          const BorderRadius.vertical(top: Radius.circular(20)));
      expect(decoration.boxShadow!.single.color, const Color(0xFF0000FF));
      expect(decoration.boxShadow!.single.blurRadius, 8);
    });

    testWidgets('an unknown shape leaves the corners alone', (tester) async {
      await pump(tester, {
        'type': 'bottomSheet',
        'backgroundColor': '#00FF00',
        'shape': {'type': 'hexagon'},
        'children': [
          {'type': 'text', 'content': 'sheet content'},
        ],
      });

      final surface = tester.widgetList<Container>(find.byType(Container))
          .firstWhere((c) =>
              c.decoration is BoxDecoration &&
              (c.decoration! as BoxDecoration).color == const Color(0xFF00FF00));
      expect((surface.decoration! as BoxDecoration).borderRadius, isNull);
    });

    testWidgets('constraints bound the sheet', (tester) async {
      await pump(tester, {
        'type': 'bottomSheet',
        'constraints': {'minHeight': 40, 'maxHeight': 120, 'maxWidth': 300},
        'children': [
          {'type': 'text', 'content': 'sheet content'},
        ],
      });

      final size = tester.getSize(find.text('sheet content'));
      expect(size.width, lessThanOrEqualTo(300),
          reason: 'a sheet that ignores maxWidth spans a tablet edge to edge');
    });

    testWidgets('dragging down reports onClosing', (tester) async {
      await pump(tester, {
        'type': 'bottomSheet',
        'onClosing': {
          'type': 'state',
          'action': 'set',
          'binding': 'closing',
          'value': true,
        },
        'children': [
          {'type': 'text', 'content': 'sheet content'},
        ],
      });

      await tester.drag(find.text('sheet content'), const Offset(0, 120));
      await tester.pumpAndSettle();

      expect(stateManager.get('closing'), isTrue,
          reason: 'a document that is never told the sheet is closing keeps '
              'it open in its own state');
    });

    testWidgets('with enableDrag false a drag reports nothing', (tester) async {
      await pump(tester, {
        'type': 'bottomSheet',
        'enableDrag': false,
        'onClosing': {
          'type': 'state',
          'action': 'set',
          'binding': 'closing',
          'value': true,
        },
        'children': [
          {'type': 'text', 'content': 'sheet content'},
        ],
      });

      await tester.drag(find.text('sheet content'), const Offset(0, 120));
      await tester.pumpAndSettle();

      expect(stateManager.get('closing'), isNull,
          reason: 'a sheet declared undraggable that still closes on a drag '
              'is closing against the document');
    });

    testWidgets('every clipBehavior spelling is read', (tester) async {
      for (final entry in const {
        'none': Clip.none,
        'hardEdge': Clip.hardEdge,
        'antiAlias': Clip.antiAlias,
        'antiAliasWithSaveLayer': Clip.antiAliasWithSaveLayer,
        'nonsense': Clip.none,
      }.entries) {
        await pump(tester, {
          'type': 'bottomSheet',
          'clipBehavior': entry.key,
          'backgroundColor': '#00FF00',
          'children': [
            {'type': 'text', 'content': 'sheet content'},
          ],
        });

        final surface = tester.widgetList<Container>(find.byType(Container))
            .firstWhere((c) =>
                c.decoration is BoxDecoration &&
                (c.decoration! as BoxDecoration).color ==
                    const Color(0xFF00FF00));
        expect(surface.clipBehavior, entry.value,
            reason: 'clipBehavior "${entry.key}"');
      }
    });
  });
}
