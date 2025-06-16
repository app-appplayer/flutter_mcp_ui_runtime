import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/services/notification_service.dart';
import 'package:flutter_mcp_ui_runtime/src/notifications/notification_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/notifications/notification_types.dart';

void main() {
  group('NotificationService Tests', () {
    late NotificationService notificationService;
    late NotificationManager notificationManager;

    setUp(() {
      notificationManager = NotificationManager(enableDebugMode: false);
      notificationService = NotificationService(
        notificationManager: notificationManager,
        enableDebugMode: false,
      );
    });

    tearDown(() async {
      await notificationService.dispose();
    });

    test('initializes notification service', () async {
      await notificationService.initialize({});
      expect(notificationService.isInitialized, isTrue);
    });

    test('creates notification channels', () async {
      await notificationService.initialize({});

      notificationService.createChannel(
        id: 'test_channel',
        name: 'Test Channel',
        description: 'A test notification channel',
        importance: NotificationImportance.high,
      );

      // Channel should be added to manager
      expect(notificationManager.channels.any((ch) => ch.id == 'test_channel'), isTrue);
    });

    test('shows local notifications', () async {
      await notificationService.initialize({});

      await notificationService.showNotification(
        id: 'test_notif',
        title: 'Test Notification',
        body: 'This is a test',
        type: NotificationType.local,
      );

      expect(notificationManager.activeNotifications.length, 1);
      expect(notificationManager.activeNotifications.first.id, 'test_notif');
      expect(notificationManager.activeNotifications.first.title, 'Test Notification');
    });

    test('dismisses notifications', () async {
      await notificationService.initialize({});

      await notificationService.showNotification(
        id: 'dismiss_test',
        title: 'Will be dismissed',
        body: 'This notification will be removed',
        type: NotificationType.local,
      );

      expect(notificationManager.activeNotifications.length, 1);

      await notificationService.dismissNotification('dismiss_test');
      expect(notificationManager.activeNotifications.length, 0);
    });

    test('shows different notification types', () async {
      await notificationService.initialize({});

      // Show info notification
      await notificationService.showInfo('Info message');
      expect(notificationManager.activeNotifications.length, 1);

      // Clear notifications before next test
      await notificationManager.dismissAllNotifications();

      // Show success notification
      await notificationService.showSuccess('Success message');
      expect(notificationManager.activeNotifications.length, 1);

      // Clear notifications before next test  
      await notificationManager.dismissAllNotifications();

      // Show warning notification
      await notificationService.showWarning('Warning message');
      expect(notificationManager.activeNotifications.length, 1);

      // Clear notifications before next test
      await notificationManager.dismissAllNotifications();

      // Show error notification
      await notificationService.showError('Error message');
      expect(notificationManager.activeNotifications.length, 1);
    });
  });
}