// A shrink-wrapped list or grid inside a scrollView must not take the
// vertical drag from it.
//
// §2.15 tells authors to set `shrinkWrap` on a list or grid that sits in an
// unbounded parent. Without author `physics`, Flutter treats a vertical
// list/grid with no controller as the primary scroll view and forces
// always-scrollable physics on it, so a list already at its full height
// still claimed every vertical drag and the page around it could not be
// scrolled. A shrink-wrapped view capped below its content must still
// scroll itself.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

Future<void> _open(WidgetTester tester, Map<String, dynamic> content) async {
  final runtime = MCPUIRuntime();
  addTearDown(runtime.dispose);
  await runtime.initialize(<String, dynamic>{
    'type': 'page',
    'content': content,
  }, validateSchema: false);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: KeyedSubtree(key: UniqueKey(), child: runtime.buildUI()),
    ),
  ));
  await tester.pumpAndSettle();
}

List<String> _items(String prefix, int n) =>
    [for (var i = 0; i < n; i++) '$prefix $i'];

Map<String, dynamic> _shrinkList(String prefix, int n,
        {String type = 'list', String? physics}) =>
    <String, dynamic>{
      'type': type,
      'shrinkWrap': true,
      if (physics != null) 'physics': physics,
      if (type == 'grid') 'columns': 2,
      'items': _items(prefix, n),
      'itemTemplate': {'type': 'text', 'text': '{{item}}'},
    };

/// A page taller than the screen: shrink-wrapped [view], then an end marker.
Map<String, dynamic> _page(Map<String, dynamic> view) => <String, dynamic>{
      'type': 'scrollView',
      'child': {
        'type': 'linear',
        'direction': 'vertical',
        'children': [
          view,
          {'type': 'sizedBox', 'height': 900},
          {'type': 'text', 'text': 'END'},
        ],
      },
    };

void main() {
  for (final type in ['list', 'grid']) {
    testWidgets('a $type at full height lets the page scroll', (tester) async {
      await _open(tester, _page(_shrinkList('row', 6, type: type)));
      final before = tester.getTopLeft(find.text('END')).dy;

      await tester.drag(find.text('row 1'), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(find.text('END')).dy, lessThan(before - 100));
    });

    testWidgets('a $type capped below its content still scrolls itself',
        (tester) async {
      await _open(tester, <String, dynamic>{
        'type': 'sizedBox',
        'height': 120,
        'child': _shrinkList('row', 40, type: type),
      });
      final position =
          Scrollable.of(tester.element(find.text('row 0'))).position;
      expect(position.pixels, 0);

      final view = find.byWidgetPredicate((w) => w is ScrollView);
      await tester.dragFrom(tester.getCenter(view), const Offset(0, -80));
      await tester.pumpAndSettle();

      expect(position.pixels, greaterThan(0));
    });
  }

  testWidgets('primary is set only for shrinkWrap without author physics',
      (tester) async {
    Future<bool?> primaryOf(Map<String, dynamic> view) async {
      await _open(tester, view);
      return tester
          .widget<ScrollView>(find.byWidgetPredicate((w) => w is ScrollView))
          .primary;
    }

    expect(await primaryOf(_page(_shrinkList('a', 3))), isFalse);
    expect(await primaryOf(_page(_shrinkList('b', 3, physics: 'clamping'))),
        isNull);
    expect(
        await primaryOf(<String, dynamic>{
          'type': 'sizedBox',
          'height': 200,
          'child': {
            'type': 'list',
            'items': _items('c', 3),
            'itemTemplate': {'type': 'text', 'text': '{{item}}'},
          },
        }),
        isNull);
  });
}
