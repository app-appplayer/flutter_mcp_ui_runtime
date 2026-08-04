// The list functions and the `runtime.*` / `sync.*` binding families were the
// largest uncovered blocks left in `binding_engine.dart`. They are what a
// document uses to derive one list from another and to ask what it is running
// on — both fail quietly, as a wrong list or a null.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart' as core;
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';

void main() {
  late StateManager state;
  late BindingEngine binding;
  late RenderContext context;

  setUp(() {
    state = StateManager();
    state.initialize(<String, dynamic>{
      'nums': <dynamic>[1, 2, 3, 4],
      'rows': <dynamic>[
        <String, dynamic>{'name': 'a', 'qty': 2, 'kind': 'fruit'},
        <String, dynamic>{'name': 'b', 'qty': 5, 'kind': 'veg'},
        <String, dynamic>{'name': 'c', 'qty': 9, 'kind': 'fruit'},
      ],
    });
    binding = BindingEngine();
    context = RenderContext(
      renderer: Renderer(
        widgetRegistry: WidgetRegistry(),
        bindingEngine: binding,
        actionHandler: ActionHandler(),
        stateManager: state,
      ),
      stateManager: state,
      bindingEngine: binding,
      actionHandler: ActionHandler(),
      themeManager: ThemeManager.instance,
    );
  });

  dynamic resolve(String expr) => binding.resolve<dynamic>(expr, context);

  group('list functions', () {
    test('map with a lambda derives a new list', () {
      expect(resolve('{{map(nums, n => n * 2)}}'), <dynamic>[2, 4, 6, 8]);
    });

    test('filter with a lambda keeps what matches', () {
      expect(resolve('{{filter(nums, n => n > 2)}}'), <dynamic>[3, 4]);
    });

    test('filter by property and value keeps matching rows', () {
      final result = resolve('{{filter(rows, "kind", "fruit")}}') as List;
      expect(result.map((e) => e['name']), <String>['a', 'c']);
    });

    test('reduce sums what the lambda returns', () {
      expect(resolve('{{reduce(nums, n => n, 0)}}'), 10);
    });

    test('a filter that matches nothing is an empty list, not the input', () {
      expect(resolve('{{filter(nums, n => n > 99)}}'), isEmpty,
          reason: 'returning the input unchanged is how an unevaluated step '
              'looks, and the two must not be confusable');
    });

    test('a non-list argument does not throw', () {
      expect(() => resolve('{{map("text", n => n)}}'), returnsNormally);
    });
  });

  group('runtime.* bindings', () {
    test('version reports the DSL version core declares', () {
      expect(resolve('{{runtime.version}}'), core.MCPUIDSLVersion.current,
          reason: 'this answered a hardcoded 1.1 — two cuts stale, and a '
              'number nothing else in the system used');
    });

    test('platform, locale and debug resolve to something', () {
      expect(resolve('{{runtime.platform}}'), isNotNull);
      expect(resolve('{{runtime.locale}}'), isNotNull);
      expect(resolve('{{runtime.debug}}'), isNotNull);
    });

    test('an unknown runtime path is null, not an error', () {
      expect(resolve('{{runtime.nonsense}}'), isNull);
    });
  });

  group('sync.* bindings without a sync manager', () {
    test('resolve to null rather than throwing', () {
      for (final path in const [
        'status',
        'pending',
        'pendingCount',
        'lastError',
        'lastSyncAt',
        'syncedCount',
        'failedCount',
        'nonsense',
      ]) {
        expect(resolve('{{sync.$path}}'), isNull, reason: path);
      }
    });
  });
}
