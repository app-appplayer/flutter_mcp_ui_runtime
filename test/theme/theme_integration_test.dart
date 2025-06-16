import 'package:test/test.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';

void main() {
  group('Theme Integration Tests', () {
    late ThemeManager themeManager;

    setUp(() {
      themeManager = ThemeManager();
    });

    test('Theme manager should have default theme', () {
      final theme = themeManager.theme;
      expect(theme, isNotNull);
      expect(theme['colors'], isNotNull);
      expect(theme['colors']['primary'], equals('#2196f3'));
    });

    test('Theme manager should set custom theme', () {
      final customTheme = {
        'colors': {
          'primary': '#4CAF50',
        },
      };

      themeManager.setTheme(customTheme);
      final primary = themeManager.getThemeValue('colors.primary');
      expect(primary, equals('#4CAF50'));
    });

    test('Theme manager should set and get theme values', () {
      final customTheme = {
        'colors': {
          'primary': '#FF5722',
        },
        'typography': {
          'h1': {
            'fontSize': 36,
            'fontWeight': 'bold',
          },
        },
      };

      themeManager.setTheme(customTheme);

      // Test simple theme value
      expect(themeManager.getThemeValue('colors.primary'), equals('#FF5722'));

      // Test nested theme value
      expect(themeManager.getThemeValue('typography.h1.fontSize'), equals(36));
    });

    test('Application definition should apply theme', () {
      final appTheme = {
        'mode': 'light',
        'colors': {
          'primary': '#9C27B0',
          'secondary': '#00BCD4',
        },
        'typography': {
          'body1': {
            'fontSize': 18,
          },
        },
      };

      themeManager.setTheme(appTheme);

      expect(themeManager.getThemeValue('colors.primary'), equals('#9C27B0'));
      expect(themeManager.getThemeValue('colors.secondary'), equals('#00BCD4'));
      expect(themeManager.getThemeValue('typography.body1.fontSize'), equals(18));
    });

    test('Theme values should be accessible via theme manager', () {
      final testTheme = {
        'spacing': {
          'md': 16,
          'lg': 24,
        },
      };

      themeManager.setTheme(testTheme);

      final spacingMd = themeManager.getThemeValue('spacing.md');
      final spacingLg = themeManager.getThemeValue('spacing.lg');

      expect(spacingMd, equals(16));
      expect(spacingLg, equals(24));
    });

    test('Theme reset should restore defaults', () {
      final customTheme = {
        'colors': {
          'primary': '#CUSTOM',
        },
      };

      themeManager.setTheme(customTheme);
      expect(themeManager.getThemeValue('colors.primary'), equals('#CUSTOM'));

      themeManager.resetTheme();
      expect(themeManager.getThemeValue('colors.primary'), equals('#2196f3'));
    });
  });
}