// `ComputedManager` had 1 of 121 lines covered. It caches derived values and
// fires watchers, so both of its failure modes are quiet: a stale cache shows
// yesterday's number, and a watcher that does not fire leaves a screen that
// simply never updates.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/state/computed_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';

void main() {
  late StateManager state;
  late BindingEngine binding;
  late ComputedManager manager;

  setUp(() {
    state = StateManager();
    state.initialize(<String, dynamic>{'a': 1, 'b': 2});
    binding = BindingEngine();
    manager = ComputedManager(stateManager: state, bindingEngine: binding);
  });

  tearDown(() => manager.dispose());

  group('computed properties', () {
    test('a computed value reads through to state', () {
      manager.registerComputed(
        'sum',
        ComputedConfig(expression: '{{a}}', dependencies: const ['a']),
      );
      expect(manager.getComputed('sum'), 1);
      // Regression: every evaluation used to throw. `_recompute` hands
      // `BindingEngine` a `SimpleComputedContext`, and the engine's chain asks
      // that context for `themeManager` before it knows whether the path is a
      // theme path — the context refused, so no computed property resolved.
    });

    test('a dependency change invalidates the cache', () {
      manager.registerComputed(
        'mirror',
        ComputedConfig(expression: '{{a}}', dependencies: const ['a']),
      );
      expect(manager.getComputed('mirror'), 1);

      state.set('a', 99);
      expect(manager.getComputed('mirror'), 99,
          reason: 'the cache exists to avoid recomputing, not to freeze the '
              'value it first saw');
    });

    test('an unregistered key is null rather than an error', () {
      expect(manager.getComputed('nothing'), isNull);
    });
  });

  // A watcher on a COMPUTED key, rather than on a plain state path. The
  // watcher reads its value back through the same lookup the manager uses, and
  // that lookup has two arms — computed first, then state. The computed arm
  // had never run, so a screen watching a derived total was the one shape
  // nobody had checked.
  group('a watcher on a computed key', () {
    test('receives the derived value, not null', () {
      manager.registerComputed(
        'sum',
        ComputedConfig(
            expression: '{{a + b}}', dependencies: const ['a', 'b']),
      );

      final seen = <dynamic>[];
      manager.registerWatcher(
        'sum',
        WatcherConfig(handler: (value, _) => seen.add(value)),
      );

      state.set('a', 10);

      expect(seen, isNotEmpty,
          reason: 'the dependency moved, so the derived value did — a watcher '
              'that never fires is a total that never updates');
      expect(seen.last, 12,
          reason: 'and it has to be the DERIVED value; reading the state path '
              '`sum`, which does not exist, answers null and blanks the label');
    });
  });

  group('watchers', () {
    test('a watcher fires on change, with the previous value', () {
      final seen = <List<dynamic>>[];
      manager.registerWatcher(
        'a',
        WatcherConfig(handler: (v, old) => seen.add(<dynamic>[v, old])),
      );

      state.set('a', 5);
      expect(seen, hasLength(1));
      expect(seen.single[0], 5);
      expect(seen.single[1], 1);
      // Regression: the baseline was primed only for `immediate` watchers, so
      // the first change reported `null` as the old value.
    });

    test('an unchanged value does not fire', () {
      var calls = 0;
      manager.registerWatcher(
        'a',
        WatcherConfig(handler: (v, old) => calls++),
      );

      state.set('a', 1); // same value
      expect(calls, 0,
          reason: 'firing on every set would make a watcher a frame counter');
      // Regression: with no baseline the first comparison was against null,
      // so setting the same value again read as a change.
    });

    test('immediate delivers the current value at registration time', () {
      final seen = <dynamic>[];
      manager.registerWatcher(
        'b',
        WatcherConfig(
          handler: (v, old) => seen.add(v),
          immediate: true,
        ),
      );
      expect(seen, <dynamic>[2]);

      // …and the immediate delivery must not count as "already seen 2" in a
      // way that swallows the next real change.
      state.set('b', 7);
      expect(seen, <dynamic>[2, 7]);
    });

    test('deep watching sees a mutated map, shallow equality does not', () {
      state.set('m', <String, dynamic>{'x': 1});

      final shallow = <dynamic>[];
      final deep = <dynamic>[];
      manager.registerWatcher(
          'm', WatcherConfig(handler: (v, o) => shallow.add(v)));
      manager.registerWatcher('m',
          WatcherConfig(handler: (v, o) => deep.add(v), deep: true));

      state.set('m', <String, dynamic>{'x': 2});

      expect(deep, hasLength(1));
      expect(shallow, hasLength(1),
          reason: 'a replaced map is a new identity, so both notice; the '
              'difference between deep and shallow shows on equal content');

      // Same content, new instance: deep must stay quiet.
      final before = deep.length;
      state.set('m', <String, dynamic>{'x': 2});
      expect(deep.length, before,
          reason: 'deep compares content — an identical map is not a change');
    });

    test('several watchers on one path all fire', () {
      var first = 0, second = 0;
      manager.registerWatcher('a', WatcherConfig(handler: (v, o) => first++));
      manager.registerWatcher('a', WatcherConfig(handler: (v, o) => second++));

      state.set('a', 42);
      expect(first, 1);
      expect(second, 1);
    });
  });

  test('dispose drops computed values and watchers', () {
    var calls = 0;
    manager.registerComputed(
      'c',
      ComputedConfig(expression: '{{a}}', dependencies: const ['a']),
    );
    manager.registerWatcher('a', WatcherConfig(handler: (v, o) => calls++));

    manager.dispose();

    expect(manager.getComputed('c'), isNull);
    final before = calls;
    state.set('a', 1234);
    expect(calls, before,
        reason: 'a disposed manager must not keep delivering');
    // Regression: `dispose` cleared its own maps but left its closures on the
    // shared StateManager, so a discarded manager kept delivering.
  });
}
