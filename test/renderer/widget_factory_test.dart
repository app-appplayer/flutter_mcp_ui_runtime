import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/widgets/widget_factory.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_result.dart';
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

/// Records every action dispatched through it. Used by the spec 1.3.4
/// common `click` field regression cases.
class _RecorderActionExecutor extends ActionExecutor {
  final List<Map<String, dynamic>> calls = <Map<String, dynamic>>[];

  @override
  Future<ActionResult> execute(
    Map<String, dynamic> action,
    RenderContext context,
  ) async {
    calls.add(Map<String, dynamic>.from(action));
    return ActionResult.success();
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

    // Spec 1.3.4 — common `click` field. Every widget admits a `click`
    // Action; the runtime wraps it in a gesture surface and dispatches
    // the action on tap. Regression cases below pin the wrap shape and
    // the dispatch path. See spec/1.3/02_Widgets.md §2.2.

    test('Normal: applyCommonWrappers wraps widget in GestureDetector when '
        'click is supplied', () {
      final factory = _TestWidgetFactory();
      final widget = const Text('Click me');
      final result = factory.applyCommonWrappers(
        widget,
        {
          'click': {'type': 'noop'},
        },
        renderContext,
      );

      expect(result, isA<GestureDetector>());
      expect((result as GestureDetector).child, isA<Text>());
    });

    testWidgets('Normal: click on a click-wrapped widget dispatches the '
        'configured action through the action handler',
        (WidgetTester tester) async {
      final recorder = _RecorderActionExecutor();
      actionHandler.registerExecutor('noop', recorder);

      final factory = _TestWidgetFactory();
      final wrapped = factory.applyCommonWrappers(
        const Text('Tappable'),
        {
          'click': {'type': 'noop', 'payload': 'box-tap'},
        },
        renderContext,
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: wrapped)));
      await tester.tap(find.text('Tappable'));
      await tester.pump();

      expect(recorder.calls, hasLength(1));
      expect(recorder.calls.single['type'], equals('noop'));
      expect(recorder.calls.single['payload'], equals('box-tap'));
    });

    testWidgets('Normal: tooltip + click + visibility coexist on the same '
        'widget — gesture surface fires and tooltip wraps the gesture',
        (WidgetTester tester) async {
      final recorder = _RecorderActionExecutor();
      actionHandler.registerExecutor('noop', recorder);

      final factory = _TestWidgetFactory();
      final wrapped = factory.applyCommonWrappers(
        const Text('Combo'),
        {
          'visible': true,
          'tooltip': 'Help',
          'click': {'type': 'noop'},
        },
        renderContext,
      );

      // Outer wrap is the GestureDetector (click), inner subtree carries
      // the Tooltip wrap created earlier in `applyCommonWrappers`.
      expect(wrapped, isA<GestureDetector>());

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: wrapped)));
      expect(find.byType(Tooltip), findsOneWidget);
      await tester.tap(find.text('Combo'));
      await tester.pump();
      expect(recorder.calls, hasLength(1));
    });

    test('Backward compat: applyCommonWrappers leaves widget untouched when '
        'click is absent', () {
      final factory = _TestWidgetFactory();
      const original = Text('Plain');
      final result = factory.applyCommonWrappers(
        original,
        const <String, dynamic>{},
        renderContext,
      );

      // No common wrap fields → the widget passes through identical.
      expect(result, same(original));
    });

    test('Boundary: non-Map click value is ignored — no gesture wrap', () {
      final factory = _TestWidgetFactory();
      const original = Text('Bad click');
      final result = factory.applyCommonWrappers(
        original,
        {'click': 'just-a-string'},
        renderContext,
      );

      expect(result, same(original));
    });

    test('Boundary: enabled:false suppresses a click-wrapped gesture surface '
        'via IgnorePointer', () {
      final factory = _TestWidgetFactory();
      final result = factory.applyCommonWrappers(
        const Text('Disabled tap'),
        {
          'enabled': false,
          'click': {'type': 'noop'},
        },
        renderContext,
      );

      // Outer wrap MUST be IgnorePointer so taps cannot reach the
      // GestureDetector sitting inside the disabled subtree.
      expect(result, isA<IgnorePointer>());
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
