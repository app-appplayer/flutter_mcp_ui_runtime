// A legacy colour name paints, not merely resolves.
//
// `ThemeManager` answers `background` with `surface`, and there are tests for
// that. Neither says whether a widget that names it ends up the right colour:
// a box whose colour resolved to null draws perfectly — transparent — and
// every render check stays green. That is the gap konpi kept falling into,
// twice, from the outside.
//
// So this reads the painted decoration and compares colours, which is the
// only form of the question a user would recognise.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

const _theme = <String, dynamic>{
  'color': <String, dynamic>{
    'seed': '#3F51B5',
    'surface': '#FFFFFF',
    'onSurface': '#0E1B2A',
  },
};

/// Paints a `box` with [color] and returns the colour it actually drew.
Future<Color?> _painted(WidgetTester tester, String color) async {
  final runtime = MCPUIRuntime();
  // The theme goes straight to the manager rather than through a document:
  // a page carries no theme of its own and an application routes through a
  // page loader, and neither detour is what this test is about. The question
  // is whether a name resolves all the way to a painted colour.
  await runtime.initialize(<String, dynamic>{
    'type': 'page',
    'content': <String, dynamic>{
      'type': 'box',
      'width': 40,
      'height': 40,
      'color': color,
      'child': <String, dynamic>{'type': 'text', 'content': 'x'},
    },
  }, useCache: false);
  runtime.engine.themeManager.setTheme(_theme);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: runtime.buildUI())),
  );
  await tester.pump(const Duration(milliseconds: 50));

  // Find the box by the size it declared. "The first coloured container" is
  // the scaffold, which is white whatever the document said — the first two
  // runs of this test were reading that and calling it a result.
  Color? found;
  for (final element in find.byType(Container).evaluate()) {
    final size = element.size;
    if (size == null || (size.width - 40).abs() > 0.5 ||
        (size.height - 40).abs() > 0.5) {
      continue;
    }
    final container = element.widget as Container;
    final decoration = container.decoration;
    if (decoration is BoxDecoration) {
      found = decoration.color;
    } else {
      found = container.color;
    }
    break;
  }
  await runtime.dispose();
  return found;
}

void main() {
  // Declared in `_theme` above; compared against as constants rather than by
  // rendering a second document. Two `_painted` calls inside one `testWidgets`
  // share a tester across disposals and the second returns nothing — a
  // harness artefact that reads exactly like an unresolved colour.
  const surface = Color(0xFFFFFFFF);
  const onSurface = Color(0xFF0E1B2A);

  testWidgets('a canonical role paints its declared colour', (tester) async {
    expect(await _painted(tester, 'surface'), surface);
  });

  testWidgets('a legacy role paints what it resolves to', (tester) async {
    // §5.3.1: `background` resolves as `surface`. Had the name resolved to
    // nothing the box would be transparent and nothing else would notice.
    expect(await _painted(tester, 'background'), surface);
  });

  testWidgets('onBackground paints onSurface', (tester) async {
    expect(await _painted(tester, 'onBackground'), onSurface);
  });

  testWidgets('a derived role paints even when the theme omits it',
      (tester) async {
    // The theme declares two roles; the rest derive from the seed. A widget
    // naming one of the derived roles must still get a colour.
    final derived = await _painted(tester, 'primaryContainer');
    expect(derived, isNotNull);
    expect(derived, isNot(surface));
  });

  testWidgets('a name that is not a role never reaches the paint at all',
      (tester) async {
    // The other direction, and the answer turned out to be one step earlier
    // than expected: validation refuses the document, so the widget is never
    // asked to paint `tomato`. That is the better place for it to fail — the
    // author is told, rather than shown a transparent box. Recorded as the
    // behaviour rather than rewritten to what the test first assumed.
    Object? thrown;
    try {
      await _painted(tester, 'tomato');
    } catch (e) {
      thrown = e;
    }
    expect(thrown, isA<StateError>());
    expect(thrown.toString(), contains('schema validation failed'));
  });
}
