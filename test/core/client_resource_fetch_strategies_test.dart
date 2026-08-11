// The caching strategies, the fallback chain and the state notifications of
// `ClientResourceManager`.
//
// The sibling file covers URI parsing, size limits and the transform pipeline.
// What was left uncovered is everything that decides WHETHER A FETCH HAPPENS —
// four strategies, three kinds of fallback, TTL expiry, background refresh —
// and the listener callbacks a widget uses to show a spinner. All of it fails
// quietly by nature: the wrong strategy shows stale data, a broken fallback
// shows nothing, and a missed notification leaves a spinner turning forever.

import 'package:flutter_mcp_ui_runtime/src/core/client_resource_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(ClientResourceManager.resetInstance);

  ClientResourceManager managerReturning(List<dynamic> values) {
    var index = 0;
    return ClientResourceManager.instance
      ..setFetcher((uri) async =>
          values[index < values.length ? index++ : values.length - 1]);
  }

  group('cacheFirst', () {
    test('an entry past its ttl is refreshed rather than served', () async {
      var calls = 0;
      final manager = ClientResourceManager.instance
        ..setFetcher((uri) async => 'v${++calls}');

      // ttl 0 means "no expiration" per the config doc, so this uses a real
      // one-second ttl and waits it out — the branch under test is the
      // expiry check, and faking the clock would skip it.
      const config =
          ResourceFetchConfig(uri: 'client://config/ttl', ttlSeconds: 1);
      expect(await manager.fetch(config), 'v1');
      await Future<void>.delayed(const Duration(milliseconds: 1100));

      expect(await manager.fetch(config), 'v2',
          reason: 'an expired entry is stale, and cacheFirst only serves what '
              'is usable — serving it anyway is how a document shows '
              'yesterday\'s numbers indefinitely');
    });
  });

  group('cacheOnly', () {
    test('never asks the fetcher, even with nothing cached', () async {
      var calls = 0;
      final manager = ClientResourceManager.instance
        ..setFetcher((uri) async => 'from network ${++calls}');

      final result = await manager.fetch(const ResourceFetchConfig(
        uri: 'client://config/offline',
        strategy: CachingStrategy.cacheOnly,
        fallback: ResourceFallback(value: 'offline placeholder'),
      ));

      expect(calls, 0,
          reason: 'cacheOnly is what a document uses when it must not touch '
              'the network — one call defeats the entire declaration');
      expect(result, 'offline placeholder');
    });

    test('serves a cached value when there is one', () async {
      final manager = managerReturning(['fetched']);

      // Warm the cache through an ordinary fetch first.
      await manager.fetch(const ResourceFetchConfig(uri: 'client://config/c'));
      final result = await manager.fetch(const ResourceFetchConfig(
        uri: 'client://config/c',
        strategy: CachingStrategy.cacheOnly,
      ));

      expect(result, 'fetched');
    });

    test('with nothing cached and no fallback the answer is null', () async {
      final manager = managerReturning(['never asked']);
      final result = await manager.fetch(const ResourceFetchConfig(
        uri: 'client://config/nothing',
        strategy: CachingStrategy.cacheOnly,
      ));
      expect(result, isNull);
    });
  });

  group('staleWhileRevalidate', () {
    test('the stale value is returned immediately and refreshed behind it',
        () async {
      var calls = 0;
      final manager = ClientResourceManager.instance
        ..setFetcher((uri) async => 'v${++calls}');

      const config = ResourceFetchConfig(
        uri: 'client://config/swr',
        strategy: CachingStrategy.staleWhileRevalidate,
        ttlSeconds: 1,
      );

      expect(await manager.fetch(config), 'v1');
      await Future<void>.delayed(const Duration(milliseconds: 1100));

      // The point of the strategy: the caller does not wait.
      expect(await manager.fetch(config), 'v1',
          reason: 'stale data now beats fresh data later — returning v2 here '
              'would make this networkFirst with extra steps');

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(manager.getCached('client://config/swr'), 'v2',
          reason: 'and the background refresh has to actually land, or the '
              'value is stale forever');
    });

    test('a background refresh that fails leaves the last good value in place',
        () async {
      var calls = 0;
      final manager = ClientResourceManager.instance
        ..setFetcher((uri) async {
          calls++;
          if (calls > 1) throw StateError('server down');
          return 'good';
        });

      const config = ResourceFetchConfig(
        uri: 'client://config/swr-fail',
        strategy: CachingStrategy.staleWhileRevalidate,
        ttlSeconds: 1,
        fallback: ResourceFallback(useLastKnown: true),
      );

      expect(await manager.fetch(config), 'good');
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(await manager.fetch(config), 'good');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(manager.getState('client://config/swr-fail'),
          ResourceLifecycleState.error,
          reason: 'the failure is recorded so a document can show it');
    });
  });

  group('fallbacks', () {
    test('useLastKnown returns the previous value when the fetch fails',
        () async {
      var calls = 0;
      final manager = ClientResourceManager.instance
        ..setFetcher((uri) async {
          calls++;
          if (calls > 1) throw StateError('server down');
          return 'first good value';
        });

      const config = ResourceFetchConfig(
        uri: 'client://config/lastknown',
        strategy: CachingStrategy.networkOnly,
        fallback: ResourceFallback(useLastKnown: true),
      );

      expect(await manager.fetch(config), 'first good value');
      expect(await manager.fetch(config), 'first good value',
          reason: 'a dashboard that blanks on the first failed poll is worse '
              'than one showing a value from a minute ago');
    });

    test('an alternative uri is tried, and its own failure does not recurse',
        () async {
      final asked = <String>[];
      final manager = ClientResourceManager.instance
        ..setFetcher((uri) async {
          asked.add(uri.path);
          if (uri.path == 'primary') throw StateError('gone');
          return 'from the alternative';
        });

      final result = await manager.fetch(const ResourceFetchConfig(
        uri: 'client://config/primary',
        strategy: CachingStrategy.networkOnly,
        fallback: ResourceFallback(alternativeUri: 'client://config/backup'),
      ));

      expect(result, 'from the alternative');
      expect(asked, ['primary', 'backup']);
    });

    test('the alternative is fetched WITHOUT a fallback of its own', () async {
      // Stated in the implementation as loop prevention, and worth pinning:
      // two resources naming each other as alternatives would otherwise
      // recurse until the stack gives out.
      var calls = 0;
      final manager = ClientResourceManager.instance
        ..setFetcher((uri) async {
          calls++;
          throw StateError('everything is down');
        });

      final result = await manager.fetch(const ResourceFetchConfig(
        uri: 'client://config/a',
        strategy: CachingStrategy.networkOnly,
        fallback: ResourceFallback(alternativeUri: 'client://config/b'),
      ));

      expect(result, isNull);
      expect(calls, 2, reason: 'primary, then alternative, then stop');
    });

    test('a static value is the last resort', () async {
      final manager = ClientResourceManager.instance
        ..setFetcher((uri) async => throw StateError('down'));

      final result = await manager.fetch(const ResourceFetchConfig(
        uri: 'client://config/static',
        strategy: CachingStrategy.networkOnly,
        fallback: ResourceFallback(value: <String, dynamic>{'rows': []}),
      ));

      expect(result, <String, dynamic>{'rows': []});
    });

    test('with no fetcher configured at all the fallback still answers',
        () async {
      ClientResourceManager.resetInstance();
      final result = await ClientResourceManager.instance.fetch(
        const ResourceFetchConfig(
          uri: 'client://config/nofetcher',
          fallback: ResourceFallback(value: 'placeholder'),
        ),
      );
      expect(result, 'placeholder',
          reason: 'a host that never wired a fetcher is a configuration '
              'mistake, but the document still has to render something');
    });

    test('data over the size limit is refused and the fallback used',
        () async {
      final manager = ClientResourceManager.instance
        ..setFetcher((uri) async => 'x' * (ResourceSizeLimits.cacheEntry + 1));

      final result = await manager.fetch(const ResourceFetchConfig(
        uri: 'client://cache/huge',
        strategy: CachingStrategy.networkOnly,
        fallback: ResourceFallback(value: 'too big'),
      ));

      expect(result, 'too big',
          reason: 'the limit is there to stop a runaway response from being '
              'held in memory — accepting it and then reporting would be too '
              'late');
      expect(manager.getState('client://cache/huge'),
          ResourceLifecycleState.error);
    });
  });

  group('state notifications', () {
    test('a subscriber sees loading, then ready, with the data', () async {
      final states = <ResourceLifecycleState>[];
      final payloads = <dynamic>[];
      final manager = managerReturning(['the data']);

      manager.subscribe('client://config/watch', (uri, state, data) {
        states.add(state);
        payloads.add(data);
      });

      await manager.fetch(const ResourceFetchConfig(uri: 'client://config/watch'));

      expect(states, [
        ResourceLifecycleState.loading,
        ResourceLifecycleState.ready,
      ], reason: 'the loading edge is what raises a spinner; without it the '
          'screen sits blank and then jumps');
      expect(payloads.last, 'the data');
    });

    test('a failure is announced as error', () async {
      final states = <ResourceLifecycleState>[];
      final manager = ClientResourceManager.instance
        ..setFetcher((uri) async => throw StateError('down'));

      manager.subscribe('client://config/fails', (uri, state, data) {
        states.add(state);
      });

      await manager.fetch(const ResourceFetchConfig(
          uri: 'client://config/fails', strategy: CachingStrategy.networkOnly));

      expect(states.last, ResourceLifecycleState.error);
    });

    test('an unsubscribed callback stops hearing', () async {
      final heard = <ResourceLifecycleState>[];
      void listener(String uri, ResourceLifecycleState state, dynamic data) =>
          heard.add(state);

      final manager = managerReturning(['a', 'b']);
      manager.subscribe('client://config/off', listener);
      await manager.fetch(const ResourceFetchConfig(uri: 'client://config/off'));
      final countWhileSubscribed = heard.length;

      manager.unsubscribe('client://config/off', listener);
      await manager.fetch(const ResourceFetchConfig(
          uri: 'client://config/off', forceRefresh: true));

      expect(heard, hasLength(countWhileSubscribed),
          reason: 'a callback that keeps firing after the widget that owned '
              'it is gone writes into a disposed state');
    });

    test('one throwing subscriber does not stop the next', () async {
      final second = <ResourceLifecycleState>[];
      final manager = managerReturning(['data']);

      manager.subscribe('client://config/throwers',
          (uri, state, data) => throw StateError('bad listener'));
      manager.subscribe(
          'client://config/throwers', (uri, state, data) => second.add(state));

      await manager
          .fetch(const ResourceFetchConfig(uri: 'client://config/throwers'));

      expect(second, isNotEmpty,
          reason: 'one badly written widget must not silence every other '
              'widget bound to the same resource');
    });

    test('subscribers of another uri hear nothing', () async {
      final other = <String>[];
      final manager = managerReturning(['data']);
      manager.subscribe('client://config/other', (uri, s, d) => other.add(uri));

      await manager.fetch(const ResourceFetchConfig(uri: 'client://config/mine'));

      expect(other, isEmpty);
    });
  });

  group('invalidation and disposal', () {
    test('invalidate forces the next read to go back to the source', () async {
      var calls = 0;
      final manager = ClientResourceManager.instance
        ..setFetcher((uri) async => 'v${++calls}');

      const config = ResourceFetchConfig(uri: 'client://config/inv');
      expect(await manager.fetch(config), 'v1');
      manager.invalidate('client://config/inv');

      expect(manager.getState('client://config/inv'),
          ResourceLifecycleState.expired);
      expect(await manager.fetch(config), 'v2');
    });

    test('invalidateAll expires every entry and tells every subscriber',
        () async {
      final heard = <String>[];
      final manager = managerReturning(['a', 'b']);
      await manager.fetch(const ResourceFetchConfig(uri: 'client://config/x'));
      await manager.fetch(const ResourceFetchConfig(uri: 'client://config/y'));

      manager.subscribe('client://config/x', (uri, s, d) => heard.add(uri));
      manager.subscribe('client://config/y', (uri, s, d) => heard.add(uri));
      manager.invalidateAll();

      expect(heard, unorderedEquals(['client://config/x', 'client://config/y']));
      expect(manager.getCached('client://config/x'), isNull,
          reason: 'an expired entry is not usable, so getCached answers '
              'nothing rather than the stale value');
    });

    test('disposing a resource releases its data and its listeners', () async {
      final heard = <ResourceLifecycleState>[];
      final manager = managerReturning(['data', 'data2']);
      manager.subscribe('client://config/d', (uri, s, d) => heard.add(s));
      await manager.fetch(const ResourceFetchConfig(uri: 'client://config/d'));

      manager.disposeResource('client://config/d');

      expect(heard.last, ResourceLifecycleState.disposed,
          reason: 'the last thing a listener hears is that it is over');
      expect(manager.getState('client://config/d'), isNull);
      expect(manager.getCached('client://config/d'), isNull);

      final before = heard.length;
      await manager.fetch(const ResourceFetchConfig(uri: 'client://config/d'));
      expect(heard, hasLength(before),
          reason: 'the listener list went with the resource');
    });

    test('getState and getCached answer nothing for a uri never fetched', () {
      final manager = ClientResourceManager.instance;
      expect(manager.getState('client://config/unknown'), isNull);
      expect(manager.getCached('client://config/unknown'), isNull);
    });

    test('clear empties the cache, and dispose drops the fetcher too',
        () async {
      final manager = managerReturning(['data']);
      await manager.fetch(const ResourceFetchConfig(uri: 'client://config/c1'));

      manager.clear();
      expect(manager.getCached('client://config/c1'), isNull);

      manager.dispose();
      final afterDispose = await manager.fetch(const ResourceFetchConfig(
        uri: 'client://config/c1',
        fallback: ResourceFallback(value: 'no fetcher'),
      ));
      expect(afterDispose, 'no fetcher',
          reason: 'dispose unwires the fetcher; a manager that kept calling '
              'it would keep a closed host\'s callback alive');
    });
  });

  group('parseStrategy', () {
    test('every documented name maps to its own strategy', () {
      expect(ClientResourceManager.parseStrategy('networkFirst'),
          CachingStrategy.networkFirst);
      expect(ClientResourceManager.parseStrategy('cacheFirst'),
          CachingStrategy.cacheFirst);
      expect(ClientResourceManager.parseStrategy('staleWhileRevalidate'),
          CachingStrategy.staleWhileRevalidate);
      expect(ClientResourceManager.parseStrategy('networkOnly'),
          CachingStrategy.networkOnly);
      expect(ClientResourceManager.parseStrategy('cacheOnly'),
          CachingStrategy.cacheOnly);
    });

    test('an unknown or absent name falls back to cacheFirst', () {
      expect(ClientResourceManager.parseStrategy('telepathy'),
          CachingStrategy.cacheFirst);
      expect(ClientResourceManager.parseStrategy(null),
          CachingStrategy.cacheFirst,
          reason: 'the safe default is the one that still serves something '
              'when the network is gone');
    });
  });
}
