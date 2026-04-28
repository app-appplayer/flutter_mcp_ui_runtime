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

  group('TC-030: ToolActionExecutor — execute tool call with name and params', () {
    test('TC-030 Normal: registered tool executor receives params and returns result', () async {
      actionHandler.registerToolExecutor('myTool', (params) async {
        return {'success': true, 'result': 'ok'};
      });

      final result = await actionHandler.execute(
        {'type': 'tool', 'tool': 'myTool', 'params': {'key': 'value'}},
        context,
      );

      expect(result.success, isTrue);
      expect(result.data, equals('ok'));
    });

    test('TC-030 Normal: tool executor receives resolved params', () async {
      Map<String, dynamic>? receivedParams;

      actionHandler.registerToolExecutor('myTool', (params) async {
        receivedParams = params;
        return {'success': true, 'result': 'done'};
      });

      await actionHandler.execute(
        {'type': 'tool', 'tool': 'myTool', 'params': {'key': 'value', 'num': 42}},
        context,
      );

      expect(receivedParams, isNotNull);
      expect(receivedParams!['key'], equals('value'));
      expect(receivedParams!['num'], equals(42));
    });

    test('TC-030 Boundary: tool with empty params map', () async {
      actionHandler.registerToolExecutor('myTool', (params) async {
        return {'success': true, 'result': 'empty'};
      });

      final result = await actionHandler.execute(
        {'type': 'tool', 'tool': 'myTool', 'params': {}},
        context,
      );

      expect(result.success, isTrue);
      expect(result.data, equals('empty'));
    });

    test('TC-030 Boundary: tool with no params key defaults to empty map', () async {
      actionHandler.registerToolExecutor('myTool', (params) async {
        return {'success': true, 'result': 'no-params'};
      });

      final result = await actionHandler.execute(
        {'type': 'tool', 'tool': 'myTool'},
        context,
      );

      expect(result.success, isTrue);
      expect(result.data, equals('no-params'));
    });
  });

  group('TC-031: ToolActionExecutor — tool result auto-stored in state', () {
    test('TC-031 Normal: successful tool result stored at tools.{toolName}.result', () async {
      actionHandler.registerToolExecutor('myTool', (params) async {
        return {'success': true, 'result': {'data': 'hello'}};
      });

      await actionHandler.execute(
        {'type': 'tool', 'tool': 'myTool', 'params': {}},
        context,
      );

      final storedResult = stateManager.get('tools.myTool.result');
      expect(storedResult, isNotNull);
      expect(storedResult['data'], equals('hello'));
    });

    test('TC-031 Normal: string result auto-stored correctly', () async {
      actionHandler.registerToolExecutor('strTool', (params) async {
        return {'success': true, 'result': 'simple_string'};
      });

      await actionHandler.execute(
        {'type': 'tool', 'tool': 'strTool', 'params': {}},
        context,
      );

      expect(stateManager.get('tools.strTool.result'), equals('simple_string'));
    });

    test('TC-031 Boundary: failed tool result not stored (success=false)', () async {
      actionHandler.registerToolExecutor('failTool', (params) async {
        return {'success': false, 'error': 'something failed'};
      });

      await actionHandler.execute(
        {'type': 'tool', 'tool': 'failTool', 'params': {}},
        context,
      );

      // Failed tools do not auto-merge result
      final storedResult = stateManager.get('tools.failTool.result');
      expect(storedResult, isNull);
    });
  });

  group('TC-032: ToolActionExecutor — onSuccess callback chaining', () {
    test('TC-032 Normal: onSuccess action executes after successful tool', () async {
      actionHandler.registerToolExecutor('myTool', (params) async {
        return {'success': true, 'result': 'ok'};
      });

      await actionHandler.execute(
        {
          'type': 'tool',
          'tool': 'myTool',
          'params': {},
          'onSuccess': {
            'type': 'state',
            'action': 'set',
            'binding': 'success_flag',
            'value': true,
          },
        },
        context,
      );

      expect(stateManager.get<bool>('success_flag'), isTrue);
    });

    test('TC-032 Boundary: onSuccess not triggered when tool fails', () async {
      actionHandler.registerToolExecutor('failTool', (params) async {
        return {'success': false, 'error': 'failed'};
      });

      await actionHandler.execute(
        {
          'type': 'tool',
          'tool': 'failTool',
          'params': {},
          'onSuccess': {
            'type': 'state',
            'action': 'set',
            'binding': 'success_flag',
            'value': true,
          },
        },
        context,
      );

      expect(stateManager.get('success_flag'), isNull);
    });
  });

  group('TC-033: ToolActionExecutor — onError callback chaining', () {
    test('TC-033 Normal: onError action executes when tool returns failure', () async {
      actionHandler.registerToolExecutor('failTool', (params) async {
        return {'success': false, 'error': 'failed'};
      });

      await actionHandler.execute(
        {
          'type': 'tool',
          'tool': 'failTool',
          'params': {},
          'onError': {
            'type': 'state',
            'action': 'set',
            'binding': 'error_flag',
            'value': true,
          },
        },
        context,
      );

      expect(stateManager.get<bool>('error_flag'), isTrue);
    });

    test('TC-033 Boundary: onError not triggered when tool succeeds', () async {
      actionHandler.registerToolExecutor('okTool', (params) async {
        return {'success': true, 'result': 'ok'};
      });

      await actionHandler.execute(
        {
          'type': 'tool',
          'tool': 'okTool',
          'params': {},
          'onError': {
            'type': 'state',
            'action': 'set',
            'binding': 'error_flag',
            'value': true,
          },
        },
        context,
      );

      expect(stateManager.get('error_flag'), isNull);
    });
  });

  group('TC-034: ToolActionExecutor — default tool executor', () {
    test('TC-034 Normal: default executor handles unregistered tool names', () async {
      actionHandler.registerToolExecutor('default', (tool, params) async {
        return {'success': true, 'result': tool};
      });

      final result = await actionHandler.execute(
        {'type': 'tool', 'tool': 'unknownTool', 'params': {}},
        context,
      );

      expect(result.success, isTrue);
      expect(result.data, equals('unknownTool'));
    });

    test('TC-034 Normal: specific executor takes priority over default', () async {
      actionHandler.registerToolExecutor('default', (tool, params) async {
        return {'success': true, 'result': 'default'};
      });
      actionHandler.registerToolExecutor('specific', (params) async {
        return {'success': true, 'result': 'specific'};
      });

      final result = await actionHandler.execute(
        {'type': 'tool', 'tool': 'specific', 'params': {}},
        context,
      );

      expect(result.data, equals('specific'));
    });

    test('TC-034 Boundary: default executor receives tool name as first arg', () async {
      String? receivedToolName;

      actionHandler.registerToolExecutor('default', (tool, params) async {
        receivedToolName = tool;
        return {'success': true, 'result': 'ok'};
      });

      await actionHandler.execute(
        {'type': 'tool', 'tool': 'myCustomTool', 'params': {}},
        context,
      );

      expect(receivedToolName, equals('myCustomTool'));
    });
  });

  group('TC-035: ToolActionExecutor — tool error returns ActionResult.error', () {
    test('TC-035 Normal: tool that throws exception returns error result', () async {
      actionHandler.registerToolExecutor('throwTool', (params) async {
        throw Exception('Tool crashed');
      });

      final result = await actionHandler.execute(
        {'type': 'tool', 'tool': 'throwTool', 'params': {}},
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Tool crashed'));
    });

    test('TC-035 Boundary: tool returning success=false has error message', () async {
      actionHandler.registerToolExecutor('failTool', (params) async {
        return {'success': false, 'error': 'Validation failed'};
      });

      final result = await actionHandler.execute(
        {'type': 'tool', 'tool': 'failTool', 'params': {}},
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Validation failed'));
    });
  });

  group('TC-036: ToolActionExecutor — tool timeout', () {
    test('TC-036 Normal: tool exceeding timeout returns error', () async {
      actionHandler.registerToolExecutor('slow', (params) async {
        await Future.delayed(const Duration(milliseconds: 500));
        return {'success': true, 'result': 'done'};
      });

      final result = await actionHandler.execute(
        {
          'type': 'tool',
          'tool': 'slow',
          'params': {},
          'timeout': 100,
        },
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('timed out'));
    });

    test('TC-036 Normal: tool completing within timeout returns success', () async {
      actionHandler.registerToolExecutor('fast', (params) async {
        return {'success': true, 'result': 'quick'};
      });

      final result = await actionHandler.execute(
        {
          'type': 'tool',
          'tool': 'fast',
          'params': {},
          'timeout': 5000,
        },
        context,
      );

      expect(result.success, isTrue);
      expect(result.data, equals('quick'));
    });

    test('TC-036 Boundary: timeout of 0 disables timeout check', () async {
      actionHandler.registerToolExecutor('noTimeout', (params) async {
        return {'success': true, 'result': 'done'};
      });

      final result = await actionHandler.execute(
        {
          'type': 'tool',
          'tool': 'noTimeout',
          'params': {},
          'timeout': 0,
        },
        context,
      );

      expect(result.success, isTrue);
    });
  });

  group('TC-037: ToolActionExecutor — missing tool executor', () {
    test('TC-037 Normal: unregistered tool without default returns error', () async {
      final result = await actionHandler.execute(
        {'type': 'tool', 'tool': 'nonexistent', 'params': {}},
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Tool executor not found'));
    });

    test('TC-037 Error: tool name is null returns error', () async {
      final result = await actionHandler.execute(
        {'type': 'tool'},
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Tool name is required'));
    });
  });

  group('TC-038: ToolActionExecutor — bindResult stores result at custom path', () {
    test('TC-038 Normal: bindResult stores tool result at custom state path', () async {
      actionHandler.registerToolExecutor('myTool', (params) async {
        return {'success': true, 'result': {'items': [1, 2, 3]}};
      });

      await actionHandler.execute(
        {
          'type': 'tool',
          'tool': 'myTool',
          'params': {},
          'bindResult': 'custom.path',
        },
        context,
      );

      final customResult = stateManager.get('custom.path');
      expect(customResult, isNotNull);
      expect(customResult['items'], equals([1, 2, 3]));
    });

    test('TC-038 Normal: bindResult and auto-merge both set', () async {
      actionHandler.registerToolExecutor('myTool', (params) async {
        return {'success': true, 'result': 'data'};
      });

      await actionHandler.execute(
        {
          'type': 'tool',
          'tool': 'myTool',
          'params': {},
          'bindResult': 'output',
        },
        context,
      );

      // Both auto-merge and custom path should be set
      expect(stateManager.get('tools.myTool.result'), equals('data'));
      expect(stateManager.get('output'), equals('data'));
    });

    test('TC-038 Boundary: bindResult with deeply nested path', () async {
      actionHandler.registerToolExecutor('myTool', (params) async {
        return {'success': true, 'result': 42};
      });

      await actionHandler.execute(
        {
          'type': 'tool',
          'tool': 'myTool',
          'params': {},
          'bindResult': 'deep.nested.result.value',
        },
        context,
      );

      expect(stateManager.get('deep.nested.result.value'), equals(42));
    });
  });
}
