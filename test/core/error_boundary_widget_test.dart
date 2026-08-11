// `ErrorBoundary` and `ErrorRecovery` — the widgets that decide what a user
// sees when a document blows up mid-build.
//
// The sibling file (`error_recovery_test.dart`) covers `GlobalErrorHandler`
// and says in its header why these two were left out: a child that throws
// during build hands its exception to `flutter_test`, and an undrained
// exception fails the test before its assertions run, while the retry strategy
// schedules further builds that `pumpAndSettle` waits for forever.
//
// The harness is the answer to both. `_settle` pumps a bounded number of
// frames and drains the exception after each one, so the boundary's own
// behaviour — not the test framework's reaction to it — is what gets asserted.
// Nothing here catches an error by accident: every test names the widget that
// threw and the surface that replaced it.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/core/error_boundary.dart';
import 'package:flutter_test/flutter_test.dart';

/// Throws on its first build and renders afterwards — a document that fails
/// once and works on retry.
class _FailsOnce extends StatelessWidget {
  const _FailsOnce({required this.builds});

  final List<int> builds;

  @override
  Widget build(BuildContext context) {
    builds.add(builds.length);
    if (builds.length == 1) throw StateError('first build fails');
    return const Text('recovered');
  }
}

class _AlwaysFails extends StatelessWidget {
  const _AlwaysFails({this.message = 'always fails'});

  final String message;

  @override
  Widget build(BuildContext context) => throw StateError(message);
}

/// Bounded pumps with the exception drained after each frame.
Future<void> _settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 30));
    tester.takeException();
  }
}

