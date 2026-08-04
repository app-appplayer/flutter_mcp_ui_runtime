// One icon vocabulary, not three.
//
// The page renderer carried its own 580-line switch: two names drew a
// different glyph than the shared map, and 186 short forms existed only there,
// so `icon: "car"` worked on an app bar and drew the missing-icon cue in a
// widget. These pin the merged behaviour — canonical names win, the legacy
// short forms still resolve, and an unknown name is still an obvious cue.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/utils/icon_resolver.dart';

void main() {
  group('canonical Material names', () {
    test('resolve to their own icon', () {
      expect(resolveIconData('home'), Icons.home);
      expect(resolveIconData('settings'), Icons.settings);
      expect(resolveIconData('camera'), Icons.camera,
          reason: 'the resolver documents snake_case names matching Flutter\'s '
              'Icons class; the renderer\'s private table said camera_alt and '
              'that is the drift being closed');
      expect(resolveIconData('copy'), Icons.copy);
    });

    test('are matched case-insensitively and tolerate the material: prefix',
        () {
      expect(resolveIconData('HOME'), Icons.home);
      expect(resolveIconData('material:home'), Icons.home);
    });
  });

  group('legacy short forms', () {
    test('still resolve, and now resolve everywhere', () {
      expect(resolveIconData('car'), Icons.directions_car);
      expect(resolveIconData('cafe'), Icons.local_cafe);
      expect(resolveIconData('calendar'), Icons.calendar_today);
      expect(resolveIconData('walk'), Icons.directions_walk);
      expect(resolveIconData('wallet'), Icons.account_balance_wallet);
    });

    test('do not shadow a canonical name of the same spelling', () {
      // `search` exists in both tables and must keep the canonical mapping.
      expect(resolveIconData('search'), Icons.search);
    });
  });

  group('IconRef object forms (§2.5 primitive)', () {
    test('a codepoint object builds its own IconData', () {
      final icon = resolveIconRef(<String, dynamic>{
        'codepoint': 0xe88a,
        'fontFamily': 'MaterialIcons',
      });
      expect(icon.codePoint, 0xe88a);
      expect(icon.fontFamily, 'MaterialIcons');
    });

    test('a name object resolves like a bare name', () {
      expect(resolveIconRef(<String, dynamic>{'name': 'home'}), Icons.home);
    });

    test('a resource object has no glyph and falls back visibly', () {
      expect(resolveIconRef(<String, dynamic>{'uri': 'bundle://a.png'}),
          Icons.help_outline);
    });
  });

  group('unknown input', () {
    test('is an obvious cue rather than a blank', () {
      expect(resolveIconData('definitely_not_an_icon'), Icons.help_outline);
      expect(resolveIconRef(null), Icons.help_outline);
      expect(resolveIconRef(42), Icons.help_outline);
      expect(resolveIconData(''), Icons.help_outline);
    });
  });
}
