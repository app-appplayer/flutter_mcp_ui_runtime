import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/notifications/notification_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/notifications/notification_types.dart';

void main() {
  group('NotificationManager Tests', () {
    late NotificationManager manager;

    setUp(() {
      manager = NotificationManager(enableDebugMode: true);
    });

    tearDown(() async {
      await manager.dispose();
    });

    group('Initialization', () {
      test('should initialize successfully', () async {
        await manager.initialize();
        expect(manager.isInitialized, isTrue);
        expect(manager.channels, isNotEmpty);
      });

      test('should throw if already initialized', () async {
        await manager.initialize();
        
        expect(
          () => manager.initialize(),
          throwsStateError,
        );
      });

      test('should set up default channels', () async {
        await manager.initialize();
        
        expect(manager.channels.length, equals(3));
        expect(manager.getChannel('general'), isNotNull);
        expect(manager.getChannel('alerts'), isNotNull);
        expect(manager.getChannel('updates'), isNotNull);
      });

      test('should accept custom channels', () async {
        final customChannels = [
          const NotificationChannel(
            id: 'custom',
            name: 'Custom Channel',
            importance: NotificationImportance.high,
          ),
        ];
        
        await manager.initialize(channels: customChannels);
        
        expect(manager.channels.length, equals(1));
        expect(manager.getChannel('custom'), isNotNull);
      });
    });

    group('Notification Management', () {
      setUp(() async {
        await manager.initialize();
      });

      test('should show notification', () async {
        const notification = MCPNotification(
          id: 'test-1',
          title: 'Test Notification',
          body: 'This is a test',
        );
        
        await manager.showNotification(notification);
        
        expect(manager.activeNotifications.length, equals(1));
        expect(manager.activeNotifications.first.id, equals('test-1'));
      });

      test('should schedule notification', () async {
        const notification = MCPNotification(
          id: 'scheduled-1',
          title: 'Scheduled Notification',
        );
        
        final scheduledTime = DateTime.now().add(const Duration(minutes: 5));
        await manager.scheduleNotification(notification, scheduledTime);
        
        expect(manager.activeNotifications.length, equals(1));
        final active = manager.activeNotifications.first;
        expect(active.scheduledTime, equals(scheduledTime));
      });

      test('should dismiss notification', () async {
        const notification = MCPNotification(
          id: 'dismiss-1',
          title: 'To Dismiss',
        );
        
        await manager.showNotification(notification);
        expect(manager.activeNotifications.length, equals(1));
        
        await manager.dismissNotification('dismiss-1');
        expect(manager.activeNotifications, isEmpty);
      });

      test('should dismiss all notifications', () async {
        final notifications = [
          const MCPNotification(id: '1', title: 'First'),
          const MCPNotification(id: '2', title: 'Second'),
          const MCPNotification(id: '3', title: 'Third'),
        ];
        
        for (final notification in notifications) {
          await manager.showNotification(notification);
        }
        expect(manager.activeNotifications.length, equals(3));
        
        await manager.dismissAllNotifications();
        expect(manager.activeNotifications, isEmpty);
      });

      test('should throw when not initialized', () {
        final uninitializedManager = NotificationManager();
        const notification = MCPNotification(
          id: 'test',
          title: 'Test',
        );
        
        expect(
          () => uninitializedManager.showNotification(notification),
          throwsStateError,
        );
      });
    });

    group('Notification Types', () {
      setUp(() async {
        await manager.initialize();
      });

      test('should handle local notifications', () async {
        const notification = MCPNotification(
          id: 'local-1',
          title: 'Local Notification',
          type: NotificationType.local,
        );
        
        await manager.showNotification(notification);
        expect(manager.activeNotifications.first.type, equals(NotificationType.local));
      });

      test('should handle system notifications', () async {
        const notification = MCPNotification(
          id: 'system-1',
          title: 'System Notification',
          type: NotificationType.system,
        );
        
        await manager.showNotification(notification);
        expect(manager.activeNotifications.first.type, equals(NotificationType.system));
      });

      test('should handle in-app notifications', () async {
        const notification = MCPNotification(
          id: 'inapp-1',
          title: 'In-App Notification',
          type: NotificationType.inApp,
        );
        
        await manager.showNotification(notification);
        expect(manager.activeNotifications.first.type, equals(NotificationType.inApp));
      });
    });

    group('Notification Actions', () {
      setUp(() async {
        await manager.initialize();
      });

      test('should handle notification action', () async {
        const notification = MCPNotification(
          id: 'action-1',
          title: 'With Actions',
          actions: [
            NotificationAction(id: 'reply', title: 'Reply'),
            NotificationAction(id: 'dismiss', title: 'Dismiss'),
          ],
        );
        
        await manager.showNotification(notification);
        
        // Should not throw
        await manager.handleNotificationAction('action-1', 'reply');
      });

      test('should throw for invalid action ID', () async {
        const notification = MCPNotification(
          id: 'action-2',
          title: 'With Actions',
          actions: [
            NotificationAction(id: 'valid', title: 'Valid'),
          ],
        );
        
        await manager.showNotification(notification);
        
        expect(
          () => manager.handleNotificationAction('action-2', 'invalid'),
          throwsArgumentError,
        );
      });

      test('should handle notification tap', () async {
        const notification = MCPNotification(
          id: 'tap-1',
          title: 'Tappable',
        );
        
        await manager.showNotification(notification);
        
        // Should not throw
        await manager.handleNotificationTap('tap-1');
      });
    });

    group('Notification Listeners', () {
      setUp(() async {
        await manager.initialize();
      });

      test('should notify listeners on show', () async {
        NotificationEvent? receivedEvent;
        MCPNotification? receivedNotification;
        
        manager.addListener((event, notification, actionId) {
          receivedEvent = event;
          receivedNotification = notification;
        });
        
        const notification = MCPNotification(
          id: 'listener-1',
          title: 'Test',
        );
        
        await manager.showNotification(notification);
        
        expect(receivedEvent, equals(NotificationEvent.shown));
        expect(receivedNotification?.id, equals('listener-1'));
      });

      test('should notify listeners on dismiss', () async {
        NotificationEvent? receivedEvent;
        
        manager.addListener((event, notification, actionId) {
          receivedEvent = event;
        });
        
        const notification = MCPNotification(
          id: 'dismiss-listener',
          title: 'Test',
        );
        
        await manager.showNotification(notification);
        await manager.dismissNotification('dismiss-listener');
        
        expect(receivedEvent, equals(NotificationEvent.dismissed));
      });

      test('should notify listeners on action tap', () async {
        NotificationEvent? receivedEvent;
        String? receivedActionId;
        
        manager.addListener((event, notification, actionId) {
          receivedEvent = event;
          receivedActionId = actionId;
        });
        
        const notification = MCPNotification(
          id: 'action-listener',
          title: 'Test',
          actions: [
            NotificationAction(id: 'test-action', title: 'Test'),
          ],
        );
        
        await manager.showNotification(notification);
        await manager.handleNotificationAction('action-listener', 'test-action');
        
        expect(receivedEvent, equals(NotificationEvent.actionTapped));
        expect(receivedActionId, equals('test-action'));
      });

      test('should remove listeners', () {
        var callCount = 0;
        
        void listener(NotificationEvent event, MCPNotification notification, String? actionId) {
          callCount++;
        }
        
        manager.addListener(listener);
        manager.removeListener(listener);
        
        const notification = MCPNotification(
          id: 'no-listener',
          title: 'Test',
        );
        
        manager.showNotification(notification);
        
        expect(callCount, equals(0));
      });

      test('should handle listener errors gracefully', () async {
        manager.addListener((event, notification, actionId) {
          throw Exception('Listener error');
        });
        
        const notification = MCPNotification(
          id: 'error-listener',
          title: 'Test',
        );
        
        // Should not throw despite listener error
        await manager.showNotification(notification);
        expect(manager.activeNotifications.length, equals(1));
      });
    });

    group('Channel Management', () {
      setUp(() async {
        await manager.initialize();
      });

      test('should add channel', () {
        const newChannel = NotificationChannel(
          id: 'new-channel',
          name: 'New Channel',
        );
        
        manager.addChannel(newChannel);
        
        expect(manager.getChannel('new-channel'), equals(newChannel));
      });

      test('should get channel by ID', () {
        final channel = manager.getChannel('general');
        
        expect(channel, isNotNull);
        expect(channel!.id, equals('general'));
        expect(channel.name, equals('General Notifications'));
      });

      test('should return null for non-existent channel', () {
        final channel = manager.getChannel('non-existent');
        expect(channel, isNull);
      });
    });

    group('Disposal', () {
      test('should clean up on dispose', () async {
        await manager.initialize();
        
        // Add some notifications
        await manager.showNotification(
          const MCPNotification(id: '1', title: 'Test'),
        );
        
        // Add a listener
        manager.addListener((event, notification, actionId) {});
        
        await manager.dispose();
        
        expect(manager.isInitialized, isFalse);
        expect(manager.activeNotifications, isEmpty);
        expect(manager.channels, isEmpty);
      });
    });
  });

  group('NotificationChannel Tests', () {
    test('should create channel with defaults', () {
      const channel = NotificationChannel(
        id: 'test',
        name: 'Test Channel',
      );
      
      expect(channel.id, equals('test'));
      expect(channel.name, equals('Test Channel'));
      expect(channel.importance, equals(NotificationImportance.defaultImportance));
      expect(channel.enableSound, isTrue);
      expect(channel.enableVibration, isTrue);
      expect(channel.enableLights, isTrue);
    });

    test('should handle equality correctly', () {
      const channel1 = NotificationChannel(
        id: 'test',
        name: 'Test Channel',
      );
      
      const channel2 = NotificationChannel(
        id: 'test',
        name: 'Different Name',
      );
      
      const channel3 = NotificationChannel(
        id: 'other',
        name: 'Test Channel',
      );
      
      expect(channel1, equals(channel2)); // Same ID
      expect(channel1, isNot(equals(channel3))); // Different ID
    });
  });

  group('NotificationAction Tests', () {
    test('should create action', () {
      const action = NotificationAction(
        id: 'test-action',
        title: 'Test Action',
      );
      
      expect(action.id, equals('test-action'));
      expect(action.title, equals('Test Action'));
      expect(action.isDestructive, isFalse);
      expect(action.isAuthenticationRequired, isFalse);
    });

    test('should handle equality correctly', () {
      const action1 = NotificationAction(
        id: 'test',
        title: 'Test',
      );
      
      const action2 = NotificationAction(
        id: 'test',
        title: 'Different Title',
      );
      
      expect(action1, equals(action2));
    });

    test('should convert to/from JSON', () {
      const action = NotificationAction(
        id: 'test',
        title: 'Test Action',
        icon: 'test_icon',
        isDestructive: true,
        isAuthenticationRequired: false,
      );
      
      final json = action.toJson();
      final decoded = NotificationActionJson.fromJson(json);
      
      expect(decoded.id, equals(action.id));
      expect(decoded.title, equals(action.title));
      expect(decoded.icon, equals(action.icon));
      expect(decoded.isDestructive, equals(action.isDestructive));
      expect(decoded.isAuthenticationRequired, equals(action.isAuthenticationRequired));
    });
  });

  group('MCPNotification Tests', () {
    test('should create notification with defaults', () {
      const notification = MCPNotification(
        id: 'test',
        title: 'Test Notification',
      );
      
      expect(notification.id, equals('test'));
      expect(notification.title, equals('Test Notification'));
      expect(notification.type, equals(NotificationType.local));
      expect(notification.channelId, equals('general'));
      expect(notification.priority, equals(NotificationImportance.defaultImportance));
      expect(notification.autoCancel, isTrue);
      expect(notification.enableLights, isTrue);
    });

    test('should copy with modified values', () {
      const original = MCPNotification(
        id: 'test',
        title: 'Original',
        body: 'Original body',
      );
      
      final copied = original.copyWith(
        title: 'Modified',
        type: NotificationType.system,
      );
      
      expect(copied.id, equals('test'));
      expect(copied.title, equals('Modified'));
      expect(copied.body, equals('Original body'));
      expect(copied.type, equals(NotificationType.system));
    });

    test('should convert to/from JSON', () {
      final notification = MCPNotification(
        id: 'test',
        title: 'Test',
        body: 'Test body',
        type: NotificationType.system,
        channelId: 'custom',
        priority: NotificationImportance.high,
        actions: [
          const NotificationAction(id: 'action1', title: 'Action 1'),
        ],
        data: {'key': 'value'},
        progress: 50,
        maxProgress: 100,
        scheduledTime: DateTime(2024, 1, 1, 12, 0),
      );
      
      final json = notification.toJson();
      final decoded = MCPNotification.fromJson(json);
      
      expect(decoded.id, equals(notification.id));
      expect(decoded.title, equals(notification.title));
      expect(decoded.body, equals(notification.body));
      expect(decoded.type, equals(notification.type));
      expect(decoded.channelId, equals(notification.channelId));
      expect(decoded.priority, equals(notification.priority));
      expect(decoded.actions.length, equals(1));
      expect(decoded.data['key'], equals('value'));
      expect(decoded.progress, equals(50));
      expect(decoded.maxProgress, equals(100));
      expect(decoded.scheduledTime, equals(notification.scheduledTime));
    });

    test('should parse notification type correctly', () {
      expect(MCPNotification.fromJson({'id': '1', 'title': 'T', 'type': 'system'}).type, 
             equals(NotificationType.system));
      expect(MCPNotification.fromJson({'id': '1', 'title': 'T', 'type': 'inapp'}).type, 
             equals(NotificationType.inApp));
      expect(MCPNotification.fromJson({'id': '1', 'title': 'T', 'type': 'in_app'}).type, 
             equals(NotificationType.inApp));
      expect(MCPNotification.fromJson({'id': '1', 'title': 'T'}).type, 
             equals(NotificationType.local));
    });

    test('should parse notification importance correctly', () {
      expect(MCPNotification.fromJson({'id': '1', 'title': 'T', 'priority': 'low'}).priority, 
             equals(NotificationImportance.low));
      expect(MCPNotification.fromJson({'id': '1', 'title': 'T', 'priority': 'high'}).priority, 
             equals(NotificationImportance.high));
      expect(MCPNotification.fromJson({'id': '1', 'title': 'T', 'priority': 'max'}).priority, 
             equals(NotificationImportance.max));
      expect(MCPNotification.fromJson({'id': '1', 'title': 'T'}).priority, 
             equals(NotificationImportance.defaultImportance));
    });
  });
}