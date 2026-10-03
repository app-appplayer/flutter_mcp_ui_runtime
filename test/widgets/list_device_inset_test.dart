// A `list` or `grid` with no `padding` is drawn where the document puts it.
//
// Flutter's ListView / GridView add the device's safe-area inset
// (`MediaQuery.padding`) along the scroll axis when given no padding — inside
// a card or a scroll view too. The spec gives `padding` no default and leaves
// system insets to the `safeArea` widget (§2.4.13), so the inset is not the
// document's. Measured on a phone-shaped view before the fix: a 47-point
// status bar put 47 points between a heading and the list under it (reported
// from a served template on iOS).

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/mcp_ui_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<double> gapUnder(WidgetTester tester, Map<String, dynamic> list) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);
    final runtime = MCPUIRuntime(enableDebugMode: false);
    addTearDown(runtime.dispose);
    await runtime.initialize({
      'type': 'page',
      'content': {
        'type': 'linear',
        'children': [
          {'type': 'text', 'content': 'HEADING'},
          list,
          {'type': 'text', 'content': 'AFTER'},
        ],
      },
    });
    await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
    await tester.pump();
    return tester.getTopLeft(find.text('ITEM')).dy -
        tester.getBottomLeft(find.text('HEADING')).dy;
  }

  const item = {'type': 'text', 'content': 'ITEM'};

  for (final type in ['list', 'grid']) {
    final base = <String, dynamic>{
      'type': type,
      'shrinkWrap': true,
      if (type == 'grid') 'columns': 1,
      'children': [item],
    };

    testWidgets('$type without padding takes no device inset', (tester) async {
      expect(await gapUnder(tester, base), 0);
    });

    testWidgets('$type keeps the padding its author wrote', (tester) async {
      expect(
          await gapUnder(tester, {
            ...base,
            'padding': {'top': 12},
          }),
          12);
    });
  }
}
