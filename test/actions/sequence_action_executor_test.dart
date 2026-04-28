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

  group('SequenceActionExecutor', () {
    test('executes actions in sequential order', () async {
      final result = await actionHandler.execute({
        'type': 'sequence',
        'actions': [
          {'type': 'state', 'binding': 'step', 'value': 1},
          {'type': 'state', 'binding': 'step', 'value': 2},
        ],
      }, context);

      expect(result.success, isTrue);
      // Last write wins, proving sequential execution
      expect(stateManager.get('step'), equals(2));
    });

    test('executes onComplete callback after all actions', () async {
      await actionHandler.execute({
        'type': 'sequence',
        'actions': [
          {'type': 'state', 'binding': 'a', 'value': 1},
        ],
        'onComplete': {'type': 'state', 'binding': 'completed', 'value': true},
      }, context);

      expect(stateManager.get('completed'), isTrue);
    });

    test('returns error when actions list is missing', () async {
      final result = await actionHandler.execute({
        'type': 'sequence',
      }, context);

      expect(result.success, isFalse);
    });
  });
}
