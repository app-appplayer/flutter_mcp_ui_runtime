// A plugin declares the hooks it listens on, the same way it declares widgets
// and actions.
//
// §18.2.1 made the `onError` hook the only signal a release build gives for a
// widget that could not be built — the message is logged and the slot is
// collapsed rather than painted. A hook nobody can subscribe to is therefore
// not a lesser version of that contract; it is the absence of it.

import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/core/service_locator.dart';
import 'package:flutter_mcp_ui_runtime/src/plugins/plugin_hooks.dart';
import 'package:flutter_mcp_ui_runtime/src/plugins/plugin_system.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

class _HookPlugin extends MCPPlugin {
  _HookPlugin(this.name, this.seen);

  @override
  final String name;

  final List<PluginHookContext> seen;

  @override
  String get version => '1.0.0';

  @override
  Map<PluginHookType, PluginHookCallback> get hooks =>
      <PluginHookType, PluginHookCallback>{
        PluginHookType.onError: (context) async => seen.add(context),
      };

  @override
  Future<void> initialize(PluginContext context) async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  late PluginManager manager;
  late WidgetRegistry registry;
  late StateManager stateManager;

  setUp(() {
    PluginManager.resetInstance();
    PluginHookManager.instance.clear();
    registry = WidgetRegistry();
    stateManager = StateManager()..initialize(<String, dynamic>{});
    manager = PluginManager.instance
      ..initialize(
        stateManager: stateManager,
        serviceLocator: ServiceLocator(),
        widgetRegistry: registry,
        actionHandler: ActionHandler(),
      );
  });

  tearDown(() {
    PluginHookManager.instance.clear();
    PluginManager.resetInstance();
  });

  test('a declared hook receives what the runtime fires', () async {
    final seen = <PluginHookContext>[];
    await manager.registerPlugin(_HookPlugin('listener', seen));
    await manager.loadPlugin('listener');

    PluginHookManager.instance.fireHookSync(
      PluginHookType.onError,
      data: <String, dynamic>{
        'source': 'renderer',
        'message': 'Unknown widget type: nope',
        'widgetType': 'nope',
      },
    );
    await Future<void>.delayed(Duration.zero);

    expect(seen, hasLength(1));
    expect(seen.single.data['message'], 'Unknown widget type: nope');
    expect(seen.single.data['widgetType'], 'nope');
  });

  test('unloading the plugin takes its hook with it', () async {
    final seen = <PluginHookContext>[];
    await manager.registerPlugin(_HookPlugin('listener', seen));
    await manager.loadPlugin('listener');
    await manager.unloadPlugin('listener');

    PluginHookManager.instance.fireHookSync(
      PluginHookType.onError,
      data: <String, dynamic>{'message': 'after unload'},
    );
    await Future<void>.delayed(Duration.zero);

    expect(seen, isEmpty);
  });

  test('a widget that cannot be built reaches the declared hook', () async {
    // Through the renderer's own failure path rather than by firing the hook
    // directly: what has to arrive is the report the renderer makes, not one
    // this test wrote. `renderWidget` builds the replacement and fires on the
    // way, so no frame is needed.
    final seen = <PluginHookContext>[];
    await manager.registerPlugin(_HookPlugin('listener', seen));
    await manager.loadPlugin('listener');

    final bindingEngine = BindingEngine();
    final actionHandler = ActionHandler();
    final renderer = Renderer(
      widgetRegistry: registry,
      bindingEngine: bindingEngine,
      actionHandler: actionHandler,
      stateManager: stateManager,
    );
    renderer.renderWidget(
      <String, dynamic>{'type': 'no_such_widget'},
      RenderContext(
        renderer: renderer,
        stateManager: stateManager,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        themeManager: ThemeManager.instance,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(seen, hasLength(1));
    expect(seen.single.data['source'], 'renderer');
    expect(seen.single.data['widgetType'], 'no_such_widget');
  });
}
