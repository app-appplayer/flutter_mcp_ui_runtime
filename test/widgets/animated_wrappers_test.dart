// The implicit-animation wrappers and `hero`.
//
// Each of these is a Flutter widget with one job: animate a property when the
// document changes it. What matters is that the declared duration, curve and
// end callback reach the widget — an animation that snaps, or a chained step
// that never fires, is the property being dropped rather than a timing bug.

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
        body: AnimatedBuilder(
          animation: stateManager,
          builder: (_, __) => context.renderer.renderWidget(definition, context),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> text(String content) =>
      <String, dynamic>{'type': 'text', 'content': content};

  group('animatedOpacity', () {
    testWidgets('the declared opacity, duration and curve are applied',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'animatedOpacity',
        'opacity': 0.25,
        'duration': 250,
        'curve': 'bounceOut',
        'child': text('fading'),
      });

      final widget =
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
      expect(widget.opacity, 0.25);
      expect(widget.duration, const Duration(milliseconds: 250));
      expect(widget.curve, Curves.bounceOut);
      expect(find.text('fading'), findsOneWidget);
    });

    testWidgets('a duration given as a dimension object is read too',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'animatedOpacity',
        'opacity': 1,
        'duration': <String, dynamic>{'value': 400, 'unit': 'ms'},
        'child': text('fading'),
      });

      expect(
          tester
              .widget<AnimatedOpacity>(find.byType(AnimatedOpacity))
              .duration,
          const Duration(milliseconds: 400),
          reason: '§2 dimensions may arrive as an object; falling back to the '
              'default makes the declared timing decorative');
    });

    testWidgets('an unknown curve name falls back rather than throwing',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'animatedOpacity',
        'opacity': 1,
        'curve': 'springy',
        'child': text('x'),
      });

      expect(
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).curve,
          Curves.easeInOut);
    });

    testWidgets('every named curve resolves to a distinct curve',
        (tester) async {
      const names = <String, Curve>{
        'linear': Curves.linear,
        'standard': Curves.fastOutSlowIn,
        'standardAccelerate': Curves.easeIn,
        'standardDecelerate': Curves.easeOut,
        'easeIn': Curves.easeIn,
        'easeOut': Curves.easeOut,
        'easeInOut': Curves.easeInOut,
        'emphasized': Curves.easeInOutCubicEmphasized,
        'emphasizedAccelerate': Curves.easeInCubic,
        'emphasizedDecelerate': Curves.easeOutCubic,
        'bounceIn': Curves.bounceIn,
        'bounceOut': Curves.bounceOut,
      };

      for (final entry in names.entries) {
        await pump(tester, <String, dynamic>{
          'type': 'animatedOpacity',
          'opacity': 1,
          'curve': entry.key,
          'child': text('x'),
        });
        expect(
            tester
                .widget<AnimatedOpacity>(find.byType(AnimatedOpacity))
                .curve,
            entry.value,
            reason: entry.key);
      }
    });

    testWidgets('onEnd fires once the animation settles', (tester) async {
      stateManager.set('shown', 0.0);
      await pump(tester, <String, dynamic>{
        'type': 'animatedOpacity',
        'opacity': '{{shown}}',
        'duration': 100,
        'onEnd': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'settled',
          'value': true,
        },
        'child': text('x'),
      });

      stateManager.set('shown', 1.0);
      await tester.pumpAndSettle();

      expect(stateManager.get('settled'), isTrue,
          reason: 'a document that chains its next step onto `onEnd` never '
              'gets there if the callback is dropped');
    });

    testWidgets('with no child it still animates a box', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'animatedOpacity',
        'opacity': 0.5,
      });

      expect(find.byType(AnimatedOpacity), findsOneWidget);
    });
  });

  group('animatedAlign', () {
    testWidgets('the declared alignment is applied', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'animatedAlign',
        'alignment': 'bottomRight',
        'duration': 200,
        'child': text('corner'),
      });

      final widget = tester.widget<AnimatedAlign>(find.byType(AnimatedAlign));
      expect(widget.alignment, Alignment.bottomRight);
      expect(widget.duration, const Duration(milliseconds: 200));
    });
  });

  group('animatedPositioned', () {
    testWidgets('the declared edges are applied inside a stack',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'stack',
        'children': <dynamic>[
          <String, dynamic>{
            'type': 'animatedPositioned',
            'left': 10,
            'top': 20,
            'width': 30,
            'height': 40,
            'duration': 150,
            'child': text('placed'),
          },
        ],
      });

      final widget =
          tester.widget<AnimatedPositioned>(find.byType(AnimatedPositioned));
      expect(widget.left, 10);
      expect(widget.top, 20);
      expect(widget.width, 30);
      expect(widget.height, 40);
    });
  });

  group('animatedDefaultTextStyle', () {
    testWidgets('the declared style reaches the text', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'animatedDefaultTextStyle',
        'duration': 200,
        'style': <String, dynamic>{
          'fontSize': 20,
          'fontWeight': 'bold',
          'color': '#FF0000',
          'letterSpacing': 1.5,
          'height': 1.4,
        },
        'child': text('styled'),
      });

      // Material inserts its own text-style animators, so this reads the one
      // wrapping our child.
      final style = tester
          .widget<AnimatedDefaultTextStyle>(find
              .ancestor(
                of: find.text('styled'),
                matching: find.byType(AnimatedDefaultTextStyle),
              )
              .first)
          .style;
      expect(style.fontSize, 20);
      expect(style.fontWeight, FontWeight.w700);
      expect(style.color, const Color(0xFFFF0000));
      expect(style.letterSpacing, 1.5);
      expect(style.height, 1.4);
    });

    testWidgets('every weight spelling is read, including the numeric one',
        (tester) async {
      Future<FontWeight?> weightOf(dynamic declared) async {
        await pump(tester, <String, dynamic>{
          'type': 'animatedDefaultTextStyle',
          'style': <String, dynamic>{'fontWeight': declared},
          'child': text('x'),
        });
        return tester
            .widget<AnimatedDefaultTextStyle>(find
                .ancestor(
                  of: find.text('x'),
                  matching: find.byType(AnimatedDefaultTextStyle),
                )
                .first)
            .style
            .fontWeight;
      }

      expect(await weightOf('thin'), FontWeight.w100);
      expect(await weightOf('w200'), FontWeight.w200);
      expect(await weightOf('light'), FontWeight.w300);
      expect(await weightOf('regular'), FontWeight.w400);
      expect(await weightOf('medium'), FontWeight.w500);
      expect(await weightOf('semiBold'), FontWeight.w600);
      expect(await weightOf('bold'), FontWeight.w700);
      expect(await weightOf('extraBold'), FontWeight.w800);
      expect(await weightOf('black'), FontWeight.w900);
      expect(await weightOf(700), FontWeight.w700,
          reason: 'a numeric weight is what a design token file emits');
      expect(await weightOf('heavy'), isNull);
      expect(await weightOf(9999), isNull,
          reason: 'a weight outside the scale is a typo, not a reason to '
              'fail the page');
    });
  });

  group('hero', () {
    testWidgets('the tag and gesture flag are applied', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'hero',
        'tag': 'photo-1',
        'transitionOnUserGestures': true,
        'child': text('photo'),
      });

      final hero = tester.widget<Hero>(find.byType(Hero));
      expect(hero.tag, 'photo-1');
      expect(hero.transitionOnUserGestures, isTrue);
      expect(hero.flightShuttleBuilder, isNull);
    });

    testWidgets('a declared flight shuttle is wired', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'hero',
        'tag': 'photo-1',
        'flightShuttleBuilder': text('in flight'),
        'child': text('photo'),
      });

      expect(tester.widget<Hero>(find.byType(Hero)).flightShuttleBuilder,
          isNotNull,
          reason: 'the shuttle is what the user sees mid-morph; leaving the '
              'callback null shows the destination widget flying instead');
    });
  });
}
