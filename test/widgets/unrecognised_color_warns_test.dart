// A colour string that matches nothing says so.
//
// `parseColor` returned null for an unrecognised name and the widget drew
// with no colour at all. Found on a live marketplace shelf: two bundles used
// `color: "tomato"`, passed publish, approval, purchase and install, and drew
// an uncoloured box on the buyer's screen with nothing anywhere to read.
//
// `Color` takes hex, the ten basic names, and the Material 3 scheme slots;
// §5.3.4 says CSS keyword colours are not canonical, so `tomato` is a
// document error. The schema rejects it — but only where a document is
// validated, and an installed bundle reaches the screen without that check.
// The warning is what makes the screen legible when it does.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_mcp_ui_runtime/src/utils/color_parser.dart';

Future<List<MCPLogRecord>> _render(
  WidgetTester tester,
  Map<String, dynamic> content,
) async {
  DslColor.resetWarnings();
  final records = <MCPLogRecord>[];
  MCPLogger.onRecord = records.add;
  addTearDown(() => MCPLogger.onRecord = null);

  final runtime = MCPUIRuntime();
  await runtime.initialize(
    <String, dynamic>{'type': 'page', 'content': content},
    validateSchema: false, // the point is the path that skips validation
  );
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: runtime.buildUI())),
  );
  await tester.pump(const Duration(milliseconds: 50));
  addTearDown(runtime.dispose);
  return records;
}

void main() {
  testWidgets('an unrecognised name is reported', (tester) async {
    final records = await _render(tester, <String, dynamic>{
      'type': 'box',
      'height': 40,
      'color': 'tomato',
      'child': <String, dynamic>{'type': 'text', 'content': 'x'},
    });

    final warning = records
        .where((r) => r.message.contains('tomato'))
        .map((r) => r.message)
        .join('\n');
    expect(warning, isNotEmpty,
        reason: 'the screen was the only place this showed, and it showed '
            'nothing');
    expect(warning, contains('#RRGGBB'));
    expect(warning, contains('primary'),
        reason: 'the scheme slot is the answer for a colour that should '
            'follow light / dark mode');
  });

  testWidgets('a name the spec accepts is silent', (tester) async {
    for (final value in <String>['red', 'gray', '#0af', '#2196F3']) {
      final records = await _render(tester, <String, dynamic>{
        'type': 'box',
        'height': 40,
        'color': value,
        'child': <String, dynamic>{'type': 'text', 'content': 'x'},
      });
      expect(records.where((r) => r.message.contains('is not a color the DSL accepts')),
          isEmpty,
          reason: '$value is legal and must not be warned about');
    }
  });

  testWidgets('a scheme slot is silent', (tester) async {
    final records = await _render(tester, <String, dynamic>{
      'type': 'box',
      'height': 40,
      'color': 'primary',
      'child': <String, dynamic>{'type': 'text', 'content': 'x'},
    });
    expect(records.where((r) => r.message.contains('is not a color the DSL accepts')),
        isEmpty);
  });

  testWidgets('the same value is reported once, not per frame',
      (tester) async {
    // Distinct definitions carrying the same colour. Identical siblings do
    // not exercise this: the renderer caches by definition, so the second box
    // never reaches `parseColor` at all — a version of this test with three
    // identical boxes passed with the guard removed.
    final records = await _render(tester, <String, dynamic>{
      'type': 'linear',
      'children': <Object>[
        <String, dynamic>{'type': 'box', 'height': 10, 'color': 'tomato'},
        <String, dynamic>{'type': 'box', 'height': 20, 'color': 'tomato'},
        <String, dynamic>{
          'type': 'text',
          'content': 'x',
          'style': <String, dynamic>{'color': 'tomato'},
        },
      ],
    });
    // Filtered on the warning itself: the renderer debug-logs each
    // definition, and those carry the value too.
    expect(
        records.where((r) =>
            r.message.contains('tomato') &&
            r.message.contains('is not a color the DSL accepts')),
        hasLength(1),
        reason: 'a colour is read on every rebuild — a per-frame log is a log '
            'nobody reads');
  });
}
