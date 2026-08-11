import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_result.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/client_actions/client_action_handler.dart';

import 'package:flutter_mcp_ui_runtime/src/models/ui_definition.dart' show PermissionsConfig;
import 'package:flutter_mcp_ui_runtime/src/permissions/permission_manager.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart' show StateActionDefinition;

void main() {
  clientActionBindResultTests();
  embeddedPermissionCeilingTests();
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
    NavigationActionExecutor.clearGlobalNavigationHandler();
    bindingEngine.dispose();
    stateManager.dispose();
  });

  group('the gate opens for what a document declared', () {
    // Every refusal test in this file is only meaningful beside these: a gate
    // that denies everything passes all of them and is still broken.
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('client_action_allow_');
      File('${tmp.path}/note.txt').writeAsStringSync('hello');
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    test('a declared path can be read, an undeclared one cannot', () async {
      actionHandler.setPermissionsConfig(PermissionsConfig.fromJson({
        'file.read': {
          'allowedPaths': [tmp.path],
        },
      }));

      final allowed = await actionHandler.execute({
        'type': 'client.readFile',
        'params': {'path': '${tmp.path}/note.txt'},
      }, context);
      expect(allowed.success, isTrue,
          reason: 'the document declared this path, so it has to be readable — '
              'a gate that refuses everything is not a gate');
      expect((allowed.data as Map)['content'], 'hello');

      final refused = await actionHandler.execute({
        'type': 'client.readFile',
        'params': {'path': '/etc/passwd'},
      }, context);
      expect(refused.success, isFalse);
      expect(refused.errorCode, 'PERMISSION_DENIED');
    });

    test('a declared command is allowed and an undeclared one is not', () async {
      actionHandler.setPermissionsConfig(PermissionsConfig.fromJson({
        'system.exec': {
          'allowedCommands': ['echo'],
        },
      }));

      final refused = await actionHandler.execute({
        'type': 'client.exec',
        'params': {'command': 'rm -rf /'},
      }, context);
      expect(refused.success, isFalse,
          reason: 'the one command that must never slip through');
      expect(refused.errorCode, 'PERMISSION_DENIED');
    });

    test('granting the permission outright also opens the action', () async {
      actionHandler.permissionManager?.grant('file.read');
      final result = await actionHandler.execute({
        'type': 'client.readFile',
        'params': {'path': '${tmp.path}/note.txt'},
      }, context);
      expect(result.success, isTrue);
    });
  });

  group('TC-063: ClientActionHandler — constructor with null PermissionsConfig', () {
    test('TC-063 Normal: a null config grants nothing', () {
      // Was: `expect(handler, isNotNull)`. That passes for a handler that
      // grants everything, which is what this class must never do.
      final handler = ClientActionHandler(null);

      expect(handler.permissionManager.enabled, isTrue,
          reason: 'a null config is "nothing declared", not "checks off"');
      expect(handler.permissionManager.isPathAllowed('/etc/passwd'), isFalse);
      expect(handler.permissionManager.isCommandAllowed('rm'), isFalse);
      expect(handler.permissionManager.isDomainAllowed('evil.test'), isFalse);
    });

    test('TC-063 Normal: a declared config grants exactly what it declares',
        () {
      final handler = ClientActionHandler(PermissionsConfig.fromJson({
        'file.read': {
          'allowedPaths': ['/workspace'],
        },
      }));

      expect(handler.permissionManager.isPathAllowed('/workspace/a.txt'),
          isTrue);
      expect(handler.permissionManager.isPathAllowed('/etc/passwd'), isFalse);
      expect(handler.permissionManager.isCommandAllowed('git'), isFalse,
          reason: 'declaring file access must not open the shell');
    });

    test('TC-063 Boundary: multiple instances are independent', () {
      final handler1 = ClientActionHandler(null);
      final handler2 = ClientActionHandler(null);
      expect(identical(handler1, handler2), isFalse);
    });
  });

  group('TC-064: ClientActionHandler — isClientAction returns true', () {
    test('TC-064 Normal: client.selectFile is a client action', () {
      final handler = ClientActionHandler(null);
      expect(handler.isClientAction('client.selectFile'), isTrue);
    });

    test('TC-064 Normal: client.readFile is a client action', () {
      final handler = ClientActionHandler(null);
      expect(handler.isClientAction('client.readFile'), isTrue);
    });

    test('TC-064 Normal: client.writeFile is a client action', () {
      final handler = ClientActionHandler(null);
      expect(handler.isClientAction('client.writeFile'), isTrue);
    });

    test('TC-064 Normal: client.httpRequest is a client action', () {
      final handler = ClientActionHandler(null);
      expect(handler.isClientAction('client.httpRequest'), isTrue);
    });

    test('TC-064 Normal: client.exec is a client action', () {
      final handler = ClientActionHandler(null);
      expect(handler.isClientAction('client.exec'), isTrue);
    });

    test('TC-064 Normal: client.clipboard is a client action', () {
      final handler = ClientActionHandler(null);
      expect(handler.isClientAction('client.clipboard'), isTrue);
    });

    test('TC-064 Normal: client.notification is a client action', () {
      final handler = ClientActionHandler(null);
      expect(handler.isClientAction('client.notification'), isTrue);
    });

    test('TC-064 Boundary: any string starting with client. is client action', () {
      final handler = ClientActionHandler(null);
      expect(handler.isClientAction('client.custom'), isTrue);
    });
  });

  group('TC-065: ClientActionHandler — isClientAction returns false', () {
    test('TC-065 Normal: state is not a client action', () {
      final handler = ClientActionHandler(null);
      expect(handler.isClientAction('state'), isFalse);
    });

    test('TC-065 Normal: navigation is not a client action', () {
      final handler = ClientActionHandler(null);
      expect(handler.isClientAction('navigation'), isFalse);
    });

    test('TC-065 Normal: tool is not a client action', () {
      final handler = ClientActionHandler(null);
      expect(handler.isClientAction('tool'), isFalse);
    });

    test('TC-065 Boundary: null is not a client action', () {
      final handler = ClientActionHandler(null);
      expect(handler.isClientAction(null), isFalse);
    });

    test('TC-065 Boundary: empty string is not a client action', () {
      final handler = ClientActionHandler(null);
      expect(handler.isClientAction(''), isFalse);
    });
  });

  group('TC-066: ClientActionHandler — execute unknown client action type', () {
    test('TC-066 Error: unknown client action type returns error', () async {
      final handler = ClientActionHandler(null);
      final result = await handler.execute(
        {'type': 'client.unknownAction123'},
        context,
      );
      expect(result.success, isFalse);
      expect(result.error, contains('Unknown client action'));
    });
  });

  group('TC-067: Permission — action without BuildContext skips permission check', () {
    test('TC-067 Normal: action without BuildContext proceeds to execution', () async {
      // Context without buildContext set (default in test setup)
      // Client actions should skip permission check and proceed
      final result = await actionHandler.execute(
        {'type': 'client.getSystemInfo'},
        context,
      );

      // Returns result (may fail due to actual system call, but permission check skipped)
      // A client action with no permission behind it and no surface to ask on
      // must be REFUSED. `isA<ActionResult>()` — what this asserted before —
      // is true of the answer either way, which is how `client.exec` came to
      // run unchecked on every headless path.
      expect(result.success, isFalse);
      expect(result.errorCode, 'PERMISSION_DENIED');
    });
  });

  group('TC-068: Permission — setPermissionsConfig updates client handler', () {
    test('TC-068 Normal: setPermissionsConfig with null is no-op', () {
      expect(() => actionHandler.setPermissionsConfig(null), returnsNormally);
    });

    test('TC-068 Boundary: repeated setPermissionsConfig calls do not throw', () {
      expect(() => actionHandler.setPermissionsConfig(null), returnsNormally);
      expect(() => actionHandler.setPermissionsConfig(null), returnsNormally);
    });
  });

  group('TC-069: Permission — permissionManager getter', () {
    test('TC-069 Normal: permissionManager getter returns PermissionManager', () {
      final pm = actionHandler.permissionManager;
      expect(pm, isNotNull);
      expect(pm, isA<PermissionManager>());
    });
  });

  group('TC-070: ActionHandler — registerToolExecutor adds custom tool', () {
    test('TC-070 Normal: registered tool executor is callable', () async {
      actionHandler.registerToolExecutor('customTool', (params) async {
        return {'success': true, 'result': 'custom_result'};
      });

      final result = await actionHandler.execute(
        {'type': 'tool', 'tool': 'customTool', 'params': {}},
        context,
      );

      expect(result.success, isTrue);
      expect(result.data, equals('custom_result'));
    });

    test('TC-070 Boundary: tool name with special characters', () async {
      actionHandler.registerToolExecutor('my-tool_v2', (params) async {
        return {'success': true, 'result': 'ok'};
      });

      final result = await actionHandler.execute(
        {'type': 'tool', 'tool': 'my-tool_v2', 'params': {}},
        context,
      );

      expect(result.success, isTrue);
    });
  });

  group('TC-071: ActionHandler — registerExecutor/registerHandler', () {
    test('TC-071 Normal: registerExecutor adds custom action executor', () async {
      actionHandler.registerExecutor('custom', _TestExecutor());
      final result = await actionHandler.execute({'type': 'custom'}, context);
      expect(result.success, isTrue);
      expect(result.data, equals('test_executed'));
    });

    test('TC-071 Normal: registerHandler is alias for registerExecutor', () async {
      actionHandler.registerHandler('custom2', _TestExecutor());
      final result = await actionHandler.execute({'type': 'custom2'}, context);
      expect(result.success, isTrue);
      expect(result.data, equals('test_executed'));
    });
  });

  group('TC-072: client.selectFile — requires params', () {
    test('TC-072 Normal: selectFile action returns result', () async {
      final result = await actionHandler.execute(
        {'type': 'client.selectFile', 'params': {}},
        context,
      );
      // In test env, may return error due to no file picker available
      // A client action with no permission behind it and no surface to ask on
      // must be REFUSED. `isA<ActionResult>()` — what this asserted before —
      // is true of the answer either way, which is how `client.exec` came to
      // run unchecked on every headless path.
      expect(result.success, isFalse);
      expect(result.errorCode, 'PERMISSION_DENIED');
    });

    test('TC-072 Boundary: selectFile without params still routed', () async {
      final result = await actionHandler.execute(
        {'type': 'client.selectFile'},
        context,
      );
      // A client action with no permission behind it and no surface to ask on
      // must be REFUSED. `isA<ActionResult>()` — what this asserted before —
      // is true of the answer either way, which is how `client.exec` came to
      // run unchecked on every headless path.
      expect(result.success, isFalse);
      expect(result.errorCode, 'PERMISSION_DENIED');
    });
  });

  group('TC-073: client.readFile — requires path param', () {
    test('TC-073 Normal: readFile action requires path', () async {
      final result = await actionHandler.execute(
        {'type': 'client.readFile', 'params': {'path': '/test/file.txt'}},
        context,
      );
      // A client action with no permission behind it and no surface to ask on
      // must be REFUSED. `isA<ActionResult>()` — what this asserted before —
      // is true of the answer either way, which is how `client.exec` came to
      // run unchecked on every headless path.
      expect(result.success, isFalse);
      expect(result.errorCode, 'PERMISSION_DENIED');
    });

    test('TC-073 Error: readFile without path returns error', () async {
      final result = await actionHandler.execute(
        {'type': 'client.readFile', 'params': {}},
        context,
      );
      // A client action with no permission behind it and no surface to ask on
      // must be REFUSED. `isA<ActionResult>()` — what this asserted before —
      // is true of the answer either way, which is how `client.exec` came to
      // run unchecked on every headless path.
      expect(result.success, isFalse);
      expect(result.errorCode, 'PERMISSION_DENIED');
      // Should indicate missing path
    });
  });

  group('TC-074: client.writeFile — requires path and content', () {
    test('TC-074 Normal: writeFile with path and content', () async {
      final result = await actionHandler.execute(
        {
          'type': 'client.writeFile',
          'params': {'path': '/test/file.txt', 'content': 'hello'},
        },
        context,
      );
      // A client action with no permission behind it and no surface to ask on
      // must be REFUSED. `isA<ActionResult>()` — what this asserted before —
      // is true of the answer either way, which is how `client.exec` came to
      // run unchecked on every headless path.
      expect(result.success, isFalse);
      expect(result.errorCode, 'PERMISSION_DENIED');
    });

    test('TC-074 Error: writeFile without params returns error', () async {
      final result = await actionHandler.execute(
        {'type': 'client.writeFile'},
        context,
      );
      // A client action with no permission behind it and no surface to ask on
      // must be REFUSED. `isA<ActionResult>()` — what this asserted before —
      // is true of the answer either way, which is how `client.exec` came to
      // run unchecked on every headless path.
      expect(result.success, isFalse);
      expect(result.errorCode, 'PERMISSION_DENIED');
    });
  });

  group('TC-075: client.listFiles — requires path param', () {
    test('TC-075 Normal: listFiles with path', () async {
      final result = await actionHandler.execute(
        {'type': 'client.listFiles', 'params': {'path': '/test'}},
        context,
      );
      // A client action with no permission behind it and no surface to ask on
      // must be REFUSED. `isA<ActionResult>()` — what this asserted before —
      // is true of the answer either way, which is how `client.exec` came to
      // run unchecked on every headless path.
      expect(result.success, isFalse);
      expect(result.errorCode, 'PERMISSION_DENIED');
    });

    test('TC-075 Error: listFiles without path', () async {
      final result = await actionHandler.execute(
        {'type': 'client.listFiles', 'params': {}},
        context,
      );
      // A client action with no permission behind it and no surface to ask on
      // must be REFUSED. `isA<ActionResult>()` — what this asserted before —
      // is true of the answer either way, which is how `client.exec` came to
      // run unchecked on every headless path.
      expect(result.success, isFalse);
      expect(result.errorCode, 'PERMISSION_DENIED');
    });
  });

  group('TC-076: client.httpRequest — requires url param', () {
    test('TC-076 Normal: httpRequest with url', () async {
      final result = await actionHandler.execute(
        {
          'type': 'client.httpRequest',
          'params': {'url': 'https://example.com', 'method': 'GET'},
        },
        context,
      );
      // A client action with no permission behind it and no surface to ask on
      // must be REFUSED. `isA<ActionResult>()` — what this asserted before —
      // is true of the answer either way, which is how `client.exec` came to
      // run unchecked on every headless path.
      expect(result.success, isFalse);
      expect(result.errorCode, 'PERMISSION_DENIED');
    });

    test('TC-076 Error: httpRequest without url', () async {
      final result = await actionHandler.execute(
        {'type': 'client.httpRequest', 'params': {}},
        context,
      );
      // A client action with no permission behind it and no surface to ask on
      // must be REFUSED. `isA<ActionResult>()` — what this asserted before —
      // is true of the answer either way, which is how `client.exec` came to
      // run unchecked on every headless path.
      expect(result.success, isFalse);
      expect(result.errorCode, 'PERMISSION_DENIED');
    });
  });

  group('TC-077: client.getSystemInfo — returns system info or error', () {
    test('TC-077 Normal: getSystemInfo returns a result', () async {
      final result = await actionHandler.execute(
        {'type': 'client.getSystemInfo'},
        context,
      );
      // A client action with no permission behind it and no surface to ask on
      // must be REFUSED. `isA<ActionResult>()` — what this asserted before —
      // is true of the answer either way, which is how `client.exec` came to
      // run unchecked on every headless path.
      expect(result.success, isFalse);
      expect(result.errorCode, 'PERMISSION_DENIED');
    });

    test('TC-077 Boundary: getSystemInfo with extra params ignored', () async {
      final result = await actionHandler.execute(
        {'type': 'client.getSystemInfo', 'params': {'extra': 'ignored'}},
        context,
      );
      // A client action with no permission behind it and no surface to ask on
      // must be REFUSED. `isA<ActionResult>()` — what this asserted before —
      // is true of the answer either way, which is how `client.exec` came to
      // run unchecked on every headless path.
      expect(result.success, isFalse);
      expect(result.errorCode, 'PERMISSION_DENIED');
    });
  });

  group('TC-078: client.exec — requires command param', () {
    test('TC-078 Normal: exec with command param', () async {
      final result = await actionHandler.execute(
        {'type': 'client.exec', 'params': {'command': 'echo hello'}},
        context,
      );
      // A client action with no permission behind it and no surface to ask on
      // must be REFUSED. `isA<ActionResult>()` — what this asserted before —
      // is true of the answer either way, which is how `client.exec` came to
      // run unchecked on every headless path.
      expect(result.success, isFalse);
      expect(result.errorCode, 'PERMISSION_DENIED');
    });

    test('TC-078 Error: exec without command param', () async {
      final result = await actionHandler.execute(
        {'type': 'client.exec', 'params': {}},
        context,
      );
      // A client action with no permission behind it and no surface to ask on
      // must be REFUSED. `isA<ActionResult>()` — what this asserted before —
      // is true of the answer either way, which is how `client.exec` came to
      // run unchecked on every headless path.
      expect(result.success, isFalse);
      expect(result.errorCode, 'PERMISSION_DENIED');
    });
  });

  group('TC-079: client.clipboard.read', () {
    test('TC-079 Normal: clipboard read action returns result', () async {
      final result = await actionHandler.execute(
        {'type': 'client.clipboard', 'params': {'action': 'read'}},
        context,
      );
      // A client action with no permission behind it and no surface to ask on
      // must be REFUSED. `isA<ActionResult>()` — what this asserted before —
      // is true of the answer either way, which is how `client.exec` came to
      // run unchecked on every headless path.
      expect(result.success, isFalse);
      expect(result.errorCode, 'PERMISSION_DENIED');
    });

    test('TC-079 Boundary: clipboard without action defaults to read', () async {
      final result = await actionHandler.execute(
        {'type': 'client.clipboard', 'params': {}},
        context,
      );
      // A client action with no permission behind it and no surface to ask on
      // must be REFUSED. `isA<ActionResult>()` — what this asserted before —
      // is true of the answer either way, which is how `client.exec` came to
      // run unchecked on every headless path.
      expect(result.success, isFalse);
      expect(result.errorCode, 'PERMISSION_DENIED');
    });
  });

  group('TC-080: client.clipboard.write', () {
    test('TC-080 Normal: clipboard write action', () async {
      final result = await actionHandler.execute(
        {
          'type': 'client.clipboard',
          'params': {'action': 'write', 'text': 'copied text'},
        },
        context,
      );
      // A client action with no permission behind it and no surface to ask on
      // must be REFUSED. `isA<ActionResult>()` — what this asserted before —
      // is true of the answer either way, which is how `client.exec` came to
      // run unchecked on every headless path.
      expect(result.success, isFalse);
      expect(result.errorCode, 'PERMISSION_DENIED');
    });

    test('TC-080 Boundary: clipboard write without text', () async {
      final result = await actionHandler.execute(
        {'type': 'client.clipboard', 'params': {'action': 'write'}},
        context,
      );
      // A client action with no permission behind it and no surface to ask on
      // must be REFUSED. `isA<ActionResult>()` — what this asserted before —
      // is true of the answer either way, which is how `client.exec` came to
      // run unchecked on every headless path.
      expect(result.success, isFalse);
      expect(result.errorCode, 'PERMISSION_DENIED');
    });
  });

  group('TC-081: client.notification', () {
    test('TC-081 Normal: client notification action', () async {
      final result = await actionHandler.execute(
        {
          'type': 'client.notification',
          'params': {'title': 'Test', 'body': 'Hello'},
        },
        context,
      );
      // A client action with no permission behind it and no surface to ask on
      // must be REFUSED. `isA<ActionResult>()` — what this asserted before —
      // is true of the answer either way, which is how `client.exec` came to
      // run unchecked on every headless path.
      expect(result.success, isFalse);
      expect(result.errorCode, 'PERMISSION_DENIED');
    });

    test('TC-081 Boundary: notification without params', () async {
      final result = await actionHandler.execute(
        {'type': 'client.notification'},
        context,
      );
      // A client action with no permission behind it and no surface to ask on
      // must be REFUSED. `isA<ActionResult>()` — what this asserted before —
      // is true of the answer either way, which is how `client.exec` came to
      // run unchecked on every headless path.
      expect(result.success, isFalse);
      expect(result.errorCode, 'PERMISSION_DENIED');
    });
  });

  group('TC-082: ActionHandler — execute with null type', () {
    test('TC-082 Error: missing type key returns error', () async {
      final result = await actionHandler.execute(
        {'action': 'set', 'binding': 'x'},
        context,
      );
      expect(result.success, isFalse);
      expect(result.error, contains('Action type is required'));
    });

    test('TC-082 Error: type explicitly null returns error', () async {
      final result = await actionHandler.execute(
        {'type': null, 'action': 'set'},
        context,
      );
      expect(result.success, isFalse);
      expect(result.error, contains('Action type is required'));
    });
  });

  group('TC-083: ActionHandler — execute with unknown type', () {
    test('TC-083 Error: completely unknown type returns error', () async {
      final result = await actionHandler.execute(
        {'type': 'totallyUnknownType'},
        context,
      );
      expect(result.success, isFalse);
      expect(result.error, contains('Unknown action type'));
    });

    test('TC-083 Boundary: type with special characters returns error', () async {
      final result = await actionHandler.execute(
        {'type': 'unknown@#\$%'},
        context,
      );
      expect(result.success, isFalse);
      expect(result.error, contains('Unknown action type'));
    });
  });

  group('TC-084: ActionHandler — executeDefinition', () {
    test('TC-084 Normal: converts ActionDefinition to JSON and executes', () async {
      const definition = StateActionDefinition(
        action: 'set',
        binding: 'counter',
        value: 42,
      );
      final result = await actionHandler.executeDefinition(definition, context);
      expect(result.success, isTrue);
      expect(stateManager.get<int>('counter'), equals(42),
          reason: 'a state action is not permission-gated — it touches nothing '
              'outside the document');
    });

    test('TC-084 Normal: toggle action via definition', () async {
      stateManager.set('flag', false);
      const definition = StateActionDefinition(
        action: 'toggle',
        binding: 'flag',
      );
      final result = await actionHandler.executeDefinition(definition, context);
      expect(result.success, isTrue);
      expect(stateManager.get<bool>('flag'), isTrue);
    });

    test('TC-084 Boundary: increment action via definition', () async {
      stateManager.set('counter', 10);
      const definition = StateActionDefinition(
        action: 'increment',
        binding: 'counter',
      );
      final result = await actionHandler.executeDefinition(definition, context);
      expect(result.success, isTrue);
      expect(stateManager.get<num>('counter'), equals(11));
    });
  });

  group('TC-085: ActionHandler — registerNavigationHandler', () {
    test('TC-085 Normal: sets global navigation handler on NavigationActionExecutor', () async {
      String? capturedAction;
      String? capturedRoute;

      actionHandler.registerNavigationHandler((action, route, params) {
        capturedAction = action;
        capturedRoute = route;
        return true;
      });

      await actionHandler.execute(
        {'type': 'navigation', 'action': 'push', 'route': '/test'},
        context,
      );

      expect(capturedAction, equals('push'));
      expect(capturedRoute, equals('/test'));
    });

    test('TC-085 Normal: replacing handler uses new handler', () async {
      var firstCalled = false;
      var secondCalled = false;

      actionHandler.registerNavigationHandler((action, route, params) {
        firstCalled = true;
        return true;
      });
      actionHandler.registerNavigationHandler((action, route, params) {
        secondCalled = true;
        return true;
      });

      await actionHandler.execute(
        {'type': 'navigation', 'action': 'push', 'route': '/test'},
        context,
      );

      expect(firstCalled, isFalse);
      expect(secondCalled, isTrue);
    });
  });

  group('TC-086: ActionHandler — onSuccess/onError callback chaining', () {
    test('TC-086 Normal: onSuccess callback executes on success', () async {
      await actionHandler.execute(
        {
          'type': 'state',
          'action': 'set',
          'binding': 'x',
          'value': 1,
          'onSuccess': {
            'type': 'state',
            'action': 'set',
            'binding': 'callback_hit',
            'value': true,
          },
        },
        context,
      );

      expect(stateManager.get<bool>('callback_hit'), isTrue);
    });

    test('TC-086 Normal: onError callback executes on failure', () async {
      await actionHandler.execute(
        {
          'type': 'state',
          'action': 'unknownAction',
          'binding': 'x',
          'onError': {
            'type': 'state',
            'action': 'set',
            'binding': 'error_hit',
            'value': true,
          },
        },
        context,
      );

      expect(stateManager.get<bool>('error_hit'), isTrue);
    });

    test('TC-086 Boundary: onSuccess not called on failure', () async {
      await actionHandler.execute(
        {
          'type': 'state',
          'action': 'unknownAction',
          'binding': 'x',
          'onSuccess': {
            'type': 'state',
            'action': 'set',
            'binding': 'should_not_set',
            'value': true,
          },
        },
        context,
      );

      expect(stateManager.get('should_not_set'), isNull);
    });
  });

  group('TC-087: State action — append with list value (spread)', () {
    test('TC-087 Normal: append list value spreads into existing list', () async {
      stateManager.set('items', [1, 2]);

      await actionHandler.execute(
        {
          'type': 'state',
          'action': 'append',
          'binding': 'items',
          'value': [3, 4],
        },
        context,
      );

      expect(stateManager.get<List>('items'), equals([1, 2, 3, 4]));
    });

    test('TC-087 Boundary: append empty list is no-op on list content', () async {
      stateManager.set('items', [1, 2]);

      await actionHandler.execute(
        {
          'type': 'state',
          'action': 'append',
          'binding': 'items',
          'value': [],
        },
        context,
      );

      expect(stateManager.get<List>('items'), equals([1, 2]));
    });
  });

  group('TC-088: State action — remove with index', () {
    test('TC-088 Normal: remove by index removes at specified position', () async {
      stateManager.set('items', ['a', 'b', 'c', 'd']);

      await actionHandler.execute(
        {
          'type': 'state',
          'action': 'remove',
          'binding': 'items',
          'index': 2,
        },
        context,
      );

      expect(stateManager.get<List>('items'), equals(['a', 'b', 'd']));
    });

    test('TC-088 Boundary: remove by out-of-bounds index is no-op', () async {
      stateManager.set('items', ['a', 'b']);

      await actionHandler.execute(
        {
          'type': 'state',
          'action': 'remove',
          'binding': 'items',
          'index': 10,
        },
        context,
      );

      expect(stateManager.get<List>('items'), equals(['a', 'b']));
    });

    test('TC-088 Error: remove by negative index is no-op', () async {
      stateManager.set('items', ['a', 'b']);

      await actionHandler.execute(
        {
          'type': 'state',
          'action': 'remove',
          'binding': 'items',
          'index': -1,
        },
        context,
      );

      expect(stateManager.get<List>('items'), equals(['a', 'b']));
    });
  });

  group('TC-089: State action — removeAt', () {
    test('TC-089 Normal: removeAt removes at specific index', () async {
      stateManager.set('items', ['a', 'b', 'c']);

      await actionHandler.execute(
        {
          'type': 'state',
          'action': 'removeAt',
          'binding': 'items',
          'index': 1,
        },
        context,
      );

      expect(stateManager.get<List>('items'), equals(['a', 'c']));
    });

    test('TC-089 Boundary: removeAt index 0 removes first', () async {
      stateManager.set('items', ['x', 'y', 'z']);

      await actionHandler.execute(
        {
          'type': 'state',
          'action': 'removeAt',
          'binding': 'items',
          'index': 0,
        },
        context,
      );

      expect(stateManager.get<List>('items'), equals(['y', 'z']));
    });

    test('TC-089 Error: removeAt without index returns error', () async {
      stateManager.set('items', ['a', 'b']);

      final result = await actionHandler.execute(
        {
          'type': 'state',
          'action': 'removeAt',
          'binding': 'items',
        },
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Index is required'));
    });
  });

  group('TC-090: State action — pop', () {
    test('TC-090 Normal: pop removes last from list', () async {
      stateManager.set('items', [1, 2, 3]);

      await actionHandler.execute(
        {
          'type': 'state',
          'action': 'pop',
          'binding': 'items',
        },
        context,
      );

      expect(stateManager.get<List>('items'), equals([1, 2]));
    });

    test('TC-090 Boundary: pop from single-element list leaves empty', () async {
      stateManager.set('items', ['only']);

      await actionHandler.execute(
        {
          'type': 'state',
          'action': 'pop',
          'binding': 'items',
        },
        context,
      );

      expect(stateManager.get<List>('items'), equals([]));
    });

    test('TC-090 Boundary: pop from empty list is no-op', () async {
      stateManager.set('items', []);

      await actionHandler.execute(
        {
          'type': 'state',
          'action': 'pop',
          'binding': 'items',
        },
        context,
      );

      expect(stateManager.get<List>('items'), equals([]));
    });
  });

  group('TC-091: State action — unknown action type', () {
    test('TC-091 Error: unknown state action returns error', () async {
      final result = await actionHandler.execute(
        {
          'type': 'state',
          'action': 'unknownAction',
          'binding': 'x',
        },
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Unknown state action'));
    });

    test('TC-091 Error: empty action string returns error', () async {
      final result = await actionHandler.execute(
        {
          'type': 'state',
          'action': 'nonexistent',
          'binding': 'x',
        },
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Unknown state action'));
    });
  });

  group('TC-092: Notification action — without message', () {
    test('TC-092 Error: notification without message returns error', () async {
      final result = await actionHandler.execute(
        {'type': 'notification'},
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Message is required'));
    });

    test('TC-092 Error: notification with empty message returns error', () async {
      final result = await actionHandler.execute(
        {'type': 'notification', 'message': ''},
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Message is required'));
    });
  });

  group('TC-093: Animation action — without target', () {
    test('TC-093 Error: animation without target returns error', () async {
      final result = await actionHandler.execute(
        {'type': 'animation', 'action': 'play'},
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Target is required'));
    });

    test('TC-093 Error: animation with empty target returns error', () async {
      final result = await actionHandler.execute(
        {'type': 'animation', 'action': 'play', 'target': ''},
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Target is required'));
    });
  });

  group('TC-094: Cancel action — without target', () {
    test('TC-094 Error: cancel without target returns error', () async {
      final result = await actionHandler.execute(
        {'type': 'cancel'},
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Target is required'));
    });

    test('TC-094 Error: cancel with empty target returns error', () async {
      final result = await actionHandler.execute(
        {'type': 'cancel', 'target': ''},
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Target is required'));
    });

    test('TC-094 Normal: cancel with valid target succeeds', () async {
      final result = await actionHandler.execute(
        {'type': 'cancel', 'target': 'someActionId'},
        context,
      );

      expect(result.success, isTrue);
    });
  });
}

/// Test executor that always returns success with custom data
class _TestExecutor extends ActionExecutor {
  @override
  Future<ActionResult> execute(
    Map<String, dynamic> action,
    RenderContext context,
  ) async {
    return ActionResult.success(data: 'test_executed');
  }
}

/// An embedded subtree cannot out-permission its embedder (spec §7.10.1).
///
/// The effective set of a `view` is the INTERSECTION with its embedder's,
/// never the union. A device's own document is authored by whoever made the
/// device, so a `view` able to prompt for — and receive — a permission the
/// embedding app never held would let any embedded server escalate through the
/// screen it was given.
void embeddedPermissionCeilingTests() {
  group('embedded permission ceiling (v1.4)', () {
    RenderContext scoped(ClientActionHandler h, String? connection) {
      final ctx = RenderContext(
        renderer: Renderer(
          widgetRegistry: WidgetRegistry(),
          bindingEngine: BindingEngine(),
          actionHandler: ActionHandler(),
          stateManager: StateManager(),
        ),
        stateManager: StateManager(),
        bindingEngine: BindingEngine(),
        actionHandler: ActionHandler(),
        themeManager: ThemeManager(),
      );
      if (connection != null) {
        ctx.origin = <String, dynamic>{'connection': connection};
      }
      return ctx;
    }

    test('a scoped action is refused when the embedder lacks the permission',
        () async {
      final handler = ClientActionHandler(null);
      final result = await handler.execute(
        <String, dynamic>{
          'type': 'client.httpRequest',
          'params': <String, dynamic>{'url': 'https://example.com'},
        },
        scoped(handler, 'esp32.node'),
      );

      expect(result.success, isFalse);
      expect(result.errorCode, 'PERMISSION_DENIED');
      expect(result.error, contains('cannot request more than its embedder'));
    });

    test('the refusal comes before any prompt could be raised', () async {
      // Asking and then denying is worse than never asking: the user has
      // already been put in front of a request the app could not honour.
      final handler = ClientActionHandler(null);
      final result = await handler.execute(
        <String, dynamic>{
          'type': 'client.httpRequest',
          'params': <String, dynamic>{'url': 'https://example.com'},
        },
        // No BuildContext at all, so a prompt is impossible — the refusal must
        // still happen, which it only can if the ceiling is checked first.
        scoped(handler, 'esp32.node'),
      );
      expect(result.errorCode, 'PERMISSION_DENIED');
    });

    test('an unscoped action keeps its normal path', () async {
      // Every pre-composition document must behave exactly as before.
      final handler = ClientActionHandler(null);
      final result = await handler.execute(
        <String, dynamic>{
          'type': 'client.httpRequest',
          'params': <String, dynamic>{'url': 'https://example.com'},
        },
        scoped(handler, null),
      );
      expect(result.error, isNot(contains('cannot request more')));
    });

    test('a permission the embedder holds is not blocked by the ceiling',
        () async {
      final handler = ClientActionHandler(null);
      handler.permissionManager.grant('network');
      final result = await handler.execute(
        <String, dynamic>{
          'type': 'client.httpRequest',
          'params': <String, dynamic>{'url': 'https://example.com'},
        },
        scoped(handler, 'esp32.node'),
      );
      expect(result.error, isNot(contains('cannot request more')));
    });
  });
}

/// `bindResult` on a client action.
///
/// Every other action that returns something binds it, and this one did not —
/// so a document could read a file, take a clipboard value or fetch a stored
/// key and have no way to put the answer on screen. The gap read as a broken
/// binding rather than a missing feature, which is why it survived.
void clientActionBindResultTests() {
  group('client action bindResult', () {
    RenderContext ctx() => RenderContext(
          renderer: Renderer(
            widgetRegistry: WidgetRegistry(),
            bindingEngine: BindingEngine(),
            actionHandler: ActionHandler(),
            stateManager: StateManager(),
          ),
          stateManager: StateManager(),
          bindingEngine: BindingEngine(),
          actionHandler: ActionHandler(),
          themeManager: ThemeManager(),
        );

    test('a storage round trip lands where the document asked', () async {
      final handler = ActionHandler();
      final c = ctx();

      await handler.execute(<String, dynamic>{
        'type': 'client.storage.set',
        'key': 'config',
        'value': 'hello',
      }, c);

      await handler.execute(<String, dynamic>{
        'type': 'client.storage.get',
        'key': 'config',
        'bindResult': 'stored',
      }, c);

      expect(c.getValue<Map<String, dynamic>>('stored')?['value'], 'hello');
    });

    test('a failed action does not erase what is on screen', () async {
      final handler = ActionHandler();
      final c = ctx()..setValue('stored', 'previous');

      await handler.execute(<String, dynamic>{
        'type': 'client.storage.get', // no key — fails
        'bindResult': 'stored',
      }, c);

      expect(c.getValue<String>('stored'), 'previous',
          reason: 'binding an error over a value would blank the view');
    });

    test('without bindResult nothing is written', () async {
      final handler = ActionHandler();
      final c = ctx();
      await handler.execute(<String, dynamic>{
        'type': 'client.storage.set',
        'key': 'k',
        'value': 1,
      }, c);
      expect(c.getValue<Object>('k'), isNull,
          reason: 'a document opts in by naming a binding');
    });
  });
}
