/// Regression for cache-key fingerprint of [ThemeManager] state.
///
/// User trace (2026-05-21): host boots dark, app A mounts (dark OK),
/// app B mounts (dark OK), app A re-mount → centre text shows light
/// tone, app B re-mount → same. The cached `Text` widget baked a
/// `Color` at first build; the cache key (`{mode, primaryColor}`) did
/// not change when token state changed afterwards, so the stale Color
/// survived the brightness swap on re-mount.
///
/// Fix: `ThemeManager.fingerprint` summarises mutable state. The
/// renderer's `_extractCacheableContext` now uses that fingerprint —
/// any token / mode / host brightness change flips the key, evicting
/// the stale widget on next lookup.
///
/// The tests deliberately avoid building a full `MCPUIRuntime` (which
/// would register the engine's `notifyListeners` tear-off on the
/// singleton ThemeManager — see `theme_forward_test.dart`) and instead
/// drive the ThemeManager directly. This keeps the regression scoped
/// to fingerprint semantics and prevents listener cross-talk between
/// test files in the shared-process test runner.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart' show ThemeDefinition;
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart' show ThemeManager;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThemeManager.fingerprint — cache key invalidation', () {
    setUp(() => ThemeManager.instance.reset());
    tearDown(() => ThemeManager.instance.reset());

    test('changes when setThemeDefinition swaps the active definition', () {
      final tm = ThemeManager.instance;
      final fp1 = tm.fingerprint;

      tm.setThemeDefinition(ThemeDefinition.defaultDark());
      final fp2 = tm.fingerprint;

      expect(fp2, isNot(equals(fp1)),
          reason:
              'identity of _themeData changes on setThemeDefinition → fingerprint must flip');
    });

    test('changes when host brightness override flips', () {
      final tm = ThemeManager.instance;
      tm.setHostBrightness(Brightness.light);
      final fpLight = tm.fingerprint;

      tm.setHostBrightness(Brightness.dark);
      final fpDark = tm.fingerprint;

      expect(fpDark, isNot(equals(fpLight)),
          reason:
              'host brightness override flips → fingerprint must reflect resolved effective mode');
    });

    test('stable across no-op calls', () {
      final tm = ThemeManager.instance;
      final fp1 = tm.fingerprint;
      final fp2 = tm.fingerprint;
      final fp3 = tm.fingerprint;

      expect(fp1, fp2);
      expect(fp2, fp3);
    });
  });
}
