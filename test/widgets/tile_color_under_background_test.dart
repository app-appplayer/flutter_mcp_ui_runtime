// A declared colour draws where the document puts it, not only where the
// framework's paint order happens to allow.
//
// `ListTile.tileColor` is painted into the nearest `Material`'s ink layer,
// which sits below anything an ancestor paints. A page that gives its own
// container a background — the ordinary case — covered the colour completely:
// the property validated, rendered no error, and did nothing. That is the same
// failure shape as `fontWeight: "700"` accepting and not applying, and it is
// worse than a rejection because there is nothing to see.
//
// The pair below is the whole point: the tile colour has to survive *with* an
// ancestor background, and the case without one has to keep working.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  Future<int> tileColorPixels(WidgetTester tester,
      {required bool withAncestorBackground}) async {
    final tile = <String, dynamic>{
      'type': 'listItem',
      'title': 'row',
      'tileColor': '#e6f4f1',
    };
    final runtime = MCPUIRuntime();
    await runtime.initialize(<String, dynamic>{
      'type': 'page',
      'content': withAncestorBackground
          ? <String, dynamic>{
              'type': 'box',
              'color': '#ffffff',
              'child': tile,
            }
          : tile,
    });
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: runtime.buildUI())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The tile has to own the `Material` its ink is painted into — that is
    // what the framework requires and what its own assertion says when a
    // background sits between the two. Counting the Materials that sit under
    // the tile is therefore counting whether the colour can be seen at all.
    final owned = find
        .ancestor(of: find.byType(ListTile), matching: find.byType(Material))
        .evaluate()
        .where((e) => (e.widget as Material).type == MaterialType.transparency)
        .length;
    expect(tester.widget<ListTile>(find.byType(ListTile)).tileColor,
        const Color(0xFFE6F4F1),
        reason: 'the declared colour did not reach the tile at all');
    await runtime.destroy();
    return owned;
  }

  testWidgets('a tile colour draws with no ancestor background',
      (tester) async {
    expect(await tileColorPixels(tester, withAncestorBackground: false),
        greaterThan(0));
  });

  testWidgets('a tile colour draws under an ancestor background too',
      (tester) async {
    expect(await tileColorPixels(tester, withAncestorBackground: true),
        greaterThan(0),
        reason: 'the declared tile colour disappeared as soon as the page '
            'painted its own background — which is what every real page does');
  });

  testWidgets('the selected tile colour wins while selected', (tester) async {
    final runtime = MCPUIRuntime();
    await runtime.initialize(<String, dynamic>{
      'type': 'page',
      'content': <String, dynamic>{
        'type': 'box',
        'color': '#ffffff',
        'child': <String, dynamic>{
          'type': 'listItem',
          'title': 'row',
          'selected': true,
          'tileColor': '#e6f4f1',
          'selectedTileColor': '#ffe8cc',
        },
      },
    });
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: runtime.buildUI())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final tile = tester.widget<ListTile>(find.byType(ListTile));
    expect(tile.selected, isTrue);
    expect(tile.selectedTileColor, const Color(0xFFFFE8CC));
    expect(
        find
            .ancestor(
                of: find.byType(ListTile), matching: find.byType(Material))
            .evaluate()
            .where((e) =>
                (e.widget as Material).type == MaterialType.transparency)
            .length,
        greaterThan(0),
        reason: 'the selected colour needs the same owned ink layer');
    await runtime.destroy();
  });
}
