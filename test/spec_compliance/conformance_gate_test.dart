// MCP UI DSL conformance gate, exercised from the runtime test suite so
// `flutter test` alone can confirm spec ↔ factory parity.
//
// Each case shells out to the matching script under `tools/spec_codegen/bin/`
// and asserts exit code 0. The external tool is the source of truth; this
// test is only a pointer so developers don't accidentally run flutter tests
// in isolation and miss a spec drift.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  // The Process.run invocations below are blocking + short-lived so
  // declaring them inside `test` blocks is fine.

  late String repoRoot;
  setUpAll(() {
    repoRoot = _findRepoRoot();
  });

  group('spec conformance gate', () {
    test('drift_audit --strict reports zero drift', () async {
      final result = await Process.run(
        'dart',
        ['run', 'tools/spec_codegen/bin/drift_audit.dart', '--strict'],
        workingDirectory: repoRoot,
      );
      printOnFailure('stdout:\n${result.stdout}');
      printOnFailure('stderr:\n${result.stderr}');
      expect(result.exitCode, 0,
          reason: 'drift_audit --strict returned ${result.exitCode}');
    });

    test('validate_examples reports no failing YAML example', () async {
      final result = await Process.run(
        'dart',
        ['run', 'tools/spec_codegen/bin/validate_examples.dart'],
        workingDirectory: repoRoot,
      );
      printOnFailure('stdout:\n${result.stdout}');
      printOnFailure('stderr:\n${result.stderr}');
      expect(result.exitCode, 0,
          reason: 'validate_examples returned ${result.exitCode}');
    });
  });
}

String _findRepoRoot() {
  var dir = Directory.current;
  while (true) {
    if (Directory(p.join(dir.path, 'specs', 'mcp_ui_dsl')).existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Repo root not found from ${Directory.current.path}');
    }
    dir = parent;
  }
}