void main() {
  group('ErrorBoundary', () {
    testWidgets('a child that throws is replaced by the errorBuilder, and the '
        'error reaches onError', (tester) async {
      final seen = <Object>[];

      await tester.pumpWidget(MaterialApp(
        home: ErrorBoundary(
          onError: (error, stack) => seen.add(error),
          errorBuilder: (error, stack) => Text('caught: $error'),
          child: const _AlwaysFails(message: 'boom'),
        ),
      ));
      await _settle(tester);

      expect(seen, isNotEmpty,
          reason: 'the host has to hear about it — a boundary that swallows '
              'silently leaves nothing in the logs to act on');
      expect(seen.first.toString(), contains('boom'));
      expect(find.textContaining('caught:'), findsOneWidget);
      expect(find.textContaining('boom'), findsOneWidget,
          reason: 'the message belongs on screen; "an error occurred" with no '
              'detail is what makes a bug report unactionable');
    });

    testWidgets('with no errorBuilder it draws its own surface, with the '
        'error text and a way back', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ErrorBoundary(
          child: const _AlwaysFails(message: 'the default surface'),
        ),
      ));
      await _settle(tester);

      expect(find.text('An error occurred'), findsOneWidget);
      expect(find.textContaining('the default surface'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Try Again'), findsOneWidget,
          reason: 'a dead end with no retry is the difference between a '
              'recoverable screen and a closed app');
    });

    testWidgets('Try Again clears the error and rebuilds the child',
        (tester) async {
      final builds = <int>[];

      await tester.pumpWidget(MaterialApp(
        home: ErrorBoundary(child: _FailsOnce(builds: builds)),
      ));
      await _settle(tester);
      expect(find.text('An error occurred'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      await _settle(tester);

      expect(find.text('recovered'), findsOneWidget,
          reason: 'the button has to actually re-run the child — resetting '
              'the flag and showing the same error is worse than no button');
      expect(builds.length, greaterThan(1));
    });

    testWidgets('a child that never throws is left completely alone',
        (tester) async {
      final seen = <Object>[];
      await tester.pumpWidget(MaterialApp(
        home: ErrorBoundary(
          onError: (error, stack) => seen.add(error),
          child: const Text('ordinary content'),
        ),
      ));
      await tester.pump();

      expect(find.text('ordinary content'), findsOneWidget);
      expect(seen, isEmpty);
    });

    testWidgets('the boundary restores the global handlers when it goes away',
        (tester) async {
      // Both `FlutterError.onError` and `ErrorWidget.builder` are global. A
      // boundary that kept them after being disposed would leave the framework
      // reporting into a dead State — every later error would hit the
      // `mounted` guard and vanish, shown nowhere and logged nowhere.
      final beforeOnError = FlutterError.onError;
      final beforeBuilder = ErrorWidget.builder;

      await tester.pumpWidget(MaterialApp(
        home: ErrorBoundary(child: const Text('a')),
      ));
      await tester.pump();
      expect(FlutterError.onError, isNot(same(beforeOnError)),
          reason: 'while mounted it does own the channel');

      await tester.pumpWidget(const MaterialApp(home: Text('boundary gone')));
      await tester.pump();

      expect(FlutterError.onError, same(beforeOnError));
      expect(ErrorWidget.builder, same(beforeBuilder));
    });

    testWidgets('catchAsync: false leaves FlutterError.onError alone',
        (tester) async {
      final before = FlutterError.onError;

      await tester.pumpWidget(MaterialApp(
        home: ErrorBoundary(catchAsync: false, child: const Text('a')),
      ));
      await tester.pump();

      expect(FlutterError.onError, same(before),
          reason: 'a host that handles async errors itself asked this '
              'boundary to stay out of the way');
    });
  });

  group('ErrorRecovery — retry', () {
    testWidgets('a transient failure recovers on its own', (tester) async {
      final builds = <int>[];
      final errors = <Object>[];

      await tester.pumpWidget(MaterialApp(
        home: ErrorRecovery(
          retryDelay: Duration.zero,
          onError: (error, stack) => errors.add(error),
          child: _FailsOnce(builds: builds),
        ),
      ));
      await _settle(tester);

      expect(errors, hasLength(1));
      expect(find.text('recovered'), findsOneWidget,
          reason: 'this is the whole point of the retry strategy: a document '
              'whose data arrived a frame late must not be left as an error '
              'screen the user has to dismiss');
    });

    testWidgets('a permanent failure stops after maxRetries and says how far '
        'it got', (tester) async {
      final errors = <Object>[];

      await tester.pumpWidget(MaterialApp(
        home: ErrorRecovery(
          maxRetries: 2,
          retryDelay: Duration.zero,
          onError: (error, stack) => errors.add(error),
          child: const _AlwaysFails(),
        ),
      ));
      await _settle(tester, frames: 20);

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry attempt 2 of 2'), findsOneWidget,
          reason: 'the count is what tells a user this is not a hiccup');
      expect(errors.length, greaterThanOrEqualTo(1));
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsNothing,
          reason: 'offering a retry button after the retries are exhausted '
              'invites the user to keep pressing something that will not work');
    });

    testWidgets('below the limit the user is offered the retry button',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ErrorRecovery(
          maxRetries: 5,
          retryDelay: const Duration(milliseconds: 500),
          child: const _AlwaysFails(),
        ),
      ));
      // Held before the automatic retry fires, which is when the surface is
      // on screen with attempts still in hand.
      await tester.pump();
      tester.takeException();
      await tester.pump(const Duration(milliseconds: 10));
      tester.takeException();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);

      // Let the scheduled retries run out: a retry timer still pending when
      // the tree is torn down fails the test on an unrelated assertion.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 600));
        tester.takeException();
      }
    });
  });

  group('ErrorRecovery — the other strategies', () {
    testWidgets('reset runs the host callback and starts the count over',
        (tester) async {
      var resets = 0;
      final builds = <int>[];

      await tester.pumpWidget(MaterialApp(
        home: ErrorRecovery(
          strategy: ErrorRecoveryStrategy.reset,
          onReset: () async => resets++,
          child: _FailsOnce(builds: builds),
        ),
      ));
      await _settle(tester);

      expect(resets, 1,
          reason: 'reset is where a host drops its stale state — skipping the '
              'callback and re-rendering would fail exactly the same way');
      expect(find.text('recovered'), findsOneWidget);
    });

    testWidgets('ignore clears the error and carries on', (tester) async {
      final builds = <int>[];

      await tester.pumpWidget(MaterialApp(
        home: ErrorRecovery(
          strategy: ErrorRecoveryStrategy.ignore,
          child: _FailsOnce(builds: builds),
        ),
      ));
      await _settle(tester);

      expect(find.text('recovered'), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing,
          reason: '"ignore" means the user is never shown the failure');
    });

    testWidgets('dialog puts the error in front of the user, and OK dismisses '
        'it', (tester) async {
      final builds = <int>[];

      await tester.pumpWidget(MaterialApp(
        home: ErrorRecovery(
          strategy: ErrorRecoveryStrategy.dialog,
          child: _FailsOnce(builds: builds),
        ),
      ));
      await _settle(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Error'), findsOneWidget);
      expect(find.textContaining('first build fails'), findsOneWidget,
          reason: 'the dialog exists to say what happened; a generic one '
              'could be a static string');

      await tester.tap(find.text('OK'));
      await _settle(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('recovered'), findsOneWidget);
    });

    testWidgets('navigate sends the user to the declared error route',
        (tester) async {
      final builds = <int>[];

      await tester.pumpWidget(MaterialApp(
        routes: {
          '/': (context) => ErrorRecovery(
                strategy: ErrorRecoveryStrategy.navigate,
                errorRoute: '/error',
                child: _FailsOnce(builds: builds),
              ),
          '/error': (context) => const Scaffold(body: Text('error page')),
        },
      ));
      await _settle(tester);

      expect(find.text('error page'), findsOneWidget,
          reason: 'a host that declared a route for failures expects to land '
              'on it, not on the runtime\'s own error surface');
    });

    testWidgets('navigate with no route declared falls back to the surface '
        'rather than doing nothing', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ErrorRecovery(
          strategy: ErrorRecoveryStrategy.navigate,
          child: const _AlwaysFails(),
        ),
      ));
      await _settle(tester);

      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('a custom errorBuilder replaces the default surface',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ErrorRecovery(
          strategy: ErrorRecoveryStrategy.navigate, // no route → shows surface
          errorBuilder: (error, stack) => Text('custom: $error'),
          child: const _AlwaysFails(message: 'shown my way'),
        ),
      ));
      await _settle(tester);

      expect(find.textContaining('custom:'), findsOneWidget);
      expect(find.textContaining('shown my way'), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing);
    });

    testWidgets('a reset button is offered whenever the host supplied onReset',
        (tester) async {
      var resets = 0;

      await tester.pumpWidget(MaterialApp(
        home: ErrorRecovery(
          strategy: ErrorRecoveryStrategy.navigate, // no route → shows surface
          onReset: () async => resets++,
          child: const _AlwaysFails(),
        ),
      ));
      await _settle(tester);

      final resetButton = find.widgetWithText(OutlinedButton, 'Reset');
      expect(resetButton, findsOneWidget);

      await tester.tap(resetButton);
      await _settle(tester);
      expect(resets, 1);
    });
  });
}
