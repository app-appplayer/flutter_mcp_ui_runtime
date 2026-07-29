import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/client_actions/executors/storage_action_executor.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';

/// `view` widget — MCP UI DSL v1.4 Composition Profile.
///
/// Covers spec §2.13.1 (widget), §1.9 (DefinitionSource forms), §6.11
/// (resolution + failure/lifecycle), §7.10.1 (origin isolation), §18.7.3
/// (fail-closed without the profile).
void main() {
  remainingOriginAxesTests();
  embeddedScopeLifetimeTests();
  ambientOriginTests();
  resolverReachesEveryContextTests();
  late WidgetRegistry registry;
  late StateManager stateManager;
  late BindingEngine bindingEngine;
  late Renderer renderer;

  setUp(() {
    registry = WidgetRegistry();
    DefaultWidgets.registerAll(registry);
    stateManager = StateManager();
    bindingEngine = BindingEngine();
    renderer = Renderer(
      widgetRegistry: registry,
      stateManager: stateManager,
      bindingEngine: bindingEngine,
      actionHandler: ActionHandler(),
    );
  });

  Future<void> pump(WidgetTester tester, Map<String, dynamic> definition) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => renderer.renderWidget(
              definition,
              renderer.createRootContext(ctx),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('view — DefinitionSource forms (§1.9.1)', () {
    testWidgets('inline definition renders directly, no resolver needed',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'view',
        'source': <String, dynamic>{'type': 'text', 'content': 'inline ok'},
      });
      expect(find.text('inline ok'), findsOneWidget);
    });

    testWidgets('qualified ref resolves through the host resolver',
        (tester) async {
      renderer.definitionResolver = (ref, origin) async {
        expect(ref, 'ui://views/summary');
        expect(origin['connection'], 'c-temp');
        return <String, dynamic>{'type': 'text', 'content': 'temp 21C'};
      };

      await pump(tester, <String, dynamic>{
        'type': 'view',
        'source': <String, dynamic>{
          r'$ref': 'ui://views/summary',
          'from': <String, dynamic>{'connection': 'c-temp'},
        },
      });
      expect(find.text('temp 21C'), findsOneWidget);
    });

    testWidgets('origin connection may be a binding', (tester) async {
      stateManager.initialize(<String, dynamic>{
        'conn': <String, dynamic>{'temp': 'c-from-state'},
      });
      String? seen;
      renderer.definitionResolver = (ref, origin) async {
        seen = origin['connection'] as String?;
        return <String, dynamic>{'type': 'text', 'content': 'bound'};
      };

      await pump(tester, <String, dynamic>{
        'type': 'view',
        'source': <String, dynamic>{
          r'$ref': 'ui://app',
          'from': <String, dynamic>{'connection': '{{conn.temp}}'},
        },
      });
      expect(seen, 'c-from-state');
      expect(find.text('bound'), findsOneWidget);
    });

    testWidgets('embedded application renders its initialRoute page',
        (tester) async {
      renderer.definitionResolver = (ref, origin) async => <String, dynamic>{
            'type': 'application',
            'initialRoute': '/main',
            'routes': <String, dynamic>{
              '/main': <String, dynamic>{
                'type': 'page',
                'content': <String, dynamic>{
                  'type': 'text',
                  'content': 'device home',
                },
              },
            },
          };

      await pump(tester, <String, dynamic>{
        'type': 'view',
        'source': <String, dynamic>{
          r'$ref': 'ui://app',
          'from': <String, dynamic>{'connection': 'c1'},
        },
      });
      expect(find.text('device home'), findsOneWidget);
    });
  });

  group('view — fail closed without the Composition Profile (§18.7.3)', () {
    testWidgets('no resolver registered → fallback, never the host origin',
        (tester) async {
      // renderer.definitionResolver deliberately left null.
      await pump(tester, <String, dynamic>{
        'type': 'view',
        'source': <String, dynamic>{
          r'$ref': 'ui://app',
          'from': <String, dynamic>{'connection': 'c1'},
        },
        'fallback': <String, dynamic>{
          'type': 'text',
          'content': 'not supported',
        },
      });
      expect(find.text('not supported'), findsOneWidget);
    });

    testWidgets('unknown origin: resolver throws → fallback', (tester) async {
      renderer.definitionResolver = (ref, origin) async {
        throw StateError('unknown origin');
      };
      await pump(tester, <String, dynamic>{
        'type': 'view',
        'source': <String, dynamic>{
          r'$ref': 'ui://app',
          'from': <String, dynamic>{'satellite': 'nope'},
        },
        'fallback': <String, dynamic>{'type': 'text', 'content': 'offline'},
      });
      expect(find.text('offline'), findsOneWidget);
    });
  });

  group('view — failure is local (§6.11.4)', () {
    testWidgets('one dead origin does not take down its siblings',
        (tester) async {
      renderer.definitionResolver = (ref, origin) async {
        if (origin['connection'] == 'dead') {
          throw StateError('unreachable');
        }
        return <String, dynamic>{
          'type': 'text',
          'content': 'live ${origin['connection']}',
        };
      };

      await pump(tester, <String, dynamic>{
        'type': 'linear',
        'direction': 'vertical',
        'children': <dynamic>[
          <String, dynamic>{
            'type': 'view',
            'source': <String, dynamic>{
              r'$ref': 'ui://v',
              'from': <String, dynamic>{'connection': 'a'},
            },
          },
          <String, dynamic>{
            'type': 'view',
            'source': <String, dynamic>{
              r'$ref': 'ui://v',
              'from': <String, dynamic>{'connection': 'dead'},
            },
            'fallback': <String, dynamic>{
              'type': 'text',
              'content': 'sensor offline',
            },
          },
          <String, dynamic>{
            'type': 'view',
            'source': <String, dynamic>{
              r'$ref': 'ui://v',
              'from': <String, dynamic>{'connection': 'b'},
            },
          },
        ],
      });

      expect(find.text('live a'), findsOneWidget);
      expect(find.text('sensor offline'), findsOneWidget);
      expect(find.text('live b'), findsOneWidget);
    });
  });

  group('view — origin isolation (§7.10.1)', () {
    testWidgets('embedded scope cannot read the embedder state', (tester) async {
      stateManager.initialize(<String, dynamic>{'secret': 'embedder-only'});
      renderer.definitionResolver = (ref, origin) async => <String, dynamic>{
            'type': 'text',
            'content': '[{{secret}}]',
          };

      await pump(tester, <String, dynamic>{
        'type': 'view',
        'source': <String, dynamic>{
          r'$ref': 'ui://v',
          'from': <String, dynamic>{'connection': 'c1'},
        },
      });

      // The embedder's value must NOT leak into the embedded scope.
      expect(find.text('[embedder-only]'), findsNothing);
    });

    testWidgets('props is the one channel in (§7.10.1 rule 2)', (tester) async {
      renderer.definitionResolver = (ref, origin) async => <String, dynamic>{
            'type': 'text',
            'content': '{{label}}',
          };

      await pump(tester, <String, dynamic>{
        'type': 'view',
        'source': <String, dynamic>{
          r'$ref': 'ui://v',
          'from': <String, dynamic>{'connection': 'c1'},
        },
        'props': <String, dynamic>{'label': 'passed in'},
      });

      expect(find.text('passed in'), findsOneWidget);
    });
  });

  group('view — catalog registration', () {
    test('`view` is a registered widget type', () {
      expect(registry.has('view'), isTrue);
    });
  });
}

