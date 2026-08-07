// Does the published registry still open bundles authored before it?
//
// The runtime validates a document at load, so a schema narrowing does not
// merely stop an author — it stops an existing bundle from opening. This
// probe answers the question directly: walk the sample corpus, validate every
// widget-shaped node the way the runtime does, and report which bundles would
// fail to open.
//
// Run against whichever registry you want to judge — with a path override for
// the local tree, without one for the published cut:
//   flutter test test/spec_compliance/bundle_open_probe.dart -r expanded
//
// Not named `_test.dart` on purpose: it reads a corpus outside the package
// and is a measurement, not a gate.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart';

const corpus = '../../../../content/sample';

void main() {
  test('bundles open', () {
    final root = Directory(corpus);
    if (!root.existsSync()) {
      // ignore: avoid_print
      print('PROBE: corpus not found at $corpus');
      return;
    }

    var files = 0, nodes = 0;
    final failures = <String, List<String>>{};

    // Validate exactly what the loader validates: the `content` subtree of a
    // document. Everything else that carries a `type` — `application`, `page`,
    // and every action (`{type: tool}`, `{type: state}`, …) — is not a widget
    // and is not checked against the Widget union. A first version of this
    // probe counted all of them and reported 25 "broken" bundles that are
    // nothing of the kind; the corpus was fine and the measurement was not.
    void check(Object? node, String origin, String path) {
      if (node is List) {
        for (var i = 0; i < node.length; i++) {
          check(node[i], origin, '$path[$i]');
        }
        return;
      }
      if (node is! Map) return;
      final content = node['content'];
      if (content is Map && content['type'] is String) {
        nodes++;
        final r = validateMcpUiDslWidget(Map<String, dynamic>.from(content));
        if (!r.isValid) {
          failures.putIfAbsent(origin, () => <String>[]).add(
              '$path.content <${content['type']}>: '
              '${r.errors.first.message.split('\n').first}');
        }
      }
      for (final entry in node.entries) {
        if (entry.key == 'content') continue;
        check(entry.value, origin, '$path.${entry.key}');
      }
    }

    for (final f in root.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.json')) continue;
      if (f.path.contains('/vendor/') || f.path.contains('/build/')) continue;
      Object? doc;
      try {
        doc = jsonDecode(f.readAsStringSync());
      } catch (_) {
        continue;
      }
      files++;
      final name = f.path.substring(root.path.length + 1);
      check(doc, name.split('/').first, name);
    }

    final buf = StringBuffer()
      ..writeln('PROBE_BEGIN')
      ..writeln('json files: $files · widget nodes: $nodes')
      ..writeln('bundles with a node the registry rejects: ${failures.length}');
    failures.forEach((sample, errs) {
      buf.writeln('  $sample — ${errs.length}');
      for (final e in errs.take(3)) {
        buf.writeln('      $e');
      }
    });
    buf.writeln('PROBE_END');
    // ignore: avoid_print
    print(buf);
  });
}
