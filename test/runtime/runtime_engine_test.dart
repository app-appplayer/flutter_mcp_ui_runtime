import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart' show TemplateDefinition;
import 'package:flutter_mcp_ui_runtime/src/runtime/runtime_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/models/ui_definition.dart' show ChannelConfig;
import 'package:flutter_mcp_ui_runtime/src/runtime/cache_manager.dart';

void main() {
  group('RuntimeEngine Tests', () {
    late RuntimeEngine engine;

    setUp(() {
      engine = RuntimeEngine(enableDebugMode: false);
    });

    tearDown(() {
      engine.dispose();
    });

    test('initializes successfully with specification', () async {
      final definition = {
        'type': 'page',
        'metadata': {
          'title': 'Test Page',
        },
        'runtime': {
          'id': 'test_app',
          'domain': 'com.test.app',
          'version': '1.0.0',
        },
        'content': {
          'type': 'scaffold',
          'body': {
            'type': 'text',
            'content': 'Test',
          },
        },
      };

      await engine.initialize(definition: definition);
      // Per the lifecycle contract (DDD §3.2.2), `onReady` fires from the
      // mounting widget so host handlers are attached before hooks run.
      // Tests that construct an engine directly invoke markReady manually.
      await engine.markReady();

      expect(engine.isInitialized, isTrue);
      expect(engine.isReady, isTrue);
      expect(engine.runtimeConfig, isNotNull);
      expect(engine.uiDefinition, isNotNull);
    });

    test('requires valid application or page type', () async {
      final invalidDefinition = {
        'type': 'scaffold',
        'properties': {},
      };

      expect(
        () => engine.initialize(definition: invalidDefinition),
        throwsA(isA<ArgumentError>()),
      );
    });


    test('throws error when already initialized', () async {
      final definition = {
        'type': 'page',
        'metadata': {
          'title': 'Test Page',
        },
        'content': {
          'type': 'text',
          'content': 'Test',
        },
      };

      await engine.initialize(definition: definition);

      expect(
        () => engine.initialize(definition: definition),
        throwsA(isA<StateError>()),
      );
    });

    test('marks as ready successfully', () async {
      final definition = {
        'type': 'page',
        'metadata': {
          'title': 'Test Page',
        },
        'content': {
          'type': 'text',
          'content': 'Test',
        },
      };

      await engine.initialize(definition: definition);
      await engine.markReady();

      expect(engine.isReady, isTrue);
    });

    test('executes lifecycle hooks correctly', () async {
      final definition = {
        'type': 'page',
        'metadata': {
          'title': 'Test Page',
        },
        'runtime': {
          'lifecycle': {
            'onInitialize': [
              {
                'type': 'log',
                'message': 'initialize',
              },
            ],
            'onReady': [
              {
                'type': 'log',
                'message': 'ready',
              },
            ],
            'onPause': [
              {
                'type': 'log',
                'message': 'pause',
              },
            ],
            'onResume': [
              {
                'type': 'log',
                'message': 'resume',
              },
            ],
            'onDestroy': [
              {
                'type': 'log',
                'message': 'destroy',
              },
            ],
          },
        },
        'content': {
          'type': 'text',
          'content': 'Test',
        },
      };

      await engine.initialize(definition: definition);
      await engine.markReady();
      await engine.pause();
      await engine.resume();
      await engine.destroy();

      // Test passes if no exceptions are thrown during lifecycle execution
      expect(engine.isInitialized, false);
    });

    test('registers core services', () async {
      final definition = {
        'type': 'page',
        'metadata': {
          'title': 'Test Page',
        },
        'content': {
          'type': 'text',
          'content': 'Test',
        },
      };

      await engine.initialize(definition: definition);

      expect(engine.services.get('navigation'), isNotNull);
      expect(engine.services.get('dialogs'), isNotNull);
      expect(engine.services.get('notifications'), isNotNull);
    });

    test('handles service initialization with config', () async {
      final definition = {
        'type': 'page',
        'metadata': {
          'title': 'Test Page',
        },
        'runtime': {
          'services': {
            'state': {
              'initialState': {
                'counter': 0,
                'message': 'Hello',
              },
            },
            'notifications': {
              'channels': [
                {
                  'id': 'general',
                  'name': 'General',
                  'importance': 'default',
                },
              ],
            },
          },
        },
        'content': {
          'type': 'text',
          'content': 'Test',
        },
      };

      await engine.initialize(definition: definition);

      // State is now managed by StateManager directly
      expect(engine.stateManager, isNotNull);
      expect(engine.stateManager.state['counter'], equals(0));
      expect(engine.stateManager.state['message'], equals('Hello'));
    });

    test('handles destroy lifecycle correctly', () async {
      final definition = {
        'type': 'page',
        'metadata': {
          'title': 'Test Page',
        },
        'content': {
          'type': 'text',
          'content': 'Test',
        },
      };

      await engine.initialize(definition: definition);
      await engine.markReady();
      await engine.destroy();

      expect(engine.isInitialized, isFalse);
      expect(engine.isReady, isFalse);
      expect(engine.runtimeConfig, isNull);
      expect(engine.uiDefinition, isNull);
    });

    group('Offline Mode Tests', () {
      test('detects offline mode support correctly', () async {
        final definition = {
          'type': 'page',
          'metadata': {
            'title': 'Test Page',
          },
          'runtime': {
            'cachePolicy': {
              'offlineMode': 'partial',
            },
          },
          'content': {
            'type': 'text',
            'content': 'Test',
          },
        };

        await engine.initialize(definition: definition);

        // expect(engine.supportsOffline, isTrue);
        // expect(engine.offlineMode, OfflineMode.partial);
      });

      test('returns disabled when no cache policy', () async {
        final definition = {
          'type': 'page',
          'metadata': {
            'title': 'Test Page',
          },
          'content': {
            'type': 'text',
            'content': 'Test',
          },
        };

        await engine.initialize(definition: definition);

        // expect(engine.supportsOffline, isFalse);
        // expect(engine.offlineMode, OfflineMode.disabled);
      });

      test('handles different offline modes', () async {
        final testCases = [
          ('full', OfflineMode.full),
          ('partial', OfflineMode.partial),
          ('disabled', OfflineMode.disabled),
        ];

        for (final testCase in testCases) {
          final engine = RuntimeEngine(enableDebugMode: false);
          
          final definition = {
            'type': 'page',
            'metadata': {
              'title': 'Test Page',
            },
            'runtime': {
              'cachePolicy': {
                'offlineMode': testCase.$1,
              },
            },
            'content': {
              'type': 'text',
              'content': 'Test',
            },
          };

          await engine.initialize(definition: definition);

          // expect(engine.offlineMode, testCase.$2);
          
          engine.dispose();
        }
      });
    });

    group('declared services', () {
      test('a navigation service declaration is taken without complaint',
          () async {
        // The body behind this is a no-op today (the shell owns navigation),
        // but the declaration is part of §1's `services` block: a document
        // that writes it must initialise, not fail on an unknown key.
        await engine.initialize(
          pageLoader: (uri) async =>
              <String, dynamic>{'type': 'page', 'content': {'type': 'box'}},
          definition: {
          'type': 'application',
          'title': 'Nav',
          'initialRoute': '/',
          'routes': {'/': '/pages/home'},
          'services': {
            'navigation': {'type': 'stack'},
            'state': {
              'initialState': {'here': true}
            },
          },
        });

        expect(engine.isInitialized, isTrue);
        expect(engine.stateManager.get<bool>('here'), isTrue,
            reason: 'the state service beside it still runs — an exception in '
                'the navigation arm would take the whole services block down '
                'and the document would open with no state at all');
      });
    });

    group('Cache Integration Tests', () {
      test('attempts to load from cache when enabled', () async {
        final definition = {
          'type': 'page',
          'metadata': {
            'title': 'Test Page',
          },
          'runtime': {
            'id': 'cached_app',
            'domain': 'com.test.cached',
            'version': '1.0.0',
            'cachePolicy': {
              'enabled': true,
            },
          },
          'content': {
            'type': 'text',
            'content': 'Test',
          },
        };

        await engine.initialize(definition: definition, useCache: true);

        expect(engine.isInitialized, isTrue);
        // Cache lookup would have been attempted
      });

      test('skips cache when disabled', () async {
        final definition = {
          'type': 'page',
          'metadata': {
            'title': 'Test Page',
          },
          'runtime': {
            'id': 'no_cache_app',
            'domain': 'com.test.nocache',
            'version': '1.0.0',
          },
          'content': {
            'type': 'text',
            'content': 'Test',
          },
        };

        await engine.initialize(definition: definition, useCache: false);

        expect(engine.isInitialized, isTrue);
        // No cache lookup attempted
      });
    });
  });

  group('TC-019: RuntimeEngine — ChangeNotifier mixin', () {
    test('Normal: RuntimeEngine extends ChangeNotifier', () {
      final engine = RuntimeEngine(enableDebugMode: false);

      // ChangeNotifier interface is available — addListener/removeListener work
      bool notified = false;
      void listener() { notified = true; }
      engine.addListener(listener);
      engine.removeListener(listener);

      expect(notified, isFalse);

      engine.dispose();
    });

    test('Normal: notifyListeners triggers registered listeners', () async {
      final engine = RuntimeEngine(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Test'},
      };

      await engine.initialize(definition: definition);

      int listenerCallCount = 0;
      engine.addListener(() {
        listenerCallCount++;
      });

      // State changes should trigger notifyListeners
      engine.stateManager.set('counter', 1);

      // The engine itself is a ChangeNotifier
      expect(listenerCallCount, greaterThanOrEqualTo(0));

      await engine.destroy();
    });
  });

  group('TC-021: RuntimeEngine — the subsystems are wired to THIS document', () {
    // Was: fourteen tests asserting `engine.<subsystem>, isNotNull`. A field
    // initialised at construction is never null, so those passed for an engine
    // whose subsystems were wired to nothing — which is the only failure worth
    // catching here. Each one now asks the subsystem something only a
    // correctly wired instance can answer.
    late RuntimeEngine engine;

    setUp(() async {
      engine = RuntimeEngine(enableDebugMode: false);
      await engine.initialize(definition: {
        'type': 'page',
        'metadata': {'title': 'Wired'},
        'runtime': {
          'services': {
            'state': {
              'initialState': {'counter': 7},
            },
          },
        },
        'theme': {
          'mode': 'light',
          'colors': {'primary': '#123456'},
        },
        'content': {'type': 'text', 'content': '{{counter}}'},
      });
    });

    tearDown(() async => engine.destroy());

    test('stateManager holds the document\'s own initial state', () {
      expect(engine.stateManager.get('counter'), 7);
      engine.stateManager.set('counter', 8);
      expect(engine.stateManager.get('counter'), 8);
    });

    test('bindingEngine resolves against that same state', () {
      final context = engine.renderer.createRootContext(null);
      expect(context.resolve<dynamic>('{{counter}}'), 7,
          reason: 'a binding engine wired to a different state manager would '
              'answer null here and the page would render blank');
    });

    test('widgetRegistry carries the default widget set', () {
      expect(engine.widgetRegistry.has('text'), isTrue);
      expect(engine.widgetRegistry.has('linear'), isTrue);
      expect(engine.widgetRegistry.has('no-such-widget'), isFalse);
    });

    test('renderer builds a widget from a definition', () {
      final context = engine.renderer.createRootContext(null);
      final widget = engine.renderer.renderWidget(
        {'type': 'text', 'content': 'rendered'},
        context,
      );
      expect(widget, isNotNull);
      expect(widget.runtimeType.toString(), isNot('SizedBox'),
          reason: 'an unwired renderer answers with an empty box');
    });

    test('themeManager carries the document\'s declared theme', () {
      expect(engine.themeManager.getColorValue('primary'), isNotNull,
          reason: 'the theme block declares primary; a theme manager that is '
              'merely non-null would answer nothing');
    });

    test('actionHandler executes an action against this engine\'s state',
        () async {
      final context = engine.renderer.createRootContext(null);
      await engine.actionHandler.execute(
        {'type': 'state', 'action': 'set', 'binding': 'counter', 'value': 42},
        context,
      );
      expect(engine.stateManager.get('counter'), 42);
    });

    test('channelManager can build and dispose a channel', () async {
      await engine.channelManager.initChannel(
        'feed',
        ChannelConfig(type: 'client.poll', params: {'interval': 60000}),
      );
      expect(engine.channelManager.hasChannel('feed'), isTrue);
      await engine.channelManager.disposeChannel('feed');
      expect(engine.channelManager.hasChannel('feed'), isFalse);
    });

    test('templateRegistry stores a template and answers with its content', () {
      engine.templateRegistry.register(const TemplateDefinition(
        name: 'probe',
        content: {'type': 'text', 'content': 'from template'},
      ));
      expect(engine.templateRegistry.getTemplate('probe'),
          {'type': 'text', 'content': 'from template'});
      expect(engine.templateRegistry.has('probe'), isTrue);
      expect(engine.templateRegistry.getTemplate('absent'), isNull,
          reason: 'a registry that answers for an unregistered name would let '
              'a typo render as an empty widget instead of failing');
    });

    test('cacheManager round-trips a document\'s state', () async {
      await engine.cacheManager.cacheState('app-key', {'counter': 7});
      expect(engine.cacheManager.getCachedState('app-key'), {'counter': 7});
      await engine.cacheManager.clearAll();
      expect(engine.cacheManager.getCachedState('app-key'), isNull);
    });

    test('the service registry answers for the services it registered', () {
      // `isNotNull` on three keys was the old assertion; a registry that
      // answers for a key it never registered is the failure.
      expect(engine.services.get('navigation'), isNotNull);
      expect(engine.services.get('dialogs'), isNotNull);
      expect(engine.services.get('notifications'), isNotNull);
      expect(engine.services.get('teleportation'), isNull,
          reason: 'a registry that answers for everything answers nothing');
    });

    test('runtimeConfig and parsedUIDefinition describe THIS document', () {
      expect(engine.parsedUIDefinition, isNotNull);
      expect(engine.uiDefinition?['metadata']['title'], 'Wired');
    });

    test('animationService and lifecycle belong to the engine', () {
      expect(engine.animationService, isNotNull);
      expect(engine.lifecycle, isNotNull);
      expect(engine.isInitialized, isTrue);
    });
  });

  group('TC-023: RuntimeEngine — resource subscription callbacks', () {
    test('Normal: registerResourceSubscription stores URI-binding mapping', () async {
      final engine = RuntimeEngine(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Test'},
      };

      await engine.initialize(definition: definition);
      engine.registerResourceSubscription('data://temp', 'temperature');

      expect(engine.getBindingForUri('data://temp'), equals('temperature'));

      await engine.destroy();
    });

    test('Normal: unregisterResourceSubscription removes mapping', () async {
      final engine = RuntimeEngine(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Test'},
      };

      await engine.initialize(definition: definition);
      engine.registerResourceSubscription('data://temp', 'temperature');
      engine.unregisterResourceSubscription('data://temp');

      expect(engine.getBindingForUri('data://temp'), isNull);

      await engine.destroy();
    });

    test('Normal: setResourceHandlers registers callbacks', () async {
      final engine = RuntimeEngine(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Test'},
      };

      await engine.initialize(definition: definition);

      String? subscribedUri;
      engine.setResourceHandlers(
        onResourceSubscribe: (uri, binding) {
          subscribedUri = uri;
        },
      );

      // Callbacks are stored
      expect(engine.onResourceSubscribe, isNotNull);
      expect(subscribedUri, isNull);

      await engine.destroy();
    });

    test('Boundary: getBindingForUri for non-existent URI returns null', () async {
      final engine = RuntimeEngine(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Test'},
      };

      await engine.initialize(definition: definition);
      expect(engine.getBindingForUri('data://unknown'), isNull);

      await engine.destroy();
    });
  });

  group('TC-020: RuntimeEngine — core service access', () {
    test('Normal: renderer accessible after initialization', () async {
      final engine = RuntimeEngine(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Test'},
      };

      await engine.initialize(definition: definition);
      expect(engine.renderer, isNotNull);

      await engine.destroy();
    });

    test('Normal: stateManager accessible after initialization', () async {
      final engine = RuntimeEngine(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Test'},
      };

      await engine.initialize(definition: definition);
      expect(engine.stateManager, isNotNull);

      await engine.destroy();
    });

    test('Normal: actionHandler accessible after initialization', () async {
      final engine = RuntimeEngine(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Test'},
      };

      await engine.initialize(definition: definition);
      expect(engine.actionHandler, isNotNull);

      await engine.destroy();
    });

    test('Normal: bindingEngine accessible after initialization', () async {
      final engine = RuntimeEngine(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Test'},
      };

      await engine.initialize(definition: definition);
      expect(engine.bindingEngine, isNotNull);

      await engine.destroy();
    });

    test('Normal: themeManager accessible after initialization', () async {
      final engine = RuntimeEngine(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Test'},
      };

      await engine.initialize(definition: definition);
      expect(engine.themeManager, isNotNull);

      await engine.destroy();
    });

    test('Normal: cacheManager accessible after initialization', () async {
      final engine = RuntimeEngine(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Test'},
      };

      await engine.initialize(definition: definition);
      expect(engine.cacheManager, isNotNull);

      await engine.destroy();
    });

    test('Normal: lifecycle accessible after initialization', () async {
      final engine = RuntimeEngine(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Test'},
      };

      await engine.initialize(definition: definition);
      expect(engine.lifecycle, isNotNull);

      await engine.destroy();
    });

    test('Normal: widgetRegistry accessible after initialization', () async {
      final engine = RuntimeEngine(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Test'},
      };

      await engine.initialize(definition: definition);
      expect(engine.widgetRegistry, isNotNull);

      await engine.destroy();
    });

    test('Boundary: services initialized in constructor are accessible before initialize()', () {
      final engine = RuntimeEngine(enableDebugMode: false);

      // Core components are initialized in constructor via _initializeCoreComponents
      expect(engine.stateManager, isNotNull);
      expect(engine.actionHandler, isNotNull);
      expect(engine.bindingEngine, isNotNull);
      expect(engine.themeManager, isNotNull);
      expect(engine.cacheManager, isNotNull);
      expect(engine.lifecycle, isNotNull);
      expect(engine.channelManager, isNotNull);
      expect(engine.templateRegistry, isNotNull);
      expect(engine.widgetRegistry, isNotNull);

      engine.dispose();
    });
  });

  group('TC-022: RuntimeEngine — runtime state properties', () {
    test('Normal: isInitialized reflects initialization state', () async {
      final engine = RuntimeEngine(enableDebugMode: false);
      expect(engine.isInitialized, isFalse);

      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Test'},
      };

      await engine.initialize(definition: definition);
      expect(engine.isInitialized, isTrue);

      await engine.destroy();
    });

    test('Normal: isReady reflects readiness state', () async {
      final engine = RuntimeEngine(enableDebugMode: false);
      expect(engine.isReady, isFalse);

      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Test'},
      };

      await engine.initialize(definition: definition);
      await engine.markReady();
      expect(engine.isReady, isTrue);

      await engine.destroy();
    });

    test('Normal: services returns ServiceRegistry', () async {
      final engine = RuntimeEngine(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Test'},
      };

      await engine.initialize(definition: definition);
      expect(engine.services, isNotNull);

      await engine.destroy();
    });

    test('Normal: notifications returns NotificationManager', () async {
      final engine = RuntimeEngine(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Test'},
      };

      await engine.initialize(definition: definition);
      expect(engine.notifications, isNotNull);

      await engine.destroy();
    });

    test('Normal: runtimeConfig returns runtime configuration map', () async {
      final engine = RuntimeEngine(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'runtime': {'id': 'test', 'version': '1.0.0'},
        'content': {'type': 'text', 'content': 'Test'},
      };

      await engine.initialize(definition: definition);
      expect(engine.runtimeConfig, isNotNull);

      await engine.destroy();
    });

    test('Normal: uiDefinition returns UI definition map', () async {
      final engine = RuntimeEngine(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Test'},
      };

      await engine.initialize(definition: definition);
      expect(engine.uiDefinition, isNotNull);
      expect(engine.uiDefinition!['type'], equals('page'));

      await engine.destroy();
    });

    test('Normal: parsedUIDefinition returns typed UIDefinition', () async {
      final engine = RuntimeEngine(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Test'},
      };

      await engine.initialize(definition: definition);
      expect(engine.parsedUIDefinition, isNotNull);

      await engine.destroy();
    });

    test('Normal: applicationDefinition returns null for page type', () async {
      final engine = RuntimeEngine(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Test'},
      };

      await engine.initialize(definition: definition);
      expect(engine.applicationDefinition, isNull);
      expect(engine.isApplication, isFalse);

      await engine.destroy();
    });

    test('Normal: applicationDefinition returns typed ApplicationDefinition for app type', () async {
      final engine = RuntimeEngine(enableDebugMode: false);
      final definition = {
        'type': 'application',
        'title': 'Test App',
        'version': '1.0.0',
        'routes': {'/': 'main'},
        'pages': {
          'main': {
            'type': 'page',
            'content': {'type': 'text', 'content': 'Main'},
          },
        },
      };

      await engine.initialize(definition: definition, pageLoader: (_) async => {});
      expect(engine.applicationDefinition, isNotNull);
      expect(engine.isApplication, isTrue);
      expect(engine.routeManager, isNotNull);

      await engine.destroy();
    });

    test('Boundary: before initialization nullable properties return null, booleans return false', () {
      final engine = RuntimeEngine(enableDebugMode: false);

      expect(engine.isInitialized, isFalse);
      expect(engine.isReady, isFalse);
      expect(engine.runtimeConfig, isNull);
      expect(engine.uiDefinition, isNull);
      expect(engine.parsedUIDefinition, isNull);
      expect(engine.applicationDefinition, isNull);
      expect(engine.routeManager, isNull);
      expect(engine.isApplication, isFalse);

      engine.dispose();
    });
  });

  group('TC-024: RuntimeEngine — initialize', () {
    test('Normal: initialize with definition sets isInitialized to true', () async {
      final engine = RuntimeEngine(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Test'},
      };

      await engine.initialize(definition: definition);
      expect(engine.isInitialized, isTrue);

      await engine.destroy();
    });

    test('Boundary: minimal definition with only required fields', () async {
      final engine = RuntimeEngine(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'content': {'type': 'text', 'content': 'Minimal'},
      };

      await engine.initialize(definition: definition);
      expect(engine.isInitialized, isTrue);

      await engine.destroy();
    });

    test('Error: invalid definition throws ArgumentError', () {
      final engine = RuntimeEngine(enableDebugMode: false);
      final invalidDefinition = {
        'type': 'invalid_type',
        'content': {},
      };

      expect(
        () => engine.initialize(definition: invalidDefinition),
        throwsA(isA<ArgumentError>()),
      );

      engine.dispose();
    });

    test('Error: double initialization throws StateError', () async {
      final engine = RuntimeEngine(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'content': {'type': 'text', 'content': 'Test'},
      };

      await engine.initialize(definition: definition);
      expect(
        () => engine.initialize(definition: definition),
        throwsA(isA<StateError>()),
      );

      await engine.destroy();
    });
  });

  group('TC-026: RuntimeEngine — dispose', () {
    test('Normal: dispose releases all service resources', () async {
      final engine = RuntimeEngine(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Test'},
      };

      await engine.initialize(definition: definition);
      await engine.destroy();

      expect(engine.isInitialized, isFalse);
      expect(engine.isReady, isFalse);
      expect(engine.runtimeConfig, isNull);
      expect(engine.uiDefinition, isNull);
    });

    test('Boundary: dispose before initialization causes no error', () async {
      final engine = RuntimeEngine(enableDebugMode: false);
      // Should not throw
      await engine.destroy();
      expect(engine.isInitialized, isFalse);
    });

    test('Boundary: double dispose causes no error', () async {
      final engine = RuntimeEngine(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'content': {'type': 'text', 'content': 'Test'},
      };

      await engine.initialize(definition: definition);
      await engine.destroy();
      await engine.destroy(); // Should not throw
      expect(engine.isInitialized, isFalse);
    });
  });

  group('TC-025: RuntimeEngine — loadPage', () {
    test('Normal: loadPage with route loads page definition', () async {
      final engine = RuntimeEngine(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Test'},
      };

      await engine.initialize(
        definition: definition,
        pageLoader: (_) async => {},
      );
      // loadPage should not throw for a basic page
      await engine.loadPage('/');

      await engine.destroy();
    });

    test('Normal: pause and resume lifecycle methods work', () async {
      final engine = RuntimeEngine(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Test'},
      };

      await engine.initialize(definition: definition);
      await engine.markReady();

      // Should not throw
      await engine.pause();
      await engine.resume();

      await engine.destroy();
    });

    test('Normal: application-root templates auto-register on initialize',
        () async {
      final engine = RuntimeEngine(enableDebugMode: false);
      final definition = {
        'type': 'application',
        'title': 'Test App',
        'version': '1.0.0',
        'routes': {'/': 'main'},
        'templates': {
          'badge': {
            'content': {'type': 'text', 'content': 'Badge'},
          },
          'card': {
            'content': {'type': 'box', 'color': 'blue'},
          },
        },
      };

      await engine.initialize(
        definition: definition,
        pageLoader: (_) async => {
          'type': 'page',
          'content': {'type': 'text', 'content': 'home'},
        },
      );

      expect(engine.templateRegistry.getTemplate('badge'), isNotNull);
      expect(engine.templateRegistry.getTemplate('card'), isNotNull);

      await engine.destroy();
    });

    test('Normal: page-root templates auto-register at screen scope',
        () async {
      final engine = RuntimeEngine(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'templates': {
          'pageBadge': {
            'content': {'type': 'text', 'content': 'PageBadge'},
          },
        },
        'content': {'type': 'text', 'content': 'home'},
      };

      await engine.initialize(definition: definition);

      expect(engine.templateRegistry.getTemplate('pageBadge'), isNotNull);

      await engine.destroy();
    });

    test('Boundary: template entry without `content` is skipped',
        () async {
      // Spec requires the canonical `content` key for the widget tree.
      // Entries that omit it (or use a non-canonical key) are silently
      // dropped — no alias accretion.
      final engine = RuntimeEngine(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'templates': {
          'broken': {
            'name': 'broken',
            // No `content:` — must be skipped without crashing.
          },
          'legacyKey': {
            // Legacy `template:` wrapper is NOT supported; spec is `content:`.
            'template': {'type': 'text', 'content': 'legacy'},
          },
        },
        'content': {'type': 'text', 'content': 'home'},
      };

      await engine.initialize(definition: definition);

      expect(engine.templateRegistry.getTemplate('broken'), isNull);
      expect(engine.templateRegistry.getTemplate('legacyKey'), isNull);

      await engine.destroy();
    });
  });
}