/// The resolver has to reach the context a page is actually rendered with.
///
/// `MCPUIRuntime.registerDefinitionResolver` stores the resolver on the
/// renderer, and contexts used to copy it at construction. Two of the five
/// construction sites did not — including the router's, which is the path a
/// bundle takes — so a host that had claimed the Composition Profile still saw
/// `view` report that the runtime does not implement it. Reading through the
/// renderer makes the profile reach the tree by construction instead of by
/// every author remembering.
void resolverReachesEveryContextTests() {
  group('resolver reach (v1.4)', () {
    late Renderer renderer;

    setUp(() {
      renderer = Renderer(
        widgetRegistry: WidgetRegistry(),
        bindingEngine: BindingEngine(),
        actionHandler: ActionHandler(),
        stateManager: StateManager(),
      );
    });

    RenderContext bareContext() => RenderContext(
          renderer: renderer,
          stateManager: StateManager(),
          bindingEngine: BindingEngine(),
          actionHandler: ActionHandler(),
          themeManager: ThemeManager(),
        );

    Future<Map<String, dynamic>> resolve(String ref, Map<String, dynamic> o) async =>
        <String, dynamic>{'type': 'text', 'text': ref};

    test('a context built without one reads the renderer\'s', () {
      renderer.definitionResolver = resolve;
      expect(bareContext().definitionResolver, isNotNull,
          reason: 'the construction site should not have to remember');
    });

    test('with no resolver anywhere it stays null so `view` fails closed', () {
      expect(bareContext().definitionResolver, isNull);
    });

    test('a context-level resolver still wins over the renderer\'s', () {
      renderer.definitionResolver = resolve;
      Future<Map<String, dynamic>> other(String r, Map<String, dynamic> o) async =>
          <String, dynamic>{'type': 'text', 'text': 'other'};
      final ctx = bareContext()..definitionResolver = other;
      expect(ctx.definitionResolver, same(other));
    });

    test('child contexts keep reaching it', () {
      renderer.definitionResolver = resolve;
      expect(bareContext().createChildContext(id: 'a').definitionResolver,
          isNotNull);
    });
  });
}

