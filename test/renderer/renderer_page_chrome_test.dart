// The chrome a page definition declares around its content: the app bar, and
// the two shapes a child can take that the renderer must not wrap.
//
// Both fail the same quiet way. An app bar built from a widget the renderer
// does not recognise disappears — the page still renders, just without its
// title and its actions. And a `ParentDataWidget` (`expanded`, `flexible`,
// `positioned`) wrapped by anything at all stops being read by its parent, so
// the layout collapses to intrinsic sizes with nothing on screen to say why.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StateManager stateManager;
  late Renderer renderer;

  setUp(() {
    stateManager = StateManager()..initialize(<String, dynamic>{});
    final registry = WidgetRegistry();
    DefaultWidgets.registerAll(registry);
    renderer = Renderer(
      widgetRegistry: registry,
      bindingEngine: BindingEngine(),
      actionHandler: ActionHandler(),
      stateManager: stateManager,
    );
  });

  Future<void> pumpPage(
    WidgetTester tester,
    Map<String, dynamic> definition,
  ) async {
    await tester.pumpWidget(MaterialApp(home: renderer.renderPage(definition)));
    await tester.pumpAndSettle();
  }

  group('the app bar', () {
    testWidgets('a declared headerBar becomes the page bar', (tester) async {
      await pumpPage(tester, <String, dynamic>{
        'type': 'page',
        'appBar': <String, dynamic>{
          'type': 'headerBar',
          'title': <String, dynamic>{'type': 'text', 'content': 'Jobs'},
        },
        'content': <String, dynamic>{'type': 'text', 'content': 'body'},
      });

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Jobs'), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('a bar whose type is not an app bar still leaves one',
        (tester) async {
      // `tabBar` builds a `DefaultTabController`, which is neither an
      // `AppBar` nor a `PreferredSizeWidget`. The page must still get its
      // chrome from the shorthand rather than rendering with no bar at all.
      await pumpPage(tester, <String, dynamic>{
        'type': 'page',
        'appBar': <String, dynamic>{
          'type': 'tabBar',
          'title': 'Jobs',
          'tabs': <dynamic>['One', 'Two'],
        },
        'content': <String, dynamic>{'type': 'text', 'content': 'body'},
      });

      expect(find.byType(AppBar), findsOneWidget,
          reason: 'a page that loses its bar loses its title and every action '
              'on it, and nothing on screen says why');
      expect(find.text('Jobs'), findsOneWidget);
    });

    testWidgets('an untyped bar is still built from its properties',
        (tester) async {
      await pumpPage(tester, <String, dynamic>{
        'type': 'page',
        'appBar': <String, dynamic>{'title': 'Settings'},
        'content': <String, dynamic>{'type': 'text', 'content': 'body'},
      });

      expect(find.text('Settings'), findsOneWidget,
          reason: 'the shorthand a bundle in the field still writes must keep '
              'working');
    });

    testWidgets('no bar declared means no bar', (tester) async {
      await pumpPage(tester, <String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{'type': 'text', 'content': 'body'},
      });

      expect(find.byType(AppBar), findsNothing);
    });
  });

  group('a definition with no type', () {
    testWidgets('is reported on screen rather than skipped', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: renderer.renderWidget(
            <String, dynamic>{'content': 'no type here'},
            renderer.createRootContext(null),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('type'), findsWidgets,
          reason: 'a widget with no type is a document that will never render '
              'that node; drawing nothing sends the author looking at the '
              'wrong place');
    });
  });

  group('a child that reports its own flex', () {
    testWidgets('flexible keeps its flex and fit through the wrap',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: renderer.renderWidget(<String, dynamic>{
            'type': 'row',
            'children': <dynamic>[
              <String, dynamic>{
                'type': 'flexible',
                'flex': 3,
                'fit': 'loose',
                // A property that makes the renderer want to wrap the child.
                'tooltip': 'the wide one',
                'child': <String, dynamic>{
                  'type': 'container',
                  'color': '#FF0000',
                },
              },
              <String, dynamic>{
                'type': 'flexible',
                'flex': 1,
                'child': <String, dynamic>{
                  'type': 'container',
                  'color': '#0000FF',
                },
              },
            ],
          }, renderer.createRootContext(null)),
        ),
      ));
      await tester.pumpAndSettle();

      final flexibles = tester.widgetList<Flexible>(find.byType(Flexible));
      expect(flexibles.map((f) => f.flex), containsAll(<int>[3, 1]),
          reason: 'wrapping the ParentDataWidget itself hides it from the row, '
              'which then lays every child out at its intrinsic size — the '
              'declared proportions are gone with nothing to say so');
      expect(flexibles.first.fit, FlexFit.loose);
    });
  });
}
