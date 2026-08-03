// `options.legend.position` decides whether the legend is drawn, and where.
//
// The factory read only `showLegend` — a name that appears nowhere in §10 —
// and defaulted it to false. A chart written the documented way declared its
// dataset labels and drew no legend at all, and every suite stayed green
// because a chart without a legend still renders. It surfaced when a test
// started asking whether a declared string reaches the screen.
//
// `top` alone cannot pin the behaviour: it is also the default, so a runtime
// that ignored the property entirely would still pass. The discriminating
// cases are `none` and `bottom`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

Map<String, dynamic> _chart({Map<String, dynamic>? legend, bool? showLegend}) =>
    <String, dynamic>{
      'type': 'chart',
      'chartType': 'line',
      'data': <String, dynamic>{
        'labels': <String>['Jan', 'Feb'],
        'datasets': <Map<String, dynamic>>[
          <String, dynamic>{
            'label': 'Sales',
            'data': <int>[100, 200],
          },
        ],
      },
      if (legend != null || showLegend != null) ...<String, dynamic>{
        if (showLegend != null) 'showLegend': showLegend,
        if (legend != null)
          'options': <String, dynamic>{'legend': legend},
      },
    };

Future<bool> _legendShown(
  WidgetTester tester,
  Map<String, dynamic> chart,
) async {
  final runtime = MCPUIRuntime();
  await runtime.initialize(
    <String, dynamic>{'type': 'page', 'content': chart},
    useCache: false,
  );
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: runtime.buildUI())),
  );
  await tester.pump(const Duration(milliseconds: 50));
  final shown = tester.any(find.text('Sales'));
  await runtime.dispose();
  return shown;
}

void main() {
  testWidgets('the legend is drawn by default', (tester) async {
    // §10 gives `position` a default of `top`, so a chart that says nothing
    // about its legend still has one.
    expect(await _legendShown(tester, _chart()), isTrue);
  });

  testWidgets('`none` hides it', (tester) async {
    expect(
      await _legendShown(tester, _chart(legend: {'position': 'none'})),
      isFalse,
    );
  });

  testWidgets('`bottom` still draws it', (tester) async {
    expect(
      await _legendShown(tester, _chart(legend: {'position': 'bottom'})),
      isTrue,
    );
  });

  testWidgets('the legacy `showLegend` is read only when position is absent',
      (tester) async {
    // Documents written before the property was read pass `showLegend`, and
    // dropping it would break them for the sake of tidiness. But a document
    // that states a position means it: letting a stale key override the
    // documented property is how a spec stops describing the runtime.
    expect(await _legendShown(tester, _chart(showLegend: false)), isFalse);
    expect(
      await _legendShown(
          tester, _chart(showLegend: true, legend: {'position': 'none'})),
      isFalse,
      reason: 'the declared position decides',
    );
  });
}
