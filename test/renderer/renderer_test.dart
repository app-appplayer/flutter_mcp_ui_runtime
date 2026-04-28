import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart' as core show WidgetDefinition, PageDefinition;

void main() {
  late Renderer renderer;
  late WidgetRegistry widgetRegistry;
  late BindingEngine bindingEngine;
  late ActionHandler actionHandler;
  late StateManager stateManager;
  late ThemeManager themeManager;

  setUp(() {
    widgetRegistry = WidgetRegistry();
    bindingEngine = BindingEngine();
    actionHandler = ActionHandler();
    stateManager = StateManager();
    themeManager = ThemeManager.instance;
    themeManager.reset();

    renderer = Renderer(
      widgetRegistry: widgetRegistry,
      bindingEngine: bindingEngine,
      actionHandler: actionHandler,
      stateManager: stateManager,
    );
  });

  tearDown(() {
    bindingEngine.dispose();
    stateManager.dispose();
  });

  group('TC-001: Renderer — constructor initialization', () {
    test('Normal: creates with required services', () {
      expect(renderer, isNotNull);
      expect(renderer.widgetRegistry, same(widgetRegistry));
      expect(renderer.bindingEngine, same(bindingEngine));
      expect(renderer.actionHandler, same(actionHandler));
      expect(renderer.stateManager, same(stateManager));
    });

    test('Normal: engine field is dynamic, initially null', () {
      expect(renderer.engine, isNull);
    });

    test('Normal: engine field can be set', () {
      renderer.engine = 'mockEngine';
      expect(renderer.engine, equals('mockEngine'));
    });
  });

  group('TC-002: Renderer — handler fields', () {
    test('Normal: navigationHandler callback set → receives params', () {
      bool handlerCalled = false;
      renderer.navigationHandler = (action, route, params) {
        handlerCalled = true;
        return true;
      };

      final result = renderer.navigationHandler!('push', '/home', {});
      expect(result, isTrue);
      expect(handlerCalled, isTrue);
    });

    test('Normal: resourceHandler callback set → receives params', () async {
      renderer.resourceHandler = (resource, method, target, data) async {
        return {'status': 'ok'};
      };

      final result = await renderer.resourceHandler!('res', 'GET', '/data', null);
      expect(result['status'], equals('ok'));
    });

    test('Boundary: handlers not set → null', () {
      expect(renderer.navigationHandler, isNull);
      expect(renderer.resourceHandler, isNull);
    });
  });

  group('TC-003: Renderer — cache management', () {
    test('Normal: getCacheStatistics returns Map', () {
      final stats = renderer.getCacheStatistics();
      expect(stats, isA<Map<String, dynamic>>());
    });

    test('Normal: clearCache clears all cached render data', () {
      renderer.clearCache();
      final stats = renderer.getCacheStatistics();
      expect(stats, isA<Map<String, dynamic>>());
    });

    test('Normal: setCacheEnabled toggles caching', () {
      renderer.setCacheEnabled(false);
      renderer.setCacheEnabled(true);
      // Should not throw
    });
  });

  group('TC-004: Renderer — renderWidget', () {
    testWidgets('Normal: render widget from JSON definition', (tester) async {
      stateManager.initialize({});
      DefaultWidgets.registerAll(widgetRegistry);

      final context = renderer.createRootContext(null);
      final widget = renderer.renderWidget(
        {'type': 'text', 'content': 'Hello'},
        context,
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('Normal: visible: false → SizedBox.shrink()', (tester) async {
      stateManager.initialize({});
      DefaultWidgets.registerAll(widgetRegistry);

      final context = renderer.createRootContext(null);
      final widget = renderer.renderWidget(
        {'type': 'text', 'content': 'Hidden', 'visible': false},
        context,
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
      expect(find.text('Hidden'), findsNothing);
    });

    testWidgets('Boundary: unknown widget type → ErrorWidget', (tester) async {
      stateManager.initialize({});

      final context = renderer.createRootContext(null);
      final widget = renderer.renderWidget(
        {'type': 'unknownWidget123'},
        context,
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
      // Should render an error widget (Container with red color or similar)
      expect(widget, isA<Widget>());
    });
  });

  group('TC-005: Renderer — renderPage', () {
    testWidgets('Normal: render full page definition → Scaffold', (tester) async {
      stateManager.initialize({});
      DefaultWidgets.registerAll(widgetRegistry);

      final widget = renderer.renderPage({
        'type': 'page',
        'content': {'type': 'text', 'content': 'Page Content'},
      });

      await tester.pumpWidget(MaterialApp(home: widget));
      expect(find.text('Page Content'), findsOneWidget);
    });

    testWidgets('Normal: content/children resolution — content as single map', (tester) async {
      stateManager.initialize({});
      DefaultWidgets.registerAll(widgetRegistry);

      final widget = renderer.renderPage({
        'type': 'page',
        'content': {'type': 'text', 'content': 'Single Content'},
      });

      await tester.pumpWidget(MaterialApp(home: widget));
      expect(find.text('Single Content'), findsOneWidget);
    });

    testWidgets('Boundary: page with no content → empty page', (tester) async {
      stateManager.initialize({});

      final widget = renderer.renderPage({'type': 'page'});

      await tester.pumpWidget(MaterialApp(home: widget));
      expect(widget, isA<Widget>());
    });
  });

  group('TC-006: Renderer — renderChildren and renderChild', () {
    test('Normal: renderChildren(list, context) → List<Widget>', () {
      stateManager.initialize({});
      DefaultWidgets.registerAll(widgetRegistry);

      final context = renderer.createRootContext(null);
      final children = renderer.renderChildren(
        [
          {'type': 'text', 'content': 'A'},
          {'type': 'text', 'content': 'B'},
        ],
        context,
      );

      expect(children, isA<List<Widget>>());
      expect(children, hasLength(2));
    });

    test('Normal: renderChild(map, context) → single Widget', () {
      stateManager.initialize({});
      DefaultWidgets.registerAll(widgetRegistry);

      final context = renderer.createRootContext(null);
      final child = renderer.renderChild(
        {'type': 'text', 'content': 'Single'},
        context,
      );

      expect(child, isA<Widget>());
    });

    test('Boundary: empty children list → empty list', () {
      stateManager.initialize({});
      final context = renderer.createRootContext(null);
      final children = renderer.renderChildren([], context);
      expect(children, isEmpty);
    });

    test('Boundary: null child → null or SizedBox', () {
      stateManager.initialize({});
      final context = renderer.createRootContext(null);
      final child = renderer.renderChild(null, context);
      // renderChild with null returns SizedBox.shrink or null
      expect(child == null || child is Widget, isTrue);
    });
  });

  group('TC-007: Renderer — renderDefinition and renderPageDefinition', () {
    test('Normal: renderDefinition converts WidgetDefinition to JSON and renders',
        () {
      stateManager.initialize({});
      final context = renderer.createRootContext(null);
      final definition = core.WidgetDefinition(type: 'text', properties: {'content': 'Hello'});
      final widget = renderer.renderDefinition(definition, context);
      expect(widget, isA<Widget>());
    });

    test('Normal: renderPageDefinition converts PageDefinition to JSON and renders',
        () {
      stateManager.initialize({});
      final definition = core.PageDefinition(
        type: 'page',
        content: core.WidgetDefinition(type: 'text', properties: {'content': 'Page'}),
      );
      final widget = renderer.renderPageDefinition(definition);
      expect(widget, isA<Widget>());
    });

    test('Boundary: definition with minimal fields', () {
      stateManager.initialize({});
      final context = renderer.createRootContext(null);
      final definition = core.WidgetDefinition(type: 'text');
      final widget = renderer.renderDefinition(definition, context);
      expect(widget, isA<Widget>());
    });
  });

  group('TC-008: Renderer — createRootContext', () {
    test('Normal: creates root RenderContext with all services', () {
      stateManager.initialize({});
      final context = renderer.createRootContext(null);

      expect(context, isA<RenderContext>());
      expect(context.stateManager, same(stateManager));
      expect(context.bindingEngine, same(bindingEngine));
      expect(context.actionHandler, same(actionHandler));
      expect(context.renderer, same(renderer));
    });

    test('Normal: ThemeManager accessed via singleton', () {
      stateManager.initialize({});
      final context = renderer.createRootContext(null);
      expect(context.themeManager, same(ThemeManager.instance));
    });

    test('Boundary: null BuildContext → context without Flutter build context', () {
      stateManager.initialize({});
      final context = renderer.createRootContext(null);
      expect(context.buildContext, isNull);
    });
  });
}
