import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart';

import '../state/state_manager.dart';
import 'theme_builder.dart';

/// Theme manager for MCP UI DSL 1.3 — `specs/mcp_ui_dsl/05_Theme.md`.
///
/// Holds a strongly-typed [ThemeDefinition] (M3 14-domain — color, typography,
/// spacing, shape, elevation, motion, density, breakpoints, border, opacity,
/// focusRing, zIndex, component) plus its serialized JSON form for path-based
/// resolution of `{{theme.*}}` bindings.
///
/// Mode resolution: `light` / `dark` / `system`. In `system` mode the active
/// scheme follows host brightness (an embedder may inject an override via
/// [setHostBrightness] — useful when an outer launcher wants its own light/
/// dark choice to win over a server app declaring `mode: 'system'`).
class ThemeManager with ChangeNotifier {
  static final ThemeManager _instance = ThemeManager._internal();
  factory ThemeManager() => _instance;
  static ThemeManager get instance => _instance;

  ThemeManager._internal();

  /// Active strongly-typed theme definition.
  ThemeDefinition _definition = ThemeDefinition.defaultLight();

  /// Cached JSON projection of [_definition] for `{{theme.*}}` path traversal.
  Map<String, dynamic> _themeData = ThemeDefinition.defaultLight().toJson();

  /// Theme mode (`light` / `dark` / `system`). Default: `system`.
  String _themeMode = 'system';

  /// Optional state manager — `theme.mode` state override wins over the
  /// declared definition value.
  StateManager? _stateManager;

  /// Host-injected brightness override used to resolve `mode: 'system'`.
  Brightness? _hostBrightnessOverride;

  /// Currently active strongly-typed theme.
  ThemeDefinition get definition => _definition;

  /// JSON projection of the active theme (for binding resolution).
  Map<String, dynamic> get theme => _themeData;

  /// Declared theme mode (`light` / `dark` / `system`).
  String get themeMode => _themeMode;

  /// Spec alias.
  String get currentMode => _themeMode;

  /// Effective mode after resolving `system` against host brightness.
  String get effectiveMode => _resolveEffectiveMode();

