import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/responsive/breakpoint_system.dart';
import 'package:flutter_mcp_ui_runtime/src/responsive/responsive_resolver.dart';

void main() {
  late ResponsiveResolver resolver;

  setUp(() {
    resolver = ResponsiveResolver();
  });

  group('ResponsiveResolver — resolveDefinition', () {
    test('Normal: resolves responsive property in flat definition', () {
      final definition = {
        'type': 'container',
        'columns': <String, dynamic>{'compact': 12, 'expanded': 6, 'extraLarge': 3},
        'padding': 16,
      };

      final resolved = resolver.resolveDefinition(definition, 1000);
      expect(resolved['type'], equals('container'));
      expect(resolved['columns'], equals(6));
      expect(resolved['padding'], equals(16));
    });

    test('Normal: resolves nested responsive properties', () {
      final definition = {
        'type': 'container',
        'style': <String, dynamic>{
          'width': <String, dynamic>{'compact': 100, 'large': 400},
          'height': 200,
        },
      };

      final resolved = resolver.resolveDefinition(definition, 1500);
      final style = resolved['style'] as Map<String, dynamic>;
      expect(style['width'], equals(400));
      expect(style['height'], equals(200));
    });

    test('Normal: resolves responsive values inside lists', () {
      final definition = {
        'children': [
          <String, dynamic>{
            'type': 'text',
            'fontSize': <String, dynamic>{'compact': 12, 'large': 18},
          },
        ],
      };

      final resolved = resolver.resolveDefinition(definition, 1500);
      final children = resolved['children'] as List;
      final child = children[0] as Map<String, dynamic>;
      expect(child['fontSize'], equals(18));
    });

    test('Normal: non-responsive map with type key preserved as-is', () {
      final definition = {
        'child': <String, dynamic>{
          'type': 'text',
          'compact': 'This is content, not a breakpoint',
        },
      };

      final resolved = resolver.resolveDefinition(definition, 300);
      final child = resolved['child'] as Map<String, dynamic>;
      expect(child['type'], equals('text'));
      expect(child['compact'], equals('This is content, not a breakpoint'));
    });

    test('Boundary: null values pass through unchanged', () {
      final definition = <String, dynamic>{
        'type': 'container',
        'style': null,
      };

      final resolved = resolver.resolveDefinition(definition, 500);
      expect(resolved['style'], isNull);
    });

    test('Boundary: empty definition returns empty map', () {
      final resolved = resolver.resolveDefinition({}, 500);
      expect(resolved, isEmpty);
    });
  });

  // The `BuildContext` doors. Both resolvers offer one — a caller that has a
  // context and no width — and neither had been called, so the width they
  // read was nobody's knowledge. Reading the wrong dimension (height, or a
  // parent's box) picks the wrong breakpoint on every screen.
  group('resolving from a BuildContext', () {
    testWidgets('the resolver reads the window width', (tester) async {
      Map<String, dynamic>? resolved;

      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(size: Size(1000, 400)),
        child: Builder(builder: (context) {
          resolved = resolver.resolveDefinition(
            <String, dynamic>{
              'columns': <String, dynamic>{'compact': 12, 'expanded': 6},
            },
            MediaQuery.of(context).size.width,
          );
          final viaContext = resolver.resolveFromContext(
            <String, dynamic>{
              'columns': <String, dynamic>{'compact': 12, 'expanded': 6},
            },
            context,
          );
          expect(viaContext, resolved,
              reason: 'the convenience door has to answer exactly what the '
                  'explicit one does, or two call sites disagree about the '
                  'same screen');
          return const SizedBox();
        }),
      ));

      expect(resolved!['columns'], 6,
          reason: 'a thousand logical pixels is the expanded class — the '
              'width is read, not the height');
    });

    testWidgets('the breakpoint system reads it the same way', (tester) async {
      final system = BreakpointSystem();

      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(size: Size(500, 900)),
        child: Builder(builder: (context) {
          expect(
              system.resolveFromContext(
                  <String, dynamic>{'compact': 'phone', 'expanded': 'desktop'},
                  context),
              'phone',
              reason: 'a tall narrow window is compact; picking by height '
                  'would make every phone a desktop');
          return const SizedBox();
        }),
      ));
    });
  });

  group('ResponsiveResolver — _isResponsiveValue detection', () {
    test('Normal: map with breakpoint keys is responsive', () {
      final definition = {
        'gap': <String, dynamic>{'compact': 8, 'expanded': 16},
      };

      final resolved = resolver.resolveDefinition(definition, 1000);
      expect(resolved['gap'], equals(16));
    });

    test('Normal: map with type key is NOT responsive even with breakpoint keys', () {
      final definition = {
        'widget': <String, dynamic>{
          'type': 'text',
          'compact': 'small label',
          'expanded': 'medium label',
        },
      };

      final resolved = resolver.resolveDefinition(definition, 1000);
      final widget = resolved['widget'] as Map<String, dynamic>;
      expect(widget['type'], equals('text'));
      expect(widget.containsKey('compact'), isTrue);
    });

    test('Normal: map with no breakpoint keys is NOT responsive', () {
      final definition = {
        'config': <String, dynamic>{'key': 'value', 'count': 5},
      };

      final resolved = resolver.resolveDefinition(definition, 500);
      final config = resolved['config'] as Map<String, dynamic>;
      expect(config['key'], equals('value'));
      expect(config['count'], equals(5));
    });
  });

  group('ResponsiveResolver — custom BreakpointSystem', () {
    test('Normal: uses injected BreakpointSystem', () {
      final customSystem = BreakpointSystem();
      customSystem.setCustomBreakpoints({
        'mobile': const Breakpoint(
            name: 'mobile', minWidth: 0, maxWidth: 767),
        'desktop': const Breakpoint(
            name: 'desktop', minWidth: 768, maxWidth: double.infinity),
      });

      final customResolver =
          ResponsiveResolver(breakpointSystem: customSystem);

      // With custom breakpoints, 'compact'/'expanded' keys won't match
      // so the resolver should return the map as non-responsive
      final definition = {
        'columns': <String, dynamic>{'compact': 12, 'expanded': 6},
      };

      final resolved = customResolver.resolveDefinition(definition, 500);
      // 'compact' and 'expanded' are not known breakpoint keys in the custom system,
      // but _isResponsiveValue checks hardcoded {'compact','medium','expanded','large','extraLarge'}
      // so it will still detect and resolve (falling back in breakpointSystem)
      expect(resolved['columns'], isA<int>());
    });

    test('Normal: default BreakpointSystem used when none provided', () {
      final defaultResolver = ResponsiveResolver();
      final definition = {
        'size': <String, dynamic>{'compact': 'small', 'extraLarge': 'large'},
      };

      final resolved = defaultResolver.resolveDefinition(definition, 2000);
      expect(resolved['size'], equals('large'));
    });
  });

  // ===========================================================================
  // TC-001: ResponsiveResolver — initialization with default breakpoints
  // ===========================================================================
  group('TC-001: ResponsiveResolver — initialization with default breakpoints', () {
    test('Normal: initialize without custom breakpoints → default breakpoints active', () {
      final defaultResolver = ResponsiveResolver();
      final bps = defaultResolver.breakpointSystem.breakpoints;
      expect(bps.containsKey('compact'), isTrue);
      expect(bps.containsKey('medium'), isTrue);
      expect(bps.containsKey('expanded'), isTrue);
      expect(bps.containsKey('large'), isTrue);
      expect(bps.containsKey('extraLarge'), isTrue);
    });

    test('Normal: activeBreakpoint returns matching breakpoint for width', () {
      expect(resolver.breakpointSystem.getCurrentBreakpoint(400), equals('compact'));
      expect(resolver.breakpointSystem.getCurrentBreakpoint(700), equals('medium'));
      expect(resolver.breakpointSystem.getCurrentBreakpoint(1000), equals('expanded'));
    });

    test('Boundary: zero-size screen → xs breakpoint selected', () {
      expect(resolver.breakpointSystem.getCurrentBreakpoint(0), equals('compact'));
    });

    test('Error: double initialization → previous state replaced cleanly', () {
      final r = ResponsiveResolver();
      r.breakpointSystem.setCustomBreakpoints({
        'a': const Breakpoint(name: 'a', minWidth: 0, maxWidth: double.infinity),
      });
      // Replace with new custom breakpoints
      r.breakpointSystem.setCustomBreakpoints({
        'b': const Breakpoint(name: 'b', minWidth: 0, maxWidth: double.infinity),
      });
      expect(r.breakpointSystem.breakpoints.containsKey('a'), isFalse);
      expect(r.breakpointSystem.breakpoints.containsKey('b'), isTrue);
    });
  });

  // ===========================================================================
  // TC-002: ResponsiveResolver — initialization with custom breakpoints
  // ===========================================================================
  group('TC-002: ResponsiveResolver — initialization with custom breakpoints', () {
    test('Normal: custom breakpoints provided → replace defaults entirely', () {
      final customSystem = BreakpointSystem();
      customSystem.setCustomBreakpoints({
        'mobile': const Breakpoint(name: 'mobile', minWidth: 0, maxWidth: 767),
        'desktop': const Breakpoint(name: 'desktop', minWidth: 768, maxWidth: double.infinity),
      });
      final customResolver = ResponsiveResolver(breakpointSystem: customSystem);
      expect(customResolver.breakpointSystem.breakpoints.length, equals(2));
      expect(customResolver.breakpointSystem.breakpoints.containsKey('compact'), isFalse);
    });

    test('Boundary: single custom breakpoint using standard name → always active', () {
      final customSystem = BreakpointSystem();
      customSystem.setCustomBreakpoints({
        'compact': const Breakpoint(name: 'compact', minWidth: 0, maxWidth: double.infinity),
      });
      expect(customSystem.getCurrentBreakpoint(0), equals('compact'));
      expect(customSystem.getCurrentBreakpoint(5000), equals('compact'));
    });
  });

  // ===========================================================================
  // TC-003: ResponsiveResolver — resolveDefinition with varying widths
  // ===========================================================================
  group('TC-003: ResponsiveResolver — resolveDefinition with varying widths', () {
    test('Normal: width 800 → sm breakpoint resolution', () {
      final definition = {
        'padding': <String, dynamic>{'compact': 8, 'medium': 12, 'expanded': 16},
      };
      final resolved = resolver.resolveDefinition(definition, 800);
      expect(resolved['padding'], equals(12));
    });

    test('Normal: width 1400 → lg breakpoint resolution', () {
      final definition = {
        'columns': <String, dynamic>{'compact': 1, 'medium': 2, 'expanded': 3, 'large': 4},
      };
      final resolved = resolver.resolveDefinition(definition, 1400);
      expect(resolved['columns'], equals(4));
    });

    test('Boundary: width exactly 600 → sm breakpoint (minWidth inclusive)', () {
      final definition = {
        'layout': <String, dynamic>{'compact': 'stack', 'medium': 'grid'},
      };
      final resolved = resolver.resolveDefinition(definition, 600);
      expect(resolved['layout'], equals('grid'));
    });
  });

  // ===========================================================================
  // TC-005: ResponsiveResolver — resolveDefinition with mobile-first cascade
  // ===========================================================================
  group('TC-005: ResponsiveResolver — resolveDefinition with mobile-first cascade', () {
    test('Normal: width 1400 (lg), map has xs and md → resolved from md', () {
      final definition = {
        'gap': <String, dynamic>{'compact': 4, 'expanded': 12},
      };
      final resolved = resolver.resolveDefinition(definition, 1400);
      // lg has no match → falls back to md (nearest smaller defined)
      expect(resolved['gap'], equals(12));
    });

    test('Normal: width 1000 (md), map has xs and md → exact match md', () {
      final definition = {
        'padding': <String, dynamic>{'compact': 8, 'expanded': 16},
      };
      final resolved = resolver.resolveDefinition(definition, 1000);
      expect(resolved['padding'], equals(16));
    });

    test('Boundary: width 1920 (xl), map only has xs → inherits from xs', () {
      final definition = {
        'margin': <String, dynamic>{'compact': 4},
      };
      final resolved = resolver.resolveDefinition(definition, 1920);
      expect(resolved['margin'], equals(4));
    });

    test('Error: empty responsive map → returns empty map', () {
      final definition = {
        'data': <String, dynamic>{},
      };
      final resolved = resolver.resolveDefinition(definition, 1000);
      expect(resolved['data'], equals(<String, dynamic>{}));
    });
  });

  // ===========================================================================
  // TC-006: ResponsiveResolver — cascade merges properties
  // ===========================================================================
  group('TC-006: ResponsiveResolver — cascade merges properties', () {
    test('Normal: per-property responsive resolution', () {
      // Each property independently resolves its responsive value
      final definition = {
        'padding': <String, dynamic>{'compact': 8, 'expanded': 16},
        'direction': <String, dynamic>{'compact': 'vertical'},
      };
      // At width 1000 (md): padding → 16, direction → falls to xs → 'vertical'
      final resolved = resolver.resolveDefinition(definition, 1000);
      expect(resolved['padding'], equals(16));
      expect(resolved['direction'], equals('vertical'));
    });

    test('Boundary: all breakpoints define all properties → no cascade needed', () {
      final definition = {
        'size': <String, dynamic>{'compact': 'small', 'medium': 'medium', 'expanded': 'large'},
      };
      final resolved = resolver.resolveDefinition(definition, 700);
      expect(resolved['size'], equals('medium')); // Exact sm match
    });
  });

  // ===========================================================================
  // TC-026: Property merge across breakpoints
  // ===========================================================================
  group('TC-026: Property merge across breakpoints', () {
    test('Normal: independent properties at different breakpoints', () {
      final definition = {
        'padding': <String, dynamic>{'compact': 8, 'expanded': 16},
        'gap': <String, dynamic>{'compact': 4},
      };
      final resolved = resolver.resolveDefinition(definition, 1000);
      expect(resolved['padding'], equals(16));
      expect(resolved['gap'], equals(4));
    });

    test('Boundary: later breakpoint overrides same property', () {
      final definition = {
        'columns': <String, dynamic>{'compact': 1, 'medium': 2, 'expanded': 3},
      };
      final resolved = resolver.resolveDefinition(definition, 1000);
      expect(resolved['columns'], equals(3));
    });
  });

  // ===========================================================================
  // TC-034: ResponsiveResolver — resolveDefinition extended tests
  // ===========================================================================
  group('TC-034: ResponsiveResolver — resolveDefinition extended', () {
    test('TC-034 Normal: resolves full widget definition with responsive overrides', () {
      final definition = {
        'type': 'container',
        'padding': <String, dynamic>{'compact': 8, 'expanded': 16, 'extraLarge': 32},
        'columns': <String, dynamic>{'compact': 1, 'medium': 2, 'large': 4},
        'color': '#FFFFFF',
      };

      // Width 1000 is md
      final resolved = resolver.resolveDefinition(definition, 1000);
      expect(resolved['type'], equals('container'));
      expect(resolved['padding'], equals(16));
      // columns: md has no exact match, falls back to sm
      expect(resolved['columns'], equals(2));
      expect(resolved['color'], equals('#FFFFFF'));
    });

    test('TC-034 Normal: responsive properties at matching breakpoint merged onto base definition', () {
      final definition = {
        'type': 'text',
        'content': 'Hello',
        'fontSize': <String, dynamic>{'compact': 12, 'large': 24},
        'fontWeight': <String, dynamic>{'compact': 'normal', 'expanded': 'bold'},
      };

      // Width 1500 is lg
      final resolved = resolver.resolveDefinition(definition, 1500);
      expect(resolved['type'], equals('text'));
      expect(resolved['content'], equals('Hello'));
      expect(resolved['fontSize'], equals(24));
      // fontWeight: lg has no match, falls back to md
      expect(resolved['fontWeight'], equals('bold'));
    });

    test('TC-034 Boundary: definition with no responsive overrides returned unchanged', () {
      final definition = {
        'type': 'container',
        'padding': 16,
        'color': '#000000',
        'visible': true,
      };

      final resolved = resolver.resolveDefinition(definition, 500);
      expect(resolved['type'], equals('container'));
      expect(resolved['padding'], equals(16));
      expect(resolved['color'], equals('#000000'));
      expect(resolved['visible'], equals(true));
    });

    test('TC-034 Normal: multiple responsive properties resolved independently', () {
      final definition = {
        'width': <String, dynamic>{'compact': 100, 'expanded': 300, 'extraLarge': 600},
        'height': <String, dynamic>{'compact': 50, 'large': 200},
        'opacity': <String, dynamic>{'compact': 0.5, 'medium': 0.8, 'extraLarge': 1.0},
      };

      // Width 700 is sm
      final resolved = resolver.resolveDefinition(definition, 700);
      // width: sm has no match, falls back to xs
      expect(resolved['width'], equals(100));
      // height: sm has no match, falls back to xs
      expect(resolved['height'], equals(50));
      // opacity: exact sm match
      expect(resolved['opacity'], equals(0.8));
    });
  });

  group('ResponsiveResolver — deeply nested structures', () {
    test('Normal: three levels deep responsive resolution', () {
      final definition = {
        'type': 'linear',
        'direction': 'vertical',
        'children': [
          <String, dynamic>{
            'type': 'linear',
            'direction': 'horizontal',
            'children': [
              <String, dynamic>{
                'type': 'text',
                'fontSize': <String, dynamic>{'compact': 12, 'large': 24},
              },
            ],
          },
        ],
      };

      final resolved = resolver.resolveDefinition(definition, 1500);
      final children = resolved['children'] as List;
      final row = children[0] as Map<String, dynamic>;
      final rowChildren = row['children'] as List;
      final text = rowChildren[0] as Map<String, dynamic>;
      expect(text['fontSize'], equals(24));
    });
  });
}
