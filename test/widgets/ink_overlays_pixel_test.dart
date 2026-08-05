// The overlays reach the screen — measured, not inferred.
//
// `hoverColor` and `focusColor` were the two the live probe could not settle:
// its tooling has no hover, and under pointer input Material suppresses the
// focus highlight, so both read zero whether the ink worked or not. Zero from
// a probe that cannot produce the state is not evidence of anything, and the
// pair stayed explicitly unmeasured rather than being called green.
//
// Both are producible here — a mouse gesture for hover, and the traditional
// highlight strategy (what a keyboard user gets) for focus. The measurement is
// a raster of the frame, because the widget tree was never in doubt: the
// colours were always on the `InkWell`. What was in doubt was whether anything
// was painted, and by whom.
//
// What this file does *not* guard: removing the widget's own `Material` leaves
// all three cases passing, so it does not discriminate the ancestor-masking
// fix — under this tree the ink survives either way, while in a real document
// (a page with its own decoration) it did not. `ink_under_background_test.dart`
// holds that contract structurally and does go red on the same mutation.
// Recorded because a suite that passes both ways looks like a guard and is
// not one.

import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  const probe = ValueKey<String>('ink-probe');

  /// Pixels carrying a red cast. Ink is translucent, so an exact match against
  /// the declared colour finds nothing — the cast is what reaches the eye.
  Future<int> reddish(WidgetTester tester) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(probe));
    final data = await tester.runAsync(() async {
      final image = await boundary.toImage();
      return image.toByteData(format: ui.ImageByteFormat.rawRgba);
    });
    final bytes = data!.buffer.asUint8List();
    var hits = 0;
    for (var i = 0; i + 3 < bytes.length; i += 4) {
      if (bytes[i] - bytes[i + 1] > 12 && bytes[i] - bytes[i + 2] > 12) hits++;
    }
    return hits;
  }

  Future<MCPUIRuntime> mount(WidgetTester tester, Map<String, dynamic> ink) async {
    final runtime = MCPUIRuntime();
    await runtime.initialize(<String, dynamic>{
      'type': 'page',
      // The page paints its own background — the condition under which these
      // overlays used to vanish entirely.
      'content': <String, dynamic>{
        'type': 'box',
        'color': '#f2f6f5',
        'child': ink,
      },
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RepaintBoundary(key: probe, child: runtime.buildUI()))));
    await tester.pump();
    return runtime;
  }

  Map<String, dynamic> inkWith(String slot, {bool autofocus = false}) =>
      <String, dynamic>{
        'type': 'inkWell',
        slot: '#b3261e',
        if (autofocus) 'autofocus': true,
        'onTap': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'x',
          'value': 1,
        },
        'child': <String, dynamic>{'type': 'text', 'content': 'tap'},
      };

  testWidgets('hoverColor paints while the pointer rests on it',
      (tester) async {
    final runtime = await mount(tester, inkWith('hoverColor'));
    expect(await reddish(tester), 0, reason: 'nothing should be drawn yet');

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('tap')));
    await tester.pumpAndSettle();

    expect(await reddish(tester), greaterThan(0),
        reason: 'the hover overlay never reached the screen');
    await runtime.destroy();
  });

  testWidgets('focusColor paints for a keyboard user', (tester) async {
    // Under pointer input Material suppresses the focus highlight, which is
    // why the live probe read zero and could not tell suppression from a
    // missing paint. This is the mode a keyboard user is in.
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic);

    final runtime = await mount(tester, inkWith('focusColor', autofocus: true));
    await tester.pumpAndSettle();

    expect(await reddish(tester), greaterThan(0),
        reason: 'the focus overlay never reached the screen');
    await runtime.destroy();
  });

  testWidgets('a hover overlay on a list row reaches the screen too',
      (tester) async {
    final runtime = await mount(tester, <String, dynamic>{
      'type': 'listItem',
      'title': 'row',
      'hoverColor': '#b3261e',
      // A row with nothing to activate is not interactive, and an overlay for
      // an interaction that cannot happen would be the wrong thing to draw.
      'onTap': <String, dynamic>{
        'type': 'state',
        'action': 'set',
        'binding': 'x',
        'value': 1,
      },
    });
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('row')));
    await tester.pumpAndSettle();

    expect(await reddish(tester), greaterThan(0));
    await runtime.destroy();
  });
}
