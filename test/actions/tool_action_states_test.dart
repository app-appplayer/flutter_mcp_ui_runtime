// A tool call is not one thing — it is a loading flag, the call itself, and
// then a success or error branch. Those surrounding parts were the uncovered
// ones, and each is what a page shows while it waits or when it fails: a
// spinner that never clears, an error the document is never told about.

import 'dart:async';

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

  testWidgets('a loading map clears its text and indicator too',
      (tester) async {
    await boot(tester);
    runtime.registerToolExecutor('slow', (params) async =>
        <String, dynamic>{'ok': true});

    await run(<String, dynamic>{
      'type': 'tool',
      'tool': 'slow',
      'params': <String, dynamic>{},
      'loading': <String, dynamic>{
        'binding': 'busy',
        'text': 'Working…',
        'indicator': 'spinner',
      },
    });

    expect(runtime.stateManager.get<bool>('busy'), isFalse,
        reason: 'a flag that stays raised leaves the page behind a spinner');
    // §4.20 defines the map form; whether its `text` / `indicator` can land
    // at all is recorded as a spec question — what is pinned here is that the
    // call completes and the flag clears either way.
  });

  testWidgets('a failing tool clears the loading map as well', (tester) async {
    await boot(tester);
    runtime.registerToolExecutor('broken', (params) async {
      throw StateError('the tool broke');
    });

    final result = await run(<String, dynamic>{
      'type': 'tool',
      'tool': 'broken',
      'params': <String, dynamic>{},
      'loading': <String, dynamic>{
        'binding': 'busy',
        'text': 'Working…',
        'indicator': 'spinner',
      },
    });

    expect(result.success, isFalse);
    expect(runtime.stateManager.get<bool>('busy'), isFalse,
        reason: 'the failure path has to clear what the success path raised, '
            'or a failed call leaves the page spinning forever');
  });

  testWidgets('a wire-shape error clears the loading map and reports the '
      'message', (tester) async {
    await boot(tester);
    runtime.registerToolExecutor('reports', (params) async =>
        <String, dynamic>{
          'isError': true,
          'content': <dynamic>[
            <String, dynamic>{
              'type': 'text',
              'text': '{"message": "not allowed"}',
            },
          ],
        });

    final result = await run(<String, dynamic>{
      'type': 'tool',
      'tool': 'reports',
      'params': <String, dynamic>{},
      'loading': <String, dynamic>{
        'binding': 'busy',
        'text': 'Working…',
        'indicator': 'spinner',
      },
    });

    expect(result.success, isFalse);
    expect(result.error, contains('not allowed'),
        reason: 'the server said why; replacing it with a generic failure '
            'throws away the only thing the user could act on');
    expect(runtime.stateManager.get<bool>('busy'), isFalse);
  });

  testWidgets('bindResult puts the whole response where the document asked',
      (tester) async {
    await boot(tester);
    runtime.registerToolExecutor('rows', (params) async =>
        <String, dynamic>{'rows': <dynamic>[1, 2, 3]});

    await run(<String, dynamic>{
      'type': 'tool',
      'tool': 'rows',
      'params': <String, dynamic>{},
      'bindResult': 'payload',
      'loading': <String, dynamic>{'binding': 'busy', 'text': 'Working…'},
    });

    expect(runtime.stateManager.get('payload'), <String, dynamic>{
      'rows': <dynamic>[1, 2, 3],
    }, reason: 'an explicit destination replaces the §3.10 auto-merge; '
        'merging as well would scatter the response across page state');
    expect(runtime.stateManager.get<bool>('busy'), isFalse);
  });
  testWidgets('the legacy envelope shape clears the loading map too',
      (tester) async {
    await boot(tester);
    // `{success, result, message}` — the shape bundles in the field still
    // return. It takes its own branch through the executor, and that branch
    // has to raise and clear the spinner exactly like the canonical one.
    runtime.registerToolExecutor('legacy', (params) async => <String, dynamic>{
          'success': true,
          'result': <String, dynamic>{'rows': 3},
        });

    final result = await run(<String, dynamic>{
      'type': 'tool',
      'tool': 'legacy',
      'params': <String, dynamic>{},
      'bindResult': 'result',
      'loading': <String, dynamic>{
        'binding': 'busy',
        'text': 'Working…',
        'indicator': 'spinner',
      },
    });

    expect(result.success, isTrue);
    expect(runtime.stateManager.get('result'), <String, dynamic>{'rows': 3},
        reason: '`bindResult` names where the body lands; the envelope form '
            'has to unwrap to the same place as the canonical one');
    expect(runtime.stateManager.get<bool>('busy'), isFalse,
        reason: 'a spinner left up by the legacy branch is the same stuck '
            'page as one left up by the canonical branch');
  });

  testWidgets('a legacy envelope that failed reports its message',
      (tester) async {
    await boot(tester);
    runtime.registerToolExecutor('legacy', (params) async => <String, dynamic>{
          'success': false,
          'message': 'the queue is full',
        });

    final result = await run(<String, dynamic>{
      'type': 'tool',
      'tool': 'legacy',
      'params': <String, dynamic>{},
      'loading': <String, dynamic>{'binding': 'busy', 'text': 'Working…'},
    });

    expect(result.success, isFalse);
    expect(result.error, 'the queue is full',
        reason: 'the server said why; a generic failure throws away the one '
            'thing the user could act on');
    expect(runtime.stateManager.get<bool>('busy'), isFalse);
  });

  testWidgets('an envelope success does not merge over page state when '
      '`bindResult` is given', (tester) async {
    await boot(tester);
    runtime.stateManager.set('rows', 'untouched');
    runtime.registerToolExecutor('legacy', (params) async => <String, dynamic>{
          'success': true,
          'result': <String, dynamic>{'rows': 3},
        });

    await run(<String, dynamic>{
      'type': 'tool',
      'tool': 'legacy',
      'params': <String, dynamic>{},
      'bindResult': 'result',
    });

    expect(runtime.stateManager.get('rows'), 'untouched',
        reason: 'naming a destination is the document saying "put it there, '
            'not everywhere"');
  });

  testWidgets('a tool that never returns is given up on, and the spinner '
      'comes down', (tester) async {
    await boot(tester);
    // A completer rather than a long delay: a pending timer outlives the
    // test and the framework reports that instead of the behaviour.
    final never = Completer<Map<String, dynamic>>();
    addTearDown(() => never.complete(<String, dynamic>{'ok': true}));
    runtime.registerToolExecutor('hangs', (params) => never.future);

    final pending = run(<String, dynamic>{
      'type': 'tool',
      'tool': 'hangs',
      'params': <String, dynamic>{},
      'timeout': 50,
      'loading': <String, dynamic>{
        'binding': 'busy',
        'text': 'Working…',
        'indicator': 'spinner',
      },
    });

    expect(runtime.stateManager.get<bool>('busy'), isTrue);

    await tester.pump(const Duration(milliseconds: 100));
    final result = await pending;

    expect(result.success, isFalse,
        reason: 'a call that never comes back has to end somewhere; waiting '
            'forever leaves the page behind a spinner with no way out');
    expect(runtime.stateManager.get<bool>('busy'), isFalse);
  });
}
