// A definition-level `onInit` that calls a tool reaches the host.
//
// §1.5.3 shows exactly that document — `"onInit": {"type": "tool", ...}` as a
// sibling of `type` — and §1.5.2 fires `onInit` before the first render. The
// tool executor was registered from `buildUI`'s widget `initState`, so an
// application-level `onInit` ran with an empty executor map: the call reached
// nothing, and the only trace was a log line reading "Tool executor not
// found", which sends the reader looking for a host that forgot to register.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

Map<String, dynamic> _application(Map<String, dynamic> hooks) => {
      'type': 'application',
      'title': 'lifecycle probe',
      'version': '1.0.0',
      'routes': <String, dynamic>{'/': '/pages/home'},
      ...hooks,
    };

Future<Map<String, dynamic>> _page(String uri) async => <String, dynamic>{
      'type': 'page',
      'content': <String, dynamic>{'type': 'text', 'content': 'home'},
    };

void main() {
  testWidgets('application onInit tool call reaches an executor passed to '
      'initialize', (tester) async {
    final called = <String>[];
    final runtime = MCPUIRuntime();

    await runtime.initialize(
      _application({
        'onInit': <String, dynamic>{'type': 'tool', 'tool': 'menu.list'},
      }),
      pageLoader: _page,
      onToolCall: (tool, params) async {
        called.add(tool);
        return <String, dynamic>{'ok': true};
      },
    );

    // The hook runs during initialize, so the call has already happened.
    expect(called, <String>['menu.list']);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: runtime.buildUI())),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(called, <String>['menu.list'], reason: 'the hook fires once');

    await runtime.dispose();
  });

  testWidgets('the grouped `lifecycle` placement behaves the same',
      (tester) async {
    final called = <String>[];
    final runtime = MCPUIRuntime();

    await runtime.initialize(
      _application({
        'lifecycle': <String, dynamic>{
          'onInit': <String, dynamic>{'type': 'tool', 'tool': 'menu.list'},
        },
      }),
      pageLoader: _page,
      onToolCall: (tool, params) async {
        called.add(tool);
        return <String, dynamic>{'ok': true};
      },
    );

    expect(called, <String>['menu.list']);
    await runtime.dispose();
  });

  testWidgets('a host that registers only at buildUI is told why the call '
      'could not land', (tester) async {
    final records = <MCPLogRecord>[];
    MCPLogger.onRecord = records.add;
    addTearDown(() => MCPLogger.onRecord = null);

    final called = <String>[];
    final runtime = MCPUIRuntime();
    await runtime.initialize(
      _application({
        'onInit': <String, dynamic>{'type': 'tool', 'tool': 'menu.list'},
      }),
      pageLoader: _page,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: runtime.buildUI(
            onToolCall: (tool, params) async {
              called.add(tool);
              return <String, dynamic>{'ok': true};
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    // Still unreachable — that is the ordering, not a regression. What must
    // not happen is the reader being pointed at the wrong cause.
    expect(called, isEmpty);
    final complaint = records
        .where((r) => r.message.contains('menu.list'))
        .map((r) => r.message)
        .join('\n');
    expect(complaint, contains('no executor is registered at all'));
    expect(complaint, contains('pass `onToolCall` to `initialize`'));

    await runtime.dispose();
  });

  testWidgets('a genuinely unknown tool still reports as unknown',
      (tester) async {
    final records = <MCPLogRecord>[];
    MCPLogger.onRecord = records.add;
    addTearDown(() => MCPLogger.onRecord = null);

    final runtime = MCPUIRuntime();
    await runtime.initialize(<String, dynamic>{
      'type': 'page',
      'content': <String, dynamic>{
        'type': 'button',
        'label': 'go',
        'onTap': <String, dynamic>{'type': 'tool', 'tool': 'menu.list'},
      },
    });
    // A named executor exists, so the map is not empty — a miss here really
    // is a miss, and must not be reported as the ordering problem.
    runtime.registerToolExecutor(
      'something.else',
      (tool, params) async => <String, dynamic>{},
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: runtime.buildUI())),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('go'));
    await tester.pump(const Duration(milliseconds: 50));

    final complaint = records
        .where((r) => r.message.contains('menu.list'))
        .map((r) => r.message)
        .join('\n');
    expect(complaint, contains('Tool executor not found'));
    // The ordering advice must not be attached to a call that simply named a
    // tool nobody registered — that would send this reader to the wrong fix.
    expect(complaint, isNot(contains('no executor is registered at all')));

    await runtime.dispose();
  });
}
