// The deprecation warning goes to the author who would break.
//
// It used to fire where the mirror is written — on every successful tool call.
// konpi saw it, went looking through their own screens for a `tools.` read,
// and found none: they use auto-merge only. The warning reached an author who
// could not act on it, and the author who *does* read the namespace heard
// nothing, because reading a value that is present succeeds quietly. When the
// mirror goes, that second author is the one whose document stops resolving.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  late List<MCPLogRecord> records;

  List<MCPLogRecord> mirrorWarnings() => records
      .where((r) =>
          r.level == 'WARN' && r.message.contains('legacy namespaced'))
      .toList();

  setUp(() {
    records = <MCPLogRecord>[];
    MCPLogger.onRecord = records.add;
  });

  tearDown(() => MCPLogger.onRecord = null);

  testWidgets('writing the mirror is not the author\'s doing, so it is silent',
      (tester) async {
    // Auto-merge is the recommended path and the common one; an author on it
    // has nothing to change and should hear nothing.
    final runtime = MCPUIRuntime();
    await runtime.initialize(<String, dynamic>{
      'type': 'page',
      'content': <String, dynamic>{'type': 'text', 'content': 'x'},
    }, useCache: false);
    runtime.stateManager.set(
      'tools.menu.list.result',
      <String, dynamic>{'items': 'ok'},
    );
    await runtime.dispose();

    expect(mirrorWarnings(), isEmpty);
  });

  testWidgets('reading the mirror warns, once per path', (tester) async {
    final runtime = MCPUIRuntime();
    await runtime.initialize(<String, dynamic>{
      'type': 'page',
      'content': <String, dynamic>{
        'type': 'text',
        'content': '{{tools.menu.list.result.items}}',
      },
    }, useCache: false);
    runtime.stateManager.set(
      'tools.menu.list.result',
      <String, dynamic>{'items': 'ok'},
    );
    // Rendered twice on purpose: a screen that reads it every frame must not
    // fill the log with one line per frame.
    await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
    await tester.pump(const Duration(milliseconds: 50));
    runtime.stateManager.set('unrelated', 1);
    await tester.pump(const Duration(milliseconds: 50));
    await runtime.dispose();

    expect(mirrorWarnings(), hasLength(1));
    expect(mirrorWarnings().single.message, contains('tools.menu.list.result'));
    expect(mirrorWarnings().single.message, contains('bindResult'));
  });
}
