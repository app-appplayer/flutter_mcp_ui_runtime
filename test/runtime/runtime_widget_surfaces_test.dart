// `MCPRuntimeWidget` — the render paths `MCPUIRuntime.buildUI` picks between,
// and the refusals in front of it.
//
// The widget takes a raw definition map, so the shapes below reach branches
// that `MCPUIRuntime.initialize` screens out earlier. That is the point: the
// branches exist, a host embedding the widget directly can hand them anything,
// and a render error must land as an error surface rather than a torn tree.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_mcp_ui_runtime/src/mcp_ui_runtime.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/runtime_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MCPUIRuntime refusals', () {
    test('building before initialising is refused by name', () {
      final runtime = MCPUIRuntime();

      expect(() => runtime.buildUI(), throwsStateError,
          reason: 'a host that builds too early gets told so, rather than an '
              'empty screen it has to explain');
      expect(() => runtime.buildDashboard(), throwsStateError);
    });

    test('initialising twice is refused', () async {
      final runtime = MCPUIRuntime();
      addTearDown(runtime.destroy);

      await runtime.initialize(<String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{'type': 'text', 'content': 'hello'},
      });

      expect(
          () => runtime.initialize(<String, dynamic>{
                'type': 'page',
                'content': <String, dynamic>{'type': 'text', 'content': 'x'},
              }),
          throwsStateError);
    });
  });

  group('MCPRuntimeWidget', () {
    late RuntimeEngine engine;

    setUp(() async {
      engine = RuntimeEngine(enableDebugMode: false);
      await engine.initialize(definition: <String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{'type': 'text', 'content': 'root'},
      });
      await engine.markReady();
    });

    tearDown(() => engine.destroy());

    Future<void> mount(
        WidgetTester tester, Map<String, dynamic> definition) async {
      await tester.pumpWidget(MaterialApp(
        home: MCPRuntimeWidget(engine: engine, uiDefinition: definition),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('a top-level appBar and body are given a scaffold',
        (tester) async {
      await mount(tester, <String, dynamic>{
        // The slot is `appBar`; the widget inside it is `headerBar` (§17.3.1,
        // alias `appbar`).
        'appBar': <String, dynamic>{
          'type': 'headerBar',
          'title': 'Jobs',
        },
        'body': <String, dynamic>{'type': 'text', 'content': 'body content'},
      });

      expect(find.byType(Scaffold), findsWidgets);
      expect(find.text('Jobs'), findsOneWidget);
      expect(find.text('body content'), findsOneWidget,
          reason: 'the shape is platform-independent — a host that hands it '
              'over gets a page, not two loose widgets');
    });

    testWidgets('a body with no appBar still gets its scaffold',
        (tester) async {
      await mount(tester, <String, dynamic>{
        'body': <String, dynamic>{'type': 'text', 'content': 'body only'},
      });

      expect(find.text('body only'), findsOneWidget);
    });

    testWidgets('an appBar with no body leaves the body empty rather than null',
        (tester) async {
      await mount(tester, <String, dynamic>{
        'appBar': <String, dynamic>{'type': 'headerBar', 'title': 'Jobs'},
      });

      expect(find.text('Jobs'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a definition with neither slot falls back to the parsed page',
        (tester) async {
      await mount(tester,
          <String, dynamic>{'type': 'text', 'content': 'just a widget'});

      expect(find.text('root'), findsOneWidget,
          reason: 'a page-type engine renders the page it parsed; the raw map '
              'is only consulted for the appBar/body shape');
    });

    testWidgets('a render failure becomes an error surface, not a torn tree',
        (tester) async {
      // A slot holding a string rather than a definition is the ordinary way
      // a hand-written map goes wrong.
      await mount(tester, <String, dynamic>{
        'body': 'not a definition',
      });

      expect(find.byType(ErrorWidget), findsOneWidget,
          reason: 'the host keeps its own chrome around a failed document; '
              'letting the exception through would take the app down');
      expect(tester.takeException(), isNull);
    });
  });
}
