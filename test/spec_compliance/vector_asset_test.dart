// Vector assets draw, on every platform the runtime ships to.
//
// `IconRef` names `data:image/svg+xml;…` as an ordinary form and `icon`'s own
// example is `assets/icons/heart.svg`, so a runtime that cannot draw them
// makes the spec's shipped example false. Until now it took the fallback path
// instead — legal under §6.12.4, and still a documented capability the
// implementation did not have.
//
// This suite runs unchanged under `--platform chrome`: the vector path uses no
// `dart:io`, which is the thing that would quietly make "works" mean "works on
// desktop".

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

const _svg = 'data:image/svg+xml;base64,'
    'PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyNCIgaGVpZ2h0PSIyNCI+'
    'PHJlY3Qgd2lkdGg9IjI0IiBoZWlnaHQ9IjI0IiBmaWxsPSIjMGY3NjZlIi8+PC9zdmc+';

const _png = 'data:image/png;base64,'
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

void main() {
  const probe = ValueKey<String>('vector-probe');

  /// Pixels carrying the colour only this SVG paints.
  ///
  /// Counting *opaque* pixels instead would pass on a page that paints its own
  /// background, on an empty vector, and on a document with no picture in it
  /// at all — three greens that prove nothing. The colour is the only thing a
  /// rasteriser can put there.
  Future<int> vectorPixels(WidgetTester tester) async {
    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(probe));
    final data = await tester.runAsync(() async {
      final image = await boundary.toImage();
      return image.toByteData(format: ui.ImageByteFormat.rawRgba);
    });
    final bytes = data!.buffer.asUint8List();
    var hits = 0;
    for (var i = 0; i + 3 < bytes.length; i += 4) {
      final r = bytes[i], g = bytes[i + 1], b = bytes[i + 2], a = bytes[i + 3];
      if (a > 250 &&
          (r - 15).abs() < 8 &&
          (g - 118).abs() < 8 &&
          (b - 110).abs() < 8) {
        hits++;
      }
    }
    return hits;
  }

  Future<void> pump(WidgetTester tester, Map<String, dynamic> content) async {
    final runtime = MCPUIRuntime();
    addTearDown(runtime.destroy);
    await runtime.initialize(
        <String, dynamic>{'type': 'page', 'content': content});
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RepaintBoundary(key: probe, child: runtime.buildUI()))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('an inline SVG draws in an image slot', (tester) async {
    await pump(tester, <String, dynamic>{
      'type': 'image',
      'src': _svg,
      'width': 48,
      'height': 48,
    });
    expect(find.byType(SvgPicture), findsOneWidget,
        reason: 'the vector took the fallback path instead of being drawn');
  });

  testWidgets('an inline SVG draws in an icon slot', (tester) async {
    // The form `icon.yaml`'s own example uses.
    await pump(tester, <String, dynamic>{
      'type': 'icon',
      'icon': _svg,
      'size': 32,
    });
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('a vector icon is tinted like the named form', (tester) async {
    await pump(tester, <String, dynamic>{
      'type': 'icon',
      'icon': _svg,
      'size': 32,
      'color': '#b3261e',
    });
    final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(picture.colorFilter, isNotNull,
        reason: '§2.5 says `color` applies to the SVG form too');
  });

  testWidgets('a raster payload still takes the image path', (tester) async {
    // The contrast is what makes the cases above mean something: the branch
    // is chosen by payload, not applied to everything.
    await pump(tester, <String, dynamic>{'type': 'image', 'src': _png});
    expect(find.byType(SvgPicture), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('a declared fallback still wins for an unreadable vector',
      (tester) async {
    // `bundle://` with no bundle reader wired is unresolvable; §6.12.4 sends
    // it to the declared fallback rather than to a broken picture.
    await pump(tester, <String, dynamic>{
      'type': 'image',
      'src': 'bundle://missing/logo.svg',
      'fallback': <String, dynamic>{'type': 'text', 'content': 'no picture'},
    });
    expect(find.text('no picture'), findsOneWidget);
  });

  // Measured, not inferred. `findsOneWidget` says the picture widget is in the
  // tree; it does not say a rasteriser turned the vector into pixels. Under
  // `--platform chrome` that difference is the whole question — the widget is
  // platform-independent, the rasteriser is not.
  testWidgets('the vector is actually painted, not merely mounted',
      (tester) async {
    await pump(tester, <String, dynamic>{
      'type': 'image',
      'src': _svg,
      'width': 64,
      'height': 64,
    });
    expect(await vectorPixels(tester), greaterThan(0),
        reason: 'no pixel carries the colour only this SVG paints');
  });

  testWidgets('an empty vector paints none of them', (tester) async {
    // The control that kills the lazy version of this check: counting opaque
    // pixels would pass here too, because the page paints itself.
    await pump(tester, <String, dynamic>{
      'type': 'image',
      'src': 'data:image/svg+xml;base64,'
          'PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyNCIgaGVpZ2h0PSIyNCI+PC9zdmc+',
      'width': 64,
      'height': 64,
    });
    expect(await vectorPixels(tester), 0);
  });
}
