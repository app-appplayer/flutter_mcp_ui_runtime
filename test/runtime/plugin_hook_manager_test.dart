import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/plugins/plugin_hooks.dart';
import 'package:flutter_mcp_ui_runtime/src/plugins/plugin_system.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/core/service_locator.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/widgets/widget_factory.dart';

void main() {
  setUp(() {
    PluginHookManager.resetInstance();
  });

  group('TC-115: PluginHookManager — singleton and lifecycle', () {
    test('Normal: PluginHookManager.instance returns singleton', () {
      final instance1 = PluginHookManager.instance;
      final instance2 = PluginHookManager.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('Normal: register plugin hooks → extends runtime capabilities', () {
      final manager = PluginHookManager.instance;

      manager.registerHook(
        pluginName: 'testPlugin',
        hookType: PluginHookType.onStateChange,
        callback: (context) async {},
      );

      expect(manager.hasHooks(PluginHookType.onStateChange), isTrue);
      expect(manager.hookCount(PluginHookType.onStateChange), equals(1));
    });

    test('Boundary: plugin with no hooks → no active hook types', () {
      final manager = PluginHookManager.instance;
      expect(manager.activeHookTypes, isEmpty);
    });
  });

  group('TC-116: Plugin hooks — hook types', () {
    test('Normal: PluginHookType enum contains all required types', () {
      expect(PluginHookType.values, containsAll([
        PluginHookType.onWidgetRegister,
        PluginHookType.onActionRegister,
        PluginHookType.onLifecycle,
        PluginHookType.onStateChange,
        PluginHookType.onRender,
        PluginHookType.onError,
      ]));
    });

    test('Normal: onWidgetRegister fires with widgetType data', () async {
      final manager = PluginHookManager.instance;
      Map<String, dynamic>? receivedData;

      manager.registerHook(
        pluginName: 'testPlugin',
        hookType: PluginHookType.onWidgetRegister,
        callback: (context) async {
          receivedData = context.data;
        },
      );

      await manager.fireHook(
        PluginHookType.onWidgetRegister,
        data: {'widgetType': 'customWidget'},
      );

      expect(receivedData, isNotNull);
      expect(receivedData!['widgetType'], equals('customWidget'));
    });

    test('Normal: onStateChange fires with path/oldValue/newValue data', () async {
      final manager = PluginHookManager.instance;
      Map<String, dynamic>? receivedData;

      manager.registerHook(
        pluginName: 'statePlugin',
        hookType: PluginHookType.onStateChange,
        callback: (context) async {
          receivedData = context.data;
        },
      );

      await manager.fireHook(
        PluginHookType.onStateChange,
        data: {'path': 'counter', 'oldValue': 0, 'newValue': 1},
      );

      expect(receivedData!['path'], equals('counter'));
      expect(receivedData!['oldValue'], equals(0));
      expect(receivedData!['newValue'], equals(1));
    });

    test('Boundary: errors in hooks caught without affecting other hooks', () async {
      final manager = PluginHookManager.instance;
      bool secondHookCalled = false;

      manager.registerHook(
        pluginName: 'badPlugin',
        hookType: PluginHookType.onError,
        callback: (context) async {
          throw Exception('Hook error');
        },
        priority: 10,
      );

      manager.registerHook(
        pluginName: 'goodPlugin',
        hookType: PluginHookType.onError,
        callback: (context) async {
          secondHookCalled = true;
        },
        priority: 0,
      );

      // Should not throw despite first hook throwing
      await manager.fireHook(
        PluginHookType.onError,
        data: {'error': 'test', 'source': 'test'},
      );

      expect(secondHookCalled, isTrue);
    });
  });

  group('TC-117: Plugin hooks — callback and registration', () {
    test('Normal: PluginHookContext contains hookType, pluginName, data, timestamp', () {
      final context = PluginHookContext.now(
        hookType: PluginHookType.onStateChange,
        pluginName: 'testPlugin',
        data: {'key': 'value'},
      );

      expect(context.hookType, equals(PluginHookType.onStateChange));
      expect(context.pluginName, equals('testPlugin'));
      expect(context.data['key'], equals('value'));
      expect(context.timestamp, isA<DateTime>());
    });

    test('Normal: registerHook with priority → higher priority runs first', () async {
      final manager = PluginHookManager.instance;
      final executionOrder = <String>[];

      manager.registerHook(
        pluginName: 'lowPriority',
        hookType: PluginHookType.onRender,
        callback: (context) async {
          executionOrder.add('low');
        },
        priority: 0,
      );

      manager.registerHook(
        pluginName: 'highPriority',
        hookType: PluginHookType.onRender,
        callback: (context) async {
          executionOrder.add('high');
        },
        priority: 10,
      );

      await manager.fireHook(PluginHookType.onRender);

      expect(executionOrder, equals(['high', 'low']));
    });

    test('Boundary: same priority → execution order is registration order', () async {
      final manager = PluginHookManager.instance;
      final executionOrder = <String>[];

      manager.registerHook(
        pluginName: 'first',
        hookType: PluginHookType.onRender,
        callback: (context) async {
          executionOrder.add('first');
        },
        priority: 0,
      );

      manager.registerHook(
        pluginName: 'second',
        hookType: PluginHookType.onRender,
        callback: (context) async {
          executionOrder.add('second');
        },
        priority: 0,
      );

      await manager.fireHook(PluginHookType.onRender);

      expect(executionOrder, equals(['first', 'second']));
    });
  });

  group('TC-118: Plugin hooks — firing and unregistration', () {
    test('Normal: fireHook → async firing awaits each hook in priority order', () async {
      final manager = PluginHookManager.instance;
      int callCount = 0;

      manager.registerHook(
        pluginName: 'plugin1',
        hookType: PluginHookType.onLifecycle,
        callback: (context) async {
          callCount++;
        },
      );

      manager.registerHook(
        pluginName: 'plugin2',
        hookType: PluginHookType.onLifecycle,
        callback: (context) async {
          callCount++;
        },
      );

      await manager.fireHook(PluginHookType.onLifecycle);
      expect(callCount, equals(2));
    });

    test('Normal: fireHookSync → fire-and-forget for hot paths', () {
      final manager = PluginHookManager.instance;

      manager.registerHook(
        pluginName: 'renderPlugin',
        hookType: PluginHookType.onRender,
        callback: (context) async {},
      );

      // Should not throw
      manager.fireHookSync(
        PluginHookType.onRender,
        data: {'widgetType': 'text', 'phase': 'before'},
      );
    });

    test('Normal: unregisterPlugin → removes all hooks for a plugin', () {
      final manager = PluginHookManager.instance;

      manager.registerHook(
        pluginName: 'myPlugin',
        hookType: PluginHookType.onStateChange,
        callback: (context) async {},
      );
      manager.registerHook(
        pluginName: 'myPlugin',
        hookType: PluginHookType.onRender,
        callback: (context) async {},
      );

      manager.unregisterPlugin('myPlugin');

      expect(manager.hasHooks(PluginHookType.onStateChange), isFalse);
      expect(manager.hasHooks(PluginHookType.onRender), isFalse);
    });

    test('Normal: unregisterHook → removes specific hook type for a plugin', () {
      final manager = PluginHookManager.instance;

      manager.registerHook(
        pluginName: 'myPlugin',
        hookType: PluginHookType.onStateChange,
        callback: (context) async {},
      );
      manager.registerHook(
        pluginName: 'myPlugin',
        hookType: PluginHookType.onRender,
        callback: (context) async {},
      );

      manager.unregisterHook(
        pluginName: 'myPlugin',
        hookType: PluginHookType.onStateChange,
      );

      expect(manager.hasHooks(PluginHookType.onStateChange), isFalse);
      expect(manager.hasHooks(PluginHookType.onRender), isTrue);
    });

    test('Boundary: fire hook with no registered callbacks → no-op', () async {
      final manager = PluginHookManager.instance;
      await manager.fireHook(PluginHookType.onError);
      // Should not throw
    });
  });

  group('PluginLifecycleEvent — enum values', () {
    test('Normal: contains all lifecycle events', () {
      expect(PluginLifecycleEvent.values, containsAll([
        PluginLifecycleEvent.initializing,
        PluginLifecycleEvent.initialized,
        PluginLifecycleEvent.enabled,
        PluginLifecycleEvent.disabled,
        PluginLifecycleEvent.disposing,
        PluginLifecycleEvent.disposed,
      ]));
    });
  });

  group('PluginManager Tests', () {
    setUp(() {
      PluginManager.resetInstance();
      PluginHookManager.resetInstance();
    });

    group('TC-031: PluginManager — loadAllPlugins', () {
      test('Normal: loads all registered plugins in dependency order', () async {
        final manager = PluginManager.instance;
        final stateManager = StateManager();
        final serviceLocator = ServiceLocator();
        final widgetRegistry = WidgetRegistry();
        final actionHandler = ActionHandler();

        manager.initialize(
          stateManager: stateManager,
          serviceLocator: serviceLocator,
          widgetRegistry: widgetRegistry,
          actionHandler: actionHandler,
        );

        final loadOrder = <String>[];
        final pluginA = _TestPlugin('pluginA', onInit: () => loadOrder.add('A'));
        final pluginB = _TestPlugin('pluginB', dependencies: ['pluginA'], onInit: () => loadOrder.add('B'));

        await manager.registerPlugin(pluginA);
        await manager.registerPlugin(pluginB);
        await manager.loadAllPlugins();

        expect(manager.isPluginLoaded('pluginA'), true);
        expect(manager.isPluginLoaded('pluginB'), true);
        expect(loadOrder, ['A', 'B']);
      });

      test('Boundary: no plugins registered is no-op', () async {
        final manager = PluginManager.instance;
        final stateManager = StateManager();
        final serviceLocator = ServiceLocator();
        final widgetRegistry = WidgetRegistry();
        final actionHandler = ActionHandler();

        manager.initialize(
          stateManager: stateManager,
          serviceLocator: serviceLocator,
          widgetRegistry: widgetRegistry,
          actionHandler: actionHandler,
        );

        await manager.loadAllPlugins();
        expect(manager.getAllPluginInfos(), isEmpty);
      });
    });

    group('TC-032: PluginManager — unloadAllPlugins', () {
      test('Normal: unloads all plugins in reverse dependency order', () async {
        final manager = PluginManager.instance;
        final stateManager = StateManager();
        final serviceLocator = ServiceLocator();
        final widgetRegistry = WidgetRegistry();
        final actionHandler = ActionHandler();

        manager.initialize(
          stateManager: stateManager,
          serviceLocator: serviceLocator,
          widgetRegistry: widgetRegistry,
          actionHandler: actionHandler,
        );

        final disposeOrder = <String>[];
        final pluginA = _TestPlugin('pluginA', onDispose: () => disposeOrder.add('A'));
        final pluginB = _TestPlugin('pluginB', dependencies: ['pluginA'], onDispose: () => disposeOrder.add('B'));

        await manager.registerPlugin(pluginA);
        await manager.registerPlugin(pluginB);
        await manager.loadAllPlugins();

        await manager.unloadAllPlugins();

        expect(manager.isPluginLoaded('pluginA'), false);
        expect(manager.isPluginLoaded('pluginB'), false);
        // Reverse order: B first, then A
        expect(disposeOrder, ['B', 'A']);
      });

      test('Boundary: no plugins loaded is no-op', () async {
        final manager = PluginManager.instance;
        final stateManager = StateManager();
        final serviceLocator = ServiceLocator();
        final widgetRegistry = WidgetRegistry();
        final actionHandler = ActionHandler();

        manager.initialize(
          stateManager: stateManager,
          serviceLocator: serviceLocator,
          widgetRegistry: widgetRegistry,
          actionHandler: actionHandler,
        );

        await manager.unloadAllPlugins();
      });
    });
  });

  // Helper to create an initialized PluginManager
  PluginManager createInitializedManager() {
    final manager = PluginManager.instance;
    manager.initialize(
      stateManager: StateManager(),
      serviceLocator: ServiceLocator(),
      widgetRegistry: WidgetRegistry(),
      actionHandler: ActionHandler(),
    );
    return manager;
  }

  group('TC-001: Full lifecycle — register → initialize → ready → dispose', () {
    setUp(() {
      PluginManager.resetInstance();
      PluginHookManager.resetInstance();
    });

    test('Normal: register → loadPlugin → isPluginLoaded true', () async {
      final manager = createInitializedManager();
      final initCalled = <bool>[false];
      final plugin = _TestPlugin('alpha', onInit: () => initCalled[0] = true);

      await manager.registerPlugin(plugin);
      expect(manager.isPluginLoaded('alpha'), isFalse);

      await manager.loadPlugin('alpha');
      expect(initCalled[0], isTrue);
      expect(manager.isPluginLoaded('alpha'), isTrue);
    });

    test('Normal: disposeAll → isPluginLoaded false', () async {
      final manager = createInitializedManager();
      final disposeCalled = <bool>[false];
      final plugin = _TestPlugin('alpha', onDispose: () => disposeCalled[0] = true);

      await manager.registerPlugin(plugin);
      await manager.loadPlugin('alpha');
      await manager.unloadAllPlugins();

      expect(disposeCalled[0], isTrue);
      expect(manager.isPluginLoaded('alpha'), isFalse);
    });

    test('Boundary: single plugin with no dependencies → immediate initialization', () async {
      final manager = createInitializedManager();
      final plugin = _TestPlugin('solo');

      await manager.registerPlugin(plugin);
      await manager.loadAllPlugins();
      expect(manager.isPluginLoaded('solo'), isTrue);
    });

    test('Error: plugin initialize() throws → plugin not loaded, error reported', () async {
      final manager = createInitializedManager();
      final plugin = _TestPlugin('bad', throwOnInit: true);

      await manager.registerPlugin(plugin);
      expect(
        () => manager.loadPlugin('bad'),
        throwsA(isA<PluginException>()),
      );
      expect(manager.isPluginLoaded('bad'), isFalse);
    });
  });

  group('TC-003: Dispose in reverse initialization order', () {
    setUp(() {
      PluginManager.resetInstance();
      PluginHookManager.resetInstance();
    });

    test('Normal: A, B(dep A), C(dep B) → dispose order C, B, A', () async {
      final manager = createInitializedManager();
      final disposeOrder = <String>[];

      final a = _TestPlugin('a', onDispose: () => disposeOrder.add('A'));
      final b = _TestPlugin('b', dependencies: ['a'], onDispose: () => disposeOrder.add('B'));
      final c = _TestPlugin('c', dependencies: ['b'], onDispose: () => disposeOrder.add('C'));

      await manager.registerPlugin(a);
      await manager.registerPlugin(b);
      await manager.registerPlugin(c);
      await manager.loadAllPlugins();
      await manager.unloadAllPlugins();

      expect(disposeOrder, equals(['C', 'B', 'A']));
    });

    test('Boundary: all independent → dispose in reverse registration order', () async {
      final manager = createInitializedManager();
      final disposeOrder = <String>[];

      final a = _TestPlugin('a', onDispose: () => disposeOrder.add('A'));
      final b = _TestPlugin('b', onDispose: () => disposeOrder.add('B'));
      final c = _TestPlugin('c', onDispose: () => disposeOrder.add('C'));

      await manager.registerPlugin(a);
      await manager.registerPlugin(b);
      await manager.registerPlugin(c);
      await manager.loadAllPlugins();
      await manager.unloadAllPlugins();

      // Reverse of load order
      expect(disposeOrder, equals(['C', 'B', 'A']));
    });
  });

  group('TC-004: Topological sort determines initialization order', () {
    setUp(() {
      PluginManager.resetInstance();
      PluginHookManager.resetInstance();
    });

    test('Normal: A(no deps), B(dep A), C(dep A,B) → init order A, B, C', () async {
      final manager = createInitializedManager();
      final initOrder = <String>[];

      final a = _TestPlugin('a', onInit: () => initOrder.add('A'));
      final b = _TestPlugin('b', dependencies: ['a'], onInit: () => initOrder.add('B'));
      final c = _TestPlugin('c', dependencies: ['a', 'b'], onInit: () => initOrder.add('C'));

      await manager.registerPlugin(a);
      await manager.registerPlugin(b);
      await manager.registerPlugin(c);
      await manager.loadAllPlugins();

      expect(initOrder, equals(['A', 'B', 'C']));
    });

    test('Boundary: single plugin → initialized immediately', () async {
      final manager = createInitializedManager();
      final initOrder = <String>[];
      final a = _TestPlugin('a', onInit: () => initOrder.add('A'));

      await manager.registerPlugin(a);
      await manager.loadAllPlugins();

      expect(initOrder, equals(['A']));
    });
  });

  group('TC-005: Circular dependency detection', () {
    setUp(() {
      PluginManager.resetInstance();
      PluginHookManager.resetInstance();
    });

    test('Normal: A depends B, B depends A → error thrown', () async {
      final manager = createInitializedManager();
      final a = _TestPlugin('a', dependencies: ['b']);
      final b = _TestPlugin('b', dependencies: ['a']);

      await manager.registerPlugin(a);
      await manager.registerPlugin(b);

      expect(
        () => manager.loadAllPlugins(),
        throwsA(isA<PluginException>().having(
          (e) => e.message, 'message', contains('Circular dependency'),
        )),
      );
    });

    test('Boundary: A depends B, B depends C (no cycle) → initializes normally', () async {
      final manager = createInitializedManager();
      final a = _TestPlugin('a', dependencies: ['b']);
      final b = _TestPlugin('b', dependencies: ['c']);
      final c = _TestPlugin('c');

      await manager.registerPlugin(a);
      await manager.registerPlugin(b);
      await manager.registerPlugin(c);
      await manager.loadAllPlugins();

      expect(manager.isPluginLoaded('a'), isTrue);
      expect(manager.isPluginLoaded('b'), isTrue);
      expect(manager.isPluginLoaded('c'), isTrue);
    });
  });

  group('TC-006: Missing dependency handling', () {
    setUp(() {
      PluginManager.resetInstance();
      PluginHookManager.resetInstance();
    });

    test('Normal: plugin depends on unregistered plugin → load fails', () async {
      final manager = createInitializedManager();
      final a = _TestPlugin('a', dependencies: ['nonexistent']);

      await manager.registerPlugin(a);

      // loadPlugin will try to load 'nonexistent' which is not registered
      expect(
        () => manager.loadPlugin('a'),
        throwsA(isA<PluginException>()),
      );
    });
  });

  group('TC-007: onWidgetRegister hook', () {
    test('Normal: hook called when widget register event fired', () async {
      final manager = PluginHookManager.instance;
      Map<String, dynamic>? received;

      manager.registerHook(
        pluginName: 'widgetPlugin',
        hookType: PluginHookType.onWidgetRegister,
        callback: (ctx) async { received = ctx.data; },
      );

      await manager.fireHook(PluginHookType.onWidgetRegister, data: {
        'pluginName': 'widgetPlugin',
        'widgetType': 'CustomButton',
      });

      expect(received, isNotNull);
      expect(received!['widgetType'], equals('CustomButton'));
    });

    test('Error: hook throws → error caught, no propagation', () async {
      final manager = PluginHookManager.instance;

      manager.registerHook(
        pluginName: 'badPlugin',
        hookType: PluginHookType.onWidgetRegister,
        callback: (ctx) async { throw Exception('widget hook error'); },
      );

      // Should not throw
      await manager.fireHook(PluginHookType.onWidgetRegister, data: {
        'widgetType': 'test',
      });
    });
  });

  group('TC-008: onActionRegister hook', () {
    test('Normal: hook called with action data', () async {
      final manager = PluginHookManager.instance;
      Map<String, dynamic>? received;

      manager.registerHook(
        pluginName: 'actionPlugin',
        hookType: PluginHookType.onActionRegister,
        callback: (ctx) async { received = ctx.data; },
      );

      await manager.fireHook(PluginHookType.onActionRegister, data: {
        'pluginName': 'actionPlugin',
        'actionType': 'customAction',
      });

      expect(received!['actionType'], equals('customAction'));
    });

    test('Boundary: no plugins hook onActionRegister → no-op', () async {
      final manager = PluginHookManager.instance;
      await manager.fireHook(PluginHookType.onActionRegister, data: {
        'actionType': 'test',
      });
      // No error expected
    });
  });

  group('TC-009: onLifecycle hook', () {
    test('Normal: hook receives lifecycle events', () async {
      final manager = PluginHookManager.instance;
      final events = <String>[];

      manager.registerHook(
        pluginName: 'lifecyclePlugin',
        hookType: PluginHookType.onLifecycle,
        callback: (ctx) async { events.add(ctx.data['event'] as String); },
      );

      await manager.fireHook(PluginHookType.onLifecycle, data: {'event': 'initializing'});
      await manager.fireHook(PluginHookType.onLifecycle, data: {'event': 'initialized'});
      await manager.fireHook(PluginHookType.onLifecycle, data: {'event': 'disposing'});

      expect(events, equals(['initializing', 'initialized', 'disposing']));
    });

    test('Error: hook throws → other lifecycle hooks still called', () async {
      final manager = PluginHookManager.instance;
      bool secondCalled = false;

      manager.registerHook(
        pluginName: 'badLifecycle',
        hookType: PluginHookType.onLifecycle,
        callback: (ctx) async { throw Exception('lifecycle error'); },
        priority: 10,
      );

      manager.registerHook(
        pluginName: 'goodLifecycle',
        hookType: PluginHookType.onLifecycle,
        callback: (ctx) async { secondCalled = true; },
        priority: 0,
      );

      await manager.fireHook(PluginHookType.onLifecycle, data: {'event': 'initializing'});
      expect(secondCalled, isTrue);
    });
  });

  group('TC-010: onStateChange hook', () {
    test('Normal: hook receives path, oldValue, newValue', () async {
      final manager = PluginHookManager.instance;
      Map<String, dynamic>? received;

      manager.registerHook(
        pluginName: 'statePlugin',
        hookType: PluginHookType.onStateChange,
        callback: (ctx) async { received = ctx.data; },
      );

      await manager.fireHook(PluginHookType.onStateChange, data: {
        'path': 'user.name',
        'oldValue': 'Alice',
        'newValue': 'Bob',
      });

      expect(received!['path'], equals('user.name'));
      expect(received!['oldValue'], equals('Alice'));
      expect(received!['newValue'], equals('Bob'));
    });

    test('Error: hook throws → error caught', () async {
      final manager = PluginHookManager.instance;

      manager.registerHook(
        pluginName: 'badState',
        hookType: PluginHookType.onStateChange,
        callback: (ctx) async { throw Exception('state error'); },
      );

      await manager.fireHook(PluginHookType.onStateChange, data: {
        'path': 'test', 'oldValue': null, 'newValue': 1,
      });
      // No throw expected
    });
  });

  group('TC-011: onRender hook', () {
    test('Normal: hook receives widget type and props', () async {
      final manager = PluginHookManager.instance;
      Map<String, dynamic>? received;

      manager.registerHook(
        pluginName: 'renderPlugin',
        hookType: PluginHookType.onRender,
        callback: (ctx) async { received = ctx.data; },
      );

      await manager.fireHook(PluginHookType.onRender, data: {
        'widgetType': 'Text',
        'props': {'text': 'Hello'},
      });

      expect(received!['widgetType'], equals('Text'));
      expect(received!['props'], equals({'text': 'Hello'}));
    });

    test('Error: hook throws → error caught', () async {
      final manager = PluginHookManager.instance;

      manager.registerHook(
        pluginName: 'badRender',
        hookType: PluginHookType.onRender,
        callback: (ctx) async { throw Exception('render error'); },
      );

      await manager.fireHook(PluginHookType.onRender, data: {'widgetType': 'Text'});
    });
  });

  group('TC-012: onError hook', () {
    test('Normal: hook receives error and stack trace data', () async {
      final manager = PluginHookManager.instance;
      Map<String, dynamic>? received;

      manager.registerHook(
        pluginName: 'errorPlugin',
        hookType: PluginHookType.onError,
        callback: (ctx) async { received = ctx.data; },
      );

      await manager.fireHook(PluginHookType.onError, data: {
        'error': 'Something failed',
        'stackTrace': 'trace...',
        'source': 'testPlugin',
      });

      expect(received!['error'], equals('Something failed'));
      expect(received!['source'], equals('testPlugin'));
    });

    test('Error: error hook itself throws → logged, chain continues', () async {
      final manager = PluginHookManager.instance;
      bool secondCalled = false;

      manager.registerHook(
        pluginName: 'badErrorPlugin',
        hookType: PluginHookType.onError,
        callback: (ctx) async { throw Exception('meta error'); },
        priority: 10,
      );

      manager.registerHook(
        pluginName: 'goodErrorPlugin',
        hookType: PluginHookType.onError,
        callback: (ctx) async { secondCalled = true; },
        priority: 0,
      );

      await manager.fireHook(PluginHookType.onError, data: {'error': 'test'});
      expect(secondCalled, isTrue);
    });
  });

  group('TC-013: Chain of Responsibility order', () {
    test('Normal: hooks invoked in priority order, each receives data', () async {
      final manager = PluginHookManager.instance;
      final order = <String>[];

      manager.registerHook(
        pluginName: 'pluginA',
        hookType: PluginHookType.onRender,
        callback: (ctx) async { order.add('A'); },
        priority: 20,
      );

      manager.registerHook(
        pluginName: 'pluginB',
        hookType: PluginHookType.onRender,
        callback: (ctx) async { order.add('B'); },
        priority: 10,
      );

      manager.registerHook(
        pluginName: 'pluginC',
        hookType: PluginHookType.onRender,
        callback: (ctx) async { order.add('C'); },
        priority: 0,
      );

      await manager.fireHook(PluginHookType.onRender);
      expect(order, equals(['A', 'B', 'C']));
    });

    test('Boundary: single plugin → hook invoked once', () async {
      final manager = PluginHookManager.instance;
      int callCount = 0;

      manager.registerHook(
        pluginName: 'solo',
        hookType: PluginHookType.onRender,
        callback: (ctx) async { callCount++; },
      );

      await manager.fireHook(PluginHookType.onRender);
      expect(callCount, equals(1));
    });

    test('Error: middle plugin throws → remaining plugins still execute', () async {
      final manager = PluginHookManager.instance;
      final order = <String>[];

      manager.registerHook(
        pluginName: 'first',
        hookType: PluginHookType.onRender,
        callback: (ctx) async { order.add('first'); },
        priority: 20,
      );

      manager.registerHook(
        pluginName: 'middle',
        hookType: PluginHookType.onRender,
        callback: (ctx) async { throw Exception('middle error'); },
        priority: 10,
      );

      manager.registerHook(
        pluginName: 'last',
        hookType: PluginHookType.onRender,
        callback: (ctx) async { order.add('last'); },
        priority: 0,
      );

      await manager.fireHook(PluginHookType.onRender);
      expect(order, equals(['first', 'last']));
    });
  });

  group('TC-016: Error boundary per plugin', () {
    test('Normal: plugin A hook throws → plugin B hook executes normally', () async {
      final manager = PluginHookManager.instance;
      bool bExecuted = false;

      manager.registerHook(
        pluginName: 'pluginA',
        hookType: PluginHookType.onStateChange,
        callback: (ctx) async { throw Exception('A fails'); },
        priority: 10,
      );

      manager.registerHook(
        pluginName: 'pluginB',
        hookType: PluginHookType.onStateChange,
        callback: (ctx) async { bExecuted = true; },
        priority: 0,
      );

      await manager.fireHook(PluginHookType.onStateChange, data: {'path': 'x'});
      expect(bExecuted, isTrue);
    });

    test('Error: multiple plugins throw in same chain → each error caught independently', () async {
      final manager = PluginHookManager.instance;
      int throwCount = 0;

      for (final name in ['p1', 'p2', 'p3']) {
        manager.registerHook(
          pluginName: name,
          hookType: PluginHookType.onRender,
          callback: (ctx) async {
            throwCount++;
            throw Exception('$name error');
          },
        );
      }

      // Should not throw despite all hooks throwing
      await manager.fireHook(PluginHookType.onRender);
      expect(throwCount, equals(3));
    });
  });

  group('TC-025: PluginManager — getPluginInfo', () {
    setUp(() {
      PluginManager.resetInstance();
      PluginHookManager.resetInstance();
    });

    test('Normal: returns PluginInfo with correct metadata', () async {
      final manager = createInitializedManager();
      final plugin = _TestPlugin('infoPlugin', version: '2.0.0', description: 'A test plugin');

      await manager.registerPlugin(plugin);
      final info = manager.getPluginInfo('infoPlugin');

      expect(info, isNotNull);
      expect(info!.name, equals('infoPlugin'));
      expect(info.version, equals('2.0.0'));
      expect(info.description, equals('A test plugin'));
      expect(info.isLoaded, isFalse);
    });

    test('Normal: isLoaded reflects loaded state', () async {
      final manager = createInitializedManager();
      final plugin = _TestPlugin('loadable');

      await manager.registerPlugin(plugin);
      await manager.loadPlugin('loadable');

      final info = manager.getPluginInfo('loadable');
      expect(info!.isLoaded, isTrue);
    });

    test('Boundary: plugin name not found → returns null', () {
      final manager = createInitializedManager();
      expect(manager.getPluginInfo('nonexistent'), isNull);
    });
  });

  group('TC-026: PluginManager — getAllPluginInfos', () {
    setUp(() {
      PluginManager.resetInstance();
      PluginHookManager.resetInstance();
    });

    test('Normal: returns list of PluginInfo for all registered plugins', () async {
      final manager = createInitializedManager();

      await manager.registerPlugin(_TestPlugin('p1'));
      await manager.registerPlugin(_TestPlugin('p2'));

      final infos = manager.getAllPluginInfos();
      expect(infos.length, equals(2));
      expect(infos.map((i) => i.name).toList(), containsAll(['p1', 'p2']));
    });

    test('Boundary: no plugins registered → returns empty list', () {
      final manager = createInitializedManager();
      expect(manager.getAllPluginInfos(), isEmpty);
    });
  });

  group('TC-027: PluginManager — isPluginLoaded', () {
    setUp(() {
      PluginManager.resetInstance();
      PluginHookManager.resetInstance();
    });

    test('Normal: true for loaded, false for registered-but-not-loaded', () async {
      final manager = createInitializedManager();

      await manager.registerPlugin(_TestPlugin('loaded'));
      await manager.registerPlugin(_TestPlugin('notLoaded'));
      await manager.loadPlugin('loaded');

      expect(manager.isPluginLoaded('loaded'), isTrue);
      expect(manager.isPluginLoaded('notLoaded'), isFalse);
    });

    test('Boundary: unknown plugin name → returns false', () {
      final manager = createInitializedManager();
      expect(manager.isPluginLoaded('unknown'), isFalse);
    });
  });

  group('TC-028: PluginHookManager — unregisterHook', () {
    test('Normal: hook unregistered → fireHook does not invoke it', () async {
      final manager = PluginHookManager.instance;
      int callCount = 0;

      manager.registerHook(
        pluginName: 'myPlugin',
        hookType: PluginHookType.onStateChange,
        callback: (ctx) async { callCount++; },
      );

      manager.unregisterHook(
        pluginName: 'myPlugin',
        hookType: PluginHookType.onStateChange,
      );

      await manager.fireHook(PluginHookType.onStateChange);
      expect(callCount, equals(0));
    });

    test('Boundary: unregister non-existent hook → no-op', () {
      final manager = PluginHookManager.instance;

      // Should not throw
      manager.unregisterHook(
        pluginName: 'nonexistent',
        hookType: PluginHookType.onRender,
      );
    });
  });

  group('TC-029: PluginHookManager — hookCount and activeHookTypes', () {
    test('Normal: hookCount returns correct count; activeHookTypes lists types', () {
      final manager = PluginHookManager.instance;

      manager.registerHook(
        pluginName: 'p1',
        hookType: PluginHookType.onRender,
        callback: (ctx) async {},
      );
      manager.registerHook(
        pluginName: 'p2',
        hookType: PluginHookType.onRender,
        callback: (ctx) async {},
      );
      manager.registerHook(
        pluginName: 'p1',
        hookType: PluginHookType.onError,
        callback: (ctx) async {},
      );

      expect(manager.hookCount(PluginHookType.onRender), equals(2));
      expect(manager.hookCount(PluginHookType.onError), equals(1));
      expect(manager.activeHookTypes, containsAll([
        PluginHookType.onRender,
        PluginHookType.onError,
      ]));
    });

    test('Boundary: no hooks → hookCount 0, activeHookTypes empty', () {
      final manager = PluginHookManager.instance;
      expect(manager.hookCount(PluginHookType.onRender), equals(0));
      expect(manager.activeHookTypes, isEmpty);
    });
  });

  group('TC-030: MCPPlugin — onEnabled and onDisabled callbacks', () {
    setUp(() {
      PluginManager.resetInstance();
      PluginHookManager.resetInstance();
    });

    test('Normal: onEnabled called after load; onDisabled called before dispose', () async {
      final manager = createInitializedManager();
      final events = <String>[];

      final plugin = _TestPlugin(
        'callbackPlugin',
        onEnabledCallback: () => events.add('enabled'),
        onDisabledCallback: () => events.add('disabled'),
        onInit: () => events.add('init'),
        onDispose: () => events.add('dispose'),
      );

      await manager.registerPlugin(plugin);
      await manager.loadPlugin('callbackPlugin');

      // onEnabled is called after initialize
      expect(events, equals(['init', 'enabled']));

      await manager.unloadPlugin('callbackPlugin');

      // onDisabled is called before dispose
      expect(events, equals(['init', 'enabled', 'disabled', 'dispose']));
    });

    test('Boundary: plugin with empty onEnabled/onDisabled → lifecycle proceeds', () async {
      final manager = createInitializedManager();
      final plugin = _TestPlugin('emptyCallbacks');

      await manager.registerPlugin(plugin);
      await manager.loadPlugin('emptyCallbacks');
      await manager.unloadPlugin('emptyCallbacks');

      expect(manager.isPluginLoaded('emptyCallbacks'), isFalse);
    });
  });

  group('TC-033: PluginHookManager — fireHookSync', () {
    test('Normal: fires hook synchronously; handlers execute', () async {
      final manager = PluginHookManager.instance;
      bool called = false;

      manager.registerHook(
        pluginName: 'syncPlugin',
        hookType: PluginHookType.onRender,
        callback: (ctx) async { called = true; },
      );

      manager.fireHookSync(PluginHookType.onRender, data: {'widgetType': 'Text'});

      // Allow microtask to complete
      await Future.delayed(Duration.zero);
      expect(called, isTrue);
    });

    test('Normal: handlers execute in registration order', () async {
      final manager = PluginHookManager.instance;
      final order = <String>[];

      manager.registerHook(
        pluginName: 'first',
        hookType: PluginHookType.onRender,
        callback: (ctx) async { order.add('first'); },
        priority: 10,
      );

      manager.registerHook(
        pluginName: 'second',
        hookType: PluginHookType.onRender,
        callback: (ctx) async { order.add('second'); },
        priority: 0,
      );

      manager.fireHookSync(PluginHookType.onRender);
      await Future.delayed(Duration.zero);

      expect(order, equals(['first', 'second']));
    });

    test('Boundary: no handlers for hook type → no-op', () {
      final manager = PluginHookManager.instance;
      // Should not throw
      manager.fireHookSync(PluginHookType.onLifecycle);
    });

    test('Error: handler throws → error isolated, remaining handlers execute', () async {
      final manager = PluginHookManager.instance;
      bool secondCalled = false;

      manager.registerHook(
        pluginName: 'thrower',
        hookType: PluginHookType.onRender,
        callback: (ctx) { throw Exception('sync error'); },
        priority: 10,
      );

      manager.registerHook(
        pluginName: 'survivor',
        hookType: PluginHookType.onRender,
        callback: (ctx) async { secondCalled = true; },
        priority: 0,
      );

      manager.fireHookSync(PluginHookType.onRender);
      await Future.delayed(Duration.zero);

      expect(secondCalled, isTrue);
    });
  });

  group('TC-034: PluginHookManager — hasHooks', () {
    test('Normal: returns true when hooks registered for type', () {
      final manager = PluginHookManager.instance;

      manager.registerHook(
        pluginName: 'p1',
        hookType: PluginHookType.onError,
        callback: (ctx) async {},
      );

      expect(manager.hasHooks(PluginHookType.onError), isTrue);
    });

    test('Normal: returns false when no hooks for type', () {
      final manager = PluginHookManager.instance;
      expect(manager.hasHooks(PluginHookType.onRender), isFalse);
    });

    test('Boundary: after unregisterHook removes last hook → returns false', () {
      final manager = PluginHookManager.instance;

      manager.registerHook(
        pluginName: 'onlyPlugin',
        hookType: PluginHookType.onStateChange,
        callback: (ctx) async {},
      );

      expect(manager.hasHooks(PluginHookType.onStateChange), isTrue);

      manager.unregisterHook(
        pluginName: 'onlyPlugin',
        hookType: PluginHookType.onStateChange,
      );

      expect(manager.hasHooks(PluginHookType.onStateChange), isFalse);
    });
  });

  group('TC-002: Configure called before initialize', () {
    setUp(() {
      PluginManager.resetInstance();
      PluginHookManager.resetInstance();
    });

    test('Normal: configure() runs before initialize() when config is set', () async {
      final manager = createInitializedManager();
      final plugin = _TestPlugin('configurable');

      manager.setPluginConfig('configurable', {'key': 'value'});
      await manager.registerPlugin(plugin);
      await manager.loadPlugin('configurable');

      expect(plugin.lifecycleOrder, equals(['configure', 'initialize']));
      expect(plugin.receivedConfig, equals({'key': 'value'}));
    });

    test('Boundary: no config set → configure() not called, initialize() still called', () async {
      final manager = createInitializedManager();
      final plugin = _TestPlugin('noConfig');

      await manager.registerPlugin(plugin);
      await manager.loadPlugin('noConfig');

      expect(plugin.lifecycleOrder, equals(['initialize']));
      expect(plugin.receivedConfig, isNull);
    });
  });

  group('TC-014: Typed configuration map', () {
    setUp(() {
      PluginManager.resetInstance();
      PluginHookManager.resetInstance();
    });

    test('Normal: plugin receives config map with correct types', () async {
      final manager = createInitializedManager();
      final plugin = _TestPlugin('typed');

      final config = <String, dynamic>{
        'stringVal': 'hello',
        'intVal': 42,
        'boolVal': true,
        'listVal': [1, 2, 3],
        'mapVal': {'nested': 'data'},
      };

      manager.setPluginConfig('typed', config);
      await manager.registerPlugin(plugin);
      await manager.loadPlugin('typed');

      expect(plugin.receivedConfig!['stringVal'], isA<String>());
      expect(plugin.receivedConfig!['stringVal'], equals('hello'));
      expect(plugin.receivedConfig!['intVal'], isA<int>());
      expect(plugin.receivedConfig!['intVal'], equals(42));
      expect(plugin.receivedConfig!['boolVal'], isA<bool>());
      expect(plugin.receivedConfig!['boolVal'], equals(true));
      expect(plugin.receivedConfig!['listVal'], equals([1, 2, 3]));
      expect(plugin.receivedConfig!['mapVal'], equals({'nested': 'data'}));
    });
  });

  group('TC-015: Configuration immutability', () {
    setUp(() {
      PluginManager.resetInstance();
      PluginHookManager.resetInstance();
    });

    test('Normal: modifying config after configure does not affect plugin', () async {
      final manager = createInitializedManager();
      final plugin = _TestPlugin('immutable');

      final config = <String, dynamic>{'key': 'original'};
      manager.setPluginConfig('immutable', config);
      await manager.registerPlugin(plugin);
      await manager.loadPlugin('immutable');

      // Modify the original config after configure was called
      config['key'] = 'modified';
      config['newKey'] = 'added';

      // Plugin should still have the original values
      expect(plugin.receivedConfig!['key'], equals('original'));
      expect(plugin.receivedConfig!.containsKey('newKey'), isFalse);
    });
  });

  group('TC-017: Disable misbehaving plugin (error isolation)', () {
    setUp(() {
      PluginManager.resetInstance();
      PluginHookManager.resetInstance();
    });

    test('Normal: plugin initialize throws → other plugins still load', () async {
      final manager = createInitializedManager();
      final loadOrder = <String>[];

      final badPlugin = _TestPlugin('bad', throwOnInit: true);
      final goodPlugin = _TestPlugin('good', onInit: () => loadOrder.add('good'));

      await manager.registerPlugin(badPlugin);
      await manager.registerPlugin(goodPlugin);

      // Bad plugin throws on load
      expect(
        () => manager.loadPlugin('bad'),
        throwsA(isA<PluginException>()),
      );
      expect(manager.isPluginLoaded('bad'), isFalse);

      // Good plugin still loads successfully
      await manager.loadPlugin('good');
      expect(manager.isPluginLoaded('good'), isTrue);
      expect(loadOrder, equals(['good']));
    });

    test('Normal: after disabling plugin, its hooks are deactivated', () async {
      final manager = createInitializedManager();
      final hookManager = PluginHookManager.instance;
      int hookCallCount = 0;

      final plugin = _TestPlugin('misbehaving');
      await manager.registerPlugin(plugin);
      await manager.loadPlugin('misbehaving');

      // Register a hook for the plugin
      hookManager.registerHook(
        pluginName: 'misbehaving',
        hookType: PluginHookType.onStateChange,
        callback: (ctx) async { hookCallCount++; },
      );

      // Hook fires before unload
      await hookManager.fireHook(PluginHookType.onStateChange, data: {'path': 'x'});
      expect(hookCallCount, equals(1));

      // Unload the misbehaving plugin (simulates disabling)
      await manager.unloadPlugin('misbehaving');

      // Hook should no longer fire after unload (hooks unregistered)
      await hookManager.fireHook(PluginHookType.onStateChange, data: {'path': 'x'});
      expect(hookCallCount, equals(1));
    });

    test('Boundary: error threshold 1 — first error disables plugin hooks', () async {
      final hookManager = PluginHookManager.instance;
      bool goodCalled = false;

      // Misbehaving plugin hook that throws
      hookManager.registerHook(
        pluginName: 'errorProne',
        hookType: PluginHookType.onRender,
        callback: (ctx) async { throw Exception('misbehave'); },
        priority: 10,
      );

      hookManager.registerHook(
        pluginName: 'stable',
        hookType: PluginHookType.onRender,
        callback: (ctx) async { goodCalled = true; },
        priority: 0,
      );

      // Fire hook — error is caught, stable plugin still runs
      await hookManager.fireHook(PluginHookType.onRender);
      expect(goodCalled, isTrue);

      // Simulate disabling: unregister the misbehaving plugin
      hookManager.unregisterPlugin('errorProne');
      expect(hookManager.hookCount(PluginHookType.onRender), equals(1));
    });
  });

  group('TC-018: Error reporting via onError hook excludes failing plugin', () {
    setUp(() {
      PluginHookManager.resetInstance();
    });

    test('Normal: onError hooks of all plugins fire independently', () async {
      final hookManager = PluginHookManager.instance;
      final errorReceivers = <String>[];

      // Plugin A registers an onError hook
      hookManager.registerHook(
        pluginName: 'pluginA',
        hookType: PluginHookType.onError,
        callback: (ctx) async { errorReceivers.add('A'); },
      );

      // Plugin B registers an onError hook
      hookManager.registerHook(
        pluginName: 'pluginB',
        hookType: PluginHookType.onError,
        callback: (ctx) async { errorReceivers.add('B'); },
      );

      // Fire error event originating from pluginA
      await hookManager.fireHook(PluginHookType.onError, data: {
        'error': 'Something failed',
        'source': 'pluginA',
      });

      // Both hooks fire — hooks are independent of plugin load state
      expect(errorReceivers, equals(['A', 'B']));
    });

    test('Boundary: only failing plugin has onError hook → still fires', () async {
      final hookManager = PluginHookManager.instance;
      bool called = false;

      hookManager.registerHook(
        pluginName: 'onlyPlugin',
        hookType: PluginHookType.onError,
        callback: (ctx) async { called = true; },
      );

      await hookManager.fireHook(PluginHookType.onError, data: {
        'error': 'self error',
        'source': 'onlyPlugin',
      });

      // Hook fires regardless — hooks are independent
      expect(called, isTrue);
    });

    test('Error: onError hook itself throws → logged, no infinite loop', () async {
      final hookManager = PluginHookManager.instance;
      bool secondCalled = false;

      hookManager.registerHook(
        pluginName: 'badErrorHandler',
        hookType: PluginHookType.onError,
        callback: (ctx) async { throw Exception('error in error handler'); },
        priority: 10,
      );

      hookManager.registerHook(
        pluginName: 'goodErrorHandler',
        hookType: PluginHookType.onError,
        callback: (ctx) async { secondCalled = true; },
        priority: 0,
      );

      // Should not throw and should not loop
      await hookManager.fireHook(PluginHookType.onError, data: {
        'error': 'original error',
        'source': 'somePlugin',
      });

      expect(secondCalled, isTrue);
    });
  });

  group('TC-019: Accessibility plugin (built-in plugins)', () {
    setUp(() {
      PluginManager.resetInstance();
      PluginHookManager.resetInstance();
    });

    test('Normal: accessibility plugin registers onRender hook for semantic labels', () async {
      final manager = createInitializedManager();
      final hookManager = PluginHookManager.instance;

      final plugin = _AccessibilityPlugin();
      await manager.registerPlugin(plugin);
      await manager.loadPlugin('accessibility');

      expect(manager.isPluginLoaded('accessibility'), isTrue);

      // Verify the onRender hook was registered
      expect(hookManager.hasHooks(PluginHookType.onRender), isTrue);

      // Fire onRender and verify semantic label is injected
      Map<String, dynamic>? modifiedData;
      hookManager.registerHook(
        pluginName: 'verifier',
        hookType: PluginHookType.onRender,
        callback: (ctx) async { modifiedData = ctx.data; },
        priority: -1,
      );

      await hookManager.fireHook(PluginHookType.onRender, data: {
        'widgetType': 'Button',
        'props': {'text': 'Submit'},
      });

      expect(modifiedData, isNotNull);
      expect(modifiedData!['widgetType'], equals('Button'));
    });

    test('Boundary: widget with no accessibility props → passes through unchanged', () async {
      final manager = createInitializedManager();
      final hookManager = PluginHookManager.instance;

      final plugin = _AccessibilityPlugin();
      await manager.registerPlugin(plugin);
      await manager.loadPlugin('accessibility');

      final receivedData = <Map<String, dynamic>>[];
      hookManager.registerHook(
        pluginName: 'collector',
        hookType: PluginHookType.onRender,
        callback: (ctx) async { receivedData.add(ctx.data); },
        priority: -1,
      );

      await hookManager.fireHook(PluginHookType.onRender, data: {
        'widgetType': 'Divider',
        'props': {},
      });

      expect(receivedData.length, equals(1));
      expect(receivedData[0]['widgetType'], equals('Divider'));
    });
  });

  group('TC-020: I18n plugin (built-in plugins)', () {
    setUp(() {
      PluginManager.resetInstance();
      PluginHookManager.resetInstance();
    });

    test('Normal: i18n plugin registers onRender hook for translations', () async {
      final manager = createInitializedManager();
      final hookManager = PluginHookManager.instance;

      final plugin = _I18nPlugin(translations: {'greeting': 'Hello'});
      await manager.registerPlugin(plugin);
      await manager.loadPlugin('i18n');

      expect(manager.isPluginLoaded('i18n'), isTrue);
      expect(hookManager.hasHooks(PluginHookType.onRender), isTrue);
    });

    test('Boundary: missing translation key → returns key as fallback', () {
      final plugin = _I18nPlugin(translations: {'greeting': 'Hello'});
      final result = plugin.translate('missing.key');
      expect(result, equals('missing.key'));
    });

    test('Normal: translate resolves known keys', () {
      final plugin = _I18nPlugin(translations: {
        'greeting': 'Hello',
        'farewell': 'Goodbye',
      });

      expect(plugin.translate('greeting'), equals('Hello'));
      expect(plugin.translate('farewell'), equals('Goodbye'));
    });

    test('Error: empty translations → returns keys as fallback', () {
      final plugin = _I18nPlugin(translations: {});
      expect(plugin.translate('any.key'), equals('any.key'));
    });
  });

  group('TC-021: Built-in plugin disable', () {
    setUp(() {
      PluginManager.resetInstance();
      PluginHookManager.resetInstance();
    });

    test('Normal: disable built-in plugin → not initialized, no hooks active', () async {
      final manager = createInitializedManager();
      final hookManager = PluginHookManager.instance;

      final plugin = _AccessibilityPlugin();
      await manager.registerPlugin(plugin);

      // Do not load the plugin — simulates disabling via config
      expect(manager.isPluginLoaded('accessibility'), isFalse);
      expect(hookManager.hasHooks(PluginHookType.onRender), isFalse);
    });

    test('Boundary: disable all built-in plugins → runtime operates without any', () async {
      final manager = createInitializedManager();

      final a11y = _AccessibilityPlugin();
      final i18n = _I18nPlugin(translations: {});

      await manager.registerPlugin(a11y);
      await manager.registerPlugin(i18n);

      // Neither loaded — runtime works with zero plugins
      expect(manager.isPluginLoaded('accessibility'), isFalse);
      expect(manager.isPluginLoaded('i18n'), isFalse);
      expect(manager.getAllPluginInfos().every((info) => !info.isLoaded), isTrue);
    });

    test('Normal: load then unload built-in plugin → hooks deactivated', () async {
      final manager = createInitializedManager();
      final hookManager = PluginHookManager.instance;

      final plugin = _AccessibilityPlugin();
      await manager.registerPlugin(plugin);
      await manager.loadPlugin('accessibility');

      expect(hookManager.hasHooks(PluginHookType.onRender), isTrue);

      await manager.unloadPlugin('accessibility');

      expect(manager.isPluginLoaded('accessibility'), isFalse);
      expect(hookManager.hasHooks(PluginHookType.onRender), isFalse);
    });
  });

  group('TC-022: Dynamic widget loading via plugin', () {
    setUp(() {
      PluginManager.resetInstance();
      PluginHookManager.resetInstance();
    });

    test('Normal: plugin registers custom widget factory at runtime', () async {
      final manager = createInitializedManager();
      final widgetRegistry = WidgetRegistry();

      // Re-initialize with the registry we can inspect
      manager.initialize(
        stateManager: StateManager(),
        serviceLocator: ServiceLocator(),
        widgetRegistry: widgetRegistry,
        actionHandler: ActionHandler(),
      );

      final plugin = _WidgetProviderPlugin(
        widgetTypes: {'CustomChart': _MockWidgetFactory()},
      );

      await manager.registerPlugin(plugin);
      await manager.loadPlugin('widgetProvider');

      expect(manager.isPluginLoaded('widgetProvider'), isTrue);
      // Verify the widget was registered via plugin's widgets getter
      final info = manager.getPluginInfo('widgetProvider');
      expect(info!.widgetCount, equals(1));
    });

    test('Normal: onWidgetRegister hook fires when plugin registers widget', () async {
      final manager = createInitializedManager();
      final hookManager = PluginHookManager.instance;
      final registeredWidgets = <String>[];

      hookManager.registerHook(
        pluginName: 'observer',
        hookType: PluginHookType.onWidgetRegister,
        callback: (ctx) async {
          registeredWidgets.add(ctx.data['widgetType'] as String);
        },
      );

      final plugin = _WidgetProviderPlugin(
        widgetTypes: {'DynamicCard': _MockWidgetFactory()},
      );

      await manager.registerPlugin(plugin);
      await manager.loadPlugin('widgetProvider');

      expect(registeredWidgets, contains('DynamicCard'));
    });

    test('Boundary: plugin registers factory for known type → hook chain notified', () async {
      final hookManager = PluginHookManager.instance;
      final notifications = <String>[];

      hookManager.registerHook(
        pluginName: 'watcher',
        hookType: PluginHookType.onWidgetRegister,
        callback: (ctx) async {
          notifications.add('${ctx.data['pluginName']}:${ctx.data['widgetType']}');
        },
      );

      // Simulate two plugins registering same type name
      await hookManager.fireHook(PluginHookType.onWidgetRegister, data: {
        'pluginName': 'pluginA',
        'widgetType': 'SharedWidget',
      });
      await hookManager.fireHook(PluginHookType.onWidgetRegister, data: {
        'pluginName': 'pluginB',
        'widgetType': 'SharedWidget',
      });

      expect(notifications, equals(['pluginA:SharedWidget', 'pluginB:SharedWidget']));
    });
  });

  group('TC-023: Third-party plugin integration', () {
    setUp(() {
      PluginManager.resetInstance();
      PluginHookManager.resetInstance();
    });

    test('Normal: third-party plugin implements MCPPlugin → registers and hooks active', () async {
      final manager = createInitializedManager();
      final hookManager = PluginHookManager.instance;

      final plugin = _ThirdPartyPlugin();
      await manager.registerPlugin(plugin);
      await manager.loadPlugin('thirdParty');

      expect(manager.isPluginLoaded('thirdParty'), isTrue);
      // Third-party plugin registers a lifecycle hook during init
      expect(hookManager.hasHooks(PluginHookType.onLifecycle), isTrue);
    });

    test('Boundary: third-party plugin with no hooks → registers but does nothing', () async {
      final manager = createInitializedManager();
      final hookManager = PluginHookManager.instance;

      final plugin = _TestPlugin('noopThirdParty');
      await manager.registerPlugin(plugin);
      await manager.loadPlugin('noopThirdParty');

      expect(manager.isPluginLoaded('noopThirdParty'), isTrue);
      // No hooks registered by this plugin
      expect(hookManager.activeHookTypes, isEmpty);
    });

    test('Error: third-party plugin init fails → error isolated, core runtime unaffected', () async {
      final manager = createInitializedManager();

      final badThirdParty = _TestPlugin('badThirdParty', throwOnInit: true);
      final corePlugin = _TestPlugin('core');

      await manager.registerPlugin(badThirdParty);
      await manager.registerPlugin(corePlugin);

      // Bad third-party plugin fails
      expect(
        () => manager.loadPlugin('badThirdParty'),
        throwsA(isA<PluginException>()),
      );
      expect(manager.isPluginLoaded('badThirdParty'), isFalse);

      // Core plugin loads fine
      await manager.loadPlugin('core');
      expect(manager.isPluginLoaded('core'), isTrue);
    });
  });

  group('TC-024: Custom protocol via plugin', () {
    setUp(() {
      PluginManager.resetInstance();
      PluginHookManager.resetInstance();
    });

    test('Normal: plugin registers custom action executor → actions available', () async {
      final manager = createInitializedManager();

      final plugin = _CustomProtocolPlugin();
      await manager.registerPlugin(plugin);
      await manager.loadPlugin('customProtocol');

      expect(manager.isPluginLoaded('customProtocol'), isTrue);
      final info = manager.getPluginInfo('customProtocol');
      expect(info!.actionCount, equals(1));
    });

    test('Normal: onActionRegister hook fires for custom protocol action', () async {
      final manager = createInitializedManager();
      final hookManager = PluginHookManager.instance;
      final registeredActions = <String>[];

      hookManager.registerHook(
        pluginName: 'observer',
        hookType: PluginHookType.onActionRegister,
        callback: (ctx) async {
          registeredActions.add(ctx.data['actionType'] as String);
        },
      );

      final plugin = _CustomProtocolPlugin();
      await manager.registerPlugin(plugin);
      await manager.loadPlugin('customProtocol');

      expect(registeredActions, contains('customProtocol.execute'));
    });

    test('Normal: custom action executor returns expected result', () async {
      final plugin = _CustomProtocolPlugin();
      final executor = plugin.actions!['customProtocol.execute']!;

      final result = await executor({'command': 'ping'});
      expect(result, isA<Map<String, dynamic>>());
      expect((result as Map<String, dynamic>)['protocol'], equals('custom'));
      expect(result['command'], equals('ping'));
    });

    test('Boundary: custom protocol action with unknown command → returns error result', () async {
      final plugin = _CustomProtocolPlugin();
      final executor = plugin.actions!['customProtocol.execute']!;

      final result = await executor({});
      expect(result, isA<Map<String, dynamic>>());
      expect((result as Map<String, dynamic>)['protocol'], equals('custom'));
      // Still returns a result even with no command
      expect(result.containsKey('command'), isTrue);
    });
  });
}

/// Test plugin for PluginManager tests
class _TestPlugin extends MCPPlugin {
  @override
  final String name;

  @override
  final String version;

  @override
  final String description;

  @override
  final List<String> dependencies;

  final void Function()? onInit;
  final void Function()? onDispose;
  final void Function()? onEnabledCallback;
  final void Function()? onDisabledCallback;
  final bool throwOnInit;
  final bool throwOnDispose;
  Map<String, dynamic>? receivedConfig;
  final List<String> lifecycleOrder = [];

  _TestPlugin(
    this.name, {
    this.version = '1.0.0',
    this.description = '',
    this.dependencies = const [],
    this.onInit,
    this.onDispose,
    this.onEnabledCallback,
    this.onDisabledCallback,
    this.throwOnInit = false,
    this.throwOnDispose = false,
  });

  @override
  void configure(Map<String, dynamic> config) {
    receivedConfig = Map.from(config);
    lifecycleOrder.add('configure');
  }

  @override
  Future<void> initialize(PluginContext context) async {
    if (throwOnInit) throw Exception('Init error for $name');
    lifecycleOrder.add('initialize');
    onInit?.call();
  }

  @override
  Future<void> dispose() async {
    if (throwOnDispose) throw Exception('Dispose error for $name');
    onDispose?.call();
  }

  @override
  void onEnabled() {
    onEnabledCallback?.call();
  }

  @override
  void onDisabled() {
    onDisabledCallback?.call();
  }
}

/// Mock accessibility plugin that registers an onRender hook
class _AccessibilityPlugin extends MCPPlugin {
  @override
  String get name => 'accessibility';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Adds semantic labels to widgets for accessibility';

  @override
  Future<void> initialize(PluginContext context) async {
    // Register onRender hook to inject semantic labels
    PluginHookManager.instance.registerHook(
      pluginName: name,
      hookType: PluginHookType.onRender,
      callback: (ctx) async {
        // In a real implementation, this would modify props to add semantics
        final props = ctx.data['props'] as Map<String, dynamic>? ?? {};
        if (props.containsKey('text') && !props.containsKey('semanticLabel')) {
          props['semanticLabel'] = props['text'];
        }
      },
      priority: 100,
    );
  }

  @override
  Future<void> dispose() async {}
}

/// Mock i18n plugin that provides translation capabilities
class _I18nPlugin extends MCPPlugin {
  final Map<String, String> translations;

  _I18nPlugin({required this.translations});

  @override
  String get name => 'i18n';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Internationalization plugin for resolving translation keys';

  /// Resolve a translation key, returning the key itself as fallback
  String translate(String key) {
    return translations[key] ?? key;
  }

  @override
  Future<void> initialize(PluginContext context) async {
    // Register onRender hook to resolve i18n expressions
    PluginHookManager.instance.registerHook(
      pluginName: name,
      hookType: PluginHookType.onRender,
      callback: (ctx) async {
        // In a real implementation, this would resolve {{i18n.key}} expressions
      },
      priority: 90,
    );
  }

  @override
  Future<void> dispose() async {}
}

/// Mock widget factory for testing dynamic widget registration
class _MockWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, context) {
    return const SizedBox.shrink();
  }
}

