// What a `button` looks like once the document has styled it.
//
// The variants are covered elsewhere; what was not is the styling applied to
// each of them — background, foreground, elevation, border — and the semantic
// override. Every one of those is a separate `styleFrom` per variant, four
// nearly-identical blocks, and a property wired in one and forgotten in
// another is invisible from a screenshot of the one that works.

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
        body: Center(
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

  /// The style the built button will actually paint with.
  ///
  /// By predicate rather than by type: `byType` matches the exact runtime
  /// type, and each variant is a different subclass of `ButtonStyleButton`.
  ButtonStyle styleOf(WidgetTester tester) {
    final button = tester.widget<ButtonStyleButton>(
        find.byWidgetPredicate((w) => w is ButtonStyleButton).first);
    return button.style!;
  }

  Color? background(WidgetTester tester) =>
      styleOf(tester).backgroundColor?.resolve(<WidgetState>{});

  Color? foreground(WidgetTester tester) =>
      styleOf(tester).foregroundColor?.resolve(<WidgetState>{});

  Map<String, dynamic> button({
    required String variant,
    Map<String, dynamic> extra = const {},
  }) =>
      {
        'type': 'button',
        'label': 'Send',
        'variant': variant,
        ...extra,
      };

  // A `variant` the runtime does not know is an ordinary authoring slip, and
  // it is also what a document written against a newer spec looks like on an
  // older runtime. The fallback branch answers both: draw the default button
  // and carry the declared styling through it, rather than drawing nothing.
  group('a variant nobody defined', () {
    testWidgets('falls back to the default button, styling and all',
        (tester) async {
      await pump(
          tester,
          button(variant: 'fancy', extra: {
            'backgroundColor': '#FF0000',
            'foregroundColor': '#00FF00',
            'elevation': 3,
          }));

      expect(find.text('Send'), findsOneWidget,
          reason: 'the label is the document\'s content — an unknown variant '
              'must not cost the button itself');
      expect(background(tester), const Color(0xFFFF0000));
      expect(foreground(tester), const Color(0xFF00FF00));
      expect(styleOf(tester).elevation?.resolve(<WidgetState>{}), 3.0);
    });

    testWidgets('and its aria label still reaches the tree', (tester) async {
      await pump(
          tester,
          button(variant: 'fancy', extra: {'ariaLabel': 'Send the report'}));

      expect(find.text('Send'), findsOneWidget);
      expect(find.bySemanticsLabel('Send the report'), findsOneWidget,
          reason: 'the wrapper is written per variant, so a branch that '
              'forgets it silently drops the label a screen reader reads');
    });

    testWidgets('a border declared on it is drawn too', (tester) async {
      await pump(
          tester,
          button(variant: 'fancy',
              extra: {'borderColor': '#0000FF', 'borderWidth': 2}));

      final side = styleOf(tester).side?.resolve(<WidgetState>{});
      expect(side?.color, const Color(0xFF0000FF));
      expect(side?.width, 2.0);
    });
  });

  group('every variant carries its declared colours', () {
    for (final variant in const ['elevated', 'outlined', 'filled', 'text']) {
      testWidgets('$variant applies backgroundColor and foregroundColor',
          (tester) async {
        await pump(
            tester,
            button(variant: variant, extra: {
              'backgroundColor': '#FF0000',
              'foregroundColor': '#00FF00',
            }));

        expect(background(tester), const Color(0xFFFF0000),
            reason: 'each variant builds its own style block, so a property '
                'wired in one and missed in another is invisible until a '
                'document uses that one');
        expect(foreground(tester), const Color(0xFF00FF00));
      });

      testWidgets('$variant applies elevation', (tester) async {
        await pump(
            tester, button(variant: variant, extra: {'elevation': 6}));

        expect(styleOf(tester).elevation?.resolve(<WidgetState>{}), 6.0);
      });

      testWidgets('$variant applies a declared border', (tester) async {
        await pump(
            tester,
            button(variant: variant, extra: {
              'borderColor': '#0000FF',
              'borderWidth': 3,
            }));

        final side = styleOf(tester).side?.resolve(<WidgetState>{});
        expect(side, isNotNull,
            reason: 'a declared border that draws nothing leaves the button '
                'looking like a different variant');
        expect(side!.color, const Color(0xFF0000FF));
        expect(side.width, 3.0);
      });

      testWidgets('$variant takes an ariaLabel without losing its own label',
          (tester) async {
        await pump(
            tester,
            button(variant: variant, extra: {'ariaLabel': 'Send the report'}));

        expect(find.text('Send'), findsOneWidget);
        expect(
            find.bySemanticsLabel('Send the report'), findsOneWidget,
            reason: '§13 — the visible label is short by design, and the '
                'screen reader needs the long one');
      });
    }
  });

  group('a border with no colour', () {
    testWidgets('still draws, at the declared width', (tester) async {
      await pump(
          tester,
          button(variant: 'outlined', extra: {'borderWidth': 4}));

      final side = styleOf(tester).side?.resolve(<WidgetState>{});
      expect(side!.width, 4.0);
    });

    testWidgets('a colour with no width draws at the default width',
        (tester) async {
      await pump(
          tester,
          button(variant: 'outlined', extra: {'borderColor': '#0000FF'}));

      final side = styleOf(tester).side?.resolve(<WidgetState>{});
      expect(side!.color, const Color(0xFF0000FF));
      expect(side.width, 1.0);
    });
  });

  group('the icon variant', () {
    testWidgets('is an IconButton carrying the declared icon and colour',
        (tester) async {
      await pump(tester, {
        'type': 'button',
        'label': 'Send',
        'variant': 'icon',
        'icon': 'send',
        'foregroundColor': '#FF0000',
      });

      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.color, const Color(0xFFFF0000));
      expect(find.byIcon(Icons.send), findsOneWidget);
      expect(iconButton.tooltip, 'Send',
          reason: 'an icon with no label is unreadable to a screen reader and '
              'ambiguous to everyone else');
    });

    testWidgets('an ariaLabel becomes the tooltip', (tester) async {
      await pump(tester, {
        'type': 'button',
        'label': 'Send',
        'variant': 'icon',
        'icon': 'send',
        'ariaLabel': 'Send the report',
      });

      expect(tester.widget<IconButton>(find.byType(IconButton)).tooltip,
          'Send the report');
    });

    testWidgets('with an action, tapping runs it', (tester) async {
      await pump(tester, {
        'type': 'button',
        'label': 'Send',
        'variant': 'icon',
        'icon': 'send',
        'onTap': {
          'type': 'state',
          'action': 'set',
          'binding': 'sent',
          'value': true,
        },
      });

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(stateManager.get('sent'), isTrue);
    });

    testWidgets('with no action it is still pressable, and does nothing',
        (tester) async {
      await pump(tester, {
        'type': 'button',
        'label': 'Send',
        'variant': 'icon',
        'icon': 'send',
      });

      expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed,
          isNotNull,
          reason: 'a button with no action yet is not a DISABLED button — '
              'greying it out would say the opposite of what the document '
              'means');
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('disabled means not pressable', (tester) async {
      await pump(tester, {
        'type': 'button',
        'label': 'Send',
        'variant': 'icon',
        'icon': 'send',
        'disabled': true,
        'onTap': {
          'type': 'state',
          'action': 'set',
          'binding': 'sent',
          'value': true,
        },
      });

      expect(
          tester.widget<IconButton>(find.byType(IconButton)).onPressed, isNull);
    });

    testWidgets('the icon variant with no icon falls back to a normal button',
        (tester) async {
      await pump(tester, button(variant: 'icon'));

      expect(find.byType(IconButton), findsNothing);
      expect(find.text('Send'), findsOneWidget,
          reason: 'an icon variant with no icon has nothing to draw; dropping '
              'to the labelled button keeps the control usable');
    });
  });

  group('an elevation token', () {
    testWidgets('resolves through the theme rather than being ignored',
        (tester) async {
      await pump(
          tester, button(variant: 'elevated', extra: {'elevation': 'level1'}));

      final elevation = styleOf(tester).elevation?.resolve(<WidgetState>{});
      expect(elevation, isNotNull,
          reason: 'a token spelling that resolves to null makes a raised '
              'button flat, which reads as a different control');
    });
  });
}
