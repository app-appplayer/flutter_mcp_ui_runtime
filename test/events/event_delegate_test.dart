import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/events/event_system.dart';
import 'package:flutter_mcp_ui_runtime/src/events/event_delegate.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';

void main() {
  group('EventDelegate Tests', () {
    group('TC-008: Parent delegates child events', () {
      test('TC-008 Normal: shouldHandle returns true for null condition', () {
        final delegate = EventDelegate();
        final event = UIEvent(type: 'click', targetId: 'item-1');
        expect(delegate.shouldHandle(event, null), true);
      });

      test('TC-008 Normal: shouldHandle with bool condition', () {
        final delegate = EventDelegate();
        final event = UIEvent(type: 'click');
        expect(delegate.shouldHandle(event, true), true);
        expect(delegate.shouldHandle(event, false), false);
      });
    });

    group('TC-017: Conditional event handling with when clause', () {
      test('TC-017 Normal: string condition matching event type', () {
        final event = UIEvent(type: 'click', targetId: 'btn-1');
        expect(
          EventDelegate.shouldHandleStatic(event, 'type == "click"'),
          true,
        );
      });

      test('TC-017 Normal: string condition with targetId', () {
        final event = UIEvent(type: 'click', targetId: 'btn-1');
        expect(
          EventDelegate.shouldHandleStatic(event, 'targetId == "btn-1"'),
          true,
        );
      });

      test('TC-017 Normal: targetId.startsWith matching', () {
        final event = UIEvent(type: 'click', targetId: 'item-42');
        expect(
          EventDelegate.shouldHandleStatic(
              event, 'targetId.startsWith("item-")'),
          true,
        );
      });

      test('TC-017 Normal: targetId.endsWith matching', () {
        final event = UIEvent(type: 'click', targetId: 'btn-delete');
        expect(
          EventDelegate.shouldHandleStatic(
              event, 'targetId.endsWith("-delete")'),
          true,
        );
      });

      test('TC-017 Normal: targetId.contains matching', () {
        final event = UIEvent(type: 'click', targetId: 'row-item-edit');
        expect(
          EventDelegate.shouldHandleStatic(
              event, 'targetId.contains("item")'),
          true,
        );
      });

      test('TC-017 Normal: data field matching', () {
        final event = UIEvent(
          type: 'click',
          data: {'category': 'electronics'},
        );
        expect(
          EventDelegate.shouldHandleStatic(
              event, 'data.category == "electronics"'),
          true,
        );
      });

      test('TC-017 Normal: non-matching condition returns false', () {
        final event = UIEvent(type: 'click', targetId: 'other');
        expect(
          EventDelegate.shouldHandleStatic(event, 'targetId == "btn-1"'),
          false,
        );
      });

      test('TC-017 Normal: event. prefix stripped for legacy parser', () {
        final event = UIEvent(type: 'click', targetId: 'btn-1');
        expect(
          EventDelegate.shouldHandleStatic(
              event, 'event.targetId == "btn-1"'),
          true,
        );
      });

      test('TC-017 Normal: event.type prefix matching', () {
        final event = UIEvent(type: 'submit');
        expect(
          EventDelegate.shouldHandleStatic(event, 'event.type == "submit"'),
          true,
        );
      });

      test('TC-017 Error: unknown condition format defaults to true', () {
        final event = UIEvent(type: 'click');
        expect(
          EventDelegate.shouldHandleStatic(event, 'some unknown format'),
          true,
        );
      });
    });

    group('TC-018: Filter with map conditions', () {
      test('TC-018 Normal: map condition matching type', () {
        final delegate = EventDelegate();
        final event = UIEvent(type: 'click', targetId: 'btn-1');

        expect(
          delegate.shouldHandle(event, {'type': 'click'}),
          true,
        );
      });

      test('TC-018 Normal: map condition matching targetId with pattern', () {
        final delegate = EventDelegate();
        final event = UIEvent(type: 'click', targetId: 'item-123');

        expect(
          delegate.shouldHandle(event, {'targetId': 'item-*'}),
          true,
        );
      });

      test('TC-018 Normal: map condition matching phase', () {
        final delegate = EventDelegate();
        final event = UIEvent(type: 'click', phase: EventPhase.bubble);

        expect(
          delegate.shouldHandle(event, {'phase': 'bubble'}),
          true,
        );
      });

      test('TC-018 Normal: map condition matching data field', () {
        final delegate = EventDelegate();
        final event = UIEvent(
          type: 'click',
          data: {'status': 'active'},
        );

        expect(
          delegate.shouldHandle(event, {'data.status': 'active'}),
          true,
        );
      });

      test('TC-018 Error: non-matching map condition', () {
        final delegate = EventDelegate();
        final event = UIEvent(type: 'click', targetId: 'other');

        expect(
          delegate.shouldHandle(event, {'type': 'submit'}),
          false,
        );
      });
    });

    group('createDelegatedHandler', () {
      test('handler fires for non-delegated event', () {
        bool called = false;
        final handler = EventDelegate.createDelegatedHandler(
          handler: (event) => called = true,
          delegate: false,
        );

        handler(UIEvent(type: 'click'));
        expect(called, true);
      });

      test('delegated handler skips target phase events', () {
        bool called = false;
        final handler = EventDelegate.createDelegatedHandler(
          handler: (event) => called = true,
          delegate: true,
        );

        handler(UIEvent(type: 'click', phase: EventPhase.target));
        expect(called, false);
      });

      test('delegated handler fires for bubble phase events', () {
        bool called = false;
        final handler = EventDelegate.createDelegatedHandler(
          handler: (event) => called = true,
          delegate: true,
        );

        handler(UIEvent(type: 'click', phase: EventPhase.bubble));
        expect(called, true);
      });

      test('handler respects when condition', () {
        bool called = false;
        final handler = EventDelegate.createDelegatedHandler(
          handler: (event) => called = true,
          when: 'type == "submit"',
        );

        handler(UIEvent(type: 'click'));
        expect(called, false);

        handler(UIEvent(type: 'submit'));
        expect(called, true);
      });

      test('TC-005 Normal: propagation stop applied before handler', () {
        final handler = EventDelegate.createDelegatedHandler(
          handler: (event) {},
          propagation: 'stop',
        );

        final event = UIEvent(type: 'click');
        handler(event);
        expect(event.isStopped, true);
      });

      test('propagation stopImmediate applied', () {
        final event = UIEvent(type: 'click');
        final handler = EventDelegate.createDelegatedHandler(
          handler: (e) {},
          propagation: 'stopImmediate',
        );

        handler(event);
        expect(event.isImmediateStopped, true);
      });

      test('propagation preventDefault applied', () {
        final event = UIEvent(type: 'click');
        final handler = EventDelegate.createDelegatedHandler(
          handler: (e) {},
          propagation: 'preventDefault',
        );

        handler(event);
        expect(event.isDefaultPrevented, true);
      });

      test('propagation stopAll applies both', () {
        final event = UIEvent(type: 'click');
        final handler = EventDelegate.createDelegatedHandler(
          handler: (e) {},
          propagation: 'stopAll',
        );

        handler(event);
        expect(event.isImmediateStopped, true);
        expect(event.isDefaultPrevented, true);
      });
    });

    group('TC-024/TC-025: Additional delegate tests', () {
      test('TC-024 Normal: unknown event type handler returns gracefully', () {
        // A delegated handler with unrecognized 'when' condition defaults to true
        bool called = false;
        final handler = EventDelegate.createDelegatedHandler(
          handler: (event) => called = true,
          when: 'some.unknown.condition.format',
        );

        handler(UIEvent(type: 'unknownEventType'));
        // Unknown condition format defaults to true, so handler fires
        expect(called, true);
      });

      test('TC-024 Boundary: handler with null when always fires', () {
        bool called = false;
        final handler = EventDelegate.createDelegatedHandler(
          handler: (event) => called = true,
        );

        handler(UIEvent(type: 'anyEvent'));
        expect(called, true);
      });

      test('TC-025 Normal: stop propagation on capture phase in delegate', () {
        final captureEvent =
            UIEvent(type: 'click', phase: EventPhase.capture, targetId: 'btn');

        final handler = EventDelegate.createDelegatedHandler(
          handler: (event) {},
          delegate: true,
          propagation: 'stop',
        );

        // Capture phase is not target phase, so delegated handler fires
        handler(captureEvent);
        expect(captureEvent.isStopped, true);
      });

      test('TC-025 Boundary: delegate skips target phase but handles capture and bubble', () {
        int callCount = 0;
        final handler = EventDelegate.createDelegatedHandler(
          handler: (event) => callCount++,
          delegate: true,
        );

        // Target phase — skipped by delegate
        handler(UIEvent(type: 'click', phase: EventPhase.target));
        expect(callCount, 0);

        // Capture phase — handled by delegate
        handler(UIEvent(type: 'click', phase: EventPhase.capture));
        expect(callCount, 1);

        // Bubble phase — handled by delegate
        handler(UIEvent(type: 'click', phase: EventPhase.bubble));
        expect(callCount, 2);
      });
    });

    group('createFilteredHandler', () {
      test('exact match pattern', () {
        bool called = false;
        final handler = EventDelegate.createFilteredHandler(
          handler: (event) => called = true,
          pattern: 'button-1',
        );

        handler(UIEvent(type: 'click', targetId: 'button-1'));
        expect(called, true);
      });

      test('prefix match pattern', () {
        bool called = false;
        final handler = EventDelegate.createFilteredHandler(
          handler: (event) => called = true,
          pattern: 'item-*',
        );

        handler(UIEvent(type: 'click', targetId: 'item-42'));
        expect(called, true);
      });

      test('suffix match pattern', () {
        bool called = false;
        final handler = EventDelegate.createFilteredHandler(
          handler: (event) => called = true,
          pattern: '*-delete',
        );

        handler(UIEvent(type: 'click', targetId: 'row-delete'));
        expect(called, true);
      });

      test('contains match pattern', () {
        bool called = false;
        final handler = EventDelegate.createFilteredHandler(
          handler: (event) => called = true,
          pattern: '*item*',
        );

        handler(UIEvent(type: 'click', targetId: 'my-item-edit'));
        expect(called, true);
      });

      test('wildcard matches everything', () {
        bool called = false;
        final handler = EventDelegate.createFilteredHandler(
          handler: (event) => called = true,
          pattern: '*',
        );

        handler(UIEvent(type: 'click', targetId: 'anything'));
        expect(called, true);
      });

      test('null targetId skipped', () {
        bool called = false;
        final handler = EventDelegate.createFilteredHandler(
          handler: (event) => called = true,
          pattern: 'button-1',
        );

        handler(UIEvent(type: 'click'));
        expect(called, false);
      });

      test('non-matching pattern skipped', () {
        bool called = false;
        final handler = EventDelegate.createFilteredHandler(
          handler: (event) => called = true,
          pattern: 'button-1',
        );

        handler(UIEvent(type: 'click', targetId: 'button-2'));
        expect(called, false);
      });
    });
  });

  group('a condition evaluated through the binding engine', () {
    late StateManager stateManager;
    late BindingEngine bindingEngine;
    late RenderContext context;
    late EventDelegate delegate;

    setUp(() {
      stateManager = StateManager()..initialize(<String, dynamic>{});
      bindingEngine = BindingEngine();
      final actionHandler = ActionHandler();
      context = RenderContext(
        renderer: Renderer(
          widgetRegistry: WidgetRegistry(),
          bindingEngine: bindingEngine,
          actionHandler: actionHandler,
          stateManager: stateManager,
        ),
        stateManager: stateManager,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        themeManager: ThemeManager.instance,
      );
      delegate = EventDelegate(
        bindingEngine: bindingEngine,
        renderContext: context,
      );
    });

    test('the full expression language is available, not just equality', () {
      final event = UIEvent(type: 'click', targetId: 'item-42');

      expect(
          delegate.shouldHandle(event, "event.targetId.startsWith('item-')"),
          isTrue,
          reason: 'this is the whole point of delegation — one parent handler '
              'matching a family of children, which equality cannot express');
      expect(
          delegate.shouldHandle(event, "event.targetId.startsWith('row-')"),
          isFalse);
    });

    test('the event payload is reachable under `event.data`', () {
      final event = UIEvent(
        type: 'click',
        targetId: 'item-1',
        data: <String, dynamic>{'id': 7, 'enabled': true},
      );

      expect(delegate.shouldHandle(event, 'event.data.enabled'), isTrue);
      expect(delegate.shouldHandle(event, 'event.data.id == 7'), isTrue);
      expect(delegate.shouldHandle(event, 'event.data.id == 8'), isFalse);
    });

    test('a scalar payload is still reachable', () {
      final event = UIEvent(type: 'click', targetId: 'item-1', data: 'hello');

      expect(delegate.shouldHandle(event, "event.data == 'hello'"), isTrue);
    });

    test('the phase and type are part of what a condition can read', () {
      final event = UIEvent(
        type: 'submit',
        targetId: 'form-1',
        phase: EventPhase.bubble,
      );

      expect(delegate.shouldHandle(event, "event.type == 'submit'"), isTrue);
      expect(
          delegate.shouldHandle(event, "event.phase == 'bubble'"), isTrue);
    });

    test('a condition already in binding syntax is used as written', () {
      stateManager.set('editing', true);
      final event = UIEvent(type: 'click', targetId: 'item-1');

      expect(delegate.shouldHandle(event, '{{editing}}'), isTrue,
          reason: 'a condition may read page state as well as the event; '
              'wrapping it twice would make it a literal string');
    });

    test('a condition that resolves to a non-empty string counts as true', () {
      final event = UIEvent(type: 'click', targetId: 'item-1');

      expect(delegate.shouldHandle(event, 'event.targetId'), isTrue);
      expect(delegate.shouldHandle(event, 'event.data'), isFalse,
          reason: 'an absent payload is not a match');
    });

    test('an unparseable condition falls back rather than throwing', () {
      final event = UIEvent(type: 'click', targetId: 'btn-1');

      expect(() => delegate.shouldHandle(event, 'type == "click"'),
          returnsNormally);
    });
  });
}
