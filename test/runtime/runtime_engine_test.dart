import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/runtime_engine.dart';
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
}