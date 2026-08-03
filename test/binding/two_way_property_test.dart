// A two-way property writes back to the path it reads from.
//
// `resizable.width` is declared `number | binding` and documented "bind it to
// persist the size". The factory took the raw property as the state path, so a
// document written the documented way — `"width": "{{panel.width}}"` — read
// through the resolver from `panel.width` and wrote back to a key literally
// named `{{panel.width}}`. Nothing crashed and nothing persisted.
//
// Rendering alone cannot catch that: the read works either way. Only driving
// the interaction and then looking at *where* the value landed does.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_mcp_ui_runtime/src/utils/binding_path.dart';

void main() {
  group('twoWayPath', () {
    test('unwraps the braced form to a writable path', () {
      expect(twoWayPath('{{panel.width}}'), 'panel.width');
      expect(twoWayPath('  {{ panel.width }}  '), 'panel.width');
    });

    test('accepts the bare path form the schema also allows', () {
      expect(twoWayPath('panel.width'), 'panel.width');
      expect(twoWayPath('items[0].w'), 'items[0].w');
    });

    test('a literal is not a path', () {
      expect(twoWayPath(300), isNull);
      expect(twoWayPath(true), isNull);
      expect(twoWayPath(null), isNull);
    });

    test('an expression has no single write target', () {
      expect(twoWayPath('{{a + 1}}'), isNull);
      expect(twoWayPath('{{a ? b : c}}'), isNull);
    });
  });

  testWidgets('resizable persists a drag to the bound path', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final runtime = MCPUIRuntime();
    await runtime.initialize(<String, dynamic>{
      'type': 'page',
      'state': <String, dynamic>{
        'initial': <String, dynamic>{
          'panel': <String, dynamic>{'width': 200.0, 'height': 100.0},
        },
      },
      'content': <String, dynamic>{
        'type': 'resizable',
        'width': '{{panel.width}}',
        'height': '{{panel.height}}',
        'handles': <String>['bottomEnd'],
        'child': <String, dynamic>{'type': 'text', 'content': 'panel'},
      },
    });
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: runtime.buildUI())),
    );
    await tester.pump(const Duration(milliseconds: 50));

    // The bound value is what got drawn.
    final sized = tester.widget<SizedBox>(
      find.ancestor(
        of: find.text('panel'),
        matching: find.byType(SizedBox),
      ).first,
    );
    expect(sized.width, 200.0);

    final handle = find.byType(GestureDetector).last;
    await tester.drag(handle, const Offset(40, 25));
    await tester.pump();

    final state = runtime.stateManager.get<Map<String, dynamic>>('panel');
    expect(state, isNotNull,
        reason: 'the drag wrote nowhere the document can read back');
    expect((state!['width'] as num).toDouble(), 240.0);
    expect((state['height'] as num).toDouble(), 125.0);

    // And nothing landed under the raw expression.
    expect(runtime.stateManager.get<dynamic>('{{panel.width}}'), isNull);

    await runtime.dispose();
  });
}
