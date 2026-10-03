// `flow.alignment` places each run within the main axis (registry: `start`,
// `center`, `end`; default `start`). It was stored and compared for repaint
// and never used for placement, so every value drew as `start`.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/mcp_ui_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Left edges of the boxes `b0`…, drawn in a 300-wide flow.
  Future<List<double>> lefts(WidgetTester tester, String? alignment,
      {int count = 2, String direction = 'horizontal'}) async {
    final runtime = MCPUIRuntime(enableDebugMode: false);
    addTearDown(runtime.dispose);
    await runtime.initialize({
      'type': 'page',
      'content': {
        'type': 'sizedBox',
        'width': 300,
        'height': 300,
        'child': {
          'type': 'flow',
          'spacing': 10,
          'direction': direction,
          if (alignment != null) 'alignment': alignment,
          'children': [
            for (var i = 0; i < count; i++)
              {
                'type': 'sizedBox',
                'width': 100,
                'height': 100,
                'child': {'type': 'text', 'content': 'b$i'},
              },
          ],
        },
      },
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Align(alignment: Alignment.topLeft, child: runtime.buildUI()))));
    await tester.pump();
    final origin = tester.getTopLeft(find.byType(Wrap)).dx;
    return [
      for (var i = 0; i < count; i++)
        tester.getTopLeft(find.text('b$i')).dx - origin,
    ];
  }

  // Two 100-wide boxes with a 10 gap take 210 of 300: 90 left over.
  testWidgets('start (the default)', (tester) async {
    expect(await lefts(tester, null), [0, 110]);
  });

  testWidgets('center', (tester) async {
    expect(await lefts(tester, 'center'), [45, 155]);
  });

  testWidgets('end', (tester) async {
    expect(await lefts(tester, 'end'), [90, 200]);
  });

  testWidgets('each run is placed on its own', (tester) async {
    // Three boxes: two fit on the first run (210), the third starts a
    // second run alone (100 of 300 → 100 left over each side when centred).
    expect(await lefts(tester, 'center', count: 3), [45, 155, 100]);
  });

  testWidgets('vertical flows align along their own axis', (tester) async {
    final runtime = MCPUIRuntime(enableDebugMode: false);
    addTearDown(runtime.dispose);
    await runtime.initialize({
      'type': 'page',
      'content': {
        'type': 'sizedBox',
        'width': 300,
        'height': 300,
        'child': {
          'type': 'flow',
          'spacing': 10,
          'direction': 'vertical',
          'alignment': 'end',
          'children': [
            {
              'type': 'sizedBox',
              'width': 100,
              'height': 100,
              'child': {'type': 'text', 'content': 'v0'},
            },
          ],
        },
      },
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Align(alignment: Alignment.topLeft, child: runtime.buildUI()))));
    await tester.pump();
    final top = tester.getTopLeft(find.text('v0')).dy -
        tester.getTopLeft(find.byType(Wrap)).dy;
    expect(top, 200);
  });

  testWidgets('a flow with no height limit sizes to its runs', (tester) async {
    // In a column inside a scroll view the flow has no height limit. A
    // Flutter `Flow` takes all the space it is given, was given an infinite
    // height, and the page failed to draw (a RangeError in release; reported
    // from Studio). The flow now takes the height of its runs.
    final runtime = MCPUIRuntime(enableDebugMode: false);
    addTearDown(runtime.dispose);
    await runtime.initialize({
      'type': 'page',
      'content': {
        'type': 'scrollView',
        'child': {
          'type': 'linear',
          'direction': 'vertical',
          'children': [
            {
              'type': 'box',
              'width': 400,
              'child': {
                'type': 'flow',
                'alignment': 'center',
                'children': [
                  for (final t in ['a', 'b'])
                    {
                      'type': 'box',
                      'width': 60,
                      'height': 20,
                      'child': {'type': 'text', 'content': t},
                    },
                ],
              },
            },
            {'type': 'text', 'content': 'AFTER'},
          ],
        },
      },
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('AFTER'), findsOneWidget);
    // 60 + 8 (default spacing) + 60 = 128 of 400, centred.
    final box = tester.getTopLeft(find.byType(Wrap)).dx;
    expect(tester.getTopLeft(find.text('a')).dx - box, 136);
  });
}

