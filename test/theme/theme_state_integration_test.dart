import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';

void main() {
  group('ThemeManager State Integration', () {
    late ThemeManager themeManager;
    late StateManager stateManager;

    setUp(() {
      themeManager = ThemeManager();
      stateManager = StateManager();
      themeManager.setStateManager(stateManager);
    });

    test('should return default theme value when no state override exists', () {
      final primaryColor = themeManager.getThemeValue('colors.primary');
      expect(primaryColor, '#2196f3');
    });

    test('should return state override when custom theme value exists', () {
      // Set a custom primary color in state
      stateManager.set('theme.colors.primary', '#ff0000');
      
      final primaryColor = themeManager.getThemeValue('colors.primary');
      expect(primaryColor, '#ff0000');
    });

    test('should handle nested theme paths in state', () {
      // Set custom typography values
      stateManager.set('theme.typography.h1.fontSize', 48);
      stateManager.set('theme.spacing.md', 20);
      
      final h1FontSize = themeManager.getThemeValue('typography.h1.fontSize');
      final mdSpacing = themeManager.getThemeValue('spacing.md');
      
      expect(h1FontSize, 48);
      expect(mdSpacing, 20);
    });

    test('should fall back to default for partial overrides', () {
      // Override only the fontSize of h1, not the entire h1 object
      stateManager.set('theme.typography.h1.fontSize', 40);
      
      // These should still return defaults since we only check exact paths in state
      final h1FontWeight = themeManager.getThemeValue('typography.h1.fontWeight');
      final h1LetterSpacing = themeManager.getThemeValue('typography.h1.letterSpacing');
      
      // But fontSize should be overridden
      final h1FontSize = themeManager.getThemeValue('typography.h1.fontSize');
      
      expect(h1FontWeight, 'bold'); // Default value
      expect(h1LetterSpacing, -1.5); // Default value
      expect(h1FontSize, 40); // Overridden value
    });

    test('should update ThemeData when state changes', () {
      // Get initial theme
      final initialTheme = themeManager.toFlutterTheme();
      final initialPrimary = initialTheme.colorScheme.primary;
      
      // Update primary color in state
      stateManager.set('theme.colors.primary', '#00ff00');
      
      // Get updated theme
      final updatedTheme = themeManager.toFlutterTheme();
      final updatedPrimary = updatedTheme.colorScheme.primary;
      
      // Colors should be different
      expect(initialPrimary, isNot(equals(updatedPrimary)));
      expect(updatedPrimary.r, 0.0); // r component is in 0-1 range
      expect(updatedPrimary.g, 1.0); // g component is in 0-1 range  
      expect(updatedPrimary.b, 0.0); // b component is in 0-1 range
    });

    test('should handle complex theme overrides', () {
      // Set multiple theme overrides
      stateManager.set('theme.colors.primary', '#123456');
      stateManager.set('theme.colors.secondary', '#654321');
      stateManager.set('theme.borderRadius.md', 12);
      stateManager.set('theme.spacing.lg', 32);
      
      expect(themeManager.getThemeValue('colors.primary'), '#123456');
      expect(themeManager.getThemeValue('colors.secondary'), '#654321');
      expect(themeManager.getThemeValue('borderRadius.md'), 12);
      expect(themeManager.getThemeValue('spacing.lg'), 32);
      
      // Non-overridden values should still return defaults
      expect(themeManager.getThemeValue('colors.error'), '#f44336');
      expect(themeManager.getThemeValue('borderRadius.sm'), 4);
    });
  });
}