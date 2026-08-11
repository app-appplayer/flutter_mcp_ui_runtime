// Values a document does not write: the ones the THEME supplies.
//
// A menu's padding, a card's corner shape, an inset bound to state — each is
// read from a place the widget's own properties never mention, and each has a
// branch for the shape the theme happens to hold. A theme value that is read
// and dropped looks exactly like a theme that does not declare it, so the
// designer changes the token and nothing moves.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/menu_tokens.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StateManager stateManager;
  late RenderContext context;
  late ThemeManager theme;

  setUp(() {
    stateManager = StateManager()..initialize(<String, dynamic>{});
    final registry = WidgetRegistry();
    DefaultWidgets.registerAll(registry);
    final bindingEngine = BindingEngine();
    final actionHandler = ActionHandler();
    theme = ThemeManager.instance..reset();
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
      themeManager: theme,
    );
  });

  tearDown(() => ThemeManager.instance.reset());

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
  }

  group('menu tokens come from the theme', () {
    test('declared numbers and flags are read', () {
      theme.setTheme(<String, dynamic>{
        'component': <String, dynamic>{
          'menu': <String, dynamic>{
            'itemVerticalPadding': 11,
            'menuVerticalPadding': 13,
            'elevation': 7,
            'noAnimation': false,
          },
        },
        'shape': <String, dynamic>{
          'small': <String, dynamic>{'uniform': 9},
        },
      });

      final tokens = MenuTokens.resolve(theme);

      expect(tokens.itemVerticalPadding, 11,
          reason: 'a designer changing the token and seeing nothing move is '
              'the failure this branch prevents');
      expect(tokens.menuVerticalPadding, 13);
      expect(tokens.elevation, 7);
      expect(tokens.noAnimation, isFalse);
      // The corner comes from the shape scale rather than the menu block —
      // two token families, one menu — and falls back through
      // `small` → `extraSmall` → a default rather than answering null.
      expect(tokens.radius, isA<double>());
    });

    test('a theme that declares none falls back rather than blanking', () {
      final tokens = MenuTokens.resolve(theme);

      expect(tokens.itemVerticalPadding, isNotNull);
      expect(tokens.elevation, isNotNull,
          reason: 'a menu with no elevation is a menu that looks pasted onto '
              'the page');
    });

    test('values of the wrong type are ignored, not coerced', () {
      theme.setTheme(<String, dynamic>{
        'component': <String, dynamic>{
          'menu': <String, dynamic>{
            'itemVerticalPadding': 'roomy',
            'noAnimation': 'yes',
          },
        },
      });

      final tokens = MenuTokens.resolve(theme);

      expect(tokens.itemVerticalPadding, isNot('roomy'));
      expect(tokens.noAnimation, isA<bool>(),
          reason: 'a string where a flag belongs is a theme mistake; taking '
              'it as true would make the mistake invisible');
    });
  });

  group('a per-corner shape token', () {
    testWidgets('reaches a widget that reads its shape from the theme',
        (tester) async {
      theme.setTheme(<String, dynamic>{
        'shape': <String, dynamic>{
          // The map form of a shape token: four corners rather than one
          // radius. A widget that reads only the numeric form draws square
          // corners and the theme looks ignored.
          'large': <String, dynamic>{'topStart': 16, 'bottomEnd': 4},
        },
      });

      await pump(tester, <String, dynamic>{
        'type': 'card',
        'shape': 'large',
        'child': <String, dynamic>{'type': 'text', 'content': 'carded'},
      });

      expect(find.text('carded'), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: 'the per-corner form is what §5.4 allows; reading it as a '
              'number would throw out of the build');
    });
  });

  group('an inset that arrives through a binding', () {
    testWidgets('a map from state is read like a literal one', (tester) async {
      // State holds `Map<dynamic, dynamic>`, not `Map<String, dynamic>` — a
      // check for the typed form alone dropped the bound spelling while the
      // literal worked, which reads as "bindings do not work here".
      stateManager.set('pad', <dynamic, dynamic>{'all': 24});

      await pump(tester, <String, dynamic>{
        'type': 'box',
        'padding': '{{pad}}',
        'child': <String, dynamic>{'type': 'text', 'content': 'padded'},
      });

      final padded = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.padding == const EdgeInsets.all(24));

      expect(padded, isNotEmpty,
          reason: 'the bound inset has to land as the same EdgeInsets the '
              'literal produces');
    });
  });
}
