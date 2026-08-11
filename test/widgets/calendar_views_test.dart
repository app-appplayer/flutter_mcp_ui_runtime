// `calendar` in its week and day views.
//
// The month grid is the one everything else tests; the other two views are
// separate builders, and each carries the same tap-to-select path a document
// binds to. A week strip that shows dates and reports none is a picker that
// cannot pick.

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
        body: SizedBox(
          width: 400,
          height: 600,
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

  Map<String, dynamic> calendar({
    required String view,
    Map<String, dynamic> extra = const {},
  }) =>
      <String, dynamic>{
        'type': 'calendar',
        'view': view,
        'selectedDate': '2026-03-15',
        ...extra,
      };

  group('the week view', () {
    testWidgets('draws seven days around the selected one', (tester) async {
      await pump(tester, calendar(view: 'week'));

      // 2026-03-15 is a Sunday; the strip runs Monday..Sunday around it.
      expect(find.text('15'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a day reports it', (tester) async {
      await pump(tester, calendar(view: 'week', extra: <String, dynamic>{
        'onDateSelect': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'picked',
          'value': '{{event.value}}',
        },
      }));

      // 2026-03-15 is a Sunday, so the strip runs 15..21.
      await tester.tap(find.text('17').first);
      await tester.pumpAndSettle();

      expect(stateManager.get<String>('picked'), contains('2026-03-17'),
          reason: 'a week strip that shows dates and reports none is a picker '
              'that cannot pick');
    });
  });

  group('the day view', () {
    testWidgets('names the day, and says so when there is nothing on it',
        (tester) async {
      await pump(tester, calendar(view: 'day'));

      expect(find.text('No events'), findsOneWidget,
          reason: 'an empty day that draws an empty box reads as a day that '
              'failed to load');
      expect(find.byIcon(Icons.event_available), findsOneWidget);
    });

    testWidgets('lists the events on the selected day', (tester) async {
      await pump(tester, calendar(view: 'day', extra: <String, dynamic>{
        'events': <dynamic>[
          <String, dynamic>{
            'date': '2026-03-15',
            'title': 'Site visit',
          },
        ],
      }));

      expect(find.text('No events'), findsNothing);
      expect(find.text('Site visit'), findsOneWidget);
    });
  });

  group('date constraints', () {
    testWidgets('a date outside the declared range cannot be selected',
        (tester) async {
      await pump(tester, calendar(view: 'week', extra: <String, dynamic>{
        'firstDate': '2026-03-16',
        'lastDate': '2026-03-20',
        'onDateSelect': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'picked',
          'value': '{{event.value}}',
        },
      }));

      // 15 is before `firstDate`, and 21 is after `lastDate`.
      await tester.tap(find.text('15').first);
      await tester.pumpAndSettle();
      expect(stateManager.get('picked'), isNull);

      await tester.tap(find.text('21').first);
      await tester.pumpAndSettle();

      expect(stateManager.get('picked'), isNull,
          reason: 'the range is the document saying which days are bookable; '
              'reporting one outside it sends an invalid request');
    });
  });
}
