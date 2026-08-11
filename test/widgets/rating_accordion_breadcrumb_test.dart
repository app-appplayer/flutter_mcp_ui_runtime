// `rating`, `accordion`, `breadcrumb`, `listTile` and `form`.
//
// Five small widgets whose uncovered part is, in each case, the interaction:
// half-star tapping, expanding a section, following a crumb, submitting a
// form. What a widget draws at rest says nothing about whether it works.

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
        body: AnimatedBuilder(
          animation: stateManager,
          builder: (_, __) => context.renderer.renderWidget(definition, context),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('rating', () {
    testWidgets('tapping a star writes that many, and reports it',
        (tester) async {
      stateManager.set('score', 0);
      await pump(tester, <String, dynamic>{
        'type': 'rating',
        'binding': 'score',
        'max': 5,
        'onChange': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'reported',
          'value': true,
        },
      });

      await tester.tap(find.byIcon(Icons.star_border).at(2));
      await tester.pumpAndSettle();

      expect(stateManager.get('score'), 3);
      expect(stateManager.get('reported'), isTrue);
    });

    testWidgets('a half-star rating reads which side was tapped',
        (tester) async {
      stateManager.set('score', 0);
      await pump(tester, <String, dynamic>{
        'type': 'rating',
        'binding': 'score',
        'max': 5,
        'allowHalf': true,
      });

      // The rect is taken before the first tap: tapping changes which glyph
      // the third star draws, so a finder by icon would move.
      final star = find.byIcon(Icons.star_border).at(2);
      final rect = tester.getRect(star);

      await tester.tapAt(rect.topLeft + const Offset(2, 8));
      await tester.pumpAndSettle();
      expect(stateManager.get('score'), 2.5,
          reason: 'a half rating that rounds up is a review the user did not '
              'give');

      await tester.tapAt(rect.bottomRight - const Offset(2, 8));
      await tester.pumpAndSettle();
      expect(stateManager.get('score'), 3);
    });

    testWidgets('a half value draws the half glyph', (tester) async {
      stateManager.set('score', 2.5);
      await pump(tester, <String, dynamic>{
        'type': 'rating',
        'binding': 'score',
        'allowHalf': true,
      });

      expect(find.byIcon(Icons.star_half), findsOneWidget);
    });

    testWidgets('a read-only rating takes no taps', (tester) async {
      stateManager.set('score', 2);
      await pump(tester, <String, dynamic>{
        'type': 'rating',
        'binding': 'score',
        'readOnly': true,
      });

      await tester.tap(find.byIcon(Icons.star_border).first,
          warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(stateManager.get('score'), 2);
    });
  });

  group('accordion', () {
    Map<String, dynamic> accordion({Map<String, dynamic> extra = const {}}) =>
        <String, dynamic>{
          'type': 'accordion',
          'panels': <dynamic>[
            <String, dynamic>{
              'id': 'a',
              'title': 'First',
              'content': <String, dynamic>{'type': 'text', 'content': 'body A'},
            },
            <String, dynamic>{
              'id': 'b',
              'title': 'Second',
              'content': <String, dynamic>{'type': 'text', 'content': 'body B'},
            },
          ],
          ...extra,
        };

    testWidgets('expanding a section writes the open set back', (tester) async {
      stateManager.set('open', <dynamic>[]);
      await pump(tester, accordion(extra: <String, dynamic>{
        'expandedIds': 'open',
        'onChange': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'changedTo',
          'value': '{{event.id}}',
        },
      }));

      await tester.tap(find.text('First'));
      await tester.pumpAndSettle();

      expect(stateManager.get('open'), <dynamic>['a'],
          reason: 'the open set is what a document persists so a page comes '
              'back the way the user left it');
      expect(stateManager.get('changedTo'), 'a');
    });

    testWidgets('collapsing removes it again', (tester) async {
      stateManager.set('open', <dynamic>['a']);
      await pump(tester, accordion(extra: <String, dynamic>{
        'expandedIds': 'open',
      }));

      await tester.tap(find.text('First'));
      await tester.pumpAndSettle();

      expect(stateManager.get('open'), isEmpty);
    });

    testWidgets('a single-open accordion closes the other one',
        (tester) async {
      stateManager.set('open', <dynamic>['a']);
      await pump(tester, accordion(extra: <String, dynamic>{
        'expandedIds': 'open',
        'allowMultiple': false,
      }));

      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();

      expect(stateManager.get('open'), <dynamic>['b'],
          reason: 'allowMultiple: false is the declaration that only one may '
              'be open; leaving both open ignores it');
    });

    testWidgets('allowMultiple keeps both open', (tester) async {
      stateManager.set('open', <dynamic>['a']);
      await pump(tester, accordion(extra: <String, dynamic>{
        'expandedIds': 'open',
        'allowMultiple': true,
      }));

      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();

      expect(stateManager.get('open'), <dynamic>['a', 'b']);
    });

    testWidgets('a header may be a widget rather than a title', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'accordion',
        'panels': <dynamic>[
          <String, dynamic>{
            'id': 'a',
            'header': <String, dynamic>{
              'type': 'text',
              'content': 'Built header',
            },
            'content': <String, dynamic>{'type': 'text', 'content': 'body'},
          },
        ],
      });

      expect(find.text('Built header'), findsOneWidget);
    });

    testWidgets('a binding holding something other than a list reads empty',
        (tester) async {
      stateManager.set('open', 'a');
      await pump(tester, accordion(extra: <String, dynamic>{
        'expandedIds': 'open',
      }));

      expect(tester.takeException(), isNull,
          reason: 'state written by an earlier version of a document is '
              'ordinary; the section list must not take the page down');
    });
  });

  group('breadcrumb', () {
    Map<String, dynamic> crumbs({Map<String, dynamic> extra = const {}}) =>
        <String, dynamic>{
          'type': 'breadcrumb',
          'items': <dynamic>[
            <String, dynamic>{'label': 'Home', 'route': '/'},
            <String, dynamic>{'label': 'Jobs', 'route': '/jobs'},
            <String, dynamic>{'label': 'Job 42'},
          ],
          ...extra,
        };

    testWidgets('draws the trail', (tester) async {
      await pump(tester, crumbs());

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Job 42'), findsOneWidget);
    });

    testWidgets('following a crumb navigates and reports it', (tester) async {
      await pump(tester, crumbs(extra: <String, dynamic>{
        'onClick': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'clicked',
          'value': true,
        },
      }));

      await tester.tap(find.text('Jobs'));
      await tester.pumpAndSettle();

      expect(stateManager.get('clicked'), isTrue,
          reason: 'a trail that cannot be followed is a label, not a control');
    });

    testWidgets('a long trail is elided in the middle', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'breadcrumb',
        'maxItems': 3,
        'items': <dynamic>[
          <String, dynamic>{'label': 'A'},
          <String, dynamic>{'label': 'B'},
          <String, dynamic>{'label': 'C'},
          <String, dynamic>{'label': 'D'},
          <String, dynamic>{'label': 'E'},
        ],
      });

      expect(find.text('…'), findsOneWidget,
          reason: 'the first and last crumbs are the ones that orient the '
              'user; dropping the ellipsis hides that anything was removed');
      expect(find.text('A'), findsOneWidget);
      expect(find.text('E'), findsOneWidget);
      expect(find.text('B'), findsNothing);
    });
  });

  group('listTile', () {
    testWidgets('a leading icon name goes through the shared vocabulary',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'listTile',
        'title': 'Home',
        'leading': 'home',
        'trailing': 'chevron_right',
      });

      expect(find.byIcon(Icons.home), findsOneWidget,
          reason: 'the local table knew four names and answered a forward '
              'chevron for the rest — a plausible wrong icon, which is '
              'harder to notice than a missing one');
    });

    testWidgets('a long press reaches its action', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'listTile',
        'title': 'Home',
        'onLongPress': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'held',
          'value': true,
        },
      });

      await tester.longPress(find.text('Home'));
      await tester.pumpAndSettle();

      expect(stateManager.get('held'), isTrue);
    });

    testWidgets('each declared shape is built', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'listTile',
        'title': 'Home',
        'shape': <String, dynamic>{'type': 'rounded', 'radius': 12},
      });
      expect(tester.widget<ListTile>(find.byType(ListTile)).shape,
          isA<RoundedRectangleBorder>());

      await pump(tester, <String, dynamic>{
        'type': 'listTile',
        'title': 'Home',
        'shape': <String, dynamic>{'type': 'stadium'},
      });
      expect(tester.widget<ListTile>(find.byType(ListTile)).shape,
          isA<StadiumBorder>());

      await pump(tester, <String, dynamic>{
        'type': 'listTile',
        'title': 'Home',
        'shape': <String, dynamic>{'type': 'beveled'},
      });
      expect(tester.widget<ListTile>(find.byType(ListTile)).shape, isNull);
    });
  });

  group('form', () {
    testWidgets('a submit button appears when a submit action is declared',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'form',
        'submitLabel': 'Send',
        // The implicit footer button is the `actions.onSubmit` shape — the
        // spec's path for a form that does not render its own button.
        'actions': <String, dynamic>{
          'onSubmit': <String, dynamic>{
            'type': 'state',
            'action': 'set',
            'binding': 'submitted',
            'value': true,
          },
        },
        'children': <dynamic>[
          <String, dynamic>{
            'type': 'textInput',
            'binding': 'name',
            'label': 'Name',
          },
        ],
      });

      expect(find.text('Send'), findsOneWidget);

      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      expect(stateManager.get('submitted'), isTrue,
          reason: 'a form whose submit does nothing is the shape a user fills '
              'in twice before giving up');
    });

    testWidgets('with no submit action there is no button', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'form',
        'children': <dynamic>[
          <String, dynamic>{
            'type': 'textInput',
            'binding': 'name',
            'label': 'Name',
          },
        ],
      });

      expect(find.byType(ElevatedButton), findsNothing);
    });
  });
}
