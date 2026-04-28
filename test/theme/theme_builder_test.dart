// MCP UI DSL 1.3 — McpUiThemeBuilder contract test.
// Verifies that ThemeDefinition → Flutter ThemeData mapping covers M3
// 28-role color, M3 15-role typography, density, and shape.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_builder.dart';

void main() {
  group('McpUiThemeBuilder — M3 mapping', () {
    test('seed-only ColorScheme drives M3 fromSeed', () {
      final def = ThemeDefinition(
        color: const ColorSchemeDefinition(seed: '#3F51B5'),
      );
      final light = McpUiThemeBuilder.build(def, isDark: false);
      final dark = McpUiThemeBuilder.build(def, isDark: true);

      expect(light.useMaterial3, isTrue);
      expect(light.brightness, equals(Brightness.light));
      expect(dark.brightness, equals(Brightness.dark));
      // Seed should produce different surfaces between light/dark.
      expect(light.colorScheme.surface, isNot(equals(dark.colorScheme.surface)));
    });

    test('explicit 28-role color overrides land on Flutter ColorScheme', () {
      final def = ThemeDefinition(
        color: const ColorSchemeDefinition(
          primary: '#FF0000',
          onPrimary: '#FFFFFF',
          surface: '#00FF00',
          onSurface: '#000000',
          surfaceContainerHigh: '#E8E8E8',
          onSurfaceVariant: '#444444',
          inverseSurface: '#222222',
          onInverseSurface: '#EEEEEE',
        ),
      );
      final theme = McpUiThemeBuilder.build(def, isDark: false);

      expect(theme.colorScheme.primary, const Color(0xFFFF0000));
      expect(theme.colorScheme.onPrimary, const Color(0xFFFFFFFF));
      expect(theme.colorScheme.surface, const Color(0xFF00FF00));
      expect(theme.colorScheme.onSurface, const Color(0xFF000000));
      expect(theme.colorScheme.surfaceContainerHigh, const Color(0xFFE8E8E8));
      expect(theme.colorScheme.onSurfaceVariant, const Color(0xFF444444));
      expect(theme.colorScheme.inverseSurface, const Color(0xFF222222));
      expect(theme.colorScheme.onInverseSurface, const Color(0xFFEEEEEE));
    });

    test('M3 15-role typography mapped to Flutter TextTheme', () {
      final def = ThemeDefinition(
        typography: const TypographyDefinition(
          displayLarge: TextStyleDefinition(
              fontSize: 57, fontWeight: 'regular', lineHeight: 64),
          headlineMedium: TextStyleDefinition(
              fontSize: 28, fontWeight: 'regular'),
          titleLarge: TextStyleDefinition(
              fontSize: 22, fontWeight: 'medium'),
          bodyLarge: TextStyleDefinition(
              fontSize: 16, fontWeight: 'regular', lineHeight: 24),
          labelSmall: TextStyleDefinition(
              fontSize: 11, fontWeight: 'medium'),
        ),
      );
      final theme = McpUiThemeBuilder.build(def, isDark: false);

      expect(theme.textTheme.displayLarge?.fontSize, equals(57));
      expect(theme.textTheme.displayLarge?.fontWeight, equals(FontWeight.w400));
      expect(theme.textTheme.headlineMedium?.fontSize, equals(28));
      expect(theme.textTheme.titleLarge?.fontWeight, equals(FontWeight.w500));
      expect(theme.textTheme.bodyLarge?.fontSize, equals(16));
      expect(theme.textTheme.bodyLarge?.height, equals(24 / 16));
      expect(theme.textTheme.labelSmall?.fontSize, equals(11));
    });

    test('numeric fontWeight (100..900) snaps to nearest FontWeight', () {
      final def = ThemeDefinition(
        typography: const TypographyDefinition(
          bodyLarge: TextStyleDefinition(fontSize: 16, fontWeight: 600),
          labelSmall: TextStyleDefinition(fontSize: 11, fontWeight: 230),
        ),
      );
      final theme = McpUiThemeBuilder.build(def, isDark: false);
      expect(theme.textTheme.bodyLarge?.fontWeight, equals(FontWeight.w600));
      expect(theme.textTheme.labelSmall?.fontWeight, equals(FontWeight.w200));
    });

    test('DensityDefinition active level → VisualDensity', () {
      final def = ThemeDefinition(
        density: const DensityDefinition(
          comfortable: DensityLevel(vertical: 1, horizontal: 0),
          standard: DensityLevel(vertical: 0, horizontal: 0),
          compact: DensityLevel(vertical: -2, horizontal: -1),
          active: 'compact',
        ),
      );
      final theme = McpUiThemeBuilder.build(def, isDark: false);
      expect(theme.visualDensity.vertical, equals(-2.0));
      expect(theme.visualDensity.horizontal, equals(-1.0));
    });

    test('ShapeDefinition medium drives card/dialog shape', () {
      final def = ThemeDefinition(
        shape: const ShapeDefinition(medium: ShapeCorner.uniform(20)),
      );
      final theme = McpUiThemeBuilder.build(def, isDark: false);
      final cardShape = theme.cardTheme.shape as RoundedRectangleBorder?;
      expect(cardShape, isNotNull);
      expect((cardShape!.borderRadius as BorderRadius).topLeft.x, equals(20.0));
    });

    test('default seed (no overrides) builds without throwing', () {
      final def = ThemeDefinition.defaultLight();
      final theme = McpUiThemeBuilder.build(def, isDark: false);
      expect(theme, isA<ThemeData>());
      expect(theme.useMaterial3, isTrue);
    });
  });
}