  /// Flutter [ThemeMode] equivalent for routing into `MaterialApp`.
  /// Honours a `theme.mode` state override (spec §5.2).
  ThemeMode get flutterThemeMode {
    final resolved = (getThemeValue('mode') as String?) ?? _themeMode;
    switch (resolved) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  /// Convert active definition into Flutter [ThemeData] for the active mode.
  ThemeData get currentTheme => toFlutterTheme();

  // ---------------------------------------------------------------------------
  // Mutators
  // ---------------------------------------------------------------------------

  /// Set the theme from a JSON map (1.3 — 14 domains).
  void setTheme(Map<String, dynamic> theme) {
    final def = ThemeDefinition.fromJson(theme);
    setThemeDefinition(def);
  }

  /// Set the theme from a strongly-typed [ThemeDefinition].
  void setThemeDefinition(ThemeDefinition definition) {
    _definition = definition;
    _themeData = definition.toJson();
    if (definition.mode != _themeMode) {
      _themeMode = _validateMode(definition.mode);
    }
    notifyListeners();
  }

  /// Set the theme mode (`light` / `dark` / `system`).
  void setThemeMode(String mode) {
    final validated = _validateMode(mode);
    if (_themeMode == validated) return;
    _themeMode = validated;
    notifyListeners();
  }

  /// Spec alias.
  void setMode(String mode) => setThemeMode(mode);

  /// Inject host brightness override (for `mode: 'system'` resolution).
  /// Pass `null` to clear and follow OS brightness.
  void setHostBrightness(Brightness? brightness) {
    if (_hostBrightnessOverride == brightness) return;
    _hostBrightnessOverride = brightness;
    if (_themeMode == 'system') notifyListeners();
  }

  /// Hook invoked when the OS platform brightness toggles. Only meaningful
  /// when no host override is active and `mode: 'system'` is declared.
  void notifyBrightnessChanged() {
    if (_themeMode != 'system' || _hostBrightnessOverride != null) return;
    notifyListeners();
  }

  /// Wire the state manager so `theme.mode` state overrides the declared mode.
  void setStateManager(StateManager stateManager) {
    _stateManager = stateManager;
  }

  /// Reset to defaults.
  void resetTheme() {
    _definition = ThemeDefinition.defaultLight();
    _themeData = _definition.toJson();
    _themeMode = 'system';
    notifyListeners();
  }

  /// Test-only reset.
  void reset() {
    _definition = ThemeDefinition.defaultLight();
    _themeData = _definition.toJson();
    _themeMode = 'system';
    _hostBrightnessOverride = null;
    _stateManager = null;
  }

  /// Apply a page-level override (spec §5.7 — deep merge) and return a
  /// restore callback.
  VoidCallback applyOverride(Map<String, dynamic> override) {
    final previousDef = _definition;
    final previousData = Map<String, dynamic>.from(_themeData);
    final previousMode = _themeMode;

    final merged = _deepMerge(_themeData, override);
    final mergedDef = ThemeDefinition.fromJson(merged);
    setThemeDefinition(mergedDef);

    return () {
      _definition = previousDef;
      _themeData = previousData;
      _themeMode = previousMode;
      notifyListeners();
    };
  }

  // ---------------------------------------------------------------------------
  // Bindings (spec §5.6)
  // ---------------------------------------------------------------------------

  /// Resolve a value via dotted path — e.g. `color.primary`,
  /// `typography.bodyLarge.fontSize`, `spacing.md`, `shape.medium.uniform`,
  /// `elevation.level3.shadow`, `motion.duration.medium2`.
  ///
  /// Spec §5.6 — bindings resolve against the active mode's effective
  /// definition. `theme.mode` is special: state-manager overrides win.
  dynamic getThemeValue(String path) {
    if (path == 'mode') {
      if (_stateManager != null) {
        final stateMode = _stateManager!.get<String>('theme.mode');
        if (stateMode != null &&
            const ['light', 'dark', 'system'].contains(stateMode)) {
          return stateMode;
        }
      }
      return _themeMode;
    }

    if (_stateManager != null) {
      final stateValue = _stateManager!.get<dynamic>('theme.$path');
      if (stateValue != null) return stateValue;
    }

    // Spec §5.7 — mode-specific override (`theme.light` / `theme.dark`)
    // wins over the base section for the active mode. Resolve the path
    // against the override first; on miss, fall back to the base.
    final mode = _resolveEffectiveMode();
    final override = _themeData[mode];
    if (override is Map<String, dynamic>) {
      final hit = _resolvePath(override, path);
      if (hit != null) return hit;
    }
    return _resolvePath(_themeData, path);
  }

  /// Spec alias.
  dynamic resolveThemeValue(String path) => getThemeValue(path);

  // ---------------------------------------------------------------------------
  // Convenience accessors (typed)
  // ---------------------------------------------------------------------------

  /// Returns the hex string for an M3 28-role color slot
  /// (e.g. `primary` / `surfaceContainer`).
  String? getColor(String slot) => getThemeValue('color.$slot') as String?;

  /// Resolved [Color] for a color slot.
  Color? getColorValue(String slot) => _parseColor(getColor(slot));

  /// Raw text-style map for an M3 typography role
  /// (e.g. `bodyLarge` / `titleMedium`).
  Map<String, dynamic>? getTextStyle(String role) =>
      getThemeValue('typography.$role') as Map<String, dynamic>?;

  /// Resolved [TextStyle] for an M3 typography role.
  TextStyle? getTextStyleValue(String role) =>
      _buildTextStyle(getTextStyle(role));

  /// Spacing token (`xxs`/`xs`/`sm`/`md`/`lg`/`xl`/`2xl`/`3xl`/`4xl`).
  num? getSpacing(String key) => getThemeValue('spacing.$key') as num?;
  double? getSpacingValue(String key) => getSpacing(key)?.toDouble();

  /// Shape token uniform corner radius
  /// (`none`/`extraSmall`/`small`/`medium`/`large`/`extraLarge`/`full`).
  num? getShape(String key) {
    final v = getThemeValue('shape.$key');
    if (v is num) return v;
    if (v is Map && v['uniform'] is num) return v['uniform'] as num;
    return null;
  }

  double? getShapeValue(String key) => getShape(key)?.toDouble();

  /// Elevation level shadow value (`level0`..`level5`).
  num? getElevation(String key) {
    final v = getThemeValue('elevation.$key');
    if (v is num) return v;
    if (v is Map && v['shadow'] is num) return v['shadow'] as num;
    return null;
  }

  double? getElevationValue(String key) => getElevation(key)?.toDouble();

  // ---------------------------------------------------------------------------
  // Flutter ThemeData
  // ---------------------------------------------------------------------------

  ThemeData toFlutterTheme({bool? isDark}) {
    final dark = isDark ?? (_resolveEffectiveMode() == 'dark');
    final modeDef = _modeSpecific(dark) ?? _definition;
    return McpUiThemeBuilder.build(modeDef, isDark: dark);
  }

  /// Spec alias.
  ThemeData toFlutterThemeData({bool? isDark}) =>
      toFlutterTheme(isDark: isDark);

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  ThemeDefinition? _modeSpecific(bool dark) {
    if (dark) {
      return _definition.dark != null
          ? _definition.merge(_definition.dark!)
          : null;
    }
    return _definition.light != null
        ? _definition.merge(_definition.light!)
        : null;
  }

  String _resolveEffectiveMode() {
    if (_themeMode == 'system') {
      final brightness = _hostBrightnessOverride ??
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark ? 'dark' : 'light';
    }
    return _themeMode;
  }

  String _validateMode(String mode) {
    if (!const ['light', 'dark', 'system'].contains(mode)) {
      throw ArgumentError(
          'Invalid theme mode: $mode. Use "light", "dark", or "system".');
    }
    return mode;
  }

  static dynamic _resolvePath(Map<String, dynamic> root, String path) {
    final parts = path.split('.');
    dynamic current = root;
    for (final part in parts) {
      if (current is Map && current.containsKey(part)) {
        current = current[part];
      } else {
        return null;
      }
    }
    return current;
  }

  TextStyle? _buildTextStyle(dynamic data) {
    if (data is! Map<String, dynamic>) return null;
    final size = (data['fontSize'] as num?)?.toDouble();
    final lineH = (data['lineHeight'] as num?)?.toDouble();
    return TextStyle(
      fontSize: size,
      fontWeight: _parseFontWeight(data['fontWeight']),
      letterSpacing: (data['letterSpacing'] as num?)?.toDouble(),
      height: (size != null && lineH != null && size > 0)
          ? lineH / size
          : null,
    );
  }

  Color? _parseColor(dynamic value) {
    if (value is! String) return null;
    final v = value.trim();
    if (v.startsWith('#')) {
      final hex = v.substring(1);
      if (hex.length == 6) return Color(int.parse('FF$hex', radix: 16));
      if (hex.length == 8) return Color(int.parse(hex, radix: 16));
      return null;
    }
    if (v.startsWith('rgb(') || v.startsWith('rgba(')) {
      final inside =
          v.substring(v.indexOf('(') + 1, v.indexOf(')')).split(',');
      if (inside.length < 3) return null;
      final r = int.tryParse(inside[0].trim());
      final g = int.tryParse(inside[1].trim());
      final b = int.tryParse(inside[2].trim());
      if (r == null || g == null || b == null) return null;
      final a = inside.length == 4
          ? ((double.tryParse(inside[3].trim()) ?? 1.0) * 255).round()
          : 255;
      return Color.fromARGB(a, r, g, b);
    }
    return null;
  }

  FontWeight? _parseFontWeight(dynamic value) {
    if (value is num) {
      final w = value.toInt();
      return FontWeight.values.firstWhere(
        (fw) => fw.value == ((w ~/ 100) * 100).clamp(100, 900),
        orElse: () => FontWeight.w400,
      );
    }
    if (value is! String) return null;
    switch (value) {
      case 'thin':
      case '100':
        return FontWeight.w100;
      case 'extraLight':
      case '200':
        return FontWeight.w200;
      case 'light':
      case '300':
        return FontWeight.w300;
      case 'regular':
      case 'normal':
      case '400':
        return FontWeight.w400;
      case 'medium':
      case '500':
        return FontWeight.w500;
      case 'semiBold':
      case '600':
        return FontWeight.w600;
      case 'bold':
      case '700':
        return FontWeight.w700;
      case 'extraBold':
      case '800':
        return FontWeight.w800;
      case 'black':
      case '900':
        return FontWeight.w900;
      default:
        return null;
    }
  }

  static Map<String, dynamic> _deepMerge(
    Map<String, dynamic> base,
    Map<String, dynamic> override,
  ) {
    final result = Map<String, dynamic>.from(base);
    override.forEach((key, value) {
      if (value is Map<String, dynamic> && result[key] is Map) {
        result[key] = _deepMerge(
          Map<String, dynamic>.from(result[key] as Map),
          value,
        );
      } else {
        result[key] = value;
      }
    });
    return result;
  }
}
