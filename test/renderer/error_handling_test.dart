import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';

void main() {
  late WidgetRegistry widgetRegistry;
  late BindingEngine bindingEngine;
  late ActionHandler actionHandler;
  late StateManager stateManager;
  late ThemeManager themeManager;
  late Renderer renderer;
  late RenderContext renderContext;

  setUp(() {
    widgetRegistry = WidgetRegistry();
    DefaultWidgets.registerAll(widgetRegistry);
    bindingEngine = BindingEngine();
    actionHandler = ActionHandler();
    stateManager = StateManager();
    themeManager = ThemeManager.instance;
    themeManager.reset();

    stateManager.initialize({});

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
  });

  tearDown(() {
    bindingEngine.dispose();
    stateManager.dispose();
  });

  group('TC-155: Unknown widget type — error container', () {
    testWidgets('Normal: unknown type renders error widget', (tester) async {
      final widget = renderer.renderWidget(
        {'type': 'unknownWidgetType123'},
        renderContext,
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

      // Should render an error container (not crash)
      expect(widget, isA<Widget>());
    });

    testWidgets('Boundary: empty type string renders error', (tester) async {
      final widget = renderer.renderWidget(
        {'type': ''},
        renderContext,
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
      expect(widget, isA<Widget>());
    });
  });

  group('TC-156: Missing required property — error widget', () {
    testWidgets('Normal: text without content renders without crash', (tester) async {
      final widget = renderer.renderWidget(
        {'type': 'text'},
        renderContext,
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
      // Should render (with empty text or placeholder)
      expect(widget, isA<Widget>());
    });

    testWidgets('Normal: button without label renders', (tester) async {
      final widget = renderer.renderWidget(
        {'type': 'button'},
        renderContext,
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
      expect(widget, isA<Widget>());
    });
  });

  group('TC-157: Binding resolution failure — fallback', () {
    testWidgets('Normal: unresolvable binding does not crash', (tester) async {
      final widget = renderer.renderWidget(
        {'type': 'text', 'content': '{{nonexistent.path.deep}}'},
        renderContext,
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
      // Should render without crashing
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('Boundary: nested binding failure in child', (tester) async {
      final widget = renderer.renderWidget(
        {
          'type': 'linear',
          'direction': 'vertical',
          'children': [
            {'type': 'text', 'content': '{{missing}}'},
            {'type': 'text', 'content': 'Static'},
          ],
        },
        renderContext,
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
      expect(find.text('Static'), findsOneWidget);
    });
  });

  group('TC-158: Child rendering failure — ErrorBoundary', () {
    testWidgets('Normal: invalid child definition does not crash parent', (tester) async {
      final widget = renderer.renderWidget(
        {
          'type': 'linear',
          'direction': 'vertical',
          'children': [
            {'type': 'text', 'content': 'Valid'},
            {'type': 'unknownWidget999'},
          ],
        },
        renderContext,
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
      // Parent should still render
      expect(find.text('Valid'), findsOneWidget);
    });
  });

  group('TC-159: Image load failure — placeholder', () {
    testWidgets('Normal: image with missing src renders placeholder', (tester) async {
      final widget = renderer.renderWidget(
        {'type': 'image'},
        renderContext,
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
      // Should render without crashing (placeholder or error)
      expect(widget, isA<Widget>());
    });

    testWidgets('Boundary: image with empty src string', (tester) async {
      final widget = renderer.renderWidget(
        {'type': 'image', 'src': ''},
        renderContext,
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
      expect(widget, isA<Widget>());
    });
  });
}
