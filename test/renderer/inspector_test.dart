import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/mcp_ui_runtime.dart';

// Tests for the optional RenderInspector hook on the runtime. The inspector
// is the editor-side widget-to-node bridge; production runtimes never supply
// one. These tests confirm that:
//   - the standard MCPUIRuntime() entry point still renders correctly,
//   - MCPUIRuntime.withInspector receives every rendered node with the same
//     Map identity as the source definition,
//   - the inspector can wrap each built widget and the wrapper survives
//     into the rendered tree.

void main() {
  group('TC-INSP-001 fast path — no inspector', () {
    late MCPUIRuntime runtime;

    setUp(() {
      runtime = MCPUIRuntime(enableDebugMode: false);
    });

    tearDown(() async {
      await runtime.dispose();
    });

    testWidgets('production runtime renders text unchanged', (tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'text',
          'content': 'hello',
        },
      });
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: runtime.buildUI())),
      );
      await tester.pump();
      expect(find.text('hello'), findsOneWidget);
    });
  });

  group('TC-INSP-002 inspector receives node identity', () {
    late MCPUIRuntime runtime;
    late List<Map<String, dynamic>> visited;
    late Map<String, dynamic> rootContent;

    setUp(() {
      visited = <Map<String, dynamic>>[];
      runtime = MCPUIRuntime.withInspector(
        widgetWrapper: (child, node) {
          visited.add(node);
          return child;
        },
        enableDebugMode: false,
      );
    });

    tearDown(() async {
      await runtime.dispose();
    });

    testWidgets('inspector fires for root + children with identical map refs',
        (tester) async {
      rootContent = <String, dynamic>{
        'type': 'linear',
        'direction': 'vertical',
        'children': <Map<String, dynamic>>[
          <String, dynamic>{'type': 'text', 'content': 'a'},
          <String, dynamic>{'type': 'text', 'content': 'b'},
        ],
      };

      await runtime.initialize({
        'type': 'page',
        'content': rootContent,
      });
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: runtime.buildUI())),
      );
      await tester.pump();

      // The inspector must fire for descendants of the page content with the
      // exact Map identity that authors hold. (UIDefinition.fromJson shallow
      // -copies the page-level content map, so the root container is rebuilt
      // by the runtime — vibe handles that miss as a non-selectable
      // synthetic node. Child maps inside the shallow copy are preserved by
      // reference, which is the contract the editor relies on.)
      expect(visited.length, greaterThanOrEqualTo(2));
      expect(
        visited.any((n) => identical(n, rootContent['children'][0])),
        isTrue,
        reason: 'inspector must receive child[0] Map by identity',
      );
      expect(
        visited.any((n) => identical(n, rootContent['children'][1])),
        isTrue,
        reason: 'inspector must receive child[1] Map by identity',
      );
    });
  });

  group('TC-INSP-003 inspector wraps the built widget', () {
    late MCPUIRuntime runtime;

    setUp(() {
      runtime = MCPUIRuntime.withInspector(
        widgetWrapper: (child, node) => Container(
          key: ValueKey('wrap:${node['type']}'),
          child: child,
        ),
        enableDebugMode: false,
      );
    });

    tearDown(() async {
      await runtime.dispose();
    });

    // `Expanded` / `Flexible` are ParentDataWidgets: the Row or Column above
    // them reads their ParentData directly, so anything wrapped AROUND one
    // hides it from its parent and the layout collapses. The wrap has to go
    // inside instead — and it has to happen for both of them, since they are
    // separate branches doing the same job.
    testWidgets('a flexible child keeps its place in the parent, wrapped '
        'inside', (tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'linear',
          'direction': 'horizontal',
          'children': [
            {
              'type': 'flexible',
              'flex': 2,
              'fit': 'loose',
              'child': {'type': 'text', 'content': 'left'},
            },
            {
              'type': 'expanded',
              'child': {'type': 'text', 'content': 'right'},
            },
          ],
        },
      });
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: runtime.buildUI())),
      );
      await tester.pump();

      expect(tester.takeException(), isNull,
          reason: 'a wrapped ParentDataWidget throws "incorrect use of '
              'ParentDataWidget" — the whole reason these two branches exist');

      final flexible = tester.widget<Flexible>(find.byType(Flexible).first);
      expect(flexible.flex, 2,
          reason: 'the declared flex has to survive the rebuild that pushes '
              'the wrap inside');
      expect(flexible.fit, FlexFit.loose);

      expect(find.byKey(const ValueKey('wrap:flexible')), findsOneWidget,
          reason: 'the wrap still happened — inside rather than outside');
      expect(find.byKey(const ValueKey('wrap:expanded')), findsOneWidget);
      expect(find.text('left'), findsOneWidget);
      expect(find.text('right'), findsOneWidget);
    });

    testWidgets('wrapper widgets appear in the rendered tree', (tester) async {
      await runtime.initialize({
        'type': 'page',
        'content': {
          'type': 'text',
          'content': 'tagged',
        },
      });
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: runtime.buildUI())),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('wrap:text')), findsOneWidget);
      expect(find.text('tagged'), findsOneWidget);
    });
  });
}
