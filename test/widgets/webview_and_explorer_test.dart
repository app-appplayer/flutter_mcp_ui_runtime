// `webView` (60%) and `fileExplorer` (73%).
//
// `webView` is the clearest §6.13 widget in the runtime: the engine is a host
// power, so with none wired it must say so rather than draw something that
// looks like a loaded page. That refusal — and the host-surface path that
// replaces it — was the uncovered part, which is to say the whole contract.
//
// `fileExplorer` had its tree drawn and never walked: expanding, selecting,
// opening, hidden files, and the sort that puts folders first.

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

  /// Taps, then waits past the double-tap timeout.
  ///
  /// Every row in the explorer carries `onDoubleTap`, so the recogniser holds
  /// a single tap for `kDoubleTapTimeout` before firing it — and that is a
  /// Timer, not an animation, so `pumpAndSettle` returns without it.
  Future<void> tapRow(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 400));
  }

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

  group('webView with no engine wired', () {
    testWidgets('reports through onError rather than drawing a page',
        (tester) async {
      await pump(tester, {
        'type': 'webView',
        'url': 'https://example.test',
        'onError': {
          'type': 'state',
          'action': 'set',
          'binding': 'problem',
          'value': '{{event.error}}',
        },
      });

      expect(stateManager.get<String>('problem'), contains('capability'),
          reason: '§6.13.1 — the old path drew the URL as text and fired '
              'onPageFinished, which told the document the page was up');
      expect(find.text('https://example.test'), findsNothing,
          reason: 'a facsimile of a loaded page is worse than nothing');
    });

    testWidgets('never claims the page finished', (tester) async {
      await pump(tester, {
        'type': 'webView',
        'url': 'https://example.test',
        'onPageFinished': {
          'type': 'state',
          'action': 'set',
          'binding': 'finished',
          'value': true,
        },
      });

      expect(stateManager.get('finished'), isNull);
    });

    testWidgets('onPageStarted still fires — the attempt did begin',
        (tester) async {
      await pump(tester, {
        'type': 'webView',
        'url': 'https://example.test',
        'onPageStarted': {
          'type': 'state',
          'action': 'set',
          'binding': 'startedUrl',
          'value': '{{event.url}}',
        },
      });

      expect(stateManager.get('startedUrl'), 'https://example.test');
    });

    testWidgets('with neither url nor html the refusal names what is missing',
        (tester) async {
      await pump(tester, {
        'type': 'webView',
        'onError': {
          'type': 'state',
          'action': 'set',
          'binding': 'problem',
          'value': '{{event.error}}',
        },
      });

      expect(stateManager.get<String>('problem'), contains('required'));
    });

    testWidgets('an unsupported platform is named', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      await pump(tester, {
        'type': 'webView',
        'url': 'https://example.test',
        'onError': {
          'type': 'state',
          'action': 'set',
          'binding': 'problem',
          'value': '{{event.error}}',
        },
      });

      debugDefaultTargetPlatformOverride = null;

      expect(stateManager.get<String>('problem'), contains('platform'),
          reason: 'a document run on a desktop target has to be told the '
              'reason is the platform, not the URL');
    });

    testWidgets('the declared size is still reserved', (tester) async {
      await pump(tester, {
        'type': 'webView',
        'url': 'https://example.test',
        'width': 320,
        'height': 200,
      });

      final box = tester.getSize(find.byType(SizedBox).first);
      expect(box.width, 320);
      expect(box.height, 200,
          reason: 'a layout that collapses when the capability is missing '
              'moves everything below it');
    });
  });

  group('webView with a host surface', () {
    testWidgets('the host builds the surface, and gets the properties',
        (tester) async {
      Map<String, dynamic>? seen;
      engine.capabilities = RuntimeCapabilities(
        webViewBuilder: (ctx, properties, events, assets) {
          seen = properties;
          return const Text('hosted surface');
        },
      );

      await pump(tester, {
        'type': 'webView',
        'url': 'https://example.test',
        'allowNavigation': ['https://example.test/*'],
        'height': 120,
      });

      expect(find.text('hosted surface'), findsOneWidget);
      expect(seen!['url'], 'https://example.test');
      expect(seen!['allowNavigation'], ['https://example.test/*'],
          reason: '§10.18 — the navigation policy is decided by the engine, so '
              'it has to reach the host rather than being read and dropped');
    });

    testWidgets('a url that changes is loaded again, not left on the old page',
        (tester) async {
      final urls = <String>[];
      engine.capabilities = RuntimeCapabilities(
        webViewBuilder: (ctx, properties, events, assets) {
          urls.add(properties['url'] as String);
          return Text('showing ${properties['url']}');
        },
      );

      await pump(tester, {
        'type': 'webView',
        'url': 'https://example.test/one',
        'height': 120,
      });
      expect(find.text('showing https://example.test/one'), findsOneWidget);

      // The same widget position, a different url — what a bound address does
      // when the state behind it moves.
      await pump(tester, {
        'type': 'webView',
        'url': 'https://example.test/two',
        'height': 120,
      });

      expect(find.text('showing https://example.test/two'), findsOneWidget,
          reason: 'a webView bound to state that keeps showing the first page '
              'is a browser whose address bar lies');
      expect(urls.last, 'https://example.test/two');
    });

    testWidgets('the host reports back into the document\'s own actions',
        (tester) async {
      engine.capabilities = RuntimeCapabilities(
        webViewBuilder: (ctx, properties, events, assets) {
          // After the frame: a host reporting from inside build() would write
          // state while the tree is being built.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            events.emit('onPageFinished', {'url': 'https://example.test/done'});
          });
          return const Text('hosted surface');
        },
      );

      await pump(tester, {
        'type': 'webView',
        'url': 'https://example.test',
        'onPageFinished': {
          'type': 'state',
          'action': 'set',
          'binding': 'finishedUrl',
          'value': '{{event.url}}',
        },
      });

      expect(stateManager.get('finishedUrl'), 'https://example.test/done',
          reason: 'a hosted surface the document cannot react to is a second '
              'way of being disconnected from the truth');
    });

    testWidgets('a host builder that declines draws nothing, not an error',
        (tester) async {
      engine.capabilities = RuntimeCapabilities(
        webViewBuilder: (ctx, properties, events, assets) => null,
      );

      await pump(tester, {'type': 'webView', 'url': 'https://example.test'});
      expect(tester.takeException(), isNull);
    });
  });

  group('fileExplorer', () {
    Map<String, dynamic> tree({Map<String, dynamic> extra = const {}}) => {
          'type': 'fileExplorer',
          'items': [
            {'name': 'readme.md', 'type': 'file'},
            {
              'name': 'src',
              'type': 'folder',
              'children': [
                {'name': 'main.dart', 'type': 'file'},
                {
                  'name': 'widgets',
                  'type': 'folder',
                  'children': [
                    {'name': 'button.dart', 'type': 'file'},
                  ],
                },
              ],
            },
            {'name': '.hidden', 'type': 'file'},
          ],
          ...extra,
        };

    testWidgets('folders sort before files, and hidden entries are hidden',
        (tester) async {
      await pump(tester, tree());

      expect(find.text('src'), findsOneWidget);
      expect(find.text('readme.md'), findsOneWidget);
      expect(find.text('.hidden'), findsNothing,
          reason: 'showHidden defaults to false, and a dotfile shown by '
              'default is noise in every listing');
      expect(tester.getTopLeft(find.text('src')).dy,
          lessThan(tester.getTopLeft(find.text('readme.md')).dy));
    });

    testWidgets('showHidden reveals the dotfiles', (tester) async {
      await pump(tester, tree(extra: {'showHidden': true}));
      expect(find.text('.hidden'), findsOneWidget);
    });

    testWidgets('a folder is closed until it is tapped', (tester) async {
      await pump(tester, tree());
      expect(find.text('main.dart'), findsNothing);

      await tapRow(tester, find.text('src'));

      expect(find.text('main.dart'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget,
          reason: 'the chevron has to follow the state, or the tree looks '
              'stuck');

      await tapRow(tester, find.text('src'));
      expect(find.text('main.dart'), findsNothing);
    });

    testWidgets('expandAll opens the whole tree at once', (tester) async {
      await pump(tester, tree(extra: {'expandAll': true}));

      expect(find.text('main.dart'), findsOneWidget);
      expect(find.text('button.dart'), findsOneWidget,
          reason: 'expandAll that opens one level is a different feature');
    });

    testWidgets('selecting reports the name, the path and the kind',
        (tester) async {
      await pump(tester, tree(extra: {
        'expandAll': true,
        'onSelect': {
          'type': 'state',
          'action': 'set',
          'binding': 'chosen',
          'value': '{{event.path}}',
        },
      }));

      await tapRow(tester, find.text('button.dart'));

      expect(stateManager.get('chosen'), 'src/widgets/button.dart',
          reason: 'the name alone cannot be opened — the path is the only '
              'thing the document can act on');
    });

    testWidgets('the selected row is marked', (tester) async {
      await pump(tester, tree(extra: {'selectedColor': '#FF0000'}));

      await tapRow(tester, find.text('readme.md'));

      final marked = tester.widgetList<Container>(find.byType(Container)).where(
          (c) =>
              c.decoration is BoxDecoration &&
              (c.decoration! as BoxDecoration).color == const Color(0xFFFF0000));
      expect(marked, isNotEmpty,
          reason: 'a tree that never shows what is selected makes the next '
              'action a guess');
    });

    testWidgets('a double tap opens rather than selects', (tester) async {
      await pump(tester, tree(extra: {
        'onOpen': {
          'type': 'state',
          'action': 'set',
          'binding': 'opened',
          'value': '{{event.name}}',
        },
      }));

      await tester.tap(find.text('readme.md'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('readme.md'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(stateManager.get('opened'), 'readme.md');
    });

    testWidgets('a plain string item is a file', (tester) async {
      await pump(tester, {
        'type': 'fileExplorer',
        'items': ['notes.txt'],
      });

      expect(find.text('notes.txt'), findsOneWidget);
    });

    testWidgets('an empty tree is an empty pane, not a failure',
        (tester) async {
      await pump(tester, {'type': 'fileExplorer', 'items': <dynamic>[]});
      expect(tester.takeException(), isNull);
    });

    testWidgets('width and height bound the pane', (tester) async {
      await pump(tester, tree(extra: {'width': 240, 'height': 180}));

      final box = tester.getSize(find.byType(SizedBox).first);
      expect(box.width, 240);
      expect(box.height, 180);
    });
  });
}
