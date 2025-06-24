import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';

void main() {
  group('Theme Mode Support', () {
    late ThemeManager themeManager;
    late StateManager stateManager;

    setUp(() {
      themeManager = ThemeManager();
      themeManager.reset(); // Reset to clean state
      stateManager = StateManager();
      themeManager.setStateManager(stateManager);
    });

    group('Basic Theme Mode', () {
      test('should default to light mode', () {
        expect(themeManager.themeMode, equals('light'));
        expect(themeManager.flutterThemeMode, equals(ThemeMode.light));
      });

      test('should set theme mode to dark', () {
        themeManager.setThemeMode('dark');
        expect(themeManager.themeMode, equals('dark'));
        expect(themeManager.flutterThemeMode, equals(ThemeMode.dark));
      });

      test('should set theme mode to system', () {
        themeManager.setThemeMode('system');
        expect(themeManager.themeMode, equals('system'));
        expect(themeManager.flutterThemeMode, equals(ThemeMode.system));
      });

      test('should reject invalid theme mode', () {
        expect(
          () => themeManager.setThemeMode('invalid'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should reset theme mode on resetTheme', () {
        themeManager.setThemeMode('dark');
        themeManager.resetTheme();
        expect(themeManager.themeMode, equals('light'));
        expect(themeManager.flutterThemeMode, equals(ThemeMode.light));
      });
    });

    group('Theme Configuration', () {
      test('should set theme mode from theme configuration', () {
        final theme = {
          'mode': 'dark',
          'colors': {
            'primary': '#ff5722',
          },
        };
        
        themeManager.setTheme(theme);
        expect(themeManager.themeMode, equals('dark'));
        expect(themeManager.flutterThemeMode, equals(ThemeMode.dark));
      });

      test('should handle theme configuration without mode', () {
        final theme = {
          'colors': {
            'primary': '#ff5722',
          },
        };
        
        themeManager.setTheme(theme);
        expect(themeManager.themeMode, equals('light')); // Should remain default
        expect(themeManager.flutterThemeMode, equals(ThemeMode.light));
      });

      test('should validate theme mode in configuration', () {
        final theme = {
          'mode': 'invalid',
          'colors': {
            'primary': '#ff5722',
          },
        };
        
        expect(
          () => themeManager.setTheme(theme),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('State Manager Integration', () {
      test('should use theme mode from state manager', () {
        // Set mode via state manager
        stateManager.set('theme.mode', 'dark');
        
        expect(themeManager.getThemeValue('mode'), equals('dark'));
        expect(themeManager.flutterThemeMode, equals(ThemeMode.dark));
      });

      test('should fall back to theme manager mode when state is null', () {
        themeManager.setThemeMode('system');
        
        expect(themeManager.getThemeValue('mode'), equals('system'));
        expect(themeManager.flutterThemeMode, equals(ThemeMode.system));
      });

      test('should validate state manager theme mode', () {
        // Set invalid mode in state - should fall back to theme manager mode
        stateManager.set('theme.mode', 'invalid');
        themeManager.setThemeMode('dark');
        
        expect(themeManager.getThemeValue('mode'), equals('dark'));
        expect(themeManager.flutterThemeMode, equals(ThemeMode.dark));
      });

      test('should prefer state manager over theme manager', () {
        themeManager.setThemeMode('light');
        stateManager.set('theme.mode', 'dark');
        
        expect(themeManager.getThemeValue('mode'), equals('dark'));
        expect(themeManager.flutterThemeMode, equals(ThemeMode.dark));
      });
    });

    group('Flutter ThemeMode Conversion', () {
      test('should convert all valid modes correctly', () {
        final testCases = {
          'light': ThemeMode.light,
          'dark': ThemeMode.dark,
          'system': ThemeMode.system,
        };

        for (final entry in testCases.entries) {
          themeManager.setThemeMode(entry.key);
          expect(
            themeManager.flutterThemeMode,
            equals(entry.value),
            reason: 'Failed for mode: ${entry.key}',
          );
        }
      });

      test('should handle case sensitivity', () {
        // Theme mode should be case sensitive and only accept lowercase
        expect(
          () => themeManager.setThemeMode('LIGHT'),
          throwsA(isA<ArgumentError>()),
        );
        
        expect(
          () => themeManager.setThemeMode('Dark'),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('Theme Data Integration', () {
      test('should maintain theme data when changing mode', () {
        final customTheme = {
          'mode': 'dark',
          'colors': {
            'primary': '#ff5722',
            'secondary': '#4caf50',
          },
        };
        
        themeManager.setTheme(customTheme);
        
        expect(themeManager.themeMode, equals('dark'));
        expect(themeManager.getThemeValue('colors.primary'), equals('#ff5722'));
        expect(themeManager.getThemeValue('colors.secondary'), equals('#4caf50'));
      });

      test('should generate correct ThemeData for light mode', () {
        themeManager.setThemeMode('light');
        final lightTheme = themeManager.toFlutterTheme(isDark: false);
        
        expect(lightTheme.brightness, equals(Brightness.light));
      });

      test('should generate correct ThemeData for dark mode', () {
        themeManager.setThemeMode('dark');
        final darkTheme = themeManager.toFlutterTheme(isDark: true);
        
        expect(darkTheme.brightness, equals(Brightness.dark));
      });
    });

    group('Edge Cases', () {
      test('should handle null state manager gracefully', () {
        final freshThemeManager = ThemeManager();
        freshThemeManager.reset();
        // Don't set state manager
        
        freshThemeManager.setThemeMode('dark');
        expect(freshThemeManager.themeMode, equals('dark'));
        expect(freshThemeManager.flutterThemeMode, equals(ThemeMode.dark));
      });

      test('should handle empty theme configuration', () {
        themeManager.setTheme({});
        expect(themeManager.themeMode, equals('light')); // Should remain default
      });

      test('should handle theme mode from getThemeValue', () {
        themeManager.setThemeMode('system');
        expect(themeManager.getThemeValue('mode'), equals('system'));
        
        stateManager.set('theme.mode', 'dark');
        expect(themeManager.getThemeValue('mode'), equals('dark'));
      });
    });
  });
}