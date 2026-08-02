/// Test-suite configuration.
///
/// Filters one environment failure that has nothing to do with this app:
/// Material 3 draws its ink splash with `shaders/ink_sparkle.frag`, and
/// `FragmentProgram.fromAsset` rejects the bundled shader when it targets a
/// different engine runtime-stages version than the one running the tests
/// ("Unsupported runtime stages format version. Expected 2, got 1.").
///
/// It fires on the first tap of every widget test, throws inside `pump()` so
/// `takeException` cannot reach it, and there is no seam to swap the splash
/// factory — `MCPUIRuntime.buildUI()` owns the ThemeData. Skipping each
/// affected case would mean skipping every test that touches the UI.
///
/// Only this exact asset is filtered; everything else reaches the framework
/// unchanged, so a real rendering error still fails the suite.
library flutter_test_config;

import 'dart:async';

import 'package:flutter/foundation.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception.toString().contains('ink_sparkle.frag')) return;
    previous?.call(details);
  };
  await testMain();
}
