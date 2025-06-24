import 'package:flutter/material.dart';
import '../state/state_manager.dart';

/// Theme manager for MCP UI DSL
class ThemeManager {
  static final ThemeManager _instance = ThemeManager._internal();
  factory ThemeManager() => _instance;
  static ThemeManager get instance => _instance;

  ThemeManager._internal();

  // State manager for custom theme values
  StateManager? _stateManager;
  
  // Current theme data
  Map<String, dynamic> _themeData = _defaultTheme;
  
  // Theme mode (light, dark, system)
  String _themeMode = 'light';

  // Default theme
  static final Map<String, dynamic> _defaultTheme = {
    'colors': {
      'primary': '#2196f3',
      'secondary': '#ff4081',
      'background': '#ffffff',
      'surface': '#f5f5f5',
      'error': '#f44336',
      // Legacy Flutter naming (backward compatibility)
      'onPrimary': '#ffffff',
      'onSecondary': '#000000',
      'onBackground': '#000000',
      'onSurface': '#000000',
      'onError': '#ffffff',
      // MCP UI DSL v1.0 naming
      'textOnPrimary': '#ffffff',
      'textOnSecondary': '#000000',
      'textOnBackground': '#000000',
      'textOnSurface': '#000000',
      'textOnError': '#ffffff',
    },
    'typography': {
      'h1': {
        'fontSize': 32,
        'fontWeight': 'bold',
        'letterSpacing': -1.5,
      },
      'h2': {
        'fontSize': 28,
        'fontWeight': 'bold',
        'letterSpacing': -0.5,
      },
      'h3': {
        'fontSize': 24,
        'fontWeight': 'bold',
        'letterSpacing': 0,
      },
      'h4': {
        'fontSize': 20,
        'fontWeight': 'bold',
        'letterSpacing': 0.25,
      },
      'h5': {
        'fontSize': 18,
        'fontWeight': 'bold',
        'letterSpacing': 0,
      },
      'h6': {
        'fontSize': 16,
        'fontWeight': 'bold',
        'letterSpacing': 0.15,
      },
      'body1': {
        'fontSize': 16,
        'fontWeight': 'normal',
        'letterSpacing': 0.5,
      },
      'body2': {
        'fontSize': 14,
        'fontWeight': 'normal',
        'letterSpacing': 0.25,
      },
      'caption': {
        'fontSize': 12,
        'fontWeight': 'normal',
        'letterSpacing': 0.4,
      },
      'button': {
        'fontSize': 14,
        'fontWeight': 'medium',
        'letterSpacing': 1.25,
        'textTransform': 'uppercase',
      },
    },
    'spacing': {
      'xs': 4,
      'sm': 8,
      'md': 16,
      'lg': 24,
      'xl': 32,
      'xxl': 48,
    },
    'borderRadius': {
      'sm': 4,
      'md': 8,
      'lg': 16,
      'xl': 24,
      'round': 9999,
    },
    'elevation': {
      'none': 0,
      'sm': 2,
      'md': 4,
      'lg': 8,
      'xl': 16,
    },
  };

  /// Get current theme
  Map<String, dynamic> get theme => _themeData;
  
  /// Get current theme mode
  String get themeMode => _themeMode;
  
  /// Set theme mode ('light', 'dark', 'system')
  void setThemeMode(String mode) {
    if (['light', 'dark', 'system'].contains(mode)) {
      _themeMode = mode;
    } else {
      throw ArgumentError('Invalid theme mode: $mode. Use "light", "dark", or "system".');
    }
  }
  
