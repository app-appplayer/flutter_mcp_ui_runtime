// The executors' wiring: what each says when the part it needs is not there,
// and the composite forms a document actually writes.
//
// An executor with no handler behind it, a batch whose members failed, a
// channel action naming a sub-operation nobody implements — each is a branch
// whose whole job is to report, and a silent success in any of them leaves the
// document showing a screen consistent with work that never happened.

import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_result.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/channels/channel_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/models/ui_definition.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ActionHandler handler;
  late StateManager stateManager;
  late RenderContext context;

  setUp(() {
    handler = ActionHandler();
    stateManager = StateManager()..initialize(<String, dynamic>{});
    final registry = WidgetRegistry();
    DefaultWidgets.registerAll(registry);
    final bindingEngine = BindingEngine();
    context = RenderContext(
      renderer: Renderer(
        widgetRegistry: registry,
        bindingEngine: bindingEngine,
        actionHandler: handler,
        stateManager: stateManager,
      ),
      stateManager: stateManager,
      bindingEngine: bindingEngine,
      actionHandler: handler,
      themeManager: ThemeManager.instance,
    );
  });

  Map<String, dynamic> set(String binding, Object value) => <String, dynamic>{
        'type': 'state',
        'action': 'set',
        'binding': binding,
        'value': value,
      };

  Map<String, dynamic> failing() => <String, dynamic>{
        'type': 'channel',
        'action': 'start',
        'channel': 'never-declared',
      };

  group('unconfigured executors', () {
    test('each composite refuses by name rather than doing nothing', () async {
      for (final action in <Map<String, dynamic>>[
        <String, dynamic>{'type': 'batch', 'actions': <dynamic>[]},
        <String, dynamic>{'type': 'conditional', 'condition': 'true'},
      ]) {
        final executor = action['type'] == 'batch'
            ? BatchActionExecutor()
            : ConditionalActionExecutor();
        final result = await executor.execute(action, context);

        expect(result.success, isFalse, reason: '${action['type']}');
        expect(result.error, 'Action handler not configured',
            reason: 'a composite with nothing to delegate to must say so — '
                'reporting success would tell the document its members ran');
      }
    });
  });

  group('batch', () {
    test('runs its members in order, and an empty batch is not an error',
        () async {
      final empty = await handler.execute(
          <String, dynamic>{'type': 'batch', 'actions': <dynamic>[]}, context);
      expect(empty.success, isTrue,
          reason: 'a batch built from a filtered list is empty on an empty '
              'input; that is a correct document');

      await handler.execute(<String, dynamic>{
        'type': 'batch',
        'actions': <dynamic>[set('a', 1), set('b', 2)],
      }, context);

      expect(stateManager.get('a'), 1);
      expect(stateManager.get('b'), 2);
    });

    test('a missing actions list is an authoring error', () async {
      final result =
          await handler.execute(<String, dynamic>{'type': 'batch'}, context);

      expect(result.success, isFalse);
      expect(result.error, contains('required'));
    });

    test('by default a failing member does not stop the rest', () async {
      final result = await handler.execute(<String, dynamic>{
        'type': 'batch',
        'actions': <dynamic>[failing(), set('after', 1)],
      }, context);

      expect(result.success, isTrue);
      expect(stateManager.get('after'), 1,
          reason: 'graceful degradation is the declared default; one failed '
              'member must not silently skip the rest');
    });

    test('stopOnError stops, and reports the member that failed', () async {
      final result = await handler.execute(<String, dynamic>{
        'type': 'batch',
        'stopOnError': true,
        'actions': <dynamic>[failing(), set('after', 1)],
      }, context);

      expect(result.success, isFalse);
      expect(stateManager.get('after'), isNull);
    });

    test('a parallel batch runs everything, and reports failure as a whole',
        () async {
      final ok = await handler.execute(<String, dynamic>{
        'type': 'batch',
        'parallel': true,
        'actions': <dynamic>[set('a', 1), set('b', 2)],
      }, context);
      expect(ok.success, isTrue);
      expect(stateManager.get('a'), 1);
      expect(stateManager.get('b'), 2);

      final failed = await handler.execute(<String, dynamic>{
        'type': 'batch',
        'parallel': true,
        'stopOnError': true,
        'actions': <dynamic>[failing(), set('c', 3)],
      }, context);

      expect(failed.success, isFalse);
      expect(failed.error, 'One or more actions failed');
      expect(stateManager.get('c'), 3,
          reason: 'parallel means every member was already in flight; the '
              'result reports the failure without pretending to unwind');
    });
  });

  group('channel actions', () {
    late ChannelManager channels;
    late ChannelActionExecutor executor;

    setUp(() async {
      channels = ChannelManager();
      await channels.initChannel(
        'telemetry',
        ChannelConfig.fromJson(<String, dynamic>{
          'type': 'client.poll',
          'autoStart': false,
          'params': <String, dynamic>{'interval': 60000},
        }),
      );
      executor = ChannelActionExecutor()..channelManager = channels;
    });

    tearDown(() => channels.dispose());

    Future<ActionResult> run(Map<String, dynamic> action) =>
        executor.execute(action, context);

    test('start, stop, toggle and restart each reach the manager', () async {
      expect((await run(<String, dynamic>{
        'type': 'channel',
        'action': 'start',
        'channel': 'telemetry',
      })).success, isTrue);
      expect(channels.isActive('telemetry'), isTrue);

      expect((await run(<String, dynamic>{
        'type': 'channel',
        'action': 'stop',
        'channel': 'telemetry',
      })).success, isTrue);
      expect(channels.isActive('telemetry'), isFalse);

      expect((await run(<String, dynamic>{
        'type': 'channel',
        'action': 'toggle',
        'channel': 'telemetry',
      })).success, isTrue);
      expect(channels.isActive('telemetry'), isTrue);

      expect((await run(<String, dynamic>{
        'type': 'channel',
        'action': 'restart',
        'channel': 'telemetry',
      })).success, isTrue);

      await run(<String, dynamic>{
        'type': 'channel',
        'action': 'stop',
        'channel': 'telemetry',
      });
    });

    test('the legacy dotted and flat spellings dispatch the same way',
        () async {
      expect((await run(<String, dynamic>{
        'type': 'channel',
        'action': 'channel.start',
        'channel': 'telemetry',
      })).success, isTrue);

      expect((await run(<String, dynamic>{
        'type': 'channel.stop',
        'channel': 'telemetry',
      })).success, isTrue,
          reason: '§17.3.4 keeps both spellings readable; a bundle written to '
              'the older one must keep working');
    });

    test('sending on an inbound-only channel is reported, not swallowed',
        () async {
      final result = await run(<String, dynamic>{
        'type': 'channel',
        'action': 'send',
        'channel': 'telemetry',
        'data': <String, dynamic>{'ping': 1},
      });

      expect(result.success, isFalse,
          reason: 'a poll channel has nowhere to send to; a success the '
              'document cannot tell apart from delivery is the failure this '
              'result exists to prevent');
    });

    test('a sub-action nobody implements is named', () async {
      final result = await run(<String, dynamic>{
        'type': 'channel',
        'action': 'rewind',
        'channel': 'telemetry',
      });

      expect(result.error, contains('Unknown channel sub-action: rewind'));
    });

    test('a channel that was never declared is reported, not shrugged off',
        () async {
      final result = await run(<String, dynamic>{
        'type': 'channel',
        'action': 'start',
        'channel': 'nope',
      });

      expect(result.success, isFalse);
      expect(result.errorCode, 'NOT_FOUND',
          reason: 'a page waiting on a channel that was never declared waits '
              'forever, and `onError` never fires if this reports success');
    });

    test('the missing pieces are each named', () async {
      expect((await run(<String, dynamic>{'channel': 'telemetry'})).error,
          contains('Channel action type is required'));
      expect(
          (await run(<String, dynamic>{
            'type': 'channel',
            'channel': 'telemetry',
          }))
              .error,
          contains('sub-operation'));
      expect(
          (await run(<String, dynamic>{'type': 'channel', 'action': 'start'}))
              .error,
          contains('Channel name is required'));
      expect(
          (await run(<String, dynamic>{
            'type': 'notAChannel',
            'action': 'start',
            'channel': 'telemetry',
          }))
              .error,
          contains('Unknown channel type'));
    });

    test('with no manager wired the action reports it', () async {
      final unwired = ChannelActionExecutor();

      final result = await unwired.execute(<String, dynamic>{
        'type': 'channel',
        'action': 'start',
        'channel': 'telemetry',
      }, context);

      expect(result.error, 'ChannelManager not configured');
    });
  });

  group('permission revoke', () {
    final executor = PermissionRevokeActionExecutor();

    test('an action type that is not a permission action is named', () async {
      final result = await executor.execute(
          <String, dynamic>{'type': 'clipboard', 'action': 'revoke'}, context);

      expect(result.error, contains('Unknown permission type'));
    });

    test('a permission action with no sub-operation is named', () async {
      final result = await executor
          .execute(<String, dynamic>{'type': 'permission'}, context);

      expect(result.error, contains('sub-operation'));
    });

    test('a sub-operation other than revoke is named', () async {
      final result = await executor.execute(
          <String, dynamic>{'type': 'permission', 'action': 'grant'}, context);

      expect(result.error, contains('Unknown permission sub-action'));
    });
  });

  group('media', () {
    test('an action this executor does not implement is named', () async {
      final result = await handler.execute(<String, dynamic>{
        'type': 'media.rewind',
        'id': 'player',
      }, context);

      expect(result.success, isFalse);
      expect(result.error, isNotNull);
    });
  });

  group('parallel and sequence with nothing wired', () {
    test('each refuses by name', () async {
      for (final executor in <ActionExecutor>[
        ParallelActionExecutor(),
        SequenceActionExecutor(),
      ]) {
        final result = await executor.execute(<String, dynamic>{
          'type': 'parallel',
          'actions': <dynamic>[set('a', 1)],
        }, context);

        expect(result.error, 'Action handler not configured',
            reason: '${executor.runtimeType}');
      }
    });
  });

  group('parallel', () {
    test('runs every member, and calls back when any failed', () async {
      final result = await handler.execute(<String, dynamic>{
        'type': 'parallel',
        'actions': <dynamic>[failing(), set('a', 1)],
        'onAnyError': set('errored', true),
        'onAllComplete': set('completed', true),
      }, context);

      expect(result.success, isFalse);
      expect(result.error, 'One or more parallel actions failed');
      expect(stateManager.get('a'), 1,
          reason: 'parallel means every member was already in flight — one '
              'failing does not unrun the others');
      expect(stateManager.get('errored'), isTrue);
      expect(stateManager.get('completed'), isTrue,
          reason: 'the completion callback runs whatever happened; a document '
              'that clears a spinner there would never clear it otherwise');
    });

    test('an empty or missing list is an authoring error', () async {
      expect(
          (await handler.execute(
                  <String, dynamic>{'type': 'parallel'}, context))
              .error,
          contains('required'));
      expect(
          (await handler.execute(<String, dynamic>{
            'type': 'parallel',
            'actions': <dynamic>[],
          }, context))
              .error,
          contains('required'));
    });
  });

  group('sequence', () {
    test('stops at the first failure by default', () async {
      final result = await handler.execute(<String, dynamic>{
        'type': 'sequence',
        'actions': <dynamic>[failing(), set('after', 1)],
      }, context);

      expect(result.success, isFalse);
      expect(stateManager.get('after'), isNull,
          reason: 'a sequence is ordered because each step depends on the one '
              'before; carrying on past a failure runs a step on state that '
              'was never written');
    });

    test('with stopOnError off it runs the rest, then completes', () async {
      final result = await handler.execute(<String, dynamic>{
        'type': 'sequence',
        'stopOnError': false,
        'actions': <dynamic>[failing(), set('after', 1)],
        'onComplete': set('completed', true),
      }, context);

      expect(result.success, isTrue);
      expect(stateManager.get('after'), 1);
      expect(stateManager.get('completed'), isTrue);
    });

    test('an empty or missing list is an authoring error', () async {
      expect(
          (await handler.execute(
                  <String, dynamic>{'type': 'sequence'}, context))
              .error,
          contains('required'));
    });
  });

  group('resource actions with no host handler', () {
    test('read and list are each refused rather than reported as done',
        () async {
      for (final action in const ['read', 'list']) {
        final result = await handler.execute(<String, dynamic>{
          'type': 'resource',
          'action': action,
          'uri': 'ui://rows',
          'binding': 'rows',
        }, context);

        expect(result.success, isFalse, reason: action);
        expect(result.error, contains('no resource $action handler'),
            reason: 'a document told its read succeeded waits forever for '
                'data nobody asked for');
      }
    });

    test('an action nobody implements is named', () async {
      final result = await handler.execute(<String, dynamic>{
        'type': 'resource',
        'action': 'rewind',
        'uri': 'ui://rows',
      }, context);

      expect(result.error, contains('Unknown resource action'));
    });
  });
}
