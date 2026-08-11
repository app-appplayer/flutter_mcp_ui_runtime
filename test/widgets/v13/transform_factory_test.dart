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
  transformMatrixTests();

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

/// The matrix, not the widget.
///
/// Every test above asserts that a `Transform` is in the tree, which it is
/// whether or not the numbers reached it. These read the matrix back: a scale
/// that is parsed wrong gives an identity, which renders perfectly and is the
/// wrong picture.
void transformMatrixTests() {
  late WidgetRegistry registry;
  late Renderer renderer;
  late StateManager stateManager;
  late BindingEngine bindingEngine;

  setUp(() {
    registry = WidgetRegistry();
    DefaultWidgets.registerAll(registry);
    stateManager = StateManager()..initialize(<String, dynamic>{});
    bindingEngine = BindingEngine();
    renderer = Renderer(
      widgetRegistry: registry,
      stateManager: stateManager,
      bindingEngine: bindingEngine,
      actionHandler: ActionHandler(),
    );
  });

  Future<void> pump(WidgetTester tester, Map<String, dynamic> definition) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (buildContext) => renderer.renderWidget(
            definition,
            RenderContext(
              renderer: renderer,
              stateManager: stateManager,
              bindingEngine: bindingEngine,
              actionHandler: ActionHandler(),
              themeManager: ThemeManager(),
              buildContext: buildContext,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// The transform around OUR child — Material draws several of its own.
  Matrix4 matrixOf(WidgetTester tester) => tester
      .widget<Transform>(
          find.ancestor(of: find.text('x'), matching: find.byType(Transform)).first)
      .transform;

  Map<String, dynamic> transform(Map<String, dynamic> extra) =>
      <String, dynamic>{
        'type': 'transform',
        'child': <String, dynamic>{'type': 'text', 'content': 'x'},
        ...extra,
      };

  group('the numbers reach the matrix', () {
    testWidgets('a scale given as a string scales both axes', (tester) async {
      await pump(tester, transform(<String, dynamic>{'scale': '2'}));

      final m = matrixOf(tester);
      expect(m.storage[0], 2.0,
          reason: 'a scale that arrives as a string — which is what a binding '
              'produces — must not fall through to 1.0 and render unchanged');
      expect(m.storage[5], 2.0);
    });

    testWidgets('a scale that is not a number at all is left at 1',
        (tester) async {
      await pump(tester, transform(<String, dynamic>{'scale': 'huge'}));

      expect(matrixOf(tester).storage[0], 1.0,
          reason: 'guessing a size from a word the runtime cannot read would '
              'resize a page for a typo');
    });

    testWidgets('a translate read from state moves the widget', (tester) async {
      stateManager.set('offset', <String, dynamic>{'x': 10, 'y': -6});
      await pump(tester, transform(<String, dynamic>{
        'translate': '{{offset}}',
      }));

      final m = matrixOf(tester);
      expect(m.storage[12], 10.0,
          reason: 'a bound translate is how an animated position is written; '
              'unresolved it matched no shape and came back as zero, so the '
              'widget rendered where it started with nothing said');
      expect(m.storage[13], -6.0);
    });

    testWidgets('a translate that is not a pair is left at the origin',
        (tester) async {
      await pump(tester, transform(<String, dynamic>{'translate': '10'}));

      final m = matrixOf(tester);
      expect(m.storage[12], 0.0,
          reason: 'a translate is an {x, y} pair; guessing which axis a bare '
              'number meant would move a widget in a direction nobody asked '
              'for');
    });

    testWidgets('rotate, scale and translate compose', (tester) async {
      await pump(tester, transform(<String, dynamic>{
        'rotate': 0,
        'scale': <String, dynamic>{'x': 3, 'y': 0.5},
        'translate': <String, dynamic>{'x': 7, 'y': -4},
      }));

      final m = matrixOf(tester);
      expect(m.storage[0], 3.0);
      expect(m.storage[5], 0.5);
      expect(m.storage[12], 7.0);
      expect(m.storage[13], -4.0);
    });
  });

  group('the animated form', () {
    testWidgets('each declared curve is the one used', (tester) async {
      const expected = <String, Curve>{
        'linear': Curves.linear,
        'easeIn': Curves.easeIn,
        'easeOut': Curves.easeOut,
        'bounceIn': Curves.bounceIn,
        'bounceOut': Curves.bounceOut,
        'elasticIn': Curves.elasticIn,
        'elasticOut': Curves.elasticOut,
      };

      for (final entry in expected.entries) {
        await pump(tester, transform(<String, dynamic>{
          'animated': true,
          'curve': entry.key,
          'scale': 2,
        }));

        final animated = tester.widget<AnimatedContainer>(find
            .ancestor(
                of: find.text('x'),
                matching: find.byType(AnimatedContainer))
            .first);
        expect(animated.curve, entry.value,
            reason: '${entry.key} fell through to the default, so a bounce '
                'the author asked for eased instead — the animation still '
                'runs, just not the one that was written');
      }
    });

    testWidgets('a curve nobody declared falls back rather than throwing',
        (tester) async {
      await pump(tester, transform(<String, dynamic>{
        'animated': true,
        'curve': 'wobble',
      }));

      final animated = tester.widget<AnimatedContainer>(find
          .ancestor(
              of: find.text('x'), matching: find.byType(AnimatedContainer))
          .first);
      expect(animated.curve, Curves.easeInOut);
    });
  });
}
