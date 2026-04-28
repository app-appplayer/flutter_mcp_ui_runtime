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

void main() {
  late RenderContext context;
  late Renderer renderer;
  late StateManager stateManager;
  late BindingEngine bindingEngine;
  late ActionHandler actionHandler;
  late ThemeManager themeManager;

  setUp(() {
    final widgetRegistry = WidgetRegistry();
    bindingEngine = BindingEngine();
    actionHandler = ActionHandler();
    stateManager = StateManager();
    themeManager = ThemeManager.instance;
    themeManager.reset();

    stateManager.initialize({
      'user': {'name': 'John', 'age': 30},
      'counter': 0,
    });

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
      buildContext: null,
    );
  });

  tearDown(() {
    bindingEngine.dispose();
    stateManager.dispose();
  });

  group('TC-009: RenderContext — construction and properties', () {
    test('Normal: contains all service references', () {
      expect(context.stateManager, same(stateManager));
      expect(context.bindingEngine, same(bindingEngine));
      expect(context.actionHandler, same(actionHandler));
      expect(context.themeManager, same(themeManager));
      expect(context.renderer, same(renderer));
    });

    test('Normal: engine field is dynamic type', () {
      final ctx = RenderContext(
        renderer: renderer,
        stateManager: stateManager,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        themeManager: themeManager,
        engine: 'dynamicEngine',
      );
      expect(ctx.engine, equals('dynamicEngine'));
    });

    test('Normal: buildContext is nullable', () {
      expect(context.buildContext, isNull);
    });

    test('Normal: parentId tracks parent widget identifier', () {
      final ctx = RenderContext(
        renderer: renderer,
        stateManager: stateManager,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        themeManager: themeManager,
        parentId: 'parent1',
      );
      expect(ctx.parentId, equals('parent1'));
    });

    test('Normal: localVariables map for iteration context', () {
      expect(context.localVariables, isA<Map<String, dynamic>>());
      expect(context.localVariables, isEmpty);
    });
  });

  group('TC-010: RenderContext — list iteration context variables', () {
    test('Normal: item → localVariables["item"]', () {
      final ctx = context.createChildContext(variables: {
        'item': {'name': 'Test'},
      });
      expect(ctx.item, equals({'name': 'Test'}));
    });

    test('Normal: index → localVariables["index"] as int?', () {
      final ctx = context.createChildContext(variables: {'index': 2});
      expect(ctx.index, equals(2));
    });

    test('Normal: isFirst, isLast, isEven, isOdd → bool? from localVariables', () {
      final ctx = context.createChildContext(variables: {
        'isFirst': true,
        'isLast': false,
        'isEven': true,
        'isOdd': false,
      });
      expect(ctx.isFirst, isTrue);
      expect(ctx.isLast, isFalse);
      expect(ctx.isEven, isTrue);
      expect(ctx.isOdd, isFalse);
    });

    test('Boundary: no local variables set → all return null', () {
      expect(context.item, isNull);
      expect(context.index, isNull);
      expect(context.isFirst, isNull);
      expect(context.isLast, isNull);
      expect(context.isEven, isNull);
      expect(context.isOdd, isNull);
    });
  });

  group('TC-011: RenderContext — createChildContext', () {
    test('Normal: creates new context with merged variables', () {
      final child = context.createChildContext(
        variables: {'key': 'value'},
        id: 'child1',
      );

      expect(child.localVariables['key'], equals('value'));
      expect(child.parentId, equals('child1'));
    });

    test('Normal: variables merged into localVariables', () {
      context.localVariables['existing'] = 'old';
      final child = context.createChildContext(
        variables: {'new': 'val'},
      );

      expect(child.localVariables['existing'], equals('old'));
      expect(child.localVariables['new'], equals('val'));
    });

    test('Normal: id sets parentId and appends to idPath', () {
      final child1 = context.createChildContext(id: 'level1');
      final child2 = child1.createChildContext(id: 'level2');

      expect(child2.parentId, equals('level2'));
      expect(child2.contextId, contains('level1'));
      expect(child2.contextId, contains('level2'));
    });

    test('Boundary: no variables → same local variables as parent', () {
      context.localVariables['x'] = 1;
      final child = context.createChildContext();
      expect(child.localVariables['x'], equals(1));
    });
  });

  group('TC-012: RenderContext — withItem', () {
    test('Normal: creates child context with item, index, and flags', () {
      final ctx = context.withItem({'name': 'Item 1'}, 0, 5);

      expect(ctx.item, equals({'name': 'Item 1'}));
      expect(ctx.index, equals(0));
      expect(ctx.isFirst, isTrue);
      expect(ctx.isLast, isFalse);
      expect(ctx.isEven, isTrue);
      expect(ctx.isOdd, isFalse);
    });

    test('Normal: index 0, total 5 → isFirst=true, isLast=false', () {
      final ctx = context.withItem('item', 0, 5);
      expect(ctx.isFirst, isTrue);
      expect(ctx.isLast, isFalse);
    });

    test('Normal: last item → isLast=true', () {
      final ctx = context.withItem('item', 4, 5);
      expect(ctx.isFirst, isFalse);
      expect(ctx.isLast, isTrue);
    });

    test('Boundary: single item list (index 0, total 1) → isFirst=true, isLast=true', () {
      final ctx = context.withItem('only', 0, 1);
      expect(ctx.isFirst, isTrue);
      expect(ctx.isLast, isTrue);
    });
  });

  group('TC-013: RenderContext — getValue/setValue with prefix resolution', () {
    test('Normal: getValue resolves from state', () {
      final value = context.getValue<String>('user.name');
      expect(value, equals('John'));
    });

    test('Normal: setValue sets state value', () {
      context.setValue('counter', 5);
      expect(stateManager.get<int>('counter'), equals(5));
    });

    test('Normal: handles local.* prefix → reads local variables', () {
      context.localVariables['myVar'] = 'localValue';
      final value = context.getValue<String>('local.myVar');
      expect(value, equals('localValue'));
    });

    test('Normal: handles app.* prefix → reads app state', () {
      final value = context.getValue<String>('app.user.name');
      expect(value, equals('John'));
    });

    test('Boundary: unknown path → null', () {
      expect(context.getValue<String>('nonexistent'), isNull);
    });
  });

  group('TC-014: RenderContext — getState/setState aliases', () {
    test('Normal: getState is alias for getValue', () {
      final v1 = context.getState<String>('user.name');
      final v2 = context.getValue<String>('user.name');
      expect(v1, equals(v2));
    });

    test('Normal: setState is alias for setValue', () {
      context.setState('counter', 10);
      expect(context.getState<int>('counter'), equals(10));
    });
  });

  group('TC-015: RenderContext — getLocal/setLocal', () {
    test('Normal: getLocal gets from localVariables', () {
      context.localVariables['key'] = 'value';
      expect(context.getLocal<String>('key'), equals('value'));
    });

    test('Normal: setLocal sets in localVariables', () {
      context.setLocal('key', 'value');
      expect(context.localVariables['key'], equals('value'));
    });

    test('Boundary: non-existent key → null', () {
      expect(context.getLocal<String>('nonexistent'), isNull);
    });
  });

  group('TC-016: RenderContext — resolve', () {
    test('Normal: resolve binding in String → resolved value', () {
      stateManager.set('name', 'World');
      final result = context.resolve<String>('{{name}}');
      expect(result, equals('World'));
    });

    test('Normal: resolve binding in Map → all values resolved recursively', () {
      stateManager.set('title', 'Hello');
      final result = context.resolve<Map<String, dynamic>>({
        'label': '{{title}}',
        'static': 'plain',
      });
      expect(result['label'], equals('Hello'));
      expect(result['static'], equals('plain'));
    });

    test('Normal: resolve binding in List → all elements resolved', () {
      stateManager.set('a', 'X');
      stateManager.set('b', 'Y');
      final result = context.resolve<List>(['{{a}}', '{{b}}', 'static']);
      expect(result, equals(['X', 'Y', 'static']));
    });

    test('Boundary: non-binding value → returned as-is', () {
      final result = context.resolve<String>('plain text');
      expect(result, equals('plain text'));
    });

    test('Boundary: null value → null', () {
      final result = context.resolve<String?>(null);
      expect(result, isNull);
    });
  });

  group('TC-017: RenderContext — buildWidget', () {
    testWidgets('Normal: build child widget from definition → Widget', (tester) async {
      final widgetRegistry = WidgetRegistry();
      DefaultWidgets.registerAll(widgetRegistry);
      final r = Renderer(
        widgetRegistry: widgetRegistry,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        stateManager: stateManager,
      );

      final ctx = RenderContext(
        renderer: r,
        stateManager: stateManager,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        themeManager: themeManager,
      );

      final widget = ctx.buildWidget({'type': 'text', 'content': 'Built'});

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
      expect(find.text('Built'), findsOneWidget);
    });
  });

  group('TC-018: RenderContext — handleAction', () {
    test('Boundary: null action → no-op', () async {
      await context.handleAction(null);
      // Should not throw
    });
  });

  group('TC-019: RenderContext — checkCondition', () {
    test('Normal: bool condition → returns directly', () {
      expect(context.checkCondition(true), isTrue);
      expect(context.checkCondition(false), isFalse);
    });

    test('Normal: Map condition → evaluates as complex condition', () {
      final result = context.checkCondition({
        'operator': '==',
        'left': 'a',
        'right': 'a',
      });
      expect(result, isTrue);
    });

    test('Boundary: null condition → true (default)', () {
      expect(context.checkCondition(null), isTrue);
    });
  });

  group('TC-020: RenderContext — additional implementation methods', () {
    test('Normal: contextId — unique context identifier', () {
      final child = context.createChildContext(id: 'myWidget');
      expect(child.contextId, contains('myWidget'));
    });

    test('Normal: updateState — state update method', () {
      context.updateState({'counter': 99});
      expect(stateManager.get<int>('counter'), equals(99));
    });

    test('Normal: getEngine<T> — typed engine access', () {
      final ctx = RenderContext(
        renderer: renderer,
        stateManager: stateManager,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        themeManager: themeManager,
        engine: 'testEngine',
      );
      expect(ctx.getEngine<String>(), equals('testEngine'));
    });

    test('Normal: theme getter — theme access', () {
      expect(context.theme, isA<ThemeData>());
    });

    test('Normal: format — number/date formatting', () {
      final result = context.format(42, null);
      expect(result, equals('42'));
    });

    test('Normal: format — with currency formatter', () {
      final result = context.format(1234.5, 'currency');
      expect(result, isA<String>());
      expect(result.isNotEmpty, isTrue);
    });

    test('Normal: onResourceSubscribe — resource subscribe handler', () {
      // With no engine, onResourceSubscribe should be null
      expect(context.onResourceSubscribe, isNull);
    });

    test('Normal: onResourceUnsubscribe — resource unsubscribe handler', () {
      // With no engine, onResourceUnsubscribe should be null
      expect(context.onResourceUnsubscribe, isNull);
    });
  });
}
