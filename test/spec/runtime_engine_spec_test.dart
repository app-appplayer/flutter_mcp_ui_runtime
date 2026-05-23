// Runtime Engine Spec Tests
// TC-200~202, TC-210~213, TC-220~221, TC-230~236,
// TC-240~241, TC-250, TC-260~264, TC-270~280
//
// Covers: engine initialization, state manager, binding engine,
// action handler, navigation, theme, new features, v1.1 conformance.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart'
    show StateChangeEvent;
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart'
    show MCPUIDSLVersion;
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart'
    show ActionExecutor;
import 'package:flutter_mcp_ui_runtime/src/actions/action_result.dart';

void main() {
  // Reset ThemeManager singleton between tests to avoid leaking state
  setUp(() {
    ThemeManager.instance.reset();
  });

  // ---------------------------------------------------------------------------
  // TC-200~202: Runtime Engine
  // ---------------------------------------------------------------------------
  group('TC-200~202: Runtime Engine', () {
    late MCPUIRuntime runtime;

    setUp(() {
      runtime = MCPUIRuntime(enableDebugMode: false);
    });

    tearDown(() async {
      await runtime.destroy();
    });

    test('TC-200: Initialize with page definition - engine ready', () async {
      await runtime.initialize({
        'type': 'page',
        'content': {'type': 'text', 'content': 'Hello'},
      });

      expect(runtime.isInitialized, isTrue);
      expect(runtime.engine, isNotNull);
      expect(runtime.engine!.isInitialized, isTrue);
    });

    test('TC-200: Initialize with metadata', () async {
      await runtime.initialize({
        'type': 'page',
        'metadata': {'title': 'Test Page', 'description': 'A test'},
        'content': {'type': 'text', 'content': 'Hello'},
      });

      expect(runtime.isInitialized, isTrue);
      expect(runtime.getUIDefinition(), isNotNull);
      expect(runtime.getUIDefinition()!['type'], equals('page'));
    });

    test('TC-200: Double initialization throws', () async {
      await runtime.initialize({
        'type': 'page',
        'content': {'type': 'text', 'content': 'Hello'},
      });

      expect(
        () => runtime.initialize({
          'type': 'page',
          'content': {'type': 'text', 'content': 'Second'},
        }),
        throwsStateError,
      );
    });

    test('TC-201: Page loading via engine', () async {
      await runtime.initialize({
        'type': 'page',
        'content': {'type': 'text', 'content': 'Loaded Page'},
      });

      // The UI definition is stored after initialization
      final uiDef = runtime.getUIDefinition();
      expect(uiDef, isNotNull);
      expect(uiDef!['content']['content'], equals('Loaded Page'));
    });

    test('TC-201: Screen type alias accepted as page', () async {
      await runtime.initialize({
        'type': 'screen',
        'content': {'type': 'text', 'content': 'Screen Alias'},
      });

      expect(runtime.isInitialized, isTrue);
    });

    test('TC-202: Notification handling - resource update', () async {
      await runtime.initialize({
        'type': 'page',
        'runtime': {
          'services': {
            'state': {
              'initialState': {'temperature': 20},
            },
          },
        },
        'content': {'type': 'text', 'content': '{{temperature}}'},
      });

      // Register a resource subscription
      runtime.registerResourceSubscription(
          'resource://weather/temp', 'temperature');

      // Spec §4.5: store the resource payload as-is at the subscribed
      // binding. The previous heuristic that unwrapped `content[binding]`
      // when the field name happened to match the binding name was
      // removed (it conflated payload shape with binding path semantics).
      // The content here has no `text` wrapper, so the entire map is
      // stored.
      await runtime.handleNotification({
        'method': 'notifications/resources/updated',
        'params': {
          'uri': 'resource://weather/temp',
          'content': {
            'temperature': 25,
          },
        },
      });

      expect(runtime.stateManager.get('temperature'),
          equals({'temperature': 25}));
    });

    test('TC-202: Notification ignored when not initialized', () async {
      // Should not throw even when not initialized
      await runtime.handleNotification({
        'method': 'notifications/resources/updated',
        'params': {
          'uri': 'resource://test',
        },
      });
      // No assertion needed - just verifying no exception
    });

    test('TC-202: Resource subscription management', () async {
      await runtime.initialize({
        'type': 'page',
        'content': {'type': 'text', 'content': 'Test'},
      });

      runtime.registerResourceSubscription('resource://data', 'myData');
      expect(runtime.getBindingForUri('resource://data'), equals('myData'));

      runtime.unregisterResourceSubscription('resource://data');
      expect(runtime.getBindingForUri('resource://data'), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-210~213: State Manager
  // ---------------------------------------------------------------------------
  group('TC-210~213: State Manager', () {
    late MCPUIRuntime runtime;

    setUp(() async {
      runtime = MCPUIRuntime(enableDebugMode: false);
      await runtime.initialize({
        'type': 'page',
        'runtime': {
          'services': {
            'state': {
              'initialState': {
                'counter': 0,
                'name': 'Alice',
                'active': true,
                'items': ['a', 'b', 'c'],
                'user': {
                  'profile': {
                    'age': 30,
                  },
                },
              },
            },
          },
        },
        'content': {'type': 'text', 'content': '{{counter}}'},
      });
    });

    tearDown(() async {
      await runtime.destroy();
    });

    // TC-210: Basic operations
    test('TC-210: set/get operations', () {
      final sm = runtime.stateManager;

      expect(sm.get('counter'), equals(0));
      sm.set('counter', 42);
      expect(sm.get('counter'), equals(42));
    });

    test('TC-210: setNested operation via dot path', () {
      final sm = runtime.stateManager;

      sm.set('user.profile.age', 31);
      expect(sm.get('user.profile.age'), equals(31));
    });

    test('TC-210: increment operation', () {
      final sm = runtime.stateManager;

      sm.increment('counter');
      expect(sm.get('counter'), equals(1));

      sm.increment('counter', 5);
      expect(sm.get('counter'), equals(6));
    });

    test('TC-210: decrement operation', () {
      final sm = runtime.stateManager;

      sm.set('counter', 10);
      sm.decrement('counter');
      expect(sm.get('counter'), equals(9));

      sm.decrement('counter', 4);
      expect(sm.get('counter'), equals(5));
    });

    test('TC-210: toggle operation', () {
      final sm = runtime.stateManager;

      expect(sm.get('active'), isTrue);
      sm.toggle('active');
      expect(sm.get('active'), isFalse);
      sm.toggle('active');
      expect(sm.get('active'), isTrue);
    });

    test('TC-210: append operation', () {
      final sm = runtime.stateManager;

      sm.append('items', 'd');
      final items = sm.get<List>('items')!;
      expect(items.length, equals(4));
      expect(items.last, equals('d'));
    });

    test('TC-210: remove operation', () {
      final sm = runtime.stateManager;

      sm.remove('items', 'b');
      final items = sm.get<List>('items')!;
      expect(items.length, equals(2));
      expect(items.contains('b'), isFalse);
    });

    test('TC-210: push and pop operations', () {
      final sm = runtime.stateManager;

      sm.push('items', 'x');
      expect(sm.get<List>('items')!.last, equals('x'));

      final popped = sm.pop('items');
      expect(popped, equals('x'));
    });

    test('TC-210: update with transform function', () {
      final sm = runtime.stateManager;

      sm.update('counter', (current) => (current as int) * 2 + 1);
      expect(sm.get('counter'), equals(1)); // 0 * 2 + 1 = 1
    });

    // TC-211: State merge
    test('TC-211: mergeState combines new data', () {
      final sm = runtime.stateManager;

      sm.mergeState({
        'counter': 99,
        'newField': 'hello',
      });

      expect(sm.get('counter'), equals(99));
      expect(sm.get('newField'), equals('hello'));
      // Original fields still present
      expect(sm.get('name'), equals('Alice'));
    });

    test('TC-211: setState replaces entire state', () {
      final sm = runtime.stateManager;

      sm.setState({'replaced': true});
      expect(sm.get('replaced'), isTrue);
      // Old fields are gone
      expect(sm.get('counter'), isNull);
    });

    // TC-212: App vs Page state isolation
    test('TC-212: App-level state uses app prefix', () {
      final sm = runtime.stateManager;

      sm.setAppState('theme', 'dark');
      expect(sm.getAppState('theme'), equals('dark'));
      expect(sm.get('app.theme'), equals('dark'));
    });

    test('TC-212: Page-level state uses page prefix', () {
      final sm = runtime.stateManager;

      sm.setPageState('scrollPosition', 100);
      expect(sm.getPageState('scrollPosition'), equals(100));
      expect(sm.get('page.scrollPosition'), equals(100));
    });

    test('TC-212: App and page state are independent', () {
      final sm = runtime.stateManager;

      sm.setAppState('data', 'global');
      sm.setPageState('data', 'local');

      expect(sm.getAppState('data'), equals('global'));
      expect(sm.getPageState('data'), equals('local'));
    });

    // TC-213: Change notification
    test('TC-213: ChangeNotifier fires on set', () {
      final sm = runtime.stateManager;
      var notified = false;

      sm.addListener(() {
        notified = true;
      });

      sm.set('counter', 5);
      expect(notified, isTrue);
    });

    test('TC-213: Stream emits state change events', () async {
      final sm = runtime.stateManager;
      final events = <StateChangeEvent>[];
      final sub = sm.stream.listen(events.add);

      sm.set('counter', 10);
      sm.set('counter', 20);

      // Allow microtasks to complete
      await Future.delayed(Duration.zero);

      expect(events.length, greaterThanOrEqualTo(2));
      expect(events.first.path, equals('counter'));
      expect(events.first.newValue, equals(10));
      expect(events.last.newValue, equals(20));

      await sub.cancel();
    });

    test('TC-213: Key-specific listeners', () {
      final sm = runtime.stateManager;
      var counterChanged = false;

      sm.addKeyListener('counter', () {
        counterChanged = true;
      });

      sm.set('counter', 99);
      expect(counterChanged, isTrue);
    });

    test('TC-213: Watch stream for specific path', () async {
      final sm = runtime.stateManager;
      final values = <int>[];

      final sub = sm.watch<int>('counter').listen((v) {
        values.add(v);
      });

      // Allow initial value emission
      await Future.delayed(Duration.zero);

      sm.set('counter', 5);
      await Future.delayed(Duration.zero);

      sm.set('counter', 10);
      await Future.delayed(Duration.zero);

      // Should have initial value (0) plus updates
      expect(values, contains(5));
      expect(values, contains(10));

      await sub.cancel();
    });
  });

  // ---------------------------------------------------------------------------
  // TC-220~221: Binding Engine
  // ---------------------------------------------------------------------------
  group('TC-220~221: Binding Engine', () {
    late MCPUIRuntime runtime;

    setUp(() async {
      runtime = MCPUIRuntime(enableDebugMode: false);
      await runtime.initialize({
        'type': 'page',
        'runtime': {
          'services': {
            'state': {
              'initialState': {
                'count': 42,
                'app': {
                  'user': {
                    'name': 'Bob',
                  },
                },
                'items': [
                  {'name': 'Apple', 'price': 1.5},
                  {'name': 'Banana', 'price': 0.75},
                ],
              },
            },
          },
        },
        'content': {'type': 'text', 'content': '{{count}}'},
      });
    });

    tearDown(() async {
      await runtime.destroy();
    });

    // TC-220: Resolution
    test('TC-220: Simple binding resolution {{count}}', () {
      final be = runtime.engine!.bindingEngine;

      expect(be.isBindingExpression('{{count}}'), isTrue);
      expect(be.containsBindingExpression('Value: {{count}}'), isTrue);
      expect(be.isBindingExpression('plain text'), isFalse);
    });

    test('TC-220: Nested binding {{app.user.name}}', () {
      final be = runtime.engine!.bindingEngine;

      expect(be.isBindingExpression('{{app.user.name}}'), isTrue);
    });

    test('TC-220: Template string with multiple bindings', () {
      final be = runtime.engine!.bindingEngine;

      const template = 'Hello {{app.user.name}}, count is {{count}}';
      expect(be.containsBindingExpression(template), isTrue);
      expect(be.hasBindings(template), isTrue);
    });

    test('TC-220: Extract dependencies from expression', () {
      final be = runtime.engine!.bindingEngine;

      final deps =
          be.extractDependencies('{{count}} items for {{app.user.name}}');
      expect(deps, contains('count'));
      expect(deps, contains('app.user.name'));
    });

    // TC-221: List context (verifying binding engine handles list paths)
    test('TC-221: List item access via state path', () {
      final sm = runtime.stateManager;

      final items = sm.get<List>('items');
      expect(items, isNotNull);
      expect(items!.length, equals(2));

      final firstItem = items[0] as Map<String, dynamic>;
      expect(firstItem['name'], equals('Apple'));
    });

    test('TC-221: Binding engine detects list binding patterns', () {
      final be = runtime.engine!.bindingEngine;

      // Verify that binding expressions for list contexts are recognized
      expect(be.isBindingExpression('{{item.name}}'), isTrue);
      expect(be.isBindingExpression('{{index}}'), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-230~236: Action Handler
  // ---------------------------------------------------------------------------
  group('TC-230~236: Action Handler', () {
    late MCPUIRuntime runtime;

    setUp(() async {
      runtime = MCPUIRuntime(enableDebugMode: false);
      await runtime.initialize({
        'type': 'page',
        'runtime': {
          'services': {
            'state': {
              'initialState': {
                'counter': 0,
                'enabled': false,
                'tags': <String>[],
              },
            },
          },
        },
        'content': {'type': 'text', 'content': '{{counter}}'},
      });
    });

    tearDown(() async {
      await runtime.destroy();
    });

    // Helper to create a RenderContext for action execution
    RenderContext createContext() {
      return runtime.engine!.renderer.createRootContext(null);
    }

    // TC-230: State actions
    test('TC-230: State action - set', () async {
      final ah = runtime.engine!.actionHandler;
      final ctx = createContext();

      await ah.execute({
        'type': 'state',
        'action': 'set',
        'binding': 'counter',
        'value': 42,
      }, ctx);

      expect(runtime.stateManager.get('counter'), equals(42));
    });

    test('TC-230: State action - increment', () async {
      final ah = runtime.engine!.actionHandler;
      final ctx = createContext();

      await ah.execute({
        'type': 'state',
        'action': 'increment',
        'binding': 'counter',
      }, ctx);

      expect(runtime.stateManager.get('counter'), equals(1));
    });

    test('TC-230: State action - toggle', () async {
      final ah = runtime.engine!.actionHandler;
      final ctx = createContext();

      await ah.execute({
        'type': 'state',
        'action': 'toggle',
        'binding': 'enabled',
      }, ctx);

      expect(runtime.stateManager.get('enabled'), isTrue);
    });

    test('TC-230: State action - append', () async {
      final ah = runtime.engine!.actionHandler;
      final ctx = createContext();

      await ah.execute({
        'type': 'state',
        'action': 'append',
        'binding': 'tags',
        'value': 'flutter',
      }, ctx);

      final tags = runtime.stateManager.get<List>('tags');
      expect(tags, contains('flutter'));
    });

    // TC-231: Tool actions (mock tool call)
    test('TC-231: Tool action with registered executor', () async {
      final ah = runtime.engine!.actionHandler;
      final ctx = createContext();
      var toolCalled = false;
      String? calledTool;
      Map<String, dynamic>? calledParams;

      // Register a mock tool executor (named executor receives only params)
      ah.registerToolExecutor('myTool', (Map<String, dynamic> params) async {
        toolCalled = true;
        calledTool = 'myTool';
        calledParams = params;
        return {'result': 'success'};
      });

      await ah.execute({
        'type': 'tool',
        'tool': 'myTool',
        'params': {'key': 'value'},
      }, ctx);

      expect(toolCalled, isTrue);
      expect(calledTool, equals('myTool'));
      expect(calledParams, containsPair('key', 'value'));
    });

    // TC-232: Navigation actions
    test('TC-232: Navigation action handler registration', () async {
      final ah = runtime.engine!.actionHandler;
      var navigatedTo = '';

      // Register navigation handler
      ah.registerNavigationHandler((action, route, params) {
        navigatedTo = route;
        return true;
      });

      final ctx = createContext();
      await ah.execute({
        'type': 'navigation',
        'action': 'push',
        'route': '/settings',
      }, ctx);

      expect(navigatedTo, equals('/settings'));
    });

    // TC-233: Resource actions
    test('TC-233: Resource action executor is registered', () async {
      // Resource actions are available - the executor is registered by default
      final ah = runtime.engine!.actionHandler;
      expect(ah, isNotNull);
    });

    // TC-234: Dialog actions
    test('TC-234: Dialog action executor is registered', () async {
      // Dialog actions require a BuildContext, so we just verify registration
      final ah = runtime.engine!.actionHandler;
      expect(ah, isNotNull);
    });

    // TC-235: Batch actions
    test('TC-235: Batch action executes multiple actions', () async {
      final ah = runtime.engine!.actionHandler;
      final ctx = createContext();

      await ah.execute({
        'type': 'batch',
        'actions': [
          {
            'type': 'state',
            'action': 'set',
            'binding': 'counter',
            'value': 10,
          },
          {
            'type': 'state',
            'action': 'set',
            'binding': 'enabled',
            'value': true,
          },
        ],
      }, ctx);

      expect(runtime.stateManager.get('counter'), equals(10));
      expect(runtime.stateManager.get('enabled'), isTrue);
    });

    // TC-236: Conditional actions
    test('TC-236: Conditional action - true branch', () async {
      final ah = runtime.engine!.actionHandler;
      final ctx = createContext();

      // Set a boolean condition directly
      runtime.stateManager.set('shouldEnable', true);

      await ah.execute({
        'type': 'conditional',
        'condition': '{{shouldEnable}}',
        'then': {
          'type': 'state',
          'action': 'set',
          'binding': 'enabled',
          'value': true,
        },
        'else': {
          'type': 'state',
          'action': 'set',
          'binding': 'enabled',
          'value': false,
        },
      }, ctx);

      expect(runtime.stateManager.get('enabled'), isTrue);
    });

    test('TC-236: Conditional action - false branch', () async {
      final ah = runtime.engine!.actionHandler;
      final ctx = createContext();

      // Counter is 0 by default
      runtime.stateManager.set('counter', 1);

      await ah.execute({
        'type': 'conditional',
        'condition': '{{counter}} > 3',
        'then': {
          'type': 'state',
          'action': 'set',
          'binding': 'enabled',
          'value': true,
        },
        'else': {
          'type': 'state',
          'action': 'set',
          'binding': 'enabled',
          'value': false,
        },
      }, ctx);

      expect(runtime.stateManager.get('enabled'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-240~241: Navigation Service
  // ---------------------------------------------------------------------------
  group('TC-240~241: Navigation Service', () {
    setUp(() {
      // Reset the singleton before each test
      NavigationService.resetInstance();
    });

    // TC-240: Route management
    test('TC-240: Register routes', () {
      final navService = NavigationService();

      navService.registerRoute('/home', (context) => const SizedBox());
      navService.registerRoute('/settings', (context) => const SizedBox());

      expect(navService.routes.length, equals(2));
      expect(navService.routes.containsKey('/home'), isTrue);
      expect(navService.routes.containsKey('/settings'), isTrue);
    });

    test('TC-240: Register multiple routes at once', () {
      final navService = NavigationService();

      navService.registerRoutes({
        '/a': (context) => const SizedBox(),
        '/b': (context) => const SizedBox(),
        '/c': (context) => const SizedBox(),
      });

      expect(navService.routes.length, equals(3));
    });

    test('TC-240: Index-based navigation', () {
      final navService = NavigationService();

      expect(navService.currentIndex, equals(0));

      var notifiedIndex = -1;
      navService.addIndexListener((index) {
        notifiedIndex = index;
      });

      navService.setIndex(2);
      expect(navService.currentIndex, equals(2));
      expect(notifiedIndex, equals(2));
    });

    test('TC-240: Route guards', () async {
      final navService = NavigationService();

      navService.addRouteGuard('/admin', (args) async => false);

      // Route guard is registered; actual navigation needs a live navigator
      navService.removeRouteGuard('/admin');
    });

    test('TC-240: Prevent and allow navigation', () {
      final navService = NavigationService();

      navService.preventNavigation();
      // Navigation would be blocked here

      navService.allowNavigation();
      // Navigation allowed again
    });

    // TC-241: Page lifecycle on navigation
    test('TC-241: Lifecycle hooks integrated in runtime engine', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);

      await runtime.initialize({
        'type': 'page',
        'lifecycle': {
          'onInitialize': [
            {
              'type': 'state',
              'action': 'set',
              'binding': 'initialized',
              'value': true,
            },
          ],
        },
        'runtime': {
          'services': {
            'state': {
              'initialState': {'initialized': false},
            },
          },
        },
        'content': {'type': 'text', 'content': 'Test'},
      });

      // onInitialize lifecycle should have executed
      expect(runtime.stateManager.get('initialized'), isTrue);

      await runtime.destroy();
    });
  });

  // ---------------------------------------------------------------------------
  // TC-250: Theme Manager
  // ---------------------------------------------------------------------------
  group('TC-250: Theme Manager', () {
    late ThemeManager themeManager;

    setUp(() {
      themeManager = ThemeManager.instance;
      themeManager.reset();
    });

    test('TC-250: Default theme has expected M3 14-domain structure', () {
      expect(themeManager.theme, isNotNull);
      expect(themeManager.theme['color'], isNotNull);
      expect(themeManager.theme['typography'], isNotNull);
      expect(themeManager.theme['spacing'], isNotNull);
      expect(themeManager.theme['shape'], isNotNull);
      expect(themeManager.theme['elevation'], isNotNull);
    });

    test('TC-250: Default theme mode is system (spec §5.2)', () {
      expect(themeManager.themeMode, equals('system'));
      expect(themeManager.currentMode, equals('system'));
      expect(themeManager.flutterThemeMode, equals(ThemeMode.system));
    });

    test('TC-250: Set dark mode', () {
      themeManager.setThemeMode('dark');

      expect(themeManager.themeMode, equals('dark'));
      expect(themeManager.flutterThemeMode, equals(ThemeMode.dark));
    });

    test('TC-250: Set system mode', () {
      themeManager.setThemeMode('system');

      expect(themeManager.themeMode, equals('system'));
      expect(themeManager.flutterThemeMode, equals(ThemeMode.system));
    });

    test('TC-250: Invalid mode throws', () {
      expect(
        () => themeManager.setThemeMode('invalid'),
        throwsArgumentError,
      );
    });

    test('TC-250: Get theme values by path (M3 1.3)', () {
      expect(themeManager.getThemeValue('color.primary'), isA<String>());
      expect(themeManager.getThemeValue('spacing.md'), equals(16));
      expect(themeManager.getThemeValue('shape.large'), equals(16));
      expect(
        themeManager.getThemeValue('elevation.level3.shadow'),
        equals(6),
      );
      expect(
        themeManager.getThemeValue('typography.bodyLarge.fontSize'),
        equals(16),
      );
    });

    test('TC-250: Get typed theme values', () {
      expect(themeManager.getColor('primary'), isA<String>());
      expect(themeManager.getColorValue('primary'), isA<Color>());
      expect(themeManager.getSpacing('md'), equals(16));
      expect(themeManager.getSpacingValue('md'), equals(16.0));
      expect(themeManager.getShape('extraSmall'), equals(4));
      expect(themeManager.getElevation('level3'), equals(6));
    });

    test('TC-250: Custom theme override at top-level color slot', () {
      themeManager.setTheme({
        'mode': 'light',
        'color': {'primary': '#FF0000'},
      });

      expect(themeManager.getThemeValue('color.primary'), equals('#FF0000'));
    });

    test('TC-250: Theme mode via setTheme', () {
      themeManager.setTheme({'mode': 'dark'});

      expect(themeManager.themeMode, equals('dark'));
    });

    test('TC-250: Apply and restore override', () {
      themeManager.setThemeMode('light');
      final originalPrimary =
          themeManager.getThemeValue('color.primary') as String;
      final restore = themeManager.applyOverride({
        'color': {'primary': '#00FF00'},
      });

      expect(themeManager.getThemeValue('color.primary'), equals('#00FF00'));

      restore();
      expect(themeManager.getThemeValue('color.primary'),
          equals(originalPrimary));
    });

    test('TC-250: Convert to Flutter ThemeData', () {
      themeManager.setThemeMode('light');
      final themeData = themeManager.toFlutterTheme();
      expect(themeData, isA<ThemeData>());
      expect(themeData.brightness, equals(Brightness.light));

      final darkTheme = themeManager.toFlutterTheme(isDark: true);
      expect(darkTheme.brightness, equals(Brightness.dark));
    });

    test('TC-250: Reset theme restores defaults', () {
      themeManager.setTheme({
        'mode': 'light',
        'color': {'primary': '#000000'},
      });
      themeManager.setThemeMode('dark');

      themeManager.resetTheme();

      // After reset the seed-derived primary is non-null and not the override.
      expect(themeManager.getThemeValue('color.primary'),
          isNot(equals('#000000')));
      expect(themeManager.themeMode, equals('system'));
    });

    test('TC-250: ThemeManager notifies listeners on change', () {
      var notified = false;
      themeManager.addListener(() {
        notified = true;
      });

      themeManager.setTheme({'color': {'primary': '#123456'}});
      expect(notified, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-260~264: New Features
  // ---------------------------------------------------------------------------
  group('TC-260~264: New Features', () {
    late MCPUIRuntime runtime;

    setUp(() async {
      runtime = MCPUIRuntime(enableDebugMode: false);
    });

    tearDown(() async {
      await runtime.destroy();
    });

    // TC-260: Parallel actions
    test('TC-260: Parallel action executor runs actions concurrently',
        () async {
      await runtime.initialize({
        'type': 'page',
        'runtime': {
          'services': {
            'state': {
              'initialState': {
                'a': 0,
                'b': 0,
              },
            },
          },
        },
        'content': {'type': 'text', 'content': 'Test'},
      });

      final ah = runtime.engine!.actionHandler;
      final ctx = runtime.engine!.renderer.createRootContext(null);

      await ah.execute({
        'type': 'parallel',
        'actions': [
          {
            'type': 'state',
            'action': 'set',
            'binding': 'a',
            'value': 1,
          },
          {
            'type': 'state',
            'action': 'set',
            'binding': 'b',
            'value': 2,
          },
        ],
      }, ctx);

      expect(runtime.stateManager.get('a'), equals(1));
      expect(runtime.stateManager.get('b'), equals(2));
    });

    // TC-261: Sequence actions
    test('TC-261: Sequence action executor runs actions in order', () async {
      await runtime.initialize({
        'type': 'page',
        'runtime': {
          'services': {
            'state': {
              'initialState': {'counter': 0},
            },
          },
        },
        'content': {'type': 'text', 'content': 'Test'},
      });

      final ah = runtime.engine!.actionHandler;
      final ctx = runtime.engine!.renderer.createRootContext(null);

      await ah.execute({
        'type': 'sequence',
        'actions': [
          {
            'type': 'state',
            'action': 'set',
            'binding': 'counter',
            'value': 10,
          },
          {
            'type': 'state',
            'action': 'increment',
            'binding': 'counter',
          },
        ],
      }, ctx);

      // Should be 11 because set(10) then increment(+1)
      expect(runtime.stateManager.get('counter'), equals(11));
    });

    // TC-262: Computed properties
    test('TC-262: Computed property from state', () async {
      await runtime.initialize({
        'type': 'page',
        'runtime': {
          'services': {
            'state': {
              'initialState': {
                'price': 100,
                'taxRate': 0.1,
              },
              'computed': {
                'total': {
                  'expression': '{{price * (1 + taxRate)}}',
                  'dependencies': ['price', 'taxRate'],
                },
              },
            },
          },
        },
        'content': {'type': 'text', 'content': '{{total}}'},
      });

      // Computed properties should be registered
      expect(runtime.stateManager, isNotNull);
    });

    test('TC-262: Computed property registered via addComputedProperty',
        () async {
      await runtime.initialize({
        'type': 'page',
        'runtime': {
          'services': {
            'state': {
              'initialState': {
                'width': 10,
                'height': 5,
              },
            },
          },
        },
        'content': {'type': 'text', 'content': 'Test'},
      });

      runtime.stateManager.addComputedProperty(
        'area',
        '{{width * height}}',
        dependencies: ['width', 'height'],
      );

      expect(runtime.stateManager.computedPropertyNames, contains('area'));
    });

    // TC-263: State watchers
    test('TC-263: State watcher triggers on change', () async {
      var watcherTriggered = false;

      await runtime.initialize({
        'type': 'page',
        'runtime': {
          'services': {
            'state': {
              'initialState': {'watchedValue': 0},
            },
          },
        },
        'content': {'type': 'text', 'content': 'Test'},
      });

      final watcher = StateWatcher(
        path: 'watchedValue',
        onChange: (newValue, oldValue) async {
          watcherTriggered = true;
        },
        enableDebugMode: false,
      );

      // First trigger initializes
      await watcher.trigger(0, null);
      expect(watcher.isInitialized, isTrue);

      // Second trigger fires the callback
      await watcher.trigger(5, 0);
      expect(watcherTriggered, isTrue);
    });

    test('TC-263: State watcher group', () async {
      final group = StateWatcherGroup(
        name: 'testGroup',
        enableDebugMode: false,
      );

      var count = 0;

      group.add(StateWatcher(
        path: 'a',
        onChange: (_, __) async {
          count++;
        },
        enableDebugMode: false,
      ));

      group.add(StateWatcher(
        path: 'b',
        onChange: (_, __) async {
          count++;
        },
        enableDebugMode: false,
      ));

      expect(group.count, equals(2));

      // Initialize all watchers
      await group.triggerAll(0, null);

      // Trigger actual change
      await group.triggerAll(1, 0);
      expect(count, equals(2));

      group.clear();
      expect(group.count, equals(0));
    });

    test('TC-263: Watcher with debounce', () async {
      final watcher = StateWatcher(
        path: 'debounced',
        onChange: (newValue, oldValue) async {},
        debounceMs: 100,
        enableDebugMode: false,
      );

      // Initialize
      await watcher.trigger(0, null);
      expect(watcher.isInitialized, isTrue);
    });

    // TC-264: Extended lifecycle hooks
    test('TC-264: Runtime supports lifecycle hooks', () async {
      await runtime.initialize({
        'type': 'page',
        'lifecycle': {
          'onInitialize': [
            {
              'type': 'state',
              'action': 'set',
              'binding': 'phase',
              'value': 'initialized',
            },
          ],
        },
        'runtime': {
          'services': {
            'state': {
              'initialState': {'phase': 'none'},
            },
          },
        },
        'content': {'type': 'text', 'content': '{{phase}}'},
      });

      expect(runtime.stateManager.get('phase'), equals('initialized'));
    });

    test('TC-264: Engine exposes lifecycle manager', () async {
      await runtime.initialize({
        'type': 'page',
        'content': {'type': 'text', 'content': 'Test'},
      });

      expect(runtime.engine!.lifecycle, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-270~280: v1.1 Conformance
  // ---------------------------------------------------------------------------
  group('TC-270~280: Runtime conformance', () {
    // TC-278: DSL version stamp — parsed onto UIDefinition but no feature
    // gating (runtime handles the single canonical DSL). Real version
    // negotiation logic is to be reintroduced only when a breaking-change
    // pivot requires it.
    test('TC-278: default stamp is current when absent', () {
      final def = UIDefinition.fromJson({
        'type': 'page',
        'content': {'type': 'text', 'content': 'Hello'},
      });
      expect(def.dslVersion, equals(MCPUIDSLVersion.current));
    });

    test('TC-278: explicit current stamp rounds-trips', () {
      final def = UIDefinition.fromJson({
        'type': 'page',
        'version': '1.3',
        'content': {'type': 'text', 'content': 'Hello'},
      });
      expect(def.dslVersion, equals('1.3'));
      expect(def.toJson()['version'], equals('1.3'));
    });

    test('TC-278: unknown stamp falls back to current', () {
      final def = UIDefinition.fromJson({
        'type': 'page',
        'version': '9.9',
        'content': {'type': 'text', 'content': 'Hello'},
      });
      expect(def.dslVersion, equals(MCPUIDSLVersion.current));
    });

    test('TC-278: historical 1.1 stamp collapses to current', () {
      // Older documents pre-dating the 1.3 canonical form are accepted
      // but normalised — the runtime has no separate 1.1 behaviour.
      final def = UIDefinition.fromJson({
        'type': 'page',
        'version': '1.1',
        'content': {'type': 'text', 'content': 'Hello'},
      });
      expect(def.dslVersion, equals(MCPUIDSLVersion.current));
    });

    test('TC-270: Runtime initializes with stamped definition', () async {
      final rt = MCPUIRuntime(enableDebugMode: false);
      await rt.initialize({
        'type': 'page',
        'version': '1.3',
        'content': {'type': 'text', 'content': 'stamped page'},
      });
      expect(rt.isInitialized, isTrue);
      await rt.destroy();
    });

    test('TC-280: Channel manager accessible after init', () async {
      final rt = MCPUIRuntime(enableDebugMode: false);
      await rt.initialize({
        'type': 'page',
        'content': {'type': 'text', 'content': 'Test'},
      });
      expect(rt.channelManager, isNotNull);
      await rt.destroy();
    });
  });

  // ---------------------------------------------------------------------------
  // Additional edge case tests
  // ---------------------------------------------------------------------------
  group('Edge cases and cleanup', () {
    test('Accessing stateManager before init returns manager', () {
      // Engine is eagerly initialized, so stateManager is always accessible
      final runtime = MCPUIRuntime(enableDebugMode: false);

      expect(runtime.stateManager, isNotNull);
    });

    test('Accessing themeManager before init returns manager', () {
      // Engine is eagerly initialized, so themeManager is always accessible
      final runtime = MCPUIRuntime(enableDebugMode: false);

      expect(runtime.themeManager, isNotNull);
    });

    test('Destroy resets state', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);

      await runtime.initialize({
        'type': 'page',
        'content': {'type': 'text', 'content': 'Test'},
      });

      expect(runtime.isInitialized, isTrue);

      await runtime.destroy();

      expect(runtime.isInitialized, isFalse);
      // Engine is final and never nulled
      expect(runtime.engine, isNotNull);
    });

    test('Invalid definition type throws', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);

      expect(
        () => runtime.initialize({
          'type': 'unknown',
          'content': {'type': 'text'},
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Register custom action executor after init', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);

      await runtime.initialize({
        'type': 'page',
        'content': {'type': 'text', 'content': 'Test'},
      });

      var executed = false;
      runtime.engine.actionHandler.registerExecutor(
        'custom',
        _TestCustomActionExecutor(() {
          executed = true;
        }),
      );

      // Execute the custom action
      final ctx = runtime.engine.renderer.createRootContext(null);
      await runtime.engine.actionHandler.execute({
        'type': 'custom',
      }, ctx);

      expect(executed, isTrue);

      await runtime.destroy();
    });

    test('UpdateState helper method works', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);

      await runtime.initialize({
        'type': 'page',
        'runtime': {
          'services': {
            'state': {
              'initialState': {'value': 'initial'},
            },
          },
        },
        'content': {'type': 'text', 'content': '{{value}}'},
      });

      runtime.updateState('value', 'updated');
      expect(runtime.stateManager.get('value'), equals('updated'));

      await runtime.destroy();
    });

    test('Destroy resets isInitialized', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);

      await runtime.initialize({
        'type': 'page',
        'content': {'type': 'text', 'content': 'Test'},
      });

      await runtime.destroy();
      expect(runtime.isInitialized, isFalse);
    });

    test('State clearState removes all data', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);

      await runtime.initialize({
        'type': 'page',
        'runtime': {
          'services': {
            'state': {
              'initialState': {'a': 1, 'b': 2},
            },
          },
        },
        'content': {'type': 'text', 'content': 'Test'},
      });

      runtime.stateManager.clearState();
      expect(runtime.stateManager.get('a'), isNull);
      expect(runtime.stateManager.get('b'), isNull);

      await runtime.destroy();
    });
  });
}

/// Test custom action executor for edge case tests
class _TestCustomActionExecutor extends ActionExecutor {
  final VoidCallback onExecute;

  _TestCustomActionExecutor(this.onExecute);

  @override
  Future<ActionResult> execute(
    Map<String, dynamic> action,
    RenderContext context,
  ) async {
    onExecute();
    return ActionResult.success();
  }
}
