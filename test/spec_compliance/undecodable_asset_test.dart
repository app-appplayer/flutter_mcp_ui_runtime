// §6.12.4 — an asset the runtime cannot decode takes the slot's declared
// fallback, and the reason never appears on screen.
//
// The rule is written with an example that is almost this exact case: "A box
// reading `Base64 not supported` states the runtime's limitation in the user's
// screen; the author asked for a picture, and the failure belongs in the
// diagnostic channel, not the layout." A tile reading `SVG not supported` is
// the same mistake with a different word, and this suite exists because that
// tile was briefly shipped.
//
// An undecodable payload is *not* the same as an invalid document: §6.12.1
// says a runtime meeting something it cannot resolve treats it as an
// unresolvable asset, never as a schema violation. So the document validates,
// and what is checked here is what the author sees.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

// A reference this runtime cannot reach: a bundle asset with no bundle wired.
// Well-formed, valid against the schema, and unresolvable — which is the pair
// the rule is about. (It used to be an SVG data URI. That stopped being an
// example when the vector path landed, and a suite whose premise has quietly
// become false is worse than no suite.)
const _unresolvable = 'bundle://missing/logo.png';

void main() {
  Future<void> pump(WidgetTester tester, Map<String, dynamic> content) async {
    final runtime = MCPUIRuntime();
    addTearDown(runtime.destroy);
    await runtime.initialize(
        <String, dynamic>{'type': 'page', 'content': content});
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: runtime.buildUI())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  test('an undecodable payload is still a valid document (§6.12.1)', () {
    final r = validateMcpUiDslWidget(
        <String, dynamic>{'type': 'image', 'src': _unresolvable});
    expect(r.isValid, isTrue, reason: r.errors.take(2).join('\n'));
  });

  testWidgets('the runtime does not name its limitation on screen',
      (tester) async {
    await pump(tester, <String, dynamic>{'type': 'image', 'src': _unresolvable});

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => (t.data ?? '').toLowerCase())
        .toList();
    for (final t in texts) {
      expect(t.contains('svg'), isFalse,
          reason: '§6.12.4: the limitation belongs in the diagnostic channel, '
              'not the layout — found "$t"');
      expect(t.contains('not supported'), isFalse, reason: 'same rule');
      expect(t.contains('base64'), isFalse, reason: 'same rule');
    }
  });

  testWidgets('the declared fallback widget takes the slot instead',
      (tester) async {
    await pump(tester, <String, dynamic>{
      'type': 'image',
      'src': _unresolvable,
      'fallback': <String, dynamic>{'type': 'text', 'content': 'no picture'},
    });
    expect(find.text('no picture'), findsOneWidget,
        reason: 'an undecodable payload must take the declared fallback path');
  });

  testWidgets('fallbackBehavior: hide leaves the slot empty', (tester) async {
    await pump(tester, <String, dynamic>{
      'type': 'image',
      'src': _unresolvable,
      'fallbackBehavior': 'hide',
    });
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('a raster payload in the same slot still draws', (tester) async {
    // The contrast is what makes the three cases above mean something: the
    // pipeline works, and it is the payload format that decides.
    await pump(tester, <String, dynamic>{
      'type': 'image',
      'src': 'data:image/png;base64,'
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    });
    expect(find.byType(Image), findsOneWidget);
  });
}
