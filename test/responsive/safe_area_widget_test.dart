import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/widgets/layout/safe_area_factory.dart';
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
  late SafeAreaWidgetFactory factory;

  setUp(() {
    widgetRegistry = WidgetRegistry();
    bindingEngine = BindingEngine();
    actionHandler = ActionHandler();
    stateManager = StateManager();
    themeManager = ThemeManager.instance;
    themeManager.reset();

    stateManager.initialize({});

    // Register text factory so child widgets can be built
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

    factory = SafeAreaWidgetFactory();
  });

  tearDown(() {
    bindingEngine.dispose();
    stateManager.dispose();
  });

  // ===========================================================================
  // TC-014: SafeArea — default insets
  // ===========================================================================
  group('TC-014: SafeArea — default insets', () {
    testWidgets('Normal: default safeArea → all insets applied (top, bottom, left, right)',
        (tester) async {
      final definition = <String, dynamic>{
        'type': 'safeArea',
        'child': {'type': 'text', 'content': 'Safe content'},
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: factory.build(definition, renderContext),
          ),
        ),
      );

      // Verify SafeArea widget is in the tree with all defaults true
      final safeAreaFinder = find.byType(SafeArea);
      expect(safeAreaFinder, findsOneWidget);

      final safeArea = tester.widget<SafeArea>(safeAreaFinder);
      expect(safeArea.top, isTrue);
      expect(safeArea.bottom, isTrue);
      expect(safeArea.left, isTrue);
      expect(safeArea.right, isTrue);
    });

    testWidgets('Normal: children rendered within safe boundaries',
        (tester) async {
      final definition = <String, dynamic>{
        'type': 'safeArea',
        'children': [
          {'type': 'text', 'content': 'Child inside safe area'},
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: factory.build(definition, renderContext),
          ),
        ),
      );

      expect(find.byType(SafeArea), findsOneWidget);
      // Child text is rendered inside the safe area
      expect(find.text('Child inside safe area'), findsOneWidget);
    });

    testWidgets('Boundary: device with no system UI → insets are zero, layout unaffected',
        (tester) async {
      // In test environment, MediaQuery padding is zero by default
      final definition = <String, dynamic>{
        'type': 'safeArea',
        'child': {'type': 'text', 'content': 'No insets'},
      };

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.zero),
            child: Scaffold(
              body: factory.build(definition, renderContext),
            ),
          ),
        ),
      );

      final safeArea = tester.widget<SafeArea>(find.byType(SafeArea));
      expect(safeArea.top, isTrue);
      expect(safeArea.bottom, isTrue);
      // With zero padding, SafeArea has no visual effect
    });
  });

  // ===========================================================================
  // TC-015: SafeArea — selective insets
  // ===========================================================================
  group('TC-015: SafeArea — selective insets', () {
    testWidgets('Normal: top true, bottom false → only top inset applied',
        (tester) async {
      final definition = <String, dynamic>{
        'type': 'safeArea',
        'top': true,
        'bottom': false,
        'child': {'type': 'text', 'content': 'Top only'},
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: factory.build(definition, renderContext),
          ),
        ),
      );

      final safeArea = tester.widget<SafeArea>(find.byType(SafeArea));
      expect(safeArea.top, isTrue);
      expect(safeArea.bottom, isFalse);
      expect(safeArea.left, isTrue);
      expect(safeArea.right, isTrue);
    });

    testWidgets('Normal: left false, right false → horizontal insets ignored',
        (tester) async {
      final definition = <String, dynamic>{
        'type': 'safeArea',
        'left': false,
        'right': false,
        'child': {'type': 'text', 'content': 'No horizontal'},
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: factory.build(definition, renderContext),
          ),
        ),
      );

      final safeArea = tester.widget<SafeArea>(find.byType(SafeArea));
      expect(safeArea.left, isFalse);
      expect(safeArea.right, isFalse);
      expect(safeArea.top, isTrue);
      expect(safeArea.bottom, isTrue);
    });

    testWidgets('Boundary: all insets false → equivalent to no safe area wrapper',
        (tester) async {
      final definition = <String, dynamic>{
        'type': 'safeArea',
        'top': false,
        'bottom': false,
        'left': false,
        'right': false,
        'child': {'type': 'text', 'content': 'No safe area'},
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: factory.build(definition, renderContext),
          ),
        ),
      );

      final safeArea = tester.widget<SafeArea>(find.byType(SafeArea));
      expect(safeArea.top, isFalse);
      expect(safeArea.bottom, isFalse);
      expect(safeArea.left, isFalse);
      expect(safeArea.right, isFalse);
    });
  });
}
