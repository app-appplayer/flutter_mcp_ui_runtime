// Live regions — how a screen reader is told that something changed.
//
// 64% covered, and the uncovered third was the widgets themselves: the region
// that subscribes and rebuilds, the status banner that dismisses itself, the
// progress indicator that announces as it moves, the form field that speaks
// its error. None of this is visible to a sighted user, which is exactly why
// it rots quietly: a region that stops announcing looks identical on screen.
//
// Everything here is checked through the semantics tree — the same tree a
// screen reader walks — rather than through the widget's internals.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mcp_ui_runtime/src/accessibility/live_regions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(LiveRegionManager.instance.clear);

  group('LiveRegionManager', () {
    test('re-creating a region keeps the listeners already attached to it',
        () async {
      final manager = LiveRegionManager.instance;
      manager.createRegion('status', LiveRegionType.polite);
      final heard = <String>[];
      manager.getRegionStream('status')!.listen(heard.add);

      manager.createRegion('status', LiveRegionType.assertive);
      manager.announce('status', 'still listening');
      await Future<void>.delayed(Duration.zero);

      expect(heard, ['still listening'],
          reason: 'replacing the controller would leave every mounted widget '
              'subscribed to a dead stream — deaf, with nothing reported');
    });

    test('announcing reaches every listener of that region', () async {
      final manager = LiveRegionManager.instance;
      manager.createRegion('status', LiveRegionType.polite);

      final a = <String>[];
      final b = <String>[];
      manager.getRegionStream('status')!.listen(a.add);
      manager.getRegionStream('status')!.listen(b.add);

      manager.announce('status', 'Saved');
      await Future<void>.delayed(Duration.zero);

      expect(a, ['Saved']);
      expect(b, ['Saved'],
          reason: 'the stream is broadcast: a second widget bound to the same '
              'region must not steal the first one\'s announcements');
    });

    test('announcing to a region nobody created reaches nobody', () async {
      final manager = LiveRegionManager.instance;
      manager.createRegion('status', LiveRegionType.polite);
      final heard = <String>[];
      manager.getRegionStream('status')!.listen(heard.add);

      manager.announce('other', 'Saved');
      await Future<void>.delayed(Duration.zero);

      expect(heard, isEmpty);
      expect(manager.getRegionStream('other'), isNull);
    });

    test('a removed region stops delivering, and clear removes them all',
        () async {
      final manager = LiveRegionManager.instance;
      manager.createRegion('status', LiveRegionType.polite);
      final heard = <String>[];
      manager.getRegionStream('status')!.listen(heard.add);

      manager.removeRegion('status');
      manager.announce('status', 'too late');
      await Future<void>.delayed(Duration.zero);

      expect(heard, isEmpty);
      expect(manager.getRegionStream('status'), isNull);

      manager.createRegion('a', LiveRegionType.polite);
      manager.createRegion('b', LiveRegionType.polite);
      manager.clear();
      expect(manager.getRegionStream('a'), isNull);
      expect(manager.getRegionStream('b'), isNull);
    });

    test('removing a region nobody created is not fatal', () {
      LiveRegionManager.instance.createRegion('real', LiveRegionType.polite);
      LiveRegionManager.instance.removeRegion('imaginary');
      expect(LiveRegionManager.instance.getRegionStream('real'), isNotNull,
          reason: 'a miss that cleared the map would mute every region on the '
              'page');
    });
  });

  group('LiveRegion widget', () {
    testWidgets('an announcement becomes the semantics label', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: LiveRegion(
          regionId: 'cart',
          child: Text('3 items'),
        ),
      ));

      LiveRegionManager.instance.announce('cart', '4 items in your cart');
      await tester.pumpAndSettle();

      final semantics = tester.widget<Semantics>(find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.liveRegion == true));
      expect(semantics.properties.liveRegion, isTrue);
      expect(semantics.properties.label, '4 items in your cart',
          reason: 'this label is the entire announcement — a region that '
              'rebuilds without it says nothing to a screen reader');
    });

    testWidgets('the region is registered while mounted and gone after',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: LiveRegion(regionId: 'cart', child: Text('x')),
      ));
      expect(LiveRegionManager.instance.getRegionStream('cart'), isNotNull);

      await tester.pumpWidget(const MaterialApp(home: Text('gone')));
      await tester.pumpAndSettle();

      expect(LiveRegionManager.instance.getRegionStream('cart'), isNull,
          reason: 'a region left behind keeps a closed page subscribed');
    });

    testWidgets('an initial value is announced once the frame is up',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: LiveRegion(
          regionId: 'status',
          announceInitialValue: true,
          initialValue: 'Loading complete',
          child: Text('body'),
        ),
      ));
      await tester.pumpAndSettle();

      final semantics = tester.widget<Semantics>(find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.liveRegion == true));
      expect(semantics.properties.label, 'Loading complete');
    });

    testWidgets('without announceInitialValue nothing is said up front',
        (tester) async {
      final heard = <String>[];
      await tester.pumpWidget(const MaterialApp(
        home: LiveRegion(
          regionId: 'status',
          initialValue: 'Loading complete',
          child: Text('body'),
        ),
      ));
      LiveRegionManager.instance.getRegionStream('status')!.listen(heard.add);
      await tester.pumpAndSettle();

      expect(heard, isEmpty,
          reason: 'announcing on mount by default would make every page load '
              'read its own status aloud');
    });
  });

  group('LiveRegionBuilder', () {
    testWidgets('the builder is handed each announcement as it arrives',
        (tester) async {
      final seen = <String?>[];

      await tester.pumpWidget(MaterialApp(
        home: LiveRegionBuilder(
          regionId: 'feed',
          builder: (context, announcement) {
            seen.add(announcement);
            return Text(announcement ?? 'nothing yet');
          },
        ),
      ));

      expect(find.text('nothing yet'), findsOneWidget);

      LiveRegionManager.instance.announce('feed', 'One new message');
      await tester.pumpAndSettle();

      expect(find.text('One new message'), findsOneWidget);
      expect(seen.last, 'One new message');
    });

    testWidgets('it unregisters its region on dispose', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: LiveRegionBuilder(
          regionId: 'feed',
          builder: (context, announcement) => const SizedBox(),
        ),
      ));
      expect(LiveRegionManager.instance.getRegionStream('feed'), isNotNull);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();
      expect(LiveRegionManager.instance.getRegionStream('feed'), isNull);
    });
  });

  group('StatusLiveRegion', () {
    testWidgets('shows its message with an icon that matches the type',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: StatusLiveRegion(
            message: 'Could not save',
            type: LiveRegionType.assertive,
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('Could not save'), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget,
          reason: 'the icon carries the severity for a sighted user; the '
              'assertiveness carries it for a screen reader');
    });

    testWidgets('autoDismiss removes it and tells the caller', (tester) async {
      var dismissed = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatusLiveRegion(
            message: 'Saved',
            autoDismiss: const Duration(milliseconds: 200),
            onDismiss: () => dismissed = true,
          ),
        ),
      ));
      await tester.pump();
      expect(dismissed, isFalse);

      await tester.pump(const Duration(milliseconds: 250));
      expect(dismissed, isTrue,
          reason: 'the host owns the banner; without the callback it would '
              'stay on screen forever after the timer fired');
    });

    testWidgets('with no autoDismiss it stays', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatusLiveRegion(
            message: 'Persistent',
            onDismiss: () => dismissed = true,
          ),
        ),
      ));
      await tester.pump(const Duration(seconds: 2));

      expect(dismissed, isFalse);
      expect(find.text('Persistent'), findsOneWidget);
    });
  });

    testWidgets('each type has its own colours', (tester) async {
      Future<Color?> backgroundFor(LiveRegionType type) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: StatusLiveRegion(message: 'x', type: type),
          ),
        ));
        await tester.pump();
        final container = tester.widget<Container>(find
            .ancestor(
                of: find.text('x'), matching: find.byType(Container))
            .first);
        return (container.decoration as BoxDecoration?)?.color ??
            container.color;
      }

      final alert = await backgroundFor(LiveRegionType.alert);
      final status = await backgroundFor(LiveRegionType.status);
      final polite = await backgroundFor(LiveRegionType.polite);

      expect(alert, isNot(status));
      expect(status, isNot(polite),
          reason: 'the banner colour is how a sighted user tells a failure '
              'from a confirmation at a glance; one colour for all three '
              'makes the type decorative');
    });

  group('AccessibleProgressIndicator', () {
    testWidgets('a determinate value draws a bar and reads as a percentage',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AccessibleProgressIndicator(value: 0.42, label: 'Upload'),
        ),
      ));
      await tester.pump();

      final bar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(bar.value, 0.42);

      await tester.pump(const Duration(seconds: 6));
      // The timer is what keeps a long upload audible; leaving it running
      // after the widget is gone is the other half of the contract.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(const Duration(seconds: 6));
      expect(tester.takeException(), isNull);
    });

    testWidgets('with no value it is indeterminate', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AccessibleProgressIndicator(label: 'Working')),
      ));
      await tester.pump();

      final bar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(bar.value, isNull,
          reason: 'an indeterminate bar must not pretend to know how far '
              'along it is');
    });

    testWidgets('announceProgress: false schedules no timer', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AccessibleProgressIndicator(
            value: 0.5,
            announceProgress: false,
          ),
        ),
      ));
      await tester.pump(const Duration(seconds: 10));
      expect(tester.takeException(), isNull,
          reason: 'a pending timer at teardown fails the test — which is how '
              'a leaked periodic announcement would show up');
    });

    testWidgets('a changed value restarts the announcements', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AccessibleProgressIndicator(value: 0.1)),
      ));
      await tester.pump();

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AccessibleProgressIndicator(value: 0.9)),
      ));
      await tester.pump();

      final bar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(bar.value, 0.9);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();
    });

    testWidgets('the percentage is announced as the value moves',
        (tester) async {
      // The announcement is the whole feature: a progress bar that moves and
      // says nothing leaves a screen-reader user with no idea whether a long
      // upload is progressing or stuck.
      final spoken = <String>[];
      tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
        SystemChannels.accessibility,
        (message) async {
          final data = (message as Map<Object?, Object?>)['data'];
          if (data is Map && data['message'] != null) {
            spoken.add(data['message'].toString());
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
              SystemChannels.accessibility, null));

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AccessibleProgressIndicator(
            value: 0.42,
            label: 'Upload',
            announcementInterval: Duration(milliseconds: 100),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(spoken, contains('Upload: 42%'),
          reason: 'the label and the rounded percentage are what a screen '
              'reader reads out; a timer that fires and announces nothing is '
              'the same as no timer');

      // The same value again must not repeat itself on every tick.
      spoken.clear();
      await tester.pump(const Duration(milliseconds: 300));
      expect(spoken, isEmpty,
          reason: 'repeating an unchanged percentage every interval talks '
              'over everything else on the screen');

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();
    });

    testWidgets('turning the value indeterminate stops the announcements',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AccessibleProgressIndicator(
            value: 0.3,
            announcementInterval: Duration(milliseconds: 50),
          ),
        ),
      ));
      await tester.pump();

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AccessibleProgressIndicator(
            announcementInterval: Duration(milliseconds: 50),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull,
          reason: 'a bar that goes indeterminate has no percentage to '
              'announce; leaving the timer running would keep reading out the '
              'last known one');
    });
  });

  group('AccessibleFormField', () {
    testWidgets('a validation error is shown and announced', (tester) async {
      final heard = <String>[];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AccessibleFormField(
            fieldId: 'email',
            label: 'Email',
            validator: (value) =>
                (value ?? '').contains('@') ? null : 'Not an email address',
          ),
        ),
      ));
      LiveRegionManager.instance
          .getRegionStream('email_error')!
          .listen(heard.add);

      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'nope');
      await tester.pumpAndSettle();

      expect(find.text('Not an email address'), findsOneWidget);
      expect(heard, ['Error: Not an email address'],
          reason: 'an error shown only in red text is invisible to a screen '
              'reader — the assertive region is how it is heard');
    });

    testWidgets('and the fix is announced too, once the value is valid',
        (tester) async {
      // The clear branch was dead: it tested the error state AFTER `setState`
      // had already replaced it, so it was null exactly when the branch needed
      // it not to be. A screen-reader user heard about every mistake and never
      // about the correction.
      final heard = <String>[];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AccessibleFormField(
            fieldId: 'email',
            label: 'Email',
            validator: (value) =>
                (value ?? '').contains('@') ? null : 'Not an email address',
          ),
        ),
      ));
      LiveRegionManager.instance
          .getRegionStream('email_error')!
          .listen(heard.add);

      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'nope');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'me@example.com');
      await tester.pumpAndSettle();

      expect(heard, ['Error: Not an email address', 'Error cleared']);
      expect(find.text('Not an email address'), findsNothing);
    });

    testWidgets('announceErrors: false registers no region at all',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AccessibleFormField(
            fieldId: 'quiet',
            label: 'Quiet',
            announceErrors: false,
            validator: (value) => 'nope',
          ),
        ),
      ));

      expect(LiveRegionManager.instance.getRegionStream('quiet_error'), isNull);
    });

    testWidgets('a supplied controller is not disposed by the field',
        (tester) async {
      final controller = TextEditingController(text: 'kept');
      addTearDown(controller.dispose);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AccessibleFormField(
            fieldId: 'own',
            label: 'Owned by the host',
            controller: controller,
          ),
        ),
      ));
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();

      expect(controller.text, 'kept',
          reason: 'disposing a controller the host owns leaves the host with '
              'a dead object it is still holding');
    });
  });
}
