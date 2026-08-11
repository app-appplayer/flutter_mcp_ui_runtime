// Shapes that cannot be drawn must still be shapes that open.
//
// Three documents used to pass the load gate and then be refused on screen: a
// `conditional` with neither `condition` nor `switch`, a `tabBar` whose tab
// names no label and no icon, a `table` whose row carries no cells. The
// obvious repair is to declare the missing key required — and it is the wrong
// one. Validation runs when the document loads (`MCPUIRuntime.initialize`), so
// a narrowed schema does not deprecate an old document, it stops the whole
// document opening: one bad row would take a page of good widgets with it.
//
// §1.7.5 is that rule. The DSL only widens; a shape once accepted stays
// accepted, and the runtime is where a shape that cannot be laid out is
// absorbed. These tests hold both halves — the schema still admits each
// document, and the frame comes up without an error card.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart'
    show validateMcpUiDslWidget;
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

/// Loads [content] through the real gate and returns the error text the frame
/// shows, or null when it came up clean.
Future<String?> _openAndDraw(
    WidgetTester tester, Map<String, dynamic> content) async {
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) => errors.add(details.exceptionAsString());

  final runtime = MCPUIRuntime();
  addTearDown(runtime.dispose);
  await runtime.initialize(<String, dynamic>{
    'type': 'page',
    'content': content,
  });
  await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: runtime.buildUI())));
  await tester.pump();
  FlutterError.onError = previous;

  if (errors.isNotEmpty) return 'FlutterError: ${errors.first}';
  for (final marker in const [
    'Unknown widget type:',
    'Error rendering',
    'Widget type is required',
  ]) {
    final found = find.textContaining(marker);
    if (tester.any(found)) {
      return tester.widgetList<Text>(found).first.data ?? marker;
    }
  }
  return null;
}

void main() {
  /// The pair: the schema keeps accepting it, and it draws.
  void staysLoadable(String what, Map<String, dynamic> content) {
    testWidgets(what, (tester) async {
      expect(validateMcpUiDslWidget(content).isValid, isTrue,
          reason: 'the schema narrowed — this document no longer opens at all, '
              'which §1.7.5 rules out\n'
              '${validateMcpUiDslWidget(content).errors.take(2).join("\n")}');
      expect(await _openAndDraw(tester, content), isNull,
          reason: 'accepted at load and then refused on screen');
    });
  }

  staysLoadable('a conditional with neither condition nor switch',
      <String, dynamic>{'type': 'conditional'});

  staysLoadable('a conditional with no condition falls to its else branch',
      <String, dynamic>{
        'type': 'conditional',
        'else': <String, dynamic>{'type': 'text', 'content': 'fallback'},
      });

  staysLoadable('a tabBar whose tab names nothing', <String, dynamic>{
    'type': 'tabBar',
    'tabs': <dynamic>[<String, dynamic>{}],
  });

  staysLoadable('a table row with no cells', <String, dynamic>{
    'type': 'table',
    'rows': <dynamic>[<String, dynamic>{}],
  });

  staysLoadable('a table row keyed by column name (the dataTable shape)',
      <String, dynamic>{
        'type': 'table',
        'rows': <dynamic>[
          <String, dynamic>{'name': 'Flutter', 'version': '3.10'},
        ],
      });

  testWidgets('the else branch is what a condition-less conditional shows',
      (tester) async {
    await _openAndDraw(tester, <String, dynamic>{
      'type': 'conditional',
      'then': <String, dynamic>{'type': 'text', 'content': 'then-branch'},
      'else': <String, dynamic>{'type': 'text', 'content': 'else-branch'},
    });
    expect(find.text('else-branch'), findsOneWidget);
    expect(find.text('then-branch'), findsNothing,
        reason: 'no condition is not a true condition');
  });

  testWidgets('a table draws the rows it can lay out and skips the rest',
      (tester) async {
    await _openAndDraw(tester, <String, dynamic>{
      'type': 'table',
      'rows': <dynamic>[
        <String, dynamic>{},
        <String, dynamic>{
          'cells': <dynamic>[
            <String, dynamic>{'type': 'text', 'content': 'kept'},
          ],
        },
      ],
    });
    expect(find.text('kept'), findsOneWidget,
        reason: 'one unlayoutable row must not take the table down with it');
  });
}
