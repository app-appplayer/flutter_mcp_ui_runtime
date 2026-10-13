// Every value a registry property declares in `enum` is one the runtime
// handles — the contract the schema makes to an author who picks one.
//
// The failure this stops is a value that validates, renders without an
// error, and silently draws the default: nothing crashes, so a render test
// passes. Two oracles:
//
//  * `text.variant` is resolved by name through the theme, not by a literal
//    in the factory — every declared role must give a style.
//  * Every other enum value must appear as a literal in the runtime source.
//    A value the runtime never names cannot have a branch of its own.
//
// Widgets that hand their properties to a host surface (`map`: tiles,
// overlays) are the host's to honour and are skipped.

import 'dart:io';

import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Properties forwarded whole to a host-provided surface.
const _hostSurfaceWidgets = {'map'};

/// Properties resolved by name through the theme rather than a literal.
const _themeResolved = {'text': 'variant'};

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

class _Enum {
  _Enum(this.widget, this.property, this.values);
  final String widget;
  final String property;
  final List<String> values;
}

List<_Enum> _registryEnums() {
  final dir = Directory(
      p.join(_repoRoot(), 'specs', 'mcp_ui_dsl', 'spec', '1.4', 'widgets'));
  final out = <_Enum>[];
  for (final f in dir.listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.yaml')) continue;
    final doc = loadYaml(f.readAsStringSync());
    if (doc is! YamlMap || doc['type'] is! String) continue;
    final props = doc['properties'];
    if (props is! YamlMap) continue;
    for (final e in props.entries) {
      final spec = e.value;
      if (spec is YamlMap && spec['enum'] is YamlList) {
        out.add(_Enum(doc['type'] as String, e.key as String,
            [for (final v in spec['enum'] as YamlList) '$v']));
      }
    }
  }
  return out;
}

String _runtimeSource() {
  final b = StringBuffer();
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is File && f.path.endsWith('.dart')) b.write(f.readAsStringSync());
  }
  return b.toString();
}

void main() {
  final enums = _registryEnums();

  test('the registry declares enums to check', () {
    expect(enums.length, greaterThan(50),
        reason: 'a registry read that finds nothing would pass everything');
  });

  test('every enum value has a literal in the runtime', () {
    final source = _runtimeSource();
    final missing = <String>[];
    for (final e in enums) {
      if (_hostSurfaceWidgets.contains(e.widget)) continue;
      if (_themeResolved[e.widget] == e.property) continue;
      for (final v in e.values) {
        if (!source.contains("'$v'") && !source.contains('"$v"')) {
          missing.add('${e.widget}.${e.property} = $v');
        }
      }
    }
    expect(missing, isEmpty,
        reason: 'declared but never named by the runtime: ${missing.join(', ')}');
  });

  test('every text.variant role resolves through the theme', () {
    final theme = ThemeManager.instance..reset();
    addTearDown(theme.reset);
    final variants = enums
        .where((e) => e.widget == 'text' && e.property == 'variant')
        .expand((e) => e.values)
        .toList();
    expect(variants, isNotEmpty);
    final unresolved = [
      for (final v in variants)
        if (theme.getTextStyleValue(v)?.fontSize == null) v,
    ];
    expect(unresolved, isEmpty,
        reason: 'roles the default theme does not style: $unresolved');
  });
}
