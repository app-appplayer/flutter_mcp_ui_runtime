// `view` — what happens when the source changes, and when it is wrong.
//
// The sibling suite covers resolving a source once. This covers the second
// time: a `view` whose `source` is bound to state points somewhere new when
// that state moves, and the widget has to drop the old definition rather than
// keep rendering it. It also covers the malformed sources — a `$ref` that is
// not a string, a `from` that is not an origin — which are the shapes a
// document arrives in while it is being written.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late WidgetRegistry registry;
  late StateManager stateManager;
  late BindingEngine bindingEngine;
  late Renderer renderer;
  late List<String> resolved;

  setUp(() {
    registry = WidgetRegistry();
    DefaultWidgets.registerAll(registry);
    stateManager = StateManager()..initialize(<String, dynamic>{});
    bindingEngine = BindingEngine();
    resolved = [];
    renderer = Renderer(
      widgetRegistry: registry,
      stateManager: stateManager,
      bindingEngine: bindingEngine,
      actionHandler: ActionHandler(),
    );
  });

  /// A resolver that answers with a page naming the uri it was asked for.
  void wireResolver({Duration delay = Duration.zero}) {
    renderer.definitionResolver = (uri, origin) async {
      resolved.add(uri);
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      return <String, dynamic>{
        'type': 'text',
        'content': 'resolved: $uri',
      };
    };
  }

  Future<void> pump(WidgetTester tester, Map<String, dynamic> definition) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => AnimatedBuilder(
            animation: stateManager,
            builder: (_, __) =>
                renderer.renderWidget(definition, renderer.createRootContext(ctx)),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('a source that moves', () {
    testWidgets('a bound source that changes is resolved again',
        (tester) async {
      wireResolver();
      stateManager.set('target', 'ui://pages/first');

      await pump(tester, {'type': 'view', 'source': '{{target}}'});
      expect(find.text('resolved: ui://pages/first'), findsOneWidget);

      stateManager.set('target', 'ui://pages/second');
      await tester.pumpAndSettle();

      expect(find.text('resolved: ui://pages/second'), findsOneWidget,
          reason: 'a view still showing the old definition after its source '
              'moved is showing one server\'s screen under another\'s name');
      expect(resolved, ['ui://pages/first', 'ui://pages/second']);
    });

    testWidgets('a source that does not change is not resolved again',
        (tester) async {
      wireResolver();
      stateManager.set('target', 'ui://pages/first');
      stateManager.set('unrelated', 1);

      await pump(tester, {'type': 'view', 'source': '{{target}}'});
      stateManager.set('unrelated', 2);
      await tester.pumpAndSettle();

      expect(resolved, ['ui://pages/first'],
          reason: 'a rebuild is not a source change; re-resolving on every '
              'one costs a round trip per frame');
    });

    testWidgets('an inline definition that changes is swapped', (tester) async {
      stateManager.set('inline', {'type': 'text', 'content': 'first'});

      await pump(tester, {'type': 'view', 'source': '{{inline}}'});
      expect(find.text('first'), findsOneWidget);

      stateManager.set('inline', {'type': 'text', 'content': 'second'});
      await tester.pumpAndSettle();

      expect(find.text('second'), findsOneWidget);
    });

    testWidgets('an identical inline definition is not rebuilt from scratch',
        (tester) async {
      stateManager.set('inline', {'type': 'text', 'content': 'same'});

      await pump(tester, {'type': 'view', 'source': '{{inline}}'});
      stateManager.set('inline', {'type': 'text', 'content': 'same'});
      await tester.pumpAndSettle();

      expect(find.text('same'), findsOneWidget,
          reason: 'the comparison is by content, so an equal map arriving in a '
              'new object must not tear the embedded scope down');
    });
  });

  group('a source that cannot be read', () {
    testWidgets('a source that is neither a map nor a uri is reported',
        (tester) async {
      await pump(tester, {
        'type': 'view',
        'source': 42,
        'onError': {
          'type': 'state',
          'action': 'set',
          'binding': 'problem',
          'value': '{{event.error}}',
        },
      });
      await tester.pumpAndSettle();

      expect(stateManager.get<String>('problem'),
          contains('definition, a uri, or a binding'));
    });

    testWidgets(r'a $ref that is not a string is reported', (tester) async {
      wireResolver();
      await pump(tester, {
        'type': 'view',
        'source': {r'$ref': 42},
        'onError': {
          'type': 'state',
          'action': 'set',
          'binding': 'problem',
          'value': '{{event.error}}',
        },
      });
      await tester.pumpAndSettle();

      expect(stateManager.get<String>('problem'), contains(r'$ref'));
      expect(resolved, isEmpty);
    });

    testWidgets('a `from` that is not an origin object is reported',
        (tester) async {
      wireResolver();
      await pump(tester, {
        'type': 'view',
        'source': {r'$ref': 'ui://pages/first', 'from': 'server-a'},
        'onError': {
          'type': 'state',
          'action': 'set',
          'binding': 'problem',
          'value': '{{event.error}}',
        },
      });
      await tester.pumpAndSettle();

      expect(stateManager.get<String>('problem'), contains('Origin'),
          reason: '§7.10.1 — the origin decides whose permissions the embedded '
              'definition spends, so a malformed one cannot be guessed at');
      expect(resolved, isEmpty);
    });

    testWidgets('a resolver that throws falls back rather than failing the page',
        (tester) async {
      renderer.definitionResolver = (uri, origin) async =>
          throw StateError('that server is not reachable');

      await pump(tester, {
        'type': 'view',
        'source': 'ui://pages/first',
        'fallback': {'type': 'text', 'content': 'unavailable for now'},
      });
      await tester.pumpAndSettle();

      expect(find.text('unavailable for now'), findsOneWidget,
          reason: 'per-view containment is the point: one embedded server '
              'being down must not take the page with it');
    });

    testWidgets('a fallback that itself fails degrades to the indicator',
        (tester) async {
      renderer.definitionResolver = (uri, origin) async =>
          throw StateError('that server is not reachable');

      await pump(tester, {
        'type': 'view',
        'source': 'ui://pages/first',
        'fallback': {'type': 'noSuchWidget'},
      });
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'a failing fallback escalating into a page-level failure '
              'defeats the containment it was written for');
    });
  });

  group('while it is resolving', () {
    testWidgets('a declared loading widget is shown instead of the spinner',
        (tester) async {
      wireResolver(delay: const Duration(milliseconds: 200));

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => renderer.renderWidget({
              'type': 'view',
              'source': 'ui://pages/first',
              'loading': {'type': 'text', 'content': 'fetching the panel'},
            }, renderer.createRootContext(ctx)),
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('fetching the panel'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: 'a declared loading state that is ignored makes every '
              'embedded panel look the same while it waits');

      // The delay is a real Future, so the fake clock has to be advanced past
      // it before the resolved definition can arrive.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('resolved: ui://pages/first'), findsOneWidget);
    });

    testWidgets('with no loading widget there is a spinner', (tester) async {
      wireResolver(delay: const Duration(milliseconds: 200));

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => renderer.renderWidget({
              'type': 'view',
              'source': 'ui://pages/first',
            }, renderer.createRootContext(ctx)),
          ),
        ),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });
}
