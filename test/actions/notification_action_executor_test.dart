import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';

import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';

void main() {
  late ActionHandler actionHandler;
  late RenderContext context;
  late StateManager stateManager;
  late BindingEngine bindingEngine;

  setUp(() {
    actionHandler = ActionHandler();
    stateManager = StateManager();
    bindingEngine = BindingEngine();
    final themeManager = ThemeManager.instance;
    themeManager.reset();
    final widgetRegistry = WidgetRegistry();
    final renderer = Renderer(
      widgetRegistry: widgetRegistry,
      bindingEngine: bindingEngine,
      actionHandler: actionHandler,
      stateManager: stateManager,
    );

    context = RenderContext(
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

  group('NotificationActionExecutor', () {
    // A message bound to a number — `{{count}}` over an int — is an ordinary
    // document ("3 items saved" written the short way). The snack bar takes a
    // String, so the resolved value fails its cast on the way in. What the
    // document must not get back is a success: a toast that never appeared
    // and an action that says it did leaves nothing on screen and nothing in
    // the result to act on.
    testWidgets('a message that does not resolve to text is reported',
        (tester) async {
      stateManager.set('count', 3);

      late BuildContext surface;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (ctx) {
          surface = ctx;
          return const Scaffold(body: Text('page'));
        }),
      ));

      final result = await actionHandler.execute({
        'type': 'notification',
        'message': '{{count}}',
      }, RenderContext(
        renderer: context.renderer,
        stateManager: stateManager,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        themeManager: ThemeManager.instance,
        buildContext: surface,
      ));

      expect(result.success, isFalse,
          reason: 'the toast did not appear; reporting success would leave '
              'the document believing the user was told');
      await tester.pumpAndSettle();
      expect(find.text('3'), findsNothing);
    });

    test('returns error when message is missing', () async {
      final result = await actionHandler.execute({
        'type': 'notification',
      }, context);

      expect(result.success, isFalse);
    });

    test('returns error when message is empty', () async {
      final result = await actionHandler.execute({
        'type': 'notification',
        'message': '',
      }, context);

      expect(result.success, isFalse);
    });

    // SnackBar display tests require a widget test with Scaffold context;
    // without a BuildContext, execute succeeds gracefully
    test('succeeds without BuildContext (no SnackBar shown)', () async {
      final result = await actionHandler.execute({
        'type': 'notification',
        'message': 'Hello',
        'severity': 'success',
        'duration': 2000,
        'position': 'top',
      }, context);

      expect(result.success, isTrue);
    });
  });
}
