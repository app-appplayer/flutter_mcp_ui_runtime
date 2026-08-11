// `tabBar`'s presentation, and the `list` shapes the earlier suite did not
// reach.
//
// Both are the same kind of gap: a property the document declares, a branch
// that reads it, and no evidence either way. A tab strip whose indicator
// colour is ignored looks like a theme problem; a list of direct children with
// no separator looks like a spacing problem. Neither reads as "the runtime
// dropped it".

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
    ThemeManager.instance.reset();
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

  group('tabBar', () {
    Map<String, dynamic> tabBar({Map<String, dynamic> extra = const {}}) => {
          'type': 'tabBar',
          'tabs': ['Day', 'Week'],
          ...extra,
        };

    testWidgets('plain string tabs are labelled', (tester) async {
      await pump(tester, tabBar());

      expect(find.text('Day'), findsOneWidget);
      expect(find.text('Week'), findsOneWidget);
    });

    testWidgets('switching tabs reports the index', (tester) async {
      await pump(tester, tabBar(extra: {
        'onChange': {
          'type': 'state',
          'action': 'set',
          'binding': 'tab',
          'value': '{{event.index}}',
        },
      }));

      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();

      expect(stateManager.get('tab'), 1,
          reason: 'the strip highlights the tap on its own; the document only '
              'learns which tab through this');
    });

    testWidgets('an underline indicator is built from its declaration',
        (tester) async {
      await pump(tester, tabBar(extra: {
        'indicator': {
          'type': 'underline',
          'color': '#FF0000',
          'width': 4,
          'insets': 8,
        },
      }));

      final tabBarWidget = tester.widget<TabBar>(find.byType(TabBar));
      final indicator = tabBarWidget.indicator! as UnderlineTabIndicator;
      expect(indicator.borderSide.color, const Color(0xFFFF0000));
      expect(indicator.borderSide.width, 4);
      expect(indicator.insets, const EdgeInsets.all(8));
    });

    testWidgets('an indicator bound to state resolves through the binding',
        (tester) async {
      stateManager.set('strip', {'type': 'underline', 'color': '#00FF00'});
      await pump(tester, tabBar(extra: {'indicator': '{{strip}}'}));

      final indicator = tester.widget<TabBar>(find.byType(TabBar)).indicator!
          as UnderlineTabIndicator;
      expect(indicator.borderSide.color, const Color(0xFF00FF00));
    });

    testWidgets('an indicator that resolves to nothing leaves the default',
        (tester) async {
      stateManager.set('strip', 'underline');
      await pump(tester, tabBar(extra: {'indicator': '{{strip}}'}));

      expect(tester.widget<TabBar>(find.byType(TabBar)).indicator, isNull);
    });

    testWidgets('an unknown indicator type leaves the default', (tester) async {
      await pump(tester, tabBar(extra: {
        'indicator': {'type': 'ripple'},
      }));

      expect(tester.widget<TabBar>(find.byType(TabBar)).indicator, isNull);
    });

    testWidgets('the label styles are read', (tester) async {
      await pump(tester, tabBar(extra: {
        'labelStyle': {
          'color': '#FF0000',
          'fontSize': 18,
          'fontWeight': 'bold',
        },
        'unselectedLabelStyle': {'fontSize': 14, 'fontWeight': 'normal'},
        'overlayColor': '#0000FF',
      }));

      final tabBarWidget = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBarWidget.labelStyle!.fontSize, 18);
      expect(tabBarWidget.labelStyle!.fontWeight, FontWeight.bold);
      expect(tabBarWidget.unselectedLabelStyle!.fontSize, 14);
      expect(tabBarWidget.unselectedLabelStyle!.fontWeight, FontWeight.normal);
      expect(tabBarWidget.overlayColor?.resolve({}), const Color(0xFF0000FF));
    });

    testWidgets('a tab declared as an object keeps its label and icon',
        (tester) async {
      await pump(tester, tabBar(extra: {
        'tabs': [
          {'label': 'Day', 'icon': 'today'},
          {'label': 'Week'},
        ],
      }));

      expect(find.text('Day'), findsOneWidget);
      expect(find.byIcon(Icons.today), findsOneWidget);
    });
  });

  group('list — the other shapes', () {
    testWidgets('direct item definitions are each rendered', (tester) async {
      await pump(tester, {
        'type': 'list',
        'items': [
          {'type': 'text', 'content': 'first'},
          {'type': 'text', 'content': 'second'},
        ],
      });

      expect(find.text('first'), findsOneWidget);
      expect(find.text('second'), findsOneWidget,
          reason: 'a list of widget definitions with no template is the '
              'shortest form a document can write');
    });

    testWidgets('spacing separates direct items too', (tester) async {
      await pump(tester, {
        'type': 'list',
        'spacing': 40,
        'items': [
          {'type': 'text', 'content': 'first'},
          {'type': 'text', 'content': 'second'},
        ],
      });

      final gap = tester.getTopLeft(find.text('second')).dy -
          tester.getTopLeft(find.text('first')).dy;
      expect(gap, greaterThan(40));
    });

    testWidgets('static children are separated by spacing as well',
        (tester) async {
      await pump(tester, {
        'type': 'list',
        'spacing': 40,
        'children': [
          {'type': 'text', 'content': 'first'},
          {'type': 'text', 'content': 'second'},
        ],
      });

      final gap = tester.getTopLeft(find.text('second')).dy -
          tester.getTopLeft(find.text('first')).dy;
      expect(gap, greaterThan(40));
    });

    testWidgets('a horizontal list of direct items scrolls sideways',
        (tester) async {
      await pump(tester, {
        'type': 'list',
        'orientation': 'horizontal',
        'spacing': 20,
        'items': [
          {'type': 'text', 'content': 'first'},
          {'type': 'text', 'content': 'second'},
        ],
      });

      expect(tester.getTopLeft(find.text('second')).dx,
          greaterThan(tester.getTopLeft(find.text('first')).dx));
    });

    testWidgets('an empty children list with a message shows it',
        (tester) async {
      await pump(tester, {
        'type': 'list',
        'children': <dynamic>[],
        'emptyMessage': 'Nothing here yet',
      });

      expect(find.text('Nothing here yet'), findsOneWidget);
    });

    testWidgets('overscan converts to a pixel cache through the item extent',
        (tester) async {
      await pump(tester, {
        'type': 'list',
        'items': [
          {'name': 'Ada'},
          {'name': 'Bob'},
        ],
        'itemTemplate': {'type': 'text', 'content': '{{item.name}}'},
        'virtual': true,
        'itemExtent': 40,
        'overscan': 3,
      });

      expect(find.text('Ada'), findsOneWidget,
          reason: 'overscan counts ITEMS and Flutter caches by pixels; the '
              'conversion needs the extent, and without one the request is '
              'ignored rather than guessed at');
    });
  });
}
