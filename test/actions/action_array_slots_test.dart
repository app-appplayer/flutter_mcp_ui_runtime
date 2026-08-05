// An action slot takes a list, and every entry in it runs.
//
// The registry declares `Action` as `object | array | binding`. Reading such a
// slot with `as Map<String, dynamic>?` renders an error for the list form,
// which is what a document writing two actions on one button got. Taking only
// `first` would be worse: the document reports success while half of what it
// asked for silently never happened.
//
// The slots are checked by name rather than through one representative,
// because the previous round fixed `click` and left `button.onTap` broken —
// the two are read in different places.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  late MCPUIRuntime runtime;

  setUp(() => runtime = MCPUIRuntime());
  tearDown(() async => runtime.destroy());

  Future<void> pump(WidgetTester tester, Map<String, dynamic> content) async {
    await runtime.initialize(<String, dynamic>{
      'type': 'page',
      'state': <String, dynamic>{
        'initial': <String, dynamic>{'a': 'untouched', 'b': 'untouched'},
      },
      'content': content,
    });
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: runtime.buildUI())));
    await tester.pumpAndSettle();
  }

  List<dynamic> twoWrites() => <dynamic>[
        <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'a',
          'value': 'first ran',
        },
        <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'b',
          'value': 'second ran',
        },
      ];

  void bothRan() {
    expect(runtime.stateManager.get('a'), 'first ran',
        reason: 'the first action in the list did not run');
    expect(runtime.stateManager.get('b'), 'second ran',
        reason: 'only the first action ran — the rest of the list was dropped');
  }

  testWidgets('button.onTap takes a list and runs every entry', (tester) async {
    await pump(tester, <String, dynamic>{
      'type': 'button',
      'label': 'go',
      'onTap': twoWrites(),
    });
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    bothRan();
  });

  testWidgets('the common `click` slot does the same', (tester) async {
    await pump(tester, <String, dynamic>{
      'type': 'box',
      'width': 120,
      'height': 40,
      'click': twoWrites(),
      'child': <String, dynamic>{'type': 'text', 'content': 'tap here'},
    });
    await tester.tap(find.text('tap here'));
    await tester.pumpAndSettle();
    bothRan();
  });

  testWidgets('a single action in the same slot still runs', (tester) async {
    await pump(tester, <String, dynamic>{
      'type': 'button',
      'label': 'go',
      'onTap': <String, dynamic>{
        'type': 'state',
        'action': 'set',
        'binding': 'a',
        'value': 'first ran',
      },
    });
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(runtime.stateManager.get('a'), 'first ran');
    expect(runtime.stateManager.get('b'), 'untouched');
  });

  testWidgets('an empty list is a slot with nothing to do, not an error',
      (tester) async {
    await pump(tester, <String, dynamic>{
      'type': 'button',
      'label': 'go',
      'onTap': <dynamic>[],
    });
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(runtime.stateManager.get('a'), 'untouched');
  });
}
