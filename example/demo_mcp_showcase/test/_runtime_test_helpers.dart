import 'package:flutter/material.dart';
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
/// Widens the test surface so the whole shell fits without scrolling.
///
/// The drawer holds nine entries and the default 800x600 cuts off the last
/// few. Scrolling to reach them fires Material 3's ink-sparkle shader, which
/// fails to load under `flutter_test` when the bundled shader targets a
/// different engine runtime-stages version — an environment mismatch that
/// says nothing about the widget under test. Removing the gesture is more
/// honest than absorbing the exception.
void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Opens the drawer and taps a navigation entry by its label.
///
/// Targets the entry *inside the drawer*: several of these strings also
/// appear in page content, so a bare `find.text` can pick the body copy. The
/// shell state is re-read on every call because navigating rebuilds it.
Future<void> navigateTo(WidgetTester tester, String entry) async {
  tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
  await settleRuntime(tester);
  await tester.tap(
    find
        .descendant(of: find.byType(Drawer), matching: find.text(entry))
        .last,
  );
  await tester.pump();
  absorbInkSparkleFailure(tester);
  await settleRuntime(tester);
  absorbInkSparkleFailure(tester);
  final shell = tester.state<ScaffoldState>(find.byType(Scaffold).first);
  if (shell.isDrawerOpen) {
    shell.closeDrawer();
    await settleRuntime(tester);
  }
}

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