  /// Get Flutter ThemeMode
  ThemeMode get flutterThemeMode {
    final currentMode = getThemeValue('mode') as String? ?? _themeMode;
    switch (currentMode) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      case 'light':
      default:
        return ThemeMode.light;
    }
  }
  
  /// Get current theme as Flutter ThemeData
  ThemeData get currentTheme => _buildThemeData();

  /// Set custom theme
  void setTheme(Map<String, dynamic> theme) {
    _themeData = _mergeTheme(_defaultTheme, theme);
    
    // Check if theme mode is specified in the theme configuration
    if (theme.containsKey('mode')) {
      setThemeMode(theme['mode'] as String);
    }
  }

  /// Reset to default theme
  void resetTheme() {
    _themeData = _defaultTheme;
    _themeMode = 'light';
  }

  /// Set the state manager for accessing custom theme values
  void setStateManager(StateManager stateManager) {
    _stateManager = stateManager;
  }
  
  /// Get theme value by path (e.g., 'colors.primary')
  dynamic getThemeValue(String path) {
    // Handle special case for theme mode
    if (path == 'mode') {
      // First check state manager for dynamic theme mode
      if (_stateManager != null) {
        final stateMode = _stateManager!.get<String>('theme.mode');
        if (stateMode != null && ['light', 'dark', 'system'].contains(stateMode)) {
          return stateMode;
        }
      }
      return _themeMode;
    }
    
    // First check if there's a custom theme value in state
    if (_stateManager != null) {
      // Check for theme.{path} in state (e.g., theme.colors.primary)
      final customValue = _stateManager!.get<dynamic>('theme.$path');
      if (customValue != null) {
        return customValue;
      }
    }
    
    // Fall back to default theme values
    final parts = path.split('.');
    dynamic current = _themeData;
    
    for (final part in parts) {
      if (current is Map<String, dynamic> && current.containsKey(part)) {
        current = current[part];
      } else {
        return null;
      }
    }
    
    return current;
  }

  /// Convert to Flutter ThemeData
  ThemeData toFlutterTheme({bool isDark = false}) {
    // Get colors from theme, checking state first
    final colors = <String, dynamic>{};
    final defaultColors = _themeData['colors'] as Map<String, dynamic>;
    
    // Build colors map with state overrides
    for (final entry in defaultColors.entries) {
      final stateValue = getThemeValue('colors.${entry.key}');
      colors[entry.key] = stateValue ?? entry.value;
    }
    
    return ThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primaryColor: _parseColor(colors['primary']),
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: _parseColor(colors['primary']) ?? Colors.blue,
        // Use v1.0 textOnPrimary if available, fallback to onPrimary
        onPrimary: _parseColor(colors['textOnPrimary'] ?? colors['onPrimary']) ?? Colors.white,
        secondary: _parseColor(colors['secondary']) ?? Colors.pink,
        // Use v1.0 textOnSecondary if available, fallback to onSecondary
        onSecondary: _parseColor(colors['textOnSecondary'] ?? colors['onSecondary']) ?? Colors.black,
        error: _parseColor(colors['error']) ?? Colors.red,
        // Use v1.0 textOnError if available, fallback to onError
        onError: _parseColor(colors['textOnError'] ?? colors['onError']) ?? Colors.white,
        surface: _parseColor(colors['surface']) ?? Colors.grey[100]!,
        // Use v1.0 textOnSurface if available, fallback to onSurface
        onSurface: _parseColor(colors['textOnSurface'] ?? colors['onSurface']) ?? Colors.black,
        // Note: background is deprecated, using surface instead
      ),
      textTheme: _buildTextTheme(),
    );
  }

  /// Build Flutter ThemeData from theme
  ThemeData _buildThemeData() {
    // Get colors from theme, checking state first
    final colors = <String, dynamic>{};
    final defaultColors = _themeData['colors'] as Map<String, dynamic>;
    
    // Build colors map with state overrides
    for (final entry in defaultColors.entries) {
      final stateValue = getThemeValue('colors.${entry.key}');
      colors[entry.key] = stateValue ?? entry.value;
    }
    
    return ThemeData(
      colorScheme: ColorScheme.light(
        primary: _parseColor(colors['primary']) ?? Colors.blue,
        secondary: _parseColor(colors['secondary']) ?? Colors.pink,
        surface: _parseColor(colors['surface']) ?? Colors.grey[100]!,
        error: _parseColor(colors['error']) ?? Colors.red,
        // Use v1.0 textOn* if available, fallback to on* for backward compatibility
        onPrimary: _parseColor(colors['textOnPrimary'] ?? colors['onPrimary']) ?? Colors.white,
        onSecondary: _parseColor(colors['textOnSecondary'] ?? colors['onSecondary']) ?? Colors.black,
        onSurface: _parseColor(colors['textOnSurface'] ?? colors['onSurface']) ?? Colors.black,
        onError: _parseColor(colors['textOnError'] ?? colors['onError']) ?? Colors.white,
      ),
      scaffoldBackgroundColor: _parseColor(colors['background']) ?? Colors.white,
      textTheme: _buildTextTheme(),
    );
  }

  /// Build Flutter TextTheme from typography
  TextTheme _buildTextTheme() {
    final typography = _themeData['typography'] as Map<String, dynamic>;
    
    return TextTheme(
      displayLarge: _buildTextStyle(typography['h1']),
      displayMedium: _buildTextStyle(typography['h2']),
      displaySmall: _buildTextStyle(typography['h3']),
      headlineMedium: _buildTextStyle(typography['h4']),
      headlineSmall: _buildTextStyle(typography['h5']),
      titleLarge: _buildTextStyle(typography['h6']),
      bodyLarge: _buildTextStyle(typography['body1']),
      bodyMedium: _buildTextStyle(typography['body2']),
      labelLarge: _buildTextStyle(typography['button']),
      bodySmall: _buildTextStyle(typography['caption']),
    );
  }

  /// Build TextStyle from theme data
  TextStyle? _buildTextStyle(dynamic styleData) {
    if (styleData == null || styleData is! Map<String, dynamic>) return null;
    
    return TextStyle(
      fontSize: styleData['fontSize']?.toDouble(),
      fontWeight: _parseFontWeight(styleData['fontWeight']),
      letterSpacing: styleData['letterSpacing']?.toDouble(),
    );
  }

  /// Parse color from hex string
  Color? _parseColor(dynamic value) {
    if (value == null) return null;
    
    if (value is String && value.startsWith('#')) {
      String hex = value.substring(1);
      
      // Handle both 6-digit (RGB) and 8-digit (ARGB) hex colors
      if (hex.length == 6) {
        // Add full opacity for 6-digit colors
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        // Parse 8-digit ARGB colors directly
        return Color(int.parse(hex, radix: 16));
      }
    }
    
    return null;
  }

  /// Parse font weight
  FontWeight? _parseFontWeight(String? value) {
    switch (value) {
      case 'thin':
        return FontWeight.w100;
      case 'light':
        return FontWeight.w300;
      case 'normal':
        return FontWeight.w400;
      case 'medium':
        return FontWeight.w500;
      case 'bold':
        return FontWeight.w700;
      case 'black':
        return FontWeight.w900;
      default:
        return null;
    }
  }

  /// Merge two theme maps
  Map<String, dynamic> _mergeTheme(
    Map<String, dynamic> base,
    Map<String, dynamic> custom,
  ) {
    final result = Map<String, dynamic>.from(base);
    
    custom.forEach((key, value) {
      if (value is Map<String, dynamic> && result[key] is Map<String, dynamic>) {
        result[key] = _mergeTheme(result[key], value);
      } else {
        result[key] = value;
      }
    });
    
    return result;
  }
  
  /// Reset theme to defaults (for testing)
  void reset() {
    _themeData = Map<String, dynamic>.from(_defaultTheme);
    _themeMode = 'light';
    _stateManager = null;
  }
}