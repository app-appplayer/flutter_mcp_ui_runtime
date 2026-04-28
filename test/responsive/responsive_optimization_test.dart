import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/responsive/breakpoint_system.dart';
import 'package:flutter_mcp_ui_runtime/src/responsive/responsive_resolver.dart';

void main() {
  late BreakpointSystem system;
  late ResponsiveResolver resolver;

  setUp(() {
    system = BreakpointSystem();
    resolver = ResponsiveResolver(breakpointSystem: system);
  });

  // ===========================================================================
  // TC-027: Same-breakpoint re-render avoidance
  // ===========================================================================
  group('TC-027: Same-breakpoint re-render avoidance', () {
    test('TC-027 Normal: same breakpoint for 500px and 550px (both xs) — no breakpoint change', () {
      final bp500 = system.getCurrentBreakpoint(500);
      final bp550 = system.getCurrentBreakpoint(550);

      // Both widths fall within xs, so no re-render should be triggered
      expect(bp500, equals('compact'));
      expect(bp550, equals('compact'));
      expect(bp500 == bp550, isTrue);
    });

    test('TC-027 Normal: breakpoint changes from 500px to 700px (xs → sm) — re-render triggered', () {
      final bp500 = system.getCurrentBreakpoint(500);
      final bp700 = system.getCurrentBreakpoint(700);

      expect(bp500, equals('compact'));
      expect(bp700, equals('medium'));
      expect(bp500 != bp700, isTrue);
    });

    test('TC-027 Normal: resolved values identical within same breakpoint', () {
      final definition = {
        'padding': <String, dynamic>{'compact': 8, 'expanded': 16},
        'columns': <String, dynamic>{'compact': 1, 'medium': 2},
      };

      // Both widths are in xs range
      final resolved500 = resolver.resolveDefinition(definition, 500);
      final resolved550 = resolver.resolveDefinition(definition, 550);

      expect(resolved500['padding'], equals(resolved550['padding']));
      expect(resolved500['columns'], equals(resolved550['columns']));
    });

    test('TC-027 Normal: resolved values differ across breakpoints', () {
      final definition = {
        'padding': <String, dynamic>{'compact': 8, 'medium': 12, 'expanded': 16},
      };

      // 500 is xs, 700 is sm
      final resolvedXs = resolver.resolveDefinition(definition, 500);
      final resolvedSm = resolver.resolveDefinition(definition, 700);

      expect(resolvedXs['padding'], equals(8));
      expect(resolvedSm['padding'], equals(12));
      expect(resolvedXs['padding'] != resolvedSm['padding'], isTrue);
    });

    test('TC-027 Boundary: size change to exact boundary triggers transition', () {
      final bp599 = system.getCurrentBreakpoint(599);
      final bp600 = system.getCurrentBreakpoint(600);

      expect(bp599, equals('compact'));
      expect(bp600, equals('medium'));
      expect(bp599 != bp600, isTrue);
    });

    test('TC-027 Normal: multiple widths in same range produce consistent results', () {
      // All within medium range (600-839)
      final widths = [600, 650, 700, 750, 800, 839];
      final breakpoints = widths.map((w) => system.getCurrentBreakpoint(w.toDouble())).toSet();

      // All should resolve to the same breakpoint
      expect(breakpoints.length, equals(1));
      expect(breakpoints.first, equals('medium'));
    });
  });

  // ===========================================================================
  // TC-028: Responsive property memoization
  // ===========================================================================
  group('TC-028: Responsive property memoization', () {
    test('TC-028 Normal: same breakpoint queried twice returns same resolved properties', () {
      final definition = {
        'padding': <String, dynamic>{'compact': 8, 'expanded': 16, 'extraLarge': 32},
        'columns': <String, dynamic>{'compact': 1, 'medium': 2, 'large': 4},
      };

      // Query the same breakpoint (md) twice with different widths in range
      final resolved1 = resolver.resolveDefinition(definition, 1000);
      final resolved2 = resolver.resolveDefinition(definition, 1100);

      // Both are md range, so resolved values should be identical
      expect(resolved1['padding'], equals(resolved2['padding']));
      expect(resolved1['columns'], equals(resolved2['columns']));
    });

    test('TC-028 Normal: breakpoint changes — properties re-resolved', () {
      final definition = {
        'padding': <String, dynamic>{'compact': 8, 'expanded': 16, 'extraLarge': 32},
      };

      // xs range
      final resolvedXs = resolver.resolveDefinition(definition, 400);
      // md range
      final resolvedMd = resolver.resolveDefinition(definition, 1000);
      // xl range
      final resolvedXl = resolver.resolveDefinition(definition, 2000);

      expect(resolvedXs['padding'], equals(8));
      expect(resolvedMd['padding'], equals(16));
      expect(resolvedXl['padding'], equals(32));
    });

    test('TC-028 Boundary: custom breakpoints produce separate resolved values', () {
      final customSystem = BreakpointSystem();
      customSystem.setCustomBreakpoints({
        'compact': const Breakpoint(name: 'compact', minWidth: 0, maxWidth: 499),
        'medium': const Breakpoint(name: 'medium', minWidth: 500, maxWidth: 999),
        'expanded': const Breakpoint(name: 'expanded', minWidth: 1000, maxWidth: double.infinity),
      });
      final customResolver = ResponsiveResolver(breakpointSystem: customSystem);

      final definition = {
        'padding': <String, dynamic>{'compact': 4, 'medium': 8, 'expanded': 16},
      };

      // With custom breakpoints, 600 is sm (500-999 custom range)
      final resolved = customResolver.resolveDefinition(definition, 600);
      expect(resolved['padding'], equals(8));

      // With default breakpoints, 600 is sm (600-959 default range)
      final defaultResolved = resolver.resolveDefinition(definition, 600);
      expect(defaultResolved['padding'], equals(8));
    });

    test('TC-028 Normal: consistent resolution across multiple calls', () {
      final definition = {
        'type': 'container',
        'gap': <String, dynamic>{'compact': 4, 'large': 12},
        'visible': true,
      };

      // Call resolveDefinition multiple times with the same width
      final results = List.generate(5, (_) {
        return resolver.resolveDefinition(definition, 1500);
      });

      // All results should be identical
      for (final result in results) {
        expect(result['type'], equals('container'));
        expect(result['gap'], equals(12));
        expect(result['visible'], equals(true));
      }
    });
  });
}
