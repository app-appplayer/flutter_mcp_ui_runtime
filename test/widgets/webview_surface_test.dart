// `webView` — what it does when there is no engine, and what it does when the
// host supplies one.
//
// §6.13 is the whole point of this widget's shape: a web view either loads
// pages or says it cannot. The version before this one drew the URL as text
// and fired `onPageFinished` a hundred milliseconds later, which told the
// document a page was up. The tests below pin the reporting, not the drawing.

import 'package:flutter/foundation.dart';
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

  setUp(() {
    stateManager = StateManager()..initialize(<String, dynamic>{});
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
    );
  });

  Future<void> pump(WidgetTester tester, Map<String, dynamic> definition) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AnimatedBuilder(
          animation: stateManager,
          builder: (_, __) => context.renderer.renderWidget(definition, context),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> record(String binding, String field) =>
      <String, dynamic>{
        'type': 'state',
        'action': 'set',
        'binding': binding,
        'value': '{{event.$field}}',
      };

  group('with no engine wired', () {
    testWidgets('a url reports the absence rather than a page load',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'webView',
        'url': 'https://example.com',
        'onPageStarted': record('started', 'url'),
        'onPageFinished': record('finished', 'url'),
        'onError': record('failed', 'error'),
      });

      expect(stateManager.get('started'), 'https://example.com',
          reason: 'the load was attempted, and the document is told so');
      expect(stateManager.get('failed'), 'no web view capability');
      expect(stateManager.get('finished'), isNull,
          reason: '§6.13.1 — announcing a finished load that never happened is '
              'the failure this shape exists to prevent');
    });

    testWidgets('nothing of the runtime\'s own limits is drawn',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'webView',
        'url': 'https://example.com',
      });

      expect(find.textContaining('capability'), findsNothing,
          reason: '§6.12.4 — the diagnostic goes to the document, not into '
              'the user\'s screen');
      expect(find.textContaining('example.com'), findsNothing,
          reason: 'drawing the URL as text is a facsimile of a loaded page');
    });

    testWidgets('with neither url nor html it says which is missing',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'webView',
        'onError': record('failed', 'error'),
      });

      expect(stateManager.get('failed'), 'Either url or html content is required');
    });

    testWidgets('a platform with no web view at all is reported as such',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      await pump(tester, <String, dynamic>{
        'type': 'webView',
        'url': 'https://example.com',
        'onError': record('failed', 'error'),
      });

      // Reset inside the body: the framework checks the debug variables when
      // the test body returns, before any tear-down runs.
      debugDefaultTargetPlatformOverride = null;

      expect(stateManager.get('failed'),
          'WebView is not supported on this platform');
    });

    testWidgets('a document that wires nothing is not an error', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'webView',
        'url': 'https://example.com',
      });

      expect(tester.takeException(), isNull);
    });
  });

  group('inline html', () {
    testWidgets('the markup is shown as markup, and can be selected',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'webView',
        'html': '<h1>Report</h1>',
      });

      expect(find.text('HTML Content'), findsOneWidget);
      expect(find.text('<h1>Report</h1>'), findsOneWidget,
          reason: 'without an engine this is source, not a rendered page — '
              'showing it as source is the honest form');
      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('scripts being off is stated rather than assumed',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'webView',
        'html': '<h1>Report</h1>',
        'enableJavaScript': false,
      });

      expect(find.text('JS Disabled'), findsOneWidget);
    });

    testWidgets('with scripts on there is no badge', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'webView',
        'html': '<h1>Report</h1>',
      });

      expect(find.text('JS Disabled'), findsNothing);
    });

    testWidgets('the declared size is what it occupies', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'webView',
        'html': '<h1>Report</h1>',
        'width': 320,
        'height': 180,
      });

      final box = find
          .ancestor(
            of: find.byType(SelectableText),
            matching: find.byType(SizedBox),
          )
          .evaluate()
          .map((e) => e.widget as SizedBox)
          .where((s) => s.width == 320 && s.height == 180);
      expect(box, isNotEmpty);
    });

    testWidgets('the common wrappers still apply', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'webView',
        'html': '<h1>Report</h1>',
        'visible': false,
      });

      expect(find.text('HTML Content'), findsNothing);
    });
  });

  group('with a host engine', () {
    late RuntimeEngine engine;

    Future<RenderContext> hosted(SurfaceBuilder builder) async {
      engine = RuntimeEngine(enableDebugMode: false);
      await engine.initialize(definition: <String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{'type': 'text', 'content': 'root'},
      });
      engine.capabilities = RuntimeCapabilities(webViewBuilder: builder);
      addTearDown(engine.destroy);

      return RenderContext(
        renderer: context.renderer,
        stateManager: stateManager,
        bindingEngine: context.bindingEngine,
        actionHandler: context.actionHandler,
        themeManager: ThemeManager.instance,
        engine: engine,
      );
    }

    Future<void> pumpHosted(
        WidgetTester tester, RenderContext ctx, Map<String, dynamic> def) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ctx.renderer.renderWidget(def, ctx)),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('the host surface is what renders, and gets the properties',
        (tester) async {
      Map<String, dynamic>? seen;
      final ctx = await hosted((buildContext, properties, events, assets) {
        seen = properties;
        return const Text('host surface');
      });

      await pumpHosted(tester, ctx, <String, dynamic>{
        'type': 'webView',
        'url': 'https://example.com',
        'allowNavigation': false,
        'width': 200,
        'height': 100,
      });

      expect(find.text('host surface'), findsOneWidget);
      expect(seen!['url'], 'https://example.com');
      expect(seen!['allowNavigation'], isFalse,
          reason: '§10.18 — the engine decides navigation, so the property has '
              'to reach the engine rather than being read and dropped here');
    });

    testWidgets('a host that declines to build draws nothing rather than '
        'falling back to a facsimile', (tester) async {
      final ctx =
          await hosted((buildContext, properties, events, assets) => null);

      await pumpHosted(tester, ctx, <String, dynamic>{
        'type': 'webView',
        'url': 'https://example.com',
        'onError': record('failed', 'error'),
      });

      expect(find.textContaining('example.com'), findsNothing);
      expect(stateManager.get('failed'), isNull,
          reason: 'the host owns the surface once it declares one; reporting '
              '"no capability" behind its back would contradict it');
    });

    testWidgets('the host surface is still subject to the common wrappers',
        (tester) async {
      final ctx = await hosted(
          (buildContext, properties, events, assets) =>
              const Text('host surface'));

      await pumpHosted(tester, ctx, <String, dynamic>{
        'type': 'webView',
        'url': 'https://example.com',
        'visible': false,
      });

      expect(find.text('host surface'), findsNothing);
    });
  });
}
