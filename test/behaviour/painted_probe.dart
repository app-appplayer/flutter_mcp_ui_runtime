// What actually reached the screen.
//
// The chart family is drawn by CustomPainters, so every question about it —
// did the grid appear, is the line the declared colour, did the second dataset
// draw at all — is a question about pixels. Asserting on the widget tree
// answers a different question: `CustomPaint` is present whether the painter
// drew anything or not, which is exactly how a chart that silently dropped a
// dataset kept its tests green.
//
// So these helpers render the real widget into a real image and count colours.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The rendered pixels under [finder].
class Painted {
  Painted(this.width, this.height, this._pixels);

  final int width;
  final int height;
  final ByteData _pixels;

  ui.Color at(int x, int y) {
    final i = (y * width + x) * 4;
    return ui.Color.fromARGB(
      _pixels.getUint8(i + 3),
      _pixels.getUint8(i),
      _pixels.getUint8(i + 1),
      _pixels.getUint8(i + 2),
    );
  }

  /// Pixels that differ from the picture's own background.
  ///
  /// The background is whatever the frame holds most of, so this asks "did the
  /// widget put anything on the page" without knowing the theme. A widget that
  /// builds cleanly and paints nothing — a chart with no series drawn, a
  /// player whose source will not open — answers 0 here and is invisible to
  /// every assertion about the widget tree.
  int nonBackground({int bucket = 8}) {
    final counts = <int, int>{};
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final c = at(x, y);
        final key = ((c.r * 255) ~/ bucket) << 16 |
            ((c.g * 255) ~/ bucket) << 8 |
            ((c.b * 255) ~/ bucket);
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return 0;
    var background = counts.keys.first;
    for (final entry in counts.entries) {
      if (entry.value > counts[background]!) background = entry.key;
    }
    var painted = 0;
    for (final entry in counts.entries) {
      if (entry.key != background) painted += entry.value;
    }
    return painted;
  }

  /// How many distinct colours the picture holds, quantised so anti-aliasing
  /// does not inflate the count.
  ///
  /// A scale is a spread of colours; a widget that clamps every value to one
  /// end of its range is a single block. That difference is invisible to a
  /// tree assertion — the widget builds, the property was read — and visible
  /// here, which is where it matters.
  int distinctColours({int bucket = 24, double minAlpha = 0.5}) {
    final seen = <int>{};
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final c = at(x, y);
        if (c.a < minAlpha) continue;
        seen.add(((c.r * 255) ~/ bucket) << 16 |
            ((c.g * 255) ~/ bucket) << 8 |
            ((c.b * 255) ~/ bucket));
      }
    }
    return seen.length;
  }

  /// Pixels within [tolerance] of [colour], per channel.
  ///
  /// A tolerance rather than equality: anti-aliasing, opacity and blending all
  /// shift the exact value, and a test that demands the exact RGB fails on a
  /// line that is unmistakably the declared colour to any human looking at it.
  int count(Color colour, {int tolerance = 24, double minAlpha = 0.5}) {
    var hits = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final p = at(x, y);
        if (p.a < minAlpha) continue;
        if ((p.r * 255 - colour.r * 255).abs() > tolerance) continue;
        if ((p.g * 255 - colour.g * 255).abs() > tolerance) continue;
        if ((p.b * 255 - colour.b * 255).abs() > tolerance) continue;
        hits++;
      }
    }
    return hits;
  }

  /// Every distinct colour with at least [minCount] pixels, most common first.
  /// Useful when a test needs to know that *something* was drawn without
  /// naming it.
  List<MapEntry<int, int>> palette({int minCount = 20}) {
    final counts = <int, int>{};
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final p = at(x, y);
        if (p.a < 0.5) continue;
        final key = (p.r * 255).round() << 16 |
            (p.g * 255).round() << 8 |
            (p.b * 255).round();
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    final out = counts.entries.where((e) => e.value >= minCount).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return out;
  }

  /// Rows that contain at least [minRun] consecutive pixels of [colour] —
  /// a horizontal line, in other words. Grid checks read as "how many
  /// horizontal rules are there", which is what an author sees.
  int horizontalRules(Color colour, {int tolerance = 24, int minRun = 20}) {
    var rules = 0;
    for (var y = 0; y < height; y++) {
      var run = 0;
      var found = false;
      for (var x = 0; x < width; x++) {
        final p = at(x, y);
        final near = p.a >= 0.5 &&
            (p.r * 255 - colour.r * 255).abs() <= tolerance &&
            (p.g * 255 - colour.g * 255).abs() <= tolerance &&
            (p.b * 255 - colour.b * 255).abs() <= tolerance;
        run = near ? run + 1 : 0;
        if (run >= minRun) found = true;
      }
      if (found) rules++;
    }
    return rules;
  }

  /// The x of the leftmost pixel matching [colour], or -1.
  int leftmost(Color colour, {int tolerance = 24}) {
    for (var x = 0; x < width; x++) {
      for (var y = 0; y < height; y++) {
        final p = at(x, y);
        if (p.a < 0.5) continue;
        if ((p.r * 255 - colour.r * 255).abs() > tolerance) continue;
        if ((p.g * 255 - colour.g * 255).abs() > tolerance) continue;
        if ((p.b * 255 - colour.b * 255).abs() > tolerance) continue;
        return x;
      }
    }
    return -1;
  }
}

/// Renders the subtree under [finder] to an image and reads its pixels.
///
/// Must be called inside `tester.runAsync` — `toImage` is a real GPU/CPU
/// round trip, not a synchronous frame.
Future<Painted> paintedOf(WidgetTester tester, Finder finder) async {
  final element = tester.element(finder);
  final boundary = _findBoundary(element);
  final image = await boundary.toImage(pixelRatio: 1.0);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return Painted(image.width, image.height, data!);
}

RenderRepaintBoundary _findBoundary(Element element) {
  RenderRepaintBoundary? found;
  void visit(Element e) {
    final ro = e.renderObject;
    if (found == null && ro is RenderRepaintBoundary) found = ro;
    if (found == null) e.visitChildren(visit);
  }

  visit(element);
  if (found != null) return found!;
  // No boundary in the subtree: fall back to the root one the test harness
  // always provides. Cropping is the caller's problem then, not a silent pass.
  var ro = element.renderObject;
  while (ro != null && ro is! RenderRepaintBoundary) {
    ro = ro.parent;
  }
  if (ro is RenderRepaintBoundary) return ro;
  throw StateError('no repaint boundary above ${element.widget.runtimeType}');
}

/// Wraps [child] so its pixels can be read on their own.
Widget isolated(Widget child, {Key? key}) => RepaintBoundary(
      key: key ?? const ValueKey('painted-probe'),
      child: child,
    );

/// How different two renders are, as a fraction of pixels.
///
/// The honest way to ask "did this setting change anything at all": render
/// twice and compare. A property that is read, stored, and never used produces
/// zero difference.
double difference(Painted a, Painted b) {
  final w = math.min(a.width, b.width);
  final h = math.min(a.height, b.height);
  if (w == 0 || h == 0) return 0;
  var differing = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (a.at(x, y).value != b.at(x, y).value) differing++;
    }
  }
  return differing / (w * h);
}
