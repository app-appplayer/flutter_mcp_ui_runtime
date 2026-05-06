// Phase 1.B — `text` widget enrichments: shader-fill, dropCap, fontFeatures.
//
// Locks the spec § configs/widget/TextStyle (shader, fontFeatures,
// shadows) and § configs/widget/DropCap fields against the runtime
// rendering. Each test asserts on the widget tree shape rather than
// pixel output so the assertions remain stable across Flutter
// rendering-pipeline changes.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

Future<MCPUIRuntime> _bootRuntime(Map<String, dynamic> root) async {
  final runtime = MCPUIRuntime();
  await runtime.initialize({
    'type': 'page',
    'content': root,
  });
  return runtime;
}

void main() {
  group('Phase 1.B — text style.shader', () {
    testWidgets('linear gradient shader wraps Text in ShaderMask',
        (tester) async {
      final runtime = await _bootRuntime({
        'type': 'text',
        'text': 'Sunset',
        'style': {
          'fontSize': 32.0,
          'fontWeight': 'bold',
          'shader': {
            'type': 'linear',
            'colors': ['#FF6B6B', '#FFD93D'],
            'begin': 'centerStart',
            'end': 'centerEnd',
          },
        },
      });
      await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
      await tester.pump();

      expect(find.byType(ShaderMask), findsOneWidget);
      expect(find.text('Sunset'), findsOneWidget);
    });

    testWidgets('no shader → no ShaderMask wrap', (tester) async {
      final runtime = await _bootRuntime({
        'type': 'text',
        'text': 'Plain',
        'style': {'fontSize': 16, 'color': '#000000'},
      });
      await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
      await tester.pump();

      expect(find.byType(ShaderMask), findsNothing);
      expect(find.text('Plain'), findsOneWidget);
    });
  });

  group('Phase 1.B — text style.fontFeatures', () {
    testWidgets('fontFeatures land on the rendered TextStyle',
        (tester) async {
      final runtime = await _bootRuntime({
        'type': 'text',
        'text': 'Old Style 1234',
        'style': {
          'fontSize': 18,
          'fontFeatures': ['smcp', 'lnum', 'tnum=1'],
        },
      });
      await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
      await tester.pump();

      final widget = tester.widget<Text>(find.text('Old Style 1234'));
      final features = widget.style?.fontFeatures;
      expect(features, isNotNull);
      expect(features!.length, equals(3));
      expect(features.any((f) => f == const ui.FontFeature.enable('smcp')),
          isTrue);
      expect(features.any((f) => f == const ui.FontFeature.enable('lnum')),
          isTrue);
      expect(features.any((f) => f == const ui.FontFeature('tnum', 1)),
          isTrue);
    });
  });

  group('Phase 1.B — DropCap', () {
    testWidgets('renders cap as separate Text + indented body',
        (tester) async {
      final runtime = await _bootRuntime({
        'type': 'text',
        'text': 'Once upon a time in a land far far away there lived '
            'a runtime that loved its decorations.',
        'style': {'fontSize': 16},
        'dropCap': {
          'lines': 3,
          'style': {'fontFamily': 'serif', 'fontWeight': 'bold'},
        },
      });
      await tester.pumpWidget(MaterialApp(
        home: SizedBox(
          width: 400,
          child: runtime.buildUI(),
        ),
      ));
      await tester.pump();

      // Cap glyph rendered separately.
      expect(find.text('O'), findsOneWidget);
      // Body text is split into the indented + continuation parts.
      expect(find.byType(Stack), findsAtLeast(1));
    });

    testWidgets('glyph override replaces first character', (tester) async {
      final runtime = await _bootRuntime({
        'type': 'text',
        'text': 'After much deliberation the decision was made.',
        'dropCap': {'lines': 2, 'glyph': '❦'},
      });
      await tester.pumpWidget(MaterialApp(
        home: SizedBox(
          width: 400,
          child: runtime.buildUI(),
        ),
      ));
      await tester.pump();

      expect(find.text('❦'), findsOneWidget);
    });

    testWidgets('empty text → empty SizedBox (no crash)', (tester) async {
      final runtime = await _bootRuntime({
        'type': 'text',
        'text': '',
        'dropCap': {'lines': 3},
      });
      await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
      await tester.pump();
      // Just shouldn't throw.
    });
  });
}
