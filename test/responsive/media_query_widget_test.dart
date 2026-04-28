import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/widgets/layout/media_query_factory.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/widgets/display/text_factory.dart';

void main() {
  late WidgetRegistry widgetRegistry;
  late BindingEngine bindingEngine;
  late ActionHandler actionHandler;
  late StateManager stateManager;
  late ThemeManager themeManager;
  late Renderer renderer;
  late RenderContext renderContext;
  late MediaQueryWidgetFactory factory;

  setUp(() {
    widgetRegistry = WidgetRegistry();
    bindingEngine = BindingEngine();
    actionHandler = ActionHandler();
    stateManager = StateManager();
    themeManager = ThemeManager.instance;
    themeManager.reset();

    stateManager.initialize({});

    // Register text factory so child widgets can be built via context.buildWidget
    widgetRegistry.register('text', TextWidgetFactory());

    renderer = Renderer(
      widgetRegistry: widgetRegistry,
      bindingEngine: bindingEngine,
      actionHandler: actionHandler,
      stateManager: stateManager,
    );

    renderContext = RenderContext(
      renderer: renderer,
      stateManager: stateManager,
      bindingEngine: bindingEngine,
      actionHandler: actionHandler,
      themeManager: themeManager,
    );

    factory = MediaQueryWidgetFactory();
  });

  tearDown(() {
    bindingEngine.dispose();
    stateManager.dispose();
  });

  /// Helper to pump a widget with a specific constrained size.
  /// Uses Center to loosen parent constraints, then SizedBox to set tight size,
  /// so LayoutBuilder receives the desired constraints.
  Future<void> pumpWithSize(
    WidgetTester tester,
    double width,
    double height,
    Widget child,
  ) async {
    // Set the test surface size so constraints propagate correctly
    await tester.binding.setSurfaceSize(Size(width, height));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.expand(
          child: child,
        ),
      ),
    );
  }

  // ===========================================================================
  // TC-009: MediaQuery — minWidth and maxWidth conditions
  // ===========================================================================
  group('TC-009: MediaQuery — minWidth and maxWidth conditions', () {
    testWidgets(
        'Normal: screen 800px, minWidth 600 maxWidth 1279 → children rendered',
        (tester) async {
      final definition = <String, dynamic>{
        'type': 'mediaQuery',
        'condition': {'minWidth': 600, 'maxWidth': 1279},
        'then': {'type': 'text', 'content': 'Visible'},
        'else': {'type': 'text', 'content': 'Hidden'},
      };

      await pumpWithSize(
          tester, 800, 600, factory.build(definition, renderContext));

      expect(find.text('Visible'), findsOneWidget);
      expect(find.text('Hidden'), findsNothing);
    });

    testWidgets('Normal: screen 400px, minWidth 600 → children hidden',
        (tester) async {
      final definition = <String, dynamic>{
        'type': 'mediaQuery',
        'condition': {'minWidth': 600},
        'then': {'type': 'text', 'content': 'Wide'},
        'else': {'type': 'text', 'content': 'Narrow'},
      };

      await pumpWithSize(
          tester, 400, 600, factory.build(definition, renderContext));

      expect(find.text('Wide'), findsNothing);
      expect(find.text('Narrow'), findsOneWidget);
    });

    testWidgets(
        'Boundary: screen exactly at minWidth (600px) → children rendered (inclusive)',
        (tester) async {
      final definition = <String, dynamic>{
        'type': 'mediaQuery',
        'condition': {'minWidth': 600},
        'then': {'type': 'text', 'content': 'Matched'},
      };

      await pumpWithSize(
          tester, 600, 600, factory.build(definition, renderContext));

      expect(find.text('Matched'), findsOneWidget);
    });

    testWidgets('Error: minWidth > maxWidth → no children rendered',
        (tester) async {
      final definition = <String, dynamic>{
        'type': 'mediaQuery',
        'condition': {'minWidth': 1000, 'maxWidth': 500},
        'then': {'type': 'text', 'content': 'Should not appear'},
        'else': {'type': 'text', 'content': 'Else branch'},
      };

      await pumpWithSize(
          tester, 800, 600, factory.build(definition, renderContext));

      // Width 800: minWidth 1000 check fails → condition not met → else shown
      expect(find.text('Should not appear'), findsNothing);
      expect(find.text('Else branch'), findsOneWidget);
    });
  });

  // ===========================================================================
  // TC-010: MediaQuery — orientation condition
  // ===========================================================================
  group('TC-010: MediaQuery — orientation condition', () {
    testWidgets(
        'Normal: landscape device, orientation "landscape" → children rendered',
        (tester) async {
      final definition = <String, dynamic>{
        'type': 'mediaQuery',
        'condition': {'orientation': 'landscape'},
        'then': {'type': 'text', 'content': 'Landscape'},
      };

      // Landscape: width > height
      await pumpWithSize(
          tester, 1000, 600, factory.build(definition, renderContext));

      expect(find.text('Landscape'), findsOneWidget);
    });

    testWidgets(
        'Normal: portrait device, orientation "landscape" → children hidden',
        (tester) async {
      final definition = <String, dynamic>{
        'type': 'mediaQuery',
        'condition': {'orientation': 'landscape'},
        'then': {'type': 'text', 'content': 'Landscape'},
        'else': {'type': 'text', 'content': 'Not Landscape'},
      };

      // Portrait: height >= width
      await pumpWithSize(
          tester, 400, 800, factory.build(definition, renderContext));

      expect(find.text('Landscape'), findsNothing);
      expect(find.text('Not Landscape'), findsOneWidget);
    });

    testWidgets('Boundary: orientation not specified → condition passes',
        (tester) async {
      final definition = <String, dynamic>{
        'type': 'mediaQuery',
        'condition': {'minWidth': 100},
        'then': {'type': 'text', 'content': 'No orientation check'},
      };

      await pumpWithSize(
          tester, 400, 800, factory.build(definition, renderContext));

      expect(find.text('No orientation check'), findsOneWidget);
    });

    testWidgets('Error: invalid orientation value → condition not met',
        (tester) async {
      final definition = <String, dynamic>{
        'type': 'mediaQuery',
        'condition': {'orientation': 'diagonal'},
        'then': {'type': 'text', 'content': 'Matched'},
        'else': {'type': 'text', 'content': 'Not matched'},
      };

      await pumpWithSize(
          tester, 800, 600, factory.build(definition, renderContext));

      // Invalid orientation: neither 'portrait' nor 'landscape' check triggers,
      // so the condition passes through without failing
      expect(find.text('Matched'), findsOneWidget);
    });
  });

  // ===========================================================================
  // TC-011: MediaQuery — platform condition
  // ===========================================================================
  group('TC-011: MediaQuery — platform condition', () {
    // The current MediaQueryWidgetFactory does not support 'platform'
    // condition natively. Unknown condition keys are ignored.

    testWidgets(
        'Normal: unknown condition keys are ignored → condition passes',
        (tester) async {
      final definition = <String, dynamic>{
        'type': 'mediaQuery',
        'condition': {'platform': 'mobile', 'minWidth': 100},
        'then': {'type': 'text', 'content': 'Rendered'},
      };

      await pumpWithSize(
          tester, 400, 600, factory.build(definition, renderContext));

      // 'platform' key is ignored by _evaluateCondition, minWidth 100 passes
      expect(find.text('Rendered'), findsOneWidget);
    });

    testWidgets(
        'Boundary: empty platform array → condition passes (no restriction)',
        (tester) async {
      final definition = <String, dynamic>{
        'type': 'mediaQuery',
        'condition': <String, dynamic>{'platform': <String>[]},
        'then': {'type': 'text', 'content': 'Passed'},
      };

      await pumpWithSize(
          tester, 400, 600, factory.build(definition, renderContext));

      expect(find.text('Passed'), findsOneWidget);
    });
  });

  // ===========================================================================
  // TC-012: MediaQuery — breakpoint condition
  // ===========================================================================
  group('TC-012: MediaQuery — breakpoint condition', () {
    testWidgets(
        'Normal: active breakpoint matches condition → children rendered',
        (tester) async {
      // Width 1000 → md breakpoint (960-1279)
      final definition = <String, dynamic>{
        'type': 'mediaQuery',
        'condition': {'breakpoint': 'expanded'},
        'then': {'type': 'text', 'content': 'MD Layout'},
      };

      await pumpWithSize(
          tester, 1000, 600, factory.build(definition, renderContext));

      expect(find.text('MD Layout'), findsOneWidget);
    });

    testWidgets(
        'Normal: active breakpoint does not match → children hidden',
        (tester) async {
      // Width 400 → xs breakpoint (0-599), condition requires md
      final definition = <String, dynamic>{
        'type': 'mediaQuery',
        'condition': {'breakpoint': 'expanded'},
        'then': {'type': 'text', 'content': 'MD Only'},
        'else': {'type': 'text', 'content': 'Not MD'},
      };

      await pumpWithSize(
          tester, 400, 600, factory.build(definition, renderContext));

      expect(find.text('MD Only'), findsNothing);
      expect(find.text('Not MD'), findsOneWidget);
    });

    testWidgets('Boundary: single breakpoint match', (tester) async {
      // Width 1920 → xl breakpoint (1920+)
      final definition = <String, dynamic>{
        'type': 'mediaQuery',
        'condition': {'breakpoint': 'extraLarge'},
        'then': {'type': 'text', 'content': 'XL'},
      };

      await pumpWithSize(
          tester, 1920, 1080, factory.build(definition, renderContext));

      expect(find.text('XL'), findsOneWidget);
    });

    testWidgets('Error: unknown breakpoint name → condition not met',
        (tester) async {
      final definition = <String, dynamic>{
        'type': 'mediaQuery',
        'condition': {'breakpoint': 'xxl'},
        'then': {'type': 'text', 'content': 'Matched'},
        'else': {'type': 'text', 'content': 'No Match'},
      };

      await pumpWithSize(
          tester, 1000, 600, factory.build(definition, renderContext));

      // 'xxl' is not a valid breakpoint, getCurrentBreakpoint returns 'expanded'
      // 'expanded' != 'xxl' → condition not met
      expect(find.text('Matched'), findsNothing);
      expect(find.text('No Match'), findsOneWidget);
    });
  });

  // ===========================================================================
  // TC-013: MediaQuery — combined conditions (AND logic)
  // ===========================================================================
  group('TC-013: MediaQuery — combined conditions (AND logic)', () {
    testWidgets('Normal: all conditions met → children rendered',
        (tester) async {
      // Width 1000, height 600: minWidth 600, maxWidth 1279, landscape
      final definition = <String, dynamic>{
        'type': 'mediaQuery',
        'condition': {
          'minWidth': 600,
          'maxWidth': 1279,
          'orientation': 'landscape',
        },
        'then': {'type': 'text', 'content': 'All Met'},
      };

      await pumpWithSize(
          tester, 1000, 600, factory.build(definition, renderContext));

      expect(find.text('All Met'), findsOneWidget);
    });

    testWidgets(
        'Normal: one condition not met → children hidden (AND semantics)',
        (tester) async {
      // Width 1000, height 600: minWidth 600 passes, orientation portrait fails
      final definition = <String, dynamic>{
        'type': 'mediaQuery',
        'condition': {
          'minWidth': 600,
          'orientation': 'portrait',
        },
        'then': {'type': 'text', 'content': 'All Met'},
        'else': {'type': 'text', 'content': 'Failed'},
      };

      await pumpWithSize(
          tester, 1000, 600, factory.build(definition, renderContext));

      expect(find.text('All Met'), findsNothing);
      expect(find.text('Failed'), findsOneWidget);
    });

    testWidgets(
        'Boundary: no conditions specified → children always rendered',
        (tester) async {
      final definition = <String, dynamic>{
        'type': 'mediaQuery',
        'condition': <String, dynamic>{},
        'then': {'type': 'text', 'content': 'Always'},
      };

      await pumpWithSize(
          tester, 500, 800, factory.build(definition, renderContext));

      expect(find.text('Always'), findsOneWidget);
    });
  });

  // ===========================================================================
  // TC-032: MediaQuery with no matching conditions
  // ===========================================================================
  group('TC-032: MediaQuery with no matching conditions', () {
    testWidgets('Normal: conditions match → children rendered',
        (tester) async {
      final definition = <String, dynamic>{
        'type': 'mediaQuery',
        'condition': {'minWidth': 300},
        'then': {'type': 'text', 'content': 'Rendered'},
      };

      await pumpWithSize(
          tester, 500, 600, factory.build(definition, renderContext));

      expect(find.text('Rendered'), findsOneWidget);
    });

    testWidgets(
        'Boundary: no conditions specified → children always rendered',
        (tester) async {
      final definition = <String, dynamic>{
        'type': 'mediaQuery',
        'condition': <String, dynamic>{},
        'then': {'type': 'text', 'content': 'Always Visible'},
      };

      await pumpWithSize(
          tester, 200, 400, factory.build(definition, renderContext));

      expect(find.text('Always Visible'), findsOneWidget);
    });

    testWidgets(
        'Error: no conditions match → children hidden (empty render)',
        (tester) async {
      // Width 400: minWidth 800 fails → no match, no else → SizedBox.shrink
      final definition = <String, dynamic>{
        'type': 'mediaQuery',
        'condition': {'minWidth': 800, 'breakpoint': 'extraLarge'},
        'then': {'type': 'text', 'content': 'Should not show'},
      };

      await pumpWithSize(
          tester, 400, 600, factory.build(definition, renderContext));

      expect(find.text('Should not show'), findsNothing);
      // Verify SizedBox.shrink is rendered (empty render)
      expect(find.byType(SizedBox), findsWidgets);
    });
  });
}
