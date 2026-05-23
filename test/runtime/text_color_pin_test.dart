/// Regression for the "tab-cycle dark text drift" reported by
/// vibe_studio_workspace: opening app_builder bundle, jumping to home
/// tab, returning — the centre `text` widget's colour flipped between
/// the dark and light onSurface values. Visible only in dark mode
/// because both branches yield near-black under light, so the
/// divergence is invisible there; in dark the same race surfaces as
/// black-on-dark text frames.
///
/// Root cause: spec §5.4.2 typography roles deliberately omit a `color`
/// field (Material 3 separates typography from colour). The runtime
/// returned `TextStyle(color: null)` and Flutter fell through to the
/// ambient `DefaultTextStyle.of(context).color`, which inherits from
/// an ancestor `Theme` whose brightness can briefly diverge from the
/// ThemeManager's effective mode during host tab transitions.
///
/// Two fixes locked here:
///   1. `flutterThemeMode` now honours `_hostBrightnessOverride`
///      unconditionally (in lockstep with `_resolveEffectiveMode`), so
///      `MaterialApp.themeMode` cannot diverge from the colour-token
///      path.
///   2. `text` widget pins an explicit `theme.color.onSurface` when the
///      author left colour unspecified, breaking the ambient
///      inheritance dependency entirely.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart'
    show ThemeDefinition;
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => ThemeManager.instance.reset());
  tearDown(() => ThemeManager.instance.reset());

  group('flutterThemeMode honours host override unconditionally', () {
    test('declared dark + host light pin → ThemeMode.light', () {
      final tm = ThemeManager.instance;
      tm.setThemeDefinition(ThemeDefinition.defaultDark());
      tm.setThemeMode('dark');
      tm.setHostBrightness(Brightness.light);

      expect(tm.flutterThemeMode, ThemeMode.light);
    });

    test('declared light + host dark pin → ThemeMode.dark', () {
      final tm = ThemeManager.instance;
      tm.setThemeDefinition(ThemeDefinition.defaultLight());
      tm.setThemeMode('light');
      tm.setHostBrightness(Brightness.dark);

      expect(tm.flutterThemeMode, ThemeMode.dark);
    });

    test('declared system + no host pin → ThemeMode.system', () {
      final tm = ThemeManager.instance;
      tm.setThemeMode('system');

      expect(tm.flutterThemeMode, ThemeMode.system);
    });

    test('declared system + host pin → resolved Mode', () {
      final tm = ThemeManager.instance;
      tm.setThemeMode('system');
      tm.setHostBrightness(Brightness.dark);

      expect(tm.flutterThemeMode, ThemeMode.dark);
    });

    test('clearing host override falls back to declared mode', () {
      final tm = ThemeManager.instance;
      tm.setThemeDefinition(ThemeDefinition.defaultDark());
      tm.setThemeMode('dark');
      tm.setHostBrightness(Brightness.light);
      expect(tm.flutterThemeMode, ThemeMode.light);

      tm.setHostBrightness(null);
      expect(tm.flutterThemeMode, ThemeMode.dark);
    });
  });

  group('text widget pins onSurface when style.color unspecified', () {
    testWidgets('renders with theme.color.onSurface (dark)', (tester) async {
      ThemeManager.instance.setHostBrightness(Brightness.dark);

      final runtime = MCPUIRuntime();
      await runtime.initialize(
        const <String, dynamic>{
          'type': 'page',
          'content': {
            'type': 'text',
            'value': 'hi',
            'variant': 'bodyMedium',
          },
        },
        validateSchema: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          // Deliberately wrap with a LIGHT theme to simulate the host's
          // ambient inheritance giving the runtime a stale light frame
          // mid-transition. Before the fix, the text colour fell through
          // to this light Theme's onSurface (near black) — now the
          // factory pins ThemeManager.onSurface (dark) directly.
          theme: ThemeData.light(),
          home: runtime.buildUI(),
        ),
      );
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(find.text('hi'));
      final pinned = textWidget.style?.color;
      final expected = ThemeManager.instance.getColorValue('onSurface');

      expect(
        pinned,
        equals(expected),
        reason:
            'text widget must pin ThemeManager.onSurface — surrounding '
            'light MaterialApp must NOT determine the text colour.',
      );

      await runtime.destroy();
    });

    testWidgets('author-supplied style.color still wins', (tester) async {
      ThemeManager.instance.setHostBrightness(Brightness.dark);

      final runtime = MCPUIRuntime();
      await runtime.initialize(
        const <String, dynamic>{
          'type': 'page',
          'content': {
            'type': 'text',
            'value': 'hi',
            'style': {'color': '#ff00ff'},
          },
        },
        validateSchema: false,
      );

      await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(find.text('hi'));
      expect(
        textWidget.style?.color,
        equals(const Color(0xFFFF00FF)),
        reason: 'inline style.color must override the onSurface pin.',
      );

      await runtime.destroy();
    });
  });
}
