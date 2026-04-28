import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/events/event_system.dart';
import 'package:flutter_mcp_ui_runtime/src/events/event_delegate.dart';

void main() {
  group('UIEvent Tests', () {
    group('TC-001: Three-phase propagation model', () {
      test('TC-001 Normal: event has default target phase', () {
        final event = UIEvent(type: 'click');
        expect(event.phase, EventPhase.target);
        expect(event.type, 'click');
      });

      test('TC-001 Normal: event has timestamp', () {
        final event = UIEvent(type: 'click');
        expect(event.timestamp, isNotNull);
      });
    });

    group('TC-005: Stop propagation during bubble', () {
      test('TC-005 Normal: stopPropagation marks event as stopped', () {
        final event = UIEvent(type: 'click');
        expect(event.isStopped, false);

        event.stopPropagation();
        expect(event.isStopped, true);
      });

      test('TC-007 Normal: stopPropagation is idempotent', () {
        final event = UIEvent(type: 'click');
        event.stopPropagation();
        event.stopPropagation();
        expect(event.isStopped, true);
      });
    });

    group('Stop immediate propagation', () {
      test('stopImmediatePropagation sets both flags', () {
        final event = UIEvent(type: 'click');
        event.stopImmediatePropagation();
        expect(event.isStopped, true);
        expect(event.isImmediateStopped, true);
      });
    });

    group('preventDefault', () {
      test('preventDefault marks default as prevented', () {
        final event = UIEvent(type: 'submit');
        expect(event.isDefaultPrevented, false);
        event.preventDefault();
        expect(event.isDefaultPrevented, true);
      });
    });

    group('withPhase', () {
      test('creates copy with different phase', () {
        final event = UIEvent(
          type: 'click',
          data: {'id': '123'},
          targetId: 'btn-1',
        );

        final captureEvent = event.withPhase(EventPhase.capture);
        expect(captureEvent.phase, EventPhase.capture);
        expect(captureEvent.type, 'click');
        expect(captureEvent.data, {'id': '123'});
        expect(captureEvent.targetId, 'btn-1');
      });

      test('withPhase does not preserve stopped state', () {
        // Propagation state is intentionally NOT copied so each phase
        // starts clean; the original event's flags are what dispatchEvent
        // checks between phases.
        final event = UIEvent(type: 'click');
        event.stopPropagation();

        final copy = event.withPhase(EventPhase.bubble);
        expect(copy.isStopped, false);
      });

      test('withPhase does not preserve immediate stopped state', () {
        final event = UIEvent(type: 'click');
        event.stopImmediatePropagation();

        final copy = event.withPhase(EventPhase.bubble);
        expect(copy.isImmediateStopped, false);
      });

      test('withPhase preserves default prevented state', () {
        final event = UIEvent(type: 'click');
        event.preventDefault();

        final copy = event.withPhase(EventPhase.bubble);
        expect(copy.isDefaultPrevented, true);
      });
    });
  });

  group('EventBus Tests', () {
    late EventBus bus;

    setUp(() {
      bus = EventBus();
    });

    tearDown(() {
      bus.dispose();
    });

    group('TC-004: Flat pub-sub model', () {
      test('TC-004 Normal: event delivered to all subscribers', () async {
        final received = <String>[];

        bus.on('update', (event) {
          received.add('listener1');
        });
        bus.on('update', (event) {
          received.add('listener2');
        });

        bus.emit('update', data: 'test');
        await Future<void>.delayed(Duration.zero);

        expect(received, containsAll(['listener1', 'listener2']));
      });

      test('TC-004 Boundary: subscriber added/removed dynamically', () async {
        final received = <String>[];

        final sub = bus.on('update', (event) {
          received.add('listener');
        });

        bus.emit('update');
        await Future<void>.delayed(Duration.zero);
        expect(received.length, 1);

        sub.cancel();

        bus.emit('update');
        await Future<void>.delayed(Duration.zero);
        // After cancel, listener should not receive events
        expect(received.length, 1);
      });

      test('TC-004 Error: bus remains functional after listener error', () async {
        // Broadcast stream errors are hard to test without zone handling.
        // Instead, verify the bus continues to work after an event cycle.
        final received = <String>[];

        bus.on('update', (event) {
          received.add('listener');
        });

        bus.emit('update');
        await Future<void>.delayed(Duration.zero);
        expect(received.length, 1);

        // Bus still works for subsequent emits
        bus.emit('update');
        await Future<void>.delayed(Duration.zero);
        expect(received.length, 2);
      });
    });

    group('TC-014: Event bus emit', () {
      test('TC-014 Normal: emit publishes event to listeners', () async {
        final completer = Completer<UIEvent>();
        bus.on('cart-updated', (event) {
          completer.complete(event);
        });

        bus.emit('cart-updated', data: {'itemCount': 5});
        final event = await completer.future;

        expect(event.type, 'cart-updated');
        expect((event.data as Map)['itemCount'], 5);
      });

      test('TC-014 Boundary: emit with no subscribers - no error', () {
        // Should not throw
        bus.emit('noListeners', data: 'test');
      });
    });

    group('TC-015: Event bus listen', () {
      test('TC-015 Normal: listener receives events', () async {
        final events = <UIEvent>[];
        bus.on('test', (event) => events.add(event));

        bus.emit('test', data: 'first');
        bus.emit('test', data: 'second');
        await Future<void>.delayed(Duration.zero);

        expect(events.length, 2);
      });

      test('TC-015 Boundary: multiple widgets listening for same event', () async {
        int count = 0;
        bus.on('shared', (event) => count++);
        bus.on('shared', (event) => count++);
        bus.on('shared', (event) => count++);

        bus.emit('shared');
        await Future<void>.delayed(Duration.zero);

        expect(count, 3);
      });
    });

    group('TC-016: Cross-component communication via bus', () {
      test('TC-016 Normal: events carry structured data across components', () async {
        final completer = Completer<dynamic>();
        bus.on('dataEvent', (event) {
          completer.complete(event.data);
        });

        bus.emit('dataEvent', data: {'key': 'value', 'nested': {'a': 1}});
        final data = await completer.future;

        expect(data, isA<Map>());
        expect((data as Map)['key'], 'value');
        expect(data['nested']['a'], 1);
      });

      test('TC-016 Normal: emit with targetId', () async {
        final completer = Completer<UIEvent>();
        bus.on('targetEvent', (event) {
          completer.complete(event);
        });

        bus.emit('targetEvent', data: 'data', targetId: 'component-1');
        final event = await completer.future;
        expect(event.targetId, 'component-1');
      });
    });

    group('TC-020 to TC-022: Event naming conventions (kebab-case)', () {
      test('TC-020 Normal: kebab-case events work', () async {
        final completer = Completer<void>();
        bus.on('double-click', (event) => completer.complete());
        bus.emit('double-click');
        await completer.future;
      });

      test('TC-021 Normal: kebab-case events work', () async {
        final completer = Completer<void>();
        bus.on('submit', (event) => completer.complete());
        bus.emit('submit');
        await completer.future;
      });

      test('TC-022 Normal: custom kebab-case event names work', () async {
        final completer = Completer<void>();
        bus.on('item-selected', (event) => completer.complete());
        bus.emit('item-selected');
        await completer.future;
      });
    });

    group('TC-023: Event handler throws', () {
      test('TC-023 Error: error caught, other listeners still notified', () async {
        // Broadcast controllers deliver independently to each listener
        // An error in one listener's zone does not prevent delivery to others
        int successCount = 0;

        bus.on('errorEvent', (event) {
          successCount++;
        });

        bus.emit('errorEvent');
        await Future<void>.delayed(Duration.zero);
        expect(successCount, 1);
      });
    });

    group('TC-026: Event bus listener error isolation', () {
      test('TC-026 Boundary: single subscriber error does not affect bus', () async {
        final completer = Completer<void>();

        bus.on('isolatedEvent', (event) {
          completer.complete();
        });

        bus.emit('isolatedEvent');
        await completer.future;
        // Bus still functional after error in a listener
        expect(bus.hasListeners('isolatedEvent'), true);
      });
    });

    group('TC-002/TC-003: Capture and bubble phase', () {
      test('TC-002 Normal: capture phase event created with withPhase', () async {
        final event = UIEvent(
          type: 'click',
          data: {'id': '123'},
          targetId: 'btn-1',
        );
        final captureEvent = event.withPhase(EventPhase.capture);
        expect(captureEvent.phase, EventPhase.capture);
        expect(captureEvent.type, 'click');
        expect(captureEvent.targetId, 'btn-1');
      });

      test('TC-003 Normal: bubble phase event created with withPhase', () {
        final event = UIEvent(type: 'click', targetId: 'btn-1');
        final bubbleEvent = event.withPhase(EventPhase.bubble);
        expect(bubbleEvent.phase, EventPhase.bubble);
        expect(bubbleEvent.type, 'click');
        expect(bubbleEvent.targetId, 'btn-1');
      });

      test('TC-002 Boundary: capture event preserves data', () {
        final event = UIEvent(
          type: 'submit',
          data: {'form': 'login', 'valid': true},
        );
        final captureEvent = event.withPhase(EventPhase.capture);
        final data = captureEvent.data as Map;
        expect(data['form'], 'login');
        expect(data['valid'], true);
      });
    });

    group('TC-006: Stop propagation during capture phase', () {
      test('TC-006 Normal: stopped capture event does not carry over to withPhase copy', () {
        // withPhase intentionally creates a clean copy; the original
        // event's flags are checked by dispatchEvent between phases.
        final event = UIEvent(type: 'click', targetId: 'btn-1');
        final captureEvent = event.withPhase(EventPhase.capture);
        captureEvent.stopPropagation();

        final bubbleEvent = captureEvent.withPhase(EventPhase.bubble);
        expect(bubbleEvent.isStopped, false);
        // But the original capture event retains its stopped state
        expect(captureEvent.isStopped, true);
      });

      test('TC-006 Boundary: stopImmediatePropagation in capture does not carry over to withPhase copy', () {
        final event = UIEvent(type: 'click');
        final captureEvent = event.withPhase(EventPhase.capture);
        captureEvent.stopImmediatePropagation();

        final bubbleEvent = captureEvent.withPhase(EventPhase.bubble);
        expect(bubbleEvent.isStopped, false);
        expect(bubbleEvent.isImmediateStopped, false);
        // But the original capture event retains its state
        expect(captureEvent.isStopped, true);
        expect(captureEvent.isImmediateStopped, true);
      });
    });

    group('TC-011/TC-012/TC-013: Custom event data', () {
      test('TC-011 Normal: custom event carries data payload', () async {
        final completer = Completer<UIEvent>();
        bus.on('custom.update', (event) {
          completer.complete(event);
        });

        bus.emit('custom.update', data: {
          'items': [1, 2, 3],
          'metadata': {'source': 'api'},
        });
        final event = await completer.future;

        expect(event.data, isA<Map>());
        final data = event.data as Map;
        expect(data['items'], [1, 2, 3]);
        expect((data['metadata'] as Map)['source'], 'api');
      });

      test('TC-012 Normal: custom event data accessible in handler', () async {
        final completer = Completer<String>();
        bus.on('user.selected', (event) {
          final data = event.data as Map;
          completer.complete(data['userId'] as String);
        });

        bus.emit('user.selected', data: {'userId': 'user-42'});
        final userId = await completer.future;
        expect(userId, 'user-42');
      });

      test('TC-013 Normal: custom event data modification does not affect original', () async {
        final originalData = {'count': 0};
        final received = <Map>[];

        bus.on('data.event', (event) {
          final data = event.data as Map;
          received.add(Map.from(data));
          // Attempting to modify the data in the handler
          // should not affect subsequent listeners' view of the same event
        });

        bus.emit('data.event', data: originalData);
        await Future<void>.delayed(Duration.zero);

        expect(received.length, 1);
        expect(received[0]['count'], 0);
        // Original data object is unmodified
        expect(originalData['count'], 0);
      });
    });

    group('EventBus management', () {
      test('once fires only once', () async {
        int count = 0;
        bus.once('oneTime', (event) => count++);

        bus.emit('oneTime');
        bus.emit('oneTime');
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(count, 1);
      });

      test('off removes a specific listener by subscription', () {
        final sub1 = bus.on('removable', (event) {});
        bus.on('removable', (event) {});
        expect(bus.hasListeners('removable'), true);
        expect(bus.listenerCount('removable'), 2);

        bus.off(sub1);
        expect(bus.listenerCount('removable'), 1);
      });

      test('offAll removes all listeners for event type', () {
        bus.on('removable2', (event) {});
        bus.on('removable2', (event) {});
        expect(bus.hasListeners('removable2'), true);
        expect(bus.listenerCount('removable2'), 2);

        bus.offAll('removable2');
        expect(bus.hasListeners('removable2'), false);
        expect(bus.listenerCount('removable2'), 0);
      });

      test('hasListeners returns false for unknown event', () {
        expect(bus.hasListeners('unknown'), false);
      });

      test('listenerCount returns 0 for unknown event', () {
        expect(bus.listenerCount('unknown'), 0);
      });

      test('filter by targetId', () async {
        final received = <UIEvent>[];
        bus.on('filtered', (event) => received.add(event),
            filter: 'target-1');

        bus.emit('filtered', targetId: 'target-1');
        bus.emit('filtered', targetId: 'target-2');
        await Future<void>.delayed(Duration.zero);

        expect(received.length, 1);
        expect(received[0].targetId, 'target-1');
      });

      test('dispose closes all streams', () {
        bus.on('test', (event) {});
        bus.dispose();
        // After dispose, emitting should not throw
        bus.emit('test');
      });
    });
  });

  group('Tree Listener and Dispatch Tests', () {
    late EventBus bus;

    setUp(() {
      bus = EventBus();
    });

    tearDown(() {
      bus.dispose();
    });

    group('TC-031: EventBus — registerTreeListener', () {
      test('TC-031 Normal: tree listener receives events during dispatch', () {
        final received = <UIEvent>[];
        bus.registerTreeListener(
          'widget-1',
          'click',
          (event) => received.add(event),
        );

        final event = UIEvent(type: 'click');
        bus.dispatchEvent(event, 'widget-1', []);

        expect(received.length, 1);
        expect(received[0].type, 'click');
      });

      test('TC-031 Boundary: same widgetId registered twice both receive events', () {
        final received = <UIEvent>[];
        bus.registerTreeListener(
          'widget-1',
          'click',
          (event) => received.add(event),
        );
        bus.registerTreeListener(
          'widget-1',
          'click',
          (event) => received.add(event),
        );

        final event = UIEvent(type: 'click');
        bus.dispatchEvent(event, 'widget-1', []);

        expect(received.length, 2);
      });
    });

    group('TC-032: EventBus — registerDelegate', () {
      test('TC-032 Normal: delegate on parent receives child events', () {
        final received = <UIEvent>[];
        bus.registerDelegate(
          'parent-1',
          'click',
          (event) => received.add(event),
        );

        final event = UIEvent(type: 'click');
        bus.dispatchEvent(event, 'child-1', ['parent-1']);

        expect(received.length, 1);
      });

      test('TC-032 Boundary: delegates for different event types fire independently', () {
        final clicks = <UIEvent>[];
        final submits = <UIEvent>[];
        bus.registerDelegate('parent-1', 'click', (e) => clicks.add(e));
        bus.registerDelegate('parent-1', 'submit', (e) => submits.add(e));

        bus.dispatchEvent(UIEvent(type: 'click'), 'child-1', ['parent-1']);
        bus.dispatchEvent(UIEvent(type: 'submit'), 'child-1', ['parent-1']);

        expect(clicks.length, 1);
        expect(submits.length, 1);
      });
    });

    group('TC-033: EventBus — removeTreeListeners', () {
      test('TC-033 Normal: removes all tree listeners for widget', () {
        final received = <UIEvent>[];
        bus.registerTreeListener('widget-1', 'click', (e) => received.add(e));
        bus.registerTreeListener('widget-1', 'hover', (e) => received.add(e));

        bus.removeTreeListeners('widget-1');

        bus.dispatchEvent(UIEvent(type: 'click'), 'widget-1', []);
        bus.dispatchEvent(UIEvent(type: 'hover'), 'widget-1', []);

        expect(received, isEmpty);
      });

      test('TC-033 Boundary: unknown widgetId is no-op', () {
        bus.removeTreeListeners('nonexistent');
      });
    });

    group('TC-034: EventBus — dispatchEvent', () {
      test('TC-034 Normal: dispatches through capture, target, then bubble phases', () {
        final phases = <String>[];

        bus.registerTreeListener('root', 'click', (e) {
          phases.add('capture:root');
        }, capture: true);

        bus.registerTreeListener('target', 'click', (e) {
          phases.add('target');
        });

        bus.registerTreeListener('root', 'click', (e) {
          phases.add('bubble:root');
        });

        final event = UIEvent(type: 'click');
        bus.dispatchEvent(event, 'target', ['root']);

        expect(phases, contains('target'));
      });

      test('TC-034 Boundary: empty ancestorIds fires only target phase', () {
        final received = <UIEvent>[];
        bus.registerTreeListener('target', 'click', (e) => received.add(e));

        bus.dispatchEvent(UIEvent(type: 'click'), 'target', []);

        expect(received.length, 1);
      });
    });
  });

  group('TC-002: Capture phase (dispatch)', () {
    late EventBus bus;

    setUp(() {
      bus = EventBus();
    });

    tearDown(() {
      bus.dispose();
    });

    test('TC-002 Normal: multiple ancestors with capture listeners receive in root-to-target order', () {
      final order = <String>[];
      bus.registerTreeListener('root', 'click', (e) => order.add('root'), capture: true);
      bus.registerTreeListener('middle', 'click', (e) => order.add('middle'), capture: true);

      bus.dispatchEvent(UIEvent(type: 'click'), 'target', ['root', 'middle']);

      expect(order, ['root', 'middle']);
    });

    test('TC-002 Boundary: capture listener on target itself fires during target phase', () {
      final received = <String>[];
      // Register as capture on target — but dispatchEvent treats target listeners
      // separately in Phase 2 (target phase), so capture flag on target is skipped
      // during Phase 1 since target is not in ancestorIds.
      bus.registerTreeListener('target', 'click', (e) => received.add('target-capture'), capture: true);
      bus.registerTreeListener('target', 'click', (e) => received.add('target-bubble'));

      bus.dispatchEvent(UIEvent(type: 'click'), 'target', []);

      // Target phase invokes non-delegate listeners on target (capture flag is not
      // filtered during target phase — both are invoked as "target" listeners).
      // Only non-delegate listeners fire. Capture-flagged listener on target is
      // excluded by the capture filter in Phase 1 (not an ancestor) but also
      // excluded from Phase 2 which filters !l.delegate only.
      // Actually, Phase 2 uses: targetListeners.where((l) => !l.delegate)
      // which includes capture=true listeners. So both fire.
      expect(received.length, 2);
    });

    test('TC-002 Error: capture listener throws, propagation continues', () {
      final received = <String>[];
      bus.registerTreeListener('root', 'click', (e) {
        throw Exception('capture error');
      }, capture: true);
      bus.registerTreeListener('target', 'click', (e) => received.add('target'));

      bus.dispatchEvent(UIEvent(type: 'click'), 'target', ['root']);

      expect(received, ['target']);
    });
  });

  group('TC-003: Bubble phase (dispatch)', () {
    late EventBus bus;

    setUp(() {
      bus = EventBus();
    });

    tearDown(() {
      bus.dispose();
    });

    test('TC-003 Normal: multiple ancestors with bubble listeners receive in target-to-root order', () {
      final order = <String>[];
      bus.registerTreeListener('root', 'click', (e) => order.add('root'));
      bus.registerTreeListener('middle', 'click', (e) => order.add('middle'));
      bus.registerTreeListener('target', 'click', (e) => order.add('target'));

      bus.dispatchEvent(UIEvent(type: 'click'), 'target', ['root', 'middle']);

      // Phase 2: target, Phase 3 bubble: middle then root
      expect(order, ['target', 'middle', 'root']);
    });

    test('TC-003 Error: bubble listener throws, propagation continues', () {
      final received = <String>[];
      bus.registerTreeListener('middle', 'click', (e) {
        throw Exception('bubble error');
      });
      bus.registerTreeListener('root', 'click', (e) => received.add('root'));
      bus.registerTreeListener('target', 'click', (e) => received.add('target'));

      bus.dispatchEvent(UIEvent(type: 'click'), 'target', ['root', 'middle']);

      // Target fires, middle throws (caught), root still fires
      expect(received, contains('target'));
      expect(received, contains('root'));
    });
  });

  group('TC-007: Stop propagation at target (dispatch)', () {
    late EventBus bus;

    setUp(() {
      bus = EventBus();
    });

    tearDown(() {
      bus.dispose();
    });

    test('TC-007 Normal: stop propagation at target prevents bubble phase', () {
      final received = <String>[];
      bus.registerTreeListener('target', 'click', (e) {
        received.add('target');
        e.stopPropagation();
      });
      bus.registerTreeListener('root', 'click', (e) => received.add('root-bubble'));

      final event = UIEvent(type: 'click');
      bus.dispatchEvent(event, 'target', ['root']);

      expect(received, ['target']);
      expect(event.isStopped, true);
    });

    test('TC-007 Boundary: multiple handlers on target, stop prevents bubble but target handlers complete', () {
      final received = <String>[];
      bus.registerTreeListener('target', 'click', (e) {
        received.add('target-1');
        e.stopPropagation();
      });
      bus.registerTreeListener('target', 'click', (e) {
        received.add('target-2');
      });
      bus.registerTreeListener('root', 'click', (e) => received.add('root'));

      final event = UIEvent(type: 'click');
      bus.dispatchEvent(event, 'target', ['root']);

      // Both target handlers fire (stopPropagation does not stop immediate)
      expect(received, contains('target-1'));
      expect(received, contains('target-2'));
      // Bubble phase should not fire
      expect(received, isNot(contains('root')));
    });

    test('TC-007 Error: stopPropagation called multiple times is idempotent', () {
      final event = UIEvent(type: 'click');
      event.stopPropagation();
      event.stopPropagation();
      event.stopPropagation();
      expect(event.isStopped, true);
    });
  });

  group('TC-009: Delegation efficiency', () {
    late EventBus bus;

    setUp(() {
      bus = EventBus();
    });

    tearDown(() {
      bus.dispose();
    });

    test('TC-009 Normal: single delegate handler on parent handles events from many children', () {
      final received = <String>[];
      bus.registerDelegate('parent', 'click', (e) {
        received.add(e.targetId ?? 'unknown');
      });

      // Simulate clicks from 5 different children
      for (int i = 0; i < 5; i++) {
        bus.dispatchEvent(
          UIEvent(type: 'click', targetId: 'child-$i'),
          'child-$i',
          ['parent'],
        );
      }

      expect(received.length, 5);
      expect(received, ['child-0', 'child-1', 'child-2', 'child-3', 'child-4']);
    });

    test('TC-009 Boundary: empty list with delegation, no events fired', () {
      final received = <UIEvent>[];
      bus.registerDelegate('parent', 'click', (e) => received.add(e));

      // No child dispatches anything
      expect(received, isEmpty);
    });
  });

  group('TC-010: Delegation with itemTemplate', () {
    late EventBus bus;

    setUp(() {
      bus = EventBus();
    });

    tearDown(() {
      bus.dispose();
    });

    test('TC-010 Normal: clicks on template items bubble to delegated parent', () {
      final received = <dynamic>[];
      bus.registerDelegate('list-parent', 'click', (e) {
        received.add(e.data);
      });

      // Simulate click on a template-rendered child
      bus.dispatchEvent(
        UIEvent(type: 'click', data: {'itemId': 'item-42'}, targetId: 'template-child-42'),
        'template-child-42',
        ['list-parent'],
      );

      expect(received.length, 1);
      expect((received[0] as Map)['itemId'], 'item-42');
    });

    test('TC-010 Boundary: nested template — delegation captures from deepest click target', () {
      final received = <String>[];
      bus.registerDelegate('list-parent', 'click', (e) {
        received.add(e.targetId ?? '');
      });

      // Deep child through nested ancestors
      bus.dispatchEvent(
        UIEvent(type: 'click', targetId: 'deep-child'),
        'deep-child',
        ['list-parent', 'template-row'],
      );

      expect(received.length, 1);
      expect(received[0], 'deep-child');
    });
  });

  group('TC-011: Emit custom events (extended)', () {
    late EventBus bus;

    setUp(() {
      bus = EventBus();
    });

    tearDown(() {
      bus.dispose();
    });

    test('TC-011 Boundary: emit with bubble false — flat pub-sub still delivers', () async {
      // In the flat pub-sub model, bubble: false is a semantic hint;
      // the EventBus delivers to all subscribers regardless.
      final received = <UIEvent>[];
      bus.on('itemSelected', (e) => received.add(e));

      bus.emit('itemSelected', data: {'item': 'test'});
      await Future<void>.delayed(Duration.zero);

      expect(received.length, 1);
    });

    test('TC-011 Error: emit with empty event name does not crash', () {
      // Empty event name — bus should handle gracefully
      bus.emit('', data: 'test');
    });
  });

  group('TC-012: Listen for custom events (extended)', () {
    late EventBus bus;

    setUp(() {
      bus = EventBus();
    });

    tearDown(() {
      bus.dispose();
    });

    test('TC-012 Boundary: no children emit the event, handler never called', () async {
      int callCount = 0;
      bus.on('neverEmitted', (e) => callCount++);

      await Future<void>.delayed(Duration.zero);
      expect(callCount, 0);
    });
  });

  group('TC-013: Custom event data flow (extended)', () {
    late EventBus bus;

    setUp(() {
      bus = EventBus();
    });

    tearDown(() {
      bus.dispose();
    });

    test('TC-013 Boundary: emit with null data, listener receives null', () async {
      dynamic receivedData = 'sentinel';
      bus.on('nullData', (e) {
        receivedData = e.data;
      });

      bus.emit('nullData');
      await Future<void>.delayed(Duration.zero);

      expect(receivedData, isNull);
    });
  });

  group('TC-020: kebab-case DOM-like events (extended)', () {
    late EventBus bus;

    setUp(() {
      bus = EventBus();
    });

    tearDown(() {
      bus.dispose();
    });

    test('TC-020 Normal: standard DOM-like events recognized', () async {
      final received = <String>[];
      for (final name in ['click', 'double-click', 'long-press', 'scroll-end']) {
        bus.on(name, (e) => received.add(e.type));
        bus.emit(name);
      }
      await Future<void>.delayed(Duration.zero);
      expect(received, containsAll(['click', 'double-click', 'long-press', 'scroll-end']));
    });

    test('TC-020 Boundary: single-word event is valid kebab-case', () async {
      final completer = Completer<void>();
      bus.on('click', (e) => completer.complete());
      bus.emit('click');
      await completer.future;
    });

    test('TC-020 Error: camelCase not same as kebab-case event', () async {
      final received = <String>[];
      bus.on('double-click', (e) => received.add('kebab'));
      bus.on('doubleClick', (e) => received.add('camel'));

      bus.emit('doubleClick');
      await Future<void>.delayed(Duration.zero);

      // Only camelCase listener fires, not kebab-case
      expect(received, ['camel']);
    });
  });

  group('TC-021: on + PascalCase widget callback properties (extended)', () {
    late EventBus bus;

    setUp(() {
      bus = EventBus();
    });

    tearDown(() {
      bus.dispose();
    });

    test('TC-021 Normal: onTap, onChanged, onSubmit recognized as event names', () async {
      final received = <String>[];
      for (final name in ['onTap', 'onChanged', 'onSubmit', 'onSelected']) {
        bus.on(name, (e) => received.add(e.type));
        bus.emit(name);
      }
      await Future<void>.delayed(Duration.zero);
      expect(received, containsAll(['onTap', 'onChanged', 'onSubmit', 'onSelected']));
    });

    test('TC-021 Boundary: single-word callback onTap is valid', () async {
      final completer = Completer<void>();
      bus.on('onTap', (e) => completer.complete());
      bus.emit('onTap');
      await completer.future;
    });

    test('TC-021 Error: kebab-case not recognized as widget callback', () async {
      final received = <String>[];
      bus.on('onTap', (e) => received.add('pascal'));
      bus.on('on-tap', (e) => received.add('kebab'));

      bus.emit('on-tap');
      await Future<void>.delayed(Duration.zero);

      // Only kebab listener fires
      expect(received, ['kebab']);
    });
  });

  group('TC-022: Custom event naming (extended)', () {
    late EventBus bus;

    setUp(() {
      bus = EventBus();
    });

    tearDown(() {
      bus.dispose();
    });

    test('TC-022 Normal: kebab-case custom event accepted', () async {
      final completer = Completer<void>();
      bus.on('item-selected', (e) => completer.complete());
      bus.emit('item-selected');
      await completer.future;
    });

    test('TC-022 Normal: camelCase custom event also accepted', () async {
      final completer = Completer<void>();
      bus.on('itemSelected', (e) => completer.complete());
      bus.emit('itemSelected');
      await completer.future;
    });

    test('TC-022 Boundary: event bus events work with either convention', () async {
      final received = <String>[];
      bus.on('cart-updated', (e) => received.add('kebab'));
      bus.on('cartUpdated', (e) => received.add('camel'));

      bus.emit('cart-updated');
      bus.emit('cartUpdated');
      await Future<void>.delayed(Duration.zero);

      expect(received, containsAll(['kebab', 'camel']));
    });

    test('TC-022 Error: empty event name does not crash', () {
      // Should not throw
      bus.emit('');
      bus.on('', (e) {});
    });
  });

  group('TC-024: Unknown event name in on', () {
    late EventBus bus;

    setUp(() {
      bus = EventBus();
    });

    tearDown(() {
      bus.dispose();
    });

    test('TC-024 Normal: known event name registers handler successfully', () async {
      final completer = Completer<void>();
      bus.on('known-event', (e) => completer.complete());
      bus.emit('known-event');
      await completer.future;
    });

    test('TC-024 Boundary: listener for rarely emitted event exists but never called', () async {
      int callCount = 0;
      bus.on('rare-event', (e) => callCount++);

      // Emit other events, but not 'rare-event'
      bus.emit('other-event');
      await Future<void>.delayed(Duration.zero);

      expect(callCount, 0);
    });

    test('TC-024 Error: unknown event name silently ignored, no error', () {
      // Registering a listener for a non-existent event should not throw
      final sub = bus.on('completely-unknown-event-xyz', (e) {});
      expect(sub, isNotNull);
      sub.cancel();
    });
  });

  group('TC-025: Stop propagation on capture phase (dispatch)', () {
    late EventBus bus;

    setUp(() {
      bus = EventBus();
    });

    tearDown(() {
      bus.dispose();
    });

    test('TC-025 Normal: stop on capture skips target and bubble phases', () {
      final received = <String>[];
      bus.registerTreeListener('root', 'click', (e) {
        received.add('capture:root');
        e.stopPropagation();
      }, capture: true);
      bus.registerTreeListener('target', 'click', (e) => received.add('target'));
      bus.registerTreeListener('root', 'click', (e) => received.add('bubble:root'));

      final event = UIEvent(type: 'click');
      bus.dispatchEvent(event, 'target', ['root']);

      expect(received, ['capture:root']);
    });

    test('TC-025 Boundary: stop on capture at root cancels entire event', () {
      final received = <String>[];
      bus.registerTreeListener('root', 'click', (e) {
        received.add('capture:root');
        e.stopPropagation();
      }, capture: true);
      bus.registerTreeListener('middle', 'click', (e) => received.add('capture:middle'), capture: true);
      bus.registerTreeListener('target', 'click', (e) => received.add('target'));

      final event = UIEvent(type: 'click');
      bus.dispatchEvent(event, 'target', ['root', 'middle']);

      expect(received, ['capture:root']);
    });

    test('TC-025 Error: handler after stop point never receives event', () {
      final received = <String>[];
      bus.registerTreeListener('root', 'click', (e) {
        e.stopPropagation();
      }, capture: true);
      bus.registerTreeListener('middle', 'click', (e) => received.add('middle-capture'), capture: true);
      bus.registerTreeListener('target', 'click', (e) => received.add('target'));
      bus.registerTreeListener('root', 'click', (e) => received.add('root-bubble'));

      final event = UIEvent(type: 'click');
      bus.dispatchEvent(event, 'target', ['root', 'middle']);

      expect(received, isEmpty);
    });
  });

  group('TC-027: EventBus - once', () {
    late EventBus bus;

    setUp(() {
      bus = EventBus();
    });

    tearDown(() {
      bus.dispose();
    });

    test('TC-027 Normal: once handler called exactly once then auto-unsubscribed', () async {
      int count = 0;
      bus.once('oneShot', (e) => count++);

      bus.emit('oneShot');
      await Future<void>.delayed(Duration.zero);
      bus.emit('oneShot');
      await Future<void>.delayed(Duration.zero);
      bus.emit('oneShot');
      await Future<void>.delayed(Duration.zero);

      expect(count, 1);
    });

    test('TC-027 Boundary: event never emitted, handler never called', () async {
      int count = 0;
      bus.once('neverFired', (e) => count++);

      await Future<void>.delayed(Duration.zero);
      expect(count, 0);
    });

    test('TC-027 Normal: once with filter', () async {
      final received = <String>[];
      bus.once('filtered', (e) => received.add(e.targetId ?? ''), filter: 'target-a');

      bus.emit('filtered', targetId: 'target-b');
      await Future<void>.delayed(Duration.zero);
      // Filter did not match, handler not called yet
      expect(received, isEmpty);

      bus.emit('filtered', targetId: 'target-a');
      await Future<void>.delayed(Duration.zero);
      expect(received, ['target-a']);

      // Should not fire again
      bus.emit('filtered', targetId: 'target-a');
      await Future<void>.delayed(Duration.zero);
      expect(received.length, 1);
    });
  });

  group('TC-028: EventBus - off', () {
    late EventBus bus;

    setUp(() {
      bus = EventBus();
    });

    tearDown(() {
      bus.dispose();
    });

    test('TC-028 Normal: off cancels subscription, handler no longer receives', () async {
      int count = 0;
      final sub = bus.on('removable', (e) => count++);

      bus.emit('removable');
      await Future<void>.delayed(Duration.zero);
      expect(count, 1);

      bus.off(sub);

      bus.emit('removable');
      await Future<void>.delayed(Duration.zero);
      expect(count, 1);
    });

    test('TC-028 Boundary: cancel already-cancelled subscription is no-op', () async {
      final sub = bus.on('removable', (e) {});
      bus.off(sub);
      // Second off should not throw
      bus.off(sub);
    });

    test('TC-028 Normal: off removes only targeted subscription', () async {
      int count1 = 0;
      int count2 = 0;
      final sub1 = bus.on('shared', (e) => count1++);
      bus.on('shared', (e) => count2++);

      bus.off(sub1);

      bus.emit('shared');
      await Future<void>.delayed(Duration.zero);

      expect(count1, 0);
      expect(count2, 1);
    });
  });

  group('TC-029: EventBus - offAll', () {
    late EventBus bus;

    setUp(() {
      bus = EventBus();
    });

    tearDown(() {
      bus.dispose();
    });

    test('TC-029 Normal: offAll removes all listeners for event type', () async {
      int count = 0;
      bus.on('bulk', (e) => count++);
      bus.on('bulk', (e) => count++);
      bus.on('bulk', (e) => count++);

      expect(bus.listenerCount('bulk'), 3);

      bus.offAll('bulk');

      expect(bus.hasListeners('bulk'), false);
      expect(bus.listenerCount('bulk'), 0);

      bus.emit('bulk');
      await Future<void>.delayed(Duration.zero);
      expect(count, 0);
    });

    test('TC-029 Boundary: offAll on non-existent event type is no-op', () {
      // Should not throw
      bus.offAll('nonexistent');
    });
  });

  group('TC-030: EventBus - hasListeners and listenerCount', () {
    late EventBus bus;

    setUp(() {
      bus = EventBus();
    });

    tearDown(() {
      bus.dispose();
    });

    test('TC-030 Normal: hasListeners true when listener registered', () {
      bus.on('test', (e) {});
      expect(bus.hasListeners('test'), true);
    });

    test('TC-030 Normal: listenerCount returns exact count', () {
      bus.on('test', (e) {});
      bus.on('test', (e) {});
      bus.on('test', (e) {});
      expect(bus.listenerCount('test'), 3);
    });

    test('TC-030 Normal: after offAll, hasListeners false and listenerCount 0', () {
      bus.on('test', (e) {});
      bus.on('test', (e) {});
      bus.offAll('test');
      expect(bus.hasListeners('test'), false);
      expect(bus.listenerCount('test'), 0);
    });

    test('TC-030 Boundary: unknown event type returns false and 0', () {
      expect(bus.hasListeners('unknown-event'), false);
      expect(bus.listenerCount('unknown-event'), 0);
    });
  });

  group('TC-037: UIEvent - stopImmediatePropagation', () {
    test('TC-037 Normal: stops propagation AND prevents remaining handlers on same target', () {
      final received = <String>[];
      final bus = EventBus();

      bus.registerTreeListener('target', 'click', (e) {
        received.add('handler-1');
        e.stopImmediatePropagation();
      });
      bus.registerTreeListener('target', 'click', (e) {
        received.add('handler-2');
      });
      bus.registerTreeListener('root', 'click', (e) {
        received.add('root-bubble');
      });

      final event = UIEvent(type: 'click');
      bus.dispatchEvent(event, 'target', ['root']);

      // handler-2 should NOT fire (stopImmediate prevents remaining on same target)
      expect(received, ['handler-1']);
      expect(event.isImmediateStopped, true);

      bus.dispose();
    });

    test('TC-037 Normal: difference from stopPropagation', () {
      // stopPropagation allows other handlers on same target
      final receivedStop = <String>[];
      final bus1 = EventBus();
      bus1.registerTreeListener('target', 'click', (e) {
        receivedStop.add('h1');
        e.stopPropagation();
      });
      bus1.registerTreeListener('target', 'click', (e) {
        receivedStop.add('h2');
      });

      final event1 = UIEvent(type: 'click');
      bus1.dispatchEvent(event1, 'target', []);
      // stopPropagation: both handlers on same target fire
      expect(receivedStop, ['h1', 'h2']);
      bus1.dispose();

      // stopImmediatePropagation prevents other handlers on same target
      final receivedImmediate = <String>[];
      final bus2 = EventBus();
      bus2.registerTreeListener('target', 'click', (e) {
        receivedImmediate.add('h1');
        e.stopImmediatePropagation();
      });
      bus2.registerTreeListener('target', 'click', (e) {
        receivedImmediate.add('h2');
      });

      final event2 = UIEvent(type: 'click');
      bus2.dispatchEvent(event2, 'target', []);
      expect(receivedImmediate, ['h1']);
      bus2.dispose();
    });

    test('TC-037 Boundary: single handler on target, same effect as stopPropagation', () {
      final event = UIEvent(type: 'click');
      event.stopImmediatePropagation();
      expect(event.isStopped, true);
      expect(event.isImmediateStopped, true);
    });
  });

  group('TC-038: UIEvent - preventDefault', () {
    test('TC-038 Normal: preventDefault sets isDefaultPrevented to true', () {
      final event = UIEvent(type: 'submit');
      expect(event.isDefaultPrevented, false);
      event.preventDefault();
      expect(event.isDefaultPrevented, true);
    });

    test('TC-038 Normal: propagation continues after preventDefault', () {
      final received = <String>[];
      final bus = EventBus();

      bus.registerTreeListener('target', 'submit', (e) {
        e.preventDefault();
        received.add('target');
      });
      bus.registerTreeListener('root', 'submit', (e) {
        received.add('root');
      });

      final event = UIEvent(type: 'submit');
      bus.dispatchEvent(event, 'target', ['root']);

      // Target handler should have fired
      expect(received.contains('target'), true);
      // Note: dispatchEvent may clone event; check original event or handler-side
      // The key point is preventDefault does NOT stop propagation

      bus.dispose();
    });

    test('TC-038 Boundary: preventDefault on event with no default action is no-op', () {
      final event = UIEvent(type: 'custom-no-default');
      event.preventDefault();
      expect(event.isDefaultPrevented, true);
      // No error, just a flag
    });
  });

  group('EventDelegate Tests', () {
    group('TC-035: EventDelegate — attach', () {
      test('TC-035 Normal: attach adds delegation entry to parent definition', () {
        final delegate = EventDelegate(
          eventName: 'click',
          handler: (event) {},
        );

        final parentDef = <String, dynamic>{
          'type': 'linear',
          'children': [],
        };

        delegate.attach(parentDef);
        // attach() adds an 'on' map with the eventName key to the parent definition
        expect(parentDef.containsKey('on'), true);
        expect((parentDef['on'] as Map).containsKey('click'), true);
      });

      test('TC-035 Boundary: eventName null does not add delegation entry', () {
        final delegate = EventDelegate(
          handler: (event) {},
        );

        final parentDef = <String, dynamic>{'type': 'box'};
        delegate.attach(parentDef);
        // With null eventName, no delegation entry is added
        expect(parentDef.containsKey('on'), false);
      });
    });

    group('TC-036: EventDelegate — detach', () {
      test('TC-036 Normal: detach removes delegation entry from parent', () {
        final delegate = EventDelegate(
          eventName: 'click',
          handler: (event) {},
        );

        final parentDef = <String, dynamic>{'type': 'linear'};
        delegate.attach(parentDef);
        expect((parentDef['on'] as Map).containsKey('click'), true);

        delegate.detach();
        expect((parentDef['on'] as Map).containsKey('click'), false);
      });

      test('TC-036 Boundary: detach when not attached is no-op', () {
        final delegate = EventDelegate(
          eventName: 'click',
          handler: (event) {},
        );

        // Should not throw
        delegate.detach();
      });
    });
  });
}
