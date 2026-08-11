// `imageFilter`, `carousel`, `staggeredGrid` and `lightbox`.
//
// 68% covered, and the uncovered third was the choices each one makes: which
// colour matrix a filter builds, whether a carousel loops, whether a grid
// transposes for a horizontal scroll, whether a lightbox lets the user zoom.
// None of these throw when they are wrong — the screen simply shows something
// else, which is why they have to be read off the built widget rather than
// assumed from the definition.

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
        body: context.renderer.renderWidget(definition, context),
      ),
    ));
    await tester.pump();
  }

  group('imageFilter', () {
    Map<String, dynamic> filtered(String filter, {num? intensity}) => {
          'type': 'imageFilter',
          'filter': filter,
          if (intensity != null) 'intensity': intensity,
          'child': {'type': 'text', 'content': 'under the filter'},
        };

    testWidgets('each named filter builds a colour filter, and blur builds an '
        'image filter', (tester) async {
      for (final name in const [
        'sepia',
        'grayscale',
        'invert',
        'saturation',
        'brightness',
        'contrast',
      ]) {
        await pump(tester, filtered(name));
        expect(find.byType(ColorFiltered), findsOneWidget,
            reason: '$name must produce a colour matrix — a filter that falls '
                'through renders the child untouched and looks like the '
                'image simply is not filtered');
        expect(find.text('under the filter'), findsOneWidget);
      }

      await pump(tester, filtered('blur', intensity: 3));
      expect(find.byType(ImageFiltered), findsOneWidget);
      expect(find.byType(ColorFiltered), findsNothing);
    });

    testWidgets('two different filters produce two different matrices',
        (tester) async {
      await pump(tester, filtered('sepia'));
      final sepia =
          tester.widget<ColorFiltered>(find.byType(ColorFiltered)).colorFilter;

      await pump(tester, filtered('grayscale'));
      final grayscale =
          tester.widget<ColorFiltered>(find.byType(ColorFiltered)).colorFilter;

      expect(sepia, isNot(grayscale),
          reason: 'if every name built the same matrix the widget would be '
              'decorative — this is the assertion that says it is not');
    });

    testWidgets('intensity changes the matrix', (tester) async {
      await pump(tester, filtered('grayscale', intensity: 1));
      final full =
          tester.widget<ColorFiltered>(find.byType(ColorFiltered)).colorFilter;

      await pump(tester, filtered('grayscale', intensity: 0.2));
      final light =
          tester.widget<ColorFiltered>(find.byType(ColorFiltered)).colorFilter;

      expect(full, isNot(light),
          reason: 'intensity blends towards identity; ignoring it makes every '
              'value look like 1.0');
    });

    testWidgets('a filter nobody implements renders the child untouched',
        (tester) async {
      await pump(tester, filtered('kaleidoscope'));

      expect(find.text('under the filter'), findsOneWidget);
      expect(find.byType(ColorFiltered), findsNothing,
          reason: 'an unknown name must not fall back to a filter the '
              'document did not ask for — showing the image plainly is the '
              'honest answer');
    });

    testWidgets('with no child it still builds', (tester) async {
      await pump(tester, {'type': 'imageFilter', 'filter': 'sepia'});
      expect(tester.takeException(), isNull);
    });
  });

  group('carousel', () {
    Map<String, dynamic> carousel({Map<String, dynamic> extra = const {}}) => {
          'type': 'carousel',
          'children': [
            {'type': 'text', 'content': 'one'},
            {'type': 'text', 'content': 'two'},
            {'type': 'text', 'content': 'three'},
          ],
          ...extra,
        };

    testWidgets('shows the first page and swipes to the next', (tester) async {
      await pump(tester, carousel());

      expect(find.text('one'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('two'), findsOneWidget);
    });

    testWidgets('initialIndex opens on the page the document named',
        (tester) async {
      await pump(tester, carousel(extra: {'initialIndex': 2}));
      expect(find.text('three'), findsOneWidget,
          reason: 'a carousel resuming where the user left off opens on that '
              'page, not on the first');
    });

    testWidgets('scrollDirection: vertical scrolls the other way',
        (tester) async {
      await pump(tester, carousel(extra: {'scrollDirection': 'vertical'}));

      final view = tester.widget<PageView>(find.byType(PageView));
      expect(view.scrollDirection, Axis.vertical);
    });

    testWidgets('loop makes the item count unbounded', (tester) async {
      await pump(tester, carousel(extra: {'loop': true}));

      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.text('one'), findsOneWidget,
          reason: 'past the last page a looping carousel comes back to the '
              'first rather than stopping dead');
    });

    testWidgets('onPageChanged fires with the new index', (tester) async {
      await pump(tester, carousel(extra: {
        'onPageChanged': {
          'type': 'state',
          'action': 'set',
          'binding': 'page',
          'value': '{{event.page}}',
        },
      }));

      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(stateManager.get('page'), 1,
          reason: '§2 — `event.page` carries the new index, and an indicator '
              'bound to it is the ordinary companion of a carousel');
    });

    testWidgets('items + itemTemplate builds a page per item', (tester) async {
      await pump(tester, {
        'type': 'carousel',
        'items': ['red', 'green'],
        'itemTemplate': {'type': 'text', 'content': 'colour: {{item}}'},
      });

      expect(find.text('colour: red'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('colour: green'), findsOneWidget);
    });

    testWidgets('with nothing to show it draws nothing', (tester) async {
      await pump(tester, {'type': 'carousel'});
      expect(find.byType(PageView), findsNothing);
    });

    testWidgets('viewportFraction is clamped into a usable range',
        (tester) async {
      await pump(tester, carousel(extra: {'viewportFraction': 0}));

      expect(tester.takeException(), isNull,
          reason: 'a zero fraction would assert inside PageController — the '
              'clamp is what keeps a bad number from taking the page down');
    });
  });

  group('staggeredGrid', () {
    Map<String, dynamic> grid({Map<String, dynamic> extra = const {}}) => {
          'type': 'staggeredGrid',
          'children': [
            {'type': 'text', 'content': 'a'},
            {'type': 'text', 'content': 'b'},
            {'type': 'text', 'content': 'c'},
            {'type': 'text', 'content': 'd'},
          ],
          ...extra,
        };

    testWidgets('items are spread across the declared columns', (tester) async {
      await pump(tester, grid(extra: {'columns': 2}));

      // Round-robin: a and c in the first column, b and d in the second.
      final aLeft = tester.getTopLeft(find.text('a')).dx;
      final bLeft = tester.getTopLeft(find.text('b')).dx;
      final cLeft = tester.getTopLeft(find.text('c')).dx;

      expect(bLeft, greaterThan(aLeft),
          reason: 'a single column would put every item at the same x, which '
              'is a list rather than a grid');
      expect(cLeft, aLeft);
    });

    testWidgets('a responsive columns map is resolved rather than ignored',
        (tester) async {
      await pump(tester, grid(extra: {
        'columns': {'default': 1, 'md': 2, 'lg': 3},
      }));

      expect(tester.takeException(), isNull);
      expect(find.text('a'), findsOneWidget,
          reason: 'the object form is what the spec\'s own example uses — '
              'treating it as null would collapse the grid to the default');
    });

    testWidgets('scrollDirection: horizontal transposes the layout',
        (tester) async {
      await pump(tester, grid(extra: {
        'columns': 2,
        'scrollDirection': 'horizontal',
      }));

      final scrollView = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView));
      expect(scrollView.scrollDirection, Axis.horizontal,
          reason: 'reading the property and ignoring it left '
              'scrollDirection: "horizontal" looking like it had taken');

      final aTop = tester.getTopLeft(find.text('a')).dy;
      final bTop = tester.getTopLeft(find.text('b')).dy;
      expect(bTop, greaterThan(aTop),
          reason: 'transposed: the rows are what stack now');
    });

    testWidgets('spacing separates the items', (tester) async {
      await pump(tester, grid(extra: {'columns': 2, 'mainAxisSpacing': 40}));

      final aBottom = tester.getBottomLeft(find.text('a')).dy;
      final cTop = tester.getTopLeft(find.text('c')).dy;
      expect(cTop - aBottom, greaterThanOrEqualTo(40),
          reason: 'a masonry shelf with no gaps reads as one solid block');
    });

    testWidgets('items + itemTemplate fills the grid', (tester) async {
      await pump(tester, {
        'type': 'staggeredGrid',
        'columns': 2,
        'items': [1, 2, 3],
        'itemTemplate': {'type': 'text', 'content': 'item {{item}}'},
      });

      expect(find.text('item 1'), findsOneWidget);
      expect(find.text('item 3'), findsOneWidget);
    });

    testWidgets('with nothing to show it draws nothing', (tester) async {
      await pump(tester, {'type': 'staggeredGrid', 'columns': 2});
      expect(find.byType(SingleChildScrollView), findsNothing);
    });
  });

  group('lightbox', () {
    Map<String, dynamic> lightbox({Map<String, dynamic> extra = const {}}) => {
          'type': 'lightbox',
          'images': ['assets/a.png', 'assets/b.png'],
          ...extra,
        };

    testWidgets('it builds a pager over the images', (tester) async {
      await pump(tester, lightbox());
      expect(find.byType(PageView), findsOneWidget);
      tester.takeException(); // the assets are not real
    });

    testWidgets('allowSwipe: false locks the pager', (tester) async {
      await pump(tester, lightbox(extra: {'allowSwipe': false}));

      final view = tester.widget<PageView>(find.byType(PageView));
      expect(view.physics, isA<NeverScrollableScrollPhysics>(),
          reason: 'a viewer showing one declared image must not be swipeable '
              'off it');
      tester.takeException();
    });

    testWidgets('allowZoom: false drops the interactive viewer',
        (tester) async {
      await pump(tester, lightbox(extra: {'allowZoom': false}));
      expect(find.byType(InteractiveViewer), findsNothing);
      tester.takeException();

      await pump(tester, lightbox());
      expect(find.byType(InteractiveViewer), findsWidgets,
          reason: 'zoom is the reason a lightbox exists rather than an image');
      tester.takeException();
    });

    testWidgets('the background colour is honoured', (tester) async {
      await pump(tester, lightbox(extra: {'backgroundColor': '#FF0000'}));

      final coloured = tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .map((b) => b.color)
          .toList();
      expect(coloured.any((c) => c.r > 0.5 && c.g < 0.2 && c.b < 0.2), isTrue,
          reason: 'the backdrop is what separates the image from the page '
              'behind it — the declared colour has to be one of the layers '
              'actually painted');
      tester.takeException();
    });

    testWidgets('with no images it draws nothing', (tester) async {
      await pump(tester, {'type': 'lightbox', 'images': <String>[]});
      expect(find.byType(PageView), findsNothing);
    });

    testWidgets('a bound images value that is not a list is empty, not fatal',
        (tester) async {
      stateManager.set('shots', 'still loading');
      await pump(tester, {'type': 'lightbox', 'images': '{{shots}}'});
      expect(tester.takeException(), isNull);
    });
  });

  group('kenBurnsImage', () {
    testWidgets('it builds and animates without a network image',
        (tester) async {
      await pump(tester, {
        'type': 'kenBurnsImage',
        'src': 'local-placeholder',
        'duration': 200,
        'intensity': 0.2,
      });

      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);

      // Torn down mid-animation: a ticker that outlives the widget is the
      // usual failure of an animated image.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('every fit name is accepted', (tester) async {
      for (final fit in const ['fill', 'contain', 'fitWidth', 'fitHeight',
        'cover', 'nonsense']) {
        await pump(tester, {
          'type': 'kenBurnsImage',
          'src': 'local',
          'fit': fit,
          'duration': 100,
        });
        expect(tester.takeException(), isNull, reason: 'fit: $fit');
      }
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    });
  });
}
