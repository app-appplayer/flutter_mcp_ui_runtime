// The exported `MCPUIRuntime` — the surface a host actually calls.
//
// Registration order is the theme: nearly every register* method behaves
// differently before and after `initialize`, and a handler that silently fails
// to attach is a host feature that is simply never reached (the
// definition-level `onInit` defect in 0.6.1 was exactly that shape).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  Map<String, dynamic> page() => <String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{'type': 'text', 'content': 'hello'},
      };

  group('lifecycle flags', () {
    test('a fresh runtime is neither initialized nor ready', () {
      final runtime = MCPUIRuntime();
      expect(runtime.isInitialized, isFalse);
      expect(runtime.isReady, isFalse);
    });

    test('initialize marks initialized; ready waits for markReady', () async {
      final runtime = MCPUIRuntime();
      await runtime.initialize(page());
      expect(runtime.isInitialized, isTrue);
      expect(runtime.isReady, isFalse,
          reason: 'readiness is the `onReady` milestone, not the end of '
              'initialize — a host that renders before it is ready is the '
              'reason the two flags are separate');

      await runtime.engine.markReady();
      expect(runtime.isReady, isTrue);
      await runtime.destroy();
    });

    test('initializing twice is refused rather than silently reset', () async {
      final runtime = MCPUIRuntime();
      await runtime.initialize(page());
      expect(() => runtime.initialize(page()), throwsStateError);
      await runtime.destroy();
    });
  });

  group('state', () {
    test('reads and writes go through the same store', () async {
      final runtime = MCPUIRuntime();
      await runtime.initialize(<String, dynamic>{
        'type': 'page',
        'state': <String, dynamic>{
          'initial': <String, dynamic>{'count': 1}
        },
        'content': <String, dynamic>{'type': 'text', 'content': 'x'},
      });

      expect(runtime.stateManager.get<int>('count'), 1);
      runtime.stateManager.set('count', 5);
      expect(runtime.stateManager.get<int>('count'), 5);
      expect(runtime.stateManager.get<String>('nothing'), isNull);

      await runtime.destroy();
    });
  });

  group('actions through the engine', () {
    test('a state action reaches the store', () async {
      final runtime = MCPUIRuntime();
      await runtime.initialize(page());

      await runtime.engine.actionHandler.execute(
        <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'greeting',
          'value': 'hi',
        },
        runtime.engine.renderer.createRootContext(null),
      );

      expect(runtime.stateManager.get<String>('greeting'), 'hi');
      await runtime.destroy();
    });
  });

  group('tool executors', () {
    test('registering before initialize is refused by name', () async {
      final runtime = MCPUIRuntime();
      expect(
        () => runtime.registerToolExecutor('ping', (params) async => null),
        throwsStateError,
        reason: 'refusing loudly is the contract; storing it and forgetting '
            'to attach it would be the silent version of the same thing',
      );
    });

    test('a tool registered after initialize is called', () async {
      final runtime = MCPUIRuntime();
      var called = 0;

      await runtime.initialize(page());
      runtime.registerToolExecutor('ping', (params) async {
        called++;
        return <String, dynamic>{'ok': true};
      });
      await runtime.engine.actionHandler.execute(
        <String, dynamic>{
          'type': 'tool',
          'tool': 'ping',
          'params': <String, dynamic>{},
        },
        runtime.engine.renderer.createRootContext(null),
      );

      expect(called, 1,
          reason: 'a host registers before it initializes; dropping those '
              'registrations is how a tool call reaches nothing');
      await runtime.destroy();
    });
  });

  group('resource subscriptions', () {
    test('a subscription is registered and can be taken back', () async {
      final runtime = MCPUIRuntime();
      await runtime.initialize(page());

      runtime.registerResourceSubscription('client://inventory/a', 'rows');
      expect(runtime.getBindingForUri('client://inventory/a'), 'rows');

      runtime.unregisterResourceSubscription('client://inventory/a');
      expect(runtime.getBindingForUri('client://inventory/a'), isNull);

      await runtime.destroy();
    });
  });

  group('navigation handler', () {
    test('registering before initialize is refused by name', () async {
      final runtime = MCPUIRuntime();
      expect(
        () => runtime.registerNavigationHandler((a, r, p) => true),
        throwsStateError,
      );
    });

    test('a handler registered after initialize receives the route', () async {
      final runtime = MCPUIRuntime();
      final routes = <String>[];

      await runtime.initialize(page());
      runtime.registerNavigationHandler((action, route, params) {
        routes.add('$action:$route');
        return true;
      });
      await runtime.engine.actionHandler.execute(
        <String, dynamic>{
          'type': 'navigation',
          'action': 'push',
          'route': '/next',
        },
        runtime.engine.renderer.createRootContext(null),
      );

      expect(routes, <String>['push:/next']);
      await runtime.destroy();
    });
  });

  group('rendering', () {
    testWidgets('buildUI renders the definition', (tester) async {
      final runtime = MCPUIRuntime();
      await runtime.initialize(page());
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: runtime.buildUI())),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('hello'), findsOneWidget);
      expect(runtime.getUIDefinition(), isNotNull);
      await runtime.destroy();
    });
  });

  group('disposal', () {
    test('destroy is idempotent', () async {
      final runtime = MCPUIRuntime();
      await runtime.initialize(page());
      await runtime.destroy();
      await runtime.destroy();
      expect(runtime.isInitialized, isFalse);
    });

    test('handleError does not throw', () async {
      final runtime = MCPUIRuntime();
      runtime.handleError('a string error');
    });
  });
}
