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
///
/// The second group are LIST slots, reported from a published build after the
/// scalar ones were fixed: a list property bound to a path that holds a scalar
/// (a response still loading, an author mid-edit) threw out of
/// `resolve<List<dynamic>?>` and each widget covered its own area with a red
/// box while the rest of the page rendered.
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

  // List slots. `wrong` holds rows, and these read a scalar out of it — the
  // shape sbuilder measured on 0.7.4.
  'tabBar (bound tabs)': {
    'type': 'tabBar',
    'tabs': '{{scalar}}',
  },
  'bottomNavigation (bound items)': {
    'type': 'bottomNavigation',
    'items': '{{scalar}}',
  },
  'dataTable (bound columns)': {
    'type': 'dataTable',
    'columns': '{{scalar}}',
    'rows': '{{scalar}}',
  },
  'kanban (bound columns)': {
    'type': 'kanban',
    'columns': '{{scalar}}',
    'itemTemplate': {'type': 'text', 'content': 'x'},
  },
  'timeline (bound items)': {
    'type': 'timeline',
    'items': '{{scalar}}',
  },
  'tree (bound data)': {
    'type': 'tree',
    'data': '{{scalar}}',
  },
  // `resizable.handles` is `array<string>` — the fourth list slot, added after
  // sbuilder measured all six and corrected three to four.
  'resizable (bound handles)': {
    'type': 'resizable',
    'child': {'type': 'text', 'content': 'inside'},
    'handles': '{{scalar}}',
  },
  'combobox (bound options)': {
    'type': 'combobox',
    'options': '{{scalar}}',
  },
  // `pagination.currentPage` is declared literal-only, so a bound value is
  // refused by the SCHEMA before the runtime sees it — a different gate, and
  // the one sbuilder measured as "the two layers disagree". Not a tolerance
  // case; left out rather than asserted against the wrong layer.
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
              'initialState': {'wrong': _rows, 'scalar': 'not a list'},
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
