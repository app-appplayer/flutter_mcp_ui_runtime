import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/widgets/widget_factory.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';

/// Concrete test factory for verifying the WidgetFactory contract
class _TestWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    final text = context.resolve<String>(properties['text'] ?? 'default');
    return Text(text);
  }
}

void main() {
  late WidgetRegistry widgetRegistry;
  late BindingEngine bindingEngine;
  late ActionHandler actionHandler;
  late StateManager stateManager;
  late ThemeManager themeManager;
  late Renderer renderer;
  late RenderContext renderContext;

  setUp(() {
    widgetRegistry = WidgetRegistry();
    bindingEngine = BindingEngine();
    actionHandler = ActionHandler();
    stateManager = StateManager();
    themeManager = ThemeManager.instance;
    themeManager.reset();

    stateManager.initialize({});

    renderer = Renderer(
      widgetRegistry: widgetRegistry,
      bindingEngine: bindingEngine,
      actionHandler: actionHandler,
      stateManager: stateManager,
    );

    renderContext = RenderContext(
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

  group('TC-026: WidgetFactory — build() method contract', () {
    test('Normal: build() takes Map<String, dynamic> and returns Widget', () {
      final factory = _TestWidgetFactory();
      final definition = {'type': 'test', 'text': 'Hello'};
      final widget = factory.build(definition, renderContext);

      expect(widget, isA<Widget>());
    });

    test('Normal: extractProperties removes type key', () {
      final factory = _TestWidgetFactory();
      final definition = {'type': 'test', 'text': 'Hello', 'color': '#FF0000'};
      final properties = factory.extractProperties(definition);

      expect(properties.containsKey('type'), isFalse);
      expect(properties['text'], equals('Hello'));
      expect(properties['color'], equals('#FF0000'));
    });

    test('Normal: applyCommonWrappers handles visibility', () {
      final factory = _TestWidgetFactory();
      final widget = const Text('Visible');
      final result = factory.applyCommonWrappers(
        widget,
        {'visible': false},
        renderContext,
      );

      expect(result, isA<SizedBox>());
    });

    test('Normal: applyCommonWrappers handles tooltip', () {
      final factory = _TestWidgetFactory();
      final widget = const Text('With Tooltip');
      final result = factory.applyCommonWrappers(
        widget,
        {'tooltip': 'Help text'},
        renderContext,
      );

      expect(result, isA<Tooltip>());
    });

    test('Normal: parseColor parses hex color strings', () {
      final factory = _TestWidgetFactory();

      final color6 = factory.parseColor('#FF5733');
      expect(color6, isNotNull);

      final color8 = factory.parseColor('#80FF5733');
      expect(color8, isNotNull);

      final color3 = factory.parseColor('#F00');
      expect(color3, isNotNull);
    });

    test('Normal: parseColor handles named colors', () {
      final factory = _TestWidgetFactory();

      expect(factory.parseColor('red'), equals(Colors.red));
      expect(factory.parseColor('blue'), equals(Colors.blue));
      expect(factory.parseColor('white'), equals(Colors.white));
    });

    test('Normal: parseEdgeInsets handles all formats', () {
      final factory = _TestWidgetFactory();

      // Single number
      expect(factory.parseEdgeInsets(8), equals(const EdgeInsets.all(8)));

      // Map with all
      expect(factory.parseEdgeInsets({'all': 16}), equals(const EdgeInsets.all(16)));

      // Map with symmetric
      expect(
        factory.parseEdgeInsets({'horizontal': 8, 'vertical': 16}),
        equals(const EdgeInsets.symmetric(horizontal: 8, vertical: 16)),
      );

      // Map with individual sides
      expect(
        factory.parseEdgeInsets({'left': 4, 'top': 8, 'right': 12, 'bottom': 16}),
        equals(const EdgeInsets.only(left: 4, top: 8, right: 12, bottom: 16)),
      );
    });

    test('Normal: parseAlignment handles string values', () {
      final factory = _TestWidgetFactory();

      expect(factory.parseAlignment('topLeft'), equals(Alignment.topLeft));
      expect(factory.parseAlignment('center'), equals(Alignment.center));
      expect(factory.parseAlignment('bottomRight'), equals(Alignment.bottomRight));
    });

    test('Normal: parseDimension handles direct numbers and MCP format', () {
      final factory = _TestWidgetFactory();

      expect(factory.parseDimension(100), equals(100.0));
      expect(factory.parseDimension(3.14), equals(3.14));
      expect(factory.parseDimension({'value': 200, 'unit': 'px'}), equals(200.0));
    });

    test('Boundary: parseColor with null → null', () {
      final factory = _TestWidgetFactory();
      expect(factory.parseColor(null), isNull);
    });

    test('Boundary: parseColor with unknown named color → null', () {
      final factory = _TestWidgetFactory();
      expect(factory.parseColor('magenta'), isNull);
    });

    test('Boundary: parseEdgeInsets with null → null', () {
      final factory = _TestWidgetFactory();
      expect(factory.parseEdgeInsets(null), isNull);
    });

    test('Boundary: parseDimension with null → null', () {
      final factory = _TestWidgetFactory();
      expect(factory.parseDimension(null), isNull);
    });

    test('Boundary: parseAlignment with unknown string → null', () {
      final factory = _TestWidgetFactory();
      expect(factory.parseAlignment('diagonal'), isNull);
    });
  });
}
