// `dateField` — the third of the three pickers, and the same shape as the
// other two: everything it does happens after a tap.
//
// The format tokens matter most. The field SHOWS a formatted date and WRITES
// the same string back through the binding, so a token the runtime does not
// apply is a value the document's own server cannot parse.

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

  Map<String, dynamic> field({Map<String, dynamic> extra = const {}}) => {
        'type': 'dateField',
        'binding': 'startsOn',
        ...extra,
      };

  /// Opens the picker, chooses [day] in the shown month, and accepts.
  Future<void> pickDay(WidgetTester tester, String day) async {
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.tap(find.text(day).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  group('what it shows', () {
    testWidgets('the bound value, with a label and the calendar affordance',
        (tester) async {
      stateManager.set('startsOn', '2026-03-15');
      await pump(tester, field(extra: {'label': 'Starts on'}));

      expect(find.text('2026-03-15'), findsOneWidget);
      expect(find.text('Starts on'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    });

    testWidgets('an errorText', (tester) async {
      await pump(tester, field(extra: {'errorText': 'Pick a weekday'}));
      expect(find.text('Pick a weekday'), findsOneWidget);
    });

    testWidgets('disabled refuses to open', (tester) async {
      await pump(tester, field(extra: {'enabled': false}));

      await tester.tap(find.byType(TextField), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('OK'), findsNothing);
    });
  });

  group('picking a date', () {
    testWidgets('writes it back through the binding, in the default format',
        (tester) async {
      stateManager.set('startsOn', '2026-03-15');
      await pump(tester, field());

      await pickDay(tester, '20');

      expect(stateManager.get('startsOn'), '2026-03-20');
      expect(find.text('2026-03-20'), findsOneWidget,
          reason: 'the field has to show what it just wrote, or the next tap '
              'opens on the old date');
    });

    testWidgets('the declared format is what gets written', (tester) async {
      stateManager.set('startsOn', '2026-03-15');
      await pump(tester, field(extra: {'format': 'dd/MM/yyyy'}));

      await pickDay(tester, '20');

      expect(stateManager.get('startsOn'), '20/03/2026',
          reason: 'the field writes the string its own server parses; a '
              'dropped token is a value that server rejects');
    });

    testWidgets('the short tokens are honoured', (tester) async {
      stateManager.set('startsOn', '2026-03-15');
      await pump(tester, field(extra: {'format': 'yy-M-d'}));

      await pickDay(tester, '20');

      expect(stateManager.get('startsOn'), '26-3-20');
    });

    testWidgets('cancelling writes nothing', (tester) async {
      stateManager.set('startsOn', '2026-03-15');
      await pump(tester, field());

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(stateManager.get('startsOn'), '2026-03-15');
    });

    testWidgets('an unparseable stored value opens on today rather than failing',
        (tester) async {
      stateManager.set('startsOn', 'next Tuesday');
      await pump(tester, field());

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(find.text('OK'), findsOneWidget,
          reason: 'state written by an earlier version of a document is '
              'ordinary; refusing to open leaves the user unable to fix it');

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('a stored date before the range opens at the range start',
        (tester) async {
      stateManager.set('startsOn', '2020-01-01');
      await pump(tester, field(extra: {
        'firstDate': '2026-03-01',
        'lastDate': '2026-03-31',
      }));

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(find.textContaining('March'), findsWidgets,
          reason: 'opening on a date outside the range is an assertion in the '
              'Material picker, so the field has to clamp before it opens');

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('a stored date after the range opens at the range end',
        (tester) async {
      stateManager.set('startsOn', '2030-01-01');
      await pump(tester, field(extra: {
        'firstDate': '2026-03-01',
        'lastDate': '2026-03-31',
      }));

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.text('OK'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('the input entry mode opens the keyboard form', (tester) async {
      await pump(tester, field(extra: {'mode': 'input'}));

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(find.byType(TextField).evaluate().length, greaterThan(1),
          reason: '§2.6.13 — a declared entry mode that always opens the '
              'calendar makes the property decorative');

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });
}
