// What the file actions answer in a browser.
//
// These refusals could not be tested at all: they were written against
// `kIsWeb`, a compile-time constant, so on a VM test run the compiler knows
// the branch is unreachable and the only way to see it was to run the whole
// suite in a browser. They now read the same host port every other web check
// in the runtime uses — which is injectable, and is also the answer a host
// gets to *declare* rather than have inferred.
//
// The refusals themselves are §6.13: a capability the platform does not have
// is reported, never answered with an empty success that a document reads as
// "the file was empty" or "the folder has no files in it".

import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/client_actions/executors/file_action_executor.dart';
import 'package:flutter_mcp_ui_runtime/src/platform/host_platform.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FileActionExecutor executor;
  late RenderContext context;

  setUp(() {
    executor = FileActionExecutor();
    final stateManager = StateManager()..initialize(<String, dynamic>{});
    final bindingEngine = BindingEngine();
    final actionHandler = ActionHandler();
    context = RenderContext(
      renderer: Renderer(
        widgetRegistry: WidgetRegistry(),
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        stateManager: stateManager,
      ),
      stateManager: stateManager,
      bindingEngine: bindingEngine,
      actionHandler: actionHandler,
      themeManager: ThemeManager.instance,
    );
    HostPlatform.override(name: 'web');
  });

  tearDown(HostPlatform.clearOverride);

  test('reading a file is refused by name', () async {
    final result =
        await executor.readFile(const {'path': '/tmp/a.txt'}, context);

    expect(result.success, isFalse);
    expect(result.error, contains('not supported on web'),
        reason: 'an empty success here reads as "the file was empty", which '
            'is a different fact from "this platform cannot read files"');
  });

  test('writing a file is refused by name', () async {
    final result = await executor.writeFile(
        const {'path': '/tmp/a.txt', 'content': 'x'}, context);

    expect(result.success, isFalse);
    expect(result.error, contains('not supported on web'));
  });

  test('listing a directory is refused by name', () async {
    final result =
        await executor.listFiles(const {'path': '/tmp'}, context);

    expect(result.success, isFalse);
    expect(result.error, contains('not supported on web'));
  });
}
