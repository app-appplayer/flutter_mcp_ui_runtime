// `McpUiThemeBuilder` — the parts of a declared theme that reach Flutter's
// `ThemeData`: typography weights, per-corner shapes, and 8-digit colours.
//
// A weight the builder drops is a heading that renders at regular; a corner
// object it flattens is a card with four identical corners where the document
// asked for two. Both look like design mistakes rather than dropped input.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ThemeManager manager;

  setUp(() => manager = ThemeManager.instance..reset());
  tearDown(() => ThemeManager.instance.reset());

  ThemeData buildWith(Map<String, dynamic> theme) {
    manager.setTheme(theme);
    return manager.toFlutterTheme();
  }

  group('typography', () {
    TextStyle? styleWith(Map<String, dynamic> declared) => buildWith(
          <String, dynamic>{
            'typography': <String, dynamic>{'bodyLarge': declared},
          },
        ).textTheme.bodyLarge;

    test('every named weight reaches the text theme', () {
      const names = <String, FontWeight>{
        'thin': FontWeight.w100,
        'extraLight': FontWeight.w200,
        'light': FontWeight.w300,
        'regular': FontWeight.w400,
        'normal': FontWeight.w400,
        'medium': FontWeight.w500,
        'semiBold': FontWeight.w600,
        'bold': FontWeight.w700,
        'extraBold': FontWeight.w800,
        'black': FontWeight.w900,
      };

      names.forEach((name, weight) {
        expect(styleWith(<String, dynamic>{'fontWeight': name})?.fontWeight,
            weight,
            reason: name);
      });
    });

    test('the numeric spellings reach it too, as strings and as numbers', () {
      for (final step in const [100, 200, 300, 400, 500, 600, 700, 800, 900]) {
        final expected = FontWeight.values.firstWhere((w) => w.value == step);
        expect(styleWith(<String, dynamic>{'fontWeight': '$step'})?.fontWeight,
            expected,
            reason: '"$step"');
        expect(styleWith(<String, dynamic>{'fontWeight': step})?.fontWeight,
            expected,
            reason: '$step');
      }
    });

    test('a number between the steps takes the nearest one', () {
      expect(styleWith(<String, dynamic>{'fontWeight': 640})?.fontWeight,
          FontWeight.w600);
      expect(styleWith(<String, dynamic>{'fontWeight': 660})?.fontWeight,
          FontWeight.w700);
      expect(styleWith(<String, dynamic>{'fontWeight': 5000})?.fontWeight,
          FontWeight.w900,
          reason: 'clamping beats asserting: a nonsense weight is a typo, not '
              'a reason to fail the whole theme');
    });

    test('an unknown name leaves the weight undeclared', () {
      expect(styleWith(<String, dynamic>{'fontWeight': 'heavy'})?.fontWeight,
          isNull);
    });

    test('a font family may be one name or a fallback list', () {
      expect(
          styleWith(<String, dynamic>{'fontFamily': 'Inter'})?.fontFamily,
          'Inter');

      final withFallbacks = styleWith(<String, dynamic>{
        'fontFamily': <dynamic>['Inter', 'Noto Sans KR'],
      });
      expect(withFallbacks?.fontFamilyFallback, ['Inter', 'Noto Sans KR'],
          reason: 'a list is how a multilingual document names the face for '
              'each script; taking only the first drops the rest');
    });

    test('line height is converted to a multiplier', () {
      final style = styleWith(<String, dynamic>{
        'fontSize': 16,
        'lineHeight': 24,
        'letterSpacing': 0.4,
      });

      expect(style?.height, 1.5);
      expect(style?.letterSpacing, 0.4);
    });

    test('a line height with no size cannot be converted, so it is dropped',
        () {
      expect(styleWith(<String, dynamic>{'lineHeight': 24})?.height, isNull,
          reason: 'passing pixels where Flutter wants a multiplier would set '
              'a 24× line height');
    });
  });

  group('shape', () {
    test('a per-corner shape keeps all four radii', () {
      final theme = buildWith(<String, dynamic>{
        'shape': <String, dynamic>{
          'medium': <String, dynamic>{
            'topStart': 16,
            'topEnd': 8,
            'bottomStart': 4,
            'bottomEnd': 0,
          },
        },
      });

      final shape = theme.cardTheme.shape;
      expect(shape, isA<RoundedRectangleBorder>());
      expect((shape! as RoundedRectangleBorder).borderRadius,
          const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(8),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.zero,
          ),
          reason: 'a corner object flattened to one radius gives four '
              'identical corners where the document asked for two');
    });

    test('a uniform radius applies to every corner', () {
      final theme = buildWith(<String, dynamic>{
        'shape': <String, dynamic>{'medium': 12},
      });

      expect((theme.cardTheme.shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(12));
    });
  });

  group('colour literals', () {
    test('six and eight digit hex are both read', () {
      final opaque = buildWith(<String, dynamic>{
        'color': <String, dynamic>{'primary': '#FF0000'},
      });
      expect(opaque.colorScheme.primary, const Color(0xFFFF0000));

      final translucent = buildWith(<String, dynamic>{
        'color': <String, dynamic>{'primary': '#80FF0000'},
      });
      expect(translucent.colorScheme.primary, const Color(0x80FF0000),
          reason: 'the alpha-first form is what a design token file emits; '
              'reading only six digits makes every declared alpha opaque');
    });

    test('a value that is not a hex colour leaves the slot derived', () {
      final theme = buildWith(<String, dynamic>{
        'color': <String, dynamic>{'primary': 'not a colour'},
      });

      expect(theme.colorScheme.primary, isNotNull,
          reason: 'one bad token must not take the palette down with it');
    });
  });
}
