// A page that survives a navigation is told so.
//
// Measured before this existed:
//
// ```
// push     A stays mounted · no hook fires at all
// pop      A still mounted · no hook fires at all
// replace  A destroyed     · onUnmount → onDestroy
// ```
//
// So `onPause` / `onResume` had never fired for a routed page — the one
// navigation that keeps an instance alive reported nothing, in either
// direction. §1.5.1 defines those hooks for exactly this case.
//
// A pushed-over page is not disposed: its element stays in the tree, so
// `dispose` never runs and nothing else in the framework reports the change.
// `RouteAware`'s `didPushNext` / `didPopNext` is the framework's own answer to
// that question, which is why the hooks ride on it rather than on a second
// mechanism invented here.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

Map<String, dynamic> _page(String id) => <String, dynamic>{
      'type': 'page',
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
      'content': <String, dynamic>{
        'type': 'linear',
        'children': <Object>[
          <String, dynamic>{'type': 'text', 'content': id},
          <String, dynamic>{
            'type': 'button',
            'label': 'push',
            'onTap': <String, dynamic>{
              'type': 'navigation',
              'action': 'push',
              'route': '/b',
            },
          },
          <String, dynamic>{
            'type': 'button',
            'label': 'back',
            'onTap': <String, dynamic>{
              'type': 'navigation',
              'action': 'pop',
            },
          },
          <String, dynamic>{
            'type': 'button',
            'label': 'replace',
            'onTap': <String, dynamic>{
              'type': 'navigation',
              'action': 'replace',
              'route': '/b',
            },
          },
        ],
      },
    };

Future<(MCPUIRuntime, List<String>)> _open(WidgetTester tester) async {
  final fired = <String>[];
  final runtime = MCPUIRuntime();
  await runtime.initialize(
    <String, dynamic>{
      'type': 'application',
      'title': 'nav',
      'version': '1.0.0',
      'routes': <String, dynamic>{'/': '/pages/a', '/b': '/pages/b'},
    },
    pageLoader: (uri) async => _page(uri.contains('b') ? 'B' : 'A'),
    onToolCall: (tool, params) async {
      fired.add(tool);
      return <String, dynamic>{};
    },
  );
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: runtime.buildUI())),
  );
  await tester.pumpAndSettle();
  return (runtime, fired);
}

void main() {
  testWidgets('a page pushed over pauses, and resumes on the way back',
      (tester) async {
    final (runtime, fired) = await _open(tester);
    expect(fired, <String>['A.onInit', 'A.onMount', 'A.onReady']);
    fired.clear();

    await tester.tap(find.text('push').first);
    await tester.pumpAndSettle();
    expect(fired, contains('A.onPause'),
        reason: 'A is still mounted and has lost focus — §1.5.1');
    expect(fired, containsAllInOrder(<String>['B.onInit', 'B.onMount']));
    expect(fired, isNot(contains('A.onUnmount')),
        reason: 'A was not destroyed, so it must not be torn down');
    fired.clear();

    await tester.tap(find.text('back').last);
    await tester.pumpAndSettle();
    expect(fired, contains('A.onResume'));
    expect(fired, containsAllInOrder(<String>['B.onUnmount', 'B.onDestroy']));
    expect(fired, isNot(contains('A.onInit')),
        reason: 'this is the same instance — a resume, not a new page');

    await runtime.dispose();
  });

  testWidgets('a replaced page is destroyed and does not pause',
      (tester) async {
    final (runtime, fired) = await _open(tester);
    fired.clear();

    await tester.tap(find.text('replace').first);
    await tester.pumpAndSettle();

    expect(fired, containsAllInOrder(<String>['A.onUnmount', 'A.onDestroy']));
    expect(fired, isNot(contains('A.onPause')),
        reason: '§6.8.3: a destroyed instance must not fire onPause');
    expect(fired, containsAllInOrder(<String>['B.onInit', 'B.onReady']));

    await runtime.dispose();
  });

  testWidgets('pause and resume can cycle', (tester) async {
    final (runtime, fired) = await _open(tester);
    fired.clear();

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('push').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('back').last);
      await tester.pumpAndSettle();
    }

    final aHooks = fired.where((f) => f.startsWith('A.')).toList();
    expect(
      aHooks,
      <String>['A.onPause', 'A.onResume', 'A.onPause', 'A.onResume'],
      reason: '§1.5.2 draws these as a pair that may cycle any number of times',
    );

    await runtime.dispose();
  });
}
