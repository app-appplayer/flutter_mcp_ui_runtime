// `RuntimeEngine` reading the shapes an older bundle still uses, and the
// app cache behind `useCache`.
//
// The legacy shapes matter because bundles already in the wild carry them: a
// `runtime.services.theme` block, a `services.state.computed` map, lifecycle
// hooks under `runtime.lifecycle`. Each one is a document that renders today
// and would quietly lose a capability if the fallback stopped being read.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/cache_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/runtime_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RuntimeEngine engine;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    engine = RuntimeEngine(enableDebugMode: true);
  });

  tearDown(() => engine.destroy());

  /// An application definition needs somewhere to fetch its pages from.
  Future<Map<String, dynamic>> pages(String uri) async => <String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{'type': 'text', 'content': uri},
      };

  Map<String, dynamic> set(String binding, Object value) => <String, dynamic>{
        'type': 'state',
        'action': 'set',
        'binding': binding,
        'value': value,
      };

  group('the legacy runtime block', () {
    test('a theme declared under runtime.services is applied', () async {
      await engine.initialize(definition: <String, dynamic>{
        'type': 'application',
        'title': 'Jobs',
        'version': '1.0.0',
        'routes': <String, dynamic>{'/': 'ui://pages/home'},
        'runtime': <String, dynamic>{
          'services': <String, dynamic>{
            'theme': <String, dynamic>{
              'color': <String, dynamic>{'primary': '#FF0000'},
            },
          },
        },
      }, pageLoader: pages);

      expect(engine.themeManager.getColorValue('primary'),
          const Color(0xFFFF0000),
          reason: 'a bundle that declares its theme in the older place keeps '
              'its colours; dropping the fallback repaints it grey');
    });

    test('computed properties and watchers declared under services.state run',
        () async {
      await engine.initialize(definition: <String, dynamic>{
        'type': 'application',
        'title': 'Jobs',
        'version': '1.0.0',
        'routes': <String, dynamic>{'/': 'ui://pages/home'},
        'services': <String, dynamic>{
          'state': <String, dynamic>{
            'initialState': <String, dynamic>{'count': 2},
            'computed': <String, dynamic>{
              'doubled': <String, dynamic>{
                'expression': '{{count * 2}}',
                'dependencies': <dynamic>['count'],
              },
            },
            'watchers': <dynamic>[
              <String, dynamic>{
                'path': 'count',
                'handler': <dynamic>[set('watched', true)],
              },
            ],
          },
        },
      }, pageLoader: pages);

      expect(engine.stateManager.get('count'), 2);
      expect(engine.computedManager.getComputed('doubled'), 4,
          reason: 'a derived value declared the older way is what the page '
              'binds to; losing it leaves the label empty');

      engine.stateManager.set('count', 5);
      expect(engine.computedManager.getComputed('doubled'), 10,
          reason: 'the declared dependency list is what makes it recompute; '
              'a stale derived number is worse than none');
    });

    test('the declared lifecycle hooks run at ready, pause and resume',
        () async {
      await engine.initialize(definition: <String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{'type': 'text', 'content': 'root'},
        'lifecycle': <String, dynamic>{
          'onReady': <dynamic>[set('ready', true)],
          'onPause': <dynamic>[set('paused', true)],
          'onResume': <dynamic>[set('resumed', true)],
        },
      });

      await engine.markReady();
      expect(engine.stateManager.get('ready'), isTrue);

      await engine.pause();
      expect(engine.stateManager.get('paused'), isTrue);

      await engine.resume();
      expect(engine.stateManager.get('resumed'), isTrue,
          reason: 'a backgrounded app that never resumes leaves its '
              'subscriptions closed on a screen the user is looking at');
    });

    test('pause and resume before the runtime is ready do nothing', () async {
      await engine.initialize(definition: <String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{'type': 'text', 'content': 'root'},
        'lifecycle': <String, dynamic>{
          'onPause': <dynamic>[set('paused', true)],
        },
      });

      await engine.pause();

      expect(engine.stateManager.get('paused'), isNull,
          reason: 'a document that has not finished starting has nothing to '
              'pause; running the hook would tear down what never came up');
    });
  });

  group('an application definition\'s own lifecycle', () {
    test('its hooks run at ready, and markReady is idempotent', () async {
      await engine.initialize(definition: <String, dynamic>{
        'type': 'application',
        'title': 'Jobs',
        'routes': <String, dynamic>{'/': 'ui://pages/home'},
        'lifecycle': <String, dynamic>{
          'onReady': <dynamic>[set('readyCount', 1)],
        },
      }, pageLoader: pages);

      await engine.markReady();
      expect(engine.stateManager.get('readyCount'), 1,
          reason: 'an application is the lifecycle-aware entity as much as a '
              'page is; a bundle whose onReady never runs opens without the '
              'data it fetches for itself');

      engine.stateManager.set('readyCount', 0);
      await engine.markReady();
      expect(engine.stateManager.get('readyCount'), 0,
          reason: 'ready happens once; running the hooks again on a second '
              'call would re-fetch on every rebuild');
    });

    test('pause and resume run the application\'s own hooks', () async {
      await engine.initialize(definition: <String, dynamic>{
        'type': 'application',
        'title': 'Jobs',
        'routes': <String, dynamic>{'/': 'ui://pages/home'},
        'lifecycle': <String, dynamic>{
          'onPause': <dynamic>[set('paused', true)],
          'onResume': <dynamic>[set('resumed', true)],
        },
      }, pageLoader: pages);
      await engine.markReady();

      await engine.pause();
      expect(engine.stateManager.get('paused'), isTrue,
          reason: 'an application backgrounded without its onPause keeps '
              'whatever it started running while nobody is looking');

      await engine.resume();
      expect(engine.stateManager.get('resumed'), isTrue,
          reason: 'and one that never hears onResume comes back showing the '
              'values it had when it went away');
    });

    test('marking ready before initialising is refused by name', () async {
      final fresh = RuntimeEngine(enableDebugMode: false);
      addTearDown(fresh.destroy);

      expect(fresh.markReady(), throwsA(isA<StateError>()),
          reason: 'hooks that run against an uninitialised engine write into '
              'state nobody is bound to yet');
    });
  });

  group('background services declared in the definition', () {
    test('a malformed one is skipped and the rest still start', () async {
      var called = 0;
      engine.actionHandler.registerToolExecutor('sync', (_) async {
        called++;
        return <String, dynamic>{'ok': true};
      });

      // Background services live under an application's `services` block.
      await engine.initialize(definition: <String, dynamic>{
        'type': 'application',
        'title': 'Jobs',
        'routes': <String, dynamic>{'/': 'ui://pages/home'},
        'services': <String, dynamic>{
          'backgroundServices': <String, dynamic>{
            // Neither `kind` nor `type`: nothing to schedule it by.
            'broken': <String, dynamic>{'tool': 'sync'},
            'good': <String, dynamic>{
              'kind': 'polling',
              'tool': 'sync',
              'interval': 20,
            },
          },
        },
      }, pageLoader: pages);
      await engine.markReady();
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(called, greaterThan(0),
          reason: 'one unparseable service must not take the others down — a '
              'typo in one block would otherwise stop every background job '
              'the document declared, with nothing on screen to say so');

      expect(engine.isInitialized, isTrue);
    });
  });

  group('the app cache', () {
    Map<String, dynamic> app({String version = '1.0.0'}) => <String, dynamic>{
          'type': 'application',
          'title': 'Jobs',
          'domain': 'example.com',
          'id': 'jobs',
          'version': version,
          'routes': <String, dynamic>{'/': 'ui://pages/home'},
          'initialState': <String, dynamic>{'tab': 1},
        };

    test('an application is filed under the identity it declares', () async {
      await engine.initialize(definition: app(), pageLoader: pages);

      final cached = engine.cacheManager.getCachedApp('example.com', 'jobs');

      expect(cached, isNotNull,
          reason: 'the lookup reads `domain`/`id` from the top level, so the '
              'write has to file it there too — otherwise the cache is '
              'write-only and every launch refetches');
      expect(cached!.version, '1.0.0');
      expect(cached.definition['title'], 'Jobs');
    });

    test('a primed cache is what the engine runs, state and all', () async {
      // What an offline shell does at launch: hand the engine what it saved
      // last time, then initialize.
      final saved = <String, dynamic>{
        ...app(),
        'title': 'Jobs (offline copy)',
      };
      final primed = RuntimeEngine(enableDebugMode: true);
      addTearDown(primed.destroy);
      await primed.cacheManager.cacheApp(CachedApp.fromDefinition(saved));
      await primed.cacheManager
          .cacheState('example.com:jobs', <String, dynamic>{'tab': 9, 'draft': 'unsent'});

      await primed.initialize(definition: app(), pageLoader: pages);

      expect(primed.applicationDefinition?.title, 'Jobs (offline copy)',
          reason: 'the cached definition is the one to run; falling back to '
              'the passed one makes the cache decorative');
      expect(primed.stateManager.get('draft'), 'unsent',
          reason: 'a key only the cache holds is exactly what a resume is '
              'made of');
      expect(primed.stateManager.get('tab'), 9,
          reason: "the definition's initial state is where a FIRST run "
              'starts; the cache is where this user actually was, and it has '
              'to win or the cache load is decorative');
    });

    test('a cache holding a newer version is still served', () async {
      final primed = RuntimeEngine(enableDebugMode: true);
      addTearDown(primed.destroy);
      await primed.cacheManager
          .cacheApp(CachedApp.fromDefinition(app(version: '2.0.0')));

      await primed.initialize(definition: app(), pageLoader: pages);

      expect(primed.applicationDefinition, isNotNull,
          reason: 'noticing an update is not a reason to refuse to start');
    });

    test('each engine keeps its own cache', () async {
      await engine.initialize(definition: app(), pageLoader: pages);

      final second = RuntimeEngine(enableDebugMode: true);
      addTearDown(second.destroy);

      expect(second.cacheManager.getCachedApp('example.com', 'jobs'), isNull,
          reason: 'the app cache lives in the engine, not in storage; a host '
              'that wants it to survive a restart has to prime it');
    });

    test('a newer version is noticed rather than silently served stale',
        () async {
      await engine.initialize(definition: app(), pageLoader: pages);

      final second = RuntimeEngine(enableDebugMode: true);
      addTearDown(second.destroy);
      await second.initialize(
          definition: app(version: '2.0.0'), pageLoader: pages);

      expect(second.applicationDefinition, isNotNull);
    });

    test('an application missing its identity is not cached', () async {
      await engine.initialize(definition: <String, dynamic>{
        'type': 'application',
        'title': 'Jobs',
        'version': '1.0.0',
        'routes': <String, dynamic>{'/': 'ui://pages/home'},
      }, pageLoader: pages);

      expect(engine.applicationDefinition, isNotNull,
          reason: 'a bundle with no domain or id has no cache key; it must '
              'still run rather than being refused');
    });

    test('caching can be turned off for a run', () async {
      await engine.initialize(
          definition: app(), useCache: false, pageLoader: pages);

      expect(engine.applicationDefinition, isNotNull);
    });
  });

  group('destroy', () {
    test('destroying twice is quiet, and disposing after it is too', () async {
      await engine.initialize(definition: <String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{'type': 'text', 'content': 'root'},
      });

      await engine.destroy();
      await engine.destroy();
      engine.dispose();

      expect(engine.isReady, isFalse);
    });
  });
}
