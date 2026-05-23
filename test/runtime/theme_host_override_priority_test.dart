/// Regression for the intermittent "text-only dark-mode leak" reported
/// by vibe_studio_workspace: bundles that hard-declared `theme.mode`
/// (e.g. `'dark'` from the bundle's manifest) would ignore the host's
/// brightness toggle, while other surfaces driven by the host's outer
/// MediaQuery/Theme would flip — producing a mid-state where text used
/// the bundle's resolved scheme but ambient ancestor widgets used the
/// host's. The race was visible because `setTheme(appDef.theme)` and
/// `setHostBrightness(...)` interleaved differently per launch.
///
/// Fix: `_resolveEffectiveMode` treats a non-null `_hostBrightnessOverride`
/// as the unconditional winner — when a host pins brightness, the bundle
/// follows even if it shipped an explicit mode. The renderer's cache
/// key (via `fingerprint`) ends with the effective mode, so this test
/// asserts on the fingerprint suffix — a stable, fix-anchoring contract.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart'
    show ThemeDefinition;
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => ThemeManager.instance.reset());
  tearDown(() => ThemeManager.instance.reset());

  group('host brightness override priority', () {
    test('host light override flips explicit dark bundle', () {
      final tm = ThemeManager.instance;
      tm.setThemeDefinition(ThemeDefinition.defaultDark());
      tm.setThemeMode('dark');

      expect(tm.fingerprint, endsWith('|dark'));
      tm.setHostBrightness(Brightness.light);
      expect(
        tm.fingerprint,
        endsWith('|light'),
        reason:
            'bundle declared dark, but host pinned light — effective mode '
            'must follow host.',
      );
    });

    test('host dark override flips explicit light bundle', () {
      final tm = ThemeManager.instance;
      tm.setThemeDefinition(ThemeDefinition.defaultLight());
      tm.setThemeMode('light');

      expect(tm.fingerprint, endsWith('|light'));
      tm.setHostBrightness(Brightness.dark);
      expect(tm.fingerprint, endsWith('|dark'));
    });

    test('clearing host override restores declared mode', () {
      final tm = ThemeManager.instance;
      tm.setThemeDefinition(ThemeDefinition.defaultDark());
      tm.setThemeMode('dark');

      tm.setHostBrightness(Brightness.light);
      expect(tm.fingerprint, endsWith('|light'));

      tm.setHostBrightness(null);
      expect(
        tm.fingerprint,
        endsWith('|dark'),
        reason:
            'after override cleared, the bundle\'s declared dark wins again.',
      );
    });

    test('setHostBrightness always notifies (even with explicit mode)',
        () {
      final tm = ThemeManager.instance;
      tm.setThemeDefinition(ThemeDefinition.defaultDark());
      tm.setThemeMode('dark'); // not 'system' — pre-fix this blocked notify

      var fired = 0;
      void listener() => fired++;
      tm.addListener(listener);

      tm.setHostBrightness(Brightness.light);

      expect(
        fired,
        greaterThanOrEqualTo(1),
        reason:
            'host override now affects effective mode unconditionally, '
            'so notify must fire regardless of declared `_themeMode`.',
      );

      tm.removeListener(listener);
    });

    test('repeated identical override is a no-op (no spurious rebuild)',
        () {
      final tm = ThemeManager.instance;
      tm.setHostBrightness(Brightness.dark);

      var fired = 0;
      tm.addListener(() => fired++);

      tm.setHostBrightness(Brightness.dark);
      tm.setHostBrightness(Brightness.dark);

      expect(
        fired,
        0,
        reason:
            'identical override must not fire — the early-return guard '
            'on `_hostBrightnessOverride == brightness` is preserved.',
      );
    });

    test('fingerprint changes across override flip (cache invalidation)',
        () {
      final tm = ThemeManager.instance;
      tm.setThemeDefinition(ThemeDefinition.defaultDark());
      tm.setThemeMode('dark');

      final beforeFp = tm.fingerprint;
      tm.setHostBrightness(Brightness.light);
      final afterFp = tm.fingerprint;

      expect(
        afterFp,
        isNot(equals(beforeFp)),
        reason:
            'renderer cache key must invalidate — otherwise the text '
            'widget rebuilt while dark would survive into the light flip.',
      );
    });
  });
}
