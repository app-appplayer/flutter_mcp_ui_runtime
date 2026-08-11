// `GlobalErrorHandler`, which had no test at all.
//
// The widget-level strategies (`ErrorBoundary`, `ErrorRecovery`) live in
// `error_boundary_widget_test.dart` beside this file. They were left out here
// once, with a note about build storms and undrained exceptions; the harness
// that solves both — bounded pumps with `takeException` after each frame — is
// in that file, and it found six defects in the widgets it finally exercised.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/core/error_boundary.dart';
import 'package:flutter_test/flutter_test.dart';

/// Throws on its first build, then renders. That is the shape of a document
/// that fails once and works on retry.
class _FailsOnce extends StatefulWidget {
  const _FailsOnce({required this.attempts});

  final List<int> attempts;

  @override
  State<_FailsOnce> createState() => _FailsOnceState();
}

class _FailsOnceState extends State<_FailsOnce> {
  @override
  Widget build(BuildContext context) {
    widget.attempts.add(widget.attempts.length);
    if (widget.attempts.length == 1) {
      throw StateError('first build fails');
    }
    return const Text('recovered');
  }
}

void main() {
  group('GlobalErrorHandler', () {
    test('registered handlers hear an error, unregistered ones do not', () {
      final heard = <Object>[];
      void handler(Object error, StackTrace? stack) => heard.add(error);

      final previousFlutterOnError = FlutterError.onError;
      addTearDown(() => FlutterError.onError = previousFlutterOnError);

      GlobalErrorHandler.registerHandler(handler);
      GlobalErrorHandler.initialize();

      FlutterError.onError!(FlutterErrorDetails(
        exception: StateError('from the framework'),
        library: 'test',
      ));
      expect(heard, hasLength(1));

      GlobalErrorHandler.unregisterHandler(handler);
      FlutterError.onError!(FlutterErrorDetails(
        exception: StateError('after unregister'),
        library: 'test',
      ));
      expect(heard, hasLength(1),
          reason: 'unregister has to actually detach the handler');
    });

    test('an async error is reported and marked handled', () {
      final heard = <Object>[];
      void handler(Object error, StackTrace? stack) => heard.add(error);

      final previousFlutterOnError = FlutterError.onError;
      final previousPlatformOnError = PlatformDispatcher.instance.onError;
      addTearDown(() {
        FlutterError.onError = previousFlutterOnError;
        PlatformDispatcher.instance.onError = previousPlatformOnError;
      });

      GlobalErrorHandler.registerHandler(handler);
      addTearDown(() => GlobalErrorHandler.unregisterHandler(handler));
      GlobalErrorHandler.initialize();

      final handled = PlatformDispatcher.instance
          .onError!(StateError('async'), StackTrace.current);

      expect(heard, hasLength(1));
      expect(handled, isTrue,
          reason: 'returning false would let the error reach the zone and '
              'take the app down, which is the opposite of a boundary');
    });
  });
}
