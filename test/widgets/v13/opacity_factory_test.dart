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

/// TC-OPACITY-001 ~ TC-OPACITY-005
/// Corresponds to: 04_TEST/feat-v13-widgets.md §2
void main() {
  group('Opacity Widget Factory Tests', () {
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

    // TC-OPACITY-001: Static opacity
    testWidgets('TC-OPACITY-001: Static opacity 0.5', (tester) async {
      final definition = {
        'type': 'opacity',
        'opacity': 0.5,
        'child': {'type': 'text', 'content': 'Semi-transparent'},
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

      // Should render Opacity widget with value 0.5
      final opacityWidget = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacityWidget.opacity, 0.5);
    });

    // TC-OPACITY-002: Binding-driven opacity
    testWidgets('TC-OPACITY-002: Binding-driven opacity', (tester) async {
      stateManager.set('alpha', 0.8);

      final definition = {
        'type': 'opacity',
        'opacity': '{{alpha}}',
        'child': {'type': 'text', 'content': 'Bound opacity'},
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

      expect(find.byType(Opacity), findsOneWidget);
    });

    // TC-OPACITY-003: Opacity clamping
    testWidgets('TC-OPACITY-003: Clamping out-of-range values', (tester) async {
      // Test value > 1.0
      final defOver = {
        'type': 'opacity',
        'opacity': 2.0,
        'child': {'type': 'text', 'content': 'Over'},
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
                return renderer.renderWidget(defOver, renderContext);
              },
            ),
          ),
        ),
      );

      final opacityWidget = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacityWidget.opacity, 1.0);

      // Test value < 0.0
      final defUnder = {
        'type': 'opacity',
        'opacity': -0.5,
        'child': {'type': 'text', 'content': 'Under'},
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
                return renderer.renderWidget(defUnder, renderContext);
              },
            ),
          ),
        ),
      );

      final opacityWidget2 = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacityWidget2.opacity, 0.0);
    });

    // TC-OPACITY-004: Animated opacity
    testWidgets('TC-OPACITY-004: Animated opacity transition', (tester) async {
      final definition = {
        'type': 'opacity',
        'opacity': 0.5,
        'animated': true,
        'duration': 500,
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

      // When animated=true, should use AnimatedOpacity
      expect(find.byType(AnimatedOpacity), findsOneWidget);
    });

    // TC-OPACITY-005: Zero opacity
    testWidgets('TC-OPACITY-005: Zero opacity still occupies space', (tester) async {
      final definition = {
        'type': 'opacity',
        'opacity': 0.0,
        'child': {'type': 'sizedBox', 'width': 100, 'height': 100},
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

      // Opacity 0 should still render (not removed from tree)
      final opacityWidget = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacityWidget.opacity, 0.0);
      // Child SizedBox should still be in the tree
      expect(find.byType(SizedBox), findsWidgets);
    });
  });
}
