// `headerBar` — the host close button (§2.8.1 / §4.3.2) and the slots a
// document fills around the title.
//
// The close button is the one control the runtime adds on the host's behalf,
// so both halves matter: it must appear when the host registered somewhere to
// go, and it must be suppressible by a document that draws its own.

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
    NavigationActionExecutor.clearOnExitCallback();
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

  tearDown(NavigationActionExecutor.clearOnExitCallback);

  /// Mounts the bar as a scaffold's app bar, which is where one lives.
  Future<void> pump(WidgetTester tester, Map<String, dynamic> definition) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(96),
            child: context.renderer.renderWidget(definition, context),
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('the host close button', () {
    testWidgets('is added on the root route when the host can be exited',
        (tester) async {
      var exited = 0;
      NavigationActionExecutor.setOnExitCallback(() => exited++);

      await pump(tester, <String, dynamic>{
        'type': 'headerBar',
        'title': 'Jobs',
      });

      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(exited, 1);
    });

    testWidgets('a document may suppress it', (tester) async {
      NavigationActionExecutor.setOnExitCallback(() {});

      await pump(tester, <String, dynamic>{
        'type': 'headerBar',
        'title': 'Jobs',
        'exitButton': false,
      });

      expect(find.byIcon(Icons.close), findsNothing,
          reason: 'a document that draws its own close control would '
              'otherwise show two');
    });

    testWidgets('a document may restyle it', (tester) async {
      NavigationActionExecutor.setOnExitCallback(() {});

      await pump(tester, <String, dynamic>{
        'type': 'headerBar',
        'title': 'Jobs',
        'exitButton': <String, dynamic>{
          'icon': 'logout',
          'tooltip': 'Leave',
          'color': '#FF0000',
        },
      });

      expect(find.byIcon(Icons.logout), findsOneWidget);
      expect(
          tester.widget<IconButton>(find.byType(IconButton).last).tooltip,
          'Leave');
      expect(
          tester.widget<Icon>(find.byIcon(Icons.logout)).color,
          const Color(0xFFFF0000));
    });

    testWidgets('every declared exit icon name resolves', (tester) async {
      NavigationActionExecutor.setOnExitCallback(() {});

      const icons = <String, IconData>{
        'close': Icons.close,
        'exit_to_app': Icons.exit_to_app,
        'logout': Icons.logout,
        'arrow_back': Icons.arrow_back,
        'nonsense': Icons.close,
      };

      for (final entry in icons.entries) {
        await pump(tester, <String, dynamic>{
          'type': 'headerBar',
          'title': 'Jobs',
          'exitButton': <String, dynamic>{'icon': entry.key},
        });
        expect(find.byIcon(entry.value), findsOneWidget, reason: entry.key);
      }
    });

    testWidgets('with no host exit there is no button', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'headerBar',
        'title': 'Jobs',
      });

      expect(find.byIcon(Icons.close), findsNothing);
    });
  });

  group('the slots', () {
    testWidgets('a bottom widget is given a preferred size', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'headerBar',
        'title': 'Jobs',
        'bottomHeight': 40,
        'bottom': <String, dynamic>{'type': 'text', 'content': 'sub'},
      });

      expect(find.text('sub'), findsOneWidget,
          reason: 'a tab strip under the title is what this slot is for; '
              'without a preferred size the Scaffold cannot place it');
      final bottom = tester.widget<PreferredSize>(
          find.byType(PreferredSize).last);
      expect(bottom.preferredSize.height, 40);
    });

    testWidgets('a flexible space is built behind the title', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'headerBar',
        'title': 'Jobs',
        'flexibleSpace': <String, dynamic>{
          'type': 'container',
          'color': '#FF0000',
        },
      });

      expect(tester.widget<AppBar>(find.byType(AppBar)).flexibleSpace,
          isNotNull);
    });

    testWidgets('a shape rounds only the bottom corners', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'headerBar',
        'title': 'Jobs',
        'shape': <String, dynamic>{'type': 'rounded', 'radius': 16},
      });

      final shape = tester.widget<AppBar>(find.byType(AppBar)).shape!
          as RoundedRectangleBorder;
      expect(shape.borderRadius,
          const BorderRadius.vertical(bottom: Radius.circular(16)),
          reason: 'a bar sits against the top edge; rounding the top corners '
              'leaves two gaps against the status bar');
    });
  });
}
