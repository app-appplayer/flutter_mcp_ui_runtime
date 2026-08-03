import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_mcp_ui_runtime/src/mcp_ui_runtime.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart'
    show ActionExecutor;
import 'package:flutter_mcp_ui_runtime/src/actions/action_result.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/widgets/widget_factory.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart'
    show ApplicationDefinition, PageDefinition, WidgetDefinition;

void main() {
  group('TC-001: MCPUIRuntime — constructor', () {
    test('Normal: creates instance with isInitialized == false', () {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      expect(runtime.isInitialized, isFalse);
    });

    test('Normal: enableDebugMode: true enables debug logging', () {
      final runtime = MCPUIRuntime(enableDebugMode: true);
      expect(runtime.enableDebugMode, isTrue);
      expect(runtime.isInitialized, isFalse);
    });

    test('Boundary: default enableDebugMode is kDebugMode', () {
      final runtime = MCPUIRuntime();
      expect(runtime.enableDebugMode, kDebugMode);
    });

    test('Normal: stateManager is accessible before initialization', () {
      // Engine is eagerly initialized in constructor, so stateManager
      // is always accessible (returns uninitialized manager)
      final runtime = MCPUIRuntime(enableDebugMode: false);
      expect(runtime.stateManager, isNotNull);
    });
  });

  group('TC-002: MCPUIRuntime — engine property', () {
    test('Normal: engine is non-null before initialization', () {
      // Engine is eagerly initialized in the constructor
      final runtime = MCPUIRuntime(enableDebugMode: false);
      expect(runtime.engine, isNotNull);
    });

    test('Boundary: engine is accessible before initialize', () {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      expect(runtime.engine, isNotNull);
      expect(runtime.isReady, isFalse);
    });
  });

  group('TC-004: MCPUIRuntime — initialize with page definition', () {
    test('Normal: initialize with type page succeeds', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {
          'type': 'text',
          'content': 'Hello',
        },
      };

      await runtime.initialize(definition);
      expect(runtime.isInitialized, isTrue);
      expect(runtime.engine, isNotNull);

      await runtime.dispose();
    });

    test('Normal: initialize with type screen is equivalent to page', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      final definition = {
        'type': 'screen',
        'metadata': {'title': 'Test Screen'},
        'content': {
          'type': 'text',
          'content': 'Hello',
        },
      };

      await runtime.initialize(definition);
      expect(runtime.isInitialized, isTrue);

      await runtime.dispose();
    });

    test('Boundary: page with no initial state starts with empty state', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {
          'type': 'text',
          'content': 'Hello',
        },
      };

      await runtime.initialize(definition);
      // State should be accessible but empty or with defaults
      expect(runtime.stateManager, isNotNull);

      await runtime.dispose();
    });

    test('Error: invalid definition type throws', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      final invalidDefinition = {
        'type': 'scaffold',
        'properties': {},
      };

      expect(
        () => runtime.initialize(invalidDefinition),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('TC-008: MCPUIRuntime — handleNotification', () {
    test('Normal: notification with URI matching subscription updates state', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {
          'type': 'text',
          'content': '{{temperature}}',
        },
      };

      await runtime.initialize(definition);
      runtime.registerResourceSubscription('data://temperature', 'temperature');

      // Spec §4.5: the parsed `text` payload is stored at the binding as-is.
      // The heuristic that unwrapped `{key: <value>}` when `key == binding`
      // was removed (it conflated authored payload shape with binding path).
      // Hosts that want a scalar at the binding should encode a scalar.
      await runtime.handleNotification({
        'method': 'notifications/resources/updated',
        'params': {
          'uri': 'data://temperature',
          'content': {
            'text': '25.5',
          },
        },
      });

      expect(runtime.engine!.stateManager.get('temperature'), equals(25.5));

      await runtime.dispose();
    });

    test('Boundary: notification for unknown URI is ignored', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Hello'},
      };

      await runtime.initialize(definition);

      // Should not throw
      await runtime.handleNotification({
        'method': 'notifications/resources/updated',
        'params': {
          'uri': 'data://unknown',
        },
      });

      await runtime.dispose();
    });

    test('Boundary: notification before initialization is ignored', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);

      // Should not throw
      await runtime.handleNotification({
        'method': 'notifications/resources/updated',
        'params': {'uri': 'data://test'},
      });
    });

    test('Normal: standard mode — notification without content calls resourceReader', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': '{{humidity}}'},
      };

      await runtime.initialize(definition);
      runtime.registerResourceSubscription('data://humidity', 'humidity');

      bool readerCalled = false;

      await runtime.handleNotification(
        {
          'method': 'notifications/resources/updated',
          'params': {
            'uri': 'data://humidity',
            // No 'content' key — triggers standard mode
          },
        },
        // Spec §4.5: store the parsed payload as-is at the binding.
        // Scalar payloads encode as scalar JSON.
        resourceReader: (uri) async {
          readerCalled = true;
          return '65.0';
        },
      );

      expect(readerCalled, true);
      expect(runtime.engine!.stateManager.get('humidity'), equals(65.0));

      await runtime.dispose();
    });

    test('Normal: same runtime handles both standard and extended notifications', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': '{{temp}} {{wind}}'},
      };

      await runtime.initialize(definition);
      runtime.registerResourceSubscription('data://temp', 'temp');
      runtime.registerResourceSubscription('data://wind', 'wind');

      // Extended mode notification — spec §4.5 stores payload as-is.
      await runtime.handleNotification({
        'method': 'notifications/resources/updated',
        'params': {
          'uri': 'data://temp',
          'content': {'text': '22.0'},
        },
      });

      // Standard mode notification — spec §4.5 stores payload as-is.
      await runtime.handleNotification(
        {
          'method': 'notifications/resources/updated',
          'params': {'uri': 'data://wind'},
        },
        resourceReader: (uri) async => '15.5',
      );

      expect(runtime.engine!.stateManager.get('temp'), equals(22.0));
      expect(runtime.engine!.stateManager.get('wind'), equals(15.5));

      await runtime.dispose();
    });
  });

  group('TC-010: MCPUIRuntime — resource subscription management', () {
    test('Normal: register URI to binding mapping and retrieve', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Hello'},
      };

      await runtime.initialize(definition);
      runtime.registerResourceSubscription('data://temp', 'temperature');

      expect(runtime.getBindingForUri('data://temp'), equals('temperature'));

      await runtime.dispose();
    });

    test('Normal: unregister removes mapping', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Hello'},
      };

      await runtime.initialize(definition);
      runtime.registerResourceSubscription('data://temp', 'temperature');
      runtime.unregisterResourceSubscription('data://temp');

      expect(runtime.getBindingForUri('data://temp'), isNull);

      await runtime.dispose();
    });

    test('Boundary: get binding for non-existent URI returns null', () {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      expect(runtime.getBindingForUri('data://unknown'), isNull);
    });
  });

  group('TC-011: MCPUIRuntime — updateState', () {
    test('Normal: updateState updates state at binding path', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Hello'},
      };

      await runtime.initialize(definition);
      runtime.updateState('counter', 5);

      expect(runtime.engine!.stateManager.get('counter'), equals(5));

      await runtime.dispose();
    });

    test('Boundary: update non-existent path creates new state entry', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Hello'},
      };

      await runtime.initialize(definition);
      runtime.updateState('newKey', 'newValue');

      expect(runtime.engine!.stateManager.get('newKey'), equals('newValue'));

      await runtime.dispose();
    });

    test('Error: update after dispose throws', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Hello'},
      };

      await runtime.initialize(definition);
      await runtime.dispose();

      expect(
        () => runtime.updateState('counter', 5),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('TC-014: MCPUIRuntime — handleError', () {
    test('Normal: handleError logs error via MCPLogger', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      // Should not throw
      runtime.handleError('Test error');
    });

    test('Boundary: empty error string still logs', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      // Should not throw
      runtime.handleError('');
    });
  });

  group('TC-015: MCPUIRuntime — v1.1 handler registration', () {
    test('Normal: permissionManager returns null before initialization', () {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      expect(runtime.permissionManager, isNull);
    });

    test('Normal: channelManager returns null before initialization', () {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      expect(runtime.channelManager, isNull);
    });

    test('Error: registerPermissionHandler before init throws', () {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      expect(
        () => runtime.registerPermissionHandler((_) {}),
        throwsA(isA<StateError>()),
      );
    });

    test('Error: registerClientActionHandler before init throws', () {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      expect(
        () => runtime.registerClientActionHandler('client', (_) {}),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('TC-017: MCPUIRuntime — dispose and destroy', () {
    test('Normal: dispose cleans up resources', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Hello'},
      };

      await runtime.initialize(definition);
      expect(runtime.isInitialized, isTrue);

      await runtime.dispose();
      expect(runtime.isInitialized, isFalse);
      // Engine is final and never nulled; it remains accessible after dispose
      expect(runtime.engine, isNotNull);
    });

    test('Boundary: double dispose causes no error', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Hello'},
      };

      await runtime.initialize(definition);
      await runtime.dispose();
      await runtime.dispose(); // Should not throw
    });

    test('Normal: destroy is alias for dispose', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Hello'},
      };

      await runtime.initialize(definition);
      await runtime.destroy();
      expect(runtime.isInitialized, isFalse);
    });
  });

  group('TC-018: MCPUIRuntime — getUIDefinition', () {
    test('Normal: returns UI definition after initialization', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Hello'},
      };

      await runtime.initialize(definition);
      final uiDef = runtime.getUIDefinition();
      expect(uiDef, isNotNull);
      expect(uiDef!['type'], equals('page'));

      await runtime.dispose();
    });

    test('Boundary: before initialization returns null', () {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      expect(runtime.getUIDefinition(), isNull);
    });

    test('Error: after destroy returns null', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Hello'},
      };

      await runtime.initialize(definition);
      await runtime.destroy();
      expect(runtime.getUIDefinition(), isNull);
    });
  });

  group('TC-009: MCPUIRuntime — registerWidget and registerAction', () {
    test('registerWidget before init is allowed, and is what makes a host '
        'widget validate', () {
      // This used to throw. It could not stay that way: schema validation runs
      // inside `initialize`, and it consults the widget registry so a host's
      // own widget is not reported as a malformed document. A host that can
      // only register afterwards has no way to get its extension past the
      // validation of the very document that introduces it.
      //
      // Registering early is safe — the registry is built with the engine, not
      // with the definition.
      final runtime = MCPUIRuntime(enableDebugMode: false);
      expect(
        () => runtime.registerWidget('custom', _DummyWidgetFactory()),
        returnsNormally,
      );
    });

    test('a registered host widget passes schema validation; an '
        'unregistered one does not', () async {
      // `registerWidget` invites a host to add types the DSL does not define —
      // a dashboard slot, a vendor chart. The generated schema knows only the
      // spec's set, so validating a document containing one used to reject it,
      // and the host was told its own extension was a malformed document.
      // Offering an extension mechanism and refusing what it produces is a
      // contract disagreeing with itself.
      //
      // The extension's subtree is the host's contract, so it is not checked;
      // everything around it still is, which is what keeps a typo an error.
      final runtime = MCPUIRuntime(enableDebugMode: false);
      runtime.registerWidget('vendorGauge', _DummyWidgetFactory());

      final withExtension = <String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{
          'type': 'linear',
          'direction': 'vertical',
          'children': <Object>[
            <String, dynamic>{'type': 'text', 'content': 'ok'},
            <String, dynamic>{'type': 'vendorGauge', 'reading': 12},
          ],
        },
      };
      await expectLater(runtime.initialize(withExtension), completes);
      await runtime.destroy();

      final unregistered = MCPUIRuntime(enableDebugMode: false);
      await expectLater(
        unregistered.initialize(<String, dynamic>{
          'type': 'page',
          'content': <String, dynamic>{
            'type': 'linear',
            'direction': 'vertical',
            'children': <Object>[
              <String, dynamic>{'type': 'vendrGauge', 'reading': 12},
            ],
          },
        }),
        throwsA(isA<StateError>()),
        reason: 'a type nothing registered is still a typo, not an extension',
      );
    });

    test('Error: registerAction before init throws', () {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      expect(
        () => runtime.registerAction('custom', _DummyActionExecutor()),
        throwsA(isA<StateError>()),
      );
    });

    test('Error: registerToolExecutor before init throws', () {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      expect(
        () => runtime.registerToolExecutor('myTool', (params) async {}),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('TC-012: MCPUIRuntime — registerToolExecutor', () {
    test('Normal: register tool executor per tool name', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Hello'},
      };

      await runtime.initialize(definition);

      // Should not throw
      runtime.registerToolExecutor('myTool', (params) async {
        return {'result': 'success'};
      });

      await runtime.dispose();
    });
  });

  group('TC-013: MCPUIRuntime — registerNavigationHandler', () {
    test('Normal: handler registration succeeds after init', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Hello'},
      };

      await runtime.initialize(definition);

      // Should not throw
      runtime.registerNavigationHandler(
        (action, route, params) => true,
      );

      await runtime.dispose();
    });

    test('Error: registerNavigationHandler before init throws', () {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      expect(
        () => runtime.registerNavigationHandler(
          (action, route, params) => true,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('TC-003: MCPUIRuntime — initialize with application definition', () {
    test('Normal: initialize with type application succeeds', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      final definition = {
        'type': 'application',
        'title': 'Test App',
        'version': '1.0.0',
        'routes': {'/': 'main'},
        'pages': {
          'main': {
            'type': 'page',
            'content': {'type': 'text', 'content': 'Main Page'},
          },
        },
      };

      await runtime.initialize(definition, pageLoader: (_) async => {});
      expect(runtime.isInitialized, isTrue);
      expect(runtime.engine, isNotNull);

      await runtime.dispose();
    });

    test('Normal: application definition provides route manager', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      final definition = {
        'type': 'application',
        'title': 'Test App',
        'version': '1.0.0',
        'routes': {'/': 'main', '/settings': 'settings'},
        'pages': {
          'main': {
            'type': 'page',
            'content': {'type': 'text', 'content': 'Main'},
          },
          'settings': {
            'type': 'page',
            'content': {'type': 'text', 'content': 'Settings'},
          },
        },
      };

      await runtime.initialize(definition, pageLoader: (_) async => {});
      expect(runtime.engine!.isApplication, isTrue);

      await runtime.dispose();
    });

    test('Normal: isInitialized becomes true after initialize', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      final definition = {
        'type': 'application',
        'title': 'Test App',
        'version': '1.0.0',
        'routes': {'/': 'main'},
        'pages': {
          'main': {
            'type': 'page',
            'content': {'type': 'text', 'content': 'Main Page'},
          },
        },
      };

      expect(runtime.isInitialized, isFalse);
      await runtime.initialize(definition, pageLoader: (_) async => {});
      expect(runtime.isInitialized, isTrue);

      await runtime.dispose();
    });

    test('Boundary: definition with useCache false', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
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

      await runtime.initialize(definition, pageLoader: (_) async => {}, useCache: false);
      expect(runtime.isInitialized, isTrue);

      await runtime.dispose();
    });

    test('Boundary: definition with useCache true (default)', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
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

      await runtime.initialize(definition, pageLoader: (_) async => {}, useCache: true);
      expect(runtime.isInitialized, isTrue);

      await runtime.dispose();
    });

    test('Boundary: application with minimal fields', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      final definition = {
        'type': 'application',
        'title': 'Minimal',
        'version': '1.0.0',
        'routes': {'/': 'main'},
        'pages': {
          'main': {
            'type': 'page',
            'content': {'type': 'text', 'content': 'Hello'},
          },
        },
      };

      await runtime.initialize(definition, pageLoader: (_) async => {});
      expect(runtime.isInitialized, isTrue);

      await runtime.dispose();
    });
  });

  group('TC-005: MCPUIRuntime — initialize v1.1 features', () {
    test('Normal: page with channels initializes channel manager', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'version': '1.1',
        'metadata': {'title': 'V1.1 Page'},
        'channels': {
          'timer': {
            'type': 'client.poll',
            'params': {'interval': 5000},
          },
        },
        'content': {'type': 'text', 'content': 'Hello'},
      };

      await runtime.initialize(definition);
      expect(runtime.isInitialized, isTrue);
      expect(runtime.channelManager, isNotNull);

      await runtime.dispose();
    });

    test('Normal: page with permissions initializes permission manager', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'version': '1.1',
        'metadata': {'title': 'Permissions Page'},
        'permissions': {
          'camera': {'required': true},
          'location': {'required': false},
        },
        'content': {'type': 'text', 'content': 'Hello'},
      };

      await runtime.initialize(definition);
      expect(runtime.isInitialized, isTrue);

      await runtime.dispose();
    });
  });

  group('TC-006: MCPUIRuntime — initializeFromDefinition (typed)', () {
    test('Normal: initialize from ApplicationDefinition succeeds', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      const appDef = ApplicationDefinition(
        title: 'Typed App',
        version: '1.0.0',
        routes: {'/': 'main'},
      );

      await runtime.initializeFromDefinition(appDef, pageLoader: (_) async => {});
      expect(runtime.isInitialized, isTrue);
      expect(runtime.engine, isNotNull);

      await runtime.dispose();
    });

    test('Boundary: double initialization throws StateError', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      const appDef = ApplicationDefinition(
        title: 'Test',
        version: '1.0.0',
        routes: {'/': 'main'},
      );

      await runtime.initializeFromDefinition(appDef, pageLoader: (_) async => {});
      expect(
        () => runtime.initializeFromDefinition(appDef, pageLoader: (_) async => {}),
        throwsA(isA<StateError>()),
      );

      await runtime.dispose();
    });
  });

  group('TC-007: MCPUIRuntime — initializeFromPageDefinition (typed)', () {
    test('Normal: initialize from PageDefinition succeeds', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      final pageDef = PageDefinition(
        type: 'page',
        title: 'Typed Page',
        content: WidgetDefinition.fromJson({
          'type': 'text',
          'content': 'Hello from typed page',
        }),
      );

      await runtime.initializeFromPageDefinition(pageDef);
      expect(runtime.isInitialized, isTrue);

      await runtime.dispose();
    });

    test('Boundary: PageDefinition without title', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      final pageDef = PageDefinition(
        content: WidgetDefinition.fromJson({
          'type': 'text',
          'content': 'No title',
        }),
      );

      await runtime.initializeFromPageDefinition(pageDef);
      expect(runtime.isInitialized, isTrue);

      await runtime.dispose();
    });
  });

  group('TC-016: MCPUIRuntime — buildUI rendering', () {
    test('Normal: buildUI returns Widget after initialization', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Hello'},
      };

      await runtime.initialize(definition);
      final widget = runtime.buildUI();
      expect(widget, isA<Widget>());

      await runtime.dispose();
    });

    test('Error: buildUI before initialization throws', () {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      expect(
        () => runtime.buildUI(),
        throwsA(isA<StateError>()),
      );
    });

    test('Normal: render() is alias for buildUI()', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      final definition = {
        'type': 'page',
        'metadata': {'title': 'Test Page'},
        'content': {'type': 'text', 'content': 'Hello'},
      };

      await runtime.initialize(definition);
      final widget = runtime.render();
      expect(widget, isA<Widget>());

      await runtime.dispose();
    });
  });
}

/// Dummy WidgetFactory for testing registration
class _DummyWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    return const SizedBox.shrink();
  }
}

/// Dummy ActionExecutor for testing registration
class _DummyActionExecutor extends ActionExecutor {
  @override
  Future<ActionResult> execute(
    Map<String, dynamic> action,
    RenderContext context,
  ) async {
    return ActionResult.success();
  }
}
