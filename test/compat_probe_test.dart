// Backward-compatibility harness.
//
// The validator builds its schema with `JsonSchema.create(<string>)`, so the
// same engine can be pointed at any published registry. This runs the real
// document corpus through three of them — the last pre-1.4 release, the
// current published one, and the working tree — and reports what each verdict
// change actually is. Comparing only against the published 0.5.1 would hide
// whatever the 1.4 cut itself narrowed, which is the part a document written
// before that cut would feel.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema/json_schema.dart';

String? _schemaFromDartConstant(File f) {
  if (!f.existsSync()) return null;
  final src = f.readAsStringSync();
  final start = src.indexOf("mcpUiDslWidgetsSchemaJson = '");
  if (start < 0) return null;
  final open = src.indexOf("'", start + "mcpUiDslWidgetsSchemaJson = ".length);
  final end = src.lastIndexOf("';");
  if (open < 0 || end <= open) return null;
  final raw = src.substring(open + 1, end);
  // Decode the Dart string literal in one pass: `\\`, `\'` and `\$` are the
  // only escapes the generator emits, and replacing them independently turns
  // `\\{` (a literal backslash before a brace, common in the regex patterns)
  // into something that is no longer JSON.
  final buf = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final c = raw[i];
    if (c == r'\' && i + 1 < raw.length) {
      buf.write(raw[i + 1]);
      i++;
    } else {
      buf.write(c);
    }
  }
  return buf.toString();
}

/// Every `type` the *current* registry defines, aliases included.
Set<String> _knownTypes(String schemaText, {bool widgetsOnly = false}) {
  final defs = (jsonDecode(schemaText) as Map<String, dynamic>)[r'$defs']
      as Map<String, dynamic>;
  final out = <String>{};
  void collect(Object? node) {
    if (node is Map<String, dynamic>) {
      final props = node['properties'];
      if (props is Map<String, dynamic>) {
        final t = props['type'];
        if (t is Map<String, dynamic> && t['enum'] is List) {
          out.addAll((t['enum'] as List).cast<String>());
        }
      }
      // `Action` is an `anyOf` now (object | list | binding), so its type enum
      // lives one level down. A masking set that misses it treats every action
      // map as an unknown widget and rewrites the document.
      for (final key in const ['anyOf', 'oneOf', 'allOf']) {
        final branches = node[key];
        if (branches is List) branches.forEach(collect);
      }
    }
  }

  for (final e in defs.entries) {
    if (e.key == 'Action' && widgetsOnly) continue;
    collect(e.value);
  }
  return out;
}

Object? _mask(Object? node, Set<String> known) {
  if (node is Map<String, dynamic>) {
    final t = node['type'];
    if (t is String && !known.contains(t)) {
      return <String, dynamic>{'type': 'box'};
    }
    return <String, dynamic>{
      for (final e in node.entries) e.key: _mask(e.value, known),
    };
  }
  if (node is List) return node.map((e) => _mask(e, known)).toList();
  return node;
}

