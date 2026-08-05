// An `EdgeInsets` slot takes a binding, like every other primitive.
//
// It did not: the registry declared a number, the dimension object and the
// `{all|horizontal|top|…}` map, and `parseEdgeInsets` read the raw value. A
// document computing its padding was therefore rejected at authoring time, and
// would have produced no inset had it got past — while the same `{{…}}`
// expression was legal in the colour, dimension and action slots beside it.
//
// Both halves are pinned here: the schema accepts the bound form, and the
// runtime resolves it to the same inset the literal produces.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  group('the registry accepts every EdgeInsets spelling', () {
    for (final form in <Object>[
      8,
      <String, dynamic>{'value': 8, 'unit': 'px'},
      <String, dynamic>{'all': 8},
      <String, dynamic>{'horizontal': 8, 'vertical': 4},
      <String, dynamic>{'left': 8, 'right': 12},
      '{{layout.pad}}',
    ]) {
      test('padding = $form', () {
        final r = validateMcpUiDslWidget(
            <String, dynamic>{'type': 'padding', 'padding': form});
        expect(r.isValid, isTrue, reason: r.errors.take(2).join('\n'));
      });
    }

    test('a bare word is still not an inset', () {
      final r = validateMcpUiDslWidget(
          <String, dynamic>{'type': 'padding', 'padding': 'roomy'});
      expect(r.isValid, isFalse);
    });
  });

  // One runtime per test: standing two up inside a single `testWidgets` left
  // the second one unmounted, which is how an earlier version of this file
  // "passed" while proving nothing.
  Future<List<EdgeInsets>> insets(WidgetTester tester,
      Map<String, dynamic> page) async {
    final runtime = MCPUIRuntime();
    await runtime.initialize(page);
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: runtime.buildUI())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final found = tester
        .widgetList<Padding>(find.byType(Padding))
        .map((p) => p.padding)
        .whereType<EdgeInsets>()
        .where((e) => e.left == 24)
        .toList();
    await runtime.destroy();
    return found;
  }

  testWidgets('a literal inset reaches the widget', (tester) async {
    final found = await insets(tester, <String, dynamic>{
      'type': 'page',
      'content': <String, dynamic>{
        'type': 'padding',
        'padding': <String, dynamic>{'left': 24},
        'child': <String, dynamic>{'type': 'text', 'content': 'x'},
      },
    });
    expect(found, isNotEmpty);
    expect(found.first, const EdgeInsets.only(left: 24));
  });

  testWidgets('a bound inset reaches the widget as the same value',
      (tester) async {
    final found = await insets(tester, <String, dynamic>{
      'type': 'page',
      'state': <String, dynamic>{
        'initial': <String, dynamic>{
          'pad': <String, dynamic>{'left': 24},
        },
      },
      'content': <String, dynamic>{
        'type': 'padding',
        'padding': '{{pad}}',
        'child': <String, dynamic>{'type': 'text', 'content': 'x'},
      },
    });
    expect(found, isNotEmpty,
        reason: 'the bound padding produced no inset');
    expect(found.first, const EdgeInsets.only(left: 24));
  });

  testWidgets('one bound field beside literal ones resolves too',
      (tester) async {
    // The common authoring shape is not a whole bound map but one value from
    // state next to literals — `{left: "{{sidebar.width}}", top: 8}`. It works,
    // and until this case it worked by accident: nothing said the edge map's
    // *entries* resolve, only that the map as a whole does.
    final found = await insets(tester, <String, dynamic>{
      'type': 'page',
      'state': <String, dynamic>{
        'initial': <String, dynamic>{'padLeft': 24},
      },
      'content': <String, dynamic>{
        'type': 'padding',
        'padding': <String, dynamic>{'left': '{{padLeft}}', 'top': 6},
        'child': <String, dynamic>{'type': 'text', 'content': 'x'},
      },
    });
    expect(found, isNotEmpty,
        reason: 'a bound entry inside the edge map produced no inset');
    expect(found.first.left, 24);
    expect(found.first.top, 6);
  });
}
