// RuntimeEngine — the declared state extras, the app lifecycle, and the
// accessors a host reaches the engine's parts through.
//
// `state.computed` and `state.watchers` are how a document derives a value and
// reacts to one. Both are written in the definition and both were covered only
// through the legacy `services.state` block — so the spec spelling had no
// evidence at all, and the watcher's `condition` (the part that decides
// whether the actions run) had never been evaluated once.
//
// `pause` / `resume` are the other half: an app that is backgrounded and
// brought back. A hook that does not fire there is a subscription left open on
// a screen nobody is looking at.

import 'package:flutter_mcp_ui_runtime/src/runtime/runtime_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late RuntimeEngine engine;

  setUp(() => engine = RuntimeEngine(enableDebugMode: false));
  tearDown(() => engine.destroy());

  /// A `state` action that writes [value] to [binding].
  Map<String, dynamic> set(String binding, Object value) => {
        'type': 'state',
        'action': 'set',
        'binding': binding,
        'value': value,
      };

  group('state.computed, written the way the spec writes it', () {
    test('a computed value is derived from the state it names', () async {
      await engine.initialize(definition: {
        'type': 'page',
        'content': {'type': 'box'},
        'state': {
          'initial': {'first': 'Ada', 'last': 'Lovelace'},
          'computed': {
            'fullName': {
              'expression': '{{first}} {{last}}',
              'dependencies': ['first', 'last'],
            },
          },
        },
      });

      expect(engine.computedManager.getComputed('fullName'), 'Ada Lovelace',
          reason: '§3.8 declared in the document used to reach nothing — the '
              'section was only read from a runtime services block, so the '
              'value never appeared and nothing said why');
    });

    test('it follows its dependencies', () async {
      await engine.initialize(definition: {
        'type': 'page',
        'content': {'type': 'box'},
        'state': {
          'initial': {'count': 2},
          'computed': {
            'doubled': {
              'expression': '{{count * 2}}',
              'dependencies': ['count'],
            },
          },
        },
      });
      expect(engine.computedManager.getComputed('doubled'), 4);

      engine.stateManager.set('count', 5);
      expect(engine.computedManager.getComputed('doubled'), 10,
          reason: 'a computed value that does not recompute is a stale number '
              'presented as a live one');
    });

    test('a computed value with no dependencies still evaluates', () async {
      await engine.initialize(definition: {
        'type': 'page',
        'content': {'type': 'box'},
        'state': {
          'initial': {'count': 3},
          'computed': {
            'constant': {'expression': '{{count}}'},
          },
        },
      });

      expect(engine.computedManager.getComputed('constant'), 3);
    });
  });

  group('state.watchers', () {
    test('a watcher runs its actions when the path changes', () async {
      await engine.initialize(definition: {
        'type': 'page',
        'content': {'type': 'box'},
        'state': {
          'initial': {'temperature': 20},
          'watchers': [
            {
              'watch': 'temperature',
              'actions': [set('alerted', true)],
            },
          ],
        },
      });

      expect(engine.stateManager.get('alerted'), isNull);
      engine.stateManager.set('temperature', 30);

      expect(engine.stateManager.get('alerted'), isTrue);
    });

    test('the new and old values are both in scope', () async {
      await engine.initialize(definition: {
        'type': 'page',
        'content': {'type': 'box'},
        'state': {
          'initial': {'temperature': 20},
          'watchers': [
            {
              'watch': 'temperature',
              'actions': [
                set('seen', '{{value}}'),
                set('previous', '{{oldValue}}'),
              ],
            },
          ],
        },
      });

      engine.stateManager.set('temperature', 30);

      expect(engine.stateManager.get('seen'), 30);
      expect(engine.stateManager.get('previous'), 20,
          reason: 'the previous value is the whole reason a watcher is not '
              'just a rebuild — "it went up" needs both');
    });

    test('a condition that is false stops the actions', () async {
      await engine.initialize(definition: {
        'type': 'page',
        'content': {'type': 'box'},
        'state': {
          'initial': {'temperature': 20},
          'watchers': [
            {
              'watch': 'temperature',
              'condition': '{{value > 25}}',
              'actions': [set('alerted', true)],
            },
          ],
        },
      });

      engine.stateManager.set('temperature', 22);
      expect(engine.stateManager.get('alerted'), isNull,
          reason: 'a condition that never refuses is a condition the document '
              'may as well not have written');

      engine.stateManager.set('temperature', 30);
      expect(engine.stateManager.get('alerted'), isTrue);
    });

    test('immediate delivers the current value at registration', () async {
      await engine.initialize(definition: {
        'type': 'page',
        'content': {'type': 'box'},
        'state': {
          'initial': {'temperature': 20},
          'watchers': [
            {
              'watch': 'temperature',
              'immediate': true,
              'actions': [set('seen', '{{value}}')],
            },
          ],
        },
      });

      expect(engine.stateManager.get('seen'), 20);
    });

    test('a single action map is accepted as well as a list', () async {
      await engine.initialize(definition: {
        'type': 'page',
        'content': {'type': 'box'},
        'state': {
          'initial': {'temperature': 20},
          'watchers': [
            {
              'watch': 'temperature',
              'handler': set('alerted', true),
            },
          ],
        },
      });

      engine.stateManager.set('temperature', 30);
      expect(engine.stateManager.get('alerted'), isTrue);
    });

    test('a watcher with no actions is inert, not fatal', () async {
      await engine.initialize(definition: {
        'type': 'page',
        'content': {'type': 'box'},
        'state': {
          'initial': {'temperature': 20},
          'watchers': [
            {'watch': 'temperature'},
          ],
        },
      });

      engine.stateManager.set('temperature', 30);
      expect(engine.stateManager.get('temperature'), 30);
    });
  });

  group('pause and resume', () {
    Future<void> withLifecycle() => engine.initialize(definition: {
          'type': 'page',
          'content': {'type': 'box'},
          'lifecycle': {
            'onPause': [set('phase', 'paused')],
            'onResume': [set('phase', 'resumed')],
          },
        });

    test('the document\'s own onPause and onResume run', () async {
      await withLifecycle();
      await engine.markReady();

      await engine.pause();
      expect(engine.stateManager.get('phase'), 'paused',
          reason: 'this used to read only the legacy runtime config, so an '
              'onPause written in the document never ran — and a stream left '
              'open in the background is what that costs');

      await engine.resume();
      expect(engine.stateManager.get('phase'), 'resumed');
    });

    // The `_runtimeConfig['lifecycle']` fallback beside each of these hooks
    // cannot be reached from any document: that config is DERIVED from the
    // same parsed definition the first branch reads, so whenever the fallback
    // would have something the first branch already had it. Recorded rather
    // than exercised — removing it is a call for whoever owns the legacy
    // shape.

    test('an engine that is not ready ignores both', () async {
      final fresh = RuntimeEngine(enableDebugMode: false);
      addTearDown(fresh.destroy);

      await fresh.pause();
      await fresh.resume();

      expect(fresh.isReady, isFalse);
    });
  });

  group('the parts a host reaches through the engine', () {
    setUp(() => engine.initialize(definition: {
          'type': 'page',
          'content': {'type': 'box'},
        }));

    test('each subsystem is exposed and is the one the engine uses', () {
      // A host wires notifications, offline queues and plugins through these.
      // An accessor that built a second instance would hand the host an object
      // nothing else in the runtime is talking to.
      expect(engine.responsiveResolver, isNotNull);
      expect(engine.eventBus, isNotNull);
      expect(engine.connectivityManager, isNotNull);
      expect(engine.offlineQueue, isNotNull);
      expect(engine.syncManager, isNotNull);
      expect(engine.pluginManager, isNotNull);
      expect(engine.backgroundServiceManager, isNotNull);
      expect(engine.cache, isNotNull);

      expect(identical(engine.syncManager, engine.syncManager), isTrue);
      expect(identical(engine.eventBus, engine.eventBus), isTrue);
    });

    test('the permission manager is the action handler\'s own', () {
      expect(engine.permissionManager,
          same(engine.actionHandler.permissionManager),
          reason: 'two permission managers means a host granting on one and '
              'the runtime checking the other');
    });

    test('navigationService answers whether one is registered or not', () {
      // Null here is an answer, not a failure: a runtime with no navigation
      // service is a page embedded in a host that owns navigation itself.
      expect(() => engine.navigationService, returnsNormally);
    });
  });

  group('loading a page with no loader', () {
    test('an application without one is refused at initialize', () async {
      // Not at the first navigation, which is a screen the user is already
      // looking at: an application whose routes can never be fetched cannot
      // start at all.
      await expectLater(
        engine.initialize(definition: {
          'type': 'application',
          'title': 'T',
          'version': '1.0.0',
          'initialRoute': '/home',
          'routes': {'/home': 'ui://pages/home'},
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('a page runtime refuses loadPage by name rather than hanging',
        () async {
      await engine.initialize(definition: {
        'type': 'page',
        'content': {'type': 'box'},
      });

      await expectLater(
        engine.loadPage('/home'),
        throwsA(isA<StateError>()),
        reason: 'a document waiting on a Future that never completes shows a '
            'spinner forever',
      );
    });
  });
}
