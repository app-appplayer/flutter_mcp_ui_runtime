// The engine's channel wiring and its app cache.
//
// Two blocks that were uncovered for the same reason: both only run for a
// document that declares something most test documents do not. The channel
// callbacks (`statePath`, `onData`, `onError`, `onConnect`, `onDisconnect`)
// are how live data reaches a screen at all — a dropped one is a panel that
// stops updating with nothing in the log. The cache is what makes a bundle
// open offline, and a cache that never writes looks exactly like one that
// never reads.

import 'package:flutter_mcp_ui_runtime/src/runtime/runtime_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RuntimeEngine engine;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    engine = RuntimeEngine(enableDebugMode: false);
  });

  tearDown(() => engine.destroy());

  Future<void> initialize(Map<String, dynamic> definition) =>
      engine.initialize(definition: definition);

  Map<String, dynamic> pageWith(Map<String, dynamic> channels) => {
        'type': 'page',
        'content': {'type': 'text', 'content': 'x'},
        'channels': channels,
      };

  group('channel callbacks declared on the document', () {
    test('data lands at the declared statePath', () async {
      await initialize(pageWith({
        'feed': {
          'type': 'client.mcpStream',
          'params': {'uri': 'mcp://feed'},
          'statePath': 'latest',
        },
      }));

      // The manager owns the transport; what the engine owns is the routing.
      engine.channelManager.onData?.call('feed', {'temperature': 21});

      expect(engine.stateManager.get('latest'), {'temperature': 21},
          reason: '`statePath` is the shortest way a document gets live data '
              'onto a screen — dropping it leaves the panel empty with the '
              'channel reporting itself connected');
    });

    test('onData runs the declared action with the payload in scope',
        () async {
      await initialize(pageWith({
        'feed': {
          'type': 'client.mcpStream',
          'params': {'uri': 'mcp://feed'},
          'onData': {
            'type': 'state',
            'action': 'set',
            'binding': 'seen',
            'value': '{{data.temperature}}',
          },
        },
      }));

      engine.channelManager.onData?.call('feed', {'temperature': 21});
      await Future<void>.delayed(Duration.zero);

      expect(engine.stateManager.get('seen'), 21,
          reason: 'the payload is published as `data` — an action that cannot '
              'see it can only know that something arrived');
    });

    test('onError runs with the message in scope', () async {
      await initialize(pageWith({
        'feed': {
          'type': 'client.mcpStream',
          'params': {'uri': 'mcp://feed'},
          'onError': {
            'type': 'state',
            'action': 'set',
            'binding': 'lastError',
            'value': '{{error}}',
          },
        },
      }));

      engine.channelManager.onError?.call('feed', StateError('wire broke'));
      await Future<void>.delayed(Duration.zero);

      expect(engine.stateManager.get<String>('lastError'), contains('wire'),
          reason: 'a feed that stops without saying why reads as a feed with '
              'nothing to report');
    });

    test('onConnect and onDisconnect each fire for their own transition',
        () async {
      await initialize(pageWith({
        'feed': {
          'type': 'client.mcpStream',
          'params': {'uri': 'mcp://feed'},
          'onConnect': {
            'type': 'state',
            'action': 'set',
            'binding': 'state',
            'value': 'connected',
          },
          'onDisconnect': {
            'type': 'state',
            'action': 'set',
            'binding': 'state',
            'value': 'disconnected',
          },
        },
      }));

      engine.channelManager.onConnect?.call('feed');
      await Future<void>.delayed(Duration.zero);
      expect(engine.stateManager.get('state'), 'connected');

      engine.channelManager.onDisconnect?.call('feed');
      await Future<void>.delayed(Duration.zero);
      expect(engine.stateManager.get('state'), 'disconnected',
          reason: '§8.6.4 — the two transitions are what a connection '
              'indicator is bound to');
    });

    test('a callback for a channel nobody declared changes nothing', () async {
      await initialize(pageWith({
        'feed': {
          'type': 'client.mcpStream',
          'params': {'uri': 'mcp://feed'},
          'statePath': 'latest',
        },
      }));

      engine.channelManager.onData?.call('ghost', {'temperature': 99});
      engine.channelManager.onError?.call('ghost', StateError('x'));
      engine.channelManager.onConnect?.call('ghost');
      engine.channelManager.onDisconnect?.call('ghost');
      await Future<void>.delayed(Duration.zero);

      expect(engine.stateManager.get('latest'), isNull,
          reason: 'routing an unknown channel\'s data into the first '
              'channel\'s statePath would put one feed\'s numbers under '
              'another feed\'s name');
    });

    test('a channel with neither statePath nor handlers is still registered',
        () async {
      await initialize(pageWith({
        'quiet': {
          'type': 'client.mcpStream',
          'params': {'uri': 'mcp://quiet'},
        },
      }));

      expect(engine.channelManager.hasChannel('quiet'), isTrue);
      engine.channelManager.onData?.call('quiet', 1);
      await Future<void>.delayed(Duration.zero);
      expect(engine.stateManager.state.containsKey('quiet'), isFalse);
    });
  });

  group('the theme declared under runtime.services', () {
    test('is applied, and the application-level theme is too', () async {
      await initialize({
        'type': 'page',
        'content': {'type': 'text', 'content': 'x'},
        'runtime': {
          'services': {
            'theme': {
              'mode': 'light',
              'colors': {'primary': '#123456'},
            },
          },
        },
      });

      expect(engine.themeManager.getColorValue('primary'), isNotNull,
          reason: 'this is the location the spec prefers; reading only the '
              'top-level `theme` leaves a document\'s palette unapplied');
    });
  });

  group('the app cache', () {
    Map<String, dynamic> application(String version) => {
          'type': 'application',
          'domain': 'example.com',
          'id': 'reports',
          'version': version,
          'title': 'Reports',
          'routes': {'/': 'main'},
          'initialState': {'greeting': 'from the document'},
        };

    test('an application with a domain, id and version is cached and read '
        'back', () async {
      await engine.initialize(
        definition: application('1.0.0'),
        pageLoader: (_) async => {},
      );
      await engine.destroy();

      // A second engine over the same identity finds the cached definition.
      final second = RuntimeEngine(enableDebugMode: false);
      addTearDown(second.destroy);
      await second.initialize(
        definition: application('1.0.0'),
        pageLoader: (_) async => {},
      );

      expect(second.isApplication, isTrue);
      expect(second.stateManager.get('greeting'), 'from the document',
          reason: 'the cached state is what makes a bundle reopen where the '
              'user left it — an empty read is indistinguishable from a first '
              'launch');
    });

    test('a definition with no identity is not cached at all', () async {
      await engine.initialize(
        definition: {
          'type': 'application',
          'title': 'Anonymous',
          'version': '1.0.0',
          'routes': {'/': 'main'},
        },
        pageLoader: (_) async => {},
      );

      expect(engine.isApplication, isTrue,
          reason: 'no domain / id means nothing to key a cache by — the app '
              'still has to open, it simply opens cold every time');
    });

    test('useCache: false skips the cache entirely', () async {
      await engine.initialize(
        definition: application('1.0.0'),
        pageLoader: (_) async => {},
        useCache: false,
      );

      expect(engine.isApplication, isTrue);
    });
  });
}
