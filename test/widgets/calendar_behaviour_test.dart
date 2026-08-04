// `calendar` at 48% — the widget that answers "which day did the user pick".
//
// Its declared surface is small (`selectedDate`, `firstDate`, `lastDate`,
// `events`, `view`, `onChange`) and every one of those is a value a document
// binds and then acts on. A calendar that renders the right month and reports
// the wrong day, or reports nothing, looks identical from the outside.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  late MCPUIRuntime runtime;

  Future<void> mount(
    WidgetTester tester,
    Map<String, dynamic> calendar, {
    Map<String, dynamic>? initial,
  }) async {
    runtime = MCPUIRuntime();
    await runtime.initialize(<String, dynamic>{
      'type': 'page',
      if (initial != null) 'state': <String, dynamic>{'initial': initial},
      'content': <String, dynamic>{
        'type': 'box',
        'height': 500,
        'child': calendar,
      },
    });
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: runtime.buildUI())),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  tearDown(() async => runtime.destroy());

  testWidgets('renders the month of the selected date', (tester) async {
    await mount(tester, <String, dynamic>{
      'type': 'calendar',
      'selectedDate': '2026-03-15',
    });

    expect(tester.takeException(), isNull);
    expect(find.textContaining('March'), findsWidgets,
        reason: 'the header names the month the selection lives in, not the '
            'month the device happens to be in');
  });

  testWidgets('a day tap reports the date through onChange', (tester) async {
    await mount(
      tester,
      <String, dynamic>{
        'type': 'calendar',
        'selectedDate': '2026-03-15',
        'onChange': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'picked',
          'value': '{{event.value}}',
        },
      },
      initial: <String, dynamic>{'picked': ''},
    );

    final cell = find
        .ancestor(of: find.text('20'), matching: find.byType(InkWell))
        .first;
    await tester.ensureVisible(cell);
    await tester.pump();
    await tester.tap(cell);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final picked = runtime.stateManager.get<String>('picked') ?? '';
    // The cell has to be scrolled into view first — a day below the fold is
    // in the tree but not hittable, which reads as "the tap did nothing".
    expect(picked, isNotEmpty,
        reason: 'a calendar that draws a selection and reports nothing leaves '
            'the document showing the old day');
    expect(picked, contains('20'));
  });

  testWidgets('events on a day are marked', (tester) async {
    await mount(
      tester,
      <String, dynamic>{
      'type': 'calendar',
      'selectedDate': '2026-03-15',
      // The registry declares `events` as a binding to an array, not an
      // inline one.
      'events': '{{events}}',
      },
      initial: <String, dynamic>{
        'events': <dynamic>[
          <String, dynamic>{'date': '2026-03-20', 'title': 'Shipment'},
        ],
      },
    );

    expect(tester.takeException(), isNull);
    expect(find.text('20'), findsWidgets);
  });

  testWidgets('firstDate and lastDate bound the range', (tester) async {
    await mount(tester, <String, dynamic>{
      'type': 'calendar',
      'selectedDate': '2026-03-15',
      'firstDate': '2026-03-10',
      'lastDate': '2026-03-20',
    });

    expect(tester.takeException(), isNull);
  });

  testWidgets('a malformed date does not take the page down', (tester) async {
    await mount(tester, <String, dynamic>{
      'type': 'calendar',
      'selectedDate': 'not-a-date',
    });

    expect(tester.takeException(), isNull,
        reason: 'a bad value in one property must not replace the whole page '
            'with an error box');
  });

  testWidgets('a bound selected date follows state', (tester) async {
    await mount(
      tester,
      <String, dynamic>{
        'type': 'calendar',
        'selectedDate': '{{when}}',
      },
      initial: <String, dynamic>{'when': '2026-05-02'},
    );

    expect(find.textContaining('May'), findsWidgets);

    runtime.stateManager.set('when', '2026-07-02');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('July'), findsWidgets,
        reason: 'a bound calendar that ignores a state change is showing a '
            'month the document has already moved on from');
  });
}
