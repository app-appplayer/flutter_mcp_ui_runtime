// PluginManager — loading, dependency order, and what happens when a plugin
// misbehaves.
//
// A plugin is how a host adds widgets, actions and services to a running
// runtime, so every failure here is a host-level one: a widget type that a
// document declares and the registry has never heard of, or a timer still
// running after the document that started it is gone. The uncovered part was
// all of it after the happy path — dependencies, cycles, refusals, and the
// unregistration side of every registration.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/core/service_locator.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/plugins/plugin_system.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/widgets/widget_factory.dart';
import 'package:flutter_test/flutter_test.dart';

/// A plugin that records what the manager did to it.
class _TestPlugin extends MCPPlugin {
  _TestPlugin(
    this.name, {
    this.dependencies = const [],
    this.widgets,
    this.actions,
    this.failOnInit = false,
    this.failOnDispose = false,
  });

  @override
  final String name;

  @override
  String get version => '1.0.0';

  @override
  String get description => 'test plugin $name';

  @override
  final List<String> dependencies;

  @override
  final Map<String, WidgetFactory>? widgets;

  @override
  final Map<String, Future<dynamic> Function(Map<String, dynamic>)>? actions;

  final bool failOnInit;
  final bool failOnDispose;

  final List<String> events = [];
  Map<String, dynamic>? seenConfig;
  PluginContext? seenContext;

  @override
  void configure(Map<String, dynamic> config) {
    seenConfig = config;
    events.add('configure');
  }

  @override
  Future<void> initialize(PluginContext context) async {
    seenContext = context;
    events.add('initialize');
    if (failOnInit) throw StateError('this plugin cannot start');
  }

  @override
  Future<void> dispose() async {
    events.add('dispose');
    if (failOnDispose) throw StateError('this plugin cannot stop');
  }

  @override
  void onEnabled() => events.add('onEnabled');

  @override
  void onDisabled() => events.add('onDisabled');
}

/// A plugin that overrides nothing beyond the required members: its
/// description and `configure` come from the base class, which is what a
/// plugin written from the README looks like.
class _BarePlugin extends MCPPlugin {
  @override
  String get name => 'bare';

  @override
  String get version => '0.1.0';

  @override
  Future<void> initialize(PluginContext context) async {}

  @override
  Future<void> dispose() async {}
}

/// A service a plugin contributes to the locator.
class _CountingService extends BaseService {
  int initialisations = 0;

  @override
  Future<void> onInitialize() async => initialisations++;

  @override
  Future<void> onDispose() async {}
}

class _ServicePlugin extends MCPPlugin {
  _ServicePlugin(this.service);

  final _CountingService service;

  @override
  String get name => 'with-services';

  @override
  String get version => '1.0.0';

  @override
  Map<Type, Service> get services => {_CountingService: service};

  @override
  Future<void> initialize(PluginContext context) async {}

  @override
  Future<void> dispose() async {}
}

class _MarkerFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) =>
      const Text('from the plugin');
}

