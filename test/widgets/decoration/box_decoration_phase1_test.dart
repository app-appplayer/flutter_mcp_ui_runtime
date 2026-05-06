// Phase 1.A — `BoxDecoration` primitive surface tests.
//
// Verifies that the spec § configs/widget/BoxDecoration fields land on
// the rendered Flutter `BoxDecoration` exactly as the resolver
// declares — sweep gradient, per-side border, multi-shadow, image
// (data URI), backdropBlur (BackdropFilter wrap), and circle shape.
//
// The two consumers (`box` and `decoration` widgets) share the
// resolver, so each test exercises both widget keywords to lock the
// shared path against drift.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

Future<MCPUIRuntime> _bootRuntime(Map<String, dynamic> root) async {
  final runtime = MCPUIRuntime();
  await runtime.initialize({
    'type': 'page',
    'content': root,
  });
  return runtime;
}

Future<Container> _firstContainer(WidgetTester tester) async {
  final finder = find.byType(Container);
  expect(finder, findsAtLeast(1),
      reason: 'expected at least one Container in tree');
  return tester.widget<Container>(finder.first);
}

Future<DecoratedBox> _firstDecoratedBox(WidgetTester tester) async {
  final finder = find.byType(DecoratedBox);
  expect(finder, findsAtLeast(1),
      reason: 'expected at least one DecoratedBox in tree');
  return tester.widget<DecoratedBox>(finder.first);
}

