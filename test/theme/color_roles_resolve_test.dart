// Every colour role resolves to a value, from both positions.
//
// The suites around this one ask whether a widget *draws*: no exception, no
// error widget. A box painted with an unresolved colour draws perfectly — it
// is simply transparent — so every one of them stayed green while three of
// the four legacy roles came back empty. konpi found it by printing the four
// values on a screen, which is the check none of my tests were making.
//
// So this one asserts the value, not the absence of a crash, and it asserts
// it from both positions a document can ask from:
//
//   `color: "primary"`            → `parseColor` → theme map, then the scheme
//   `{{theme.color.primary}}`     → `getThemeValue` → theme map, then the scheme
//
// Those were two different code paths that had drifted apart: one derived the
// missing roles from `seed` and the other returned null, so the same role
// answered in one place and was empty in the other.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

/// §5.3.1 — the roles a theme may name, including the legacy spellings the
/// spec keeps. The semantic six are listed apart: they have no Material 3
/// counterpart, so they do not derive and resolve only when declared.
const _derivedRoles = <String>[
  'primary', 'onPrimary', 'primaryContainer', 'onPrimaryContainer',
  'secondary', 'onSecondary', 'secondaryContainer', 'onSecondaryContainer',
  'tertiary', 'onTertiary', 'tertiaryContainer', 'onTertiaryContainer',
  'error', 'onError', 'errorContainer', 'onErrorContainer',
  'surface', 'onSurface', 'onSurfaceVariant', 'surfaceTint',
  'surfaceBright', 'surfaceDim',
  'surfaceContainerLowest', 'surfaceContainerLow', 'surfaceContainer',
  'surfaceContainerHigh', 'surfaceContainerHighest',
  'outline', 'outlineVariant',
  'inverseSurface', 'onInverseSurface', 'inversePrimary',
  'scrim', 'shadow',
  // §5.3.1 legacy spellings.
  'background', 'onBackground', 'surfaceVariant', 'inverseOnSurface',
];

const _semanticRoles = <String>[
  'success', 'onSuccess', 'warning', 'onWarning', 'info', 'onInfo',
];

void main() {
  group('a seed-only theme derives every role', () {
    late ThemeManager manager;

    setUp(() {
      // The minimum a bundle may declare (§5.3.2). Everything else derives —
      // that is the promise, and it has to hold from both positions.
      manager = ThemeManager()
        ..setTheme(<String, dynamic>{
          'color': <String, dynamic>{'seed': '#3F51B5'},
        });
    });

    test('`color: "<role>"` resolves to a colour', () {
      final empty = <String>[];
      for (final role in _derivedRoles) {
        if (manager.getColorValue(role) == null) empty.add(role);
      }
      expect(empty, isEmpty,
          reason: 'these roles painted nothing: $empty');
    });

    test('`{{theme.color.<role>}}` resolves to a value', () {
      // The half that was broken. A binding that resolves to null renders as
      // an empty string, which is why nothing looked wrong.
      final empty = <String>[];
      for (final role in _derivedRoles) {
        final v = manager.getThemeValue('color.$role');
        if (v == null || v.toString().isEmpty) empty.add(role);
      }
      expect(empty, isEmpty,
          reason: 'these roles read as empty from a binding: $empty');
    });

    test('a legacy role answers as the role it resolves to', () {
      // Not "the two positions return equal objects" — one yields a hex
      // string and the other a parsed colour. The claim §5.3.1 makes is
      // narrower and checkable: a legacy name means its replacement.
      const pairs = <String, String>{
        'background': 'surface',
        'onBackground': 'onSurface',
        'inverseOnSurface': 'onInverseSurface',
        'surfaceVariant': 'surfaceContainerHighest',
      };
      pairs.forEach((legacy, canonical) {
        expect(manager.getColorValue(legacy),
            equals(manager.getColorValue(canonical)),
            reason: '`color: "$legacy"` must paint what "$canonical" paints');
        expect(manager.getThemeValue('color.$legacy'),
            equals(manager.getThemeValue('color.$canonical')),
            reason: '{{theme.color.$legacy}} must read what "$canonical" reads');
      });
    });

    test('the semantic six resolve only once declared', () {
      // They have no Material 3 counterpart to derive from, which §5.3.1 now
      // says out loud. Asserted so the day one of them starts deriving is a
      // decision rather than a surprise.
      for (final role in _semanticRoles) {
        expect(manager.getColorValue(role), isNull,
            reason: '"$role" has nothing to derive from');
      }

      final declared = ThemeManager()
        ..setTheme(<String, dynamic>{
          'color': <String, dynamic>{'seed': '#3F51B5', 'success': '#2E7D32'},
        });
      expect(declared.getColorValue('success'), isNotNull);
      expect(declared.getThemeValue('color.success'), '#2E7D32');
    });
  });

  test('a declared role wins over the derived one', () {
    final manager = ThemeManager()
      ..setTheme(<String, dynamic>{
        'color': <String, dynamic>{'seed': '#3F51B5', 'primary': '#FF0000'},
      });
    expect(manager.getThemeValue('color.primary'), '#FF0000');
    expect(manager.getColorValue('primary'), isNotNull);
    expect(manager.getColorValue('primary'),
        isNot(equals(manager.getColorValue('secondary'))));
  });

  test('declaring a retired role does not take, and does not do so quietly',
      () {
    // konpi set `background` to magenta and got their `surface` back with no
    // word said. Reading the role still works — that is why §5.3.1 keeps it —
    // but the value written here is parsed away, and an author who cannot see
    // that concludes the theme is being ignored somewhere else.
    final manager = ThemeManager()
      ..setTheme(<String, dynamic>{
        'color': <String, dynamic>{
          'seed': '#3F51B5',
          'surface': '#FFFFFF',
          'background': '#FF00FF',
        },
      });

    expect(manager.getColorValue('background'),
        equals(manager.getColorValue('surface')),
        reason: 'the declared magenta is not applied; the role paints as '
            '`surface`, which §5.3.1 says it resolves to');
    expect(manager.getThemeValue('color.background'), isNot('#FF00FF'),
        reason: 'reading it back must not suggest the declaration took');

    // The two answers are the same colour in different spellings: a declared
    // role reads back as the author wrote it, a derived one as `#AARRGGBB`.
    // Documents that compare colour *strings* would see a difference where
    // there is none, so it is stated rather than left to be discovered.
    expect(manager.getThemeValue('color.surface'), '#FFFFFF');
    expect(manager.getThemeValue('color.background'), '#FFFFFFFF');
  });
}
