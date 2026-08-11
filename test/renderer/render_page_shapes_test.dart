// `Renderer.renderPage` — the scaffold shapes a document can ask for.
//
// The widget path through `renderWidget` is covered many times over. The PAGE
// path was not: tabs, drawer, the app bar built from a bare map, the bottom
// bar, the floating action, and the two places a document may put each of
// them. Every one of those is something an author sees or does not see, and
// the failure mode is a screen missing a bar rather than an error.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Renderer renderer;
  late StateManager stateManager;

  Renderer build({
    Widget Function(Widget, Map<String, dynamic>)? widgetWrapper,
  }) {
    stateManager = StateManager()..initialize(<String, dynamic>{'title': 'From state'});
    final registry = WidgetRegistry();
    DefaultWidgets.registerAll(registry);
    return Renderer(
      widgetRegistry: registry,
      bindingEngine: BindingEngine(),
      actionHandler: ActionHandler(),
      stateManager: stateManager,
      widgetWrapper: widgetWrapper,
    );
  }

  setUp(() => renderer = build());

  Future<void> pumpPage(
    WidgetTester tester,
    Map<String, dynamic> page, {
    Renderer? using,
  }) async {
    await tester.pumpWidget(MaterialApp(home: (using ?? renderer).renderPage(page)));
    await tester.pump();
  }

  group('a single page', () {
    testWidgets('renders its content', (tester) async {
      await pumpPage(tester, {
        'type': 'page',
        'content': {'type': 'text', 'content': 'the body'},
      });
      expect(find.text('the body'), findsOneWidget);
    });

    testWidgets('a list of children is stacked rather than dropped',
        (tester) async {
      // `children` as a LIST is the v1.0 shape. Taking only the first, or
      // nothing, is the kind of silent loss this file exists to catch.
      await pumpPage(tester, {
        'type': 'page',
        'children': [
          {'type': 'text', 'content': 'first'},
          {'type': 'text', 'content': 'second'},
        ],
      });

      expect(find.text('first'), findsOneWidget);
      expect(find.text('second'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('second')).dy,
        greaterThan(tester.getTopLeft(find.text('first')).dy),
        reason: 'they are stacked vertically, not drawn on top of each other',
      );
    });

    testWidgets('a page with no content at all still renders a scaffold',
        (tester) async {
      await pumpPage(tester, {'type': 'page'});
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('an unknown page type falls back to a single page rather than '
        'a blank screen', (tester) async {
      await pumpPage(tester, {
        'type': 'carousel-of-pages',
        'content': {'type': 'text', 'content': 'still here'},
      });
      expect(find.text('still here'), findsOneWidget,
          reason: 'a newer document opened on an older runtime must not lose '
              'its whole body over one unrecognised page type');
    });
  });

  group('the app bar', () {
    testWidgets('a bare map becomes an AppBar with its title', (tester) async {
      await pumpPage(tester, {
        'type': 'page',
        'appBar': {'title': 'Reports'},
        'content': {'type': 'text', 'content': 'body'},
      });

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
    });

    testWidgets('its title resolves a binding', (tester) async {
      await pumpPage(tester, {
        'type': 'page',
        'appBar': {'title': '{{title}}'},
        'content': {'type': 'text', 'content': 'body'},
      });
      expect(find.text('From state'), findsOneWidget);
    });

    testWidgets('actions and leading are rendered as widgets', (tester) async {
      await pumpPage(tester, {
        'type': 'page',
        'appBar': {
          'title': 'With actions',
          'leading': {'type': 'text', 'content': 'L'},
          'actions': [
            {'type': 'text', 'content': 'A1'},
            {'type': 'text', 'content': 'A2'},
          ],
        },
        'content': {'type': 'text', 'content': 'body'},
      });

      expect(find.text('L'), findsOneWidget);
      expect(find.text('A1'), findsOneWidget);
      expect(find.text('A2'), findsOneWidget,
          reason: 'rendering only the first action is a menu with items '
              'missing and nothing said');
    });

    testWidgets('a title given as a widget definition is rendered',
        (tester) async {
      await pumpPage(tester, {
        'type': 'page',
        'appBar': {
          'title': {'type': 'text', 'content': 'a widget title'},
        },
        'content': {'type': 'text', 'content': 'body'},
      });
      expect(find.text('a widget title'), findsOneWidget);
    });

    testWidgets('it is accepted under `properties` as well as at the root',
        (tester) async {
      // Both spellings appear in documents in the field; dropping either one
      // loses the bar with no error.
      await pumpPage(tester, {
        'type': 'page',
        'properties': {
          'appBar': {'title': 'Nested'},
        },
        'content': {'type': 'text', 'content': 'body'},
      });
      expect(find.text('Nested'), findsOneWidget);
    });
  });

  group('the bottom bar and the floating action', () {
    testWidgets('both are rendered from the root level', (tester) async {
      await pumpPage(tester, {
        'type': 'page',
        'content': {'type': 'text', 'content': 'body'},
        'bottomBar': {'type': 'text', 'content': 'bottom'},
        'floatingAction': {'type': 'text', 'content': 'fab'},
      });

      expect(find.text('bottom'), findsOneWidget);
      expect(find.text('fab'), findsOneWidget);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.bottomNavigationBar, isNotNull);
      expect(scaffold.floatingActionButton, isNotNull,
          reason: 'rendering them somewhere in the body instead of in their '
              'scaffold slots would put them in the wrong place entirely');
    });

    testWidgets('and from properties', (tester) async {
      await pumpPage(tester, {
        'type': 'page',
        'properties': {
          'bottomBar': {'type': 'text', 'content': 'bottom'},
          'floatingAction': {'type': 'text', 'content': 'fab'},
        },
        'content': {'type': 'text', 'content': 'body'},
      });
      expect(find.text('bottom'), findsOneWidget);
      expect(find.text('fab'), findsOneWidget);
    });

    testWidgets('a page that declares neither leaves the slots empty',
        (tester) async {
      await pumpPage(tester, {
        'type': 'page',
        'content': {'type': 'text', 'content': 'body'},
      });
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.bottomNavigationBar, isNull);
      expect(scaffold.floatingActionButton, isNull);
      expect(scaffold.appBar, isNull);
    });
  });

  group('a tabs page', () {
    Map<String, dynamic> tabsPage() => {
          'type': 'tabs',
          'properties': {'title': 'Tabbed'},
          'tabs': [
            {
              'label': 'One',
              'icon': 'home',
              'content': {'type': 'text', 'content': 'first tab body'},
            },
            {
              'label': 'Two',
              'content': {'type': 'text', 'content': 'second tab body'},
            },
          ],
        };

    testWidgets('every declared tab gets a tab, with its label and icon',
        (tester) async {
      await pumpPage(tester, tabsPage());

      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('One'), findsOneWidget);
      expect(find.text('Two'), findsOneWidget);
      expect(find.byIcon(Icons.home), findsOneWidget,
          reason: 'a declared icon that does not draw is a tab strip that '
              'looks unfinished, and nothing reports it');
      expect(find.text('Tabbed'), findsOneWidget);
    });

    testWidgets('the first tab body is shown, and switching shows the second',
        (tester) async {
      await pumpPage(tester, tabsPage());

      expect(find.text('first tab body'), findsOneWidget);

      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();

      expect(find.text('second tab body'), findsOneWidget,
          reason: 'tabs that render but do not switch are the shape of a '
              'TabBarView built from the wrong list');
    });

    testWidgets('a tab with no content is empty rather than fatal',
        (tester) async {
      await pumpPage(tester, {
        'type': 'tabs',
        'properties': {'title': 't'},
        'tabs': [
          {'label': 'Empty'},
        ],
      });
      expect(find.text('Empty'), findsOneWidget);
    });

    testWidgets('a tabs page with no tabs declared still builds', (tester) async {
      await pumpPage(tester, {'type': 'tabs', 'properties': {'title': 't'}});
      expect(find.byType(TabBar), findsOneWidget);
    });
  });

  group('a drawer page', () {
    testWidgets('the drawer is attached to the scaffold and opens',
        (tester) async {
      await pumpPage(tester, {
        'type': 'drawer',
        'properties': {
          'appBar': {'title': 'With drawer'},
          'drawer': {'type': 'text', 'content': 'drawer contents'},
        },
        'content': {'type': 'text', 'content': 'body'},
      });

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.drawer, isNotNull,
          reason: 'rendering the drawer definition into the body would put a '
              'navigation panel in the middle of the page');
      expect(find.text('body'), findsOneWidget);
      expect(find.text('drawer contents'), findsNothing);

      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pumpAndSettle();
      expect(find.text('drawer contents'), findsOneWidget);
    });

    testWidgets('a drawer page with no drawer declared is an ordinary page',
        (tester) async {
      await pumpPage(tester, {
        'type': 'drawer',
        'content': {'type': 'text', 'content': 'body'},
      });
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.drawer, isNull);
      expect(find.text('body'), findsOneWidget);
    });
  });

  group('renderDashboard', () {
    testWidgets('renders the declared content', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: renderer.renderDashboard({
          'content': {'type': 'text', 'content': 'dashboard tile'},
        }),
      ));
      expect(find.text('dashboard tile'), findsOneWidget);
    });

    testWidgets('a null config or a config with no content draws nothing',
        (tester) async {
      await tester.pumpWidget(MaterialApp(home: renderer.renderDashboard(null)));
      expect(find.byType(SizedBox), findsWidgets);

      await tester.pumpWidget(MaterialApp(
        home: renderer.renderDashboard(<String, dynamic>{'title': 'no content'}),
      ));
      expect(find.text('no content'), findsNothing,
          reason: '§11.9.1 — with no dashboard content the embedder falls back '
              'to a card of its own, so the runtime must draw nothing rather '
              'than something approximate');
    });
  });

  group('a host widget wrapper', () {
    testWidgets('wraps ordinary widgets', (tester) async {
      final wrapped = <String>[];
      final withWrapper = build(widgetWrapper: (child, definition) {
        wrapped.add(definition['type'] as String);
        return DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFF00FF00)),
          child: child,
        );
      });

      await pumpPage(tester, {
        'type': 'page',
        'content': {'type': 'text', 'content': 'wrapped'},
      }, using: withWrapper);

      expect(wrapped, contains('text'));
      expect(find.byType(DecoratedBox), findsWidgets);
    });

    testWidgets('a ParentDataWidget keeps its position — the wrap goes inside',
        (tester) async {
      // The comment in the renderer explains the stake: an Expanded wrapped
      // from outside is no longer a direct child of the Row, its parent cannot
      // read its ParentData, and the layout collapses. This asserts the layout
      // rather than the widget shape, because the layout is what breaks.
      final withWrapper = build(
        widgetWrapper: (child, definition) => Semantics(
          container: false,
          child: child,
        ),
      );

      await pumpPage(tester, {
        'type': 'page',
        'content': {
          'type': 'linear',
          'direction': 'horizontal',
          'children': [
            {
              'type': 'expanded',
              'child': {'type': 'text', 'content': 'grows'},
            },
            {'type': 'text', 'content': 'fixed'},
          ],
        },
      }, using: withWrapper);

      expect(tester.takeException(), isNull,
          reason: 'a wrapped Expanded raises "Incorrect use of '
              'ParentDataWidget" — the exact failure this branch prevents');
      expect(find.text('grows'), findsOneWidget);
      expect(find.text('fixed'), findsOneWidget);
    });

    testWidgets('the same holds for a Positioned inside a stack',
        (tester) async {
      final withWrapper = build(
        widgetWrapper: (child, definition) =>
            Semantics(container: false, child: child),
      );

      await pumpPage(tester, {
        'type': 'page',
        'content': {
          'type': 'stack',
          'children': [
            {
              'type': 'positioned',
              'left': 10.0,
              'top': 20.0,
              'child': {'type': 'text', 'content': 'placed'},
            },
          ],
        },
      }, using: withWrapper);

      expect(tester.takeException(), isNull);
      final topLeft = tester.getTopLeft(find.text('placed'));
      expect(topLeft.dx, 10);
      expect(topLeft.dy, 20,
          reason: 'the coordinates have to survive the wrap, or every '
              'absolutely positioned element lands at the origin');
    });
  });
}
