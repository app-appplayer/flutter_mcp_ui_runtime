import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';

/// TC-CANVAS-001 ~ TC-CANVAS-006
/// Corresponds to: 04_TEST/feat-v13-widgets.md §1
void main() {
  group('Canvas Widget Factory Tests', () {
    late WidgetRegistry registry;
    late Renderer renderer;
    late StateManager stateManager;
    late BindingEngine bindingEngine;

    setUp(() {
      registry = WidgetRegistry();
      DefaultWidgets.registerAll(registry);
      stateManager = StateManager();
      bindingEngine = BindingEngine();
      renderer = Renderer(
        widgetRegistry: registry,
        stateManager: stateManager,
        bindingEngine: bindingEngine,
        actionHandler: ActionHandler(),
      );
    });

    // TC-CANVAS-001: Basic canvas rendering
    testWidgets('TC-CANVAS-001: Basic canvas with rect and circle', (tester) async {
      final definition = {
        'type': 'canvas',
        'width': 300,
        'height': 200,
        'commands': [
          {'op': 'rect', 'x': 10, 'y': 10, 'width': 100, 'height': 50, 'fill': '#FF0000'},
          {'op': 'circle', 'cx': 200, 'cy': 100, 'radius': 30, 'fill': '#0000FF'},
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final renderContext = RenderContext(
                  renderer: renderer,
                  stateManager: stateManager,
                  bindingEngine: bindingEngine,
                  actionHandler: ActionHandler(),
                  themeManager: ThemeManager(),
                  buildContext: context,
                );
                return renderer.renderWidget(definition, renderContext);
              },
            ),
          ),
        ),
      );

      // Canvas should render — SizedBox and CustomPaint present in tree
      expect(find.byType(SizedBox), findsWidgets);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    // TC-CANVAS-002: All drawing command types
    testWidgets('TC-CANVAS-002: All drawing op types', (tester) async {
      final definition = {
        'type': 'canvas',
        'width': 400,
        'height': 400,
        'commands': [
          {'op': 'rect', 'x': 0, 'y': 0, 'width': 50, 'height': 50, 'fill': '#FF0000'},
          {'op': 'circle', 'cx': 100, 'cy': 100, 'radius': 25, 'stroke': '#00FF00', 'strokeWidth': 2},
          {'op': 'arc', 'cx': 200, 'cy': 200, 'radius': 30, 'startAngle': 0, 'endAngle': 3.14, 'stroke': '#0000FF'},
          {'op': 'line', 'x1': 0, 'y1': 0, 'x2': 100, 'y2': 100, 'stroke': '#000000'},
          {'op': 'path', 'd': 'M10 10 L50 50 L10 50 Z', 'fill': '#FFFF00'},
          {'op': 'text', 'content': 'Hello', 'x': 10, 'y': 300, 'fontSize': 16, 'color': '#000000'},
          {'op': 'image', 'x': 300, 'y': 300, 'width': 50, 'height': 50},
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final renderContext = RenderContext(
                  renderer: renderer,
                  stateManager: stateManager,
                  bindingEngine: bindingEngine,
                  actionHandler: ActionHandler(),
                  themeManager: ThemeManager(),
                  buildContext: context,
                );
                return renderer.renderWidget(definition, renderContext);
              },
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });

    // TC-CANVAS-003: Data binding in commands
    testWidgets('TC-CANVAS-003: Binding expressions in commands', (tester) async {
      stateManager.set('rectWidth', 150);
      stateManager.set('circleColor', '#00FF00');

      final definition = {
        'type': 'canvas',
        'width': 300,
        'height': 200,
        'commands': [
          {'op': 'rect', 'x': 0, 'y': 0, 'width': '{{rectWidth}}', 'height': 50, 'fill': '#FF0000'},
          {'op': 'circle', 'cx': 100, 'cy': 100, 'radius': 20, 'fill': '{{circleColor}}'},
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final renderContext = RenderContext(
                  renderer: renderer,
                  stateManager: stateManager,
                  bindingEngine: bindingEngine,
                  actionHandler: ActionHandler(),
                  themeManager: ThemeManager(),
                  buildContext: context,
                );
                return renderer.renderWidget(definition, renderContext);
              },
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });

    // TC-CANVAS-004: Empty commands array
    testWidgets('TC-CANVAS-004: Empty commands', (tester) async {
      final definition = {
        'type': 'canvas',
        'width': 100,
        'height': 100,
        'backgroundColor': '#EEEEEE',
        'commands': <dynamic>[],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final renderContext = RenderContext(
                  renderer: renderer,
                  stateManager: stateManager,
                  bindingEngine: bindingEngine,
                  actionHandler: ActionHandler(),
                  themeManager: ThemeManager(),
                  buildContext: context,
                );
                return renderer.renderWidget(definition, renderContext);
              },
            ),
          ),
        ),
      );

      // Should render empty canvas without error
      expect(find.byType(CustomPaint), findsWidgets);
    });

    // TC-CANVAS-005: Invalid op type
    testWidgets('TC-CANVAS-005: Unknown op skipped gracefully', (tester) async {
      final definition = {
        'type': 'canvas',
        'width': 200,
        'height': 200,
        'commands': [
          {'op': 'unknown_shape'},
          {'op': 'rect', 'x': 0, 'y': 0, 'width': 50, 'height': 50, 'fill': '#FF0000'},
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final renderContext = RenderContext(
                  renderer: renderer,
                  stateManager: stateManager,
                  bindingEngine: bindingEngine,
                  actionHandler: ActionHandler(),
                  themeManager: ThemeManager(),
                  buildContext: context,
                );
                return renderer.renderWidget(definition, renderContext);
              },
            ),
          ),
        ),
      );

      // Should render without error, unknown op ignored
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    // TC-CANVAS-006: Canvas registration check
    test('TC-CANVAS-006: Canvas widget is registered', () {
      expect(registry.has('canvas'), isTrue);
      final factory = registry.get('canvas');
      expect(factory, isNotNull);
    });
  });
}
