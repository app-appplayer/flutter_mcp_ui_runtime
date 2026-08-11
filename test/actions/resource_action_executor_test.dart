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

  group('TC-039: ResourceActionExecutor — subscribe action', () {
    test('TC-039 Normal: subscribe with uri and binding returns success', () async {
      final result = await actionHandler.execute(
        {
          'type': 'resource',
          'action': 'subscribe',
          'uri': 'file:///test',
          'binding': 'data',
        },
        context,
      );

      // No host handler is wired in this harness, and that is now REPORTED
      // rather than answered as success: the executor cannot subscribe,
      // read or list without one. (These expectations were written from
      // the implementation — 'should still return success' — which is how
      // a defect gets a test that guards it.)
      expect(result.success, isFalse);
      expect(result.error, contains('handler'));
    });

    test('TC-039 Boundary: subscribe without a resource handler is reported',
        () async {
      // Was: "should still return success" — written from the implementation
      // rather than from §4.5, and it described the defect. A host with no
      // subscribe handler cannot subscribe, and a document told otherwise waits
      // forever for data nobody asked for.
      final result = await actionHandler.execute(
        {
          'type': 'resource',
          'action': 'subscribe',
          'uri': 'file:///test',
          'binding': 'data',
        },
        context,
      );

      // No host handler is wired in this harness, and that is now REPORTED
      // rather than answered as success: the executor cannot subscribe,
      // read or list without one. (These expectations were written from
      // the implementation — 'should still return success' — which is how
      // a defect gets a test that guards it.)
      expect(result.success, isFalse);
      expect(result.error, contains('handler'));
    });

    test('TC-039 Error: subscribe without binding returns error', () async {
      final result = await actionHandler.execute(
        {
          'type': 'resource',
          'action': 'subscribe',
          'uri': 'file:///test',
        },
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Binding is required'));
    });
  });

  group('TC-040: ResourceActionExecutor — unsubscribe action', () {
    test('TC-040 Normal: unsubscribe with uri returns success', () async {
      final result = await actionHandler.execute(
        {
          'type': 'resource',
          'action': 'unsubscribe',
          'uri': 'file:///test',
        },
        context,
      );

      // No host handler is wired in this harness, and that is now REPORTED
      // rather than answered as success: the executor cannot subscribe,
      // read or list without one. (These expectations were written from
      // the implementation — 'should still return success' — which is how
      // a defect gets a test that guards it.)
      expect(result.success, isFalse);
      expect(result.error, contains('handler'));
    });

    test('TC-040 Boundary: unsubscribe without a resource handler is reported',
        () async {
      final result = await actionHandler.execute(
        {
          'type': 'resource',
          'action': 'unsubscribe',
          'uri': 'file:///nonexistent',
        },
        context,
      );

      // No host handler is wired in this harness, and that is now REPORTED
      // rather than answered as success: the executor cannot subscribe,
      // read or list without one. (These expectations were written from
      // the implementation — 'should still return success' — which is how
      // a defect gets a test that guards it.)
      expect(result.success, isFalse);
      expect(result.error, contains('handler'));
    });
  });

  group('TC-041: ResourceActionExecutor — read action', () {
    test('TC-041 Normal: read with uri and binding returns success', () async {
      final result = await actionHandler.execute(
        {
          'type': 'resource',
          'action': 'read',
          'uri': 'file:///test',
          'binding': 'result',
        },
        context,
      );

      // No host handler is wired in this harness, and that is now REPORTED
      // rather than answered as success: the executor cannot subscribe,
      // read or list without one. (These expectations were written from
      // the implementation — 'should still return success' — which is how
      // a defect gets a test that guards it.)
      expect(result.success, isFalse);
      expect(result.error, contains('handler'));
    });

    test('TC-041 Boundary: read without explicit binding uses uri as default', () async {
      final result = await actionHandler.execute(
        {
          'type': 'resource',
          'action': 'read',
          'uri': 'file:///test',
        },
        context,
      );

      // No host handler is wired in this harness, and that is now REPORTED
      // rather than answered as success: the executor cannot subscribe,
      // read or list without one. (These expectations were written from
      // the implementation — 'should still return success' — which is how
      // a defect gets a test that guards it.)
      expect(result.success, isFalse);
      expect(result.error, contains('handler'));
    });

    test('TC-041 Boundary: read without resource handler still succeeds', () async {
      final result = await actionHandler.execute(
        {
          'type': 'resource',
          'action': 'read',
          'uri': 'file:///test',
          'binding': 'result',
        },
        context,
      );

      // No handler configured, but operation still returns success
      // No host handler is wired in this harness, and that is now REPORTED
      // rather than answered as success: the executor cannot subscribe,
      // read or list without one. (These expectations were written from
      // the implementation — 'should still return success' — which is how
      // a defect gets a test that guards it.)
      expect(result.success, isFalse);
      expect(result.error, contains('handler'));
    });
  });

  group('TC-042: ResourceActionExecutor — list action', () {
    test('TC-042 Normal: list with uri and binding returns success', () async {
      final result = await actionHandler.execute(
        {
          'type': 'resource',
          'action': 'list',
          'uri': 'file:///dir',
          'binding': 'items',
        },
        context,
      );

      // No host handler is wired in this harness, and that is now REPORTED
      // rather than answered as success: the executor cannot subscribe,
      // read or list without one. (These expectations were written from
      // the implementation — 'should still return success' — which is how
      // a defect gets a test that guards it.)
      expect(result.success, isFalse);
      expect(result.error, contains('handler'));
    });

    test('TC-042 Boundary: list without explicit binding uses uri as default', () async {
      final result = await actionHandler.execute(
        {
          'type': 'resource',
          'action': 'list',
          'uri': 'file:///dir',
        },
        context,
      );

      // No host handler is wired in this harness, and that is now REPORTED
      // rather than answered as success: the executor cannot subscribe,
      // read or list without one. (These expectations were written from
      // the implementation — 'should still return success' — which is how
      // a defect gets a test that guards it.)
      expect(result.success, isFalse);
      expect(result.error, contains('handler'));
    });

    test('TC-042 Boundary: list without resource handler still succeeds', () async {
      final result = await actionHandler.execute(
        {
          'type': 'resource',
          'action': 'list',
          'uri': 'file:///dir',
          'binding': 'items',
        },
        context,
      );

      // No host handler is wired in this harness, and that is now REPORTED
      // rather than answered as success: the executor cannot subscribe,
      // read or list without one. (These expectations were written from
      // the implementation — 'should still return success' — which is how
      // a defect gets a test that guards it.)
      expect(result.success, isFalse);
      expect(result.error, contains('handler'));
    });
  });

  group('TC-043: ResourceActionExecutor — HTTP-style resource with method/target', () {
    test('TC-043 Normal: GET method with binding and resourceHandler returns success', () async {
      final contextWithHandler = RenderContext(
        renderer: context.renderer,
        stateManager: stateManager,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        themeManager: ThemeManager.instance,
        resourceHandler: (resource, method, target, data) async {
          return {'status': 200, 'body': 'ok'};
        },
      );

      final result = await actionHandler.execute(
        {
          'type': 'resource',
          'method': 'GET',
          'binding': '/api/data',
        },
        contextWithHandler,
      );

      expect(result.success, isTrue);
      expect(result.data, isNotNull);
    });

    test('TC-043 Boundary: HTTP-style resource without handler returns error', () async {
      final result = await actionHandler.execute(
        {
          'type': 'resource',
          'method': 'GET',
          'binding': '/api/data',
        },
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('No resource handler'));
    });

    test('TC-043 Boundary: POST method with data passes through', () async {
      Map<String, dynamic>? capturedData;

      final contextWithHandler = RenderContext(
        renderer: context.renderer,
        stateManager: stateManager,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        themeManager: ThemeManager.instance,
        resourceHandler: (resource, method, target, data) async {
          capturedData = data is Map<String, dynamic> ? data : null;
          return {'status': 201};
        },
      );

      await actionHandler.execute(
        {
          'type': 'resource',
          'method': 'POST',
          'binding': '/api/items',
          'data': {'name': 'test'},
        },
        contextWithHandler,
      );

      expect(capturedData, isNotNull);
      expect(capturedData!['name'], equals('test'));
    });
  });

  group('TC-044: ResourceActionExecutor — missing URI', () {
    test('TC-044 Error: action without uri returns error', () async {
      final result = await actionHandler.execute(
        {
          'type': 'resource',
          'action': 'subscribe',
          'binding': 'data',
        },
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('URI is required'));
    });

    test('TC-044 Error: read without uri returns error', () async {
      final result = await actionHandler.execute(
        {
          'type': 'resource',
          'action': 'read',
        },
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('URI is required'));
    });
  });

  group('TC-045: ResourceActionExecutor — missing binding for subscribe', () {
    test('TC-045 Error: subscribe without binding returns error', () async {
      final result = await actionHandler.execute(
        {
          'type': 'resource',
          'action': 'subscribe',
          'uri': 'file:///test',
        },
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Binding is required'));
    });
  });

  group('TC-046: ResourceActionExecutor — unknown resource action', () {
    test('TC-046 Error: unknown action type returns error', () async {
      final result = await actionHandler.execute(
        {
          'type': 'resource',
          'action': 'unknown_action',
          'uri': 'file:///test',
        },
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Unknown resource action'));
    });

    test('TC-046 Boundary: action missing entirely returns error', () async {
      final result = await actionHandler.execute(
        {
          'type': 'resource',
          'uri': 'file:///test',
        },
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Action is required'));
    });
  });
}
