// `mediaQuery` — the breakpoint mode and the boolean condition form.
//
// This is how a document says "this layout on a phone, that one on a desktop".
// A breakpoint that finds no exact match must fall back to a neighbour rather
// than drawing nothing: a page that is blank at one window width and correct
// at another reads as a rendering bug, not a missing declaration.

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

  /// Renders [definition] at a fixed viewport width.
  Future<void> pumpAt(
    WidgetTester tester,
    double width,
    Map<String, dynamic> definition,
  ) async {
    // The default 800×600 surface would clamp anything wider, so a "desktop"
    // width would be measured as a tablet.
    await tester.binding.setSurfaceSize(Size(width + 100, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            height: 600,
            child: AnimatedBuilder(
              animation: stateManager,
              builder: (_, __) =>
                  context.renderer.renderWidget(definition, context),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> text(String content) =>
      <String, dynamic>{'type': 'text', 'content': content};

  group('breakpoint mode', () {
    Map<String, dynamic> byBreakpoint(Map<String, dynamic> breakpoints) =>
        <String, dynamic>{
          'type': 'mediaQuery',
          'breakpoints': breakpoints,
        };

    testWidgets('an exact match is used', (tester) async {
      await pumpAt(tester, 400, byBreakpoint(<String, dynamic>{
        'xs': text('phone'),
        'lg': text('desktop'),
      }));

      expect(find.text('phone'), findsOneWidget);
    });

    testWidgets('a wide viewport picks the wide declaration', (tester) async {
      await pumpAt(tester, 1300, byBreakpoint(<String, dynamic>{
        'xs': text('phone'),
        'lg': text('desktop'),
      }));

      expect(find.text('desktop'), findsOneWidget);
    });

    testWidgets('with no exact match it falls back to a smaller one',
        (tester) async {
      await pumpAt(tester, 1300, byBreakpoint(<String, dynamic>{
        'sm': text('small'),
      }));

      expect(find.text('small'), findsOneWidget,
          reason: 'a layout declared for a narrower window still works in a '
              'wider one; drawing nothing is the worse answer');
    });

    testWidgets('with nothing smaller it falls back to a larger one',
        (tester) async {
      await pumpAt(tester, 300, byBreakpoint(<String, dynamic>{
        'xl': text('wide'),
      }));

      expect(find.text('wide'), findsOneWidget);
    });

    testWidgets('a default child stands in when no breakpoint matches',
        (tester) async {
      await pumpAt(tester, 400, <String, dynamic>{
        'type': 'mediaQuery',
        'breakpoints': <String, dynamic>{},
        'defaultChild': text('fallback'),
      });

      expect(find.text('fallback'), findsOneWidget);
    });

    testWidgets('with nothing declared at all it draws nothing',
        (tester) async {
      await pumpAt(tester, 400, <String, dynamic>{'type': 'mediaQuery'});

      expect(tester.takeException(), isNull);
    });
  });

  group('condition mode', () {
    testWidgets('a width range decides which branch renders', (tester) async {
      Map<String, dynamic> wideOnly() => <String, dynamic>{
            'type': 'mediaQuery',
            'condition': <String, dynamic>{'minWidth': 800},
            'then': text('wide'),
            'orElse': text('narrow'),
          };

      await pumpAt(tester, 1000, wideOnly());
      expect(find.text('wide'), findsOneWidget);

      await pumpAt(tester, 400, wideOnly());
      expect(find.text('narrow'), findsOneWidget);
    });

    testWidgets('a maximum width is honoured too', (tester) async {
      await pumpAt(tester, 1000, <String, dynamic>{
        'type': 'mediaQuery',
        'condition': <String, dynamic>{'maxWidth': 600},
        'then': text('narrow'),
        'else': text('wide'),
      });

      expect(find.text('wide'), findsOneWidget,
          reason: '`else` is the legacy spelling of `orElse`; a document '
              'written with it must still choose a branch');
    });

    testWidgets('a height range is measured as well', (tester) async {
      await pumpAt(tester, 400, <String, dynamic>{
        'type': 'mediaQuery',
        'condition': <String, dynamic>{'minHeight': 900},
        'then': text('tall'),
        'orElse': text('short'),
      });

      expect(find.text('short'), findsOneWidget);

      await pumpAt(tester, 400, <String, dynamic>{
        'type': 'mediaQuery',
        'condition': <String, dynamic>{'maxHeight': 100},
        'then': text('tiny'),
        'orElse': text('roomy'),
      });

      expect(find.text('roomy'), findsOneWidget);
    });

    testWidgets('orientation is derived from the box, not the device',
        (tester) async {
      await pumpAt(tester, 300, <String, dynamic>{
        'type': 'mediaQuery',
        'condition': <String, dynamic>{'orientation': 'portrait'},
        'then': text('portrait'),
        'orElse': text('landscape'),
      });
      expect(find.text('portrait'), findsOneWidget);

      await pumpAt(tester, 1200, <String, dynamic>{
        'type': 'mediaQuery',
        'condition': <String, dynamic>{'orientation': 'landscape'},
        'then': text('landscape'),
        'orElse': text('portrait'),
      });
      expect(find.text('landscape'), findsOneWidget);
    });

    testWidgets('a named breakpoint is matched by name', (tester) async {
      await pumpAt(tester, 400, <String, dynamic>{
        'type': 'mediaQuery',
        'condition': <String, dynamic>{'breakpoint': 'xs'},
        'then': text('phone'),
        'orElse': text('other'),
      });

      expect(find.text('phone'), findsOneWidget);
    });

    testWidgets('a plain boolean decides directly, with nothing measured',
        (tester) async {
      stateManager.set('compact', true);

      await pumpAt(tester, 1200, <String, dynamic>{
        'type': 'mediaQuery',
        'condition': '{{compact}}',
        'then': text('compact'),
        'orElse': text('full'),
      });
      expect(find.text('compact'), findsOneWidget,
          reason: 'the property may bind to a boolean rather than a '
              'constraint object — reading it as a Map threw on a shape the '
              'schema allows');

      stateManager.set('compact', false);
      await tester.pumpAndSettle();
      expect(find.text('full'), findsOneWidget);
    });

    testWidgets('a boolean branch that is not declared draws nothing',
        (tester) async {
      await pumpAt(tester, 400, <String, dynamic>{
        'type': 'mediaQuery',
        'condition': true,
      });

      expect(tester.takeException(), isNull);
    });
  });
}