void main() {
  test('corpus verdicts across releases', () {
    final home = Platform.environment['HOME']!;
    final cache = '$home/.pub-cache/hosted/pub.dev';
    final repo = Directory.current.path.split('/packages/')[0];

    final sources = <String, String?>{
      '0.4.3 (pre-1.4)': _schemaFromDartConstant(File(
          '$cache/flutter_mcp_ui_core-0.4.3/lib/src/schema/widgets_schema.g.dart')),
      '0.5.1 (published)': _schemaFromDartConstant(File(
          '$cache/flutter_mcp_ui_core-0.5.1/lib/src/schema/widgets_schema.g.dart')),
      'working tree': File(
              '$repo/specs/mcp_ui_dsl/spec/1.4/schema/widgets.schema.json')
          .readAsStringSync(),
    };

    final schemas = <String, JsonSchema>{};
    sources.forEach((name, text) {
      if (text == null) {
        // ignore: avoid_print
        print('MISSING $name');
        return;
      }
      schemas[name] = JsonSchema.create(text);
    });

    final knownTypes = _knownTypes(sources['working tree']!);
    final widgetTypes =
        _knownTypes(sources['working tree']!, widgetsOnly: true);

    final docs = (jsonDecode(File('/tmp/dsl_docs.json').readAsStringSync())
            as List)
        .cast<String>()
        .where((p) => !p.contains('/tools/legacy/'))
        .toList();

    final verdicts = <String, Map<String, bool>>{
      for (final k in schemas.keys) k: <String, bool>{},
    };
    final messages = <String, List<String>>{};

    for (final rel in docs) {
      final path = rel.startsWith('./') ? rel.substring(2) : rel;
      final f = File('$repo/$path');
      if (!f.existsSync()) continue;
      Object? content;
      try {
        content = (jsonDecode(f.readAsStringSync()) as Map)['content'];
      } catch (_) {
        continue;
      }
      if (content is! Map<String, dynamic>) continue;
      // The runtime masks host-registered extensions before validating
      // (`_maskExtensions`): offering `registerWidget` and then refusing what
      // it produces would be a contract disagreeing with itself. A harness
      // that skips that step measures a rejection the product does not make,
      // so unknown types are masked here the same way.
      final masked = _mask(content, knownTypes);
      schemas.forEach((name, schema) {
        final r = schema.validate(masked);
        verdicts[name]![rel] = r.isValid;
        if (name == 'working tree' && !r.isValid) {
          messages[rel] =
              r.errors.take(2).map((e) => '${e.instancePath}: ${e.message}').toList();
        }
      });
    }

    final out = <String, dynamic>{
      'verdicts': verdicts,
      'messages': messages,
    };
    File(Platform.environment['COMPAT_OUT'] ?? '/tmp/compat_matrix.json')
        .writeAsStringSync(jsonEncode(out));

    // Phase 2: for every document the pre-1.4 registry accepted and this one
    // does not, find the *deepest* node that fails. Parents fail too — the
    // union reports "nothing matched" all the way up — so the deepest failing
    // node is the one that actually changed meaning.
    final oldV = verdicts['0.4.3 (pre-1.4)']!;
    final nowV = verdicts['working tree']!;
    final regressed =
        oldV.keys.where((k) => oldV[k] == true && nowV[k] == false).toList();
    final causes = <String, int>{};
    final current = schemas['working tree']!;
    for (final rel in regressed) {
      final path = rel.startsWith('./') ? rel.substring(2) : rel;
      final content =
          (jsonDecode(File('$repo/$path').readAsStringSync()) as Map)['content'];
      final masked = _mask(content, knownTypes);
      String? deepest;
      var deepestAt = -1;
      void walk(Object? n, int depth) {
        if (n is Map<String, dynamic>) {
          final t = n['type'];
          if (t is String && widgetTypes.contains(t)) {
            final r = current.validate(n);
            if (!r.isValid && depth > deepestAt) {
              deepestAt = depth;
              final first = r.errors.isEmpty ? '' : r.errors.first.message;
              deepest = '$t | ${first.length > 60 ? first.substring(0, 60) : first}';
            }
          }
          for (final v in n.values) {
            walk(v, depth + 1);
          }
        } else if (n is List) {
          for (final v in n) {
            walk(v, depth + 1);
          }
        }
      }
      walk(masked, 0);
      final key = deepest ?? '(root only)';
      causes[key] = (causes[key] ?? 0) + 1;
    }
    // ignore: avoid_print
    print('REGRESSED docs=${regressed.length}');
    final sorted = causes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sorted.take(12)) {
      // ignore: avoid_print
      print('  CAUSE ${e.key} x${e.value}');
    }

    verdicts.forEach((name, m) {
      // ignore: avoid_print
      print('COMPAT $name: ${m.length} docs, ${m.values.where((v) => v).length} valid');
    });
  });
}
