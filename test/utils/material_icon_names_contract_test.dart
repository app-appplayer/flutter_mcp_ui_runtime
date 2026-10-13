// The icon-name contract: icon_resolver.dart promises every name of
// Flutter's `Icons` (and the font's own name where it differs, `10k`,
// `class`). This reads the SDK's icons.dart directly — independent of the
// generator — and resolves every declaration, so a name the runtime does not
// know fails here instead of drawing the missing-icon cue in an app.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/utils/icon_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

class _Declared {
  _Declared(this.identifier, this.codePoint, this.matchTextDirection);
  final String identifier;
  final int codePoint;
  final bool matchTextDirection;
}

List<_Declared> _sdkIcons() {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) {
    throw StateError('FLUTTER_ROOT is not set; run under `flutter test`.');
  }
  final source = File('$root/packages/flutter/lib/src/material/icons.dart')
      .readAsStringSync();
  final decl = RegExp(
      r'static const IconData (\w+) = IconData\(\s*(0x[0-9a-fA-F]+),([^;]*?)\);');
  return [
    for (final m in decl.allMatches(source))
      _Declared(m.group(1)!, int.parse(m.group(2)!),
          m.group(3)!.contains('matchTextDirection: true')),
  ];
}

void main() {
  final declared = _sdkIcons();

  test('the SDK declares the full Material set', () {
    expect(declared.length, greaterThan(8000),
        reason: 'a parse that finds a handful would pass everything below');
  });

  test('every Icons name resolves to its own glyph', () {
    final wrong = <String>[];
    for (final d in declared) {
      final got = resolveIconData(d.identifier);
      if (got.codePoint != d.codePoint ||
          got.fontFamily != 'MaterialIcons' ||
          got.matchTextDirection != d.matchTextDirection) {
        wrong.add(d.identifier);
      }
    }
    expect(wrong, isEmpty,
        reason: '${wrong.length} of ${declared.length} names do not resolve; '
            'first: ${wrong.take(10).join(', ')}');
  });

  test("the font's own names resolve where they are not Dart identifiers", () {
    expect(resolveIconData('10k').codePoint, Icons.ten_k.codePoint);
    expect(resolveIconData('class').codePoint, Icons.class_.codePoint);
    expect(resolveIconData('3d_rotation').codePoint,
        Icons.threed_rotation.codePoint);
  });

  test('the names that drew the missing-icon cue in a workspace app', () {
    expect(resolveIconData('fact_check').codePoint, Icons.fact_check.codePoint);
    expect(resolveIconData('groups').codePoint, Icons.groups.codePoint);
  });

  test('an unknown name still draws the missing-icon cue', () {
    expect(resolveIconData('no_such_icon_name'), Icons.help_outline);
  });
}
