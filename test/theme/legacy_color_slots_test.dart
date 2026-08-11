// §5.3.1 legacy colour spellings resolve.
//
// Material 3 folded the background family into the surface family and retired
// `surfaceVariant`; `inverseOnSurface` is the earlier spelling of
// `onInverseSurface`. §5.3.1 keeps all four documented, so a document written
// against an earlier draft must still get a colour rather than silently
// falling back to the widget's default.
//
// The schema was widened for these at the same time. Widening the schema
// without teaching the runtime to resolve them would produce the failure this
// cycle already made once: validation says the document is fine and the screen
// shows nothing.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  group('legacy colour slots derive from seed', () {
    late ThemeManager manager;

    setUp(() {
      manager = ThemeManager();
      manager.setTheme(<String, dynamic>{
        'color': <String, dynamic>{'seed': '#3F51B5'},
      });
    });

    test('each legacy name resolves to its Material 3 replacement', () {
      final pairs = <String, String>{
        'background': 'surface',
        'onBackground': 'onSurface',
        'surfaceVariant': 'surfaceContainerHighest',
        'inverseOnSurface': 'onInverseSurface',
      };
      pairs.forEach((legacy, canonical) {
        final legacyValue = manager.getColorValue(legacy);
        final canonicalValue = manager.getColorValue(canonical);
        expect(legacyValue, isNotNull,
            reason: '"$legacy" is documented in §5.3.1 and must resolve');
        expect(legacyValue, equals(canonicalValue),
            reason: '"$legacy" must resolve as "$canonical"');
      });
    });

    test('a binding into the theme map answers the same as a colour property',
        () {
      // konpi drew all four on one screen and three came back empty:
      // `parseColor` resolves a bare slot name through the scheme, but
      // `{{theme.color.background}}` goes through `getThemeValue`, and
      // `ColorSchemeDefinition` carries no `background` field at all — M3
      // folded that family into surface. The same name answered in one
      // position and was empty in the other, which is worse than either
      // answer alone.
      final pairs = <String, String>{
        'background': 'surface',
        'onBackground': 'onSurface',
        'inverseOnSurface': 'onInverseSurface',
        'surfaceVariant': 'surfaceContainerHighest',
      };
      pairs.forEach((legacy, canonical) {
        final viaBinding = manager.getThemeValue('color.$legacy');
        expect(viaBinding, isNotNull,
            reason: '{{theme.color.$legacy}} is documented in §5.3.1');
        expect(viaBinding, equals(manager.getThemeValue('color.$canonical')),
            reason: '"$legacy" must read as "$canonical"');
      });
    });

    test('a theme that declares a legacy role keeps its own value', () {
      // The alias is a fallback, not an override: an author who writes
      // `surfaceVariant` explicitly gets what they wrote.
      final declared = ThemeManager();
      declared.setTheme(<String, dynamic>{
        'color': <String, dynamic>{
          'seed': '#3F51B5',
          'surfaceVariant': '#123456',
        },
      });
      expect(declared.getThemeValue('color.surfaceVariant'), '#123456');
    });

    test('a name that is not a role still resolves to null', () {
      // The point of the mapping is the four documented spellings, not a
      // general tolerance for unknown words.
      expect(manager.getColorValue('notacolor'), isNull);
      expect(manager.getColorValue('tomato'), isNull);
    });
  });
}
