// `MCPUIRuntime` — the whole public surface a host touches.
//
// Most of this file used to end at `expect(runtime.isInitialized, isTrue)` or
// `expect(widget, isA<Widget>())`. `initialize` sets that flag as its last
// statement whatever it built, and `buildUI` returns a widget for a document
// that renders nothing at all, so neither says the document arrived. The
// registration tests were worse: "Should not throw" for a callback nobody
// afterwards called — a host could register a tool executor into a dead map
// and every test stayed green.
//
// Everything below either renders the document and reads the screen, or fires
// the seam it registered and checks the far end.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart'
    show ApplicationDefinition, PageDefinition, WidgetDefinition;
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart'
    show ActionExecutor;
import 'package:flutter_mcp_ui_runtime/src/actions/action_result.dart';
import 'package:flutter_mcp_ui_runtime/src/mcp_ui_runtime.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/widgets/widget_factory.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _page({
  Map<String, dynamic>? content,
  Map<String, dynamic>? extra,
}) =>
    {
      'type': 'page',
      'metadata': const {'title': 'Test Page'},
      'content': content ?? const {'type': 'text', 'content': 'Hello'},
      ...?extra,
    };

/// Renders the runtime's UI and lets it settle enough to show its content.
///
/// `pumpAndSettle` is avoided on purpose: the runtime schedules a ready-state
/// microtask and, on an application document, a page load — a settle here can
/// wait on animations that are part of the shell rather than the document.
Future<void> _render(WidgetTester tester, MCPUIRuntime runtime) async {
  await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Executes an action against the runtime's own engine, the way a tapped
/// button does.
Future<ActionResult> _fire(
        MCPUIRuntime runtime, Map<String, dynamic> action) async =>
    await runtime.engine.actionHandler
        .execute(action, runtime.engine.renderer.createRootContext(null));

void main() {
  group('a runtime that has not been initialized refuses to be used', () {
    late MCPUIRuntime runtime;
    setUp(() => runtime = MCPUIRuntime(enableDebugMode: false));

    test('and it says so, on every seam a host might reach for early', () {
      // The guard is the same shape everywhere, and each one is a real host
      // mistake: wiring the callbacks before the document has been fetched.
      // What matters is that the refusal names initialization rather than
      // failing later with a null.
      final calls = <String, void Function()>{
        'updateState': () => runtime.updateState('k', 1),
        'buildUI': () => runtime.buildUI(),
        'registerAction': () =>
            runtime.registerAction('custom', _DummyActionExecutor()),
        'registerToolExecutor': () =>
            runtime.registerToolExecutor('myTool', (p) async {}),
        'registerNavigationHandler': () =>
            runtime.registerNavigationHandler((a, r, p) => true),
        'registerPermissionHandler': () =>
            runtime.registerPermissionHandler((_) {}),
        'registerClientActionHandler': () =>
            runtime.registerClientActionHandler('client', (_) {}),
      };
      for (final entry in calls.entries) {
        expect(entry.value, throwsA(isA<StateError>()),
            reason: '${entry.key} must refuse before initialize');
      }
    });

    test('the read-only surface answers empty rather than throwing', () {
      expect(runtime.isInitialized, isFalse);
      expect(runtime.isReady, isFalse);
      expect(runtime.getUIDefinition(), isNull);
      expect(runtime.permissionManager, isNull);
      expect(runtime.channelManager, isNull);
      expect(runtime.getBindingForUri('data://unknown'), isNull);
    });

    test('the engine and its state manager exist from construction', () {
      // Deliberate: the engine is built eagerly so a host can register widgets
      // BEFORE initialize — schema validation consults the widget registry, so
      // a host extension has to be in it before the document that uses it is
      // validated. See the registerWidget group below.
      expect(runtime.engine, isNotNull);
      runtime.stateManager.set('early', 1);
      expect(runtime.stateManager.get('early'), 1);
    });

    test('debug mode follows the build unless the host says otherwise', () {
      expect(MCPUIRuntime().enableDebugMode, kDebugMode);
      expect(MCPUIRuntime(enableDebugMode: true).enableDebugMode, isTrue);
      expect(MCPUIRuntime(enableDebugMode: false).enableDebugMode, isFalse);
    });
  });

  group('initialize with a page', () {
    late MCPUIRuntime runtime;
    setUp(() => runtime = MCPUIRuntime(enableDebugMode: false));
    tearDown(() => runtime.dispose());

    testWidgets('the document reaches the screen', (tester) async {
      await runtime.initialize(_page(
        content: const {'type': 'text', 'content': 'Hello from the document'},
      ));
      await _render(tester, runtime);

      expect(find.text('Hello from the document'), findsOneWidget,
          reason: 'initialize + buildUI is the entire contract of this class; '
              'a flag set to true with nothing rendered is what this file used '
              'to accept');
    });

    testWidgets('`screen` renders exactly like `page`', (tester) async {
      // Two spellings of the same thing. The claim "equivalent" is only worth
      // anything if both put the same words on screen.
      await runtime.initialize({
        'type': 'screen',
        'metadata': const {'title': 'Test Screen'},
        'content': const {'type': 'text', 'content': 'same either way'},
      });
      await _render(tester, runtime);
      expect(find.text('same either way'), findsOneWidget);
    });

    testWidgets('the document\'s initial state is bound into the render',
        (tester) async {
      await runtime.initialize(_page(
        content: const {'type': 'text', 'content': '{{greeting}}'},
        extra: const {
          'runtime': {
            'services': {
              'state': {
                'initialState': {'greeting': 'from initialState'},
              },
            },
          },
        },
      ));
      await _render(tester, runtime);
      expect(find.text('from initialState'), findsOneWidget);
    });

    testWidgets('a page with no state renders its literals and no binding text',
        (tester) async {
      await runtime.initialize(_page(
          content: const {'type': 'text', 'content': 'plain {{absent}}'}));
      await _render(tester, runtime);

      expect(find.text('plain '), findsOneWidget,
          reason: 'an unresolved binding renders as nothing, not as the raw '
              '{{absent}} braces — a user must never be shown the syntax');
    });

    test('a definition that is neither page nor application is refused', () {
      expect(
        () => runtime.initialize({'type': 'scaffold', 'properties': {}}),
        throwsA(isA<ArgumentError>().having(
            (e) => e.toString(), 'message', contains('application or page'))),
      );
      expect(runtime.isInitialized, isFalse,
          reason: 'a refused definition must not leave the runtime looking '
              'initialized');
    });

    test('a document whose content is not a known widget type is refused',
        () async {
      await expectLater(
        runtime.initialize(_page(content: const {'type': 'txet'})),
        throwsA(isA<StateError>()),
        reason: 'a typo caught at initialize is a message; a typo caught at '
            'render is an empty screen',
      );
    });
  });

  group('initialize with an application', () {
    late MCPUIRuntime runtime;
    setUp(() => runtime = MCPUIRuntime(enableDebugMode: false));
    tearDown(() => runtime.dispose());

    Map<String, dynamic> app() => {
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

    test('the routes named in the document become the route table', () async {
      await runtime.initialize(app(), pageLoader: (_) async => {});

      expect(runtime.engine.isApplication, isTrue);
      final manager = runtime.engine.routeManager;
      expect(manager, isNotNull);
      expect(manager!.initialRoute, '/');
      expect(manager.appDefinition.routes.keys,
          containsAll(<String>['/', '/settings']),
          reason: 'a route table that lost a route is a link that goes '
              'nowhere, and nothing else in the runtime would notice');
    });

    testWidgets('the initial route\'s page is the one that renders',
        (tester) async {
      await runtime.initialize(
        app(),
        pageLoader: (page) async => {
          'type': 'page',
          'content': {'type': 'text', 'content': 'loaded:$page'},
        },
      );
      await _render(tester, runtime);

      expect(find.text('loaded:main'), findsOneWidget,
          reason: 'the loader is asked for the page the initial route names — '
              'asking for the wrong one shows a user another screen entirely');
    });

    test('the page loader is the only way pages are fetched', () async {
      final asked = <String>[];
      await runtime.initialize(app(), pageLoader: (page) async {
        asked.add(page);
        return {'type': 'page', 'content': {'type': 'text', 'content': page}};
      });
      // Nothing is fetched at initialize; loading happens when a route is
      // shown. Pinned because a runtime that eagerly loaded every page would
      // pull an entire application over the wire to show one screen.
      expect(asked, isEmpty);
    });

    test('useCache is accepted in both positions and neither breaks init',
        () async {
      for (final useCache in const [true, false]) {
        final r = MCPUIRuntime(enableDebugMode: false);
        await r.initialize(app(), pageLoader: (_) async => {}, useCache: useCache);
        expect(r.engine.isApplication, isTrue);
        await r.dispose();
      }
    });

    test('a second initialize is refused', () async {
      await runtime.initialize(app(), pageLoader: (_) async => {});
      expect(() => runtime.initialize(app(), pageLoader: (_) async => {}),
          throwsA(isA<StateError>()));
    });
  });

  group('resource notifications', () {
    late MCPUIRuntime runtime;
    setUp(() => runtime = MCPUIRuntime(enableDebugMode: false));
    tearDown(() => runtime.dispose());

    test('a notification for a subscribed uri lands at its binding', () async {
      await runtime.initialize(
          _page(content: const {'type': 'text', 'content': '{{temperature}}'}));
      runtime.registerResourceSubscription('data://temperature', 'temperature');

      // Spec §4.5: the parsed `text` payload is stored at the binding as-is.
      // The heuristic that unwrapped `{key: <value>}` when `key == binding`
      // was removed — it conflated the authored payload shape with the binding
      // path.
      await runtime.handleNotification({
        'method': 'notifications/resources/updated',
        'params': {
          'uri': 'data://temperature',
          'content': {'text': '25.5'},
        },
      });

      expect(runtime.engine.stateManager.get('temperature'), 25.5);
    });

    testWidgets('and the screen shows the new value', (tester) async {
      await runtime.initialize(
          _page(content: const {'type': 'text', 'content': '{{temperature}}'}));
      runtime.registerResourceSubscription('data://temperature', 'temperature');
      await _render(tester, runtime);

      await runtime.handleNotification({
        'method': 'notifications/resources/updated',
        'params': {
          'uri': 'data://temperature',
          'content': {'text': '25.5'},
        },
      });
      await tester.pump();

      expect(find.text('25.5'), findsOneWidget,
          reason: 'the point of a subscription is a screen that updates; '
              'state that changes behind a stale widget is the defect this '
              'file exists to catch');
    });

    test('with no inline content the host reader is consulted', () async {
      await runtime.initialize(
          _page(content: const {'type': 'text', 'content': '{{humidity}}'}));
      runtime.registerResourceSubscription('data://humidity', 'humidity');

      final read = <String>[];
      await runtime.handleNotification(
        {
          'method': 'notifications/resources/updated',
          'params': {'uri': 'data://humidity'},
        },
        resourceReader: (uri) async {
          read.add(uri);
          return '65.0';
        },
      );

      expect(read, ['data://humidity'],
          reason: 'standard MCP sends the notification without a payload, so '
              'a runtime that does not read back shows nothing');
      expect(runtime.engine.stateManager.get('humidity'), 65.0);
    });

    test('both notification shapes work on the same runtime', () async {
      await runtime.initialize(_page(
          content: const {'type': 'text', 'content': '{{temp}} {{wind}}'}));
      runtime.registerResourceSubscription('data://temp', 'temp');
      runtime.registerResourceSubscription('data://wind', 'wind');

      await runtime.handleNotification({
        'method': 'notifications/resources/updated',
        'params': {
          'uri': 'data://temp',
          'content': {'text': '22.0'},
        },
      });
      await runtime.handleNotification(
        {
          'method': 'notifications/resources/updated',
          'params': {'uri': 'data://wind'},
        },
        resourceReader: (uri) async => '15.5',
      );

      expect(runtime.engine.stateManager.get('temp'), 22.0);
      expect(runtime.engine.stateManager.get('wind'), 15.5);
    });

    test('a notification for an unknown uri writes nothing anywhere', () async {
      await runtime.initialize(_page());
      runtime.registerResourceSubscription('data://temp', 'temp');
      final before = Map<String, dynamic>.from(runtime.engine.stateManager.state);

      await runtime.handleNotification({
        'method': 'notifications/resources/updated',
        'params': {
          'uri': 'data://unknown',
          'content': {'text': '1'},
        },
      });

      expect(runtime.engine.stateManager.state, before,
          reason: 'a subscription nobody registered must not be able to write '
              'into another document\'s state');
    });

    test('a notification before initialize is ignored, not fatal', () async {
      await runtime.handleNotification({
        'method': 'notifications/resources/updated',
        'params': {'uri': 'data://test'},
      });
      expect(runtime.isInitialized, isFalse);
    });

    test('a subscription can be registered, read back and removed', () async {
      await runtime.initialize(_page());
      runtime.registerResourceSubscription('data://temp', 'temperature');
      expect(runtime.getBindingForUri('data://temp'), 'temperature');

      runtime.unregisterResourceSubscription('data://temp');
      expect(runtime.getBindingForUri('data://temp'), isNull);

      // And after removal a notification no longer writes.
      await runtime.handleNotification({
        'method': 'notifications/resources/updated',
        'params': {
          'uri': 'data://temp',
          'content': {'text': '9'},
        },
      });
      expect(runtime.engine.stateManager.get('temperature'), isNull);
    });
  });

  group('updateState', () {
    late MCPUIRuntime runtime;
    setUp(() => runtime = MCPUIRuntime(enableDebugMode: false));

    testWidgets('a host write reaches the rendered screen', (tester) async {
      await runtime.initialize(
          _page(content: const {'type': 'text', 'content': '{{counter}}'}));
      await _render(tester, runtime);

      runtime.updateState('counter', 5);
      await tester.pump();
      expect(find.text('5'), findsOneWidget);

      runtime.updateState('counter', 6);
      await tester.pump();
      expect(find.text('6'), findsOneWidget,
          reason: 'the second write proves the widget is listening rather '
              'than having happened to build after the first');
      await runtime.dispose();
    });

    test('a path nobody declared is created rather than refused', () async {
      await runtime.initialize(_page());
      runtime.updateState('newKey', 'newValue');
      expect(runtime.engine.stateManager.get('newKey'), 'newValue');
      await runtime.dispose();
    });

    test('after dispose it is refused', () async {
      await runtime.initialize(_page());
      await runtime.dispose();
      expect(() => runtime.updateState('counter', 5), throwsA(isA<StateError>()),
          reason: 'writing into a disposed runtime is how a closed page keeps '
              'a dead widget tree alive');
    });
  });

  group('host handlers, fired rather than merely registered', () {
    late MCPUIRuntime runtime;
    setUp(() async {
      runtime = MCPUIRuntime(enableDebugMode: false);
      await runtime.initialize(_page());
    });
    tearDown(() => runtime.dispose());

    test('a registered tool executor is the one that runs, and its result '
        'merges into state', () async {
      final seen = <Map<String, dynamic>>[];
      runtime.registerToolExecutor('myTool', (params) async {
        seen.add(Map<String, dynamic>.from(params as Map));
        return {'reading': 42};
      });

      final result = await _fire(runtime, {
        'type': 'tool',
        'tool': 'myTool',
        'params': {'unit': 'celsius'},
      });

      expect(result.success, isTrue);
      expect(seen, [
        {'unit': 'celsius'}
      ], reason: 'the params the document declared have to arrive at the host');
      expect(runtime.engine.stateManager.get('reading'), 42,
          reason: 'spec §3.10 — a plain map response merges into page state');
    });

    test('a tool nobody registered is reported, naming what is available',
        () async {
      runtime.registerToolExecutor('myTool', (params) async => {});
      final result =
          await _fire(runtime, {'type': 'tool', 'tool': 'otherTool'});
      expect(result.success, isFalse);
      expect(result.error, contains('myTool'),
          reason: 'listing what IS registered is what turns this from a dead '
              'end into a fixable message');
    });

    test('a custom action executor receives the action it was registered for',
        () async {
      final executor = _RecordingActionExecutor();
      runtime.registerAction('vendor.ping', executor);

      final result = await _fire(runtime, {'type': 'vendor.ping', 'id': 7});
      expect(result.success, isTrue);
      expect(executor.seen.single['id'], 7);
    });

    test('a navigation handler is consulted with the action, route and params',
        () async {
      final calls = <List<Object?>>[];
      runtime.registerNavigationHandler((action, route, params) {
        calls.add([action, route, params]);
        return true;
      });

      await _fire(runtime, {
        'type': 'navigation',
        'action': 'push',
        'route': '/details',
        'params': {'id': 3},
      });

      expect(calls.single[0], 'push');
      expect(calls.single[1], '/details');
      expect(calls.single[2], {'id': 3},
          reason: 'a host that routes navigation itself needs all three, and '
              'dropping params silently opens the right page with no data');
    });

    test('a client action handler is dispatched by its action type', () async {
      final seen = <dynamic>[];
      runtime.registerClientActionHandler('client', (params) async {
        seen.add(params);
        return {'ok': true};
      });
      await _fire(runtime, {
        'type': 'tool',
        'tool': 'client',
        'params': {'command': 'ping'},
      });
      expect(seen.single, {'command': 'ping'});
    });

    test('a permission handler is handed to the engine', () {
      handler(dynamic _) {}
      runtime.registerPermissionHandler(handler);
      expect(runtime.engine.permissionHandler, same(handler));
    });
  });

  group('v1.1 blocks in the document are actually built', () {
    test('a declared channel exists on the channel manager', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      await runtime.initialize(_page(extra: const {
        'version': '1.1',
        'channels': {
          'timer': {
            'type': 'client.poll',
            'params': {'interval': 5000},
          },
        },
      }));

      expect(runtime.channelManager, isNotNull);
      expect(runtime.channelManager!.hasChannel('timer'), isTrue,
          reason: 'a channel block that produces a manager but no channel is '
              'a screen that waits forever for data');
      await runtime.dispose();
    });

    test('declared permissions reach the permission manager', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      await runtime.initialize(_page(extra: const {
        'version': '1.1',
        'permissions': {
          'camera': {'required': true},
          'location': {'required': false},
        },
      }));

      final permissions = runtime.permissionManager;
      expect(permissions, isNotNull);
      expect(permissions!.enabled, isTrue,
          reason: 'a document that declares permissions must not run with the '
              'gate switched off');
      await runtime.dispose();
    });
  });

  group('typed definitions', () {
    testWidgets('a PageDefinition renders its content', (tester) async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      await runtime.initializeFromPageDefinition(PageDefinition(
        type: 'page',
        title: 'Typed Page',
        content: WidgetDefinition.fromJson(
            const {'type': 'text', 'content': 'Hello from typed page'}),
      ));
      await _render(tester, runtime);

      expect(find.text('Hello from typed page'), findsOneWidget);
      expect(runtime.getUIDefinition()?['type'], 'page');
      await runtime.dispose();
    });

    testWidgets('a PageDefinition with no title still renders', (tester) async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      await runtime.initializeFromPageDefinition(PageDefinition(
        content:
            WidgetDefinition.fromJson(const {'type': 'text', 'content': 'No title'}),
      ));
      await _render(tester, runtime);
      expect(find.text('No title'), findsOneWidget);
      await runtime.dispose();
    });

    test('an ApplicationDefinition carries its routes through', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      const appDef = ApplicationDefinition(
        title: 'Typed App',
        version: '1.0.0',
        routes: {'/': 'main'},
      );

      await runtime.initializeFromDefinition(appDef, pageLoader: (_) async => {});
      expect(runtime.engine.routeManager?.appDefinition.routes.keys,
          contains('/'));
      expect(
        () => runtime.initializeFromDefinition(appDef, pageLoader: (_) async => {}),
        throwsA(isA<StateError>()),
      );
      await runtime.dispose();
    });
  });

  group('dispose', () {
    testWidgets('the document is gone afterwards and the seams are closed',
        (tester) async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      await runtime.initialize(
          _page(content: const {'type': 'text', 'content': 'visible'}));
      await _render(tester, runtime);
      expect(find.text('visible'), findsOneWidget);

      await runtime.dispose();

      expect(runtime.isInitialized, isFalse);
      expect(runtime.getUIDefinition(), isNull);
      expect(() => runtime.buildUI(), throwsA(isA<StateError>()));
      expect(() => runtime.updateState('x', 1), throwsA(isA<StateError>()));
    });

    test('a channel declared by the document is stopped', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      await runtime.initialize(_page(extra: const {
        'channels': {
          'timer': {
            'type': 'client.poll',
            'params': {'interval': 5000},
          },
        },
      }));
      final channels = runtime.channelManager!;
      expect(channels.hasChannel('timer'), isTrue);

      await runtime.dispose();
      expect(channels.hasChannel('timer'), isFalse,
          reason: 'a poll left running after the page closed keeps firing at '
              'the server for the life of the process');
    });

    test('disposing twice, and destroy, are the same thing', () async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      await runtime.initialize(_page());
      await runtime.dispose();
      await runtime.dispose();
      await runtime.destroy();
      expect(runtime.isInitialized, isFalse);
    });
  });

  group('registerWidget — the host extension seam', () {
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

    testWidgets('and the registered factory is the one that builds it',
        (tester) async {
      final runtime = MCPUIRuntime(enableDebugMode: false);
      runtime.registerWidget('vendorGauge', _DummyWidgetFactory());
      await runtime.initialize({
        'type': 'page',
        'content': <String, dynamic>{'type': 'vendorGauge', 'reading': 12},
      });
      await _render(tester, runtime);

      expect(find.byKey(_DummyWidgetFactory.rendered), findsOneWidget,
          reason: 'accepting the type at validation and then rendering '
              'nothing would be the worse half of the same bug');
      await runtime.dispose();
    });
  });

  test('handleError only logs — the runtime has no error surface of its own',
      () {
    // Pinned rather than asserted: `handleError` writes to the logger and
    // nothing else. A host calling it must not expect the document to show
    // anything; if an error belongs on screen, it has to be written to state.
    // Recorded here so the next reader does not go looking for the surface.
    final runtime = MCPUIRuntime(enableDebugMode: false);
    runtime.handleError('Test error');
    runtime.handleError('');
    expect(runtime.isInitialized, isFalse);
  });
}

/// A host widget factory that leaves a mark on the screen, so registration can
/// be checked by looking rather than by trusting the map.
class _DummyWidgetFactory extends WidgetFactory {
  static const rendered = Key('vendor-gauge-rendered');

  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    return const SizedBox(key: rendered, width: 10, height: 10);
  }
}

class _DummyActionExecutor extends ActionExecutor {
  @override
  Future<ActionResult> execute(
    Map<String, dynamic> action,
    RenderContext context,
  ) async =>
      ActionResult.success();
}

class _RecordingActionExecutor extends ActionExecutor {
  final seen = <Map<String, dynamic>>[];

  @override
  Future<ActionResult> execute(
    Map<String, dynamic> action,
    RenderContext context,
  ) async {
    seen.add(action);
    return ActionResult.success();
  }
}
