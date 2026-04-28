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

/// TC-TRANSFORM-001 ~ TC-TRANSFORM-007
/// Corresponds to: 04_TEST/feat-v13-widgets.md §3
void main() {
  group('Transform Widget Factory Tests', () {
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

    // TC-TRANSFORM-001: Rotation
    testWidgets('TC-TRANSFORM-001: Rotation 90 degrees', (tester) async {
      final definition = {
        'type': 'transform',
        'rotate': 1.57,
        'child': {'type': 'text', 'content': 'Rotated'},
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

      expect(find.byType(Transform), findsWidgets);
    });

    // TC-TRANSFORM-002: Uniform scale
    testWidgets('TC-TRANSFORM-002: Uniform scale 2x', (tester) async {
      final definition = {
        'type': 'transform',
        'scale': 2.0,
        'child': {'type': 'text', 'content': 'Scaled'},
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

      expect(find.byType(Transform), findsWidgets);
    });

    // TC-TRANSFORM-003: Non-uniform scale
    testWidgets('TC-TRANSFORM-003: Non-uniform scale', (tester) async {
      final definition = {
        'type': 'transform',
        'scale': {'x': 2.0, 'y': 0.5},
        'child': {'type': 'text', 'content': 'Stretched'},
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

      expect(find.byType(Transform), findsWidgets);
    });

    // TC-TRANSFORM-004: Translate
    testWidgets('TC-TRANSFORM-004: Translate offset', (tester) async {
      final definition = {
        'type': 'transform',
        'translate': {'x': 50, 'y': 30},
        'child': {'type': 'text', 'content': 'Moved'},
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

      expect(find.byType(Transform), findsWidgets);
    });

    // TC-TRANSFORM-005: Custom origin
    testWidgets('TC-TRANSFORM-005: Custom transform origin', (tester) async {
      final definition = {
        'type': 'transform',
        'rotate': 3.14,
        'origin': {'x': 0.0, 'y': 0.0},
        'child': {'type': 'text', 'content': 'Top-left origin'},
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

      // Verify Transform widgets are present in the tree
      expect(find.byType(Transform), findsWidgets);
    });

    // TC-TRANSFORM-006: Animated transform
    testWidgets('TC-TRANSFORM-006: Animated transform', (tester) async {
      final definition = {
        'type': 'transform',
        'rotate': 1.0,
        'animated': true,
        'duration': 300,
        'child': {'type': 'text', 'content': 'Animated'},
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

      // When animated=true, should use AnimatedContainer
      expect(find.byType(AnimatedContainer), findsWidgets);
    });

    // TC-TRANSFORM-007: Combined transforms
    testWidgets('TC-TRANSFORM-007: Combined rotate + scale + translate', (tester) async {
      final definition = {
        'type': 'transform',
        'rotate': 0.785,
        'scale': 1.5,
        'translate': {'x': 20, 'y': 10},
        'child': {'type': 'text', 'content': 'Combined'},
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

      // Should render Transform with combined matrix
      expect(find.byType(Transform), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