/// A subtree embedded by `view` must ACT against its origin, not just render
/// against it (spec §1.9.5, §2.13.1, §7.10).
///
/// This exists because the composed screen looked finished and did nothing: the
/// tiles rendered each device's UI, and every button inside them called the
/// app's own session, which had no client for that device's tools. Rendering
/// and acting are separate halves and only one of them was implemented.
void ambientOriginTests() {
  group('ambient origin (v1.4)', () {
    late Renderer renderer;

    setUp(() {
      renderer = Renderer(
        widgetRegistry: WidgetRegistry(),
        bindingEngine: BindingEngine(),
        actionHandler: ActionHandler(),
        stateManager: StateManager(),
      );
    });

    RenderContext root() => RenderContext(
          renderer: renderer,
          stateManager: StateManager(),
          bindingEngine: BindingEngine(),
          actionHandler: ActionHandler(),
          themeManager: ThemeManager(),
        );

    test('an embedded scope carries the origin it was resolved from', () {
      final ctx = root()..origin = <String, dynamic>{'connection': 'esp32.node'};
      final embedded = ctx.createEmbeddedScope();
      expect(embedded.origin, <String, dynamic>{'connection': 'esp32.node'});
    });

    test('descendants of a scoped subtree keep the origin', () {
      final ctx = root()..origin = <String, dynamic>{'connection': 'a'};
      expect(ctx.createChildContext(id: 'x').createChildContext(id: 'y').origin,
          <String, dynamic>{'connection': 'a'});
    });

    test('an unscoped tree has no origin — it is the app\'s own', () {
      expect(root().origin, isNull);
      expect(root().createChildContext(id: 'x').origin, isNull);
    });

    test('the origin tool caller is reached through the renderer', () {
      Future<dynamic> call(Map<String, dynamic> o, String t,
              Map<String, dynamic> p) async =>
          'ok';
      renderer.originToolCaller = call;
      expect(root().originToolCaller, isNotNull,
          reason: 'the construction site should not have to carry it');
    });

    test('a tool action inside a scoped subtree goes to the origin', () async {
      final calls = <List<Object?>>[];
      renderer.originToolCaller = (origin, tool, params) async {
        calls.add(<Object?>[origin, tool, params]);
        return <String, dynamic>{'ok': true};
      };
      final handler = ActionHandler();
      final ctx = root()..origin = <String, dynamic>{'connection': 'esp32.node'};

      final result = await handler.execute(<String, dynamic>{
        'type': 'tool',
        'tool': 'led.set',
        'params': <String, dynamic>{'on': true},
      }, ctx);

      expect(result.success, isTrue);
      expect(calls, hasLength(1));
      expect(calls.single[0], <String, dynamic>{'connection': 'esp32.node'});
      expect(calls.single[1], 'led.set');
      expect(calls.single[2], <String, dynamic>{'on': true});
    });

    test('a scoped subtree with no bridge fails instead of calling our server',
        () async {
      // Silently taking the app's own path is what produced a screen that
      // rendered and did nothing; running another device's tool name against
      // this app's server would be worse still.
      final handler = ActionHandler();
      final ctx = root()..origin = <String, dynamic>{'connection': 'esp32.node'};
      final result = await handler.execute(<String, dynamic>{
        'type': 'tool',
        'tool': 'led.set',
      }, ctx);
      expect(result.success, isFalse);
      expect(result.error, contains('another origin'));
    });
  });
}

/// The embedded scope must live as long as the mounted view.
///
/// The scope owns a fresh StateManager (§6.11.3, §7.10.1). Building it inside
/// `build()` meant every rebuild replaced it: a subscription would write the
/// device's value, that write triggered a rebuild, and the rebuild discarded
/// the value. The live reading rendered its label and never a number — with
/// the host layer visibly succeeding, which is what made it hard to see.
void embeddedScopeLifetimeTests() {
  group('embedded scope lifetime (v1.4)', () {
    test('a scope keeps its state across reads', () {
      final renderer = Renderer(
        widgetRegistry: WidgetRegistry(),
        bindingEngine: BindingEngine(),
        actionHandler: ActionHandler(),
        stateManager: StateManager(),
      );
      final parent = RenderContext(
        renderer: renderer,
        stateManager: StateManager(),
        bindingEngine: BindingEngine(),
        actionHandler: ActionHandler(),
        themeManager: ThemeManager(),
      );

      final scope = parent.createEmbeddedScope();
      scope.setValue('uptime', <String, dynamic>{'uptime_s': 42});
      expect(scope.getValue<Map<String, dynamic>>('uptime')?['uptime_s'], 42);

      // A second scope is a different state tree — which is exactly why one
      // must not be minted per build.
      final other = parent.createEmbeddedScope();
      expect(other.getValue<Object>('uptime'), isNull,
          reason: 'each scope is isolated, so reusing one matters');
    });
  });
}

