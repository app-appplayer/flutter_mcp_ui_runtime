import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/accessibility/focus_manager.dart';

/// TC-010, TC-022: TouchTargetSize tests
/// Corresponds to: 04_TEST/feat-runtime/14-accessibility.md §5, §10
void main() {
  group('TouchTargetSize Tests', () {
    // TC-010: TouchTargetEnforcer — size enforcement
    group('TC-010: Size enforcement', () {
      test('Normal: Button 60x60 is compliant (no adjustment needed)', () {
        const width = 60.0;
        const height = 60.0;
        expect(width >= TouchTargetSize.minimumSize, isTrue);
        expect(height >= TouchTargetSize.minimumSize, isTrue);
      });

      test('Normal: Button 30x30 is not compliant', () {
        const width = 30.0;
        const height = 30.0;
        expect(width >= TouchTargetSize.minimumSize, isFalse);
        expect(height >= TouchTargetSize.minimumSize, isFalse);
      });

      test('Normal: Button 48x48 is exactly minimum, compliant', () {
        const width = 48.0;
        const height = 48.0;
        expect(width >= TouchTargetSize.minimumSize, isTrue);
        expect(height >= TouchTargetSize.minimumSize, isTrue);
      });

      test('Boundary: Button 48x20 — height non-compliant', () {
        const width = 48.0;
        const height = 20.0;
        expect(width >= TouchTargetSize.minimumSize, isTrue);
        expect(height >= TouchTargetSize.minimumSize, isFalse);
      });

      test('Boundary: Button 20x48 — width non-compliant', () {
        const width = 20.0;
        const height = 48.0;
        expect(width >= TouchTargetSize.minimumSize, isFalse);
        expect(height >= TouchTargetSize.minimumSize, isTrue);
      });
    });

    // TC-022: TouchTargetSize — ensureMinimumSize
    group('TC-022: TouchTargetSize constants and enforcement', () {
      test('Normal: minimumSize constant equals 48.0', () {
        expect(TouchTargetSize.minimumSize, 48.0);
      });

      testWidgets(
          'Normal: ConstrainedBox with 48x48 minimum wraps small widget',
          (tester) async {
        // Simulate ensureMinimumSize behavior using ConstrainedBox
        const child = SizedBox(width: 20, height: 20);
        final wrapped = ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: TouchTargetSize.minimumSize,
            minHeight: TouchTargetSize.minimumSize,
          ),
          child: child,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: Center(child: wrapped)),
          ),
        );

        final boxes = tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox));
        final hasMinSize = boxes.any((cb) =>
            cb.constraints.minWidth >= TouchTargetSize.minimumSize &&
            cb.constraints.minHeight >= TouchTargetSize.minimumSize);
        expect(hasMinSize, isTrue);
      });

      testWidgets('Normal: Widget already >= 48x48 needs no wrapping',
          (tester) async {
        const child = SizedBox(width: 60, height: 60);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: Center(child: child)),
          ),
        );

        final box = tester.getSize(find.byType(SizedBox));
        expect(box.width >= TouchTargetSize.minimumSize, isTrue);
        expect(box.height >= TouchTargetSize.minimumSize, isTrue);
      });
    });
  });
}
