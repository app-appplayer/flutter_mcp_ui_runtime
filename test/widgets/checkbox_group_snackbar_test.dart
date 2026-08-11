// `checkboxGroup` (both binding shapes) and `snackbar`.
//
// The group has two ways to say what is selected — one list for the group, or
// a boolean per option — and a document written either way has to work. The
// snackbar is the one widget that shows itself: what it carries is an action
// the user taps once and cannot get back.

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

  group('checkboxGroup — one list for the group', () {
    Map<String, dynamic> group({Map<String, dynamic> extra = const {}}) =>
        <String, dynamic>{
          'type': 'checkboxGroup',
          'binding': 'chosen',
          'options': <dynamic>[
            <String, dynamic>{'value': 'a', 'label': 'Alpha'},
            <String, dynamic>{'value': 'b', 'label': 'Bravo'},
          ],
          ...extra,
        };

    testWidgets('the bound list decides what is ticked', (tester) async {
      stateManager.set('chosen', <dynamic>['b']);
      await pump(tester, group());

      final boxes = tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .map((c) => c.value)
          .toList();
      expect(boxes, <bool?>[false, true]);
    });

    testWidgets('ticking adds to the list and unticking removes from it',
        (tester) async {
      stateManager.set('chosen', <dynamic>[]);
      await pump(tester, group(extra: <String, dynamic>{
        'onChange': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'reported',
          'value': '{{event.value}}',
        },
      }));

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(stateManager.get('chosen'), <dynamic>['a']);
      expect(stateManager.get('reported'), <dynamic>['a'],
          reason: 'the whole selection is what a filter needs; reporting only '
              'the box that moved makes the caller rebuild the list');

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(stateManager.get('chosen'), isEmpty);
    });

    testWidgets('plain string options are their own value and label',
        (tester) async {
      stateManager.set('chosen', <dynamic>[]);
      await pump(tester, group(extra: <String, dynamic>{
        'options': <dynamic>['alpha', 'bravo'],
      }));

      expect(find.text('alpha'), findsOneWidget);

      await tester.tap(find.byType(Checkbox).last);
      await tester.pumpAndSettle();
      expect(stateManager.get('chosen'), <dynamic>['bravo']);
    });

    testWidgets('a horizontal group lays its boxes in a row', (tester) async {
      stateManager.set('chosen', <dynamic>[]);
      await pump(tester, group(extra: <String, dynamic>{
        'orientation': 'horizontal',
      }));

      expect(find.byType(Row), findsWidgets);
      expect(
          tester.getTopLeft(find.text('Bravo')).dx,
          greaterThan(tester.getTopLeft(find.text('Alpha')).dx),
          reason: 'a declared orientation that stacks anyway is the property '
              'doing nothing');
    });

    testWidgets('a disabled group takes no ticks', (tester) async {
      stateManager.set('chosen', <dynamic>[]);
      await pump(tester, group(extra: <String, dynamic>{'enabled': false}));

      expect(tester.widget<Checkbox>(find.byType(Checkbox).first).onChanged,
          isNull);
    });
  });

  group('checkboxGroup — a boolean per option', () {
    testWidgets('each option reads and writes its own binding', (tester) async {
      stateManager.set('wantsA', true);
      stateManager.set('wantsB', false);

      await pump(tester, <String, dynamic>{
        'type': 'checkboxGroup',
        'options': <dynamic>[
          <String, dynamic>{
            'value': 'a',
            'label': 'Alpha',
            'binding': 'wantsA',
          },
          <String, dynamic>{
            'value': 'b',
            'label': 'Bravo',
            'binding': 'wantsB',
          },
        ],
      });

      final boxes = tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .map((c) => c.value)
          .toList();
      expect(boxes, <bool?>[true, false],
          reason: 'the legacy shape is what already-shipped documents use; '
              'reading it as unchecked loses the user\'s stored answer');

      await tester.tap(find.byType(Checkbox).last);
      await tester.pumpAndSettle();
      expect(stateManager.get('wantsB'), isTrue);
    });

    testWidgets('an option with no binding at all is simply unticked',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'checkboxGroup',
        'options': <dynamic>[
          <String, dynamic>{'value': 'a', 'label': 'Alpha'},
        ],
      });

      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    });
  });

  group('snackbar', () {
    /// The factory schedules the snackbar for after the frame, so the tree
    /// has to be pumped once more before it is on screen.
    Future<void> show(
        WidgetTester tester, Map<String, dynamic> definition) async {
      await pump(tester, definition);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('shows its message, and its action reaches the document',
        (tester) async {
      await show(tester, <String, dynamic>{
        'type': 'snackBar',
        'content': 'Saved',
        'action': <String, dynamic>{
          'label': 'UNDO',
          'onTap': <String, dynamic>{
            'type': 'state',
            'action': 'set',
            'binding': 'undone',
            'value': true,
          },
        },
      });

      expect(find.text('Saved'), findsOneWidget);

      await tester.tap(find.text('UNDO'));
      await tester.pumpAndSettle();

      expect(stateManager.get('undone'), isTrue,
          reason: 'undo is the one chance a user has to take the action back; '
              'a button that does nothing is worse than no button');
    });

    testWidgets('an action with no handler is still tappable', (tester) async {
      await show(tester, <String, dynamic>{
        'type': 'snackBar',
        'content': 'Saved',
        'action': <String, dynamic>{'label': 'UNDO'},
      });

      await tester.tap(find.text('UNDO'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('onVisible fires when it appears', (tester) async {
      await show(tester, <String, dynamic>{
        'type': 'snackBar',
        'content': 'Saved',
        'onVisible': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'seen',
          'value': true,
        },
      });

      expect(stateManager.get('seen'), isTrue,
          reason: 'a document that logs what the user was actually shown has '
              'no other hook for it');
    });

    testWidgets('a rounded shape is built', (tester) async {
      await show(tester, <String, dynamic>{
        'type': 'snackBar',
        'content': 'Saved',
        'shape': <String, dynamic>{'type': 'rounded', 'radius': 12},
      });

      expect(tester.widget<SnackBar>(find.byType(SnackBar)).shape,
          isA<RoundedRectangleBorder>());
    });

    testWidgets('a stadium shape is built', (tester) async {
      // One per test: snackbars queue, so a second one raised in the same
      // test would still be waiting behind the first.
      await show(tester, <String, dynamic>{
        'type': 'snackBar',
        'content': 'Saved',
        'shape': <String, dynamic>{'type': 'stadium'},
      });

      expect(tester.widget<SnackBar>(find.byType(SnackBar)).shape,
          isA<StadiumBorder>());
    });

    testWidgets('a shape nobody defined leaves the default', (tester) async {
      await show(tester, <String, dynamic>{
        'type': 'snackBar',
        'content': 'Saved',
        'shape': <String, dynamic>{'type': 'beveled'},
      });

      expect(tester.widget<SnackBar>(find.byType(SnackBar)).shape, isNull);
    });

    testWidgets('the behaviour and dismiss direction are read', (tester) async {
      await show(tester, <String, dynamic>{
        'type': 'snackBar',
        'content': 'Saved',
        'behavior': 'floating',
        'dismissDirection': 'horizontal',
        'showCloseIcon': true,
        'closeIconColor': '#FF0000',
      });

      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.behavior, SnackBarBehavior.floating);
      expect(bar.dismissDirection, DismissDirection.horizontal);
      expect(bar.showCloseIcon, isTrue);
      expect(bar.closeIconColor, const Color(0xFFFF0000));
    });

  });
}
