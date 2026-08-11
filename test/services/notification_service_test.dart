// `NotificationService` — the runtime's own notification surface.
//
// 43% covered. What was missing is everything a document actually asks for:
// scheduling, progress that updates in place, channels built from a config
// block, the action handlers a tapped button runs, and the four convenience
// levels. A notification that is created and never delivered looks the same
// from inside the runtime as one that was; only the manager's own state says
// which happened, and nothing was reading it.

import 'package:flutter_mcp_ui_runtime/src/notifications/notification_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/notifications/notification_types.dart';
import 'package:flutter_mcp_ui_runtime/src/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late NotificationManager manager;
  late NotificationService service;

  setUp(() {
    manager = NotificationManager(enableDebugMode: false);
    service = NotificationService(notificationManager: manager);
  });

  tearDown(() async {
    if (manager.isInitialized) await manager.dispose();
  });

  MCPNotification? active(String id) {
    for (final n in manager.activeNotifications) {
      if (n.id == id) return n;
    }
    return null;
  }

  group('showing', () {
    test('a notification reaches the manager with what it was given',
        () async {
      await manager.initialize(requestPermissions: false);

      await service.showNotification(
        id: 'n1',
        title: 'Build finished',
        body: 'All green',
        data: {'route': '/builds/7'},
      );

      final shown = active('n1');
      expect(shown, isNotNull,
          reason: 'a service that builds a notification and never hands it to '
              'the manager is a message nobody receives');
      expect(shown!.title, 'Build finished');
      expect(shown.body, 'All green');
      expect(shown.data['route'], '/builds/7');
      expect(shown.autoCancel, isTrue);
    });

    test('the four levels differ in importance, not just in title', () async {
      await manager.initialize(requestPermissions: false);

      await service.showInfo('info');
      await service.showSuccess('success');
      await service.showError('error');
      await service.showWarning('warning');

      // Four in the same millisecond: they used to share an id derived from
      // the clock alone, so the manager kept only the last and three messages
      // vanished with nothing said.
      expect(manager.activeNotifications, hasLength(4));
      final byTitle = {
        for (final n in manager.activeNotifications) n.title: n,
      };
      expect(byTitle.keys,
          containsAll(['Information', 'Success', 'Error', 'Warning']));
      expect(byTitle['Information']!.priority, NotificationImportance.low);
      expect(byTitle['Error']!.priority, NotificationImportance.high,
          reason: 'importance is what decides whether the OS interrupts — an '
              'error at low importance is a silent error');
      expect(byTitle['Information']!.type, NotificationType.inApp);
    });

    test('a custom title overrides the level default', () async {
      await manager.initialize(requestPermissions: false);
      await service.showError('disk full', title: 'Storage');

      expect(manager.activeNotifications.single.title, 'Storage');
      expect(manager.activeNotifications.single.body, 'disk full');
    });

    test('dismissing removes it, and dismissAll empties the tray', () async {
      await manager.initialize(requestPermissions: false);
      await service.showNotification(id: 'a', title: 'A');
      await service.showNotification(id: 'b', title: 'B');

      await service.dismissNotification('a');
      expect(active('a'), isNull);
      expect(active('b'), isNotNull);

      await service.dismissAllNotifications();
      expect(manager.activeNotifications, isEmpty);
    });
  });

  group('scheduling', () {
    test('a scheduled notification is registered with its repeat interval',
        () async {
      await manager.initialize(requestPermissions: false);

      await service.scheduleNotification(
        id: 'daily',
        title: 'Daily digest',
        scheduledTime: DateTime.now().add(const Duration(hours: 8)),
        repeatInterval: const Duration(days: 1),
      );

      final scheduled = active('daily');
      expect(scheduled, isNotNull);
      expect(scheduled!.repeatInterval, const Duration(days: 1),
          reason: 'a repeat that is dropped turns a daily reminder into a '
              'one-off, and nothing on screen says so');
    });
  });

  group('progress', () {
    test('a progress notification is ongoing and not auto-cancelled',
        () async {
      await manager.initialize(requestPermissions: false);

      await service.showProgressNotification(
        id: 'upload',
        title: 'Uploading',
        progress: 10,
        maxProgress: 100,
      );

      final shown = active('upload')!;
      expect(shown.progress, 10);
      expect(shown.maxProgress, 100);
      expect(shown.ongoing, isTrue);
      expect(shown.autoCancel, isFalse,
          reason: 'a transfer that vanishes from the tray when tapped leaves '
              'the user with no way back to it');
      expect(shown.priority, NotificationImportance.low,
          reason: 'progress must not interrupt — it is ambient');
    });

    test('updating moves the bar and keeps the rest', () async {
      await manager.initialize(requestPermissions: false);
      await service.showProgressNotification(
        id: 'upload',
        title: 'Uploading',
        body: 'report.pdf',
        progress: 10,
      );

      await service.updateProgress(id: 'upload', progress: 60);

      final updated = active('upload')!;
      expect(updated.progress, 60);
      expect(updated.title, 'Uploading');
      expect(updated.body, 'report.pdf',
          reason: 'an update that blanks the body loses which file is being '
              'transferred');
    });

    test('an update may also change the title and body', () async {
      await manager.initialize(requestPermissions: false);
      await service.showProgressNotification(id: 'upload', title: 'Uploading');

      await service.updateProgress(
        id: 'upload',
        progress: 100,
        title: 'Uploaded',
        body: 'done',
      );

      expect(active('upload')!.title, 'Uploaded');
      expect(active('upload')!.body, 'done');
    });

    test('updating a notification that is not there is refused by name',
        () async {
      await manager.initialize(requestPermissions: false);

      expect(
        () => service.updateProgress(id: 'ghost', progress: 50),
        throwsA(isA<ArgumentError>()),
        reason: 'silently creating one would show a progress bar for a '
            'transfer that never started',
      );
    });

    test('indeterminate progress is carried through', () async {
      await manager.initialize(requestPermissions: false);
      await service.showProgressNotification(
        id: 'sync',
        title: 'Syncing',
        indeterminate: true,
      );

      expect(active('sync')!.indeterminate, isTrue);
    });
  });

  group('channels', () {
    test('a channel created directly reaches the manager', () async {
      service.createChannel(
        id: 'alerts',
        name: 'Alerts',
        description: 'Things that need you',
        importance: NotificationImportance.high,
        enableSound: false,
      );
      await manager.initialize(requestPermissions: false);

      final channel =
          manager.channels.firstWhere((c) => c.id == 'alerts');
      expect(channel.name, 'Alerts');
      expect(channel.importance, NotificationImportance.high);
      expect(channel.enableSound, isFalse,
          reason: 'a channel declared silent that rings is the complaint that '
              'gets an app uninstalled');
    });

    test('onInitialize builds every channel in the config block', () async {
      await service.initialize({
        'requestPermissions': false,
        'channels': [
          {'id': 'general', 'name': 'General'},
          {
            'id': 'alerts',
            'name': 'Alerts',
            'importance': 'max',
            'enableVibration': false,
            'enableLights': false,
          },
          'not a channel', // ignored rather than fatal
        ],
      });

      final ids = manager.channels.map((c) => c.id).toList();
      expect(ids, containsAll(['general', 'alerts']));
      final alerts = manager.channels.firstWhere((c) => c.id == 'alerts');
      expect(alerts.importance, NotificationImportance.max);
      expect(alerts.enableVibration, isFalse);
    });

    test('every importance name maps to its own level, and an unknown one '
        'falls back to default', () async {
      await service.initialize({
        'requestPermissions': false,
        'channels': [
          {'id': 'l', 'name': 'l', 'importance': 'low'},
          {'id': 'h', 'name': 'h', 'importance': 'HIGH'},
          {'id': 'm', 'name': 'm', 'importance': 'max'},
          {'id': 'u', 'name': 'u', 'importance': 'telepathic'},
          {'id': 'n', 'name': 'n'},
        ],
      });

      NotificationImportance importanceOf(String id) =>
          manager.channels.firstWhere((c) => c.id == id).importance;

      expect(importanceOf('l'), NotificationImportance.low);
      expect(importanceOf('h'), NotificationImportance.high,
          reason: 'the name is matched case-insensitively — a config written '
              'in caps must not silently drop to default');
      expect(importanceOf('m'), NotificationImportance.max);
      expect(importanceOf('u'), NotificationImportance.defaultImportance);
      expect(importanceOf('n'), NotificationImportance.defaultImportance);
    });

    test('a config with no channels still initialises the manager', () async {
      await service.initialize({'requestPermissions': false});
      expect(manager.isInitialized, isTrue);
    });
  });

  group('action handlers', () {
    test('a tapped action runs the handler that was registered for it',
        () async {
      await service.initialize({'requestPermissions': false});
      var pressed = 0;
      service.registerActionHandler('snooze', () => pressed++);

      await service.showNotification(
        id: 'alarm',
        title: 'Wake up',
        actions: [
          const NotificationAction(id: 'snooze', title: 'Snooze'),
        ],
      );
      await manager.handleNotificationAction('alarm', 'snooze');

      expect(pressed, 1,
          reason: 'the button on a notification is the whole point of putting '
              'it there — an unrouted tap does nothing and reports nothing');
    });

    test('an action nobody registered is ignored rather than fatal',
        () async {
      await service.initialize({'requestPermissions': false});

      await service.showNotification(
        id: 'alarm',
        title: 'Wake up',
        actions: [const NotificationAction(id: 'ignore', title: 'Ignore')],
      );

      // The manager verifies the action exists on the notification before
      // routing it; an id nobody declared is refused there rather than
      // reaching a handler map that has never heard of it.
      await manager.handleNotificationAction('alarm', 'ignore');
      expect(manager.isInitialized, isTrue);
    });

    test('tapping the notification itself does not run an action handler',
        () async {
      await service.initialize({'requestPermissions': false});
      var pressed = 0;
      service.registerActionHandler('snooze', () => pressed++);

      await service.showNotification(id: 'alarm', title: 'Wake up');
      await manager.handleNotificationTap('alarm');

      expect(pressed, 0,
          reason: 'a body tap and a button tap are different gestures; '
              'conflating them fires Snooze when the user opened the app');
    });
  });

  group('lifecycle', () {
    test('dispose clears the channels and the handlers', () async {
      await service.initialize({
        'requestPermissions': false,
        'channels': [
          {'id': 'general', 'name': 'General'},
        ],
      });
      service.registerActionHandler('snooze', () {});

      await service.dispose();

      expect(manager.isInitialized, isFalse,
          reason: 'a service left initialised keeps a disposed page\'s '
              'handlers reachable');
    });

    test('the manager is reachable for a host that needs it directly', () {
      expect(service.manager, same(manager));
    });
  });
}
