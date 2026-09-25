// The `onError` hook is a contract a host reads, not a list of senders it has
// to know. Every report — whichever part of the runtime makes it — carries the
// same keys, and one failure is reported once — to the hook and to the log,
// on every path, in every build mode. A host that installed only a log sink
// must see what a hook subscriber sees.
//
// Each case goes through the runtime's own failure path rather than firing the
// hook directly: what has to arrive is the report the runtime makes.

import 'package:flutter/widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_result.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/plugins/plugin_hooks.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/utils/mcp_logger.dart';
import 'package:flutter_mcp_ui_runtime/src/widgets/widget_factory.dart';
import 'package:flutter_test/flutter_test.dart';

class _ThrowingFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    throw StateError('factory broke');
  }
}

class _ThrowingExecutor extends ActionExecutor {
  @override
  Future<ActionResult> execute(
    Map<String, dynamic> action,
    RenderContext context,
  ) async {
    throw StateError('executor broke');
  }
}

const _rendererKeys = {'source', 'message', 'widgetType'};
const _actionKeys = {'source', 'message', 'actionType'};

void main() {
  late List<Map<String, dynamic>> reports;
  late List<MCPLogRecord> errorLogs;
  late Renderer renderer;
  late ActionHandler actionHandler;
  late RenderContext context;

  setUp(() {
    PluginHookManager.instance.clear();
    reports = <Map<String, dynamic>>[];
    errorLogs = <MCPLogRecord>[];
    MCPLogger.onRecord = (r) {
      if (r.level == 'ERROR') errorLogs.add(r);
    };
    PluginHookManager.instance.registerHook(
      pluginName: 'host',
      hookType: PluginHookType.onError,
      callback: (hook) async => reports.add(hook.data),
    );

    final registry = WidgetRegistry()..register('broken', _ThrowingFactory());
    final stateManager = StateManager()..initialize(<String, dynamic>{});
    final bindingEngine = BindingEngine();
    actionHandler = ActionHandler()
      ..registerExecutor('custom.broken', _ThrowingExecutor());
    renderer = Renderer(
      widgetRegistry: registry,
      bindingEngine: bindingEngine,
      actionHandler: actionHandler,
      stateManager: stateManager,
    );
    context = RenderContext(
      renderer: renderer,
      stateManager: stateManager,
      bindingEngine: bindingEngine,
      actionHandler: actionHandler,
      themeManager: ThemeManager.instance,
    );
  });

  tearDown(() {
    PluginHookManager.instance.clear();
    MCPLogger.onRecord = null;
  });

  group('renderer', () {
    test('an unknown type is one report with every key', () {
      renderer.renderWidget(<String, dynamic>{'type': 'nope'}, context);

      expect(reports, hasLength(1));
      final r = reports.single;
      expect(r.keys.toSet(), _rendererKeys);
      expect(r['source'], 'renderer');
      expect(r['message'], 'Unknown widget type: nope');
      expect(r['widgetType'], 'nope');
      expect(r.containsKey('error'), isFalse);
      expect(errorLogs, hasLength(1));
      expect(errorLogs.single.message, contains('Unknown widget type: nope'));
    });

    test('a missing type still carries widgetType, as null', () {
      renderer.renderWidget(<String, dynamic>{}, context);

      expect(reports, hasLength(1));
      expect(reports.single.keys.toSet(), _rendererKeys);
      expect(reports.single['widgetType'], isNull);
      expect(reports.single['message'], 'Widget type is required');
      expect(errorLogs, hasLength(1));
    });

    test('a factory that throws is reported once, not twice', () {
      renderer.renderWidget(<String, dynamic>{'type': 'broken'}, context);

      expect(reports, hasLength(1));
      final r = reports.single;
      expect(r.keys.toSet(), _rendererKeys);
      expect(r['widgetType'], 'broken');
      expect(r['message'], contains('factory broke'));
      expect(r.containsKey('error'), isFalse);
      // Logged once too, and with the exception and its stack, which the
      // message alone does not carry.
      expect(errorLogs, hasLength(1));
      expect(errorLogs.single.error, isA<StateError>());
      expect(errorLogs.single.stackTrace, isNotNull);
    });

    test('inside errorRecovery the failure escapes and is still reported', () {
      expect(
        () => renderer.renderWidgetRethrowingErrors(
          <String, dynamic>{'type': 'broken'},
          context,
        ),
        throwsStateError,
      );

      expect(reports, hasLength(1));
      expect(reports.single.keys.toSet(), _rendererKeys);
      expect(reports.single['message'], contains('factory broke'));
      // The log sees the escaping failure as well: a host with only a sink is
      // not blind to what `errorRecovery` handles.
      expect(errorLogs, hasLength(1));
      expect(errorLogs.single.error, isA<StateError>());
    });
  });

  group('action handler', () {
    test('an executor that throws is one report with every key', () async {
      final result = await actionHandler.execute(
        <String, dynamic>{'type': 'custom.broken'},
        context,
      );

      expect(result.success, isFalse);
      expect(reports, hasLength(1));
      final r = reports.single;
      expect(r.keys.toSet(), _actionKeys);
      expect(r['source'], 'actionHandler');
      expect(r['actionType'], 'custom.broken');
      expect(r['message'], contains('executor broke'));
      expect(r.containsKey('error'), isFalse);
    });
  });
}
