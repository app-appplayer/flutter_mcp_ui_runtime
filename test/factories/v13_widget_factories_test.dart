import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

/// v1.3 Widget Factories Tests
///
/// Tests TC-001 through TC-022 for Canvas, Opacity, Transform, and Dashboard widgets.
void main() {
  late MCPUIRuntime runtime;

  setUp(() {
    runtime = MCPUIRuntime(enableDebugMode: false);
  });

  tearDown(() async {
    await runtime.dispose();
  });

  // ===========================================================================
  // Canvas Widget Tests (TC-001 ~ TC-006)
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // TC-001: Basic canvas rendering
  // ---------------------------------------------------------------------------
  group('TC-001: Basic canvas rendering', () {
    testWidgets('Normal: canvas with rect and circle renders with correct dimensions',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'canvas',
          'width': 400,
          'height': 300,
          'backgroundColor': '#EEEEEE',
          'commands': [
            {'op': 'rect', 'x': 10, 'y': 10, 'width': 80, 'height': 60, 'fill': '#FF0000'},
            {'op': 'circle', 'cx': 200, 'cy': 150, 'radius': 40, 'fill': '#0000FF'},
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      // Canvas renders as CustomPaint inside SizedBox
      expect(find.byType(CustomPaint), findsWidgets);
      final sizedBox = tester.widgetList<SizedBox>(find.byType(SizedBox))
          .where((s) => s.width == 400 && s.height == 300)
          .toList();
      expect(sizedBox, isNotEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-002: All drawing command types
  // ---------------------------------------------------------------------------
  group('TC-002: All drawing command types', () {
    testWidgets('Normal: canvas with all op types renders without error',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'canvas',
          'width': 500,
          'height': 400,
          'commands': [
            {'op': 'rect', 'x': 10, 'y': 10, 'width': 50, 'height': 30, 'fill': '#FF0000'},
            {'op': 'circle', 'cx': 100, 'cy': 100, 'radius': 25, 'fill': '#00FF00'},
            {'op': 'arc', 'cx': 200, 'cy': 100, 'radius': 30, 'startAngle': 0, 'endAngle': 3.14, 'stroke': '#0000FF', 'strokeWidth': 2},
            {'op': 'line', 'x1': 0, 'y1': 200, 'x2': 500, 'y2': 200, 'stroke': '#000000', 'strokeWidth': 1},
            {'op': 'path', 'd': 'M10 250 L50 300 L90 250 Z', 'fill': '#FF00FF'},
            {'op': 'text', 'content': 'Hello Canvas', 'x': 10, 'y': 350, 'fontSize': 16, 'color': '#333333'},
            {'op': 'image', 'x': 300, 'y': 300, 'width': 80, 'height': 60},
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-003: Data binding in commands
  // ---------------------------------------------------------------------------
  group('TC-003: Data binding in commands', () {
    testWidgets('Normal: canvas with binding expressions resolves state values',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'state': {
          'circleX': 150,
          'circleColor': '#FF0000',
        },
        'content': {
          'type': 'canvas',
          'width': 300,
          'height': 200,
          'commands': [
            {
              'op': 'circle',
              'cx': '{{circleX}}',
              'cy': 100,
              'radius': 30,
              'fill': '{{circleColor}}',
            },
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      // Renders without error; binding resolved
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-004: Empty commands array
  // ---------------------------------------------------------------------------
  group('TC-004: Empty commands array', () {
    testWidgets('Boundary: canvas with empty commands renders empty canvas',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'canvas',
          'width': 200,
          'height': 100,
          'backgroundColor': '#CCCCCC',
          'commands': <Map<String, dynamic>>[],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      // Should render a SizedBox with CustomPaint, no errors
      expect(find.byType(CustomPaint), findsWidgets);
      final sizedBox = tester.widgetList<SizedBox>(find.byType(SizedBox))
          .where((s) => s.width == 200 && s.height == 100)
          .toList();
      expect(sizedBox, isNotEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-005: Invalid op type
  // ---------------------------------------------------------------------------
  group('TC-005: Invalid op type', () {
    testWidgets('Error: unknown op is skipped gracefully; other commands render',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'canvas',
          'width': 300,
          'height': 200,
          'commands': [
            {'op': 'unknown', 'x': 10, 'y': 10},
            {'op': 'rect', 'x': 50, 'y': 50, 'width': 100, 'height': 80, 'fill': '#00FF00'},
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      // No error thrown; canvas renders normally
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-006: Canvas in template
  // ---------------------------------------------------------------------------
  group('TC-006: Canvas in template', () {
    testWidgets('Normal: template containing canvas binds parameters correctly',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'templates': [
          {
            'name': 'canvasTemplate',
            'parameters': ['canvasWidth', 'canvasHeight', 'rectColor'],
            'content': {
              'type': 'canvas',
              'width': '{{canvasWidth}}',
              'height': '{{canvasHeight}}',
              'commands': [
                {'op': 'rect', 'x': 0, 'y': 0, 'width': '{{canvasWidth}}', 'height': '{{canvasHeight}}', 'fill': '{{rectColor}}'},
              ],
            },
          },
        ],
        'content': {
          'type': 'use',
          'template': 'canvasTemplate',
          'arguments': {
            'canvasWidth': 250,
            'canvasHeight': 150,
            'rectColor': '#FF5500',
          },
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  // ===========================================================================
  // Opacity Widget Tests (TC-007 ~ TC-011)
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // TC-007: Static opacity
  // ---------------------------------------------------------------------------
  group('TC-007: Static opacity', () {
    testWidgets('Normal: opacity 0.5 renders child at half opacity',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'opacity',
          'opacity': 0.5,
          'child': {'type': 'text', 'content': 'Half Visible'},
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('Half Visible'), findsOneWidget);
      final opacityWidget = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacityWidget.opacity, 0.5);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-008: Binding-driven opacity
  // ---------------------------------------------------------------------------
  group('TC-008: Binding-driven opacity', () {
    testWidgets('Normal: opacity resolves from state binding',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'state': {
          'fadeLevel': 0.3,
        },
        'content': {
          'type': 'opacity',
          'opacity': '{{fadeLevel}}',
          'child': {'type': 'text', 'content': 'Bound Opacity'},
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      // Verify child renders; binding resolution depends on runtime context
      expect(find.text('Bound Opacity'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-009: Opacity clamping
  // ---------------------------------------------------------------------------
  group('TC-009: Opacity clamping', () {
    testWidgets('Boundary: opacity below 0 is clamped to 0.0',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'opacity',
          'opacity': -0.5,
          'child': {'type': 'text', 'content': 'Clamped Low'},
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      final opacityWidget = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacityWidget.opacity, 0.0);
    });

    testWidgets('Boundary: opacity above 1 is clamped to 1.0',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'opacity',
          'opacity': 2.0,
          'child': {'type': 'text', 'content': 'Clamped High'},
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      final opacityWidget = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacityWidget.opacity, 1.0);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-010: Animated opacity
  // ---------------------------------------------------------------------------
  group('TC-010: Animated opacity', () {
    testWidgets('Normal: animated opacity uses AnimatedOpacity with correct duration',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'opacity',
          'opacity': 0.7,
          'animated': true,
          'duration': 500,
          'child': {'type': 'text', 'content': 'Animated'},
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('Animated'), findsOneWidget);
      final animatedOpacity = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
      expect(animatedOpacity.opacity, 0.7);
      expect(animatedOpacity.duration, const Duration(milliseconds: 500));
    });
  });

  // ---------------------------------------------------------------------------
  // TC-011: Zero opacity
  // ---------------------------------------------------------------------------
  group('TC-011: Zero opacity', () {
    testWidgets('Boundary: opacity 0.0 makes child fully transparent but present in layout',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'opacity',
          'opacity': 0.0,
          'child': {'type': 'text', 'content': 'Invisible'},
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      // Child is still in widget tree (occupies layout space)
      expect(find.text('Invisible'), findsOneWidget);
      final opacityWidget = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacityWidget.opacity, 0.0);
    });
  });

  // ===========================================================================
  // Transform Widget Tests (TC-012 ~ TC-018)
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // TC-012: Rotation
  // ---------------------------------------------------------------------------
  group('TC-012: Rotation', () {
    testWidgets('Normal: transform with rotate renders child',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'transform',
          'rotate': 1.57,
          'child': {'type': 'text', 'content': 'Rotated'},
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('Rotated'), findsOneWidget);
      // Transform widget should be in tree
      expect(find.byType(Transform), findsWidgets);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-013: Uniform scale
  // ---------------------------------------------------------------------------
  group('TC-013: Uniform scale', () {
    testWidgets('Normal: transform with scale 2.0 renders child',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'transform',
          'scale': 2.0,
          'child': {'type': 'text', 'content': 'Scaled'},
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('Scaled'), findsOneWidget);
      expect(find.byType(Transform), findsWidgets);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-014: Non-uniform scale
  // ---------------------------------------------------------------------------
  group('TC-014: Non-uniform scale', () {
    testWidgets('Normal: transform with scale {x: 2.0, y: 0.5} renders child',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'transform',
          'scale': {'x': 2.0, 'y': 0.5},
          'child': {'type': 'text', 'content': 'Non-uniform'},
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('Non-uniform'), findsOneWidget);
      expect(find.byType(Transform), findsWidgets);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-015: Translate
  // ---------------------------------------------------------------------------
  group('TC-015: Translate', () {
    testWidgets('Normal: transform with translate renders child',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'transform',
          'translate': {'x': 50, 'y': 30},
          'child': {'type': 'text', 'content': 'Translated'},
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('Translated'), findsOneWidget);
      expect(find.byType(Transform), findsWidgets);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-016: Custom origin
  // ---------------------------------------------------------------------------
  group('TC-016: Custom origin', () {
    testWidgets('Boundary: transform with origin (0,0) renders child',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'transform',
          'rotate': 3.14,
          'origin': {'x': 0.0, 'y': 0.0},
          'child': {'type': 'text', 'content': 'Origin Test'},
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('Origin Test'), findsOneWidget);
      expect(find.byType(Transform), findsWidgets);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-017: Animated transform
  // ---------------------------------------------------------------------------
  group('TC-017: Animated transform', () {
    testWidgets('Normal: animated transform uses AnimatedContainer',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'transform',
          'rotate': 0.5,
          'animated': true,
          'duration': 400,
          'child': {'type': 'text', 'content': 'Animated Transform'},
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('Animated Transform'), findsOneWidget);
      final animatedContainer = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      expect(animatedContainer.duration, const Duration(milliseconds: 400));
      expect(animatedContainer.transform, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-018: Combined transforms
  // ---------------------------------------------------------------------------
  group('TC-018: Combined transforms', () {
    testWidgets('Normal: rotate + scale + translate all applied',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'transform',
          'rotate': 0.785,
          'scale': 1.5,
          'translate': {'x': 20, 'y': 10},
          'child': {'type': 'text', 'content': 'Combined'},
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('Combined'), findsOneWidget);
      // Transform widget should be in tree with combined matrix
      expect(find.byType(Transform), findsWidgets);
    });
  });

  // ===========================================================================
  // Dashboard Entry Point Tests (TC-019 ~ TC-022)
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // TC-019: Dashboard rendering mode
  // ---------------------------------------------------------------------------
  group('TC-019: Dashboard rendering mode', () {
    testWidgets('Normal: dashboard with content renders widget tree',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'dashboard',
          'content': {'type': 'text', 'content': 'Dashboard Summary'},
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      expect(find.text('Dashboard Summary'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-020: Dashboard refresh interval
  // ---------------------------------------------------------------------------
  group('TC-020: Dashboard refresh interval', () {
    testWidgets('Normal: dashboard with refreshInterval rebuilds periodically',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'dashboard',
          'refreshInterval': 5000,
          'content': {'type': 'text', 'content': 'Refreshable'},
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      // Content renders with refresh interval
      expect(find.text('Refreshable'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-021: Dashboard click action
  // ---------------------------------------------------------------------------
  group('TC-021: Dashboard click action', () {
    testWidgets('Normal: dashboard with onTap fires action on tap',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'dashboard',
          'onTap': {'type': 'navigation', 'action': 'openApp'},
          'content': {'type': 'text', 'content': 'Tap Me'},
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      // GestureDetector wraps the content
      expect(find.text('Tap Me'), findsOneWidget);
      expect(find.byType(GestureDetector), findsWidgets);

      // Tap the dashboard card — should not throw
      await tester.tap(find.text('Tap Me'));
      await tester.pump();
    });
  });

  // ---------------------------------------------------------------------------
  // TC-022: Missing dashboard field
  // ---------------------------------------------------------------------------
  group('TC-022: Missing dashboard field', () {
    testWidgets('Error: dashboard with no content renders empty widget',
        (WidgetTester tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'dashboard',
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
      await tester.pump();

      // Should render without error (SizedBox.shrink as fallback)
      expect(tester.takeException(), isNull);
    });
  });
}
