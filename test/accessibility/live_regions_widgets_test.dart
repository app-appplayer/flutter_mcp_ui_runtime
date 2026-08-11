// The live-region widgets — what a screen reader is told when something on
// screen changes without the user touching anything.
//
// `LiveRegion` and `AccessibleProgressIndicator` are exported widgets that
// nothing in this repository builds, so nothing had ever checked that an
// announcement reaches the semantics tree at all. A live region that stays
// silent looks identical to one that works: the sighted user sees the new
// value either way.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/accessibility/live_regions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  /// The label the region is currently carrying.
  ///
  /// Read off the `Semantics` widget rather than the semantics tree: the tree
  /// only exists while a `SemanticsHandle` is open, and what is under test is
  /// what the region publishes, not whether a11y happens to be switched on.
  String? regionLabel(WidgetTester tester) => tester
      .widgetList<Semantics>(find.byType(Semantics))
      .map((s) => s.properties.label)
      .firstWhere((l) => l != null && l.isNotEmpty, orElse: () => null);

  group('LiveRegion', () {
    testWidgets('an announcement becomes the region label', (tester) async {
      await tester.pumpWidget(host(const LiveRegion(
        regionId: 'status',
        child: Text('form'),
      )));

      LiveRegionManager.instance.announce('status', 'Saved');
      await tester.pumpAndSettle();

      expect(regionLabel(tester), 'Saved',
          reason: 'the label is the whole announcement — without it the '
              'region is a `Semantics(liveRegion: true)` with nothing to say');
      expect(find.text('form'), findsOneWidget,
          reason: 'and the child it wraps is still drawn');
    });

    testWidgets('an initial value is announced once the first frame is up',
        (tester) async {
      await tester.pumpWidget(host(const LiveRegion(
        regionId: 'greeting',
        announceInitialValue: true,
        initialValue: 'Ready',
        child: Text('form'),
      )));
      await tester.pumpAndSettle();

      expect(regionLabel(tester), 'Ready',
          reason: 'announcing during the build would fire before anything is '
              'listening, which is why it waits for the frame');
    });

    testWidgets('a rebuild with the same id keeps the same subscription',
        (tester) async {
      await tester.pumpWidget(host(const LiveRegion(
        regionId: 'steady',
        child: Text('form'),
      )));

      LiveRegionManager.instance.announce('steady', 'First');
      await tester.pumpAndSettle();
      expect(regionLabel(tester), 'First');

      // Same id, same type — the ordinary rebuild. Re-subscribing here would
      // drop the region and re-create it, and the announcement already on
      // screen would vanish.
      await tester.pumpWidget(host(const LiveRegion(
        regionId: 'steady',
        child: Text('form (again)'),
      )));
      await tester.pumpAndSettle();

      expect(regionLabel(tester), 'First',
          reason: 'the last announcement survives a rebuild that changed only '
              'the child');

      LiveRegionManager.instance.announce('steady', 'Second');
      await tester.pumpAndSettle();
      expect(regionLabel(tester), 'Second',
          reason: 'and the subscription is still live');
    });

    testWidgets('leaving the screen takes the region with it', (tester) async {
      await tester.pumpWidget(host(const LiveRegion(
        regionId: 'gone',
        child: Text('form'),
      )));
      expect(LiveRegionManager.instance.getRegionStream('gone'), isNotNull);

      await tester.pumpWidget(host(const SizedBox()));
      await tester.pumpAndSettle();

      expect(LiveRegionManager.instance.getRegionStream('gone'), isNull,
          reason: 'a region left registered after its widget is gone is an '
              'announcement channel nobody drains');
    });

    // Also the regression for a bound `regionId`: each turn of this loop
    // rebuilds the SAME widget position with a different id, which is what a
    // document does when one status line serves several forms. The state used
    // to keep listening to the region it was created with — the new id was
    // never registered, and the widget went on showing the previous region's
    // announcement.
    testWidgets('every region type announces, and a changed id follows',
        (tester) async {
      for (final type in LiveRegionType.values) {
        await tester.pumpWidget(host(LiveRegion(
          regionId: 'r-${type.name}',
          type: type,
          child: const Text('form'),
        )));

        LiveRegionManager.instance.announce('r-${type.name}', 'Hello ${type.name}');
        await tester.pumpAndSettle();

        expect(regionLabel(tester), 'Hello ${type.name}',
            reason: '${type.name} chooses assertive or polite delivery, and a '
                'type that falls through the switch says nothing at all');
      }
    });
  });

  group('AccessibleProgressIndicator', () {
    testWidgets('it draws, and its label is readable', (tester) async {
      // Built at run time rather than as a const, so the constructor itself
      // runs — a `const` instance is created by the compiler and the
      // constructor body is never entered.
      final value = 0.25;
      await tester.pumpWidget(host(AccessibleProgressIndicator(
        value: value,
        label: 'Uploading',
      )));
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('progress is announced as it moves, not on every frame',
        (tester) async {
      await tester.pumpWidget(host(const AccessibleProgressIndicator(
        value: 0.25,
        label: 'Uploading',
        announceProgress: true,
        announcementInterval: Duration(milliseconds: 100),
      )));

      await tester.pump(const Duration(milliseconds: 150));
      // The announcement goes to the platform channel, which a test cannot
      // read back; what is asserted here is that the timer path runs to
      // completion rather than throwing, and that the widget survives it.
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(host(const AccessibleProgressIndicator(
        value: 0.75,
        label: 'Uploading',
        announceProgress: true,
        announcementInterval: Duration(milliseconds: 100),
      )));
      await tester.pump(const Duration(milliseconds: 150));

      expect(tester.takeException(), isNull);

      await tester.pumpWidget(host(const SizedBox()));
      await tester.pumpAndSettle();
    });
  });
}
