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

import 'dart:ui';

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

/// Counts the pixels the chart painter actually put on the canvas.
///
/// A chart that draws nothing looks identical to one that draws correctly in
/// every check that asks "did it render" — the panel is there either way, and
/// the panel is drawn by a `Container`, not by the painter. So the painter is
/// run onto a transparent surface of its own and the opaque pixels counted:
/// zero means it returned before drawing.
///
/// `approximateBytesUsed` was the first attempt and it does not discriminate —
/// an empty picture still reports a size, so the mutation that restored the
/// bug survived the test.
Future<int> _paintedPixels(
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

  var painted = 0;
  // Rasterising is real async work; the test binding's fake clock never
  // completes it unless it runs outside.
  await tester.runAsync(() async {
    for (final element in find.byType(CustomPaint).evaluate()) {
      final painter = (element.widget as CustomPaint).painter;
      final size = element.size;
      if (painter == null || size == null || size.isEmpty) continue;

      final recorder = PictureRecorder();
      painter.paint(Canvas(recorder), size);
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        size.width.round(),
        size.height.round(),
      );
      final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);
      picture.dispose();
      image.dispose();
      if (bytes == null) continue;
      final data = bytes.buffer.asUint8List();
      for (var i = 3; i < data.length; i += 4) {
        if (data[i] != 0) painted++;
      }
    }
  });
  await runtime.dispose();
  return painted;
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

  testWidgets('a short chart still draws its bars', (tester) async {
    // mark found this from the browser: the legend appeared exactly where the
    // document asked and the plot area was empty. Turning the legend on by
    // default left 77px of the 140 for the plot, and the painter's flat 40px
    // gutter takes 80 of it — so every paint method returned before drawing.
    // The number was the silent part; the default only made it common.
    final painted = await _paintedPixels(tester, <String, dynamic>{
      'type': 'chart',
      'chartType': 'bar',
      'height': 140,
      'data': <Map<String, dynamic>>[
        <String, dynamic>{'label': 'A', 'value': 3},
        <String, dynamic>{'label': 'B', 'value': 7},
        <String, dynamic>{'label': 'C', 'value': 5},
      ],
      'options': <String, dynamic>{
        'legend': <String, dynamic>{'position': 'bottom'},
      },
    });
    expect(painted, greaterThan(0),
        reason: 'the painter drew nothing into a 140-tall chart');
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
