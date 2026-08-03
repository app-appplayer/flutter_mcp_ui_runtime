// A shell that switches pages keeps them, and says so.
//
// Measured before this existed, for every navigation shape the shell offers:
//
// ```
// → Order   TILL.onUnmount, TILL.onDestroy, ORDER.onInit, onMount, onReady
// → Till    ORDER.onUnmount, ORDER.onDestroy, TILL.onInit, onMount, onReady
// ```
//
// Every switch destroyed the outgoing page and built the incoming one from
// nothing: hooks re-ran, tools were called again, images were fetched and
// decoded again. Each branch of the shell had its own `FutureBuilder` keyed on
// the current route, so the element could not survive a switch.
//
// That is not what a Flutter app does with a tab bar, and it is not what
// §6.8.3 describes for a navigation that keeps its pages. What it cost is
// concrete: a page that loads its data in `onInit` — the shape §1.5.3 shows —
// re-fetches on every tap of the tab bar.

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
      'content': <String, dynamic>{'type': 'text', 'content': id},
    };

Future<(MCPUIRuntime, List<String>)> _open(
  WidgetTester tester,
  String navType,
) async {
  final fired = <String>[];
  final runtime = MCPUIRuntime();
  await runtime.initialize(
    <String, dynamic>{
      'type': 'application',
      'title': 'shell',
      'version': '1.0.0',
      'routes': <String, dynamic>{
        '/till': '/pages/till',
        '/order': '/pages/order',
      },
      'navigation': <String, dynamic>{
        'type': navType,
        'items': <Object>[
          <String, dynamic>{
            'label': 'Till',
            'route': '/till',
            'icon': 'home',
          },
          <String, dynamic>{
            'label': 'Order',
            'route': '/order',
            'icon': 'list',
          },
        ],
      },
    },
    pageLoader: (uri) async => _page(uri.contains('order') ? 'ORDER' : 'TILL'),
    onToolCall: (tool, params) async {
      fired.add(tool);
      return <String, dynamic>{};
    },
  );
  await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
  await tester.pumpAndSettle();
  return (runtime, fired);
}

void main() {
  for (final navType in <String>['bottomNavigation', 'rail', 'tabs']) {
    group(navType, () {
      testWidgets('only the opened page initializes', (tester) async {
        final (runtime, fired) = await _open(tester, navType);
        expect(fired, <String>['TILL.onInit', 'TILL.onMount', 'TILL.onReady']);
        expect(fired.where((f) => f.startsWith('ORDER.')), isEmpty,
            reason: 'a page nobody has opened must not run its onInit — that '
                'is what makes keeping pages alive cheap');
        await runtime.dispose();
      });

      testWidgets('leaving a page pauses it instead of destroying it',
          (tester) async {
        final (runtime, fired) = await _open(tester, navType);
        fired.clear();

        await tester.tap(find.text('Order').last);
        await tester.pumpAndSettle();

        expect(fired, contains('TILL.onPause'));
        expect(fired, isNot(contains('TILL.onUnmount')));
        expect(fired, isNot(contains('TILL.onDestroy')));
        expect(
          fired.where((f) => f.startsWith('ORDER.')),
          <String>['ORDER.onInit', 'ORDER.onMount', 'ORDER.onReady'],
        );
        await runtime.dispose();
      });

      testWidgets('returning resumes the same instance', (tester) async {
        final (runtime, fired) = await _open(tester, navType);
        await tester.tap(find.text('Order').last);
        await tester.pumpAndSettle();
        fired.clear();

        await tester.tap(find.text('Till').last);
        await tester.pumpAndSettle();

        expect(fired, contains('TILL.onResume'));
        expect(fired, contains('ORDER.onPause'));
        expect(fired, isNot(contains('TILL.onInit')),
            reason: 'this is the same instance — the whole point');
        await runtime.dispose();
      });

      testWidgets('switching repeatedly never re-initializes', (tester) async {
        final (runtime, fired) = await _open(tester, navType);
        fired.clear();

        for (var i = 0; i < 3; i++) {
          await tester.tap(find.text('Order').last);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Till').last);
          await tester.pumpAndSettle();
        }

        expect(fired.where((f) => f.endsWith('.onInit')),
            <String>['ORDER.onInit'],
            reason: 'ORDER initializes on its first visit and never again');
        expect(fired.where((f) => f.endsWith('.onDestroy')), isEmpty);
        // Every pause is answered by a resume: §1.5.2 draws them as a pair,
        // and a resume with no pause before it reports something that did not
        // happen.
        expect(
          fired.where((f) => f.startsWith('TILL.')).toList(),
          <String>[
            'TILL.onPause',
            'TILL.onResume',
            'TILL.onPause',
            'TILL.onResume',
            'TILL.onPause',
            'TILL.onResume',
          ],
        );
        await runtime.dispose();
      });
    });
  }
}
