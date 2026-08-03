// What is inside a paused page is paused too.
//
// A page that is left rather than destroyed stays mounted, and so does
// everything in it. Measured before this existed: the page fired `onPause`
// and an instance-level `lifecycle` block (§6.8.2) inside it heard nothing —
// it got `onInit` → `onMount` → `onReady` when the page opened and then
// silence forever.
//
// ```
// open      A.onInit, A.W.onInit, A.onMount, A.W.onMount, A.onReady, A.W.onReady
// leave A   A.onPause                      ← A.W hears nothing
// return    A.onResume                     ← A.W hears nothing
// ```
//
// A widget that started a timer or a subscription in `onMount` therefore kept
// running behind an unselected tab, and never received the `onResume` its own
// document declares. Keeping pages alive is what made this visible: while
// every switch destroyed the page, `onUnmount` covered it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

Map<String, dynamic> _hooks(String id) => <String, dynamic>{
      for (final hook in <String>[
        'onInit',
        'onMount',
        'onReady',
        'onPause',
        'onResume',
        'onUnmount',
        'onDestroy',
      ])
        hook: <String, dynamic>{'type': 'tool', 'tool': '$id.$hook'},
    };

Map<String, dynamic> _page(String id) => <String, dynamic>{
      'type': 'page',
      ..._hooks(id),
      'content': <String, dynamic>{
        'type': 'linear',
        'children': <Object>[
          <String, dynamic>{'type': 'text', 'content': id},
          <String, dynamic>{
            'type': 'box',
            'lifecycle': _hooks('$id.W'),
            'child': <String, dynamic>{'type': 'text', 'content': 'w'},
          },
        ],
      },
    };

void main() {
  testWidgets('an instance-level lifecycle follows the page it is in',
      (tester) async {
    final fired = <String>[];
    final runtime = MCPUIRuntime();
    await runtime.initialize(
      <String, dynamic>{
        'type': 'application',
        'title': 'nested',
        'version': '1.0.0',
        'routes': <String, dynamic>{'/a': '/pages/a', '/b': '/pages/b'},
        'navigation': <String, dynamic>{
          'type': 'bottomNavigation',
          'items': <Object>[
            <String, dynamic>{'label': 'A', 'route': '/a', 'icon': 'home'},
            <String, dynamic>{'label': 'B', 'route': '/b', 'icon': 'list'},
          ],
        },
      },
      pageLoader: (uri) async => _page(uri.contains('b') ? 'B' : 'A'),
      onToolCall: (tool, params) async {
        fired.add(tool);
        return <String, dynamic>{};
      },
    );
    await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
    await tester.pumpAndSettle();
    expect(fired.where((f) => f.startsWith('A.W.')),
        <String>['A.W.onInit', 'A.W.onMount', 'A.W.onReady']);
    fired.clear();

    await tester.tap(find.text('B').last);
    await tester.pumpAndSettle();
    expect(fired, contains('A.W.onPause'),
        reason: 'the widget is still mounted behind an unselected tab');
    expect(fired, isNot(contains('A.W.onUnmount')));
    fired.clear();

    await tester.tap(find.text('A').last);
    await tester.pumpAndSettle();
    expect(fired, contains('A.W.onResume'));
    expect(fired, isNot(contains('A.W.onInit')),
        reason: 'the same widget instance — it was never rebuilt');

    await runtime.dispose();
  });
}