void main() {
  late PluginManager manager;
  late WidgetRegistry widgetRegistry;
  late ActionHandler actionHandler;

  setUp(() {
    PluginManager.resetInstance();
    manager = PluginManager.instance;
    widgetRegistry = WidgetRegistry();
    actionHandler = ActionHandler();
    manager.initialize(
      stateManager: StateManager()..initialize(<String, dynamic>{}),
      serviceLocator: ServiceLocator.instance,
      widgetRegistry: widgetRegistry,
      actionHandler: actionHandler,
    );
  });

  tearDown(PluginManager.resetInstance);

  group('registering', () {
    test('a registered plugin is known but not yet loaded', () async {
      await manager.registerPlugin(_TestPlugin('alpha'));

      expect(manager.isPluginLoaded('alpha'), isFalse,
          reason: 'registering is declaring it exists; loading is what makes '
              'its widgets reachable');
      expect(manager.getPluginInfo('alpha')!.version, '1.0.0');
    });

    test('the same name twice is refused rather than silently replaced',
        () async {
      await manager.registerPlugin(_TestPlugin('alpha'));

      await expectLater(
        manager.registerPlugin(_TestPlugin('alpha')),
        throwsA(isA<PluginException>()),
        reason: 'a second plugin taking the first one\'s name would take its '
            'widget types with it',
      );
    });

    test('info for an unknown plugin is null, not an error', () {
      expect(manager.getPluginInfo('nobody'), isNull);
    });

    test('getAllPluginInfos counts what each plugin contributes', () async {
      await manager.registerPlugin(_TestPlugin(
        'alpha',
        widgets: {'alphaWidget': _MarkerFactory()},
        actions: {'alphaAction': (params) async => 1},
      ));

      final info = manager.getAllPluginInfos().single;
      expect(info.name, 'alpha');
      expect(info.widgetCount, 1);
      expect(info.actionCount, 1);
      expect(info.serviceCount, 0);
      expect(info.isLoaded, isFalse);
      expect(info.toJson()['description'], 'test plugin alpha');
    });
  });

  group('loading', () {
    test('a loaded plugin\'s widget type becomes renderable', () async {
      await manager.registerPlugin(
          _TestPlugin('alpha', widgets: {'alphaWidget': _MarkerFactory()}));

      expect(widgetRegistry.get('alphaWidget'), isNull);
      await manager.loadPlugin('alpha');

      expect(widgetRegistry.get('alphaWidget'), isNotNull,
          reason: 'this is the whole point of a plugin — a document declaring '
              '`alphaWidget` has to find a factory');
      expect(manager.isPluginLoaded('alpha'), isTrue);
    });

    test('a loaded plugin\'s action becomes callable', () async {
      await manager.registerPlugin(_TestPlugin('alpha',
          actions: {'alphaAction': (params) async => {'ok': params['n']}}));
      await manager.loadPlugin('alpha');

      final executor = actionHandler.toolExecutors['alphaAction'];
      expect(executor, isNotNull,
          reason: 'a registered action a document cannot call is a capability '
              'that exists only in the plugin\'s own manifest');
      expect(await executor!({'n': 7}), {'ok': 7});
    });

    test('configure runs before initialize, with the config set beforehand',
        () async {
      final plugin = _TestPlugin('alpha');
      manager.setPluginConfig('alpha', {'endpoint': 'https://example.test'});
      await manager.registerPlugin(plugin);
      await manager.loadPlugin('alpha');

      expect(plugin.seenConfig, {'endpoint': 'https://example.test'});
      expect(plugin.events.take(2), ['configure', 'initialize'],
          reason: 'a plugin configured after it starts has already made its '
              'connections with the wrong settings');
      expect(plugin.events, contains('onEnabled'));
    });

    test('the plugin is handed the runtime it is extending', () async {
      final plugin = _TestPlugin('alpha');
      await manager.registerPlugin(plugin);
      await manager.loadPlugin('alpha');

      expect(plugin.seenContext!.widgetRegistry, same(widgetRegistry));
      expect(plugin.seenContext!.actionHandler, same(actionHandler));
    });

    test('loading twice is a no-op, not a second registration', () async {
      final plugin = _TestPlugin('alpha');
      await manager.registerPlugin(plugin);
      await manager.loadPlugin('alpha');
      await manager.loadPlugin('alpha');

      expect(plugin.events.where((e) => e == 'initialize').length, 1);
    });

    test('an unknown plugin is refused', () async {
      await expectLater(
        manager.loadPlugin('nobody'),
        throwsA(isA<PluginException>()),
      );
    });

    test('a plugin that fails to start says so, and stays unloaded', () async {
      await manager.registerPlugin(_TestPlugin('alpha', failOnInit: true));

      await expectLater(
        manager.loadPlugin('alpha'),
        throwsA(isA<PluginException>()),
      );
      expect(manager.isPluginLoaded('alpha'), isFalse,
          reason: 'a plugin marked loaded after a failed initialize would be '
              'unloaded later, disposing something that never started');
    });
  });

  group('dependencies', () {
    test('a dependency is loaded first, without being asked for', () async {
      final base = _TestPlugin('base');
      final dependent = _TestPlugin('dependent', dependencies: ['base']);
      await manager.registerPlugin(base);
      await manager.registerPlugin(dependent);

      await manager.loadPlugin('dependent');

      expect(manager.isPluginLoaded('base'), isTrue,
          reason: 'a plugin whose dependency is missing fails at the first '
              'call, not at load time, which is much harder to read');
    });

    test('loadAllPlugins loads in dependency order', () async {
      // Registered in the wrong order on purpose.
      await manager.registerPlugin(_TestPlugin('c', dependencies: ['b']));
      await manager.registerPlugin(_TestPlugin('b', dependencies: ['a']));
      await manager.registerPlugin(_TestPlugin('a'));

      await manager.loadAllPlugins();

      expect(manager.getAllPluginInfos().every((p) => p.isLoaded), isTrue);
    });

    test('a circular dependency is reported, not looped over', () async {
      await manager.registerPlugin(_TestPlugin('x', dependencies: ['y']));
      await manager.registerPlugin(_TestPlugin('y', dependencies: ['x']));

      await expectLater(
        manager.loadAllPlugins(),
        throwsA(isA<PluginException>()),
        reason: 'the alternative is a stack overflow with no name in it',
      );
    });

    test('a dependency the manager does not have is skipped by the sort',
        () async {
      // The sort only visits plugins it knows; loadPlugin is what reports the
      // missing one, and it has to report rather than hang.
      await manager.registerPlugin(_TestPlugin('alpha', dependencies: ['gone']));

      await expectLater(
        manager.loadAllPlugins(),
        throwsA(isA<PluginException>()),
      );
    });
  });

  group('unloading', () {
    test('everything the plugin registered is taken back out', () async {
      await manager.registerPlugin(_TestPlugin(
        'alpha',
        widgets: {'alphaWidget': _MarkerFactory()},
        actions: {'alphaAction': (params) async => 1},
      ));
      await manager.loadPlugin('alpha');
      await manager.unloadPlugin('alpha');

      expect(widgetRegistry.get('alphaWidget'), isNull,
          reason: 'a widget type left registered by an unloaded plugin builds '
              'from a factory whose plugin has been disposed');
      expect(actionHandler.toolExecutors.containsKey('alphaAction'), isFalse);
      expect(manager.isPluginLoaded('alpha'), isFalse);
    });

    test('the disabled hook and dispose both run', () async {
      final plugin = _TestPlugin('alpha');
      await manager.registerPlugin(plugin);
      await manager.loadPlugin('alpha');
      await manager.unloadPlugin('alpha');

      expect(plugin.events, containsAllInOrder(['onDisabled', 'dispose']));
    });

    test('a plugin something else depends on cannot be pulled out from under it',
        () async {
      await manager.registerPlugin(_TestPlugin('base'));
      await manager.registerPlugin(_TestPlugin('dependent', dependencies: ['base']));
      await manager.loadPlugin('dependent');

      await expectLater(
        manager.unloadPlugin('base'),
        throwsA(isA<PluginException>()),
        reason: 'unloading it would leave the dependent plugin calling into a '
            'disposed one',
      );
    });

    test('unloading what was never loaded is a no-op', () async {
      final plugin = _TestPlugin('alpha');
      await manager.registerPlugin(plugin);
      await manager.unloadPlugin('alpha');

      expect(plugin.events, isEmpty);
    });

    test('unloading an unknown plugin is refused', () async {
      await expectLater(
        manager.unloadPlugin('nobody'),
        throwsA(isA<PluginException>()),
      );
    });

    test('a plugin that throws on dispose is reported', () async {
      await manager.registerPlugin(_TestPlugin('alpha', failOnDispose: true));
      await manager.loadPlugin('alpha');

      await expectLater(
        manager.unloadPlugin('alpha'),
        throwsA(isA<PluginException>()),
      );
    });

    test('one plugin failing to unload does not strand the rest', () async {
      await manager.registerPlugin(_TestPlugin('first'));
      await manager.registerPlugin(
          _TestPlugin('second', failOnDispose: true));
      final third = _TestPlugin('third');
      await manager.registerPlugin(third);
      await manager.loadAllPlugins();

      await manager.unloadAllPlugins();

      expect(third.events, contains('dispose'));
      expect(manager.getAllPluginInfos().every((p) => !p.isLoaded), isTrue,
          reason: 'the failing plugin is not coming back — leaving it in the '
              'load order would stop every future shutdown on the same one');
    });

    test('unloadAllPlugins unwinds in reverse load order', () async {
      final order = <String>[];
      final a = _TestPlugin('a');
      final b = _TestPlugin('b', dependencies: ['a']);
      await manager.registerPlugin(a);
      await manager.registerPlugin(b);
      await manager.loadAllPlugins();

      // `b` depends on `a`, so unloading `a` first would be refused — reverse
      // order is what makes the shutdown legal at all.
      await manager.unloadAllPlugins();
      for (final p in [a, b]) {
        if (p.events.contains('dispose')) order.add(p.name);
      }

      expect(order, ['a', 'b'],
          reason: 'both came down; the order is what allowed it');
    });
  });

  group('a plugin written from the README', () {
    test('takes its description and configure from the base class', () async {
      final plugin = _BarePlugin();
      await manager.registerPlugin(plugin);

      expect(manager.getPluginInfo('bare')!.description, '',
          reason: 'a plugin that declares no description has none, rather '
              'than failing to register');

      // `configure` is a no-op the base class supplies; a plugin that does
      // not want settings must not have to write an empty override.
      manager.setPluginConfig('bare', {'anything': true});
      await manager.loadPlugin('bare');

      expect(manager.isPluginLoaded('bare'), isTrue);
    });
  });

  group('services a plugin contributes', () {
    test('are registered into the locator and taken back out', () async {
      final service = _CountingService();
      await manager.registerPlugin(_ServicePlugin(service));

      await manager.loadPlugin('with-services');
      expect(ServiceLocator.instance.isRegistered<_CountingService>(), isTrue,
          reason: 'a service a plugin declares and never registers is a '
              'capability the rest of the runtime cannot find');

      await manager.unloadPlugin('with-services');
      expect(ServiceLocator.instance.isRegistered<_CountingService>(), isFalse,
          reason: 'a service left behind by an unloaded plugin is answered by '
              'an object whose plugin has been disposed');
    });

    test('its info counts them', () async {
      await manager.registerPlugin(_ServicePlugin(_CountingService()));

      expect(manager.getPluginInfo('with-services')!.serviceCount, 1);
    });
  });

  group('the example plugin that ships with the package', () {
    testWidgets('loads, renders its widget and runs its action',
        (tester) async {
      await manager.registerPlugin(ExamplePlugin());
      // The example's `initialize` waits on a real timer, which a widget
      // test's fake clock never delivers.
      await tester.runAsync(() => manager.loadPlugin('example'));

      expect(manager.getPluginInfo('example')!.description, isNotEmpty);

      final factory = widgetRegistry.get('ExampleWidget')!;
      final stateManager = StateManager()..initialize(<String, dynamic>{});
      final bindingEngine = BindingEngine();
      final context = RenderContext(
        renderer: Renderer(
          widgetRegistry: widgetRegistry,
          bindingEngine: bindingEngine,
          actionHandler: actionHandler,
          stateManager: stateManager,
        ),
        stateManager: stateManager,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        themeManager: ThemeManager.instance,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: factory.build({'type': 'ExampleWidget', 'text': 'Hello'}, context),
        ),
      ));

      expect(find.text('Hello'), findsOneWidget,
          reason: 'the example is the first thing anyone writing a plugin '
              'copies; a broken one is a broken starting point');

      final action = actionHandler.toolExecutors['exampleAction']!;
      final result = await action({'n': 1}) as Map;
      expect(result['result'], contains('executed'));
      expect(result['params'], {'n': 1});

      await tester.runAsync(() => manager.unloadPlugin('example'));
      expect(widgetRegistry.get('ExampleWidget'), isNull);
    });

    testWidgets('its widget has a default label', (tester) async {
      await manager.registerPlugin(ExamplePlugin());
      await tester.runAsync(() => manager.loadPlugin('example'));

      final factory = widgetRegistry.get('ExampleWidget')!;
      final stateManager = StateManager()..initialize(<String, dynamic>{});
      final bindingEngine = BindingEngine();
      final context = RenderContext(
        renderer: Renderer(
          widgetRegistry: widgetRegistry,
          bindingEngine: bindingEngine,
          actionHandler: actionHandler,
          stateManager: stateManager,
        ),
        stateManager: stateManager,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        themeManager: ThemeManager.instance,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: factory.build({'type': 'ExampleWidget'}, context),
        ),
      ));

      expect(find.text('Example Widget'), findsOneWidget);
    });
  });
}
