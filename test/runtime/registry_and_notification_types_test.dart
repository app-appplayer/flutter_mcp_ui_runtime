// `WidgetRegistry`'s status report, and the notification value types.
//
// The status report is what tells a host which widget types its runtime can
// actually build — a document referencing a type nobody registered renders an
// error card, and this is the only place that gap is visible before it
// happens. The notification types are equality and JSON: a channel that never
// compares equal is a duplicate every time it is re-declared.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/notifications/notification_types.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/widgets/widget_factory.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WidgetRegistry status', () {
    test('an empty registry reports everything as missing', () {
      final registry = WidgetRegistry();
      final status = registry.getRegistrationStatus();

      expect(status['totalRegistered'], 0);
      expect(status['totalExpected'], greaterThan(0));
      expect(status['totalMissing'], status['totalExpected']);
      expect(status['percentage'], 0);
      expect(status['missingTypes'], isNotEmpty,
          reason: 'the list is what a host reads to know which documents it '
              'cannot render yet');
    });

    test('the default registration covers the declared catalogue', () {
      final registry = WidgetRegistry();
      DefaultWidgets.registerAll(registry);
      final status = registry.getRegistrationStatus();

      expect(status['missingTypes'], <String>['use'],
          reason: 'a type in the catalogue with no factory is a document that '
              'renders an error card where a widget should be. `use` is the '
              'one exception: it needs a template registry, so it is '
              'registered separately by `registerTemplateWidgets`');
      expect(status['percentage'], greaterThanOrEqualTo(100),
          reason: 'the registry also carries the alias spellings (§17.3), so '
              'it holds more names than the catalogue counts');

      final byCategory =
          status['byCategory'] as Map<String, Map<String, dynamic>>;
      expect(byCategory, isNotEmpty);
      for (final entry in byCategory.entries) {
        expect(
            (entry.value['missing'] as List)
                .where((t) => t != 'use'),
            isEmpty,
            reason: entry.key);
      }
    });

    test('printing the status is safe on a partial registry', () {
      final registry = WidgetRegistry();
      registry.register('text', _StubFactory());

      // No assertion beyond the absence of a crash: the report goes to the
      // logger, which is where a host looks when a document will not render.
      registry.printRegistrationStatus();

      expect(registry.hasFactory('text'), isTrue);
      expect(registry.hasFactory('nonesuch'), isFalse,
          reason: '`hasFactory` is the design-doc spelling of `has`; a host '
              'checking through it must get the same answer');
    });

    test('printing a complete registry is safe too', () {
      final registry = WidgetRegistry();
      DefaultWidgets.registerAll(registry);

      registry.printRegistrationStatus();

      expect(registry.registeredTypes, isNotEmpty);
    });

    test('unregistering removes it from the categories as well', () {
      final registry = WidgetRegistry();
      DefaultWidgets.registerAll(registry);
      expect(registry.has('text'), isTrue);

      registry.unregister('text');

      expect(registry.has('text'), isFalse);
      expect(registry.getTypesByCategory('display'), isNot(contains('text')),
          reason: 'a type left in its category is still advertised by the '
              'status report after the factory is gone');
    });

    test('clearing empties both maps', () {
      final registry = WidgetRegistry();
      DefaultWidgets.registerAll(registry);

      registry.clear();

      expect(registry.registeredTypes, isEmpty);
      expect(registry.getTypesByCategory('display'), isEmpty);
    });
  });

  group('NotificationChannel', () {
    test('two channels with the same id are the same channel', () {
      const a = NotificationChannel(id: 'alerts', name: 'Alerts');
      const b = NotificationChannel(id: 'alerts', name: 'Renamed');
      const other = NotificationChannel(id: 'updates', name: 'Updates');

      expect(a, b,
          reason: 'the id is the identity; comparing the name would make a '
              'renamed channel a second one, and the user would see two');
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(other));
      expect(a, same(a));
      expect(a.toString(), contains('alerts'));
    });
  });

  group('NotificationAction', () {
    test('two actions with the same id are the same action', () {
      const a = NotificationAction(id: 'open', title: 'Open');
      const b = NotificationAction(id: 'open', title: 'View');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const NotificationAction(id: 'dismiss', title: 'X')));
      expect(a.toString(), contains('open'));
    });
  });

  group('MCPNotification', () {
    test('the scheduling fields survive the round trip', () {
      final json = <String, dynamic>{
        'id': 'n1',
        'title': 'Job ready',
        'body': 'Tap to open',
        'scheduledTime': '2026-03-15T09:30:00.000Z',
        'repeatInterval': 3600000,
        'timeoutAfter': 5000,
        'progress': 3,
        'maxProgress': 10,
        'indeterminate': true,
        'ongoing': true,
        'autoCancel': false,
      };

      final notification = MCPNotification.fromJson(json);

      expect(notification.scheduledTime, DateTime.utc(2026, 3, 15, 9, 30));
      expect(notification.repeatInterval, const Duration(hours: 1),
          reason: 'the interval arrives as milliseconds and is used as a '
              'Duration; reading it as seconds would repeat a reminder a '
              'thousand times too often');
      expect(notification.timeoutAfter, const Duration(seconds: 5));
      expect(notification.progress, 3);
      expect(notification.ongoing, isTrue);
      expect(notification.autoCancel, isFalse);
    });

    test('the defaults are what an ordinary notification gets', () {
      final notification =
          MCPNotification.fromJson(<String, dynamic>{'id': 'n1', 'title': 'X'});

      expect(notification.type, NotificationType.local);
      expect(notification.channelId, 'general');
      expect(notification.autoCancel, isTrue);
      expect(notification.indeterminate, isFalse);
      expect(notification.scheduledTime, isNull);
    });

    test('two notifications with the same id are the same one', () {
      const a = MCPNotification(id: 'n1', title: 'Job ready');
      const b = MCPNotification(id: 'n1', title: 'Renamed');

      expect(a, b,
          reason: 'the id is what a dismissal names; comparing the title '
              'would leave a re-titled notification undismissable');
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const MCPNotification(id: 'n2', title: 'X')));
      expect(a.toString(), contains('n1'));
    });
  });
}

/// The registry only stores factories; nothing here builds one.
class _StubFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) =>
      const SizedBox.shrink();
}
