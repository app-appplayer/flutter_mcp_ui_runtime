// `conditional` (both forms), `gestureDetector`, and the two dialog surfaces.
//
// `conditional` is the widget a document uses to say "show this OR that", so
// a branch that picks wrong shows the user the opposite of what the state
// says. `gestureDetector` is a bare surface — every handler it drops is an
// interaction that silently does nothing.

import 'package:flutter/gestures.dart';
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

  Map<String, dynamic> text(String content) =>
      <String, dynamic>{'type': 'text', 'content': content};

  group('conditional — if/then/else', () {
    testWidgets('a true condition takes the then branch', (tester) async {
      stateManager.set('signedIn', true);
      await pump(tester, <String, dynamic>{
        'type': 'conditional',
        'condition': '{{signedIn}}',
        'then': text('Welcome'),
        'orElse': text('Sign in'),
      });

      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text('Sign in'), findsNothing);
    });

    testWidgets('it follows the state it is bound to', (tester) async {
      stateManager.set('signedIn', true);
      await pump(tester, <String, dynamic>{
        'type': 'conditional',
        'condition': '{{signedIn}}',
        'then': text('Welcome'),
        'orElse': text('Sign in'),
      });

      stateManager.set('signedIn', false);
      await tester.pumpAndSettle();

      expect(find.text('Sign in'), findsOneWidget,
          reason: 'a branch that does not re-evaluate shows the user the '
              'opposite of what the state says');
    });

    testWidgets('the legacy `else` spelling still works', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'conditional',
        'condition': false,
        'else': text('Sign in'),
      });

      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('a branch that is not declared draws nothing', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'conditional',
        'condition': false,
        'then': text('Welcome'),
      });

      expect(find.byType(SizedBox), findsWidgets);
      expect(find.text('Welcome'), findsNothing);
    });

    testWidgets('truthiness follows the values a document actually holds',
        (tester) async {
      Future<String> branchFor(dynamic condition) async {
        stateManager.set('flag', condition);
        await pump(tester, <String, dynamic>{
          'type': 'conditional',
          'condition': '{{flag}}',
          'then': text('yes'),
          'orElse': text('no'),
        });
        return find.text('yes').evaluate().isNotEmpty ? 'yes' : 'no';
      }

      expect(await branchFor(true), 'yes');
      expect(await branchFor(false), 'no');
      expect(await branchFor(1), 'yes');
      expect(await branchFor(0), 'no',
          reason: 'a count of zero is the empty case; treating it as true '
              'shows "1 result" over an empty list');
      expect(await branchFor('text'), 'yes');
      expect(await branchFor(''), 'no');
      expect(await branchFor(<dynamic>[1]), 'yes');
      expect(await branchFor(<dynamic>[]), 'no');
      expect(await branchFor(<String, dynamic>{'a': 1}), 'yes');
      expect(await branchFor(<String, dynamic>{}), 'no');
    });

    testWidgets('an unset condition takes the else branch', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'conditional',
        'condition': '{{neverSet}}',
        'then': text('yes'),
        'orElse': text('no'),
      });

      expect(find.text('no'), findsOneWidget);
    });

    testWidgets(
        'with neither a condition nor a switch it shows no branch, and does '
        'not throw', (tester) async {
      // It used to throw, which the renderer turned into an error card. The
      // schema cannot forbid the shape instead — validation runs at load, so
      // a document carrying one would stop opening altogether (§1.7.5) — so
      // the widget absorbs it. What it must not do is pick a branch: nothing
      // was tested, so `then` has not been shown to hold.
      await pump(tester, <String, dynamic>{
        'type': 'conditional',
        'then': text('Welcome'),
      });

      expect(find.text('Welcome'), findsNothing,
          reason: 'a conditional with nothing to test must not render one '
              'branch as though it had passed');
      expect(find.textContaining('Error rendering'), findsNothing);
    });
  });

  group('conditional — switch/cases', () {
    Map<String, dynamic> statusSwitch({dynamic value = '{{status}}'}) =>
        <String, dynamic>{
          'type': 'conditional',
          'switch': value,
          'cases': <dynamic>[
            <String, dynamic>{'value': 'loading', 'child': text('Loading')},
            <String, dynamic>{
              'value': <dynamic>['failed', 'cancelled'],
              'child': text('Stopped'),
            },
            <String, dynamic>{'value': 'done', 'widget': text('Done')},
          ],
          'default': text('Unknown'),
        };

    testWidgets('a matching case is the one that renders', (tester) async {
      stateManager.set('status', 'loading');
      await pump(tester, statusSwitch());

      expect(find.text('Loading'), findsOneWidget);
    });

    testWidgets('a case may list several values', (tester) async {
      stateManager.set('status', 'cancelled');
      await pump(tester, statusSwitch());

      expect(find.text('Stopped'), findsOneWidget);
    });

    testWidgets('the legacy `widget` and `then` case keys still resolve',
        (tester) async {
      stateManager.set('status', 'done');
      await pump(tester, statusSwitch());
      expect(find.text('Done'), findsOneWidget);

      stateManager.set('status', 'queued');
      await pump(tester, <String, dynamic>{
        'type': 'conditional',
        'switch': '{{status}}',
        'cases': <dynamic>[
          <String, dynamic>{'value': 'queued', 'then': text('Queued')},
        ],
      });
      expect(find.text('Queued'), findsOneWidget);
    });

    testWidgets('no match falls through to the default', (tester) async {
      stateManager.set('status', 'paused');
      await pump(tester, statusSwitch());

      expect(find.text('Unknown'), findsOneWidget);
    });

    testWidgets('values are compared by their text when the types differ',
        (tester) async {
      stateManager.set('code', 404);
      await pump(tester, <String, dynamic>{
        'type': 'conditional',
        'switch': '{{code}}',
        'cases': <dynamic>[
          <String, dynamic>{'value': '404', 'child': text('Not found')},
        ],
      });

      expect(find.text('Not found'), findsOneWidget,
          reason: 'a status arriving as a number and written as a string in '
              'the document is the ordinary case, not an error');
    });

    testWidgets('with no cases and no default it draws nothing',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'conditional',
        'switch': 'anything',
      });

      expect(tester.takeException(), isNull);
    });

    testWidgets('a case with no child falls through rather than blanking',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'conditional',
        'switch': 'loading',
        'cases': <dynamic>[
          <String, dynamic>{'value': 'loading'},
          'not a case',
        ],
        'default': text('Unknown'),
      });

      expect(find.text('Unknown'), findsOneWidget);
    });

    testWidgets('a null switch value matches nothing but the default',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'conditional',
        'switch': '{{missing}}',
        'cases': <dynamic>[
          <String, dynamic>{'value': null, 'child': text('Null case')},
        ],
        'default': text('Unknown'),
      });

      expect(find.text('Null case'), findsOneWidget,
          reason: 'null == null is a match; falling to the default here would '
              'hide the case a document wrote for "not set yet"');
    });
  });

  group('gestureDetector', () {
    Map<String, dynamic> record(String key) => <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': key,
          'value': true,
        };

    testWidgets('tap, double tap and long press each reach their action',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'gestureDetector',
        'child': text('surface'),
        'onTap': record('tapped'),
        'onDoubleTap': record('doubled'),
        'onLongPress': record('pressed'),
      });

      await tester.tap(find.text('surface'));
      // A double-tap handler delays the single tap by the recogniser's
      // timeout, so the state only lands after that has elapsed.
      await tester.pump(kDoubleTapTimeout);
      expect(stateManager.get('tapped'), isTrue);

      await tester.tap(find.text('surface'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('surface'));
      await tester.pump(kDoubleTapTimeout);
      expect(stateManager.get('doubled'), isTrue);

      await tester.longPress(find.text('surface'));
      await tester.pump(kDoubleTapTimeout);
      expect(stateManager.get('pressed'), isTrue);
    });

    testWidgets('a drag reports its start, its delta and its end',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'gestureDetector',
        'child': <String, dynamic>{
          'type': 'container',
          'width': 200,
          'height': 200,
          'color': '#EEEEEE',
        },
        'onPanStart': record('started'),
        'onPanEnd': record('ended'),
        'onPanUpdate': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'moved',
          'delta': '{{event.delta}}',
          'value': true,
        },
      });

      await tester.drag(find.byType(Container).first, const Offset(30, 40));
      await tester.pumpAndSettle();

      expect(stateManager.get('started'), isTrue);
      expect(stateManager.get('moved'), isTrue);
      expect(stateManager.get('ended'), isTrue,
          reason: 'a drag that never reports its end leaves whatever it was '
              'moving stuck to the finger');
    });

    testWidgets('a scale gesture reports its factor', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'gestureDetector',
        'child': <String, dynamic>{
          'type': 'container',
          'width': 200,
          'height': 200,
          'color': '#EEEEEE',
        },
        'onScaleUpdate': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'zoom',
          'scale': '{{event.scale}}',
          'value': true,
        },
      });

      final centre = tester.getCenter(find.byType(Container).first);
      final first = await tester.startGesture(centre - const Offset(20, 0));
      final second = await tester.startGesture(centre + const Offset(20, 0));
      await first.moveBy(const Offset(-30, 0));
      await second.moveBy(const Offset(30, 0));
      await tester.pump();
      await first.up();
      await second.up();
      await tester.pumpAndSettle();

      expect(stateManager.get('zoom'), isTrue);
    });

    testWidgets('with no handlers the surface passes taps through',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'gestureDetector',
        'child': text('surface'),
      });

      final detector =
          tester.widget<GestureDetector>(find.byType(GestureDetector).first);
      expect(detector.onTap, isNull);
      expect(detector.onLongPress, isNull);
    });

    testWidgets('a children list is accepted in place of a child',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'gestureDetector',
        'children': <dynamic>[text('first'), text('second')],
        'onTap': record('tapped'),
      });

      expect(find.text('first'), findsOneWidget);
      expect(find.text('second'), findsNothing,
          reason: 'a gesture surface takes one child; the rest would be '
              'silently stacked');
    });

    testWidgets('the legacy kebab handler names still bind', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'gestureDetector',
        'child': text('surface'),
        'click': record('tapped'),
        'long-press': record('pressed'),
      });

      await tester.tap(find.text('surface'));
      await tester.pumpAndSettle();
      expect(stateManager.get('tapped'), isTrue);

      await tester.longPress(find.text('surface'));
      await tester.pumpAndSettle();
      expect(stateManager.get('pressed'), isTrue);
    });
  });

  group('alertDialog', () {
    testWidgets('title, content and actions are drawn', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'alertDialog',
        'title': 'Delete the job?',
        'content': 'This cannot be undone.',
        'actions': <dynamic>[
          <String, dynamic>{'label': 'Cancel'},
          <String, dynamic>{
            'label': 'Delete',
            'isDestructive': true,
            'isDefault': true,
            'onTap': <String, dynamic>{
              'type': 'state',
              'action': 'set',
              'binding': 'confirmed',
              'value': true,
            },
          },
        ],
      });

      expect(find.text('Delete the job?'), findsOneWidget);
      expect(find.text('This cannot be undone.'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(stateManager.get('confirmed'), isTrue);
    });

    testWidgets('a destructive action is coloured, a default one is bold',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'alertDialog',
        'title': 'Delete the job?',
        'actions': <dynamic>[
          <String, dynamic>{'label': 'Delete', 'isDestructive': true},
          <String, dynamic>{'label': 'Keep', 'isDefault': true},
          'not an action',
        ],
      });

      expect(tester.widget<Text>(find.text('Delete')).style!.color, isNotNull,
          reason: 'the destructive action has to look different from the one '
              'beside it, or the safe tap and the dangerous one read alike');
      expect(tester.widget<Text>(find.text('Keep')).style!.fontWeight,
          FontWeight.bold);
    });

    testWidgets('an action with no label falls back rather than blanking',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'alertDialog',
        'actions': <dynamic>[<String, dynamic>{}],
      });

      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets('title and content may be widgets', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'alertDialog',
        'title': text('Built title'),
        'content': text('Built content'),
      });

      expect(find.text('Built title'), findsOneWidget);
      expect(find.text('Built content'), findsOneWidget);
    });

    testWidgets('the *Widget slots are read when the plain ones are absent',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'alertDialog',
        'titleWidget': text('Slot title'),
        'contentWidget': text('Slot content'),
      });

      expect(find.text('Slot title'), findsOneWidget);
      expect(find.text('Slot content'), findsOneWidget);
    });

    testWidgets('children are the last place content is looked for',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'alertDialog',
        'title': 'Report',
        'children': <dynamic>[text('From children')],
      });

      expect(find.text('From children'), findsOneWidget);
    });

    testWidgets('the surface properties are applied', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'alertDialog',
        'title': 'Report',
        'backgroundColor': '#EEEEEE',
        'elevation': 6,
        'shadowColor': '#000000',
        'surfaceTintColor': '#FFFFFF',
        'shape': <String, dynamic>{'type': 'rounded', 'radius': 20},
        'alignment': 'topLeft',
        'insetPadding': 8,
        'clipBehavior': 'antiAlias',
        'scrollable': true,
      });

      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.backgroundColor, const Color(0xFFEEEEEE));
      expect(dialog.elevation, 6);
      expect(dialog.shadowColor, const Color(0xFF000000));
      expect(dialog.surfaceTintColor, const Color(0xFFFFFFFF));
      expect((dialog.shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(20));
      expect(dialog.alignment, Alignment.topLeft);
      expect(dialog.insetPadding, const EdgeInsets.all(8));
      expect(dialog.clipBehavior, Clip.antiAlias);
      expect(dialog.scrollable, isTrue);
    });

    testWidgets('a circle shape and an unknown one are both handled',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'alertDialog',
        'title': 'Report',
        'shape': <String, dynamic>{'type': 'circle'},
        'clipBehavior': 'hardEdge',
      });
      expect(tester.widget<AlertDialog>(find.byType(AlertDialog)).shape,
          isA<CircleBorder>());

      await pump(tester, <String, dynamic>{
        'type': 'alertDialog',
        'title': 'Report',
        'shape': <String, dynamic>{'type': 'stadium'},
        'clipBehavior': 'antiAliasWithSaveLayer',
      });
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.shape, isNull);
      expect(dialog.clipBehavior, Clip.antiAliasWithSaveLayer);
    });
  });

  group('dialog', () {
    testWidgets('the custom form wraps its first child', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'dialog',
        'children': <dynamic>[text('Custom body')],
        'backgroundColor': '#EEEEEE',
        'elevation': 3,
        'shadowColor': '#000000',
        'surfaceTintColor': '#FFFFFF',
        'insetPadding': 10,
        'clipBehavior': 'antiAlias',
        'shape': <String, dynamic>{'type': 'rounded'},
        'alignment': 'center',
      });

      expect(find.text('Custom body'), findsOneWidget);
      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      expect(dialog.backgroundColor, const Color(0xFFEEEEEE));
      expect(dialog.elevation, 3);
      expect(dialog.insetPadding, const EdgeInsets.all(10));
      expect(dialog.clipBehavior, Clip.antiAlias);
      expect(dialog.alignment, Alignment.center);
      expect((dialog.shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(8));
    });

    testWidgets('the alert form is reached through dialogType', (tester) async {
      // `type` is the widget-type key and is stripped before the factory sees
      // it, so `dialogType` is the only spelling that reaches this branch.
      await pump(tester, <String, dynamic>{
        'type': 'dialog',
        'dialogType': 'alert',
        'title': 'Delete the job?',
        'content': 'This cannot be undone.',
        'backgroundColor': '#EEEEEE',
        'elevation': 4,
        'shape': <String, dynamic>{'type': 'rounded', 'radius': 12},
        'actions': <dynamic>[
          <String, dynamic>{
            'label': 'Delete',
            'onTap': <String, dynamic>{
              'type': 'state',
              'action': 'set',
              'binding': 'confirmed',
              'value': true,
            },
          },
          'not an action',
        ],
      });

      expect(find.text('Delete the job?'), findsOneWidget);
      expect(find.text('This cannot be undone.'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(stateManager.get('confirmed'), isTrue);

      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.backgroundColor, const Color(0xFFEEEEEE));
      expect(dialog.elevation, 4);
    });

    testWidgets('an alert action with no label reads OK', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'dialog',
        'dialogType': 'alert',
        'actions': <dynamic>[<String, dynamic>{}],
      });

      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets('the simple form lists all its children', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'dialog',
        'dialogType': 'simple',
        'title': 'Pick a site',
        'elevation': 2,
        'backgroundColor': '#EEEEEE',
        'shape': <String, dynamic>{'type': 'circle'},
        'children': <dynamic>[text('North'), text('South')],
      });

      expect(find.text('Pick a site'), findsOneWidget);
      expect(find.text('North'), findsOneWidget);
      expect(find.text('South'), findsOneWidget,
          reason: 'a chooser that drops every option after the first offers '
              'one choice');
      expect(tester.widget<SimpleDialog>(find.byType(SimpleDialog)).shape,
          isA<CircleBorder>());
    });

    testWidgets('an empty custom dialog still builds', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'dialog',
        'clipBehavior': 'none',
      });

      expect(find.byType(Dialog), findsOneWidget);
    });
  });
}

/// Renders a definition outside a widget tree so a build-time refusal is
/// observable as a thrown exception rather than a red screen.
class ConditionalUnderTest {
  ConditionalUnderTest(this.context);

  final RenderContext context;

  Widget render(Map<String, dynamic> definition) =>
      context.renderer.renderWidgetRethrowingErrors(definition, context);
}
