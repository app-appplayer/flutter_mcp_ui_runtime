// MCP UI DSL 1.3 — ThemeManager tests (M3 14-domain · seed-derived defaults
// · `{{theme.<domain>.<token>}}` path resolution).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';

void main() {
  late ThemeManager tm;

  setUp(() {
    tm = ThemeManager();
    tm.reset();
  });

  group('TC-TH-01: singleton', () {
    test('same instance across factory + instance getter', () {
      expect(identical(ThemeManager(), ThemeManager.instance), isTrue);
    });
  });

  group('TC-TH-02: setTheme — 1.3 14-domain shape', () {
    test('parses M3 28-role color slot at top level', () {
      tm.setTheme({
        'mode': 'light',
        'color': {
          'primary': '#FF0000',
          'onPrimary': '#FFFFFF',
        },
      });

      expect(tm.getThemeValue('color.primary'), '#FF0000');
      expect(tm.getThemeValue('color.onPrimary'), '#FFFFFF');
    });

    test('typography, spacing, shape, elevation are surface-addressable', () {
      tm.setTheme({
        'typography': {
          'displayLarge': {'fontSize': 64},
        },
        'spacing': {'md': 20},
        'shape': {'large': 20},
        'elevation': {
          'level3': {'shadow': 7},
        },
      });
      expect(tm.getThemeValue('typography.displayLarge.fontSize'), 64);
      expect(tm.getThemeValue('spacing.md'), 20);
      expect(tm.getThemeValue('shape.large'), 20);
      expect(tm.getThemeValue('elevation.level3.shadow'), 7);
    });
  });

  group('TC-TH-03: mode selection', () {
    test('declared mode survives setTheme', () {
      tm.setTheme({'mode': 'dark', 'color': {'primary': '#222222'}});
      expect(tm.themeMode, 'dark');
    });

    test('setThemeMode swaps the active mode without re-setting theme', () {
      tm.setTheme({'mode': 'light', 'color': {'primary': '#AAAAAA'}});
      expect(tm.themeMode, 'light');

      tm.setThemeMode('dark');
      expect(tm.themeMode, 'dark');
    });

    test('mode override via theme.dark sub-section affects ThemeData', () {
      tm.setTheme({
        'mode': 'system',
        'color': {'primary': '#AAAAAA'},
        'dark': {
          'mode': 'dark',
          'color': {'primary': '#222222'},
        },
      });

      tm.setHostBrightness(Brightness.dark);
      final dark = tm.toFlutterTheme();
      expect(dark.colorScheme.primary, const Color(0xFF222222));

      tm.setHostBrightness(Brightness.light);
      final light = tm.toFlutterTheme();
      expect(light.colorScheme.primary, const Color(0xFFAAAAAA));
    });

    test('invalid mode throws', () {
      expect(() => tm.setThemeMode('invalid'), throwsArgumentError);
    });
  });

  group('TC-TH-04: state overrides', () {
    test('state theme.color.X wins over declared JSON', () {
      final state = StateManager();
      state.setState({
        'theme': {
          'color': {'primary': '#00FF00'},
        },
      });
      tm.setStateManager(state);
      tm.setTheme({
        'mode': 'light',
        'color': {'primary': '#FF0000'},
      });
      expect(tm.getThemeValue('color.primary'), '#00FF00');
    });
  });

  group('TC-TH-05: typed accessors', () {
    test('getColor / getColorValue resolve via active scheme', () {
      tm.setTheme({
        'mode': 'light',
        'color': {'primary': '#2196F3'},
      });
      expect(tm.getColor('primary'), '#2196F3');
      expect(tm.getColorValue('primary'), isA<Color>());
    });

    test('typography / spacing / shape / elevation accessors', () {
      tm.setTheme({
        'typography': {
          'bodyLarge': {'fontSize': 18},
        },
        'spacing': {'md': 12},
        'shape': {'medium': 10},
        'elevation': {
          'level3': {'shadow': 5},
        },
      });
      expect(tm.getTextStyle('bodyLarge')?['fontSize'], 18);
      expect(tm.getSpacingValue('md'), 12.0);
      expect(tm.getShapeValue('medium'), 10.0);
      expect(tm.getElevationValue('level3'), 5.0);
    });
  });

  group('TC-TH-06: page override', () {
    test('applyOverride / restore deep-merges then rolls back', () {
      tm.setTheme({
        'mode': 'light',
        'color': {'primary': '#111111', 'secondary': '#222222'},
      });

      final restore = tm.applyOverride({
        'color': {'primary': '#FFFFFF'},
      });
      expect(tm.getThemeValue('color.primary'), '#FFFFFF');
      expect(tm.getThemeValue('color.secondary'), '#222222');

      restore();
      expect(tm.getThemeValue('color.primary'), '#111111');
    });
  });

  group('TC-TH-07: ThemeData bridge', () {
    test('toFlutterTheme exposes M3 28-role on Flutter ColorScheme', () {
      tm.setTheme({
        'mode': 'light',
        'color': {
          'primary': '#FF0000',
          'onPrimary': '#0000FF',
          'surface': '#00FF00',
          'onSurface': '#000000',
        },
      });

      final data = tm.toFlutterTheme();
      expect(data.colorScheme.primary, const Color(0xFFFF0000));
      expect(data.colorScheme.onPrimary, const Color(0xFF0000FF));
      expect(data.colorScheme.surface, const Color(0xFF00FF00));
    });

    test('seed-only ColorScheme auto-derives 28 roles via M3 HCT', () {
      tm.setTheme({
        'mode': 'light',
        'color': {'seed': '#3F51B5'},
      });
      final data = tm.toFlutterTheme();
      expect(data.colorScheme.primary, isA<Color>());
      expect(data.colorScheme.onPrimary, isA<Color>());
      expect(data.colorScheme.surfaceContainer, isA<Color>());
    });
  });
}
