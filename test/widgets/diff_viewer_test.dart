/// `diffViewer` rendering — spec §10.26.
///
/// The diff itself is the part worth pinning: an LCS that drifts produces a
/// comparison that looks plausible and attributes changes to the wrong lines,
/// which is a worse failure than not rendering.
library diff_viewer_test;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Map<String, dynamic> widgetDef,
  ) async {
    final runtime = MCPUIRuntime();
    await runtime.initialize({'type': 'page', 'content': widgetDef});
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: runtime.buildUI())),
    );
    await tester.pump();
  }

  Map<String, dynamic> diff(String a, String b, {bool split = true}) => {
        'type': 'diffViewer',
        'oldValue': a,
        'newValue': b,
        'splitView': split,
      };

  testWidgets('identical documents show every line once, unmarked',
      (tester) async {
    await pump(tester, diff('a\nb\nc', 'a\nb\nc', split: false));
    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
    expect(find.text('c'), findsOneWidget);
    // No add/remove gutters when nothing changed.
    expect(find.text('+ '), findsNothing);
    expect(find.text('- '), findsNothing);
  });

  testWidgets('an inserted line is marked added, not as a rewrite',
      (tester) async {
    // The LCS test: a naive line-by-line comparison reports b->x and c->b and
    // a trailing add, marking three lines changed instead of one.
    await pump(tester, diff('a\nc', 'a\nb\nc', split: false));
    expect(find.text('+ '), findsOneWidget);
    expect(find.text('- '), findsNothing);
    expect(find.text('b'), findsOneWidget);
  });

  testWidgets('a deleted line is marked removed', (tester) async {
    await pump(tester, diff('a\nb\nc', 'a\nc', split: false));
    expect(find.text('- '), findsOneWidget);
    expect(find.text('+ '), findsNothing);
  });

  testWidgets('a replaced line is one removal and one addition',
      (tester) async {
    await pump(tester, diff('a\nb\nc', 'a\nx\nc', split: false));
    expect(find.text('- '), findsOneWidget);
    expect(find.text('+ '), findsOneWidget);
  });

  testWidgets('split view renders both sides', (tester) async {
    await pump(tester, diff('a\nb', 'a\nc'));
    // Old-only and new-only lines both appear, on their own sides.
    expect(find.text('b'), findsOneWidget);
    expect(find.text('c'), findsOneWidget);
    expect(find.byType(VerticalDivider), findsWidgets);
  });

  testWidgets('contextLines elides unchanged runs', (tester) async {
    final long = List.generate(30, (i) => 'line$i').join('\n');
    final changed = long.replaceFirst('line15', 'CHANGED');
    await pump(tester, {
      'type': 'diffViewer',
      'oldValue': long,
      'newValue': changed,
      'splitView': false,
      'contextLines': 2,
    });
    expect(find.text('CHANGED'), findsOneWidget);
    // Distant unchanged lines are collapsed rather than rendered.
    expect(find.text('line0'), findsNothing);
    expect(find.text('…'), findsWidgets);
  });

  testWidgets('empty inputs render without throwing', (tester) async {
    await pump(tester, diff('', ''));
    expect(tester.takeException(), isNull);
  });

  testWidgets('line numbers can be turned off', (tester) async {
    await pump(tester, {
      'type': 'diffViewer',
      'oldValue': 'a',
      'newValue': 'b',
      'splitView': false,
      'showLineNumbers': false,
    });
    expect(tester.takeException(), isNull);
  });
}
