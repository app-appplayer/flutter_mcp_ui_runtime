// The decoration resolver — every surface in a document goes through it.
//
// `box`, `card`, `container` and a dozen others hand it the same property map,
// so one unread key is that key silently doing nothing on every widget at
// once. The uncovered part was the shapes an author reaches for once the plain
// colour is not enough: the radial and sweep gradients, the background image
// with its fit and its tint, the per-side border, the backdrop blur.

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

/// A 1×1 transparent png — a real image with no network behind it.
const _pixel =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

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
        body: Center(
          child: AnimatedBuilder(
            animation: stateManager,
            builder: (_, __) =>
                context.renderer.renderWidget(definition, context),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  Map<String, dynamic> box(Map<String, dynamic> extra) => {
        'type': 'box',
        'width': 100.0,
        'height': 100.0,
        ...extra,
      };

  /// The decoration the box actually painted with.
  BoxDecoration decorationOf(WidgetTester tester) {
    final container = tester
        .widgetList<Container>(find.byType(Container))
        .firstWhere((c) => c.decoration is BoxDecoration);
    return container.decoration! as BoxDecoration;
  }

  group('where the properties may be written', () {
    testWidgets('flat top-level keys are read', (tester) async {
      await pump(tester, box({'color': '#FF0000'}));

      expect(decorationOf(tester).color, const Color(0xFFFF0000));
    });

    testWidgets('a nested decoration block is read', (tester) async {
      await pump(tester, box({
        'decoration': {'color': '#00FF00'},
      }));

      expect(decorationOf(tester).color, const Color(0xFF00FF00));
    });

    testWidgets('a flat key overrides the nested one', (tester) async {
      await pump(tester, box({
        'decoration': {'color': '#00FF00'},
        'color': '#0000FF',
      }));

      expect(decorationOf(tester).color, const Color(0xFF0000FF));
    });

    testWidgets('a decoration bound to state resolves through the binding',
        (tester) async {
      stateManager.set('surface', {'color': '#123456'});
      await pump(tester, box({'decoration': '{{surface}}'}));

      expect(decorationOf(tester).color, const Color(0xFF123456));
    });

    testWidgets('a decoration binding that resolves to a scalar is ignored',
        (tester) async {
      stateManager.set('surface', 'dark');
      await pump(tester, box({'decoration': '{{surface}}', 'color': '#FF0000'}));

      expect(decorationOf(tester).color, const Color(0xFFFF0000),
          reason: 'a half-loaded theme must not erase the colour the document '
              'declared beside it');
    });
  });

  group('gradients', () {
    testWidgets('a linear gradient is built with its stops and ends',
        (tester) async {
      await pump(tester, box({
        'gradient': {
          'type': 'linear',
          'colors': ['#FF0000', '#0000FF'],
          'stops': [0.2, 0.8],
          'begin': 'topLeft',
          'end': 'bottomRight',
        },
      }));

      final gradient = decorationOf(tester).gradient! as LinearGradient;
      expect(gradient.colors,
          [const Color(0xFFFF0000), const Color(0xFF0000FF)]);
      expect(gradient.stops, [0.2, 0.8]);
      expect(gradient.begin, Alignment.topLeft);
      expect(gradient.end, Alignment.bottomRight);
    });

    testWidgets('a radial gradient carries its centre and radius',
        (tester) async {
      await pump(tester, box({
        'gradient': {
          'type': 'radial',
          'colors': ['#FF0000', '#0000FF'],
          'center': 'topCenter',
          'radius': 0.9,
        },
      }));

      final gradient = decorationOf(tester).gradient! as RadialGradient;
      expect(gradient.center, Alignment.topCenter);
      expect(gradient.radius, 0.9);
    });

    testWidgets('a sweep gradient carries its angles', (tester) async {
      await pump(tester, box({
        'gradient': {
          'type': 'sweep',
          'colors': ['#FF0000', '#0000FF'],
          'startAngle': 0.5,
          'endAngle': 3.0,
        },
      }));

      final gradient = decorationOf(tester).gradient! as SweepGradient;
      expect(gradient.startAngle, 0.5);
      expect(gradient.endAngle, 3.0);
    });

    testWidgets('an x/y alignment pair is accepted', (tester) async {
      await pump(tester, box({
        'gradient': {
          'type': 'linear',
          'colors': ['#FF0000', '#0000FF'],
          'begin': {'x': -0.5, 'y': 0.25},
        },
      }));

      final gradient = decorationOf(tester).gradient! as LinearGradient;
      expect(gradient.begin, const Alignment(-0.5, 0.25));
    });

    testWidgets('every tile mode spelling is read', (tester) async {
      for (final entry in const {
        'repeated': TileMode.repeated,
        'mirror': TileMode.mirror,
      }.entries) {
        await pump(tester, box({
          'gradient': {
            'type': 'linear',
            'colors': ['#FF0000', '#0000FF'],
            'tileMode': entry.key,
          },
        }));

        expect((decorationOf(tester).gradient! as LinearGradient).tileMode,
            entry.value,
            reason: 'tileMode "${entry.key}"');
      }
    });

    testWidgets('a gradient replaces the colour rather than fighting it',
        (tester) async {
      await pump(tester, box({
        'color': '#FF0000',
        'gradient': {
          'type': 'linear',
          'colors': ['#00FF00', '#0000FF'],
        },
      }));

      final decoration = decorationOf(tester);
      expect(decoration.gradient, isNotNull);
      expect(decoration.color, isNull,
          reason: 'BoxDecoration asserts when both are given, and the page '
              'would fail to build');
    });

    testWidgets('an unknown gradient type is ignored', (tester) async {
      await pump(tester, box({
        'color': '#FF0000',
        'gradient': {
          'type': 'conical',
          'colors': ['#00FF00'],
        },
      }));

      expect(decorationOf(tester).gradient, isNull);
      expect(decorationOf(tester).color, const Color(0xFFFF0000));
    });
  });

  group('a background image', () {
    testWidgets('is resolved, with its fit and alignment', (tester) async {
      await pump(tester, box({
        'image': {
          'image': _pixel,
          'fit': 'fitWidth',
          'alignment': 'bottomRight',
          'repeat': 'repeatX',
          'opacity': 0.5,
        },
      }));

      final image = decorationOf(tester).image!;
      expect(image.fit, BoxFit.fitWidth);
      expect(image.alignment, Alignment.bottomRight);
      expect(image.repeat, ImageRepeat.repeatX);
      expect(image.opacity, 0.5);
    });

    testWidgets('the source may be bound', (tester) async {
      stateManager.set('picture', _pixel);
      await pump(tester, box({
        'image': {'image': '{{picture}}'},
      }));

      expect(decorationOf(tester).image, isNotNull,
          reason: '§6.12.2 — an unresolved binding reaches the loader as a '
              'literal, matches no scheme, and the box renders with its '
              'colour and without its image on a document that was correct');
    });

    testWidgets('the legacy `src` key is accepted', (tester) async {
      await pump(tester, box({
        'image': {'src': _pixel},
      }));

      expect(decorationOf(tester).image, isNotNull);
    });

    testWidgets('every fit spelling is read', (tester) async {
      for (final entry in const {
        'fill': BoxFit.fill,
        'contain': BoxFit.contain,
        'cover': BoxFit.cover,
        'fitWidth': BoxFit.fitWidth,
        'fitHeight': BoxFit.fitHeight,
        'none': BoxFit.none,
        'scaleDown': BoxFit.scaleDown,
        'nonsense': BoxFit.cover,
      }.entries) {
        await pump(tester, box({
          'image': {'image': _pixel, 'fit': entry.key},
        }));

        expect(decorationOf(tester).image!.fit, entry.value,
            reason: 'fit "${entry.key}"');
      }
    });

    testWidgets('a colour filter tints it, in the declared blend mode',
        (tester) async {
      for (final mode in const [
        'srcIn',
        'color',
        'screen',
        'overlay',
        'multiply',
      ]) {
        await pump(tester, box({
          'image': {
            'image': _pixel,
            'colorFilter': {'color': '#FF0000', 'blendMode': mode},
          },
        }));

        expect(decorationOf(tester).image!.colorFilter, isNotNull,
            reason: 'blendMode "$mode"');
      }
    });

    testWidgets('a colour filter with no colour is dropped', (tester) async {
      await pump(tester, box({
        'image': {
          'image': _pixel,
          'colorFilter': {'blendMode': 'srcIn'},
        },
      }));

      expect(decorationOf(tester).image!.colorFilter, isNull);
    });

    testWidgets('a source that resolves to nothing leaves no image',
        (tester) async {
      await pump(tester, box({
        'color': '#FF0000',
        'image': {'image': 'not-a-scheme://x.png'},
      }));

      expect(decorationOf(tester).image, isNull);
      expect(decorationOf(tester).color, const Color(0xFFFF0000),
          reason: 'the rest of the surface still has to draw');
    });
  });

  group('borders and shape', () {
    testWidgets('a uniform border is built', (tester) async {
      await pump(tester, box({
        'border': {'color': '#FF0000', 'width': 3},
      }));

      final border = decorationOf(tester).border! as Border;
      expect(border.top.color, const Color(0xFFFF0000));
      expect(border.top.width, 3);
    });

    testWidgets('a per-side selection leaves the other sides bare',
        (tester) async {
      await pump(tester, box({
        'border': {
          'color': '#FF0000',
          'width': 3,
          'top': true,
          'bottom': true,
        },
      }));

      final border = decorationOf(tester).border! as Border;
      expect(border.top.width, 3);
      expect(border.bottom.width, 3);
      expect(border.left, BorderSide.none,
          reason: 'a divider written as a bottom border and drawn on all four '
              'sides is a box where the document asked for a line');
      expect(border.right, BorderSide.none);
    });

    testWidgets('a circle shape is read', (tester) async {
      await pump(tester, box({'color': '#FF0000', 'shape': 'circle'}));

      expect(decorationOf(tester).shape, BoxShape.circle);
    });

    testWidgets('a border radius is read', (tester) async {
      await pump(tester, box({'color': '#FF0000', 'borderRadius': 12}));

      expect(decorationOf(tester).borderRadius, BorderRadius.circular(12));
    });

    testWidgets('a shadow is built, under both spellings', (tester) async {
      await pump(tester, box({
        'color': '#FF0000',
        'boxShadow': [
          {'color': '#000000', 'blurRadius': 8, 'offsetY': 4},
        ],
      }));
      expect(decorationOf(tester).boxShadow, isNotEmpty);

      await pump(tester, box({
        'color': '#FF0000',
        'shadow': [
          {'color': '#000000', 'blurRadius': 8},
        ],
      }));
      expect(decorationOf(tester).boxShadow, isNotEmpty,
          reason: 'the legacy alias is still in bundles in the field');
    });
  });

  group('backdrop blur', () {
    testWidgets('a declared blur wraps the child in a filter', (tester) async {
      await pump(tester, box({'backdropBlur': 8}));

      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('a blur with a radius clips to it', (tester) async {
      await pump(tester, box({'backdropBlur': 8, 'borderRadius': 12}));

      expect(find.byType(ClipRRect), findsWidgets);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('no blur means no filter in the tree', (tester) async {
      await pump(tester, box({'color': '#FF0000'}));

      expect(find.byType(BackdropFilter), findsNothing,
          reason: 'a backdrop filter costs a saveLayer on every frame');
    });

    testWidgets('a blur declared inside the decoration block is read too',
        (tester) async {
      await pump(tester, box({
        'decoration': {'backdropBlur': 6},
      }));

      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('a zero or negative blur is not a filter', (tester) async {
      await pump(tester, box({'backdropBlur': 0}));

      expect(find.byType(BackdropFilter), findsNothing);
    });
  });

  group('nothing declared', () {
    testWidgets('draws no decoration at all', (tester) async {
      await pump(tester, {'type': 'box', 'width': 10.0, 'height': 10.0});

      final decorated = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.decoration != null);
      expect(decorated, isEmpty,
          reason: 'an empty BoxDecoration is still a paint pass');
    });
  });
}
