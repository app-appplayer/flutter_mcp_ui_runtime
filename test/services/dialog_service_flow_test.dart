// `dialog_service.dart` sat at 35% — the file next to this one builds its
// pieces and asserts on their shape; nothing had ever shown a dialog and
// pressed a button. Each helper here ends in a value the caller acts on: a
// confirm that answers the wrong way, or an input that returns the hint
// instead of what was typed, is a decision made on the user's behalf.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/services/dialog_service.dart';

void main() {
  late DialogService service;

  Future<void> mount(WidgetTester tester) async {
    service = DialogService();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: DialogService.navigatorKey,
      home: const Scaffold(body: Center(child: Text('page'))),
    ));
  }

  group('showConfirm', () {
    testWidgets('returns true when the user confirms', (tester) async {
      await mount(tester);
      bool? answer;
      // ignore: unawaited_futures
      service
          .showConfirm(message: 'Discard?', title: 'Draft')
          .then((v) => answer = v);
      await tester.pumpAndSettle();

      expect(find.text('Discard?'), findsOneWidget);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(answer, isTrue);
    });

    testWidgets('returns false when the user cancels', (tester) async {
      await mount(tester);
      bool? answer;
      // ignore: unawaited_futures
      service.showConfirm(message: 'Discard?').then((v) => answer = v);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(answer, isFalse);
    });

    testWidgets('a barrier dismissal counts as "no"', (tester) async {
      await mount(tester);
      bool? answer;
      // ignore: unawaited_futures
      service.showConfirm(message: 'Discard?').then((v) => answer = v);
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(answer, isFalse,
          reason: 'a dismissed confirm must not read as confirmation — null '
              'collapsing to true is how a tap outside deletes something');
    });

    testWidgets('custom button labels are used', (tester) async {
      await mount(tester);
      // ignore: unawaited_futures
      service.showConfirm(
        message: 'Ship it?',
        confirmText: 'Ship',
        cancelText: 'Hold',
      );
      await tester.pumpAndSettle();

      expect(find.text('Ship'), findsOneWidget);
      expect(find.text('Hold'), findsOneWidget);

      await tester.tap(find.text('Hold'));
      await tester.pumpAndSettle();
    });
  });

  group('showInput', () {
    testWidgets('returns what was typed', (tester) async {
      await mount(tester);
      String? typed;
      // ignore: unawaited_futures
      service.showInput(title: 'Name', hint: 'your name').then((v) => typed = v);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'cherry');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(typed, 'cherry');
    });

    testWidgets('an initial value is pre-filled and returned unchanged',
        (tester) async {
      await mount(tester);
      String? typed;
      // ignore: unawaited_futures
      service.showInput(initialValue: 'draft').then((v) => typed = v);
      await tester.pumpAndSettle();

      expect(find.text('draft'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(typed, 'draft');
    });

    testWidgets('cancelling returns null, not the empty string',
        (tester) async {
      await mount(tester);
      String? typed = 'sentinel';
      // ignore: unawaited_futures
      service.showInput(title: 'Name').then((v) => typed = v);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(typed, isNull,
          reason: 'an empty string is a value the user typed; null is the '
              'absence of an answer, and callers branch on the difference');
    });
  });

  group('showAlert', () {
    testWidgets('shows the message and completes on the confirm button',
        (tester) async {
      await mount(tester);
      var done = false;
      // ignore: unawaited_futures
      service.showAlert(message: 'Saved', title: 'Done').then((_) => done = true);
      await tester.pumpAndSettle();

      expect(find.text('Saved'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(done, isTrue);
    });
  });

  group('one at a time', () {
    testWidgets('a second dialog is refused while one is up', (tester) async {
      await mount(tester);
      // ignore: unawaited_futures
      service.showAlert(message: 'first');
      await tester.pumpAndSettle();

      Object? second = 'not answered';
      // ignore: unawaited_futures
      service.showConfirm(message: 'second').then((v) => second = v);
      await tester.pumpAndSettle();

      expect(find.text('first'), findsOneWidget);
      expect(find.text('second'), findsNothing);
      expect(second, isFalse,
          reason: 'the refused confirm resolves to its "no" default rather '
              'than leaving the caller waiting on a dialog that never opened');

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    });
  });

  group('snackbar and overlays', () {
    testWidgets('a snackbar appears without a dialog', (tester) async {
      await mount(tester);
      service.showSnackbar(message: 'copied');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('copied'), findsOneWidget);
    });

    testWidgets('overlays can be added and removed', (tester) async {
      await mount(tester);
      service.showOverlay(builder: (_) => const Text('badge'));
      await tester.pump();
      expect(find.text('badge'), findsOneWidget);

      service.removeOverlay();
      await tester.pump();
      expect(find.text('badge'), findsNothing);
    });

    testWidgets('removeAllOverlays clears every one', (tester) async {
      await mount(tester);
      service.showOverlay(builder: (_) => const Text('a'));
      service.showOverlay(builder: (_) => const Text('b'));
      await tester.pump();

      service.removeAllOverlays();
      await tester.pump();

      expect(find.text('a'), findsNothing);
      expect(find.text('b'), findsNothing);
    });
  });
}
