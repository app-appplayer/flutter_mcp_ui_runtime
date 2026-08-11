// A child declared into a slot its widget never reads draws nothing and says
// nothing.
//
// `{"type": "box", "content": {...}}` — `box` reads `child`, so the node was
// never mounted: no widget, no error, no pixels. Every downstream reading was
// consistent with it ("the surface is never called" → "the capability must be
// missing" → "the shared byte path is broken"), and a colleague spent a day
// walking that chain before finding the slot name. The runtime cannot render
// what it does not know about, but it can say that something was declared and
// dropped — §6.13's rule applied to a slot rather than to a capability.
//
// Reported, never rendered: drawing an error box here would change screens
// that carry harmless extra keys.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_mcp_ui_runtime/src/utils/mcp_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> warnings;

  setUp(() {
    warnings = <String>[];
    MCPLogger.onRecord = (record) {
      if (record.level == 'WARN') warnings.add(record.message);
    };
  });

  tearDown(() => MCPLogger.onRecord = null);

  Future<void> render(WidgetTester tester, Map<String, dynamic> content) async {
    final runtime = MCPUIRuntime();
    addTearDown(runtime.destroy);
    await runtime.initialize({'type': 'page', 'content': content});
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: runtime.buildUI())),
    );
    await tester.pump();
  }

  testWidgets('a widget in a slot the parent never reads is reported',
      (tester) async {
    await render(tester, {
      'type': 'box',
      'height': 100,
      // `box` takes `child`. This node is dropped.
      'content': {'type': 'text', 'content': 'invisible'},
    });

    expect(find.text('invisible'), findsNothing,
        reason: 'the premise: the node really is dropped');
    expect(
      warnings.where((w) => w.contains('box') && w.contains('content')),
      isNotEmpty,
      reason: 'silence is what made this cost a day',
    );
    expect(warnings.first, contains('takes `child`'),
        reason: 'the report should name the slot that would have worked');
  });

  testWidgets('the correct slot is not reported', (tester) async {
    await render(tester, {
      'type': 'box',
      'height': 100,
      'child': {'type': 'text', 'content': 'visible'},
    });

    expect(find.text('visible'), findsOneWidget);
    expect(warnings, isEmpty);
  });

  testWidgets('a non-widget value in an undeclared key is not reported',
      (tester) async {
    // Documents carry extra keys for their own reasons; only a DROPPED WIDGET
    // is worth a word.
    await render(tester, {
      'type': 'box',
      'height': 100,
      'analyticsId': 'hero-box',
      'child': {'type': 'text', 'content': 'visible'},
    });

    expect(find.text('visible'), findsOneWidget);
    expect(warnings, isEmpty);
  });

  testWidgets('it says it once, however many times the page repeats it',
      (tester) async {
    await render(tester, {
      'type': 'linear',
      'direction': 'vertical',
      'children': [
        {'type': 'box', 'content': {'type': 'text', 'content': 'a'}},
        {'type': 'box', 'content': {'type': 'text', 'content': 'b'}},
        {'type': 'box', 'content': {'type': 'text', 'content': 'c'}},
      ],
    });

    expect(warnings.where((w) => w.contains('content')).length, 1);
  });
}
