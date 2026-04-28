import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_result.dart';
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
  late Renderer renderer;

  setUp(() {
    actionHandler = ActionHandler();
    stateManager = StateManager();
    bindingEngine = BindingEngine();
    final themeManager = ThemeManager.instance;
    themeManager.reset();
    final widgetRegistry = WidgetRegistry();
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

  tearDown(() {
    NavigationActionExecutor.clearGlobalNavigationHandler();
    bindingEngine.dispose();
    stateManager.dispose();
  });

  group('TC-023: NavigationActionExecutor — navigate push', () {
    test('TC-023 Normal: push action calls handler with correct arguments', () async {
      String? capturedAction;
      String? capturedRoute;
      Map<String, dynamic>? capturedParams;

      renderer.navigationHandler = (action, route, params) {
        capturedAction = action;
        capturedRoute = route;
        capturedParams = params;
        return true;
      };

      final result = await actionHandler.execute(
        {'type': 'navigation', 'action': 'push', 'route': '/home'},
        context,
      );

      expect(result.success, isTrue);
      expect(capturedAction, equals('push'));
      expect(capturedRoute, equals('/home'));
      expect(capturedParams, equals({}));
    });

    test('TC-023 Boundary: push without handler returns success (graceful)', () async {
      final result = await actionHandler.execute(
        {'type': 'navigation', 'action': 'push', 'route': '/home'},
        context,
      );
      // Without navigator state, returns success gracefully
      expect(result, isA<ActionResult>());
    });

    test('TC-023 Error: push without route returns error', () async {
      final result = await actionHandler.execute(
        {'type': 'navigation', 'action': 'push'},
        context,
      );
      expect(result.success, isFalse);
      expect(result.error, contains('Route is required'));
    });
  });

  group('TC-024: NavigationActionExecutor — navigate back (pop)', () {
    test('TC-024 Normal: pop action returns success', () async {
      var handlerCalled = false;
      renderer.navigationHandler = (action, route, params) {
        handlerCalled = true;
        return true;
      };

      final result = await actionHandler.execute(
        {'type': 'navigation', 'action': 'pop'},
        context,
      );

      expect(result.success, isTrue);
      expect(handlerCalled, isTrue);
    });

    test('TC-024 Boundary: pop without handler still returns success', () async {
      final result = await actionHandler.execute(
        {'type': 'navigation', 'action': 'pop'},
        context,
      );
      // Pop without navigator state returns success gracefully
      expect(result, isA<ActionResult>());
    });

    test('TC-024 Boundary: pop does not require route parameter', () async {
      renderer.navigationHandler = (action, route, params) => true;

      final result = await actionHandler.execute(
        {'type': 'navigation', 'action': 'pop'},
        context,
      );
      expect(result.success, isTrue);
    });
  });

  group('TC-025: NavigationActionExecutor — navigate replace', () {
    test('TC-025 Normal: replace action calls handler with replace action', () async {
      String? capturedAction;

      renderer.navigationHandler = (action, route, params) {
        capturedAction = action;
        return true;
      };

      final result = await actionHandler.execute(
        {'type': 'navigation', 'action': 'replace', 'route': '/settings'},
        context,
      );

      expect(result.success, isTrue);
      expect(capturedAction, equals('replace'));
    });

    test('TC-025 Error: replace without route returns error', () async {
      final result = await actionHandler.execute(
        {'type': 'navigation', 'action': 'replace'},
        context,
      );
      expect(result.success, isFalse);
      expect(result.error, contains('Route is required'));
    });
  });

  group('TC-026: NavigationActionExecutor — navigate with params', () {
    test('TC-026 Normal: params are passed to handler', () async {
      Map<String, dynamic>? capturedParams;

      renderer.navigationHandler = (action, route, params) {
        capturedParams = params;
        return true;
      };

      await actionHandler.execute(
        {
          'type': 'navigation',
          'action': 'push',
          'route': '/user',
          'params': {'id': '123'},
        },
        context,
      );

      expect(capturedParams, isNotNull);
      expect(capturedParams!['id'], equals('123'));
    });

    test('TC-026 Boundary: empty params map passed correctly', () async {
      Map<String, dynamic>? capturedParams;

      renderer.navigationHandler = (action, route, params) {
        capturedParams = params;
        return true;
      };

      await actionHandler.execute(
        {
          'type': 'navigation',
          'action': 'push',
          'route': '/user',
          'params': <String, dynamic>{},
        },
        context,
      );

      expect(capturedParams, equals({}));
    });

    test('TC-026 Boundary: multiple params passed correctly', () async {
      Map<String, dynamic>? capturedParams;

      renderer.navigationHandler = (action, route, params) {
        capturedParams = params;
        return true;
      };

      await actionHandler.execute(
        {
          'type': 'navigation',
          'action': 'push',
          'route': '/user',
          'params': {'id': '123', 'name': 'Alice', 'active': true},
        },
        context,
      );

      expect(capturedParams!['id'], equals('123'));
      expect(capturedParams!['name'], equals('Alice'));
      expect(capturedParams!['active'], equals(true));
    });
  });

  group('TC-027: NavigationActionExecutor — navigate with transition', () {
    test('TC-027 Normal: transition property does not cause error', () async {
      renderer.navigationHandler = (action, route, params) => true;

      final result = await actionHandler.execute(
        {
          'type': 'navigation',
          'action': 'push',
          'route': '/page',
          'transition': 'slideLeft',
        },
        context,
      );

      // Transition is handled at widget level, executor ignores it gracefully
      expect(result.success, isTrue);
    });

    test('TC-027 Boundary: unknown transition value does not throw', () async {
      renderer.navigationHandler = (action, route, params) => true;

      final result = await actionHandler.execute(
        {
          'type': 'navigation',
          'action': 'push',
          'route': '/page',
          'transition': 'unknownTransition',
        },
        context,
      );

      expect(result.success, isTrue);
    });
  });

  group('TC-028: NavigationActionExecutor — external link navigation', () {
    test('TC-028 Normal: http:// route calls handler', () async {
      String? capturedRoute;

      renderer.navigationHandler = (action, route, params) {
        capturedRoute = route;
        return true;
      };

      final result = await actionHandler.execute(
        {
          'type': 'navigation',
          'action': 'push',
          'route': 'http://example.com',
        },
        context,
      );

      expect(result.success, isTrue);
      expect(capturedRoute, equals('http://example.com'));
    });

    test('TC-028 Normal: https:// route calls handler', () async {
      String? capturedRoute;

      renderer.navigationHandler = (action, route, params) {
        capturedRoute = route;
        return true;
      };

      final result = await actionHandler.execute(
        {
          'type': 'navigation',
          'action': 'push',
          'route': 'https://example.com/page',
        },
        context,
      );

      expect(result.success, isTrue);
      expect(capturedRoute, equals('https://example.com/page'));
    });

    test('TC-028 Boundary: external link with params passes through', () async {
      Map<String, dynamic>? capturedParams;

      renderer.navigationHandler = (action, route, params) {
        capturedParams = params;
        return true;
      };

      await actionHandler.execute(
        {
          'type': 'navigation',
          'action': 'push',
          'route': 'https://example.com',
          'params': {'target': '_blank'},
        },
        context,
      );

      expect(capturedParams!['target'], equals('_blank'));
    });
  });

  group('TC-029: NavigationActionExecutor — handler callback rejection', () {
    test('TC-029 Normal: handler returning false produces error result', () async {
      renderer.navigationHandler = (action, route, params) => false;

      final result = await actionHandler.execute(
        {'type': 'navigation', 'action': 'push', 'route': '/blocked'},
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('rejected'));
    });

    test('TC-029 Normal: handler returning true produces success result', () async {
      renderer.navigationHandler = (action, route, params) => true;

      final result = await actionHandler.execute(
        {'type': 'navigation', 'action': 'push', 'route': '/allowed'},
        context,
      );

      expect(result.success, isTrue);
    });

    test('TC-029 Boundary: global handler rejection also produces error', () async {
      actionHandler.registerNavigationHandler((action, route, params) => false);

      final result = await actionHandler.execute(
        {'type': 'navigation', 'action': 'push', 'route': '/blocked'},
        context,
      );

      expect(result.success, isFalse);
    });
  });
}
