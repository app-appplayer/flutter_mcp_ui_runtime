// `lazy` implements all three things it declares.
//
// §10.22 gives `content` two forms — an inline widget and
// `{ source: "ui://..." }` naming a fragment to fetch — and declares `onLoad`
// (after content materializes) and `onError` (if the fetch fails). Only the
// inline form was implemented: a source was handed to the renderer as-is,
// which answered `Widget type is required` because a source is not a widget.
// `onLoad` and `onError` were read into locals and silenced with an
// `unused_local_variable` ignore, so a document declaring them waited for
// something that never came.
//
// This surfaced only after the union-branch harness stopped waiting a fixed
// 50 ms and started settling: `lazy` materializes after a post-frame
// callback, so the failure arrived a frame later than the assertion did.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

Future<void> _pump(WidgetTester tester, MCPUIRuntime runtime) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: runtime.buildUI())),
  );
  try {
    await tester.pumpAndSettle(const Duration(milliseconds: 16));
  } catch (_) {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }
}

void main() {
  testWidgets('an inline content widget still renders', (tester) async {
    final runtime = MCPUIRuntime();
    await runtime.initialize(<String, dynamic>{
      'type': 'page',
      'content': <String, dynamic>{
        'type': 'lazy',
        'trigger': 'immediate',
        'content': <String, dynamic>{'type': 'text', 'content': 'heavy'},
      },
    });
    await _pump(tester, runtime);
    expect(find.text('heavy'), findsOneWidget);
    await runtime.dispose();
  });

  testWidgets('a source form does not reach the renderer as a widget',
      (tester) async {
    final runtime = MCPUIRuntime();
    await runtime.initialize(
      <String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{
          'type': 'lazy',
          'trigger': 'immediate',
          'content': <String, dynamic>{'source': 'ui://pages/heavy'},
        },
      },
    );
    await _pump(tester, runtime);

    // The exact resolution needs a definition resolver the host injects, so
    // what is pinned here is that the source is no longer mistaken for a
    // widget definition — that error was the whole defect.
    expect(find.textContaining('Widget type is required'), findsNothing);
    await runtime.dispose();
  });

  testWidgets('onLoad fires once the content is materialized', (tester) async {
    final fired = <String>[];
    final runtime = MCPUIRuntime();
    await runtime.initialize(
      <String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{
          'type': 'lazy',
          'trigger': 'immediate',
          'content': <String, dynamic>{'type': 'text', 'content': 'heavy'},
          'onLoad': <String, dynamic>{'type': 'tool', 'tool': 'loaded'},
        },
      },
      onToolCall: (tool, params) async {
        fired.add(tool);
        return <String, dynamic>{};
      },
    );
    await _pump(tester, runtime);
    expect(fired, <String>['loaded']);
    await runtime.dispose();
  });

  testWidgets('the default visible trigger materializes once, not per frame',
      (tester) async {
    // `visible` schedules a post-frame callback from inside `build`, so
    // without the idempotence guard every frame would re-render the content
    // and re-fire `onLoad` for as long as the widget is on screen.
    final fired = <String>[];
    final runtime = MCPUIRuntime();
    await runtime.initialize(
      <String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{
          'type': 'lazy',
          'content': <String, dynamic>{'type': 'text', 'content': 'heavy'},
          'onLoad': <String, dynamic>{'type': 'tool', 'tool': 'loaded'},
        },
      },
      onToolCall: (tool, params) async {
        fired.add(tool);
        return <String, dynamic>{};
      },
    );
    await _pump(tester, runtime);
    expect(find.text('heavy'), findsOneWidget,
        reason: 'the default trigger has to actually load');
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(fired, <String>['loaded']);
    await runtime.dispose();
  });

  testWidgets('onLoad fires once, not on every rebuild', (tester) async {
    final fired = <String>[];
    final runtime = MCPUIRuntime();
    await runtime.initialize(
      <String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{
          'type': 'lazy',
          'trigger': 'immediate',
          'content': <String, dynamic>{'type': 'text', 'content': 'heavy'},
          'onLoad': <String, dynamic>{'type': 'tool', 'tool': 'loaded'},
        },
      },
      onToolCall: (tool, params) async {
        fired.add(tool);
        return <String, dynamic>{};
      },
    );
    await _pump(tester, runtime);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(fired, <String>['loaded'],
        reason: 'materialization happens once — so does the hook');
    await runtime.dispose();
  });
}
