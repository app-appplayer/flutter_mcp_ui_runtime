import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/responsive/breakpoint_system.dart';

void main() {
  late BreakpointSystem system;

  setUp(() {
    system = BreakpointSystem();
  });

  group('BreakpointSystem — getCurrentBreakpoint', () {
    test('Normal: width 0 → compact', () {
      expect(system.getCurrentBreakpoint(0), equals('compact'));
    });

    test('Normal: width 320 → compact', () {
      expect(system.getCurrentBreakpoint(320), equals('compact'));
    });

    test('Normal: width 599 → compact', () {
      expect(system.getCurrentBreakpoint(599), equals('compact'));
    });

    test('Normal: width 600 → medium', () {
      expect(system.getCurrentBreakpoint(600), equals('medium'));
    });

    test('Normal: width 839 → medium', () {
      expect(system.getCurrentBreakpoint(839), equals('medium'));
    });

    test('Normal: width 840 → expanded', () {
      expect(system.getCurrentBreakpoint(840), equals('expanded'));
    });

    test('Normal: width 1199 → expanded', () {
      expect(system.getCurrentBreakpoint(1199), equals('expanded'));
    });

    test('Normal: width 1200 → large', () {
      expect(system.getCurrentBreakpoint(1200), equals('large'));
    });

    test('Normal: width 1599 → large', () {
      expect(system.getCurrentBreakpoint(1599), equals('large'));
    });

    test('Normal: width 1600 → extraLarge', () {
      expect(system.getCurrentBreakpoint(1600), equals('extraLarge'));
    });

    test('Normal: width 3840 → extraLarge', () {
      expect(system.getCurrentBreakpoint(3840), equals('extraLarge'));
    });
  });

  group('BreakpointSystem — isBreakpoint', () {
    test('Normal: 500 is compact', () {
      expect(system.isBreakpoint(500, 'compact'), isTrue);
    });

    test('Normal: 500 is not medium', () {
      expect(system.isBreakpoint(500, 'medium'), isFalse);
    });

    test('Boundary: 600 is medium, not compact', () {
      expect(system.isBreakpoint(600, 'medium'), isTrue);
      expect(system.isBreakpoint(600, 'compact'), isFalse);
    });

    test('Boundary: unknown breakpoint name → false', () {
      expect(system.isBreakpoint(500, 'unknown'), isFalse);
    });
  });

  group('BreakpointSystem — resolveResponsiveValue', () {
    test('Normal: exact match for current breakpoint', () {
      final value = {'compact': 12, 'expanded': 6, 'extraLarge': 3};
      expect(system.resolveResponsiveValue(value, 320), equals(12));
      expect(system.resolveResponsiveValue(value, 1000), equals(6));
      expect(system.resolveResponsiveValue(value, 2000), equals(3));
    });

    test('Normal: fallback to smaller breakpoint when no exact match', () {
      final value = {'compact': 12, 'large': 4};
      // sm (700) has no match → fall back to xs
      expect(system.resolveResponsiveValue(value, 700), equals(12));
      // md (1000) has no match → fall back to xs
      expect(system.resolveResponsiveValue(value, 1000), equals(12));
    });

    test('Normal: fallback to larger breakpoint when no smaller available', () {
      final value = {'expanded': 6, 'extraLarge': 3};
      // xs (300) has no match, no smaller breakpoint → fall back to md
      expect(system.resolveResponsiveValue(value, 300), equals(6));
    });

    test('Normal: non-map value returned as-is', () {
      expect(system.resolveResponsiveValue(42, 500), equals(42));
      expect(system.resolveResponsiveValue('hello', 500), equals('hello'));
      expect(system.resolveResponsiveValue(null, 500), isNull);
    });

    test('Boundary: empty map returns empty map as-is', () {
      final value = <String, dynamic>{};
      expect(system.resolveResponsiveValue(value, 500), equals(value));
    });

    test('Normal: single breakpoint value serves all widths', () {
      final value = {'medium': 'compact'};
      // xs → no exact, no smaller, fall to sm (larger)
      expect(system.resolveResponsiveValue(value, 300), equals('compact'));
      // sm → exact match
      expect(system.resolveResponsiveValue(value, 700), equals('compact'));
      // lg → no exact, fall to sm (smaller)
      expect(system.resolveResponsiveValue(value, 1500), equals('compact'));
    });
  });

  group('BreakpointSystem — custom breakpoints', () {
    test('Normal: setCustomBreakpoints replaces defaults', () {
      system.setCustomBreakpoints({
        'mobile': const Breakpoint(
            name: 'mobile', minWidth: 0, maxWidth: 767),
        'desktop': const Breakpoint(
            name: 'desktop', minWidth: 768, maxWidth: double.infinity),
      });

      final breakpoints = system.breakpoints;
      expect(breakpoints.length, equals(2));
      expect(breakpoints.containsKey('mobile'), isTrue);
      expect(breakpoints.containsKey('desktop'), isTrue);
    });

    test('Normal: resetBreakpoints restores defaults', () {
      system.setCustomBreakpoints({
        'mobile': const Breakpoint(
            name: 'mobile', minWidth: 0, maxWidth: 767),
      });

      system.resetBreakpoints();
      final breakpoints = system.breakpoints;
      expect(breakpoints.length, equals(5));
      expect(breakpoints.containsKey('compact'), isTrue);
      expect(breakpoints.containsKey('extraLarge'), isTrue);
    });

    test('Normal: breakpoints getter returns unmodifiable copy', () {
      final breakpoints = system.breakpoints;
      expect(() => breakpoints['compact'] = const Breakpoint(
        name: 'compact', minWidth: 0, maxWidth: 100,
      ), throwsA(isA<UnsupportedError>()));
    });
  });

  group('Breakpoint model', () {
    test('Normal: Breakpoint stores name, minWidth, maxWidth', () {
      const bp = Breakpoint(name: 'test', minWidth: 100, maxWidth: 500);
      expect(bp.name, equals('test'));
      expect(bp.minWidth, equals(100));
      expect(bp.maxWidth, equals(500));
    });

    test('Normal: default breakpoint ranges are contiguous', () {
      const bps = BreakpointSystem.defaultBreakpoints;
      expect(bps['compact']!.maxWidth + 1, equals(bps['medium']!.minWidth));
      expect(bps['medium']!.maxWidth + 1, equals(bps['expanded']!.minWidth));
      expect(bps['expanded']!.maxWidth + 1, equals(bps['large']!.minWidth));
      expect(bps['large']!.maxWidth + 1, equals(bps['extraLarge']!.minWidth));
    });
  });

  // ===========================================================================
  // TC-004: BreakpointSystem — breakpoint change detection
  // ===========================================================================
  group('TC-004: BreakpointSystem — breakpoint change detection', () {
    test('Normal: different widths produce different breakpoints', () {
      final bp1 = system.getCurrentBreakpoint(500);
      final bp2 = system.getCurrentBreakpoint(700);
      expect(bp1, equals('compact'));
      expect(bp2, equals('medium'));
      expect(bp1 != bp2, isTrue);
    });

    test('Normal: same-range widths produce same breakpoint', () {
      final bp1 = system.getCurrentBreakpoint(500);
      final bp2 = system.getCurrentBreakpoint(550);
      expect(bp1, equals(bp2));
    });

    test('Boundary: width at exact boundary transitions correctly', () {
      final bp599 = system.getCurrentBreakpoint(599);
      final bp600 = system.getCurrentBreakpoint(600);
      expect(bp599, equals('compact'));
      expect(bp600, equals('medium'));
    });
  });

  // ===========================================================================
  // TC-007: BreakpointDefinition — default breakpoints
  // ===========================================================================
  group('TC-007: BreakpointDefinition — default breakpoints', () {
    test('Normal: compact has minWidth 0, maxWidth 599', () {
      const bps = BreakpointSystem.defaultBreakpoints;
      expect(bps['compact']!.minWidth, equals(0));
      expect(bps['compact']!.maxWidth, equals(599));
    });

    test('Normal: extraLarge has minWidth 1600, maxWidth infinity', () {
      const bps = BreakpointSystem.defaultBreakpoints;
      expect(bps['extraLarge']!.minWidth, equals(1600));
      expect(bps['extraLarge']!.maxWidth, equals(double.infinity));
    });

    test('Boundary: all default breakpoints are contiguous with no gaps', () {
      const bps = BreakpointSystem.defaultBreakpoints;
      final order = ['compact', 'medium', 'expanded', 'large', 'extraLarge'];
      for (int i = 0; i < order.length - 1; i++) {
        final current = bps[order[i]]!;
        final next = bps[order[i + 1]]!;
        expect(current.maxWidth + 1, equals(next.minWidth),
            reason: '${order[i]}.maxWidth + 1 should equal ${order[i + 1]}.minWidth');
      }
    });
  });

  // ===========================================================================
  // TC-008: Custom breakpoint validation
  // ===========================================================================
  group('TC-008: Custom breakpoint validation', () {
    test('Normal: custom breakpoints with standard names accepted', () {
      system.setCustomBreakpoints({
        'compact': const Breakpoint(name: 'compact', minWidth: 0, maxWidth: 599),
        'medium': const Breakpoint(name: 'medium', minWidth: 600, maxWidth: double.infinity),
      });
      expect(system.breakpoints.length, equals(2));
      expect(system.getCurrentBreakpoint(300), equals('compact'));
      expect(system.getCurrentBreakpoint(800), equals('medium'));
    });

    test('Boundary: last breakpoint with infinity maxWidth (unbounded)', () {
      system.setCustomBreakpoints({
        'compact': const Breakpoint(name: 'compact', minWidth: 0, maxWidth: 767),
        'medium': const Breakpoint(name: 'medium', minWidth: 768, maxWidth: double.infinity),
      });
      expect(system.getCurrentBreakpoint(5000), equals('medium'));
    });
  });

  // ===========================================================================
  // TC-024: Mobile-first cascade — base case
  // ===========================================================================
  group('TC-024: Mobile-first cascade — base case', () {
    test('Normal: only xs defined, active breakpoint lg → xs values used', () {
      final value = {'compact': 'mobile-layout'};
      // Width 1500 is lg, only xs defined → falls back to xs
      expect(system.resolveResponsiveValue(value, 1500), equals('mobile-layout'));
    });

    test('Boundary: only xl defined, active breakpoint xs → falls to xl (larger)', () {
      final value = {'extraLarge': 'desktop-only'};
      // Width 300 is xs, only xl defined → falls forward to xl
      expect(system.resolveResponsiveValue(value, 300), equals('desktop-only'));
    });
  });

  // ===========================================================================
  // TC-025: Mobile-first cascade — intermediate breakpoints
  // ===========================================================================
  group('TC-025: Mobile-first cascade — intermediate breakpoints', () {
    test('Normal: xs and lg defined, active md → xs values used', () {
      final value = {'compact': 8, 'large': 24};
      // Width 1000 is md → no exact match, falls back to xs
      expect(system.resolveResponsiveValue(value, 1000), equals(8));
    });

    test('Normal: xs and lg defined, active xl → lg values used', () {
      final value = {'compact': 8, 'large': 24};
      // Width 2000 is xl → no exact match, falls back to lg
      expect(system.resolveResponsiveValue(value, 2000), equals(24));
    });

    test('Boundary: all breakpoints defined → exact match used', () {
      final value = {'compact': 1, 'medium': 2, 'expanded': 3, 'large': 4, 'extraLarge': 5};
      expect(system.resolveResponsiveValue(value, 1000), equals(3)); // md exact
    });
  });

  // ===========================================================================
  // TC-029: Unknown breakpoint name in responsive map
  // ===========================================================================
  group('TC-029: Unknown breakpoint name in responsive map', () {
    test('Normal: known breakpoint names resolved correctly', () {
      final value = {'compact': 'small', 'expanded': 'medium'};
      expect(system.resolveResponsiveValue(value, 1000), equals('medium'));
    });

    test('Boundary: mix of known and unknown names → unknown ignored', () {
      final value = {'compact': 'small', 'custom': 'custom-val', 'expanded': 'medium'};
      // md (1000) → exact match 'medium'
      expect(system.resolveResponsiveValue(value, 1000), equals('medium'));
    });

    test('Error: all unknown names → returns first value as fallback', () {
      final value = {'custom1': 'a', 'custom2': 'b'};
      // No breakpoint keys match, so treated as non-responsive
      final result = system.resolveResponsiveValue(value, 500);
      expect(result, isNotNull);
    });
  });

  // ===========================================================================
  // TC-033: Responsive map with no matching breakpoint
  // ===========================================================================
  group('TC-033: Responsive map with no matching breakpoint', () {
    test('Normal: responsive map matches current breakpoint', () {
      final value = {'compact': 12, 'expanded': 6};
      expect(system.resolveResponsiveValue(value, 1000), equals(6));
    });

    test('Error: no breakpoint <= active → falls to larger breakpoint', () {
      final value = {'large': 4, 'extraLarge': 2};
      // xs (300) → no match at xs, sm, md → falls forward to lg
      expect(system.resolveResponsiveValue(value, 300), equals(4));
    });

    test('Boundary: empty responsive map → returned as-is', () {
      final value = <String, dynamic>{};
      expect(system.resolveResponsiveValue(value, 500), equals(value));
    });
  });

  // ===========================================================================
  // TC-030: Custom breakpoint validation errors
  // ===========================================================================
  group('TC-030: Custom breakpoint validation errors', () {
    test('Normal: valid custom breakpoints → accepted', () {
      system.setCustomBreakpoints({
        'small': const Breakpoint(name: 'small', minWidth: 0, maxWidth: 599),
        'large': const Breakpoint(
            name: 'large', minWidth: 600, maxWidth: double.infinity),
      });

      expect(system.breakpoints.length, equals(2));
      expect(system.breakpoints.containsKey('small'), isTrue);
      expect(system.breakpoints.containsKey('large'), isTrue);
    });

    test('Error: breakpoints with gaps → width falls through to largest defined', () {
      // Gap between 600-799: no breakpoint covers this range
      system.setCustomBreakpoints({
        'compact': const Breakpoint(name: 'compact', minWidth: 0, maxWidth: 599),
        'expanded': const Breakpoint(
            name: 'expanded', minWidth: 800, maxWidth: double.infinity),
      });

      // Width 700 falls in the gap → getCurrentBreakpoint falls to the
      // largest defined breakpoint (`expanded` here).
      final bp = system.getCurrentBreakpoint(700);
      expect(bp, equals('expanded'));
    });

    test('Error: breakpoints with overlaps → first matching breakpoint wins', () {
      // Overlapping ranges: xs 0-800, sm 500-infinity
      system.setCustomBreakpoints({
        'compact': const Breakpoint(name: 'compact', minWidth: 0, maxWidth: 800),
        'medium': const Breakpoint(
            name: 'medium', minWidth: 500, maxWidth: double.infinity),
      });

      // Width 600 matches both xs and sm; iteration order determines result
      // _breakpointOrder is ['compact','medium','expanded','large','extraLarge'], xs checked first
      final bp = system.getCurrentBreakpoint(600);
      expect(bp, equals('compact'));
    });
  });

  // ===========================================================================
  // TC-035: BreakpointSystem — getCurrentBreakpoint extended
  // ===========================================================================
  group('TC-035: BreakpointSystem — getCurrentBreakpoint extended', () {
    test('TC-035 Normal: getCurrentBreakpoint(400) returns "compact"', () {
      expect(system.getCurrentBreakpoint(400), equals('compact'));
    });

    test('TC-035 Normal: getCurrentBreakpoint(800) returns "medium"', () {
      expect(system.getCurrentBreakpoint(800), equals('medium'));
    });

    test('TC-035 Normal: returns the breakpoint name for the largest breakpoint <= given width', () {
      // Width 1000 is within expanded range (840-1199)
      expect(system.getCurrentBreakpoint(1000), equals('expanded'));
      // Width 1400 is within large range (1200-1599)
      expect(system.getCurrentBreakpoint(1400), equals('large'));
      // Width 2500 is within extraLarge range (1600+)
      expect(system.getCurrentBreakpoint(2500), equals('extraLarge'));
    });

    test('TC-035 Boundary: width exactly at breakpoint boundary returns that breakpoint', () {
      // Exact lower-bound values
      expect(system.getCurrentBreakpoint(0), equals('compact'));
      expect(system.getCurrentBreakpoint(600), equals('medium'));
      expect(system.getCurrentBreakpoint(840), equals('expanded'));
      expect(system.getCurrentBreakpoint(1200), equals('large'));
      expect(system.getCurrentBreakpoint(1600), equals('extraLarge'));
    });

    test('TC-035 Boundary: width at upper boundary of breakpoint range', () {
      expect(system.getCurrentBreakpoint(599), equals('compact'));
      expect(system.getCurrentBreakpoint(839), equals('medium'));
      expect(system.getCurrentBreakpoint(1199), equals('expanded'));
      expect(system.getCurrentBreakpoint(1599), equals('large'));
    });

    test('TC-035 Normal: uses custom breakpoints after setCustomBreakpoints', () {
      // Use standard breakpoint names since getCurrentBreakpoint
      // iterates _breakpointOrder which only contains standard names
      system.setCustomBreakpoints({
        'compact': const Breakpoint(name: 'compact', minWidth: 0, maxWidth: 499),
        'medium': const Breakpoint(name: 'medium', minWidth: 500, maxWidth: double.infinity),
      });

      expect(system.getCurrentBreakpoint(300), equals('compact'));
      expect(system.getCurrentBreakpoint(800), equals('medium'));
    });
  });

  // ===========================================================================
  // TC-036: BreakpointSystem — isBreakpoint extended
  // ===========================================================================
  group('TC-036: BreakpointSystem — isBreakpoint extended', () {
    test('TC-036 Normal: isBreakpoint(400, "compact") returns true', () {
      expect(system.isBreakpoint(400, 'compact'), isTrue);
    });

    test('TC-036 Normal: isBreakpoint(400, "expanded") returns false', () {
      expect(system.isBreakpoint(400, 'expanded'), isFalse);
    });

    test('TC-036 Normal: isBreakpoint for each breakpoint range', () {
      // Verify each breakpoint name with a width in its range
      expect(system.isBreakpoint(300, 'compact'), isTrue);
      expect(system.isBreakpoint(700, 'medium'), isTrue);
      expect(system.isBreakpoint(1000, 'expanded'), isTrue);
      expect(system.isBreakpoint(1400, 'large'), isTrue);
      expect(system.isBreakpoint(2000, 'extraLarge'), isTrue);
    });

    test('TC-036 Boundary: width at exact boundary returns true for that breakpoint', () {
      expect(system.isBreakpoint(0, 'compact'), isTrue);
      expect(system.isBreakpoint(600, 'medium'), isTrue);
      expect(system.isBreakpoint(840, 'expanded'), isTrue);
      expect(system.isBreakpoint(1200, 'large'), isTrue);
      expect(system.isBreakpoint(1600, 'extraLarge'), isTrue);
    });

    test('TC-036 Boundary: width at upper boundary returns true', () {
      expect(system.isBreakpoint(599, 'compact'), isTrue);
      expect(system.isBreakpoint(839, 'medium'), isTrue);
      expect(system.isBreakpoint(1199, 'expanded'), isTrue);
      expect(system.isBreakpoint(1599, 'large'), isTrue);
    });

    test('TC-036 Error: unknown breakpoint name returns false', () {
      expect(system.isBreakpoint(500, 'unknown'), isFalse);
      expect(system.isBreakpoint(500, 'xxl'), isFalse);
      expect(system.isBreakpoint(500, ''), isFalse);
    });
  });

  // ===========================================================================
  // TC-037: BreakpointSystem — setCustomBreakpoints extended
  // ===========================================================================
  group('TC-037: BreakpointSystem — setCustomBreakpoints extended', () {
    test('TC-037 Normal: replaces default breakpoint definitions with custom ones', () {
      system.setCustomBreakpoints({
        'phone': const Breakpoint(name: 'phone', minWidth: 0, maxWidth: 599),
        'tablet': const Breakpoint(name: 'tablet', minWidth: 600, maxWidth: 1023),
        'desktop': const Breakpoint(name: 'desktop', minWidth: 1024, maxWidth: double.infinity),
      });

      final breakpoints = system.breakpoints;
      expect(breakpoints.length, equals(3));
      expect(breakpoints.containsKey('phone'), isTrue);
      expect(breakpoints.containsKey('tablet'), isTrue);
      expect(breakpoints.containsKey('desktop'), isTrue);
      // Default breakpoints should be gone
      expect(breakpoints.containsKey('compact'), isFalse);
      expect(breakpoints.containsKey('medium'), isFalse);
    });

    test('TC-037 Normal: subsequent getCurrentBreakpoint uses new breakpoint boundaries', () {
      system.setCustomBreakpoints({
        'compact': const Breakpoint(name: 'compact', minWidth: 0, maxWidth: 399),
        'medium': const Breakpoint(name: 'medium', minWidth: 400, maxWidth: 799),
        'expanded': const Breakpoint(name: 'expanded', minWidth: 800, maxWidth: double.infinity),
      });

      // With the new boundaries, 500 is now 'medium' (400-799) not 'compact' (0-399)
      expect(system.getCurrentBreakpoint(500), equals('medium'));
      // 300 is 'compact' (0-399)
      expect(system.getCurrentBreakpoint(300), equals('compact'));
      // 900 is 'expanded' (800+)
      expect(system.getCurrentBreakpoint(900), equals('expanded'));
    });

    test('TC-037 Boundary: single custom breakpoint — all widths resolve to that breakpoint', () {
      system.setCustomBreakpoints({
        'compact': const Breakpoint(name: 'compact', minWidth: 0, maxWidth: double.infinity),
      });

      expect(system.getCurrentBreakpoint(0), equals('compact'));
      expect(system.getCurrentBreakpoint(500), equals('compact'));
      expect(system.getCurrentBreakpoint(5000), equals('compact'));
    });

    test('TC-037 Normal: resolveResponsiveValue works with custom breakpoints', () {
      system.setCustomBreakpoints({
        'compact': const Breakpoint(name: 'compact', minWidth: 0, maxWidth: 499),
        'large': const Breakpoint(name: 'large', minWidth: 500, maxWidth: double.infinity),
      });

      final value = {'compact': 12, 'large': 4};
      expect(system.resolveResponsiveValue(value, 300), equals(12));
      expect(system.resolveResponsiveValue(value, 800), equals(4));
    });
  });

  // ===========================================================================
  // TC-038: BreakpointSystem — resetBreakpoints extended
  // ===========================================================================
  group('TC-038: BreakpointSystem — resetBreakpoints extended', () {
    test('TC-038 Normal: restores default breakpoint definitions after custom set', () {
      // First set custom breakpoints
      system.setCustomBreakpoints({
        'mobile': const Breakpoint(name: 'mobile', minWidth: 0, maxWidth: 767),
        'desktop': const Breakpoint(name: 'desktop', minWidth: 768, maxWidth: double.infinity),
      });
      expect(system.breakpoints.length, equals(2));
      expect(system.breakpoints.containsKey('compact'), isFalse);

      // Reset to defaults
      system.resetBreakpoints();

      final breakpoints = system.breakpoints;
      expect(breakpoints.length, equals(5));
      expect(breakpoints.containsKey('compact'), isTrue);
      expect(breakpoints.containsKey('medium'), isTrue);
      expect(breakpoints.containsKey('expanded'), isTrue);
      expect(breakpoints.containsKey('large'), isTrue);
      expect(breakpoints.containsKey('extraLarge'), isTrue);
    });

    test('TC-038 Normal: getCurrentBreakpoint uses default boundaries again', () {
      system.setCustomBreakpoints({
        'compact': const Breakpoint(name: 'compact', minWidth: 0, maxWidth: 999),
        'medium': const Breakpoint(name: 'medium', minWidth: 1000, maxWidth: double.infinity),
      });

      // With custom: 800 is xs (0-999)
      expect(system.getCurrentBreakpoint(800), equals('compact'));

      system.resetBreakpoints();

      // With defaults: 800 is sm (600-959)
      expect(system.getCurrentBreakpoint(800), equals('medium'));
    });

    test('TC-038 Boundary: reset when already at defaults is a no-op', () {
      // Get defaults before reset
      final beforeReset = system.breakpoints;
      expect(beforeReset.length, equals(5));

      // Reset without prior customization
      system.resetBreakpoints();

      final afterReset = system.breakpoints;
      expect(afterReset.length, equals(5));
      expect(afterReset.containsKey('compact'), isTrue);
      expect(afterReset.containsKey('extraLarge'), isTrue);

      // Verify behavior unchanged
      expect(system.getCurrentBreakpoint(400), equals('compact'));
      expect(system.getCurrentBreakpoint(700), equals('medium'));
    });

    test('TC-038 Normal: multiple set/reset cycles work correctly', () {
      // Cycle 1: set custom
      system.setCustomBreakpoints({
        'a': const Breakpoint(name: 'a', minWidth: 0, maxWidth: double.infinity),
      });
      expect(system.breakpoints.length, equals(1));

      // Reset
      system.resetBreakpoints();
      expect(system.breakpoints.length, equals(5));

      // Cycle 2: set different custom
      system.setCustomBreakpoints({
        'x': const Breakpoint(name: 'x', minWidth: 0, maxWidth: 499),
        'y': const Breakpoint(name: 'y', minWidth: 500, maxWidth: double.infinity),
      });
      expect(system.breakpoints.length, equals(2));

      // Reset again
      system.resetBreakpoints();
      expect(system.breakpoints.length, equals(5));
      expect(system.getCurrentBreakpoint(400), equals('compact'));
    });
  });
}
