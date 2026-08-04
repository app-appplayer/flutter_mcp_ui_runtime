// A tool call is not one thing — it is a loading flag, the call itself, and
// then a success or error branch. Those surrounding parts were the uncovered
// ones, and each is what a page shows while it waits or when it fails: a
// spinner that never clears, an error the document is never told about.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  late MCPUIRuntime runtime;

  Future<void> boot(WidgetTester tester) async {
    runtime = MCPUIRuntime();
    await runtime.initialize(<String, dynamic>{
      'type': 'page',
      'state': <String, dynamic>{
        'initial': <String, dynamic>{'busy': false, 'result': '', 'err': ''},
      },
      'content': <String, dynamic>{'type': 'text', 'content': 'page'},
    });
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: runtime.buildUI())),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<ActionResult> run(Map<String, dynamic> action) =>
      runtime.engine.actionHandler.execute(
        action,
        runtime.engine.renderer.createRootContext(null),
      );

  tearDown(() async => runtime.destroy());

  testWidgets('a loading binding is raised and cleared around the call',
      (tester) async {
    await boot(tester);
    final seen = <bool>[];
    runtime.stateManager.addListener(() {
      final v = runtime.stateManager.get<bool>('busy');
      if (v != null) seen.add(v);
    });

    // No artificial delay: in a widget test the fake clock does not advance
    // on an awaited `Future.delayed`, so the call would never return and the
    // hang would look like the product blocking.
    runtime.registerToolExecutor('slow', (params) async {
      return <String, dynamic>{'ok': true};
    });

    await run(<String, dynamic>{
      'type': 'tool',
      'tool': 'slow',
      'params': <String, dynamic>{},
      'loading': <String, dynamic>{'binding': 'busy'},
    });

    expect(seen, contains(true), reason: 'the spinner has to go up');
    expect(runtime.stateManager.get<bool>('busy'), isFalse,
        reason: 'a loading flag that is never cleared leaves a spinner on a '
            'page whose work has already finished');
  });

  testWidgets('the loading flag clears even when the tool fails',
      (tester) async {
    await boot(tester);
    runtime.registerToolExecutor('boom', (params) async {
      throw StateError('tool exploded');
    });

    final result = await run(<String, dynamic>{
      'type': 'tool',
      'tool': 'boom',
      'params': <String, dynamic>{},
      'loading': <String, dynamic>{'binding': 'busy'},
    });

    expect(result.success, isFalse);
    expect(runtime.stateManager.get<bool>('busy'), isFalse,
        reason: 'the failure path is exactly where a stuck spinner survives');
  });

  testWidgets('onError receives the failure', (tester) async {
    await boot(tester);
    runtime.registerToolExecutor('boom', (params) async {
      throw StateError('tool exploded');
    });

    await run(<String, dynamic>{
      'type': 'tool',
      'tool': 'boom',
      'params': <String, dynamic>{},
      'onError': <String, dynamic>{
        'type': 'state',
        'action': 'set',
        'binding': 'err',
        'value': 'failed',
      },
    });

    expect(runtime.stateManager.get<String>('err'), 'failed');
  });

  testWidgets('onSuccess runs after the call returns', (tester) async {
    await boot(tester);
    runtime.registerToolExecutor('fetch', (params) async {
      return <String, dynamic>{'value': 'fresh'};
    });

    await run(<String, dynamic>{
      'type': 'tool',
      'tool': 'fetch',
      'params': <String, dynamic>{},
      'onSuccess': <String, dynamic>{
        'type': 'state',
        'action': 'set',
        'binding': 'result',
        'value': 'done',
      },
    });

    expect(runtime.stateManager.get<String>('result'), 'done');
  });

  testWidgets('an unregistered tool is reported by name', (tester) async {
    await boot(tester);

    final result = await run(<String, dynamic>{
      'type': 'tool',
      'tool': 'nowhere',
      'params': <String, dynamic>{},
    });

    expect(result.success, isFalse);
    expect(result.error, contains('nowhere'),
        reason: 'naming the tool is the difference between a fixable message '
            'and "something went wrong"');
  });

  testWidgets('a tool action with no tool name is refused', (tester) async {
    await boot(tester);
    final result = await run(<String, dynamic>{'type': 'tool'});
    expect(result.success, isFalse);
  });
}
