// `pdfViewer` — a host surface, and what stands in when there is none.
//
// The uncovered part was every refusal (no source, a source the platform
// cannot fetch, no renderer at all) and the open-parameter fragment that
// carries page, zoom and chrome into the embedded viewer. A viewer that
// silently drops those shows page 1 at the default zoom for a document that
// asked for page 12 — which reads as a broken link, not as a dropped
// parameter.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/capabilities/runtime_capabilities.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/runtime_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StateManager stateManager;
  late RenderContext context;
  late RuntimeEngine engine;

  setUp(() async {
    engine = RuntimeEngine(enableDebugMode: false);
    await engine.initialize(definition: {
      'type': 'page',
      'content': {'type': 'box'},
    });
    stateManager = engine.stateManager;

    final registry = WidgetRegistry();
    DefaultWidgets.registerAll(registry);
    final bindingEngine = BindingEngine();
    final actionHandler = ActionHandler();
    context = RenderContext(
      renderer: Renderer(
        widgetRegistry: registry,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        stateManager: stateManager,
      ),
      stateManager: stateManager,
      bindingEngine: bindingEngine,
      actionHandler: actionHandler,
      themeManager: ThemeManager.instance,
      engine: engine,
    );
  });

  tearDown(() => engine.destroy());

  Future<void> pump(WidgetTester tester, Map<String, dynamic> definition) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AnimatedBuilder(
          animation: stateManager,
          builder: (_, __) => context.renderer.renderWidget(definition, context),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Map<String, dynamic> viewer({Map<String, dynamic> extra = const {}}) => {
        'type': 'pdfViewer',
        'src': 'https://example.test/report.pdf',
        'onError': {
          'type': 'state',
          'action': 'set',
          'binding': 'problem',
          'value': '{{event.message}}',
        },
        ...extra,
      };

  group('with a host surface wired', () {
    testWidgets('the host draws it, and receives the properties',
        (tester) async {
      Map<String, dynamic>? seen;
      engine.capabilities = RuntimeCapabilities(
        pdfBuilder: (ctx, properties, events, assets) {
          seen = properties;
          return const Text('hosted pdf');
        },
      );

      await pump(tester, viewer(extra: {'page': 12, 'zoom': 1.5}));

      expect(find.text('hosted pdf'), findsOneWidget);
      expect(seen!['page'], 12);
      expect(seen!['zoom'], 1.5,
          reason: 'the host renders the document, so the page and zoom the '
              'author asked for have to reach it');
    });

    testWidgets('a host that declines draws nothing rather than failing',
        (tester) async {
      engine.capabilities = RuntimeCapabilities(
        pdfBuilder: (ctx, properties, events, assets) => null,
      );

      await pump(tester, viewer());
      expect(tester.takeException(), isNull);
    });

    testWidgets('the host can report back into the document', (tester) async {
      engine.capabilities = RuntimeCapabilities(
        pdfBuilder: (ctx, properties, events, assets) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            events.emit('onError', {'message': 'the file is encrypted'});
          });
          return const Text('hosted pdf');
        },
      );

      await pump(tester, viewer());
      await tester.pump();

      expect(stateManager.get('problem'), 'the file is encrypted');
    });
  });

  group('with no host surface', () {
    testWidgets('no src is reported rather than drawn as an empty page',
        (tester) async {
      await pump(tester, {
        'type': 'pdfViewer',
        'onError': {
          'type': 'state',
          'action': 'set',
          'binding': 'problem',
          'value': '{{event.message}}',
        },
      });

      expect(stateManager.get<String>('problem'), contains('no src'));
      expect(find.text('No document'), findsOneWidget,
          reason: 'the slot keeps its place in the layout and says what is '
              'missing, rather than collapsing');
    });

    testWidgets('a platform with no renderer says so', (tester) async {
      await pump(tester, viewer());

      expect(stateManager.get<String>('problem'), contains('no PDF renderer'),
          reason: '§6.12.4 — a host that cannot serve a form says so; drawing '
              'a blank frame would read as an empty document');
      expect(find.textContaining('not available'), findsOneWidget);
    });

    // The remaining branch — a source form the built-in viewer cannot fetch
    // (`bundle://`, `client://`, an origin resource) — sits BELOW the
    // renderer check and is reachable only on the web, where a renderer
    // exists. Recorded rather than faked: overriding the platform flag would
    // test the override.

    testWidgets('a declared height is still reserved', (tester) async {
      await pump(tester, viewer(extra: {'height': 320}));

      final box = tester.getSize(find.byType(SizedBox).first);
      expect(box.height, 320,
          reason: 'a slot that collapses when the document cannot be shown '
              'moves everything below it');
    });

    testWidgets('the error is reported once, not on every rebuild',
        (tester) async {
      await pump(tester, {
        'type': 'pdfViewer',
        'onError': {
          'type': 'state',
          'action': 'increment',
          'binding': 'reports',
          'value': 1,
        },
      });

      stateManager.set('unrelated', 1);
      await tester.pump();
      stateManager.set('unrelated', 2);
      await tester.pump();

      expect(stateManager.get('reports'), 1,
          reason: 'one missing document is one report, not a stream of them');
    });
  });
}
