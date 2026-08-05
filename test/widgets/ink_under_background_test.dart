// Ink draws over what the document paints, not under it.
//
// Splash, focus and hover overlays are painted by the nearest `Material`. That
// is normally the app's, which sits *below* every background the document
// paints on the way down — so a page with a background colour, which is nearly
// every page, covered them completely. The properties validated, rendered no
// error, and drew nothing.
//
// What is asserted here is the *structure* that decides it: the ink layer has
// to belong to this widget. A pixel probe was tried first and thrown away —
// under the test binding no splash reaches the raster even where the ink is
// known good, so it read zero in every case and would have called the bug
// fixed and the fix broken alike. The pixel evidence comes from a live run
// instead (three-way control: opaque child · transparent child under a painted
// page · no page background — only the last showed ink before this change).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  Map<String, dynamic> pageWith(Map<String, dynamic> content,
          {required bool background}) =>
      <String, dynamic>{
        'type': 'page',
        'content': background
            ? <String, dynamic>{
                'type': 'box',
                'color': '#f2f6f5',
                'child': content,
              }
            : content,
      };

  final ink = <String, dynamic>{
    'type': 'inkWell',
    'splashColor': '#b3261e',
    'focusColor': '#b3261e',
    'hoverColor': '#b3261e',
    'onTap': <String, dynamic>{'type': 'state', 'action': 'set', 'binding': 'x', 'value': 1},
    'child': <String, dynamic>{'type': 'text', 'content': 'tap'},
  };

  Future<int> ownedInkLayers(WidgetTester tester,
      {required bool background}) async {
    final runtime = MCPUIRuntime();
    await runtime.initialize(pageWith(ink, background: background));
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: runtime.buildUI())));
    await tester.pump();
    final owned = find
        .ancestor(of: find.byType(InkWell), matching: find.byType(Material))
        .evaluate()
        .where((e) => (e.widget as Material).type == MaterialType.transparency)
        .length;
    await runtime.destroy();
    return owned;
  }

  testWidgets('the ink layer belongs to the widget, with a page background',
      (tester) async {
    expect(await ownedInkLayers(tester, background: true), greaterThan(0),
        reason: 'without its own Material the ink is painted by the app, '
            'below the background the page paints over it');
  });

  testWidgets('and without one', (tester) async {
    expect(await ownedInkLayers(tester, background: false), greaterThan(0));
  });

  testWidgets('a list row owns its ink layer too', (tester) async {
    final runtime = MCPUIRuntime();
    await runtime.initialize(pageWith(<String, dynamic>{
      'type': 'listItem',
      'title': 'row',
      'hoverColor': '#b3261e',
    }, background: true));
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: runtime.buildUI())));
    await tester.pump();
    expect(
        find
            .ancestor(
                of: find.byType(ListTile), matching: find.byType(Material))
            .evaluate()
            .where((e) =>
                (e.widget as Material).type == MaterialType.transparency)
            .length,
        greaterThan(0),
        reason: 'hoverColor uses the same layer as tileColor');
    await runtime.destroy();
  });
}
