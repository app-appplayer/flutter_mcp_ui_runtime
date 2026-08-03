// `IconRef` resolves to the icon the document names — not merely to *an* icon.
//
// `widget_union_branch_test` proves every IconRef branch draws without
// throwing, and that is not enough: a factory that silently answers every
// object form with `Icons.help_outline` also draws without throwing. These
// assertions pin the resolved glyph, so dropping the codepoint branch fails
// here even though the frame stays clean.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/utils/icon_resolver.dart';

void main() {
  group('resolveIconRef', () {
    test('name form resolves through the icon table', () {
      expect(resolveIconRef('home'), Icons.home);
    });

    test('codepoint form resolves to that codepoint', () {
      final resolved = resolveIconRef(<String, dynamic>{'codepoint': 0xe88a});
      expect(resolved.codePoint, 0xe88a);
      expect(resolved.fontFamily, 'MaterialIcons');
      // The fallback would answer here too, so the distinguishing assertion
      // is that it is *not* the fallback.
      expect(resolved.codePoint, isNot(Icons.help_outline.codePoint));
    });

    test('codepoint form carries a custom font', () {
      final resolved = resolveIconRef(<String, dynamic>{
        'codepoint': 0xe900,
        'fontFamily': 'CustomIcons',
        'fontPackage': 'my_pack',
      });
      expect(resolved.codePoint, 0xe900);
      expect(resolved.fontFamily, 'CustomIcons');
      expect(resolved.fontPackage, 'my_pack');
    });

    test('object form with a name resolves through the table', () {
      expect(resolveIconRef(<String, dynamic>{'name': 'search'}), Icons.search);
    });

    test('resource form has no IconData and falls back visibly', () {
      // Nothing to resolve to — a slot that can draw an image reaches for
      // AssetRef itself; one that cannot gets the missing-icon cue.
      expect(resolveIconRef(<String, dynamic>{'uri': 'ui://icons/home'}),
          Icons.help_outline);
    });

    test('unknown name falls back rather than throwing', () {
      expect(resolveIconRef('no_such_icon_name'), Icons.help_outline);
      expect(resolveIconRef(null), Icons.help_outline);
      expect(resolveIconRef(42), Icons.help_outline);
    });
  });
}
