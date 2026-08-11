// `SimpleComputedContext` — the cut-down render context a computed property
// is evaluated in, and the watcher bookkeeping around it.
//
// It exists so a computed expression can be evaluated with no widget tree at
// all, which means every member is either "the small part that works" or an
// explicit refusal. The refusals matter: a computed expression that reached
// the action handler or built a child context would be running document code
// outside any frame, and the exception is what says so.

import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/state/computed_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StateManager stateManager;
  late BindingEngine bindingEngine;
  late ComputedManager manager;

  setUp(() {
    stateManager = StateManager()..initialize(<String, dynamic>{});
    bindingEngine = BindingEngine();
    manager = ComputedManager(
      stateManager: stateManager,
      bindingEngine: bindingEngine,
    );
  });

  tearDown(() {
    manager.dispose();
    bindingEngine.dispose();
  });

  group('the computed context', () {
    late SimpleComputedContext context;

    setUp(() {
      stateManager.set('count', 3);
      context = SimpleComputedContext(stateManager);
    });

    test('reads state, and writes back through it', () {
      expect(context.getValue<int>('count'), 3);
      expect(context.getState<int>('count'), 3);

      context.setValue('count', 5);
      expect(stateManager.get('count'), 5);

      context.setState('count', 7);
      expect(stateManager.get('count'), 7,
          reason: 'the two spellings are one operation; a document written '
              'either way has to reach the same state');
    });

    test('resolve passes a matching value through and stringifies for String',
        () {
      expect(context.resolve<int>(3), 3);
      expect(context.resolve<String>(3), '3');
    });

    test('it exposes the state manager and the theme', () {
      expect(context.stateManager, same(stateManager));
      expect(context.themeManager, isNotNull,
          reason: 'the binding engine consults the theme for any path it did '
              'not find in state — refusing here threw on EVERY computed '
              'property, not only the ones that mention a theme');
    });

    test('it has no build context, no parent and no local variables', () {
      expect(context.buildContext, isNull);
      expect(context.parentId, isNull);
      expect(context.localVariables, isEmpty);
      expect(context.contextId, 'computed');
    });

    test('everything that needs a frame is refused by name', () {
      expect(() => context.engine, throwsUnsupportedError);
      expect(() => context.renderer, throwsUnsupportedError);
      expect(() => context.bindingEngine, throwsUnsupportedError);
      expect(() => context.actionHandler, throwsUnsupportedError,
          reason: 'a computed expression that could run an action would be '
              'running document code outside any frame');
      expect(() => context.theme, throwsUnsupportedError);
      expect(context.createChildContext, throwsUnsupportedError);
    });

    test('anything else is refused with the member name in it', () {
      expect(
        () => (context as dynamic).somethingNobodyImplemented(),
        throwsA(isA<UnsupportedError>().having((e) => e.message, 'message',
            contains('somethingNobodyImplemented'))),
        reason: 'a silent null from noSuchMethod would surface as a wrong '
            'value somewhere else entirely',
      );
    });
  });

  group('watchers', () {
    test('a watcher fires on a change and carries both values', () {
      final seen = <List<dynamic>>[];
      stateManager.set('temperature', 20);

      manager.registerWatcher(
        'temperature',
        WatcherConfig(handler: (value, old) => seen.add([value, old])),
      );

      stateManager.set('temperature', 30);

      expect(seen, [
        [30, 20]
      ], reason: 'the previous value is the whole reason a watcher is not just '
          'a rebuild');
    });

    test('an unchanged value does not fire it', () {
      final seen = <dynamic>[];
      stateManager.set('temperature', 20);
      manager.registerWatcher(
        'temperature',
        WatcherConfig(handler: (value, old) => seen.add(value)),
      );

      stateManager.set('temperature', 20);

      expect(seen, isEmpty,
          reason: 'a write of the same value is not a change; firing on it '
              'turns one poll into an action per poll');
    });

    test('immediate delivers the current value at registration', () {
      final seen = <dynamic>[];
      stateManager.set('temperature', 20);

      manager.registerWatcher(
        'temperature',
        WatcherConfig(
          immediate: true,
          handler: (value, old) => seen.add(value),
        ),
      );

      expect(seen, [20]);
    });

    test('a deep watcher notices a change inside a map', () {
      final seen = <dynamic>[];
      stateManager.set('row', {'a': 1});

      manager.registerWatcher(
        'row',
        WatcherConfig(deep: true, handler: (value, old) => seen.add(value)),
      );

      stateManager.set('row', {'a': 2});
      expect(seen, hasLength(1));

      stateManager.set('row', {'a': 2});
      expect(seen, hasLength(1),
          reason: 'an equal map arriving as a new object is not a change — '
              'without the deep comparison every rebuild would fire');
    });

    test('a deep watcher compares lists element by element', () {
      final seen = <dynamic>[];
      stateManager.set('rows', [1, 2]);

      manager.registerWatcher(
        'rows',
        WatcherConfig(deep: true, handler: (value, old) => seen.add(value)),
      );

      stateManager.set('rows', [1, 2]);
      expect(seen, isEmpty);

      stateManager.set('rows', [1, 3]);
      expect(seen, hasLength(1));

      stateManager.set('rows', [1, 2, 3]);
      expect(seen, hasLength(2),
          reason: 'a different length is a different list, whatever the '
              'shared prefix says');
    });

    test('a computed property is readable and recomputes on its dependency',
        () {
      stateManager.set('count', 2);
      manager.registerComputed(
        'doubled',
        ComputedConfig(expression: '{{count * 2}}', dependencies: ['count']),
      );

      expect(manager.getComputed('doubled'), 4);

      stateManager.set('count', 5);
      expect(manager.getComputed('doubled'), 10);
    });

    test('an unknown computed name reads as null', () {
      expect(manager.getComputed('nothing'), isNull);
    });

    test('dispose takes the listeners off the shared state manager', () {
      final seen = <dynamic>[];
      stateManager.set('temperature', 20);
      manager.registerWatcher(
        'temperature',
        WatcherConfig(handler: (value, old) => seen.add(value)),
      );

      manager.dispose();
      stateManager.set('temperature', 30);

      expect(seen, isEmpty,
          reason: 'a discarded manager that goes on delivering keeps a whole '
              'page alive for the life of the state object');
    });
  });
}
