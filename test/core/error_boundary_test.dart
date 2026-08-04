// `error_boundary.dart` had 0 of 177 lines covered — the widget whose whole
// job is to be there when something else fails.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/core/error_boundary.dart';

void main() {
  group('ErrorBoundary', () {
    testWidgets('passes the child through while nothing is wrong',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: ErrorBoundary(
          catchAsync: false,
          child: Text('content'),
        ),
      ));
      expect(find.text('content'), findsOneWidget);
    });

    testWidgets('an async error reaches onError and replaces the child',
        (tester) async {
      Object? seen;
      final previous = FlutterError.onError;
      addTearDown(() => FlutterError.onError = previous);

      await tester.pumpWidget(MaterialApp(
        home: ErrorBoundary(
          showErrorInDebug: false, // do not re-present into the test harness
          onError: (error, stack) => seen = error,
          child: const Text('content'),
        ),
      ));

      FlutterError.onError!(FlutterErrorDetails(
        exception: StateError('boom'),
        library: 'test',
      ));
      await tester.pump();

      expect(seen, isA<StateError>());
      expect(find.text('content'), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsOneWidget,
          reason: 'the default surface names the failure instead of leaving a '
              'blank screen');
    });

    testWidgets('errorBuilder replaces the default surface', (tester) async {
      final previous = FlutterError.onError;
      addTearDown(() => FlutterError.onError = previous);

      await tester.pumpWidget(MaterialApp(
        home: ErrorBoundary(
          showErrorInDebug: false,
          errorBuilder: (error, stack) => Text('caught: $error'),
          child: const Text('content'),
        ),
      ));

      FlutterError.onError!(FlutterErrorDetails(
        exception: StateError('specific'),
        library: 'test',
      ));
      await tester.pump();

      expect(find.textContaining('specific'), findsOneWidget);
    });

    testWidgets('catchAsync: false leaves the global handler alone',
        (tester) async {
      final previous = FlutterError.onError;
      await tester.pumpWidget(const MaterialApp(
        home: ErrorBoundary(catchAsync: false, child: Text('content')),
      ));
      expect(identical(FlutterError.onError, previous), isTrue);
    });

    testWidgets('the global handler is restored when the boundary goes away',
        (tester) async {
      final previous = FlutterError.onError;
      addTearDown(() => FlutterError.onError = previous);

      await tester.pumpWidget(const MaterialApp(
        home: ErrorBoundary(showErrorInDebug: false, child: Text('content')),
      ));
      expect(identical(FlutterError.onError, previous), isFalse,
          reason: 'while mounted it is the boundary that hears errors');

      await tester.pumpWidget(const MaterialApp(home: Text('other')));

      expect(identical(FlutterError.onError, previous), isTrue,
          reason: 'a disposed boundary that keeps the global handler swallows '
              'every framework error after it: the closure survives, its state '
              'is unmounted, and setState is skipped — so nothing is shown and '
              'nothing is reported anywhere else either');
    });
  });

  group('ErrorRecovery', () {
    testWidgets('ignore keeps the child on screen', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: ErrorRecovery(
          strategy: ErrorRecoveryStrategy.ignore,
          child: Text('content'),
        ),
      ));
      expect(find.text('content'), findsOneWidget);
    });

    testWidgets('every strategy is constructible with its own defaults',
        (tester) async {
      for (final strategy in ErrorRecoveryStrategy.values) {
        await tester.pumpWidget(MaterialApp(
          home: ErrorRecovery(
            strategy: strategy,
            errorRoute: '/error',
            maxRetries: 1,
            retryDelay: Duration.zero,
            child: Text('content-${strategy.name}'),
          ),
        ));
        await tester.pump();
        expect(find.text('content-${strategy.name}'), findsOneWidget,
            reason: '${strategy.name} must render its child until something '
                'actually fails');
      }
    });
  });
}
