/// Regression for the ThemeManager → RuntimeEngine listener wiring
/// (`runtime_engine.dart` `initialize()` forwards `_themeManager`
/// mutations to engine listeners; `destroy()` detaches cleanly).
///
/// Spec `mcp_ui_dsl/spec/1.3/05_Theme.md` §L56 mandates re-render on
/// theme change — the engine is the spec's contribution to the chain
/// (host → ThemeManager mutator → engine.notifyListeners →
/// MCPRuntimeWidget AnimatedBuilder → MaterialApp rebuild).
library;

import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart' show ThemeDefinition;
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ThemeManager is process-singleton; reset between tests so a
  // sibling test (theme_fingerprint_cache_test) cannot leave state
  // that makes our setThemeDefinition call a no-op reference swap.
  setUp(() => ThemeManager.instance.reset());
  tearDown(() => ThemeManager.instance.reset());

  group('ThemeManager → RuntimeEngine forward', () {
    test('setThemeDefinition fires engine listeners', () async {
      final runtime = MCPUIRuntime();
      await runtime.initialize(
        const <String, dynamic>{
          'type': 'page',
          'content': {'type': 'text', 'value': 'hi'},
        },
        validateSchema: false,
      );

      var fired = 0;
      void onChange() => fired++;
      runtime.engine.addListener(onChange);

      runtime.engine.themeManager
          .setThemeDefinition(ThemeDefinition.defaultDark());

      // The forward is synchronous (ChangeNotifier.notifyListeners
      // dispatches in-line), so the listener has already run.
      expect(fired, greaterThanOrEqualTo(1));

      runtime.engine.removeListener(onChange);
      await runtime.destroy();
    });

    test('destroy detaches the listener cleanly', () async {
      final runtime = MCPUIRuntime();
      await runtime.initialize(
        const <String, dynamic>{
          'type': 'page',
          'content': {'type': 'text', 'value': 'hi'},
        },
        validateSchema: false,
      );

      final tm = runtime.engine.themeManager;
      await runtime.destroy();

      // After destroy, mutating the (process-singleton) ThemeManager
      // must not throw or notify a disposed engine.
      expect(
        () => tm.setThemeDefinition(ThemeDefinition.defaultLight()),
        returnsNormally,
      );
    });

    test('setThemeMode also forwards (host brightness toggle path)',
        () async {
      final runtime = MCPUIRuntime();
      await runtime.initialize(
        const <String, dynamic>{
          'type': 'page',
          'content': {'type': 'text', 'value': 'hi'},
        },
        validateSchema: false,
      );

      final notified = <int>[];
      runtime.engine
          .addListener(() => notified.add(DateTime.now().microsecondsSinceEpoch));

      runtime.engine.themeManager.setThemeMode('dark');

      expect(notified.length, greaterThanOrEqualTo(1));
      await runtime.destroy();
    });
  });
}
