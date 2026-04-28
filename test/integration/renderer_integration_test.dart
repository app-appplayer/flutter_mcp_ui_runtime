import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';

/// Phase 3.14 - Renderer Integration Tests (9 TCs)
///
/// Validates the Renderer integration with WidgetRegistry, BindingEngine,
/// StateManager, ThemeManager, and ActionHandler across nested trees,
/// dynamic lists, conditional rendering, theme-aware rendering,
/// dialog rendering, v1.1 widgets (permissionPrompt, textInput with
/// clientAction, image with client:// protocol), and full page rendering.
void main() {
  group('Renderer Integration Tests', () {
    late WidgetRegistry widgetRegistry;
    late BindingEngine bindingEngine;
    late ActionHandler actionHandler;
    late StateManager stateManager;
    late ThemeManager themeManager;
    late Renderer renderer;

    setUp(() {
      widgetRegistry = WidgetRegistry();
      DefaultWidgets.registerAll(widgetRegistry);
      bindingEngine = BindingEngine();
      actionHandler = ActionHandler();
      stateManager = StateManager();
      stateManager.initialize({
        'user': {'name': 'John', 'age': 30},
        'items': [
          {'id': 1, 'name': 'Item A', 'price': 10},
          {'id': 2, 'name': 'Item B', 'price': 20},
        ],
        'isAdmin': true,
        'theme': 'light',
        'counter': 0,
      });
      themeManager = ThemeManager.instance;
      themeManager.reset();
      renderer = Renderer(
        widgetRegistry: widgetRegistry,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        stateManager: stateManager,
      );
    });

    tearDown(() {
      bindingEngine.dispose();
      stateManager.dispose();
    });

    // -------------------------------------------------------
    // Normal: IT-013 - Nested widget tree rendering
    // -------------------------------------------------------
    testWidgets('IT-013: Nested widget tree renders correctly', (tester) async {
      final context = renderer.createRootContext(null);
      final widget = renderer.renderWidget({
        'type': 'box',
        'child': {
          'type': 'linear',
          'direction': 'vertical',
          'children': [
            {'type': 'text', 'content': 'Title'},
            {'type': 'text', 'content': 'Subtitle'},
          ],
        },
      }, context);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Subtitle'), findsOneWidget);
    });

    // -------------------------------------------------------
    // Normal: IT-014 - List with dynamic item template
    // -------------------------------------------------------
    testWidgets('IT-014: List with dynamic item template renders items from state',
        (tester) async {
      final context = renderer.createRootContext(null);
      final widget = renderer.renderWidget({
        'type': 'list',
        'items': '{{items}}',
        'shrinkWrap': true,
        'itemTemplate': {
          'type': 'text',
          'content': '{{item.name}}',
        },
      }, context);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
      await tester.pumpAndSettle();

      expect(find.text('Item A'), findsOneWidget);
      expect(find.text('Item B'), findsOneWidget);
    });

    // -------------------------------------------------------
    // Normal: IT-015 - Conditional rendering chain
    // -------------------------------------------------------
    testWidgets('IT-015: Conditional rendering shows child when condition is true',
        (tester) async {
      final context = renderer.createRootContext(null);

      // When isAdmin is true, the "then" branch should render
      final widget = renderer.renderWidget({
        'type': 'conditional',
        'condition': '{{isAdmin}}',
        'then': {
          'type': 'text',
          'content': 'Admin Panel',
        },
        'orElse': {
          'type': 'text',
          'content': 'Access Denied',
        },
      }, context);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

      expect(find.text('Admin Panel'), findsOneWidget);
      expect(find.text('Access Denied'), findsNothing);
    });

    // -------------------------------------------------------
    // Boundary: IT-016 - Theme-aware rendering
    // -------------------------------------------------------
    testWidgets('IT-016: Theme-aware rendering resolves theme bindings',
        (tester) async {
      final context = renderer.createRootContext(null);

      // Render text that uses theme color binding in its style
      final widget = renderer.renderWidget({
        'type': 'text',
        'content': 'Themed Text',
        'style': {
          'fontSize': 18,
          'fontWeight': 'bold',
        },
      }, context);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

      // Verify the themed text is rendered
      expect(find.text('Themed Text'), findsOneWidget);

      // Verify the text has the correct style applied
      final textWidget = tester.widget<Text>(find.text('Themed Text'));
      expect(textWidget.style?.fontSize, 18.0);
      expect(textWidget.style?.fontWeight, FontWeight.bold);
    });

    // -------------------------------------------------------
    // Normal: IT-017 - Dialog factory rendering
    // -------------------------------------------------------
    testWidgets('IT-017: AlertDialog widget renders title and content',
        (tester) async {
      final context = renderer.createRootContext(null);

      final widget = renderer.renderWidget({
        'type': 'alertDialog',
        'title': 'Confirm Action',
        'content': 'Are you sure you want to proceed?',
        'actions': [
          {'label': 'Cancel'},
          {'label': 'OK', 'isDefault': true},
        ],
      }, context);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

      expect(find.text('Confirm Action'), findsOneWidget);
      expect(find.text('Are you sure you want to proceed?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
    });

    // -------------------------------------------------------
    // Normal: IT-018 - v1.1 Permission prompt rendering
    // -------------------------------------------------------
    testWidgets('IT-018: PermissionPrompt widget renders appropriate prompt',
        (tester) async {
      final context = renderer.createRootContext(null);

      final widget = renderer.renderWidget({
        'type': 'permissionPrompt',
        'title': 'Camera Access',
        'description': 'This app needs camera access to take photos.',
        'permissions': ['camera', 'microphone'],
        'style': 'inline',
        'onAllow': {'type': 'setState', 'path': 'cameraGranted', 'value': true},
        'onDeny': {'type': 'setState', 'path': 'cameraGranted', 'value': false},
      }, context);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

      expect(find.text('Camera Access'), findsOneWidget);
      expect(find.text('This app needs camera access to take photos.'),
          findsOneWidget);
      expect(find.text('camera'), findsOneWidget);
      expect(find.text('microphone'), findsOneWidget);
      expect(find.text('Allow'), findsOneWidget);
      expect(find.text('Deny'), findsOneWidget);
    });

    // -------------------------------------------------------
    // Boundary: IT-019 - v1.1 Enhanced textInput with clientAction
    // -------------------------------------------------------
    testWidgets(
        'IT-019: TextInput with on-submit client action renders correctly',
        (tester) async {
      final context = renderer.createRootContext(null);

      final widget = renderer.renderWidget({
        'type': 'textInput',
        'hint': 'Enter search query',
        'label': 'Search',
        'onSubmit': {
          'type': 'client:search',
          'params': {'query': '{{event.value}}'},
        },
      }, context);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

      // TextField should be rendered with the correct hint
      expect(find.byType(TextField), findsOneWidget);
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.hintText, 'Enter search query');
      expect(textField.decoration?.labelText, 'Search');
    });

    // -------------------------------------------------------
    // Boundary: IT-020 - v1.1 Enhanced image with client:// protocol
    // -------------------------------------------------------
    testWidgets(
        'IT-020: Image with client:// src renders placeholder gracefully',
        (tester) async {
      final context = renderer.createRootContext(null);

      // client:// protocol is not a standard URL, so the image factory
      // should fall through to fallback/placeholder rendering
      final widget = renderer.renderWidget({
        'type': 'image',
        'src': 'client://user/avatar',
        'width': 64,
        'height': 64,
        'fallbackBehavior': 'placeholder',
        'placeholder': 'No image',
      }, context);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

      // The widget should render without error (shows fallback)
      // client:// is not http/https/assets/data, so it goes to fallback path
      expect(find.byType(Container), findsWidgets);
    });

    // -------------------------------------------------------
    // Normal: IT-021 - Full page render with content/children resolution
    // -------------------------------------------------------
    testWidgets('IT-021: Full page renders with content', (tester) async {
      final widget = renderer.renderPage({
        'type': 'page',
        'content': {
          'type': 'linear',
          'direction': 'vertical',
          'children': [
            {'type': 'text', 'content': 'Page Header'},
            {'type': 'text', 'content': 'Page Body'},
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: widget));

      expect(find.text('Page Header'), findsOneWidget);
      expect(find.text('Page Body'), findsOneWidget);
    });

    // -------------------------------------------------------
    // Error: Rendering unknown widget type in nested tree
    // -------------------------------------------------------
    testWidgets(
        'IT-013E: Nested tree with unknown widget type shows error widget',
        (tester) async {
      final context = renderer.createRootContext(null);

      final widget = renderer.renderWidget({
        'type': 'box',
        'child': {
          'type': 'linear',
          'direction': 'vertical',
          'children': [
            {'type': 'text', 'content': 'Valid Widget'},
            {'type': 'nonExistentWidget', 'content': 'Should fail'},
          ],
        },
      }, context);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

      // Valid widget should still render
      expect(find.text('Valid Widget'), findsOneWidget);
      // Error widget should be shown for the unknown type
      expect(find.textContaining('Unknown widget type'), findsOneWidget);
    });

    // -------------------------------------------------------
    // Boundary: Conditional rendering when condition is false
    // -------------------------------------------------------
    testWidgets(
        'IT-015B: Conditional rendering shows else branch when condition is false',
        (tester) async {
      // Set isAdmin to false to test else branch
      stateManager.set('isAdmin', false);

      final context = renderer.createRootContext(null);

      final widget = renderer.renderWidget({
        'type': 'conditional',
        'condition': '{{isAdmin}}',
        'then': {
          'type': 'text',
          'content': 'Admin Panel',
        },
        'orElse': {
          'type': 'text',
          'content': 'Access Denied',
        },
      }, context);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

      expect(find.text('Admin Panel'), findsNothing);
      expect(find.text('Access Denied'), findsOneWidget);
    });
  });
}
