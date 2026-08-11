// `timeField` (36%) and `errorBoundary` (27%).
//
// The time field's whole job happens after a tap — open the picker, read what
// was chosen, write it back in the declared format — and none of that had run.
// The error boundary's whole job happens after a failure, and neither had
// that.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/widgets/widget_factory.dart';
import 'package:flutter_test/flutter_test.dart';

/// A widget type that throws while building.
class _ExplodingFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) =>
      throw StateError('the child could not be built');
}

void main() {
  late StateManager stateManager;
  late RenderContext context;

  setUp(() {
    stateManager = StateManager()..initialize(<String, dynamic>{});
    final registry = WidgetRegistry();
    DefaultWidgets.registerAll(registry);
    registry.register('explodes', _ExplodingFactory());
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

  group('timeField', () {
    Map<String, dynamic> field({Map<String, dynamic> extra = const {}}) => {
          'type': 'timeField',
          'binding': 'startsAt',
          ...extra,
        };

    testWidgets('shows the bound value', (tester) async {
      stateManager.set('startsAt', '09:30');
      await pump(tester, field(extra: {'label': 'Starts at'}));

      expect(find.text('09:30'), findsOneWidget);
      expect(find.text('Starts at'), findsOneWidget);
      expect(find.byIcon(Icons.access_time), findsOneWidget);
    });

    testWidgets('an errorText is shown', (tester) async {
      await pump(tester, field(extra: {'errorText': 'Outside opening hours'}));

      expect(find.text('Outside opening hours'), findsOneWidget);
    });

    testWidgets('tapping opens the picker and the choice is written back',
        (tester) async {
      stateManager.set('startsAt', '09:30');
      await pump(tester, field());

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // The picker opens on the bound time; accepting it writes that time
      // back through the binding.
      expect(find.text('OK'), findsOneWidget,
          reason: 'a field that cannot open its picker is a read-only label');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(stateManager.get('startsAt'), '09:30');
    });

    testWidgets('cancelling writes nothing', (tester) async {
      stateManager.set('startsAt', '09:30');
      await pump(tester, field());

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(stateManager.get('startsAt'), '09:30');
    });

    testWidgets('the input entry mode is honoured', (tester) async {
      await pump(tester, field(extra: {'mode': 'input'}));

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // Keyboard entry mode puts editable fields on the dialog rather than a
      // clock face.
      expect(find.byType(TextField).evaluate().length, greaterThan(1),
          reason: '§2.6.14 — a declared entry mode that always opens the dial '
              'makes the property decorative');

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('the dial mode opens the clock face', (tester) async {
      await pump(tester, field(extra: {'mode': 'dial'}));

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.text('OK'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('a 24-hour field shows no AM/PM control', (tester) async {
      await pump(tester, field(extra: {'use24HourFormat': true}));

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(find.text('AM'), findsNothing,
          reason: 'a 24-hour document showing a meridiem toggle is offering a '
              'choice its format cannot express');

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('an unparseable stored value does not block the picker',
        (tester) async {
      stateManager.set('startsAt', 'half past nine');
      await pump(tester, field());

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(find.text('OK'), findsOneWidget,
          reason: 'state written by an earlier version of a document is '
              'ordinary; the picker opens on now instead');

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('disabled refuses to open', (tester) async {
      await pump(tester, field(extra: {'enabled': false}));

      await tester.tap(find.byType(TextField), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('OK'), findsNothing);
    });
  });

  group('errorBoundary', () {
    testWidgets('a child that builds is left alone', (tester) async {
      await pump(tester, {
        'type': 'errorBoundary',
        'content': {'type': 'text', 'content': 'the content'},
      });

      expect(find.text('the content'), findsOneWidget);
    });

    testWidgets('with no child it draws nothing', (tester) async {
      await pump(tester, {'type': 'errorBoundary'});

      expect(tester.takeException(), isNull);
    });

    testWidgets('a child that throws is replaced by the default surface',
        (tester) async {
      await pump(tester, {
        'type': 'errorBoundary',
        'child': {'type': 'explodes'},
      });

      expect(find.text('Something went wrong'), findsOneWidget,
          reason: 'this is the whole widget — without it the exception '
              'reaches the framework and paints a red box');
    });

    testWidgets('a declared fallback replaces the default surface',
        (tester) async {
      await pump(tester, {
        'type': 'errorBoundary',
        'child': {'type': 'explodes'},
        'fallback': {'type': 'text', 'content': 'Try again in a moment'},
      });

      expect(find.text('Try again in a moment'), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing);
    });

    testWidgets('a fallback that itself fails falls back again',
        (tester) async {
      await pump(tester, {
        'type': 'errorBoundary',
        'child': {'type': 'explodes'},
        'fallback': {'type': 'explodes'},
      });

      expect(find.text('Something went wrong'), findsOneWidget,
          reason: 'a failing fallback must not escalate past the boundary it '
              'was written to hold');
    });

    testWidgets('onError fires once, not on every rebuild', (tester) async {
      await pump(tester, {
        'type': 'errorBoundary',
        'child': {'type': 'explodes'},
        'onError': {
          'type': 'state',
          'action': 'increment',
          'binding': 'reports',
          'value': 1,
        },
      });

      stateManager.set('unrelated', 1);
      await tester.pumpAndSettle();
      stateManager.set('unrelated', 2);
      await tester.pumpAndSettle();

      expect(stateManager.get('reports'), 1,
          reason: '§2.13.11 — an onError that fires on every rebuild turns one '
              'failure into a stream of reports to the server');
    });
  });
}
