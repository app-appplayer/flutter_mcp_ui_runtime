import 'package:flutter_test/flutter_test.dart';

/// Allows real-time to flow for `MCPUIRuntime.initialize`, whose internal
/// timers (debounce/rate-limiter cleanup, etc.) cannot be advanced by the
/// test's fake async zone. Wrap the initialize call in this helper.
Future<T> initRuntimeWithRealTime<T>(
  WidgetTester tester,
  Future<T> Function() init,
) async {
  T? result;
  await tester.runAsync(() async {
    result = await init();
  });
  return result as T;
}

/// Pump pattern that tolerates runtime-side real-time activity.
/// Call this wherever the test previously used `pumpAndSettle()`.
Future<void> settleRuntime(
  WidgetTester tester, {
  Duration bleedTime = const Duration(milliseconds: 100),
  Duration pumpDuration = const Duration(milliseconds: 100),
  Duration timeout = const Duration(seconds: 5),
}) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(bleedTime);
  });
  await tester.pump();
  await tester.pumpAndSettle(
    pumpDuration,
    EnginePhase.sendSemanticsUpdate,
    timeout,
  );
}
