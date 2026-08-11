// `dateRangePicker` (37%) and `voiceInput` (37%) — two widgets whose covered
// third was the part that draws, and whose uncovered two thirds was everything
// that happens after a tap.
//
// The range picker is driven all the way through the Material dialog: open,
// pick two days, save, and read what was written back — because the format
// tokens, the two state paths and the `onChange` payload are all downstream of
// the dialog returning, and nothing before that point proves any of them.
//
// `voiceInput` is a Client Profile widget with no native capture. Under the VM
// `speechSupported` is false, so the reachable behaviour is the refusal: the
// control must say it cannot run rather than render a microphone that does
// nothing. The listening state (waveform, stop button, transcript) belongs to
// the web branch and cannot be reached from a VM test — noted here rather than
// faked, since a fake would prove nothing about the branch that ships.

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

  group('dateRangePicker', () {
    Map<String, dynamic> picker({Map<String, dynamic> extra = const {}}) => {
          'type': 'dateRangePicker',
          'startDate': 'from',
          'endDate': 'to',
          'firstDate': '2026-01-01',
          'lastDate': '2026-12-31',
          ...extra,
        };

    testWidgets('with nothing chosen it invites a choice', (tester) async {
      await pump(tester, picker());

      expect(find.text('Select date range'), findsOneWidget);
      expect(find.byIcon(Icons.date_range), findsOneWidget);
    });

    testWidgets('an existing range is shown as a range', (tester) async {
      stateManager.set('from', '2026-03-01');
      stateManager.set('to', '2026-03-08');
      await pump(tester, picker());

      expect(find.text('2026-03-01 - 2026-03-08'), findsOneWidget,
          reason: 'a filter that shows "Select date range" while a range is '
              'applied tells the user the opposite of what is true');
    });

    testWidgets('only a start date is not yet a range', (tester) async {
      stateManager.set('from', '2026-03-01');
      await pump(tester, picker());

      expect(find.text('Select date range'), findsOneWidget);
    });

    testWidgets('a label and an errorText are shown', (tester) async {
      await pump(tester, picker(extra: {
        'label': 'Reporting period',
        'errorText': 'Pick a period under 90 days',
      }));

      expect(find.text('Reporting period'), findsOneWidget);
      expect(find.text('Pick a period under 90 days'), findsOneWidget);
    });

    testWidgets('picking a range writes both paths and fires onChange',
        (tester) async {
      stateManager.set('from', '2026-03-10');
      stateManager.set('to', '2026-03-12');
      await pump(tester, picker(extra: {
        'onChange': {
          'type': 'state',
          'action': 'set',
          'binding': 'picked',
          'value': '{{event.value}}',
        },
      }));

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      // The Material range picker opens on the month of the initial range.
      await tester.tap(find.text('15').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('18').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(stateManager.get('from'), '2026-03-15');
      expect(stateManager.get('to'), '2026-03-18',
          reason: 'both ends have to land, or the query runs against half the '
              'range the user chose');
      expect(stateManager.get('picked'),
          {'start': '2026-03-15', 'end': '2026-03-18'});
    });

    testWidgets('the declared format is what gets written', (tester) async {
      stateManager.set('from', '2026-03-10');
      stateManager.set('to', '2026-03-12');
      await pump(tester, picker(extra: {'format': 'dd/MM/yyyy'}));

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('18').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(stateManager.get('from'), '15/03/2026',
          reason: 'the format the document declared is the one its server '
              'parses');
    });

    testWidgets('the short format tokens are honoured too', (tester) async {
      stateManager.set('from', '2026-03-10');
      stateManager.set('to', '2026-03-12');
      await pump(tester, picker(extra: {'format': 'yy-M-d'}));

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('18').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(stateManager.get('from'), '26-3-15');
    });

    testWidgets('cancelling writes nothing', (tester) async {
      stateManager.set('from', '2026-03-10');
      stateManager.set('to', '2026-03-12');
      await pump(tester, picker());

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(stateManager.get('from'), '2026-03-10',
          reason: 'a cancelled dialog that still commits is a change the user '
              'explicitly declined');
    });

    testWidgets('the legacy startBinding/endBinding spellings still bind',
        (tester) async {
      stateManager.set('from', '2026-03-01');
      stateManager.set('to', '2026-03-08');
      await pump(tester, {
        'type': 'dateRangePicker',
        'startBinding': 'from',
        'endBinding': 'to',
      });

      expect(find.text('2026-03-01 - 2026-03-08'), findsOneWidget);
    });

    testWidgets('disabled refuses to open', (tester) async {
      await pump(tester, picker(extra: {'enabled': false}));

      await tester.tap(find.byType(InkWell), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Save'), findsNothing);
    });

    testWidgets('an unparseable stored date does not block the picker',
        (tester) async {
      stateManager.set('from', 'yesterday');
      stateManager.set('to', 'tomorrow');
      await pump(tester, picker(extra: {
        'firstDate': 'not a date',
        'lastDate': 'also not a date',
      }));

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      expect(find.text('Save'), findsOneWidget,
          reason: 'state written by an earlier version of a document is '
              'ordinary; the picker has to open anyway');
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    });
  });

  group('voiceInput', () {
    testWidgets('offers a microphone', (tester) async {
      await pump(tester, {'type': 'voiceInput', 'binding': 'transcript'});

      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.text('Listening'), findsNothing);
    });

    testWidgets('says it cannot run rather than doing nothing', (tester) async {
      await pump(tester, {
        'type': 'voiceInput',
        'binding': 'transcript',
        'onError': {
          'type': 'state',
          'action': 'set',
          'binding': 'problem',
          'value': '{{event.message}}',
        },
      });

      await tester.tap(find.byIcon(Icons.mic));
      await tester.pumpAndSettle();

      expect(stateManager.get<String>('problem'), contains('not available'),
          reason: '§6.13 — a control that renders and silently does nothing is '
              'the failure this widget exists to avoid');
      expect(find.byIcon(Icons.mic), findsOneWidget,
          reason: 'it must not enter a listening state it cannot leave');
    });

    testWidgets('a refusal does not fire onStart', (tester) async {
      await pump(tester, {
        'type': 'voiceInput',
        'onStart': {
          'type': 'state',
          'action': 'set',
          'binding': 'started',
          'value': true,
        },
        'onError': {
          'type': 'state',
          'action': 'set',
          'binding': 'problem',
          'value': '{{event.message}}',
        },
      });

      await tester.tap(find.byIcon(Icons.mic));
      await tester.pumpAndSettle();

      expect(stateManager.get('started'), isNull,
          reason: 'onStart is the document\'s cue that the room is being '
              'recorded — firing it when nothing started is the worst possible '
              'direction for that error');
    });

    testWidgets('with no onError the refusal is still not a crash',
        (tester) async {
      await pump(tester, {'type': 'voiceInput'});

      await tester.tap(find.byIcon(Icons.mic));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('disabled offers no microphone to press', (tester) async {
      await pump(tester, {
        'type': 'voiceInput',
        'enabled': false,
        'onError': {
          'type': 'state',
          'action': 'set',
          'binding': 'problem',
          'value': '{{event.message}}',
        },
      });

      expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed,
          isNull);
      await tester.tap(find.byIcon(Icons.mic), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(stateManager.get('problem'), isNull);
    });

    testWidgets('the tooltip names the action', (tester) async {
      await pump(tester, {'type': 'voiceInput'});

      expect(
          tester.widget<IconButton>(find.byType(IconButton)).tooltip,
          'Start voice input');
    });

    testWidgets('the declared options survive to the widget', (tester) async {
      // Language, continuous capture, interim results and the duration
      // ceiling only take effect once capture starts, which this platform
      // cannot do. What is checkable here is that they are accepted and the
      // control still builds — a widget that threw on `maxDuration` would
      // take the page with it.
      await pump(tester, {
        'type': 'voiceInput',
        'binding': 'transcript',
        'language': 'ko-KR',
        'continuous': true,
        'interimResults': true,
        'maxDuration': 30,
        'showWaveform': false,
      });

      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
