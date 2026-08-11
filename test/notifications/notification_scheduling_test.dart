// Scheduling and the per-type dispatch in `NotificationManager`.
//
// The manager is what a document reaches through `notification` actions, and
// the listener stream is the only report a host gets. A scheduled
// notification that is dismissed before its time must not arrive; one whose
// time has passed must not fire immediately as though it were new.

import 'package:flutter_mcp_ui_runtime/src/notifications/notification_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/notifications/notification_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late NotificationManager manager;

  setUp(() async {
    manager = NotificationManager(enableDebugMode: true);
    await manager.initialize();
  });

  tearDown(() => manager.dispose());

  MCPNotification note(
    String id, {
    NotificationType type = NotificationType.local,
    DateTime? scheduledTime,
  }) =>
      MCPNotification(
        id: id,
        title: 'Job $id',
        body: 'ready',
        type: type,
        scheduledTime: scheduledTime,
      );

  group('showing', () {
    test('each type is dispatched, and the show is reported', () async {
      final events = <NotificationEvent>[];
      manager.addListener((event, notification, actionId) => events.add(event));

      for (final type in NotificationType.values) {
        await manager.showNotification(note(type.name, type: type));
      }

      expect(events, everyElement(NotificationEvent.shown));
      expect(events, hasLength(NotificationType.values.length),
          reason: 'a type that silently does nothing leaves the document '
              'believing the user was told');
      expect(manager.activeNotifications, hasLength(3));
    });

    test('showing before initialising is refused by name', () async {
      final fresh = NotificationManager(enableDebugMode: true);

      expect(() => fresh.showNotification(note('a')), throwsStateError);
      expect(() => fresh.scheduleNotification(note('a'), DateTime.now()),
          throwsStateError);
    });
  });

  group('scheduling', () {
    test('a scheduled notification is held, and reported as scheduled',
        () async {
      final events = <NotificationEvent>[];
      manager.addListener((event, notification, actionId) => events.add(event));

      final when = DateTime.now().add(const Duration(hours: 1));
      await manager.scheduleNotification(note('a'), when);

      expect(events, [NotificationEvent.scheduled]);
      expect(manager.activeNotifications.first.scheduledTime, when,
          reason: 'the stored copy carries the time, which is what a host '
              'reads back to show "reminder set for …"');
    });

    test('an in-app notification is scheduled through its own path', () async {
      await manager.scheduleNotification(
        note('a', type: NotificationType.inApp),
        DateTime.now().add(const Duration(hours: 1)),
      );

      expect(manager.activeNotifications, hasLength(1));
    });

    test('a time already past does not fire again', () async {
      await manager.scheduleNotification(
        note('a', type: NotificationType.inApp),
        DateTime.now().subtract(const Duration(hours: 1)),
      );

      expect(manager.activeNotifications, hasLength(1),
          reason: 'a reminder whose time passed while the app was closed must '
              'not arrive as though it were new');
    });

    testWidgets('a scheduled in-app notification arrives when its time comes',
        (tester) async {
      await manager.scheduleNotification(
        note('a', type: NotificationType.inApp),
        DateTime.now().add(const Duration(milliseconds: 40)),
      );

      await tester.pump(const Duration(milliseconds: 80));

      expect(manager.activeNotifications, hasLength(1),
          reason: 'the delivery reads the active set to decide whether the '
              'reminder is still wanted; a reminder that fires and vanishes '
              'from the list cannot be dismissed afterwards');
    });

    testWidgets('one dismissed before its time does not arrive',
        (tester) async {
      await manager.scheduleNotification(
        note('a', type: NotificationType.inApp),
        DateTime.now().add(const Duration(milliseconds: 40)),
      );
      await manager.dismissNotification('a');

      await tester.pump(const Duration(milliseconds: 80));

      expect(manager.activeNotifications, isEmpty,
          reason: 'a reminder the user cancelled must not arrive anyway — the '
              'delivery checks the active set for exactly this reason');
    });

    test('a system type schedules through the system path', () async {
      await manager.scheduleNotification(
        note('a', type: NotificationType.system),
        DateTime.now().add(const Duration(minutes: 5)),
      );

      expect(manager.activeNotifications, hasLength(1));
    });
  });

  group('dismissing', () {
    test('a dismissal is reported and drops the notification', () async {
      final events = <NotificationEvent>[];
      manager.addListener((event, notification, actionId) => events.add(event));

      await manager.showNotification(note('a'));
      await manager.dismissNotification('a');

      expect(events, [NotificationEvent.shown, NotificationEvent.dismissed]);
      expect(manager.activeNotifications, isEmpty);
    });

    test('dismissing something that is not there is quiet', () async {
      final events = <NotificationEvent>[];
      manager.addListener((event, notification, actionId) => events.add(event));

      await manager.dismissNotification('never-shown');

      expect(events, isEmpty,
          reason: 'reporting a dismissal that did not happen would make a '
              'host clear a badge it should have kept');
    });

    test('dismissing all clears every one of them', () async {
      await manager.showNotification(note('a'));
      await manager.showNotification(note('b'));

      await manager.dismissAllNotifications();

      expect(manager.activeNotifications, isEmpty);
    });
  });

  group('listeners', () {
    test('a removed listener hears nothing more', () async {
      final events = <NotificationEvent>[];
      void listener(
              NotificationEvent event, MCPNotification n, String? actionId) =>
          events.add(event);

      manager.addListener(listener);
      await manager.showNotification(note('a'));
      manager.removeListener(listener);
      await manager.showNotification(note('b'));

      expect(events, hasLength(1));
    });

    test('one throwing listener does not stop the others', () async {
      var reached = false;
      manager.addListener((_, __, ___) => throw StateError('broke'));
      manager.addListener((_, __, ___) => reached = true);

      await manager.showNotification(note('a'));

      expect(reached, isTrue);
    });
  });
}
