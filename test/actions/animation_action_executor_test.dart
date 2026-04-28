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

  group('AnimationActionExecutor', () {
    test('returns error when target is missing', () async {
      final result = await actionHandler.execute({
        'type': 'animation',
        'action': 'play',
      }, context);

      expect(result.success, isFalse);
    });

    test('stores animation action in state for target widget', () async {
      final result = await actionHandler.execute({
        'type': 'animation',
        'action': 'reverse',
        'target': 'myWidget',
      }, context);

      expect(result.success, isTrue);
      expect(stateManager.get('_animations.myWidget.action'), equals('reverse'));
    });

    test('stores duration and curve overrides', () async {
      await actionHandler.execute({
        'type': 'animation',
        'action': 'play',
        'target': 'card1',
        'duration': 500,
        'curve': 'easeInOut',
      }, context);

      expect(stateManager.get('_animations.card1.duration'), equals(500));
      expect(stateManager.get('_animations.card1.curve'), equals('easeInOut'));
    });

    test('defaults to play action when action key is omitted', () async {
      await actionHandler.execute({
        'type': 'animation',
        'target': 'widget1',
      }, context);

      expect(stateManager.get('_animations.widget1.action'), equals('play'));
    });
  });
}