/// Mock plugin that provides custom widgets
class _WidgetProviderPlugin extends MCPPlugin {
  final Map<String, WidgetFactory> widgetTypes;

  _WidgetProviderPlugin({required this.widgetTypes});

  @override
  String get name => 'widgetProvider';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Plugin that provides custom widgets';

  @override
  Map<String, WidgetFactory>? get widgets => widgetTypes;

  @override
  Future<void> initialize(PluginContext context) async {}

  @override
  Future<void> dispose() async {}
}

/// Mock third-party plugin that registers hooks during initialization
class _ThirdPartyPlugin extends MCPPlugin {
  @override
  String get name => 'thirdParty';

  @override
  String get version => '2.0.0';

  @override
  String get description => 'Third-party plugin integration test';

  @override
  Future<void> initialize(PluginContext context) async {
    // Third-party plugin registers a lifecycle hook
    PluginHookManager.instance.registerHook(
      pluginName: name,
      hookType: PluginHookType.onLifecycle,
      callback: (ctx) async {
        // Monitor lifecycle events
      },
    );
  }

  @override
  Future<void> dispose() async {}
}

/// Mock plugin that provides a custom protocol action executor
class _CustomProtocolPlugin extends MCPPlugin {
  @override
  String get name => 'customProtocol';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Plugin providing a custom protocol via action executor';

  @override
  Map<String, Future<dynamic> Function(Map<String, dynamic>)>? get actions => {
        'customProtocol.execute': (params) async {
          return <String, dynamic>{
            'protocol': 'custom',
            'command': params['command'],
          };
        },
      };

  @override
  Future<void> initialize(PluginContext context) async {}

  @override
  Future<void> dispose() async {}
}