/// The remaining axes an ambient origin must scope: one-shot reads, storage,
/// and permissions (spec §1.9.5, §2.13.1, §7.10.1).
///
/// Tools and subscriptions were done first because they are what a user
/// notices. These three fail more quietly: a read returns the embedder's
/// resource under the embedded document's uri (a wrong answer, not a missing
/// one), two devices silently share a key space, and an embedded document can
/// ask for — and be granted — more than the app embedding it ever held.
void remainingOriginAxesTests() {
  group('origin scoping — reads, storage, permissions (v1.4)', () {
    late Renderer renderer;

    setUp(() {
      renderer = Renderer(
        widgetRegistry: WidgetRegistry(),
        bindingEngine: BindingEngine(),
        actionHandler: ActionHandler(),
        stateManager: StateManager(),
      );
    });

    RenderContext scoped(String? connection) {
      final ctx = RenderContext(
        renderer: renderer,
        stateManager: StateManager(),
        bindingEngine: BindingEngine(),
        actionHandler: ActionHandler(),
        themeManager: ThemeManager(),
      );
      if (connection != null) {
        ctx.origin = <String, dynamic>{'connection': connection};
      }
      return ctx;
    }

    test('a one-shot read goes to the origin, not the app', () async {
      final asked = <List<Object?>>[];
      renderer.originResourceReader = (origin, uri) async {
        asked.add(<Object?>[origin, uri]);
        return <String, dynamic>{'v': 1};
      };
      final handler = ActionHandler();
      final ctx = scoped('esp32.node');

      final r = await handler.execute(<String, dynamic>{
        'type': 'resource',
        'action': 'read',
        'uri': 'sensor://uptime',
        'binding': 'up',
      }, ctx);

      expect(r.success, isTrue);
      expect(asked.single[0], <String, dynamic>{'connection': 'esp32.node'});
      expect(asked.single[1], 'sensor://uptime');
      expect(ctx.getValue<Map<String, dynamic>>('up')?['v'], 1);
    });

    test('a scoped read with no reader fails rather than reading ours',
        () async {
      final handler = ActionHandler();
      final r = await handler.execute(<String, dynamic>{
        'type': 'resource',
        'action': 'read',
        'uri': 'sensor://uptime',
      }, scoped('esp32.node'));

      expect(r.success, isFalse);
      expect(r.error, contains('another origin'));
    });

    test('an unscoped read is untouched', () async {
      // Every pre-composition document must behave exactly as before.
      var originReads = 0;
      renderer.originResourceReader = (_, __) async => originReads++;
      final handler = ActionHandler();

      await handler.execute(<String, dynamic>{
        'type': 'resource',
        'action': 'read',
        'uri': 'sensor://uptime',
      }, scoped(null));

      expect(originReads, 0, reason: 'the app keeps its own path');
    });

    test('two origins do not share a storage key space', () async {
      final exec = StorageActionExecutor();
      Future<void> set(String conn, Object v) => exec.execute(
            'client.storage.set',
            <String, dynamic>{'key': 'config', 'value': v},
            scoped(conn),
          );
      Future<Object?> get(String? conn) async {
        final r = await exec.execute('client.storage.get',
            <String, dynamic>{'key': 'config'}, scoped(conn));
        return (r.data as Map<String, dynamic>)['value'];
      }

      await set('esp32.node', 'A');
      await set('stm32.h723', 'B');

      expect(await get('esp32.node'), 'A',
          reason: 'the second device must not overwrite the first');
      expect(await get('stm32.h723'), 'B');
      expect(await get(null), isNull,
          reason: "and neither writes into the app's own space");
    });

    test('the app\'s own storage keys are unchanged', () async {
      final exec = StorageActionExecutor();
      await exec.execute('client.storage.set',
          <String, dynamic>{'key': 'k', 'value': 1}, scoped(null));
      final r = await exec.execute(
          'client.storage.get', <String, dynamic>{'key': 'k'}, scoped(null));
      expect((r.data as Map<String, dynamic>)['value'], 1);
    });
  });
}


