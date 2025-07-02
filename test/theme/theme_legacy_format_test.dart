import 'package:flutter/material.dart';
import 'package:test/test.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';

void main() {
  group('Theme Legacy Format Tests', () {
    late ThemeManager themeManager;

    setUp(() {
      themeManager = ThemeManager();
      themeManager.reset();
    });

    test('should NOT support legacy onPrimary, onSecondary format', () {
      final themeData = {
        'colors': {
          'primary': '#2196F3',
          'onPrimary': '#FF0000', // This should be ignored
          'textOnPrimary': '#00FF00', // This should be used
        },
      };

      themeManager.setTheme(themeData);
      final flutterTheme = themeManager.currentTheme;
      
      // Should use textOnPrimary value (green), not onPrimary value (red)
      expect(flutterTheme.colorScheme.onPrimary, equals(const Color(0xFF00FF00)));
    });

    test('should use default values when only legacy format is provided', () {
      final themeData = {
        'colors': {
          'primary': '#2196F3',
          'onPrimary': '#FF0000', // This should be ignored
          'onSecondary': '#00FF00', // This should be ignored
        },
      };

      themeManager.setTheme(themeData);
      final flutterTheme = themeManager.currentTheme;
      
      // Should use default values since textOn* is not provided
      expect(flutterTheme.colorScheme.onPrimary, equals(Colors.white));
      expect(flutterTheme.colorScheme.onSecondary, equals(Colors.black));
    });

    test('should only recognize MCP UI DSL v1.0 textOn* format', () {
      final themeData = {
        'colors': {
          'primary': '#1976D2',
          'secondary': '#D32F2F',
          'textOnPrimary': '#FFFFFF',
          'textOnSecondary': '#FFFFFF',
          'textOnBackground': '#212121',
          'textOnSurface': '#424242',
          'textOnError': '#FFFFFF',
        },
      };

      themeManager.setTheme(themeData);
      final flutterTheme = themeManager.currentTheme;
      
      // Verify all textOn* values are correctly applied
      expect(flutterTheme.colorScheme.onPrimary.toARGB32(), equals(0xFFFFFFFF));
      expect(flutterTheme.colorScheme.onSecondary.toARGB32(), equals(0xFFFFFFFF));
      expect(flutterTheme.colorScheme.onSurface.toARGB32(), equals(0xFF424242));
      expect(flutterTheme.colorScheme.onError.toARGB32(), equals(0xFFFFFFFF));
    });
  });
}