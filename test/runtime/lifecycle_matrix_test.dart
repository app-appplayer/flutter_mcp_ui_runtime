import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

/// The same document, mounted every way the runtime can mount one, must run
/// the same hooks in the same order (§1.5.2, §6.8.3).
///
/// Written because nothing pinned this before: an application, a routed page
/// and an embedded `view` each ran a different subset of the seven hooks, so a
/// page that subscribed in `onReady` streamed when embedded and sat dead when
/// opened on its own — and every layer reported success. A matrix is the only
/// shape that catches that, because each path passes its own tests in
/// isolation.
void main() {
  /// Records hook names in the order they fire, via a state action per hook.
  Map<String, dynamic> hookAction(String name) => <String, dynamic>{
        'type': 'state',
        'action': 'append',
        'binding': 'fired',
        'value': name,
      };

  Map<String, dynamic> hooksBlock() => <String, dynamic>{
        for (final h in const [
          'onInit',
          'onMount',
          'onReady',
          'onPause',
          'onUnmount',
          'onDestroy',
        ])
          h: hookAction(h),
      };

  group('parsing (§1.5.1, §1.5.3)', () {
    test('top-level placement is read', () {
      final hooks = LifecycleDefinition.fromDefinition(<String, dynamic>{
        'type': 'page',
        'onReady': [hookAction('onReady')],
      });
      expect(hooks.onReady, isNotNull);
      expect(hooks.onReady!.single['value'], 'onReady');
    });

    test('grouped placement is read', () {
      final hooks = LifecycleDefinition.fromDefinition(<String, dynamic>{
        'type': 'page',
        'lifecycle': {
          'onReady': [hookAction('onReady')]
        },
      });
      expect(hooks.onReady, isNotNull);
    });

    test('the two placements merge', () {
      final hooks = LifecycleDefinition.fromDefinition(<String, dynamic>{
        'type': 'page',
        'onInit': hookAction('onInit'),
        'lifecycle': {'onDestroy': hookAction('onDestroy')},
      });
      expect(hooks.onInit, isNotNull);
      expect(hooks.onDestroy, isNotNull);
    });

    test('a single Action is accepted, not only an array', () {
      final hooks = LifecycleDefinition.fromDefinition(<String, dynamic>{
        'type': 'page',
        'onReady': hookAction('onReady'),
      });
      expect(hooks.onReady, hasLength(1));
    });

    test('a hook named in both placements warns and keeps one copy', () {
      final hooks = LifecycleDefinition.fromDefinition(<String, dynamic>{
        'type': 'page',
        'onReady': hookAction('top'),
        'lifecycle': {'onReady': hookAction('grouped')},
      });
      expect(hooks.onReady, hasLength(1));
      expect(hooks.aliasWarnings, isNotEmpty);
      // §1.5.3 makes this an error; until 0.6.0 the grouped value wins so a
      // document that used to load still loads.
      expect(hooks.onReady!.single['value'], 'grouped');
    });

    test('deprecated names are accepted and warned about', () {
      final hooks = LifecycleDefinition.fromDefinition(<String, dynamic>{
        'type': 'page',
        'lifecycle': {
          'onInitialize': hookAction('a'),
          'onEnter': hookAction('b'),
          'onLeave': hookAction('c'),
        },
      });
      expect(hooks.onInit, isNotNull, reason: 'onInitialize → onInit');
      expect(hooks.onMount, isNotNull, reason: 'onEnter → onMount');
      expect(hooks.onUnmount, isNotNull, reason: 'onLeave → onUnmount');
      expect(hooks.aliasWarnings, hasLength(3));
    });

    test('no hooks declared reads as empty', () {
      final hooks = LifecycleDefinition.fromDefinition(
          <String, dynamic>{'type': 'page', 'content': <String, dynamic>{}});
      expect(hooks.isEmpty, isTrue);
    });
  });

  group('firing order (§1.5.2, §6.8.3)', () {
    test('mount runs onInit → onMount → onReady', () async {
      final fired = <String>[];
      final runner = LifecycleRunner(
        lifecycle: LifecycleDefinition.fromDefinition(hooksBlock()),
        execute: (a) async => fired.add(a['value'] as String),
      );
      await runner.mount();
      expect(fired, <String>['onInit', 'onMount', 'onReady']);
    });

    test('unmount runs onUnmount → onDestroy, without onPause', () async {
      // This used to expect `onPause` first, pinning the §6.8.3 text of the
      // time. That text contradicted §1.5.1, which reserves the hook for an
      // instance that loses focus *without* being destroyed, and §1.5.2,
      // which draws it as half of a pair. §6.8.3 now splits on whether the
      // outgoing instance survives; a destroyed one goes straight out.
      final fired = <String>[];
      final runner = LifecycleRunner(
        lifecycle: LifecycleDefinition.fromDefinition(hooksBlock()),
        execute: (a) async => fired.add(a['value'] as String),
      );
      await runner.mount();
      fired.clear();
      await runner.unmount();
      expect(fired, <String>['onUnmount', 'onDestroy']);
    });

    test('mount is idempotent — a rebuild must not re-subscribe', () async {
      final fired = <String>[];
      final runner = LifecycleRunner(
        lifecycle: LifecycleDefinition.fromDefinition(hooksBlock()),
        execute: (a) async => fired.add(a['value'] as String),
      );
      await runner.mount();
      await runner.mount();
      expect(fired, hasLength(3));
    });

    test('unmount without mount releases nothing', () async {
      final fired = <String>[];
      final runner = LifecycleRunner(
        lifecycle: LifecycleDefinition.fromDefinition(hooksBlock()),
        execute: (a) async => fired.add(a['value'] as String),
      );
      await runner.unmount();
      expect(fired, isEmpty,
          reason: 'releasing what was never started unsubscribes '
              'a resource this definition does not hold');
    });

    test('a failing hook does not stop the rest (§6.8.3)', () async {
      final fired = <String>[];
      final runner = LifecycleRunner(
        lifecycle: LifecycleDefinition.fromDefinition(hooksBlock()),
        execute: (a) async {
          if (a['value'] == 'onMount') throw StateError('boom');
          fired.add(a['value'] as String);
        },
      );
      await runner.mount();
      expect(fired, <String>['onInit', 'onReady']);
    });
  });

  group('a hook runs exactly once per transition', () {
    testWidgets('leaving a page tears it down once, not once per layer',
        (tester) async {
      // Teardown has one owner: the widget that mounted the page. Navigation
      // used to run it too, and once `onLeave` was folded onto its spec name
      // `onUnmount` the two overlapped — a page left behind fired onUnmount up
      // to three times and onDestroy twice, so an unsubscribe hook tried to
      // release a subscription that was already gone.
      final calls = <String>[];
      final runtime = MCPUIRuntime();
      await runtime.initialize(<String, dynamic>{
        'type': 'page',
        'title': 'T',
        'lifecycle': <String, dynamic>{
          'onUnmount': <String, dynamic>{'type': 'tool', 'tool': 'unmounted'},
          'onDestroy': <String, dynamic>{'type': 'tool', 'tool': 'destroyed'},
        },
        'content': <String, dynamic>{'type': 'text', 'content': 'hi'},
      });
      runtime.engine.actionHandler.registerToolExecutor(
        'unmounted',
        (String tool, Map<String, dynamic> params) async {
          calls.add(tool);
          return <String, dynamic>{};
        },
      );
      runtime.engine.actionHandler.registerToolExecutor(
        'destroyed',
        (String tool, Map<String, dynamic> params) async {
          calls.add(tool);
          return <String, dynamic>{};
        },
      );

      await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
      await tester.pumpAndSettle();
      calls.clear();

      // Replace the tree: the page widget leaves, which is the unmount.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();

      expect(calls.where((c) => c == 'unmounted').length, lessThanOrEqualTo(1),
          reason: 'onUnmount ran more than once');
      expect(calls.where((c) => c == 'destroyed').length, lessThanOrEqualTo(1),
          reason: 'onDestroy ran more than once');
      await runtime.destroy();
    });
  });

    test('navigating away does not tear the page down a second time',
        () async {
      // `loadPage` used to run the outgoing page's onUnmount and onDestroy on
      // top of the page widget's own dispose. This drives that path directly:
      // no widget mounts here, so anything that fires came from the navigation
      // code — which must now be nothing.
      //
      // Observed through state, not a tool: the lifecycle manager dispatches
      // on its own path and never reaches a registered tool executor, so a
      // tool-based probe would report "nothing ran" no matter what.
      final runtime = MCPUIRuntime();
      await runtime.initialize(
        <String, dynamic>{
          'type': 'page',
          'title': 'T',
          'lifecycle': <String, dynamic>{
            'onUnmount': <String, dynamic>{
              'type': 'state',
              'action': 'set',
              'path': 'tornDown',
              'value': 'unmount',
            },
            'onDestroy': <String, dynamic>{
              'type': 'state',
              'action': 'set',
              'path': 'tornDown',
              'value': 'destroy',
            },
          },
          'content': <String, dynamic>{'type': 'text', 'content': 'hi'},
        },
        pageLoader: (String route) async => <String, dynamic>{},
      );

      await runtime.engine.loadPage('/other');

      expect(runtime.engine.stateManager.get<String>('tornDown'), isNull,
          reason: 'teardown belongs to the page widget, not to navigation');
      await runtime.destroy();
    });

  group('every mount path runs the same hooks', () {
    /// The page document under test, written the way §6.8.1 shows it —
    /// hooks as top-level fields.
    Map<String, dynamic> pageDoc() => <String, dynamic>{
          'type': 'page',
          'title': 'T',
          ...hooksBlock(),
          'content': <String, dynamic>{'type': 'text', 'content': 'hi'},
        };

    testWidgets('routed page', (tester) async {
      final runtime = MCPUIRuntime();
      await runtime.initialize(pageDoc());
      await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
      await tester.pumpAndSettle();

      final fired = runtime.engine.stateManager.get<List<dynamic>>('fired');
      expect(fired, isNotNull,
          reason: 'a routed page ran no hooks at all before this');
      expect(fired!.cast<String>(),
          containsAllInOrder(<String>['onInit', 'onMount', 'onReady']));
      await runtime.destroy();
    });

    testWidgets('embedded view', (tester) async {
      // An embedded definition runs in its OWN scope (§6.11.3), so its hooks
      // write where the embedder cannot read them — that isolation is the
      // point. Observe them the only way that stays honest: on screen, in the
      // subtree they belong to.
      final host = MCPUIRuntime();
      await host.initialize(<String, dynamic>{
        'type': 'page',
        'title': 'host',
        'content': <String, dynamic>{
          'type': 'view',
          'source': <String, dynamic>{
            'type': 'page',
            'title': 'embedded',
            for (final h in const ['onInit', 'onMount', 'onReady'])
              h: <String, dynamic>{
                'type': 'state',
                'action': 'set',
                'path': h,
                'value': 'fired',
              },
            'content': <String, dynamic>{
              'type': 'text',
              'content': '{{onInit}}/{{onMount}}/{{onReady}}',
            },
          },
        },
      });
      await tester.pumpWidget(MaterialApp(home: host.buildUI()));
      await tester.pumpAndSettle();

      expect(find.text('fired/fired/fired'), findsOneWidget,
          reason: 'all three mount hooks ran in the embedded scope');
      await host.destroy();
    });

    testWidgets('instance-level hooks on a plain widget (§6.8.2)',
        (tester) async {
      final runtime = MCPUIRuntime();
      await runtime.initialize(<String, dynamic>{
        'type': 'page',
        'title': 'T',
        'content': <String, dynamic>{
          'type': 'box',
          'lifecycle': <String, dynamic>{'onMount': hookAction('boxMount')},
          'child': <String, dynamic>{'type': 'text', 'content': 'hi'},
        },
      });
      await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
      await tester.pumpAndSettle();

      final fired = runtime.engine.stateManager.get<List<dynamic>>('fired');
      expect(fired?.cast<String>(), contains('boxMount'),
          reason: 'a widget\'s own lifecycle block was never read');
      await runtime.destroy();
    });
  });
}
