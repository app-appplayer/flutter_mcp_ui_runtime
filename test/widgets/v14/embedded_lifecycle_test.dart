import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';

/// Embedded-definition lifecycle, in its own file.
///
/// These mount structurally identical trees. Sharing a file with the rest of
/// the `view` suite let Flutter reuse the State between tests, so a later test
/// asserted against an earlier one's already-resolved view and failed for a
/// reason that had nothing to do with the behaviour under test.
void main() {
  embeddedLifecycleTests();
}

/// An embedded definition's own lifecycle must run.
///
/// A definition is the lifecycle-aware entity (§6.8). Mounting one without
/// firing its hooks changes what the document does: a device whose `onReady`
/// subscribes to its own live reading showed a value that never arrived, and
/// the only way to get it was a manual control the author had added as an
/// override. Observed on real hardware — the reading was blank until
/// `Subscribe` was tapped, in a screen where the device's own app fills it in
/// by itself.
void embeddedLifecycleTests() {
  testWidgets('an embedded definition fires onReady once and seeds state',
      (tester) async {
    // One handler for both the renderer and the context: an embedded scope
    // inherits its embedder's handler.
    final handler = ActionHandler();
    final renderer = Renderer(
      widgetRegistry: _registryWithDefaults(),
      bindingEngine: BindingEngine(),
      actionHandler: handler,
      stateManager: StateManager(),
    );
    renderer.definitionResolver = (ref, origin) async => <String, dynamic>{
          'type': 'page',
          'content': <String, dynamic>{
            'type': 'text',
            'text': 'seeded={{seed}} ready={{ready}}',
          },
          'state': <String, dynamic>{
            'initial': <String, dynamic>{'seed': 'yes'},
          },
          // A state write, not a tool call: state lands on screen, so whether
          // the hook ran is observable rather than inferred.
          'onReady': <dynamic>[
            <String, dynamic>{
              'type': 'state',
              'action': 'set',
              'path': 'ready',
              'value': 'fired',
            },
          ],
        };

    final ctx = RenderContext(
      renderer: renderer,
      stateManager: StateManager(),
      bindingEngine: BindingEngine(),
      actionHandler: handler,
      themeManager: ThemeManager(),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: renderer.renderWidget(<String, dynamic>{
          'type': 'view',
          'source': <String, dynamic>{
            r'$ref': 'ui://app',
            'from': <String, dynamic>{'connection': 'dev'},
          },
        }, ctx),
      ),
    ));
    await tester.pumpAndSettle();

    // What actually rendered — a view that never resolved would show its
    // unavailable indicator instead, and the hook assertion below would then
    // be reporting the wrong thing.
    expect(find.text('seeded=yes ready=fired'), findsOneWidget,
        reason: '`state.initial` seeds the scope and `onReady` then runs in it');
  });

  testWidgets('an embedded app whose route is a uri keeps the origin',
      (tester) async {
    // A route value that is a bare uri carries no origin of its own. Reading it
    // against the embedder means an embedded device app renders nothing —
    // observed on the bench as one board appearing (it inlined its page) and
    // the other showing only "Unavailable" (its route was a uri).
    final asked = <List<Object?>>[];
    var hookRan = false;
    final handler = ActionHandler()
      ..registerToolExecutor('mark', (_) async {
        hookRan = true;
        return <String, dynamic>{'ok': true};
      })
      ;
    final renderer = Renderer(
      widgetRegistry: _registryWithDefaults(),
      bindingEngine: BindingEngine(),
      actionHandler: handler,
      stateManager: StateManager(),
    );
    // A hook inside an origin-scoped subtree routes its tool call to that
    // origin (§1.9.5), so the host bridge has to be wired here exactly as a
    // real host wires it — otherwise the hook fires and fails, which is
    // indistinguishable from the hook never firing.
    renderer.originToolCaller = (origin, tool, params) async {
      if (tool == 'mark') hookRan = true;
      return <String, dynamic>{'ok': true};
    };
    renderer.definitionResolver = (ref, origin) async {
      asked.add(<Object?>[ref, origin]);
      if (ref == 'ui://app') {
        return <String, dynamic>{
          'type': 'application',
          'initialRoute': '/',
          'routes': <String, dynamic>{'/': 'ui://page/main'},
          'onReady': <dynamic>[
            <String, dynamic>{'type': 'tool', 'tool': 'mark'},
          ],
        };
      }
      return <String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{'type': 'text', 'text': 'device page'},
      };
    };

    final ctx = RenderContext(
      renderer: renderer,
      stateManager: StateManager(),
      bindingEngine: BindingEngine(),
      actionHandler: handler,
      themeManager: ThemeManager(),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: KeyedSubtree(
          // Structurally identical trees across tests let Flutter reuse the
          // State, so a later test would assert against an earlier one's
          // already-resolved view.
          key: const ValueKey<String>('uri-route-case'),
          child: renderer.renderWidget(<String, dynamic>{
            'type': 'view',
            'source': <String, dynamic>{
              r'$ref': 'ui://app',
              'from': <String, dynamic>{'connection': 'uri-route-board'},
            },
          }, ctx),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('device page'), findsOneWidget);
    expect(hookRan, isTrue,
        reason: "the embedded application's own onReady must fire — a device "
            'that subscribes to its own live reading otherwise shows a label '
            'with no value');
    expect(asked, hasLength(2), reason: 'the uri route resolves one level down');
    expect(asked[1][0], 'ui://page/main');
    expect(asked[1][1], <String, dynamic>{'connection': 'uri-route-board'},
        reason: 'the route belongs to the app that declared it');
  });

  testWidgets('an equal source rebuilt each frame does not re-resolve',
      (tester) async {
    // An embedded application whose route is a uri produces a fresh
    // `{$ref, from}` map on every build. Compared by identity that reads as a
    // changed origin, so the view resolves, renders, rebuilds and resolves
    // again — on the bench the tile flickered between its content and its
    // spinner, then stuck on the spinner.
    var resolves = 0;
    final handler = ActionHandler();
    final renderer = Renderer(
      widgetRegistry: _registryWithDefaults(),
      bindingEngine: BindingEngine(),
      actionHandler: handler,
      stateManager: StateManager(),
    );
    renderer.definitionResolver = (ref, origin) async {
      resolves++;
      if (ref == 'ui://app') {
        return <String, dynamic>{
          'type': 'application',
          'initialRoute': '/',
          'routes': <String, dynamic>{'/': 'ui://page/main'},
        };
      }
      return <String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{'type': 'text', 'text': 'stable'},
      };
    };

    final ctx = RenderContext(
      renderer: renderer,
      stateManager: StateManager(),
      bindingEngine: BindingEngine(),
      actionHandler: handler,
      themeManager: ThemeManager(),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: KeyedSubtree(
          // Structurally identical trees across tests let Flutter reuse the
          // State, so a later test would assert against an earlier one's
          // already-resolved view.
          key: const ValueKey<String>('stable-source-case'),
          child: renderer.renderWidget(<String, dynamic>{
            'type': 'view',
            'source': <String, dynamic>{
              r'$ref': 'ui://app',
              'from': <String, dynamic>{'connection': 'stable-source-board'},
            },
          }, ctx),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final settled = resolves;

    // Several more frames must not resolve anything again.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();

    expect(find.text('stable'), findsOneWidget);
    expect(resolves, settled,
        reason: 'a source with identical meaning is not a changed source');
    expect(settled, 2, reason: 'the app and the page it routes to, once each');
  });
}


WidgetRegistry _registryWithDefaults() {
  final registry = WidgetRegistry();
  DefaultWidgets.registerAll(registry);
  return registry;
}
