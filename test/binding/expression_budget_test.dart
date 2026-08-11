// The sandbox's time budget, measured on the aggregate operations that can
// actually run long.
//
// `sandbox.timeout` is documented as the ceiling for a single expression, and
// the aggregates check it every hundred items — but nothing had ever crossed
// it, so the only evidence that the budget did anything was the code being
// there. A budget that is never enforced is the same as no budget: a document
// binding a total over a large collection blocks the frame for as long as the
// collection takes, and the screen it belongs to simply stops.
//
// Every test here is a pair: the same expression over the same list, once
// with room to finish and once with the budget already spent. The pair is the
// point — a partial answer alone could just as well be a broken `reduce`.

import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StateManager stateManager;
  late BindingEngine bindingEngine;
  late RenderContext context;

  setUp(() {
    stateManager = StateManager()..initialize(<String, dynamic>{});
    bindingEngine = BindingEngine();
    final actionHandler = ActionHandler();
    context = RenderContext(
      renderer: Renderer(
        widgetRegistry: WidgetRegistry(),
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

  void budget({required int ms, required int items}) {
    bindingEngine.sandbox =
        ExpressionSandbox(timeout: ms, maxIterations: items);
  }

  test('summing numbers: the whole list with room, less without', () {
    const rowCount = 200000;
    stateManager.set(
        'values', List<int>.generate(rowCount, (i) => 1, growable: false));

    budget(ms: 10000, items: rowCount);
    expect(bindingEngine.resolve<dynamic>('{{values.reduce()}}', context),
        rowCount,
        reason: 'with room to finish the sum is the sum — otherwise the '
            'measurement below is about a broken reduce, not about a budget');

    budget(ms: 0, items: rowCount);
    final capped = bindingEngine.resolve<dynamic>('{{values.reduce()}}', context)
        as num;
    expect(capped, lessThan(rowCount),
        reason: 'a spent budget has to end the loop; running the list anyway '
            'is the frame the ceiling exists to protect');
  });

  test('summing a property: the whole list with room, less without', () {
    const rowCount = 100000;
    stateManager.set(
        'rows',
        List<Map<String, dynamic>>.generate(
            rowCount, (i) => <String, dynamic>{'v': 1},
            growable: false));

    budget(ms: 10000, items: rowCount);
    expect(
        bindingEngine.resolve<dynamic>('{{rows.reduce("v")}}', context), rowCount);

    budget(ms: 0, items: rowCount);
    final capped =
        bindingEngine.resolve<dynamic>('{{rows.reduce("v")}}', context) as num;
    expect(capped, lessThan(rowCount));
  });

  test('an accumulator lambda: the whole list with room, less without', () {
    // This pair is what found the state-logging cost: 5,000 rows did not
    // finish inside a TEN SECOND budget (3,974 of 5,000), because every read
    // the lambda made stringified the whole state map. With that gone the
    // same 5,000 rows take about 30ms and the cost is linear again. The list
    // stays small here because this test is about the ceiling, not the speed.
    const rowCount = 200;
    stateManager.set(
        'rows',
        List<Map<String, dynamic>>.generate(
            rowCount, (i) => <String, dynamic>{'v': 1},
            growable: false));

    budget(ms: 10000, items: rowCount);
    expect(
        bindingEngine.resolve<dynamic>(
            '{{rows.reduce((acc, item) => acc + item.v, 0)}}', context),
        rowCount,
        reason: 'the form §3.6.3 writes, accumulating over every item');

    budget(ms: 1, items: rowCount);
    final capped = bindingEngine.resolve<dynamic>(
        '{{rows.reduce((acc, item) => acc + item.v, 0)}}', context);
    expect(capped is num ? capped : 0, lessThan(rowCount),
        reason: 'each item costs an expression evaluation, so this is the '
            'shape most likely to hold a frame');
  });
}
