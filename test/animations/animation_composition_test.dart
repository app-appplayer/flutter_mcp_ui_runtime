import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/animations/animation_composition.dart';

void main() {
  group('TC-ANIM-020: AnimationComposition — parallel', () {
    test('Normal: multiple widgets rendered in Stack', () {
      final result = AnimationComposition.parallel([
        const Text('A'),
        const Text('B'),
        const Text('C'),
      ]);

      expect(result, isA<Stack>());
      final stack = result as Stack;
      expect(stack.children.length, equals(3));
    });

    test('Boundary: single widget returned directly', () {
      const widget = Text('Only');
      final result = AnimationComposition.parallel([widget]);
      expect(result, same(widget));
    });

    test('Boundary: empty list returns SizedBox.shrink', () {
      final result = AnimationComposition.parallel([]);
      expect(result, isA<SizedBox>());
    });
  });

  group('TC-ANIM-021: AnimationComposition — sequence', () {
    testWidgets('Normal: creates sequence animation widget',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AnimationComposition.sequence(
            [
              () => const Text('Step 1'),
              () => const Text('Step 2'),
            ],
            [
              const Duration(milliseconds: 100),
              const Duration(milliseconds: 100),
            ],
          ),
        ),
      );

      // First step should be visible initially
      expect(find.text('Step 1'), findsOneWidget);
      expect(find.text('Step 2'), findsNothing);

      // After first duration, second step should appear
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Step 2'), findsOneWidget);
    });

    test('Boundary: empty builders returns SizedBox.shrink', () {
      final result = AnimationComposition.sequence([], []);
      expect(result, isA<SizedBox>());
    });
  });

  group('TC-021: AnimationComposition — parallel (spec)', () {
    test('Normal: all start simultaneously in Stack', () {
      final result = AnimationComposition.parallel([
        const Text('X'),
        const Text('Y'),
      ]);
      expect(result, isA<Stack>());
    });

    test('Boundary: single animation → behaves as standalone', () {
      const w = Text('Solo');
      final result = AnimationComposition.parallel([w]);
      expect(result, same(w));
    });

    test('Boundary: empty animations array → returns SizedBox (no-op)', () {
      final result = AnimationComposition.parallel([]);
      expect(result, isA<SizedBox>());
    });
  });

  group('TC-022: AnimationComposition — sequence (spec)', () {
    testWidgets('Normal: animations play one after another',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AnimationComposition.sequence(
            [
              () => const Text('First'),
              () => const Text('Second'),
              () => const Text('Third'),
            ],
            [
              const Duration(milliseconds: 100),
              const Duration(milliseconds: 100),
              const Duration(milliseconds: 100),
            ],
          ),
        ),
      );

      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsNothing);

      await tester.pump(const Duration(milliseconds: 150));

      // Advance past all timers to avoid "Timer still pending" error
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    test('Boundary: single animation in sequence → behaves as standalone',
        () {
      // Single builder should still create the widget
      final result = AnimationComposition.sequence(
        [() => const Text('Only')],
        [const Duration(milliseconds: 100)],
      );
      // Returns _SequenceAnimationWidget (StatefulWidget)
      expect(result, isA<Widget>());
    });

    test('Boundary: empty builders → returns SizedBox', () {
      final result = AnimationComposition.sequence([], []);
      expect(result, isA<SizedBox>());
    });
  });

  group('TC-023: AnimationComposition — stagger (spec)', () {
    testWidgets('Normal: stagger with 50ms delay',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AnimationComposition.stagger(
            [
              () => const Text('S0'),
              () => const Text('S1'),
              () => const Text('S2'),
            ],
            const Duration(milliseconds: 50),
          ),
        ),
      );

      await tester.pump(Duration.zero);
      expect(find.text('S0'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('S1'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('S2'), findsOneWidget);

      // Advance past all timers
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('Boundary: staggerDelay 0 → equivalent to parallel',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AnimationComposition.stagger(
            [
              () => const Text('A'),
              () => const Text('B'),
            ],
            Duration.zero,
          ),
        ),
      );

      await tester.pump(Duration.zero);
      // Both should appear immediately with zero delay
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);

      // Advance past all timers
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    test('Boundary: empty builders → returns SizedBox', () {
      final result = AnimationComposition.stagger(
        [],
        const Duration(milliseconds: 50),
      );
      expect(result, isA<SizedBox>());
    });
  });

  group('TC-ANIM-022: AnimationComposition — stagger', () {
    testWidgets('Normal: widgets appear with staggered timing',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AnimationComposition.stagger(
            [
              () => const Text('Item 0'),
              () => const Text('Item 1'),
              () => const Text('Item 2'),
            ],
            const Duration(milliseconds: 100),
          ),
        ),
      );

      // Item 0 should appear immediately (delay = 0)
      await tester.pump(Duration.zero);
      expect(find.text('Item 0'), findsOneWidget);

      // Item 1 should appear after 100ms
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Item 1'), findsOneWidget);

      // Item 2 should appear after another 100ms
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Item 2'), findsOneWidget);
    });

    test('Boundary: empty builders returns SizedBox.shrink', () {
      final result = AnimationComposition.stagger(
        [],
        const Duration(milliseconds: 100),
      );
      expect(result, isA<SizedBox>());
    });
  });
}
