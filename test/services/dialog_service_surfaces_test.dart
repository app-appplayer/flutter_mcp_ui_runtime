// The `DialogService` surfaces the flow suite next door does not raise: the
// plain `show`, the loading dialog, the bottom sheet, the overlay, and the
// refusals when the navigator is not there.
//
// Each one ends in something the caller acts on. `show` answering null for
// both "refused" and "dismissed" is exactly why `isShowing` exists, and a
// loading dialog that cannot be hidden leaves the app behind a barrier.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/services/dialog_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DialogService service;

  Future<void> mount(WidgetTester tester) async {
    service = DialogService();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: DialogService.navigatorKey,
      home: const Scaffold(body: Center(child: Text('page'))),
    ));
    await tester.pumpAndSettle();
  }

  group('show', () {
    testWidgets('bare content is given a surface rather than the whole overlay',
        (tester) async {
      await mount(tester);

      // ignore: unawaited_futures
      service.show<void>(content: const Text('just content'));
      await tester.pumpAndSettle();

      expect(find.text('just content'), findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget,
          reason: 'without a bounding surface the content fills the overlay '
              'and the barrier tap has nothing to dismiss');
      expect(service.isShowing, isTrue);
    });

    testWidgets('a title or actions promote it to a standard dialog',
        (tester) async {
      await mount(tester);

      // ignore: unawaited_futures
      service.show<void>(
        content: const Text('body'),
        title: 'Report',
        actions: <DialogAction>[
          DialogAction(text: 'Close', onPressed: () {}),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Report'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('a second dialog is refused while the first is up',
        (tester) async {
      await mount(tester);

      // ignore: unawaited_futures
      service.show<void>(content: const Text('first'));
      await tester.pumpAndSettle();

      final second = await service.show<Object>(content: const Text('second'));

      expect(second, isNull);
      expect(find.text('second'), findsNothing,
          reason: 'two stacked dialogs leave the user answering the one they '
              'did not open');
      expect(service.isShowing, isTrue,
          reason: 'the caller tells a refusal from a dismissal by reading '
              'this, since both answer null');
    });

    testWidgets('an alert with no actions still offers a way out',
        (tester) async {
      await mount(tester);

      // ignore: unawaited_futures
      service.show<void>(
        content: const Text('body'),
        title: 'Heads up',
        type: DialogType.alert,
      );
      await tester.pumpAndSettle();

      expect(find.text('OK'), findsOneWidget,
          reason: 'an alert with no button is a dialog the user cannot close');

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Heads up'), findsNothing);
    });

    testWidgets('a destructive action is themed apart from the rest',
        (tester) async {
      await mount(tester);

      // ignore: unawaited_futures
      service.show<void>(
        content: const Text('body'),
        title: 'Delete?',
        actions: <DialogAction>[
          DialogAction(text: 'Keep', onPressed: () {}),
          DialogAction(
              text: 'Delete', onPressed: () {}, isDestructive: true),
          DialogAction(text: 'Save', onPressed: () {}, isDefault: true),
        ],
      );
      await tester.pumpAndSettle();

      expect(
          find.ancestor(
            of: find.text('Delete'),
            matching: find.byType(Theme),
          ),
          findsWidgets,
          reason: 'the dangerous button has to read differently from the one '
              'beside it');
      expect(find.widgetWithText(ElevatedButton, 'Save'), findsOneWidget,
          reason: 'the default action is the raised one');
    });
  });

  group('loading', () {
    testWidgets('shows a spinner with its message, and hides again',
        (tester) async {
      await mount(tester);

      service.showLoading(message: 'Working…');
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Working…'), findsOneWidget);

      service.hideLoading();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: 'a loading dialog that cannot be hidden leaves the app '
              'behind a barrier with no way back');
    });

    testWidgets('hiding when nothing is showing does nothing', (tester) async {
      await mount(tester);

      service.hideLoading();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('a loading dialog with no message is just the spinner',
        (tester) async {
      await mount(tester);

      service.showLoading();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      service.hideLoading();
      await tester.pumpAndSettle();
    });
  });

  group('bottom sheet', () {
    testWidgets('shows its content, and a declared height bounds it',
        (tester) async {
      await mount(tester);

      // ignore: unawaited_futures
      service.showBottomSheet<void>(
        content: const Text('sheet body'),
        height: 180,
      );
      await tester.pumpAndSettle();

      expect(find.text('sheet body'), findsOneWidget);
      expect(
          tester.getSize(find.ancestor(
            of: find.text('sheet body'),
            matching: find.byType(SizedBox),
          ).first).height,
          180);
    });

    testWidgets('with no height it takes only what it needs', (tester) async {
      await mount(tester);

      // ignore: unawaited_futures
      service.showBottomSheet<void>(content: const Text('sheet body'));
      await tester.pumpAndSettle();

      expect(find.text('sheet body'), findsOneWidget);
    });
  });

  group('overlay', () {
    testWidgets('an entry is inserted, and removed again', (tester) async {
      await mount(tester);

      service.showOverlay(builder: (_) => const Text('floating'));
      await tester.pumpAndSettle();

      expect(find.text('floating'), findsOneWidget,
          reason: 'the overlay comes from the navigator state; looking it up '
              'from the overlay\'s own context searched above itself and '
              'threw every time');

      service.removeOverlay();
      await tester.pumpAndSettle();

      expect(find.text('floating'), findsNothing);
    });

    testWidgets('with no navigator the overlay is refused by name',
        (tester) async {
      final detached = DialogService();

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      expect(() => detached.showOverlay(builder: (_) => const SizedBox()),
          throwsStateError,
          reason: 'a host that forgot the navigator key gets told so, rather '
              'than an overlay that silently goes nowhere');
    });
  });

  group('snackbar', () {
    testWidgets('each severity shows the message', (tester) async {
      await mount(tester);

      for (final type in SnackbarType.values) {
        service.showSnackbar(
          message: 'saved ${type.name}',
          type: type,
          duration: const Duration(milliseconds: 200),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('saved ${type.name}'), findsOneWidget,
            reason: type.name);

        // Snackbars queue, so the next one only appears once this has both
        // timed out and finished animating away.
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
      }
    });
  });
}
