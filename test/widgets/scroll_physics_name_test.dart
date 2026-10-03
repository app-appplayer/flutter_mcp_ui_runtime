// `physics` is the one name for scroll response (§17.3.2 registers
// `scrollPhysics` as the legacy name on `scrollView` / `pageView`; §17.3.1a
// registers `neverScrollable` / `alwaysScrollable`, and `tabBarView`'s
// `bounce` / `clamp`, as legacy values).
//
// Before: `scrollView` read `scrollPhysics ?? physics`, `pageView` read only
// `scrollPhysics` and only `neverScrollable`, `tabBarView` read `bounce` /
// `clamp`, and six factories read the raw property, so a bound value was
// ignored everywhere but `scrollView`.

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
    stateManager = StateManager()..initialize(<String, dynamic>{'p': 'never'});
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

  /// The physics every scrollable in the drawn tree was given.
  Future<List<Type>> physicsOf(
      WidgetTester tester, Map<String, dynamic> definition) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 400,
          child: context.renderer.renderWidget(definition, context),
        ),
      ),
    ));
    await tester.pump();
    // `PageView` and `TabBarView` wrap the given physics in their own, so
    // the whole parent chain is collected.
    final types = <Type>[];
    for (final s in tester.widgetList<Scrollable>(find.byType(Scrollable))) {
      for (ScrollPhysics? p = s.physics; p != null; p = p.parent) {
        types.add(p.runtimeType);
      }
    }
    return types;
  }

  const children = [
    {'type': 'text', 'content': 'a'},
    {'type': 'text', 'content': 'b'},
  ];

  final cases = <String, Map<String, dynamic>>{
    'list': {'type': 'list', 'children': children},
    'grid': {'type': 'grid', 'columns': 2, 'children': children},
    'singleChildScrollView': {
      'type': 'singleChildScrollView',
      'child': {'type': 'text', 'content': 'a'},
    },
    'scrollView': {'type': 'scrollView', 'children': children},
    'pageView': {'type': 'pageView', 'children': children},
    'stepper': {
      'type': 'stepper',
      'steps': [
        {'title': 'one', 'content': {'type': 'text', 'content': 'a'}},
      ],
    },
  };

  for (final entry in cases.entries) {
    testWidgets('${entry.key} reads `physics: never`', (tester) async {
      final types =
          await physicsOf(tester, {...entry.value, 'physics': 'never'});
      expect(types, contains(NeverScrollableScrollPhysics));
    });
  }

  for (final type in ['scrollView', 'pageView']) {
    testWidgets('$type still reads the legacy `scrollPhysics: neverScrollable`',
        (tester) async {
      final types = await physicsOf(
          tester, {...cases[type]!, 'scrollPhysics': 'neverScrollable'});
      expect(types, contains(NeverScrollableScrollPhysics));
    });

    testWidgets('$type: the canonical name wins over the legacy one',
        (tester) async {
      final types = await physicsOf(tester, {
        ...cases[type]!,
        'physics': 'bouncing',
        'scrollPhysics': 'neverScrollable',
      });
      expect(types, contains(BouncingScrollPhysics));
      expect(types, isNot(contains(NeverScrollableScrollPhysics)));
    });
  }

  testWidgets('a bound value resolves', (tester) async {
    final types =
        await physicsOf(tester, {...cases['list']!, 'physics': '{{p}}'});
    expect(types, contains(NeverScrollableScrollPhysics));
  });

  testWidgets('tabBarView keeps its legacy `clamp`', (tester) async {
    final types = await physicsOf(tester, {
      'type': 'tabBarView',
      'physics': 'clamp',
      'children': children,
    });
    expect(types, contains(ClampingScrollPhysics));
  });
}