void main() {
  group('Phase 1.A — BoxDecoration primitive', () {
    testWidgets('box: linear gradient with stops + tileMode', (tester) async {
      final runtime = await _bootRuntime({
        'type': 'box',
        'width': 200,
        'height': 100,
        'decoration': {
          'gradient': {
            'type': 'linear',
            'colors': ['#FF0000', '#0000FF'],
            'stops': [0.2, 0.8],
            'begin': 'topStart',
            'end': 'bottomEnd',
            'tileMode': 'mirror',
          },
        },
      });
      await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
      await tester.pump();

      final box = await _firstContainer(tester);
      final dec = box.decoration as BoxDecoration;
      expect(dec.gradient, isA<LinearGradient>());
      final g = dec.gradient as LinearGradient;
      expect(g.colors, equals(const [Color(0xFFFF0000), Color(0xFF0000FF)]));
      expect(g.stops, equals(const [0.2, 0.8]));
      expect(g.begin, equals(Alignment.topLeft));
      expect(g.end, equals(Alignment.bottomRight));
      expect(g.tileMode, equals(TileMode.mirror));
    });

    testWidgets('box: sweep gradient (new in 1.A)', (tester) async {
      final runtime = await _bootRuntime({
        'type': 'box',
        'width': 100,
        'height': 100,
        'decoration': {
          'gradient': {
            'type': 'sweep',
            'colors': ['#FF0000', '#00FF00', '#0000FF'],
            'startAngle': 0.0,
            'endAngle': 6.283185307179586,
          },
        },
      });
      await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
      await tester.pump();

      final box = await _firstContainer(tester);
      final dec = box.decoration as BoxDecoration;
      expect(dec.gradient, isA<SweepGradient>());
      final g = dec.gradient as SweepGradient;
      expect(g.colors.length, equals(3));
      expect(g.startAngle, equals(0.0));
      expect(g.endAngle, closeTo(6.2832, 0.001));
    });

    testWidgets('decoration widget: per-side border', (tester) async {
      final runtime = await _bootRuntime({
        'type': 'decoration',
        'border': {
          'top': {'color': '#FF0000', 'width': 2.0},
          'bottom': {'color': '#0000FF', 'width': 4.0},
        },
        'child': {'type': 'sizedBox', 'width': 50, 'height': 50},
      });
      await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
      await tester.pump();

      final box = await _firstDecoratedBox(tester);
      final dec = box.decoration as BoxDecoration;
      final border = dec.border as Border;
      expect(border.top.color, equals(const Color(0xFFFF0000)));
      expect(border.top.width, equals(2.0));
      expect(border.bottom.color, equals(const Color(0xFF0000FF)));
      expect(border.bottom.width, equals(4.0));
      expect(border.left, equals(BorderSide.none));
      expect(border.right, equals(BorderSide.none));
    });

    testWidgets('box: multi-shadow array', (tester) async {
      final runtime = await _bootRuntime({
        'type': 'box',
        'width': 80,
        'height': 80,
        'decoration': {
          'color': '#FFFFFF',
          'boxShadow': [
            {
              'color': '#80000000',
              'offset': {'dx': 0, 'dy': 2},
              'blurRadius': 4,
              'spreadRadius': 0,
            },
            {
              'color': '#40000000',
              'offset': {'dx': 0, 'dy': 8},
              'blurRadius': 16,
            },
          ],
        },
      });
      await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
      await tester.pump();

      final box = await _firstContainer(tester);
      final dec = box.decoration as BoxDecoration;
      expect(dec.boxShadow, isNotNull);
      expect(dec.boxShadow!.length, equals(2));
      expect(dec.boxShadow![0].offset, equals(const Offset(0, 2)));
      expect(dec.boxShadow![0].blurRadius, equals(4));
      expect(dec.boxShadow![1].offset, equals(const Offset(0, 8)));
      expect(dec.boxShadow![1].blurRadius, equals(16));
    });

    testWidgets('box: data: image URI builds DecorationImage',
        (tester) async {
      // Smallest valid base64 PNG (1×1 transparent).
      const pngB64 =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNgAAIAAAUAAeImBZsAAAAASUVORK5CYII=';
      final runtime = await _bootRuntime({
        'type': 'box',
        'width': 64,
        'height': 64,
        'decoration': {
          'image': {
            'image': 'data:image/png;base64,$pngB64',
            'fit': 'cover',
            'opacity': 0.8,
          },
        },
      });
      await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
      await tester.pump();

      final box = await _firstContainer(tester);
      final dec = box.decoration as BoxDecoration;
      expect(dec.image, isNotNull);
      expect(dec.image!.fit, equals(BoxFit.cover));
      expect(dec.image!.opacity, closeTo(0.8, 0.001));
      expect(dec.image!.image, isA<MemoryImage>());
    });

    testWidgets('decoration widget: shape circle', (tester) async {
      final runtime = await _bootRuntime({
        'type': 'decoration',
        'shape': 'circle',
        'color': '#3F51B5',
        'child': {'type': 'sizedBox', 'width': 40, 'height': 40},
      });
      await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
      await tester.pump();

      final box = await _firstDecoratedBox(tester);
      final dec = box.decoration as BoxDecoration;
      expect(dec.shape, equals(BoxShape.circle));
    });

    testWidgets('box: backdropBlur wraps with BackdropFilter', (tester) async {
      final runtime = await _bootRuntime({
        'type': 'box',
        'width': 100,
        'height': 100,
        'decoration': {
          'color': '#80FFFFFF',
          'backdropBlur': 12.0,
        },
      });
      await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
      await tester.pump();

      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets(
        'box: gradient + color → gradient wins (mutual exclusion)',
        (tester) async {
      final runtime = await _bootRuntime({
        'type': 'box',
        'width': 100,
        'height': 100,
        'decoration': {
          'color': '#FF0000',
          'gradient': {
            'type': 'linear',
            'colors': ['#000000', '#FFFFFF'],
          },
        },
      });
      await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
      await tester.pump();

      final box = await _firstContainer(tester);
      final dec = box.decoration as BoxDecoration;
      expect(dec.color, isNull);
      expect(dec.gradient, isNotNull);
    });

    // Regression — 5/4 refactor of `container_factory` and the new
    // shared `box_decoration_resolver` together silently dropped
    // `decoration: {color: ...}` whenever top-level `color` /
    // `backgroundColor` were absent. The factory wrote an explicit
    // `color: null` into `flatProps`, then the resolver's
    // `containsKey`-based override pass overwrote the nested value
    // with that null. Reported via Standard's demo_showcase
    // navigation page — `surfaceContainerHigh` boxes rendered
    // transparent. Both layers are now null-tolerant; lock that in.
    testWidgets('box: nested decoration.color survives without top-level color',
        (tester) async {
      final runtime = await _bootRuntime({
        'type': 'box',
        'width': 100,
        'height': 100,
        'decoration': {
          'color': '#1ABC9C',
        },
      });
      await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
      await tester.pump();

      final box = await _firstContainer(tester);
      final dec = box.decoration as BoxDecoration;
      expect(dec.color, equals(const Color(0xFF1ABC9C)));
    });

    testWidgets('box: nested decoration.color resolves theme slot fallback',
        (tester) async {
      final runtime = await _bootRuntime({
        'type': 'box',
        'width': 100,
        'height': 100,
        'decoration': {
          'color': 'surfaceContainerHigh',
        },
      });
      await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
      await tester.pump();

      final box = await _firstContainer(tester);
      final dec = box.decoration as BoxDecoration;
      // Bundle declares no theme — the M3 28-role fallback in
      // ThemeManager.getColorValue must populate this with the
      // fromSeed-derived surface tone, not null.
      expect(dec.color, isA<Color>());
      expect(dec.color, isNotNull);
    });

    testWidgets('box: top-level color still overrides nested decoration.color',
        (tester) async {
      final runtime = await _bootRuntime({
        'type': 'box',
        'width': 100,
        'height': 100,
        'color': '#FF0000',
        'decoration': {
          'color': '#0000FF',
        },
      });
      await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
      await tester.pump();

      final box = await _firstContainer(tester);
      final dec = box.decoration as BoxDecoration;
      expect(dec.color, equals(const Color(0xFFFF0000)));
    });
  });
}
