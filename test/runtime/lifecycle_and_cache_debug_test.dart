// `LifecycleManager` and `CacheManager` with debug mode ON, plus the paths the
// existing suites do not reach: persisted state, the component handler, and
// the hook kinds that dispatch through the action handler.
//
// Debug mode is not decoration here — the logging branches are where a dropped
// hook is reported, and a host that turns debug on to find out why its
// `onReady` never ran is exercising code nothing else does.

import 'package:flutter_mcp_ui_runtime/src/runtime/cache_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/lifecycle_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records what the lifecycle manager dispatches, standing in for the real
/// `ActionHandler` the engine wires.
class _RecordingActionHandler {
  final List<Map<String, dynamic>> executed = <Map<String, dynamic>>[];
  bool throwOnExecute = false;

  Future<void> execute(Map<String, dynamic> action, dynamic context) async {
    executed.add(action);
    if (throwOnExecute) throw StateError('handler broke');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LifecycleManager', () {
    late LifecycleManager manager;
    late _RecordingActionHandler handler;

    setUp(() {
      manager = LifecycleManager(enableDebugMode: true);
      handler = _RecordingActionHandler();
      manager.setActionHandler(handler, Object());
    });

    tearDown(() => manager.dispose());

    test('a listener hears its event, and stops once removed', () async {
      var fired = 0;
      void listener() => fired++;

      manager.addListener(LifecycleEvent.ready, listener);
      await manager.executeOnReady(<dynamic>[]);
      expect(fired, 1);

      manager.removeListener(LifecycleEvent.ready, listener);
      await manager.executeOnReady(<dynamic>[]);
      expect(fired, 1,
          reason: 'a removed listener that keeps firing runs a torn-down '
              'page’s work on the next mount');
    });

    test('an async listener is awaited', () async {
      final order = <String>[];
      manager.addListener(LifecycleEvent.ready, () async {
        await Future<void>.delayed(Duration.zero);
        order.add('listener');
      });

      await manager.executeOnReady(<dynamic>[
        <String, dynamic>{'type': 'state', 'action': 'set'},
      ]);
      order.add('after');

      expect(order, ['listener', 'after'],
          reason: 'hooks that run after a listener must see what the listener '
              'did, which means waiting for it');
    });

    test('a listener that throws does not stop the hooks behind it', () async {
      manager.addListener(
          LifecycleEvent.ready, () => throw StateError('broke'));

      await manager.executeOnReady(<dynamic>[
        <String, dynamic>{'type': 'state', 'action': 'set'},
      ]);

      expect(handler.executed, hasLength(1));
    });

    test('a hook that throws does not stop the ones behind it', () async {
      handler.throwOnExecute = true;

      await manager.executeOnReady(<dynamic>[
        <String, dynamic>{'type': 'state', 'action': 'set'},
        <String, dynamic>{'type': 'tool', 'tool': 'refresh'},
      ]);

      expect(handler.executed, hasLength(2),
          reason: 'one failing hook taking the rest down leaves a page half '
              'initialised with nothing said');
    });

    test('every declared hook kind reaches the action handler', () async {
      await manager.executeOnInitialize(<dynamic>[
        <String, dynamic>{'type': 'state', 'action': 'set'},
        <String, dynamic>{'type': 'tool', 'tool': 'refresh'},
        <String, dynamic>{'type': 'service', 'service': 'sync'},
        <String, dynamic>{'type': 'notification', 'action': 'show'},
        <String, dynamic>{'type': 'resource', 'resource': 'ui://x'},
        <String, dynamic>{'type': 'navigation', 'action': 'push'},
      ]);

      expect(handler.executed.map((a) => a['type']), [
        'state',
        'tool',
        'service',
        'notification',
        'resource',
        'navigation',
      ], reason: 'any action type may be a lifecycle hook; the switch names '
          'five and the default must carry the rest');
    });

    test('a malformed hook is skipped rather than dispatched', () async {
      await manager.executeOnInit(<dynamic>[
        'not a map',
        <String, dynamic>{'action': 'set'},
        42,
      ]);

      expect(handler.executed, isEmpty);
    });

    test('with nothing wired a hook is dropped, and the manager says so',
        () async {
      final unwired = LifecycleManager(enableDebugMode: true);
      addTearDown(unwired.dispose);

      // Nothing to assert but the absence of a crash: the drop is reported
      // through the logger, which is the only channel a host has for an
      // ordering bug in its own wiring.
      await unwired.executeOnReady(<dynamic>[
        <String, dynamic>{'type': 'state', 'action': 'set'},
      ]);

      expect(handler.executed, isEmpty,
          reason: 'an unwired manager must not reach some other manager’s '
              'handler');
    });

    test('triggerEvent reaches listeners of every shape', () async {
      final seen = <String>[];

      manager.addListener(
          LifecycleEvent.pause, (dynamic data) => seen.add('sync:$data'));
      manager.addListener(LifecycleEvent.pause, (dynamic data) async {
        seen.add('async:$data');
      });
      manager.addListener(LifecycleEvent.pause, () => seen.add('noArg'));
      manager.addListener(LifecycleEvent.pause, () async => seen.add('noArgAsync'));
      manager.addListener(
          LifecycleEvent.pause, () => throw StateError('broke'));

      await manager.triggerEvent(LifecycleEvent.pause, 'now');

      expect(seen, ['sync:now', 'async:now', 'noArg', 'noArgAsync']);
    });

    test('every convenience method targets its own event', () async {
      final seen = <LifecycleEvent>[];
      for (final event in LifecycleEvent.values) {
        manager.addListener(event, () => seen.add(event));
      }

      await manager.executeOnInitialize(<dynamic>[]);
      await manager.executeOnInit(<dynamic>[]);
      await manager.executeOnReady(<dynamic>[]);
      await manager.executeOnPause(<dynamic>[]);
      await manager.executeOnResume(<dynamic>[]);
      await manager.executeOnDispose(<dynamic>[]);
      await manager.executeOnMount(<dynamic>[]);
      await manager.executeOnUnmount(<dynamic>[]);
      await manager.executeOnEnter(<dynamic>[]);
      await manager.executeOnLeave(<dynamic>[]);
      await manager.executeOnPagePause(<dynamic>[]);
      await manager.executeOnPageResume(<dynamic>[]);

      expect(seen.toSet(), LifecycleEvent.values.toSet(),
          reason: 'each convenience method names one event; two of them '
              'pointing at the same event silently merges two hooks');
    });

    test('disposing drops the listeners', () async {
      var fired = 0;
      manager.addListener(LifecycleEvent.ready, () => fired++);

      manager.dispose();
      await manager.executeOnReady(<dynamic>[]);

      expect(fired, 0);
    });
  });

  group('ComponentLifecycleHandler', () {
    test('mounts once, runs its hooks, and unmounts once', () async {
      final manager = LifecycleManager(enableDebugMode: true);
      final handler = _RecordingActionHandler();
      manager.setActionHandler(handler, Object());
      addTearDown(manager.dispose);

      final component = manager.createComponentHandler('card-1');
      component.setLifecycleConfig(<String, dynamic>{
        'onMount': <dynamic>[
          <String, dynamic>{'type': 'state', 'action': 'set'},
        ],
        'onUnmount': <dynamic>[
          <String, dynamic>{'type': 'tool', 'tool': 'release'},
        ],
      });

      expect(component.isMounted, isFalse);

      await component.mount();
      await component.mount();
      expect(component.isMounted, isTrue);
      expect(handler.executed.where((a) => a['type'] == 'state'), hasLength(1),
          reason: 'mounting twice would run `onMount` twice — a second '
              'subscription nobody releases');

      await component.unmount();
      await component.unmount();
      expect(component.isMounted, isFalse);
      expect(handler.executed.where((a) => a['type'] == 'tool'), hasLength(1));
    });

    test('a component with no config mounts and unmounts quietly', () async {
      final manager = LifecycleManager(enableDebugMode: true);
      addTearDown(manager.dispose);

      final component = manager.createComponentHandler('card-2');
      await component.mount();
      await component.unmount();

      expect(component.isMounted, isFalse);
    });
  });

  group('CacheManager', () {
    late CacheManager cache;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      cache = CacheManager(enableDebugMode: true);
    });

    CachedApp app({
      String version = '1.0.0',
      CachePolicy? policy,
      DateTime? cachedAt,
      DateTime? expiresAt,
    }) =>
        CachedApp(
          id: 'jobs',
          domain: 'example.com',
          version: version,
          definition: <String, dynamic>{'type': 'page'},
          cachedAt: cachedAt ?? DateTime.now(),
          expiresAt: expiresAt,
          cachePolicy: policy,
        );

    test('a cached app comes back, and an unknown one does not', () async {
      await cache.cacheApp(app());

      expect(cache.getCachedApp('example.com', 'jobs'), isNotNull);
      expect(cache.getCachedApp('example.com', 'other'), isNull);
    });

    test('an expired app is a miss', () async {
      await cache.cacheApp(app(
        cachedAt: DateTime.now().subtract(const Duration(hours: 2)),
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      ));

      expect(cache.getCachedApp('example.com', 'jobs'), isNull,
          reason: 'serving an expired definition is serving a document its '
              'author already replaced');
    });

    test('an app older than the policy allows is a miss', () async {
      await cache.cacheApp(app(
        cachedAt: DateTime.now().subtract(const Duration(hours: 2)),
        policy: const CachePolicy(maxAge: Duration(minutes: 30)),
      ));

      expect(cache.getCachedApp('example.com', 'jobs'), isNull);
    });

    test('a disabled policy makes every read a miss', () async {
      await cache.cacheApp(app(policy: const CachePolicy(enabled: false)));

      expect(cache.getCachedApp('example.com', 'jobs'), isNull);
    });

    test('a newer cached version is reported as an update', () async {
      await cache.cacheApp(app(version: '1.2.0'));

      expect(cache.isUpdateAvailable('example.com', 'jobs', '1.1.9'), isTrue);
      expect(cache.isUpdateAvailable('example.com', 'jobs', '1.2.0'), isFalse);
      expect(cache.isUpdateAvailable('example.com', 'jobs', '2.0.0'), isFalse);
      expect(cache.isUpdateAvailable('example.com', 'nope', '1.0.0'), isFalse);
    });

    test('state is persisted and read back after the memory cache is gone',
        () async {
      await cache.cacheState('example.com:jobs', <String, dynamic>{'tab': 2});

      final fresh = CacheManager(enableDebugMode: true);
      await fresh.loadPersistedState('example.com:jobs');

      expect(fresh.getCachedState('example.com:jobs'), {'tab': 2},
          reason: 'persisted state is what makes a restart resume where the '
              'user was');
    });

    test('a non-persistent policy keeps state in memory only', () async {
      cache.defaultPolicy = const CachePolicy(persistent: false);
      await cache.cacheState('example.com:jobs', <String, dynamic>{'tab': 2});

      final fresh = CacheManager(enableDebugMode: true);
      await fresh.loadPersistedState('example.com:jobs');

      expect(cache.getCachedState('example.com:jobs'), {'tab': 2});
      expect(fresh.getCachedState('example.com:jobs'), isNull);
    });

    test('loading does not overwrite what is already in memory', () async {
      await cache.cacheState('example.com:jobs', <String, dynamic>{'tab': 2});
      cache.getCachedState('example.com:jobs')!['tab'] = 5;

      await cache.loadPersistedState('example.com:jobs');

      expect(cache.getCachedState('example.com:jobs')!['tab'], 5,
          reason: 'the live value is newer than the stored one; reloading '
              'over it would undo what the user just did');
    });

    test('the cached state is a copy of what was handed in', () async {
      final state = <String, dynamic>{'tab': 2};
      await cache.cacheState('example.com:jobs', state);

      state['tab'] = 9;

      expect(cache.getCachedState('example.com:jobs')!['tab'], 2);
    });

    test('resources are cached by key, as copies', () async {
      final data = <String, dynamic>{'rows': 3};
      await cache.cacheResource('ui://rows', data);
      data['rows'] = 9;

      expect(cache.getCachedResource('ui://rows'), {'rows': 3});
      expect(cache.getCachedResource('ui://missing'), isNull);
    });

    test('stats count what is held, and name it', () async {
      await cache.cacheApp(app());
      await cache.cacheState('example.com:jobs', <String, dynamic>{'tab': 2});
      await cache.cacheResource('ui://rows', <String, dynamic>{'rows': 3});

      final stats = cache.getStats();
      expect(stats.appCount, 1);
      expect(stats.stateCount, 1);
      expect(stats.resourceCount, 1);
      expect(stats.totalSize, greaterThan(0));
      expect(stats.toString(), contains('apps: 1'));
    });

    test('clearing one app leaves the others, and clearAll empties everything',
        () async {
      await cache.cacheApp(app());
      await cache.cacheState('example.com:jobs', <String, dynamic>{'tab': 2});
      await cache.cacheResource('ui://rows', <String, dynamic>{'rows': 3});

      await cache.clearApp('example.com', 'jobs');
      expect(cache.getCachedApp('example.com', 'jobs'), isNull);
      expect(cache.getCachedState('example.com:jobs'), isNull);
      expect(cache.getCachedResource('ui://rows'), isNotNull);

      final fresh = CacheManager(enableDebugMode: true);
      await fresh.loadPersistedState('example.com:jobs');
      expect(fresh.getCachedState('example.com:jobs'), isNull,
          reason: 'clearing an app has to reach the persisted copy too, or a '
              'restart brings back what was cleared');

      await cache.clearAll();
      expect(cache.getStats().resourceCount, 0);
    });

    test('setting the default policy is what later reads are judged by', () {
      cache.defaultPolicy = const CachePolicy(enabled: false);
      expect(cache.defaultPolicy.enabled, isFalse);
    });
  });
}
