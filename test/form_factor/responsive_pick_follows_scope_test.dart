// Which variant of a `{compact: …, expanded: …}` value a document gets.
//
// The widgets decide their layout through `FormFactor.of(context)`, which
// honours a `FormFactorScope` — that scope is how a host pins a view mode and
// how a derivative player flags `embedded`. The value picker read
// `MediaQuery` directly instead, so the two disagreed: a pinned window laid
// out one way and read its numbers for another, and `embedded` could not be
// picked at all because width alone never says it.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/form_factor/form_factor.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StateManager stateManager;
  late Renderer renderer;
  late BindingEngine bindingEngine;
  late ActionHandler actionHandler;

  setUp(() {
    stateManager = StateManager()..initialize(<String, dynamic>{});
    final registry = WidgetRegistry();
    DefaultWidgets.registerAll(registry);
    bindingEngine = BindingEngine();
    actionHandler = ActionHandler();
    renderer = Renderer(
      widgetRegistry: registry,
      bindingEngine: bindingEngine,
      actionHandler: actionHandler,
      stateManager: stateManager,
    );
  });

  /// Picks [value] inside a tree of the given [width], optionally pinned.
  Future<dynamic> pick(
    WidgetTester tester,
    Map<String, dynamic> value, {
    required double width,
    FormFactor? pinned,
  }) async {
    dynamic picked;
    Widget probe = Builder(builder: (context) {
      picked = RenderContext(
        renderer: renderer,
        stateManager: stateManager,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        themeManager: ThemeManager.instance,
        buildContext: context,
      ).pickResponsive(value);
      return const SizedBox();
    });

    if (pinned != null) {
      probe = FormFactorScope(formFactor: pinned, child: probe);
    }

    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData(size: Size(width, 800)),
      child: Directionality(textDirection: TextDirection.ltr, child: probe),
    ));
    return picked;
  }

  const value = <String, dynamic>{
    'compact': 8,
    'expanded': 24,
    'embedded': 40,
    'default': 0,
  };

  testWidgets('with no pin, the window width decides', (tester) async {
    expect(await pick(tester, value, width: 400), 8);
    expect(await pick(tester, value, width: 1000), 24);
  });

  testWidgets('a pinned view mode decides instead of the width',
      (tester) async {
    expect(
        await pick(tester, value,
            width: 400, pinned: FormFactor.expanded),
        24,
        reason: 'the widgets lay out as expanded under this pin; reading the '
            'numbers for compact leaves a wide layout with phone spacing');

    expect(
        await pick(tester, value,
            width: 1400, pinned: FormFactor.compact),
        8);
  });

  testWidgets('embedded is pickable at all, and falls back in order',
      (tester) async {
    expect(
        await pick(tester, value, width: 400, pinned: FormFactor.embedded),
        40,
        reason: 'width never says embedded — only a host tag does, and the '
            'branch for it could not run before');

    expect(
        await pick(tester, const <String, dynamic>{'compact': 8, 'default': 0},
            width: 400, pinned: FormFactor.embedded),
        8,
        reason: 'an embedded surface is a small one, so compact is the next '
            'best answer');

    expect(
        await pick(tester, const <String, dynamic>{'default': 0},
            width: 400, pinned: FormFactor.embedded),
        isNull,
        reason: 'a map with no form-factor key at all is not a responsive map '
            '— `default` alone is an ordinary field name, and picking it '
            'would rewrite documents that happen to use the word');

    expect(
        await pick(tester, const <String, dynamic>{'large': 32},
            width: 400, pinned: FormFactor.embedded),
        isNull,
        reason: 'nothing that applies, and no default — the caller keeps its '
            'own value rather than being handed a desktop number');
  });
}
