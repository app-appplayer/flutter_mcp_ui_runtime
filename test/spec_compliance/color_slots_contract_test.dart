// Every scheme slot the `Color` primitive declares resolves to a colour.
//
// §5.3.4 makes `configs/_primitive/Color.yaml` the one set: a document may
// name any slot listed there. A slot the runtime does not know validates,
// loads, and paints nothing — so this reads the primitive itself and asks the
// runtime's own resolver (the one every widget uses) for each slot, in both
// modes. The six semantic roles have no Material 3 counterpart and resolve
// to the widget's own default until the theme declares them (§5.3.1), so
// they are checked declared.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/utils/color_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

String _repoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 12; i++) {
    if (Directory(p.join(dir.path, 'specs', 'mcp_ui_dsl')).existsSync()) {
      return dir.path;
    }
    if (dir.parent.path == dir.path) break;
    dir = dir.parent;
  }
  throw StateError('specs/mcp_ui_dsl not found above ${Directory.current}');
}

/// The slot names of the primitive's `enum` branch.
List<String> _declaredSlots() {
  final file = File(p.join(_repoRoot(), 'specs', 'mcp_ui_dsl', 'spec', '1.4',
      'configs', '_primitive', 'Color.yaml'));
  final doc = jsonDecode(jsonEncode(loadYaml(file.readAsStringSync())));
  final slots = <String>[];
  void walk(Object? node) {
    if (node is Map) {
      final e = node['enum'];
      if (e is List && e.isNotEmpty && e.every((v) => v is String)) {
        slots.addAll(e.cast<String>());
      }
      node.values.forEach(walk);
    } else if (node is List) {
      node.forEach(walk);
    }
  }

  walk(doc);
  return slots;
}

/// §5.3.1: no M3 counterpart — the widget's default until declared.
const _semantic = {
  'success',
  'onSuccess',
  'warning',
  'onWarning',
  'info',
  'onInfo',
};

void main() {
  final slots = _declaredSlots();

  test('the primitive declares the M3 slot set', () {
    expect(slots, containsAll(['primary', 'onSurface', 'surfaceContainer']));
  });

  for (final mode in ['light', 'dark']) {
    test('every declared slot paints a colour in $mode mode', () {
      final theme = ThemeManager.instance..reset();
      addTearDown(theme.reset);
      theme.setTheme(<String, dynamic>{'mode': mode});
      final unresolved = [
        for (final s in slots)
          if (!_semantic.contains(s) &&
              DslColor.parse(s, slotResolver: theme.getColorValue) == null)
            s,
      ];
      expect(unresolved, isEmpty,
          reason: 'declared slots that paint nothing: $unresolved');
    });
  }

  test('a semantic role the theme declares paints that colour', () {
    final theme = ThemeManager.instance..reset();
    addTearDown(theme.reset);
    theme.setTheme(<String, dynamic>{
      'color': {for (final s in _semantic) s: '#123456'},
    });
    final unresolved = [
      for (final s in _semantic)
        if (DslColor.parse(s, slotResolver: theme.getColorValue)?.toARGB32() !=
            0xFF123456)
          s,
    ];
    expect(unresolved, isEmpty,
        reason: 'declared but not painted: $unresolved');
  });

  test('every §5.3.1 role a theme declares paints that colour', () {
    final md = File(p.join(
            _repoRoot(), 'specs', 'mcp_ui_dsl', 'spec', '1.4', '05_Theme.md'))
        .readAsStringSync();
    final section =
        md.substring(md.indexOf('### 5.3.1'), md.indexOf('### 5.3.2'));
    final roles = [
      for (final m
          in RegExp(r'^\| `(\w+)` \|', multiLine: true).allMatches(section))
        m.group(1)!,
    ];
    expect(roles.length, greaterThan(40));
    for (final mode in ['light', 'dark']) {
      final theme = ThemeManager.instance..reset();
      theme.setTheme(<String, dynamic>{
        'mode': mode,
        'color': {for (final r in roles) r: '#123456'},
      });
      final wrong = [
        for (final r in roles)
          if (DslColor.parse(r, slotResolver: theme.getColorValue)
                  ?.toARGB32() !=
              0xFF123456)
            r,
      ];
      theme.reset();
      expect(wrong, isEmpty, reason: '$mode: declared but not painted: $wrong');
    }
  });
}
