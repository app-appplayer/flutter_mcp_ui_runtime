// Full rendering audit for demo_ui fixtures.
//
// Loads every page fixture emitted by apps/demo_ui through MCPUIRuntime
// with validateSchema=true default and pumps it into a real widget tree to
// surface rendering, binding, and factory issues (RenderFlex overflow,
// unresolved bindings, missing factories, etc.).
//
// Failures from FlutterError handlers are collected per page so a single
// page's issues don't mask the others.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:path/path.dart' as p;

void main() {
  // Fixtures live in apps/demo_ui/test/fixtures relative to repo root.
  late final String repoRoot;
  late final Directory fixtureDir;

  setUpAll(() {
    repoRoot = _findRepoRoot();
    fixtureDir = Directory(
      p.join(repoRoot, 'apps', 'demo_ui', 'test', 'fixtures'),
    );
    expect(fixtureDir.existsSync(), isTrue,
        reason: 'demo_ui fixtures dir not found at ${fixtureDir.path}');
  });

  // Each page fixture gets its own test so diagnostics are localized.
  final pageFixtures = <String>[
    'layout', 'display', 'input', 'list', 'navigation', 'scroll',
    'interactive', 'dialog', 'form', 'charts', 'advanced', 'media',
    'realtime', 'dev',
  ];

  for (final name in pageFixtures) {
    testWidgets('demo_ui page "$name" renders cleanly', (tester) async {
      final file = File(p.join(fixtureDir.path, '$name.json'));
      expect(file.existsSync(), isTrue,
          reason: 'missing fixture $name.json');
      final definition =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      final errors = <FlutterErrorDetails>[];
      final prev = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      // Use a real desktop-sized viewport (1280x800) so pages that
      // legitimately need more than the test default 800x600 can render
      // without spurious overflow.
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final runtime = MCPUIRuntime();
      try {
        await runtime.initialize(definition);
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: runtime.buildUI())),
        );
        // One extra frame so post-layout errors (Scrollbar, RenderFlex
        // overflow) surface.
        await tester.pump(const Duration(milliseconds: 50));
      } finally {
        FlutterError.onError = prev;
        await runtime.dispose();
      }

      if (errors.isNotEmpty) {
        final summary = errors.take(5).map((e) {
          final msg = e.exceptionAsString();
          final ctx = e.context?.toDescription() ?? '';
          final libraryName = e.library ?? '';
          return '[$libraryName] $msg\n      ctx: $ctx';
        }).join('\n  - ');
        fail('Page "$name" surfaced ${errors.length} rendering error(s):\n'
            '  - $summary');
      }
    });
  }
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
