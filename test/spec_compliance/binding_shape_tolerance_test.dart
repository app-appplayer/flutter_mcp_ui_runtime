// A binding whose state holds the wrong shape must not take the screen down.
//
// These six read a bound value with a hard cast (`resolve<bool>`,
// `resolve<num?>`, `as String?`). When the path resolved to something else —
// a list where a number was expected, a map where a string was — the cast
// threw during build and the renderer painted a red `Error rendering …` box
// over the whole widget. A mistyped or momentarily-wrong binding is an
// authoring mistake; it is not a reason to blank the page, and on an
// authoring host (a studio mid-edit) or a server-fed document (a response
// still loading) that state is normal rather than exceptional.
//
// Found by the render matrix once it started requiring pixels: the harness
// seeded generic state, six widgets exploded, and the explosion was the
// finding rather than the harness's fault.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shape that used to throw: rows where a scalar was expected.
const _rows = [
  {'id': 'r0', 'label': 'Row 0'},
  {'id': 'r1', 'label': 'Row 1'},
];

/// Each case is the smallest document that reproduced the red box, with the
/// state that made it happen. These are the fragments consumers asked for.
final cases = <String, Map<String, dynamic>>{
  'bottomNavigation': {
    'type': 'bottomNavigation',
    'items': [
      {'label': 'Home', 'icon': 'home'},
      {'label': 'Settings', 'icon': 'settings'},
    ],
    'currentIndex': '{{wrong}}',
  },
  'tabBar': {
    'type': 'tabBar',
    'tabs': [
      {'label': 'One'},
      {'label': 'Two'},
    ],
    'selectedIndex': '{{wrong}}',
  },
  'dataTable': {
    'type': 'dataTable',
    'columns': [
      {'key': 'name', 'label': 'Name'},
    ],
    'rows': [
      {'name': 'A'},
    ],
    'filterable': '{{wrong}}',
  },
  'kenBurnsImage': {
    'type': 'kenBurnsImage',
    'src': '{{wrong}}',
  },
  'resizable': {
    'type': 'resizable',
    'child': {'type': 'text', 'content': 'inside'},
    'minWidth': '{{wrong}}',
  },
  'visibility': {
    'type': 'visibility',
    'visible': '{{wrong}}',
    'child': {'type': 'text', 'content': 'inside'},
  },
};

void main() {
  final live = <MCPUIRuntime>[];
  tearDown(() {
    for (final runtime in live) {
      runtime.destroy();
    }
    live.clear();
  });

  cases.forEach((type, document) {
    testWidgets('$type survives a binding of the wrong shape', (tester) async {
      final runtime = MCPUIRuntime();
      live.add(runtime);
      await runtime.initialize({
        'type': 'page',
        'content': document,
        'runtime': {
          'services': {
            'state': {
              'initialState': {'wrong': _rows},
            },
          },
        },
      });

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: runtime.buildUI())),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // The renderer reports a failed widget by DRAWING a red box, not by
      // throwing, so the frame is where the failure shows.
      expect(find.textContaining('Error rendering'), findsNothing,
          reason: '$type painted an error box over the page because a bound '
              'value held the wrong shape');
      expect(tester.takeException(), isNull);
    });
  });
}
