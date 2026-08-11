// `radioGroup`'s two layouts and its selection, and `card`'s declared shapes.
//
// A radio group is one control made of several: the selection lives on the
// group, not on the tiles, so a tap that lands on a tile and never reaches
// the group leaves a form where nothing can be chosen. `card`'s shape is
// cosmetic until it is not — a shape name the runtime does not recognise
// falls back to a plain rectangle, which looks like a card that was never
// styled.

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

import '../behaviour/painted_probe.dart';

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

  group('radioGroup', () {
    Map<String, dynamic> group({Map<String, dynamic> extra = const {}}) =>
        <String, dynamic>{
          'type': 'radioGroup',
          'binding': 'choice',
          'options': <dynamic>[
            <String, dynamic>{'value': 'a', 'label': 'Option A'},
            <String, dynamic>{'value': 'b', 'label': 'Option B'},
          ],
          ...extra,
        };

    testWidgets('tapping an option writes it to the binding', (tester) async {
      await pump(tester, group());

      await tester.tap(find.text('Option B'));
      await tester.pumpAndSettle();

      expect(stateManager.get<String>('choice'), 'b',
          reason: 'the selection lives on the group; a tap that reaches the '
              'tile and stops there leaves a form where nothing can be '
              'chosen');
    });

    testWidgets('the bound value is the one shown as selected',
        (tester) async {
      stateManager.set('choice', 'b');
      await pump(tester, group());

      final tiles = tester
          .widgetList<RadioListTile<String>>(find.byType(RadioListTile<String>))
          .toList();
      final radioGroup = tester.widget<RadioGroup<String>>(
          find.byType(RadioGroup<String>));

      expect(radioGroup.groupValue, 'b',
          reason: 'a document that restores a saved answer must see it ticked, '
              'or the user re-answers a question they already answered');
      expect(tiles.map((t) => t.value), <String>['a', 'b']);
    });

    testWidgets('options given as bare strings are their own label and value',
        (tester) async {
      await pump(tester, group(extra: <String, dynamic>{
        'options': <dynamic>['Yes', 'No'],
      }));

      expect(find.text('Yes'), findsOneWidget);

      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();

      expect(stateManager.get<String>('choice'), 'No',
          reason: 'the short form is what a document writes for a yes/no; '
              'dropping it would make the options unselectable');
    });

    testWidgets('a horizontal group lays its options in a row', (tester) async {
      await pump(tester, group(extra: <String, dynamic>{
        'direction': 'horizontal',
      }));

      final a = tester.getCenter(find.text('Option A'));
      final b = tester.getCenter(find.text('Option B'));

      expect(b.dx, greaterThan(a.dx),
          reason: 'a horizontal group that stacks vertically ignores the only '
              'layout choice the widget offers');
      expect(a.dy, b.dy);
    });

    testWidgets('a vertical group stacks them', (tester) async {
      await pump(tester, group());

      expect(tester.getCenter(find.text('Option B')).dy,
          greaterThan(tester.getCenter(find.text('Option A')).dy));
    });

    testWidgets('a disabled group takes no answer', (tester) async {
      await pump(tester, group(extra: <String, dynamic>{'enabled': false}));

      await tester.tap(find.text('Option B'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(stateManager.get('choice'), isNull,
          reason: 'a disabled control that still writes is worse than one '
              'that is not disabled at all');
    });
  });

  group('card shapes', () {
    ShapeBorder? shapeOf(WidgetTester tester) =>
        tester.widget<Card>(find.byType(Card)).shape;

    Future<void> pumpCard(WidgetTester tester, Object? shape) => pump(
          tester,
          <String, dynamic>{
            'type': 'card',
            if (shape != null) 'shape': shape,
            'child': <String, dynamic>{'type': 'text', 'content': 'body'},
          },
        );

    testWidgets('each declared shape is the one built', (tester) async {
      await pumpCard(tester, <String, dynamic>{'type': 'rounded', 'radius': 20});
      expect(shapeOf(tester), isA<RoundedRectangleBorder>());

      await pumpCard(tester, <String, dynamic>{'type': 'circle'});
      expect(shapeOf(tester), isA<CircleBorder>());

      await pumpCard(tester, <String, dynamic>{'type': 'stadium'});
      expect(shapeOf(tester), isA<StadiumBorder>());

      await pumpCard(tester, <String, dynamic>{'type': 'continuous'});
      expect(shapeOf(tester), isA<ContinuousRectangleBorder>(),
          reason: 'a shape name that falls through to the default gives a '
              'plain rectangle, which reads as a card that was never styled');
    });

    testWidgets('a shape nobody declared leaves the theme in charge',
        (tester) async {
      await pumpCard(tester, null);
      expect(shapeOf(tester), isNull);

      await pumpCard(tester, <String, dynamic>{'type': 'hexagon'});
      expect(shapeOf(tester), isNull,
          reason: 'an unknown shape is an authoring mistake; inventing one '
              'would hide it');
    });
  });
  // `flow` paints its children itself, through a delegate that applies a
  // paint transform. Nothing about that shows up in the widget tree — the
  // positions are the behaviour, and they are only visible in the pixels. A
  // delegate that ignores `direction` or `spacing` produces a pile in the
  // corner and every tree assertion still passes.
  group('flow', () {
    const colours = <String>['#FF0000', '#00AA00', '#0000FF'];

    Map<String, dynamic> flow({String? direction, double spacing = 0}) =>
        <String, dynamic>{
          'type': 'flow',
          if (direction != null) 'direction': direction,
          'spacing': spacing,
          'children': <dynamic>[
            for (final colour in colours)
              <String, dynamic>{
                'type': 'container',
                'width': 40,
                'height': 20,
                'color': colour,
              },
          ],
        };

    Future<Painted> pumpFlow(
      WidgetTester tester,
      Map<String, dynamic> definition, {
      Size size = const Size(100, 100),
    }) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFFFFFFFF),
          body: Center(
            child: isolated(
              SizedBox(
                width: size.width,
                height: size.height,
                child: context.renderer.renderWidget(definition, context),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      late Painted painted;
      await tester.runAsync(() async {
        painted = await paintedOf(
            tester, find.byKey(const ValueKey('painted-probe')));
      });
      return painted;
    }

    /// Where a block of [colour] starts, in the probe's own pixels.
    ({int x, int y}) cornerOf(Painted p, Color colour) {
      for (var y = 0; y < p.height; y++) {
        for (var x = 0; x < p.width; x++) {
          final c = p.at(x, y);
          if (c.a >= 0.5 &&
              (c.r * 255 - colour.r * 255).abs() <= 24 &&
              (c.g * 255 - colour.g * 255).abs() <= 24 &&
              (c.b * 255 - colour.b * 255).abs() <= 24) {
            return (x: x, y: y);
          }
        }
      }
      return (x: -1, y: -1);
    }

    const red = Color(0xFFFF0000);
    const green = Color(0xFF00AA00);
    const blue = Color(0xFF0000FF);

    testWidgets('children run across, then wrap to the next line',
        (tester) async {
      final painted = await pumpFlow(tester, flow());

      final first = cornerOf(painted, red);
      final second = cornerOf(painted, green);
      final third = cornerOf(painted, blue);

      expect(second.x, greaterThan(first.x));
      expect(second.y, first.y);
      expect(third.y, greaterThan(second.y),
          reason: 'two 40-wide children fit in 100 and the third does not; a '
              'flow that never wraps paints the rest off the edge');
      expect(third.x, first.x);
    });

    testWidgets('vertical runs down, then wraps to the next column',
        (tester) async {
      final painted = await pumpFlow(
        tester,
        flow(direction: 'vertical'),
        size: const Size(200, 50),
      );

      final first = cornerOf(painted, red);
      final second = cornerOf(painted, green);
      final third = cornerOf(painted, blue);

      expect(second.y, greaterThan(first.y));
      expect(second.x, first.x);
      expect(third.x, greaterThan(second.x),
          reason: 'a direction that is read and ignored gives the same '
              'picture for both words');
    });

    testWidgets('spacing separates the children', (tester) async {
      final tightPainted =
          await pumpFlow(tester, flow(), size: const Size(300, 100));
      final tight = cornerOf(tightPainted, green).x -
          cornerOf(tightPainted, red).x;

      final spacedPainted =
          await pumpFlow(tester, flow(spacing: 12), size: const Size(300, 100));
      final spaced = cornerOf(spacedPainted, green).x -
          cornerOf(spacedPainted, red).x;

      expect(spaced, greaterThan(tight),
          reason: 'a spacing that is read and dropped leaves the tags in a '
              'tag list touching each other');
    });
  });
}
