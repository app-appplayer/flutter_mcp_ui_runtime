// `ThemeManager` — the typed accessors and the spec aliases.
//
// A document reads `theme.typography.bodyLarge.fontWeight` and expects the
// text to come out at that weight. The parser behind it accepts a name, a
// numeric string and a number, and a spelling it silently drops is a heading
// that renders at regular weight with nothing said.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ThemeManager theme;

  setUp(() {
    theme = ThemeManager.instance..reset();
  });

  tearDown(() => ThemeManager.instance.reset());

  group('font weight', () {
    FontWeight? weightOf(dynamic declared) {
      theme.setTheme(<String, dynamic>{
        'typography': <String, dynamic>{
          'bodyLarge': <String, dynamic>{
            'fontSize': 16,
            'fontWeight': declared,
          },
        },
      });
      return theme.getTextStyleValue('bodyLarge')?.fontWeight;
    }

    test('every declared name is honoured', () {
      expect(weightOf('thin'), FontWeight.w100);
      expect(weightOf('extraLight'), FontWeight.w200);
      expect(weightOf('light'), FontWeight.w300);
      expect(weightOf('regular'), FontWeight.w400);
      expect(weightOf('normal'), FontWeight.w400);
      expect(weightOf('medium'), FontWeight.w500);
      expect(weightOf('semiBold'), FontWeight.w600);
      expect(weightOf('bold'), FontWeight.w700);
      expect(weightOf('extraBold'), FontWeight.w800);
      expect(weightOf('black'), FontWeight.w900);
    });

    test('the numeric spellings are honoured as strings and as numbers', () {
      for (final step in const [100, 200, 300, 400, 500, 600, 700, 800, 900]) {
        expect(weightOf('$step'), FontWeight.values.firstWhere(
            (w) => w.value == step),
            reason: 'CSS-style weights are what a designer hands over');
        expect(weightOf(step), FontWeight.values.firstWhere(
            (w) => w.value == step));
      }
    });

    test('a number between steps rounds down to a real weight', () {
      expect(weightOf(550), FontWeight.w500);
      expect(weightOf(50), FontWeight.w100,
          reason: 'below the lightest is the lightest, not an assertion');
      expect(weightOf(1200), FontWeight.w900);
    });

    test('an unknown spelling leaves the weight undeclared', () {
      expect(weightOf('heavy'), isNull);
      expect(weightOf(true), isNull);
    });

    test('line height is expressed as a multiple of the size', () {
      theme.setTheme(<String, dynamic>{
        'typography': <String, dynamic>{
          'bodyLarge': <String, dynamic>{
            'fontSize': 16,
            'lineHeight': 24,
            'letterSpacing': 0.5,
          },
        },
      });

      final style = theme.getTextStyleValue('bodyLarge')!;
      expect(style.height, 1.5,
          reason: 'Flutter takes a multiplier and the spec declares pixels; '
              'passing the pixels through would set a 24× line height');
      expect(style.letterSpacing, 0.5);
      expect(style.fontSize, 16);
    });

    test('a role that is not declared has no style', () {
      expect(theme.getTextStyleValue('displayHuge'), isNull);
      expect(theme.getTextStyle('displayHuge'), isNull);
    });
  });

  group('font weight from a number', () {
    test('a value between the steps lands on a real weight', () {
      theme.setTheme(<String, dynamic>{
        'typography': <String, dynamic>{
          'bodyLarge': <String, dynamic>{'fontSize': 16, 'fontWeight': 1400},
        },
      });

      expect(theme.getTextStyleValue('bodyLarge')?.fontWeight,
          FontWeight.w900,
          reason: 'above the heaviest is the heaviest — a number Flutter has '
              'no weight for must not throw out of a text style');
    });
  });

  group('shape tokens', () {
    test('a plain radius answers; a per-corner one has no single value', () {
      theme.setTheme(<String, dynamic>{
        'shape': <String, dynamic>{
          'small': 4,
          // §5.4 — the per-corner form. It is not a single radius, so the
          // scalar accessor has nothing to answer with.
          'large': <String, dynamic>{'topStart': 16, 'bottomEnd': 4},
        },
      });

      expect(theme.getShape('small'), 4);
      expect(theme.getShapeValue('small'), 4.0);
      expect(theme.getShape('large'), isNull,
          reason: 'a per-corner shape has four radii; answering with one of '
              'them would round the other three off silently');
      expect(theme.getShape('missing'), isNull);
    });
  });

  group('spacing tokens', () {
    test('a declared step answers, an undeclared one does not', () {
      theme.setTheme(<String, dynamic>{
        'spacing': <String, dynamic>{'md': 16},
      });

      expect(theme.getSpacing('md'), 16);
      expect(theme.getSpacingValue('md'), 16.0);
      expect(theme.getSpacing('nope'), isNull);
    });
  });

  group('the spec aliases', () {
    test('`currentMode`, `setMode` and `resolveThemeValue` are the same '
        'operations under their spec names', () {
      theme.setTheme(<String, dynamic>{
        'spacing': <String, dynamic>{'md': 16},
      });

      expect(theme.currentMode, theme.themeMode);

      theme.setMode('dark');
      expect(theme.themeMode, 'dark');
      expect(theme.currentMode, 'dark');
      expect(theme.effectiveMode, 'dark');

      expect(theme.resolveThemeValue('spacing.md'), 16,
          reason: 'a document written to the spec names must reach the same '
              'values as one written to the implementation names');
    });

    test('`toFlutterThemeData` builds the same theme as `toFlutterTheme`', () {
      final viaAlias = theme.toFlutterThemeData(isDark: true);
      final direct = theme.toFlutterTheme(isDark: true);

      expect(viaAlias.colorScheme.brightness, Brightness.dark);
      expect(viaAlias.colorScheme.primary, direct.colorScheme.primary);
    });

    test('an unknown mode is refused by name', () {
      expect(() => theme.setMode('sepia'), throwsArgumentError,
          reason: 'silently keeping the old mode would leave an author '
              'looking for a typo in the wrong place');
      expect(theme.themeMode, isNot('sepia'));
    });
  });

  group('the active definition', () {
    test('is the one that was set, and reset puts the default back', () {
      final before = theme.definition;

      theme.setTheme(<String, dynamic>{
        'color': <String, dynamic>{'primary': '#FF0000'},
      });
      expect(theme.getColorValue('primary'), const Color(0xFFFF0000));

      theme.resetTheme();
      expect(theme.getColorValue('primary'), isNot(const Color(0xFFFF0000)));
      expect(theme.definition.runtimeType, before.runtimeType);
    });

    // Which slots can answer null is the whole reason every caller of
    // `getColorValue` writes `?? someColor`. Those fallbacks look like dead
    // defensive code — a standard slot always resolves through the derived
    // scheme — and they are not: the moment a widget reads a SEMANTIC slot,
    // null is the documented answer, and the `??` beside it is the only thing
    // between the document and a null-check crash.
    test('a standard slot always resolves; a semantic one does not', () {
      theme.resetTheme();

      for (final slot in const [
        'primary',
        'surface',
        'surfaceContainer',
        'outlineVariant',
        'onSurface',
        'secondaryContainer',
        'onSurfaceVariant',
      ]) {
        expect(theme.getColorValue(slot), isNotNull,
            reason: '$slot is an M3 role, so it derives from the scheme even '
                'when the bundle never declares it');
      }

      for (final slot in const ['success', 'warning', 'info', 'onSuccess']) {
        expect(theme.getColorValue(slot), isNull,
            reason: '$slot is not part of ColorScheme, so §5.3 puts it on the '
                'bundle to declare — a caller that assumes non-null here '
                'crashes on the first document that leaves it out');
      }
    });

    test('colorOr answers the slot when there is one, the fallback when not',
        () {
      theme.resetTheme();

      expect(theme.colorOr('primary', const Color(0xFF000001)),
          theme.getColorValue('primary'),
          reason: 'a standard role resolves, so the fallback is not what the '
              'widget paints with');
      expect(theme.colorOr('success', const Color(0xFF000002)),
          const Color(0xFF000002),
          reason: 'and a semantic slot the bundle never declared is exactly '
              'the case the fallback exists for — this is the branch that '
              'was written seventeen times and run zero');
      expect(theme.colorOr('notASlotAtAll', const Color(0xFF000003)),
          const Color(0xFF000003));
    });

    test('a declared semantic slot resolves like any other', () {
      theme.setTheme(<String, dynamic>{
        'color': <String, dynamic>{'success': '#FF00FF00'},
      });

      expect(theme.getColorValue('success'), const Color(0xFF00FF00));
    });

    test('a dark build with no dark section derives from the default dark', () {
      final dark = theme.toFlutterTheme(isDark: true);
      final light = theme.toFlutterTheme(isDark: false);

      expect(dark.colorScheme.brightness, Brightness.dark);
      expect(light.colorScheme.brightness, Brightness.light);
      expect(dark.colorScheme.surface, isNot(light.colorScheme.surface),
          reason: 'a dark theme that reuses the light surfaces is a light '
              'theme with dark text on it');
    });
  });
}
