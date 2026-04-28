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

  group('PermissionRevokeActionExecutor', () {
    test('revokes a single permission via singular key', () async {
      final result = await actionHandler.execute({
        'type': 'permission.revoke',
        'permission': 'camera',
      }, context);

      expect(result.success, isTrue);
      expect(stateManager.get('permissions.camera.status'), equals('revoked'));
    });

    test('revokes multiple permissions via plural key', () async {
      final result = await actionHandler.execute({
        'type': 'permission.revoke',
        'permissions': ['camera', 'microphone'],
      }, context);

      expect(result.success, isTrue);
      expect(stateManager.get('permissions.camera.status'), equals('revoked'));
      expect(stateManager.get('permissions.microphone.status'), equals('revoked'));
    });

    test('returns error when no permission specified', () async {
      final result = await actionHandler.execute({
        'type': 'permission.revoke',
      }, context);

      expect(result.success, isFalse);
    });

    test('returns error when permissions list is empty', () async {
      final result = await actionHandler.execute({
        'type': 'permission.revoke',
        'permissions': <String>[],
      }, context);

      expect(result.success, isFalse);
    });
  });
}
