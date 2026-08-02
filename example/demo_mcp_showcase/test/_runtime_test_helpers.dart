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
/// Absorbs the Material 3 ink-sparkle shader failure.
///
/// `FragmentProgram.fromAsset('shaders/ink_sparkle.frag')` throws under
/// `flutter_test` when the bundled shader was compiled for a different engine
/// runtime-stages version. It fires on the first real gesture that produces a
/// splash, so any test that scrolls or taps hits it — and it says nothing
/// about the widget under test. Anything else is rethrown.
void absorbInkSparkleFailure(WidgetTester tester) {
  final error = tester.takeException();
  if (error == null) return;
  if (error.toString().contains('ink_sparkle.frag')) return;
  throw error;
}

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
