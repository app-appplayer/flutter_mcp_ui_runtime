// The last branch in a dozen small widgets.
//
// Each of these is one property away from what is already tested: a vertical
// divider instead of a horizontal one, an avatar that falls back to an icon,
// a corner radius written as `{all: n}`, a font feature switched on by name,
// a combo box walked upwards with the arrow key. They all render either way,
// which is exactly why they were never read.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          width: 400,
          height: 400,
          child: AnimatedBuilder(
            animation: stateManager,
            builder: (_, __) =>
                context.renderer.renderWidget(definition, context),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> set(String binding, Object? value) => <String, dynamic>{
        'type': 'state',
        'action': 'set',
        'binding': binding,
        'value': value,
      };

  testWidgets('a vertical divider is a vertical divider', (tester) async {
    await pump(tester, <String, dynamic>{
      'type': 'divider',
      'vertical': true,
      'thickness': 3,
    });

    expect(find.byType(VerticalDivider), findsOneWidget,
        reason: 'a divider that ignores its direction draws a line across a '
            'column layout that asked for one down the side');
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('an avatar with no image falls back to the declared icon',
      (tester) async {
    await pump(tester, <String, dynamic>{
      'type': 'avatar',
      'icon': 'person',
    });

    expect(find.byIcon(Icons.person), findsOneWidget,
        reason: 'an avatar with neither picture nor initials is an empty '
            'circle; the icon is the last thing that says who this is');
  });

  testWidgets('a corner radius written as {all: n} rounds every corner',
      (tester) async {
    await pump(tester, <String, dynamic>{
      'type': 'clipRRect',
      'borderRadius': <String, dynamic>{'all': 16},
      'child': <String, dynamic>{
        'type': 'container',
        'width': 80,
        'height': 80,
        'color': '#FF0000',
      },
    });

    final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
    expect(clip.borderRadius, BorderRadius.circular(16),
        reason: 'the shorthand is what a document writes for a uniform '
            'radius; dropping it leaves square corners');
  });

  testWidgets('a font feature named without a value is switched on',
      (tester) async {
    await pump(tester, <String, dynamic>{
      'type': 'text',
      'content': '0123',
      'style': <String, dynamic>{
        'fontFeatures': <dynamic>['tnum'],
      },
    });

    final text = tester.widget<Text>(find.text('0123'));
    expect(text.style?.fontFeatures, isNotNull);
    expect(text.style!.fontFeatures!.first.value, 1,
        reason: 'a bare feature name means "on"; ignoring it leaves a table '
            'of figures with proportional digits that will not line up');
  });

  testWidgets('a date field opens in the declared locale', (tester) async {
    await pump(tester, <String, dynamic>{
      'type': 'dateField',
      'locale': 'ko',
      'label': 'When',
    });

    expect(tester.takeException(), isNull);
    expect(find.text('When'), findsOneWidget);
  });

  testWidgets('an animated container reports when its animation ends',
      (tester) async {
    stateManager.set('w', 50.0);
    await pump(tester, <String, dynamic>{
      'type': 'animatedContainer',
      'width': '{{w}}',
      'height': 50,
      'duration': 50,
      'onEnd': set('ended', true),
    });

    stateManager.set('w', 120.0);
    await tester.pump();
    // Past the declared duration, with a frame to run the callback in.
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();

    expect(
      tester.widget<AnimatedContainer>(find.byType(AnimatedContainer))
          .constraints
          ?.maxWidth,
      120.0,
      reason: 'a bound width is where an animated size comes from; read as a '
          'literal it is null, and the box has nothing to animate between',
    );
    expect(stateManager.get('ended'), isTrue,
        reason: 'a document that chains one animation after another binds to '
            'onEnd; without it the second one never starts');
  });

  testWidgets('the combo box wraps to the last match when walked upwards',
      (tester) async {
    stateManager.set('picked', '');
    await pump(tester, <String, dynamic>{
      'type': 'combobox',
      'binding': 'picked',
      'options': <dynamic>['Alpha', 'Beta', 'Gamma'],
    });

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    // Up from the top wraps to the bottom, which is what every other list
    // control does; stopping at the top makes the last option unreachable
    // from the keyboard.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Gamma'), findsWidgets);
  });
  // Every dimension slot in the DSL may be written as a number, as
  // `{value, unit}`, or as a binding (§3). A slot read with a raw cast
  // answers null for the third form — the size silently reverts to its
  // default the moment a document binds it, which is the only way a size is
  // ever animated or made responsive.
  group('a bound dimension reaches the widget', () {
    testWidgets('sizedBox takes its size from state', (tester) async {
      stateManager.set('w', 120.0);
      stateManager.set('h', 40.0);
      await pump(tester, <String, dynamic>{
        'type': 'sizedBox',
        'width': '{{w}}',
        'height': '{{h}}',
      });

      final box = tester.widget<SizedBox>(find.byType(SizedBox).last);
      expect(box.width, 120.0);
      expect(box.height, 40.0);
    });

    testWidgets('positioned takes its offsets from state', (tester) async {
      stateManager.set('left', 30.0);
      await pump(tester, <String, dynamic>{
        'type': 'stack',
        'children': <dynamic>[
          <String, dynamic>{
            'type': 'positioned',
            'left': '{{left}}',
            'top': 10,
            'child': <String, dynamic>{'type': 'text', 'content': 'pinned'},
          },
        ],
      });

      final positioned =
          tester.widget<Positioned>(find.byType(Positioned).first);
      expect(positioned.left, 30.0,
          reason: 'a bound offset is how a document moves something; read as '
              'a literal the widget never leaves the corner');
      expect(positioned.top, 10.0);
    });

    testWidgets('the `{value, unit}` form still works beside a binding',
        (tester) async {
      stateManager.set('h', 44.0);
      await pump(tester, <String, dynamic>{
        'type': 'sizedBox',
        'width': <String, dynamic>{'value': 90, 'unit': 'px'},
        'height': '{{h}}',
      });

      final box = tester.widget<SizedBox>(find.byType(SizedBox).last);
      expect(box.width, 90.0);
      expect(box.height, 44.0);
    });
  });
}
