import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/lifecycle_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wires a manager to a real ActionHandler and returns the state it writes to.
///
/// Several tests below used to run hooks with no handler attached and assert
/// only that nothing threw — which is indistinguishable from a manager that
/// silently drops every hook it is given. With this the hooks land somewhere
/// observable.
StateManager wireHooks(LifecycleManager manager) {
  final stateManager = StateManager()..initialize(<String, dynamic>{});
  final bindingEngine = BindingEngine();
  final actionHandler = ActionHandler();
  final context = RenderContext(
    renderer: Renderer(
      widgetRegistry: WidgetRegistry(),
      bindingEngine: bindingEngine,
      actionHandler: actionHandler,
      stateManager: stateManager,
    ),
    stateManager: stateManager,
    bindingEngine: bindingEngine,
    actionHandler: actionHandler,
    themeManager: ThemeManager.instance,
  );
  manager.setActionHandler(actionHandler, context);
  return stateManager;
}

void main() {
  group('TC-028: LifecycleManager — constructor', () {
    test('Normal: LifecycleManager() creates instance', () {
      final manager = LifecycleManager(enableDebugMode: false);
      expect(manager, isNotNull);
      manager.dispose();
    });

    test('Normal: enableDebugMode: true enables debug logging', () {
      final manager = LifecycleManager(enableDebugMode: true);
      expect(manager.enableDebugMode, isTrue);
      manager.dispose();
    });

    test('Boundary: default enableDebugMode is kDebugMode', () {
      final manager = LifecycleManager();
      // In test mode kDebugMode is typically true
      expect(manager.enableDebugMode, isNotNull);
      manager.dispose();
    });
  });

  group('TC-029: LifecycleManager — LifecycleEvent enum', () {
    test('Normal: contains all core events', () {
      expect(LifecycleEvent.values, containsAll([
        LifecycleEvent.initialize,
        LifecycleEvent.ready,
        LifecycleEvent.pause,
        LifecycleEvent.resume,
        LifecycleEvent.destroy,
        LifecycleEvent.mount,
        LifecycleEvent.unmount,
      ]));
    });

    test('Normal: contains v1.1 events', () {
      expect(LifecycleEvent.values, containsAll([
        LifecycleEvent.enter,
        LifecycleEvent.leave,
        LifecycleEvent.pagePause,
        LifecycleEvent.pageResume,
        LifecycleEvent.pageInit,
      ]));
    });

    test('Boundary: all enum values are distinct', () {
      final valueSet = LifecycleEvent.values.toSet();
      expect(valueSet.length, equals(LifecycleEvent.values.length));
    });
  });

  group('TC-030: LifecycleManager — executeLifecycleHooks', () {
    test('Boundary: an empty hooks list still runs the registered listeners',
        () async {
      // "No hooks" does not mean "nothing happens": the listeners a host
      // attached for the same event have to fire either way, and a manager
      // that returned early on an empty list would skip them.
      final manager = LifecycleManager(enableDebugMode: false);
      final state = wireHooks(manager);
      final ran = <String>[];
      manager.addListener(LifecycleEvent.initialize, () => ran.add('listener'));

      await manager.executeLifecycleHooks(LifecycleEvent.initialize, []);

      expect(ran, ['listener']);
      expect(state.state, isEmpty, reason: 'and no hook was invented');
      manager.dispose();
    });

    test('Error: hook execution failure continues remaining hooks', () async {
      final manager = LifecycleManager(enableDebugMode: false);
      final executed = <String>[];

      manager.addListener(LifecycleEvent.initialize, () {
        throw Exception('Hook failure');
      });
      manager.addListener(LifecycleEvent.initialize, () {
        executed.add('second');
      });

      // executeLifecycleHooks executes listeners then hooks
      await manager.executeLifecycleHooks(LifecycleEvent.initialize, []);
      expect(executed, contains('second'));
      manager.dispose();
    });
  });

  group('TC-031: LifecycleManager — convenience methods', () {
    late LifecycleManager manager;
    late List<LifecycleEvent> triggeredEvents;

    setUp(() {
      manager = LifecycleManager(enableDebugMode: false);
      triggeredEvents = [];

      for (final event in LifecycleEvent.values) {
        manager.addListener(event, () {
          triggeredEvents.add(event);
        });
      }
    });

    tearDown(() {
      manager.dispose();
    });

    test('Normal: executeOnInitialize delegates to LifecycleEvent.initialize', () async {
      await manager.executeOnInitialize([]);
      expect(triggeredEvents, contains(LifecycleEvent.initialize));
    });

    test('Normal: executeOnInit delegates to LifecycleEvent.pageInit', () async {
      await manager.executeOnInit([]);
      expect(triggeredEvents, contains(LifecycleEvent.pageInit));
    });

    test('Normal: executeOnReady delegates to LifecycleEvent.ready', () async {
      await manager.executeOnReady([]);
      expect(triggeredEvents, contains(LifecycleEvent.ready));
    });

    test('Normal: executeOnPause delegates to LifecycleEvent.pause', () async {
      await manager.executeOnPause([]);
      expect(triggeredEvents, contains(LifecycleEvent.pause));
    });

    test('Normal: executeOnResume delegates to LifecycleEvent.resume', () async {
      await manager.executeOnResume([]);
      expect(triggeredEvents, contains(LifecycleEvent.resume));
    });

    test('Normal: executeOnDispose delegates to LifecycleEvent.destroy', () async {
      await manager.executeOnDispose([]);
      expect(triggeredEvents, contains(LifecycleEvent.destroy));
    });

    test('Normal: executeOnMount delegates to LifecycleEvent.mount', () async {
      await manager.executeOnMount([]);
      expect(triggeredEvents, contains(LifecycleEvent.mount));
    });

    test('Normal: executeOnUnmount delegates to LifecycleEvent.unmount', () async {
      await manager.executeOnUnmount([]);
      expect(triggeredEvents, contains(LifecycleEvent.unmount));
    });

    test('Normal: executeOnEnter delegates to LifecycleEvent.enter', () async {
      await manager.executeOnEnter([]);
      expect(triggeredEvents, contains(LifecycleEvent.enter));
    });

    test('Normal: executeOnLeave delegates to LifecycleEvent.leave', () async {
      await manager.executeOnLeave([]);
      expect(triggeredEvents, contains(LifecycleEvent.leave));
    });

    test('Normal: executeOnPagePause delegates to LifecycleEvent.pagePause', () async {
      await manager.executeOnPagePause([]);
      expect(triggeredEvents, contains(LifecycleEvent.pagePause));
    });

    test('Normal: executeOnPageResume delegates to LifecycleEvent.pageResume', () async {
      await manager.executeOnPageResume([]);
      expect(triggeredEvents, contains(LifecycleEvent.pageResume));
    });
  });

  group('TC-032: LifecycleManager — event listeners (additional)', () {
    test('Boundary: trigger with data passes data to listeners', () async {
      final manager = LifecycleManager(enableDebugMode: false);
      dynamic receivedData;

      manager.addListener(LifecycleEvent.enter, (data) {
        receivedData = data;
      });

      await manager.triggerEvent(LifecycleEvent.enter, {'route': '/home'});
      expect(receivedData, equals({'route': '/home'}));
      manager.dispose();
    });
  });

  group('TC-033: LifecycleManager — setActionHandler', () {
    test('Normal: once a handler is set, hooks reach it', () async {
      final manager = LifecycleManager(enableDebugMode: false);
      final state = wireHooks(manager);

      await manager.executeLifecycleHooks(LifecycleEvent.initialize, [
        {'type': 'state', 'action': 'set', 'binding': 'ready', 'value': true},
      ]);

      expect(state.get('ready'), isTrue,
          reason: 'setActionHandler is the entire point of this class — a '
              'test that only checked it did not throw could not tell a wired '
              'manager from an unwired one');
      manager.dispose();
    });

    test('Error: with no handler wired the hook is dropped and the rest of '
        'the run continues', () async {
      final manager = LifecycleManager(enableDebugMode: false);
      manager.setActionHandler(null, null);
      final ran = <String>[];
      manager.addListener(LifecycleEvent.initialize, () => ran.add('listener'));

      await manager.executeLifecycleHooks(
        LifecycleEvent.initialize,
        [
          {'type': 'custom', 'action': 'doSomething'},
          {'type': 'state', 'action': 'set', 'binding': 'x', 'value': 1},
        ],
      );

      // The drop is logged rather than thrown (see `_dispatchToActionHandler`)
      // — a hook that fires before the engine finishes wiring must not take
      // initialization down with it.
      expect(ran, ['listener']);
      manager.dispose();
    });
  });

  group('TC-034: LifecycleManager — createComponentHandler (additional)', () {
    test('Boundary: multiple component handlers for different IDs', () {
      final manager = LifecycleManager(enableDebugMode: false);
      final handler1 = manager.createComponentHandler('component_a');
      final handler2 = manager.createComponentHandler('component_b');

      expect(handler1.componentId, equals('component_a'));
      expect(handler2.componentId, equals('component_b'));
      expect(handler1, isNot(same(handler2)));
      manager.dispose();
    });
  });

  group('TC-035: LifecycleManager — dispose', () {
    test('Normal: dispose cleans up all listeners', () async {
      final manager = LifecycleManager(enableDebugMode: false);
      final executed = <String>[];

      manager.addListener(LifecycleEvent.initialize, () {
        executed.add('should_not_run');
      });

      manager.dispose();

      // After dispose, triggering should have no listeners
      await manager.triggerEvent(LifecycleEvent.initialize);
      expect(executed, isEmpty);
    });

    test('Boundary: dispose clears the listeners, and disposing twice is safe',
        () async {
      final manager = LifecycleManager(enableDebugMode: false);
      final ran = <String>[];
      manager.addListener(LifecycleEvent.initialize, () => ran.add('listener'));

      manager.dispose();
      manager.dispose(); // the "no registered listeners" case, for real

      await manager.triggerEvent(LifecycleEvent.initialize);
      expect(ran, isEmpty,
          reason: 'a listener that still fires after dispose keeps a closed '
              'page reacting to the next one');
    });
  });

  group('TC-036: ComponentLifecycleHandler — constructor (additional)', () {
    test('Normal: isMounted is false initially', () {
      final manager = LifecycleManager(enableDebugMode: false);
      final handler = ComponentLifecycleHandler(
        componentId: 'test',
        lifecycleManager: manager,
        enableDebugMode: false,
      );
      expect(handler.isMounted, isFalse);
      manager.dispose();
    });

    test('Boundary: empty componentId string', () {
      final manager = LifecycleManager(enableDebugMode: false);
      final handler = manager.createComponentHandler('');
      expect(handler.componentId, equals(''));
      manager.dispose();
    });
  });

  group('TC-037: ComponentLifecycleHandler — mount/unmount (additional)', () {
    test('Boundary: unmount already unmounted component is a no-op', () async {
      final manager = LifecycleManager(enableDebugMode: false);
      final handler = manager.createComponentHandler('test');

      expect(handler.isMounted, isFalse);
      // Should not throw
      await handler.unmount();
      expect(handler.isMounted, isFalse);
      manager.dispose();
    });
  });

  group('TC-038: ComponentLifecycleHandler — setLifecycleConfig', () {
    test('Normal: setLifecycleConfig configures hooks', () {
      final manager = LifecycleManager(enableDebugMode: false);
      final handler = manager.createComponentHandler('test');

      handler.setLifecycleConfig({
        'onMount': [{'type': 'state', 'action': 'set', 'path': 'x', 'value': 1}],
      });

      // No error expected
      expect(handler.isMounted, isFalse);
      manager.dispose();
    });

    test('Boundary: null config clears lifecycle hooks', () {
      final manager = LifecycleManager(enableDebugMode: false);
      final handler = manager.createComponentHandler('test');

      handler.setLifecycleConfig({'onMount': [{'type': 'state'}]});
      handler.setLifecycleConfig(null);

      // No error expected
      expect(handler.isMounted, isFalse);
      manager.dispose();
    });
  });

  group('TC-039: LifecycleManager — app vs page scope', () {
    test('Normal: separate events for app pause/resume and page pause/resume', () async {
      final manager = LifecycleManager(enableDebugMode: false);
      final events = <String>[];

      manager.addListener(LifecycleEvent.pause, () {
        events.add('app_pause');
      });
      manager.addListener(LifecycleEvent.resume, () {
        events.add('app_resume');
      });
      manager.addListener(LifecycleEvent.pagePause, () {
        events.add('page_pause');
      });
      manager.addListener(LifecycleEvent.pageResume, () {
        events.add('page_resume');
      });

      await manager.triggerEvent(LifecycleEvent.pause);
      await manager.triggerEvent(LifecycleEvent.pagePause);
      await manager.triggerEvent(LifecycleEvent.resume);
      await manager.triggerEvent(LifecycleEvent.pageResume);

      expect(events, equals(['app_pause', 'page_pause', 'app_resume', 'page_resume']));
      manager.dispose();
    });
  });

  group('LifecycleManager Tests', () {
    late LifecycleManager lifecycleManager;

    setUp(() {
      lifecycleManager = LifecycleManager(enableDebugMode: false);
    });

    tearDown(() {
      lifecycleManager.dispose();
    });

    test('adds listeners and triggers events', () async {
      final executionOrder = <String>[];

      // Add listeners for different events
      lifecycleManager.addListener(
        LifecycleEvent.initialize,
        () async {
          executionOrder.add('initialize');
        },
      );

      lifecycleManager.addListener(
        LifecycleEvent.ready,
        () async {
          executionOrder.add('ready');
        },
      );

      lifecycleManager.addListener(
        LifecycleEvent.pause,
        () async {
          executionOrder.add('pause');
        },
      );

      // Trigger events
      await lifecycleManager.triggerEvent(LifecycleEvent.initialize);
      await lifecycleManager.triggerEvent(LifecycleEvent.ready);
      await lifecycleManager.triggerEvent(LifecycleEvent.pause);

      expect(executionOrder, ['initialize', 'ready', 'pause']);
    });

    test('executes multiple listeners for same event', () async {
      final executionOrder = <String>[];

      lifecycleManager.addListener(
        LifecycleEvent.initialize,
        () async {
          executionOrder.add('listener1');
        },
      );

      lifecycleManager.addListener(
        LifecycleEvent.initialize,
        () async {
          executionOrder.add('listener2');
        },
      );

      lifecycleManager.addListener(
        LifecycleEvent.initialize,
        () async {
          executionOrder.add('listener3');
        },
      );

      await lifecycleManager.triggerEvent(LifecycleEvent.initialize);

      expect(executionOrder, ['listener1', 'listener2', 'listener3']);
    });

    test('executes hooks from action definitions, and one failure does not '
        'stop the next', () async {
      final state = wireHooks(lifecycleManager);

      await lifecycleManager.executeLifecycleHooks(
        LifecycleEvent.initialize,
        [
          // A service hook with nothing behind it: it fails, and the state
          // hook after it still has to run. That ordering is the whole
          // contract of the loop in `executeLifecycleHooks`.
          {'type': 'service', 'service': 'navigation', 'action': 'initialize'},
          {
            'type': 'state',
            'action': 'set',
            'binding': 'initialized',
            'value': true,
          },
        ],
      );

      expect(state.get('initialized'), isTrue);
    });

    test('handles async listeners correctly', () async {
      final executionOrder = <String>[];

      lifecycleManager.addListener(
        LifecycleEvent.ready,
        () async {
          await Future.delayed(const Duration(milliseconds: 50));
          executionOrder.add('async1');
        },
      );

      lifecycleManager.addListener(
        LifecycleEvent.ready,
        () async {
          await Future.delayed(const Duration(milliseconds: 25));
          executionOrder.add('async2');
        },
      );

      lifecycleManager.addListener(
        LifecycleEvent.ready,
        () async {
          executionOrder.add('sync');
        },
      );

      await lifecycleManager.triggerEvent(LifecycleEvent.ready);

      // All listeners should complete
      expect(executionOrder.length, 3);
    });

    test('handles listener errors gracefully', () async {
      final executionOrder = <String>[];

      lifecycleManager.addListener(
        LifecycleEvent.destroy,
        () async {
          throw Exception('Test error');
        },
      );

      lifecycleManager.addListener(
        LifecycleEvent.destroy,
        () async {
          executionOrder.add('success');
        },
      );

      // Should not throw, but continue with other listeners
      await lifecycleManager.triggerEvent(LifecycleEvent.destroy);

      expect(executionOrder, ['success']);
    });

    test('removes listeners', () async {
      final executed = <String>[];

      void testListener() {
        executed.add('should_not_execute');
      }

      lifecycleManager.addListener(LifecycleEvent.initialize, testListener);
      lifecycleManager.removeListener(LifecycleEvent.initialize, testListener);

      await lifecycleManager.triggerEvent(LifecycleEvent.initialize);

      expect(executed, isEmpty);
    });

    test('supports all lifecycle events', () async {
      final events = <LifecycleEvent>[];

      for (final event in LifecycleEvent.values) {
        lifecycleManager.addListener(
          event,
          () async {
            events.add(event);
          },
        );
      }

      // Trigger all events
      for (final event in LifecycleEvent.values) {
        await lifecycleManager.triggerEvent(event);
      }

      expect(events.length, LifecycleEvent.values.length);
      expect(events.toSet(), LifecycleEvent.values.toSet());
    });

    test('passes data to listeners', () async {
      dynamic receivedData;

      lifecycleManager.addListener(
        LifecycleEvent.mount,
        (data) async {
          receivedData = data;
        },
      );

      await lifecycleManager.triggerEvent(LifecycleEvent.mount, 'test_data');

      expect(receivedData, 'test_data');
    });

    test('creates component lifecycle handler', () {
      final handler = lifecycleManager.createComponentHandler('test_component');

      expect(handler, isNotNull);
      expect(handler.componentId, 'test_component');
      expect(handler.isMounted, false);
    });
  });

  group('ComponentLifecycleHandler Tests', () {
    late LifecycleManager lifecycleManager;
    late ComponentLifecycleHandler handler;

    setUp(() {
      lifecycleManager = LifecycleManager(enableDebugMode: false);
      handler = lifecycleManager.createComponentHandler('test_component');
    });

    tearDown(() {
      lifecycleManager.dispose();
    });

    test('handles mount and unmount', () async {
      expect(handler.isMounted, false);

      await handler.mount();
      expect(handler.isMounted, true);

      await handler.unmount();
      expect(handler.isMounted, false);
    });

    test('prevents double mount', () async {
      await handler.mount();
      expect(handler.isMounted, true);

      // Second mount should be ignored
      await handler.mount();
      expect(handler.isMounted, true);
    });

    test('executes lifecycle config hooks', () async {
      final executionOrder = <String>[];

      // Set up global listeners to track execution
      lifecycleManager.addListener(LifecycleEvent.mount, (componentId) {
        executionOrder.add('mount:$componentId');
      });

      lifecycleManager.addListener(LifecycleEvent.unmount, (componentId) {
        executionOrder.add('unmount:$componentId');
      });

      await handler.mount();
      await handler.unmount();

      expect(executionOrder, ['mount:test_component', 'unmount:test_component']);
    });

    test('executes component-specific lifecycle hooks', () async {
      final state = wireHooks(lifecycleManager);
      handler.setLifecycleConfig({
        'onMount': [
          {
            'type': 'state',
            'action': 'set',
            'binding': 'mounted',
            'value': true,
          },
        ],
        'onUnmount': [
          {
            'type': 'state',
            'action': 'set',
            'binding': 'mounted',
            'value': false,
          },
        ],
      });

      await handler.mount();
      expect(state.get('mounted'), isTrue,
          reason: 'onMount is where a component asks for its data — a config '
              'that is stored and never executed leaves the component empty');

      await handler.unmount();
      expect(state.get('mounted'), isFalse);
    });
  });
}