// `onSuccess` / `onError` take one action or a list of them.
//
// Every other action slot in a document already does — lifecycle hooks,
// watchers, widget slots all read through `readActions`. The callbacks cast
// straight to `Map<String, dynamic>?`, so a list ran nothing and reported
// nothing: the tool succeeded and the state it was supposed to write stayed at
// its initial value.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

Future<MCPUIRuntime> _pump(
  WidgetTester tester,
  Map<String, dynamic> onTap, {
  required Future<dynamic> Function(Map<String, dynamic>) tool,
}) async {
  final runtime = MCPUIRuntime();
  addTearDown(runtime.dispose);
  await runtime.initialize(<String, dynamic>{
    'type': 'page',
    'content': <String, dynamic>{
      'type': 'button',
      'label': 'go',
      'onTap': onTap,
    },
    'runtime': <String, dynamic>{
      'services': <String, dynamic>{
        'state': <String, dynamic>{
          'initialState': <String, dynamic>{'a': '-', 'b': '-'},
        },
      },
    },
  }, validateSchema: false);
  runtime.registerToolExecutor('probe.run', tool);
  await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: runtime.buildUI())));
  await tester.pump();
  await tester.tap(find.text('go'));
  await tester.pump(const Duration(milliseconds: 300));
  return runtime;
}

void main() {
  testWidgets('a list of onSuccess actions all run, in order', (tester) async {
    final runtime = await _pump(
      tester,
      <String, dynamic>{
        'type': 'tool',
        'tool': 'probe.run',
        'params': <String, dynamic>{},
        'onSuccess': <dynamic>[
          {'type': 'state', 'action': 'set', 'binding': 'a', 'value': 'A'},
          {'type': 'state', 'action': 'set', 'binding': 'b', 'value': 'B'},
        ],
      },
      tool: (_) async => <String, dynamic>{'ok': true},
    );

    expect(runtime.engine.stateManager.get('a'), 'A');
    expect(runtime.engine.stateManager.get('b'), 'B',
        reason: 'the second entry must not be dropped');
  });

  testWidgets('a list of onError actions all run', (tester) async {
    final runtime = await _pump(
      tester,
      <String, dynamic>{
        'type': 'tool',
        'tool': 'probe.run',
        'params': <String, dynamic>{},
        'onError': <dynamic>[
          {'type': 'state', 'action': 'set', 'binding': 'a', 'value': 'E1'},
          {'type': 'state', 'action': 'set', 'binding': 'b', 'value': 'E2'},
        ],
      },
      tool: (_) async => throw StateError('nope'),
    );

    expect(runtime.engine.stateManager.get('a'), 'E1');
    expect(runtime.engine.stateManager.get('b'), 'E2');
  });

  testWidgets('a single-object callback still runs', (tester) async {
    final runtime = await _pump(
      tester,
      <String, dynamic>{
        'type': 'tool',
        'tool': 'probe.run',
        'params': <String, dynamic>{},
        'onSuccess': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'a',
          'value': 'ONE',
        },
      },
      tool: (_) async => <String, dynamic>{'ok': true},
    );

    expect(runtime.engine.stateManager.get('a'), 'ONE');
  });
}
