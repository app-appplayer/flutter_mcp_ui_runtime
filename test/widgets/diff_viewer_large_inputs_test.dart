// `diffViewer` on inputs big enough to matter.
//
// The widget has a branch a small example never reaches: a pair of files too
// large to diff cell by cell. It protects the frame budget — an n×m table over
// two long files is the kind of allocation that freezes an app rather than
// slowing it — and until now nothing had crossed the bound to see whether the
// degraded path renders at all.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MCPUIRuntime runtime;

  setUp(() => runtime = MCPUIRuntime());
  tearDown(() => runtime.destroy());

  Future<void> pumpContent(
    WidgetTester tester,
    Map<String, dynamic> content,
  ) async {
    await runtime.initialize({'type': 'page', 'content': content});
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: runtime.buildUI())),
    );
    await tester.pump();
  }

  group('diffViewer', () {
    testWidgets('a short pair is compared line by line', (tester) async {
      await pumpContent(tester, <String, dynamic>{
        'type': 'diffViewer',
        'oldValue': 'alpha\nbravo\ncharlie',
        'newValue': 'alpha\ndelta\ncharlie',
      });

      expect(find.textContaining('bravo'), findsWidgets,
          reason: 'the removed line is what a reviewer is looking for');
      expect(find.textContaining('delta'), findsWidgets);
      expect(find.textContaining('alpha'), findsWidgets,
          reason: 'and the unchanged context around it stays');
    });

    testWidgets('a pair too large to table degrades instead of allocating',
        (tester) async {
      // The bound is n*m; 2,100 lines each is over four million cells, which
      // is where the widget stops building a table and shows the two files as
      // a wholesale replacement.
      final left = List<String>.generate(2100, (i) => 'old line $i').join('\n');
      final right = List<String>.generate(2100, (i) => 'new line $i').join('\n');

      await pumpContent(tester, <String, dynamic>{
        'type': 'diffViewer',
        'oldValue': left,
        'newValue': right,
      });

      expect(tester.takeException(), isNull,
          reason: 'the whole point of the bound: a large pair has to render at '
              'all rather than freeze the frame building an n×m table');
      expect(find.textContaining('old line 0'), findsWidgets);
    });

    testWidgets('lines only the old side has are all reported', (tester) async {
      await pumpContent(tester, <String, dynamic>{
        'type': 'diffViewer',
        'oldValue': 'keep\ncut one\ncut two\ncut three',
        'newValue': 'keep',
      });

      for (final line in const ['cut one', 'cut two', 'cut three']) {
        expect(find.textContaining(line), findsWidgets,
            reason: 'a tail of removals that stops early hides deletions from '
                'the person reviewing them');
      }
    });

    testWidgets('lines only the new side has are all reported', (tester) async {
      await pumpContent(tester, <String, dynamic>{
        'type': 'diffViewer',
        'oldValue': 'keep',
        'newValue': 'keep\nadd one\nadd two',
      });

      expect(find.textContaining('add one'), findsWidgets);
      expect(find.textContaining('add two'), findsWidgets);
    });
  });

}
