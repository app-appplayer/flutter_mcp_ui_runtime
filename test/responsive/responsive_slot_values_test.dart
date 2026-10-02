// A responsive object is accepted on any numeric, string, enum or token
// shorthand property (§14.2.2) — not only on the few slots that happened to
// call the picker. Each case below draws the same document at a compact and a
// medium width and reads what the widget was built with.
//
// Measured on a sample before the fix: `grid.itemAspectRatio` given
// `{default: 0.95, medium: 1.25}` drew at 1.0 on a desk-sized screen, so the
// kiosk cards grew and pushed the page's last button off screen.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/mcp_ui_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const compact = Size(400, 800);
  const medium = Size(700, 900);

  Future<void> draw(
    WidgetTester tester,
    Size size,
    Map<String, dynamic> content,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final runtime = MCPUIRuntime(enableDebugMode: false);
    addTearDown(runtime.dispose);
    await runtime.initialize({'type': 'page', 'content': content});
    await tester
        .pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
    await tester.pump();
  }

  /// One test per size: the runtime keeps process-wide services, so two
  /// runtimes drawn in one test would measure the second against the first.
  void atBoth(
    String name,
    Map<String, dynamic> content,
    void Function(WidgetTester tester, String formFactor) check,
  ) {
    for (final entry in {'compact': compact, 'medium': medium}.entries) {
      testWidgets('$name at ${entry.key}', (tester) async {
        await draw(tester, entry.value, content);
        check(tester, entry.key);
      });
    }
  }

  atBoth(
    'grid itemAspectRatio',
    {
      'type': 'grid',
      'columns': 2,
      'itemAspectRatio': {'default': 0.5, 'medium': 2.0},
      'children': [
        {'type': 'text', 'content': 'a'},
        {'type': 'text', 'content': 'b'},
      ],
    },
    (tester, ff) {
      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.childAspectRatio, ff == 'medium' ? 2.0 : 0.5,
          reason: 'at $ff');
    },
  );

  atBoth(
    'container width and padding',
    {
      'type': 'container',
      'width': {'compact': 100, 'medium': 300},
      'padding': {'compact': 4, 'medium': 24},
      'child': {'type': 'text', 'content': 'x'},
    },
    (tester, ff) {
      final box = tester.renderObject<RenderBox>(find.byType(Container).last);
      expect(box.size.width, ff == 'medium' ? 300 : 100, reason: 'at $ff');
      final text = tester.getTopLeft(find.text('x'));
      final origin = tester.getTopLeft(find.byType(Container).last);
      expect(text.dx - origin.dx, ff == 'medium' ? 24 : 4, reason: 'at $ff');
    },
  );

  atBoth(
    'text content, fontSize and textAlign',
    {
      'type': 'text',
      'content': {'compact': 'short', 'medium': 'longer label'},
      'textAlign': {'compact': 'left', 'medium': 'center'},
      'style': {
        'fontSize': {'compact': 12, 'medium': 20},
      },
    },
    (tester, ff) {
      final label = ff == 'medium' ? 'longer label' : 'short';
      expect(find.text(label), findsOneWidget, reason: 'at $ff');
      final text = tester.widget<Text>(find.text(label));
      expect(text.style?.fontSize, ff == 'medium' ? 20 : 12, reason: 'at $ff');
      expect(text.textAlign, ff == 'medium' ? TextAlign.center : TextAlign.left,
          reason: 'at $ff');
    },
  );

  testWidgets('resizing the window redraws with the new size\'s value',
      (tester) async {
    // The renderer caches built widgets; a key without the form factor
    // answered a medium window with the widget built for compact.
    await draw(tester, compact, {
      'type': 'container',
      'width': {'compact': 100, 'medium': 300},
      'child': {'type': 'text', 'content': 'x'},
    });
    expect(
        tester.renderObject<RenderBox>(find.byType(Container).last).size.width,
        100);

    tester.view.physicalSize = medium;
    await tester.pump();

    expect(
        tester.renderObject<RenderBox>(find.byType(Container).last).size.width,
        300);
  });

  testWidgets('a value with no key for the active size falls back to default',
      (tester) async {
    await draw(tester, compact, {
      'type': 'container',
      'width': {'medium': 300, 'default': 150},
      'child': {'type': 'text', 'content': 'x'},
    });
    final box = tester.renderObject<RenderBox>(find.byType(Container).last);
    expect(box.size.width, 150);
  });

  testWidgets('a configuration map keyed by size names is not collapsed',
      (tester) async {
    // `theme.breakpoints` is keyed by the same labels a responsive object
    // uses. Picking applies to a scalar slot only, so a map read as a map
    // keeps every entry.
    final runtime = MCPUIRuntime(enableDebugMode: false);
    addTearDown(runtime.dispose);
    await runtime.initialize({
      'type': 'page',
      'content': {'type': 'text', 'content': 'x'},
    });
    await tester
        .pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
    await tester.pump();
    final element = tester.element(find.text('x'));
    final ctx = runtime.engine.renderer.createRootContext(element);
    final map = ctx.resolve<Map<String, dynamic>>(
        <String, dynamic>{'compact': 0, 'medium': 600});
    expect(map, {'compact': 0, 'medium': 600});
  });

  test('no slot is read without its context', () {
    // `parseDimension` takes no context, so it cannot pick a responsive
    // object or resolve a binding. 47 slots read `parseDimension(
    // context.resolve(x))` and a handful `parseDimension(properties[x])`;
    // a slot read that way is the defect this file is about.
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.contains('parseDimension(context.resolve(') ||
            line.contains('parseDimension(properties[')) {
          offenders.add('${file.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'read the slot with readDimension(raw, context)');
  });
}
