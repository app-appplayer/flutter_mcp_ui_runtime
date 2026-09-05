// A host that registers a read handler gets the document's `resource read`
// through it — and only through it.
//
// `buildUI` / `buildDashboard` accepted subscribe and unsubscribe handlers
// and nothing for read, and the widget layer re-set every handler slot from
// its own fields, so a read handler set on the engine directly was wiped to
// null on build. Every host's `read` therefore fell to the legacy fallback:
// it borrowed the subscribe handler, which on AppPlayer added a wire
// subscription per read and never wrote the binding.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  /// An application whose home page reads a resource on init. The page
  /// mounts after `buildUI` has installed the host's handlers — the shape
  /// AppPlayer runs, and the one where a read handler can be reached at all.
  Future<MCPUIRuntime> pumpWithHandlers(
    WidgetTester tester, {
    required Function(String, String)? onRead,
    required Function(String, String)? onSubscribe,
  }) async {
    final runtime = MCPUIRuntime();
    await runtime.initialize(
      {
        'type': 'application',
        'title': 'door',
        'version': '1.0.0',
        'routes': {'/': '/pages/door'},
      },
      pageLoader: (uri) async => {
        'type': 'page',
        'onInit': {
          'type': 'resource',
          'action': 'read',
          'uri': 'line://state',
          'binding': 'live',
        },
        'content': {'type': 'text', 'content': 'door'},
      },
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: runtime.buildUI(
          onResourceRead: onRead,
          onResourceSubscribe: onSubscribe,
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    return runtime;
  }

  testWidgets('a registered read handler receives the read, not subscribe',
      (tester) async {
    final reads = <String>[];
    final subscribes = <String>[];
    final runtime = await pumpWithHandlers(
      tester,
      onRead: (uri, binding) async => reads.add('$uri->$binding'),
      onSubscribe: (uri, binding) async => subscribes.add('$uri->$binding'),
    );
    expect(reads, ['line://state->live']);
    expect(subscribes, isEmpty, reason: 'a read must not add a subscription');
    runtime.destroy();
  });

  testWidgets(
      'without a read handler the legacy fallback still borrows subscribe',
      (tester) async {
    final subscribes = <String>[];
    final runtime = await pumpWithHandlers(
      tester,
      onRead: null,
      onSubscribe: (uri, binding) async => subscribes.add('$uri->$binding'),
    );
    expect(subscribes, ['line://state->live']);
    runtime.destroy();
  });
}
