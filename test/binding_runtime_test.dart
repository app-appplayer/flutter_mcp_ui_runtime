import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';

void main() {
  group('Binding Runtime Tests - Length Property', () {
    late BindingEngine bindingEngine;
    late StateManager stateManager;
    late ThemeManager themeManager;
    late Renderer renderer;
    late ActionHandler actionHandler;
    late RenderContext context;

    setUp(() {
      bindingEngine = BindingEngine();
      stateManager = StateManager();
      themeManager = ThemeManager();
      
      final widgetRegistry = WidgetRegistry();
      DefaultWidgets.registerAll(widgetRegistry);
      
      actionHandler = ActionHandler();
      
      renderer = Renderer(
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

    test('resolve handles .length in simple expressions', () {
      stateManager.initialize({
        'canvasWidgets': ['widget1', 'widget2', 'widget3'],
        'emptyList': [],
      });

      // Test simple length access
      final result1 = bindingEngine.resolve<int>('{{canvasWidgets.length}}', context);
      expect(result1, 3);

      final result2 = bindingEngine.resolve<int>('{{emptyList.length}}', context);
      expect(result2, 0);
    });

    test('resolve handles .length in comparison expressions', () {
      stateManager.initialize({
        'canvasWidgets': ['widget1', 'widget2', 'widget3'],
        'emptyList': [],
      });

      // This is the key test case
      final result1 = bindingEngine.resolve<bool>('{{canvasWidgets.length > 0}}', context);
      expect(result1, true);

      final result2 = bindingEngine.resolve<bool>('{{emptyList.length > 0}}', context);
      expect(result2, false);

      final result3 = bindingEngine.resolve<bool>('{{canvasWidgets.length == 3}}', context);
      expect(result3, true);
    });

    test('resolve handles .length in mixed content', () {
      stateManager.initialize({
        'users': ['Alice', 'Bob', 'Charlie'],
      });

      final result = bindingEngine.resolve<String>(
        'You have {{users.length}} users in the system',
        context
      );
      expect(result, 'You have 3 users in the system');
    });

    test('resolve handles nested property paths with .length', () {
      stateManager.initialize({
        'data': {
          'items': ['a', 'b', 'c'],
          'nested': {
            'list': [1, 2, 3, 4, 5],
          },
        },
      });

      final result1 = bindingEngine.resolve<int>('{{data.items.length}}', context);
      expect(result1, 3);

      final result2 = bindingEngine.resolve<int>('{{data.nested.list.length}}', context);
      expect(result2, 5);

      final result3 = bindingEngine.resolve<bool>('{{data.nested.list.length > 3}}', context);
      expect(result3, true);
    });

    test('checkCondition handles .length expressions', () {
      stateManager.initialize({
        'items': ['a', 'b', 'c'],
        'emptyItems': [],
      });

      // Test using checkCondition method which might be used for visibility
      final condition1 = context.checkCondition('{{items.length > 0}}');
      expect(condition1, true);

      final condition2 = context.checkCondition('{{emptyItems.length > 0}}');
      expect(condition2, false);
    });
  });
}