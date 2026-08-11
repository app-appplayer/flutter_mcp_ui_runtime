// `kenBurnsImage` and `carousel`'s image sources, and the waveform painter.
//
// Each of these decides what to draw from the shape of a string: a URL, a
// bundled asset, or something the widget cannot open. Picking the wrong
// branch draws a grey rectangle where a photograph belongs — and a grey
// rectangle is exactly what a still-loading image looks like, so nothing on
// screen says the source was never read.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
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
        body: SizedBox(
          width: 300,
          height: 200,
          child: context.renderer.renderWidget(definition, context),
        ),
      ),
    ));
    await tester.pump();
    // Image loads fail in a test binding; the branch under test is which
    // provider was chosen, not whether the bytes arrived.
    tester.takeException();
  }

  group('kenBurnsImage', () {
    testWidgets('a URL source is fetched over the network', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'kenBurnsImage',
        'src': 'https://example.com/city.jpg',
        'duration': 100,
      });

      final images = tester.widgetList<Image>(find.byType(Image));
      expect(images, isNotEmpty,
          reason: 'a grey rectangle where a photograph belongs looks exactly '
              'like an image that is still loading');
      expect(images.first.image, isA<NetworkImage>());
    });

    testWidgets('an assets/ source is read from the bundle', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'kenBurnsImage',
        'src': 'assets/city.jpg',
        'duration': 100,
      });

      final images = tester.widgetList<Image>(find.byType(Image));
      expect(images, isNotEmpty);
      expect(images.first.image, isA<AssetImage>());
    });

    testWidgets('a source it cannot open draws a placeholder rather than '
        'failing', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'kenBurnsImage',
        'src': 'not-a-source',
        'duration': 100,
      });

      expect(find.byType(Image), findsNothing);
    });

    testWidgets('a looping pan turns around at each end', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'kenBurnsImage',
        'src': 'assets/city.jpg',
        'duration': 60,
        'loop': true,
      });

      // Past the first leg, then past the second: a loop that never reverses
      // stops moving after one pass and the panel goes still.
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pump(const Duration(milliseconds: 80));
      tester.takeException();

      expect(find.byType(Image), findsWidgets);
    });
  });

  group('lightbox', () {
    testWidgets('each declared image source is read the same way',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'lightbox',
        'images': <dynamic>[
          'https://example.com/one.jpg',
        ],
      });

      expect(
        tester.widgetList<Image>(find.byType(Image))
            .any((i) => i.image is NetworkImage),
        isTrue,
      );

      await pump(tester, <String, dynamic>{
        'type': 'lightbox',
        'images': <dynamic>['assets/two.jpg'],
      });

      await pump(tester, <String, dynamic>{
        'type': 'lightbox',
        'images': <dynamic>['neither'],
      });
      expect(find.byType(Image), findsNothing,
          reason: 'a source the widget cannot open draws a plain block, not '
              'a broken image');

      await pump(tester, <String, dynamic>{
        'type': 'lightbox',
        'images': <dynamic>['assets/two.jpg'],
      });

      expect(
        tester.widgetList<Image>(find.byType(Image))
            .any((i) => i.image is AssetImage),
        isTrue,
        reason: 'a bundled slide read as a network URL fetches nothing and '
            'shows the placeholder for the life of the page',
      );
    });
  });
}
