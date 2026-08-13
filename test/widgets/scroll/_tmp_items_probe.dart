// TEMPORARY PROBE — delete after the run.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart'
    show validateMcpUiDslWidget;
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

Future<void> probe(WidgetTester tester, String label,
    Map<String, dynamic> content) async {
  final schemaOk = validateMcpUiDslWidget(content).isValid;
  final runtime = MCPUIRuntime();
  var loaded = true;
  try {
    await runtime.initialize({'type': 'page', 'content': content});
  } catch (_) {
    loaded = false;
  }
  var painted = 'n/a';
  if (loaded) {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: KeyedSubtree(key: UniqueKey(), child: runtime.buildUI()))));
    await tester.pump();
    painted = find.text('ALPHA').evaluate().isNotEmpty ? 'DREW' : 'blank';
  }
  debugPrint('PROBE ${label.padRight(34)} schema=${schemaOk ? "ok" : "reject"} '
      'load=${loaded ? "ok" : "throw"} $painted');
  if (loaded) await runtime.dispose();
}

void main() {
  const item = {'type': 'text', 'content': 'ALPHA'};

  testWidgets('sliverList items as widgets, no template', (t) async {
    await probe(t, 'sliverList items=[widget]', {
      'type': 'scrollView',
      'slivers': [
        {'type': 'sliverList', 'items': [item]}
      ]
    });
  });

  testWidgets('sliverList children', (t) async {
    await probe(t, 'sliverList children=[widget]', {
      'type': 'scrollView',
      'slivers': [
        {'type': 'sliverList', 'children': [item]}
      ]
    });
  });

  testWidgets('list items as widgets, no template', (t) async {
    await probe(t, 'list items=[widget]', {'type': 'list', 'items': [item]});
  });

  testWidgets('list children', (t) async {
    await probe(t, 'list children=[widget]', {'type': 'list', 'children': [item]});
  });

  testWidgets('grid items as widgets, no template', (t) async {
    await probe(t, 'grid items=[widget]', {'type': 'grid', 'columns': 2, 'items': [item]});
  });
}
