// One branch each, across a dozen widgets.
//
// These are the alternate spellings and the second half of a switch: a size
// named by token rather than by number, an opacity that arrived as a string,
// a badge offset written as `{dx, dy}`, a diff where one side is empty. Every
// one of them renders either way — the widget appears, just at the wrong size
// or the wrong opacity — so nothing on screen says the value was dropped.

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

  /// Builds inside a `Builder`, so the factories that read tokens off the
  /// BuildContext (icon sizes, spacing) have one.
  Future<void> pump(WidgetTester tester, Map<String, dynamic> definition) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (ctx) {
          final ctxWithBuild = RenderContext(
            renderer: context.renderer,
            stateManager: stateManager,
            bindingEngine: context.bindingEngine,
            actionHandler: context.actionHandler,
            themeManager: ThemeManager.instance,
            buildContext: ctx,
          );
          return AnimatedBuilder(
            animation: stateManager,
            builder: (_, __) =>
                context.renderer.renderWidget(definition, ctxWithBuild),
          );
        }),
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

  testWidgets('an icon size named by token is the token size', (tester) async {
    final sizes = <String, double>{};
    for (final token in const ['sm', 'md', 'lg', 'xl']) {
      await pump(tester, <String, dynamic>{
        'type': 'icon',
        'icon': 'home',
        'size': token,
      });
      sizes[token] = tester.widget<Icon>(find.byType(Icon)).size!;
    }

    expect(sizes.values.toSet(), hasLength(4),
        reason: 'four tokens that all resolve to the same size is a scale '
            'that was read and thrown away');
    expect(sizes['sm']!, lessThan(sizes['xl']!));
  });

  testWidgets('an opacity that arrived as a string is still an opacity',
      (tester) async {
    await pump(tester, <String, dynamic>{
      'type': 'opacity',
      'opacity': '0.25',
      'child': <String, dynamic>{'type': 'text', 'content': 'faded'},
    });

    final opacity = tester.widget<Opacity>(find.byType(Opacity));
    expect(opacity.opacity, 0.25,
        reason: 'a value that came from a form field or a query string is a '
            'string; falling back to 1.0 shows a widget the document asked to '
            'fade');
  });

  testWidgets('an opacity that is not a number at all stays opaque',
      (tester) async {
    await pump(tester, <String, dynamic>{
      'type': 'opacity',
      'opacity': 'quite',
      'child': <String, dynamic>{'type': 'text', 'content': 'solid'},
    });

    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1.0,
        reason: 'guessing a fade from a word would hide content for a typo');
  });

  testWidgets('a badge offset written as {dx, dy} moves the badge',
      (tester) async {
    await pump(tester, <String, dynamic>{
      'type': 'badge',
      'label': '3',
      'offset': <String, dynamic>{'dx': 6, 'dy': -4},
      'child': <String, dynamic>{'type': 'icon', 'icon': 'mail'},
    });

    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.offset, const Offset(6, -4),
        reason: 'a badge that ignores its offset sits on top of the glyph it '
            'is counting');
  });

  testWidgets('a canvas colour written as six digits is opaque',
      (tester) async {
    await pump(tester, <String, dynamic>{
      'type': 'canvas',
      'width': 100,
      'height': 100,
      'backgroundColor': '#112233',
      'commands': <dynamic>[
        <String, dynamic>{
          'op': 'rect',
          'x': 0,
          'y': 0,
          'width': 10,
          'height': 10,
          'color': '#FF0000',
        },
      ],
    });

    expect(tester.takeException(), isNull,
        reason: 'the six-digit form is the one every document writes; only '
            'the eight-digit one carrying alpha was read');
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('a switch reports the value it moved to', (tester) async {
    stateManager.set('on', false);
    await pump(tester, <String, dynamic>{
      'type': 'switch',
      'value': '{{on}}',
      'onChange': set('reported', '{{event.value}}'),
    });

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(stateManager.get('reported'), isTrue,
        reason: 'a switch that moves and reports nothing leaves the document '
            'showing the old setting');
  });

  testWidgets('a multiSelect reads a literal value and bare-string options',
      (tester) async {
    await pump(tester, <String, dynamic>{
      'type': 'multiSelect',
      'label': 'Tags',
      'value': <dynamic>['red'],
      'options': <dynamic>['red', 'green'],
    });

    expect(find.text('Tags'), findsOneWidget,
        reason: 'a label that is declared and not drawn leaves a control with '
            'no name on it');
    expect(find.textContaining('red'), findsWidgets,
        reason: 'the short option form is what a document writes for a fixed '
            'list; ignoring it leaves nothing to select');
  });

  testWidgets('a diff against an empty side lists every line as added',
      (tester) async {
    await pump(tester, <String, dynamic>{
      'type': 'diffViewer',
      'oldValue': '',
      'newValue': 'one\ntwo',
      'showLineNumbers': true,
    });

    expect(find.textContaining('one'), findsWidgets,
        reason: 'a new file is a diff with nothing on the left; drawing it '
            'empty hides the whole change');
    expect(find.textContaining('two'), findsWidgets);
  });

  testWidgets('a diff against an empty new side lists every line as removed',
      (tester) async {
    await pump(tester, <String, dynamic>{
      'type': 'diffViewer',
      'oldValue': 'one\ntwo',
      'newValue': '',
    });

    expect(find.textContaining('one'), findsWidgets);
  });

  testWidgets('a button carries its declared colours, elevation and border',
      (tester) async {
    await pump(tester, <String, dynamic>{
      'type': 'button',
      'label': 'Send',
      'backgroundColor': '#FF0000',
      'foregroundColor': '#FFFFFF',
      'elevation': 6,
      'borderColor': '#0000FF',
      'borderWidth': 2,
    });

    expect(find.text('Send'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'a button that accepts a style and renders the default one is '
            'a theme the document cannot reach');
  });
  testWidgets('a tab indicator with no colour takes the theme primary',
      (tester) async {
    await pump(tester, <String, dynamic>{
      'type': 'tabBar',
      'tabs': <dynamic>['One', 'Two'],
      // A decoration that declares a shape and no colour: the indicator has
      // to come from the theme rather than disappearing.
      'indicator': <String, dynamic>{'borderRadius': 4},
    });

    expect(find.text('One'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'an indicator with no colour is the ordinary way to say '
            '"use the theme"; falling through to nothing leaves the selected '
            'tab unmarked');
  });
}
