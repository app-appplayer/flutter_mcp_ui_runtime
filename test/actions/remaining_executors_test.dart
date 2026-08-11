// The action executors still without a test: `notification`, `channel`,
// `permission.revoke`, `event`, `cancel` and `identity`.
//
// Each is small, and each is the far end of something a document declares and
// then trusts. A notification that never reaches the messenger, a channel
// action that reports success for a channel it never started, a revoke that
// leaves the permission marked granted — all of them look like nothing
// happened, which is also what success looks like.

import 'package:flutter/material.dart';
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
  late ActionHandler handler;
  late StateManager stateManager;

  RenderContext contextFor(BuildContext? buildContext) {
    final registry = WidgetRegistry();
    DefaultWidgets.registerAll(registry);
    final bindingEngine = BindingEngine();
    return RenderContext(
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
      buildContext: buildContext,
    );
  }

  setUp(() {
    handler = ActionHandler();
    stateManager = StateManager()..initialize(<String, dynamic>{});
  });

  group('notification', () {
    /// Mounts a scaffold and runs the action against its context.
    Future<ActionResult> notify(
      WidgetTester tester,
      Map<String, dynamic> action,
    ) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          ctx = context;
          return const Scaffold(body: Text('page'));
        }),
      ));
      final result = await handler.execute(action, contextFor(ctx));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      return result;
    }

    testWidgets('the message reaches the messenger', (tester) async {
      final result =
          await notify(tester, {'type': 'notification', 'message': 'Saved'});

      expect(result.success, isTrue);
      expect(find.text('Saved'), findsOneWidget,
          reason: 'a notification action that builds a SnackBar and never '
              'shows it is indistinguishable from one that worked');
    });

    testWidgets('a bound message is resolved before it is shown',
        (tester) async {
      stateManager.set('name', 'Ada');
      await notify(tester, {
        'type': 'notification',
        'message': 'Welcome back, {{name}}',
      });

      expect(find.text('Welcome back, Ada'), findsOneWidget,
          reason: 'showing the braces to a user is the failure this catches');
    });

    testWidgets('severity colours the bar, and info leaves it default',
        (tester) async {
      await notify(tester, {
        'type': 'notification',
        'message': 'Gone wrong',
        'severity': 'error',
        'duration': 100,
      });
      final error = tester.widget<SnackBar>(find.byType(SnackBar).last);
      expect(error.backgroundColor, isNotNull,
          reason: 'severity is the only thing distinguishing an error toast '
              'from a confirmation at a glance');

      // The messenger queues, so the previous bar has to expire before the
      // next one is the only one on screen.
      await tester.pump(const Duration(seconds: 1));
      await notify(tester, {'type': 'notification', 'message': 'FYI'});
      final info = tester.widget<SnackBar>(find.byType(SnackBar).last);
      expect(info.backgroundColor, isNull);
    });

    testWidgets('an action button is shown and its handler runs',
        (tester) async {
      await notify(tester, {
        'type': 'notification',
        'message': 'Deleted',
        'action': {
          'label': 'Undo',
          'click': {
            'type': 'state',
            'action': 'set',
            'binding': 'undone',
            'value': true,
          },
        },
      });

      expect(find.text('Undo'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(stateManager.get('undone'), isTrue);
    });

    testWidgets('position: top floats it away from the bottom edge',
        (tester) async {
      await notify(tester, {
        'type': 'notification',
        'message': 'Up here',
        'position': 'top',
      });

      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.behavior, SnackBarBehavior.floating);
      expect(bar.margin, isNotNull);
    });

    test('a notification with no message is refused by name', () async {
      final result = await handler
          .execute({'type': 'notification'}, contextFor(null));
      expect(result.success, isFalse);
      expect(result.error, contains('Message'));
    });

    test('with no surface it answers rather than throwing', () async {
      final result = await handler.execute(
          {'type': 'notification', 'message': 'nowhere'}, contextFor(null));
      expect(result.success, isTrue,
          reason: 'a headless render has no messenger; the action reports '
              'that it ran, and the absence of a screen is the host\'s fact');
    });
  });

  group('channel', () {
    late ChannelManager channels;

    setUp(() async {
      channels = ChannelManager();
      handler.setChannelManager(channels);
      await channels.initChannel(
        'feed',
        ChannelConfig(type: 'client.poll', params: {'interval': 5000}),
      );
    });

    tearDown(() => channels.dispose());

    Future<ActionResult> run(Map<String, dynamic> action) =>
        handler.execute(action, contextFor(null));

    test('start, stop and toggle move the channel', () async {
      expect((await run({'type': 'channel.start', 'channel': 'feed'})).success,
          isTrue);
      expect(channels.isActive('feed'), isTrue);

      expect((await run({'type': 'channel.stop', 'channel': 'feed'})).success,
          isTrue);
      expect(channels.isActive('feed'), isFalse,
          reason: 'reporting success for a channel that kept running leaves a '
              'document paying for a poll it thinks it stopped');

      await run({'type': 'channel.toggle', 'channel': 'feed'});
      expect(channels.isActive('feed'), isTrue);
    });

    test('restart stops and starts again', () async {
      await run({'type': 'channel.start', 'channel': 'feed'});
      expect((await run({'type': 'channel.restart', 'channel': 'feed'})).success,
          isTrue);
      expect(channels.isActive('feed'), isTrue);
    });

    test('the canonical `{type: channel, action: …}` spelling works too',
        () async {
      final result =
          await run({'type': 'channel', 'action': 'start', 'channel': 'feed'});
      expect(result.success, isTrue);
      expect(channels.isActive('feed'), isTrue);
    });

    test('an unknown sub-action is refused by name', () async {
      final result = await run({'type': 'channel.telepathy', 'channel': 'feed'});
      expect(result.success, isFalse);
      expect(result.error, contains('telepathy'));
    });

    test('acting on a channel nobody declared is reported', () async {
      final result = await run({'type': 'channel.start', 'channel': 'ghost'});
      expect(result.success, isFalse,
          reason: 'a start that answers success for a channel that does not '
              'exist leaves the document waiting for data forever');
    });
  });

  group('permission.revoke', () {
    Future<ActionResult> run(Map<String, dynamic> action) =>
        handler.execute(action, contextFor(null));

    test('a single permission is marked revoked in state', () async {
      final result = await run({
        'type': 'permission.revoke',
        'permission': 'camera',
      });

      expect(result.success, isTrue);
      expect(stateManager.get('permissions.camera.status'), 'revoked',
          reason: 'the state binding is what a document reads to hide the '
              'feature — a revoke that writes nothing leaves it on screen');
    });

    test('the plural form revokes every one named', () async {
      await run({
        'type': 'permission',
        'action': 'revoke',
        'permissions': ['camera', 'location'],
      });

      expect(stateManager.get('permissions.camera.status'), 'revoked');
      expect(stateManager.get('permissions.location.status'), 'revoked');
    });

    test('an empty list, a missing permission and a bad sub-action are all '
        'refused', () async {
      expect((await run({'type': 'permission.revoke', 'permissions': []}))
          .success, isFalse);
      expect((await run({'type': 'permission.revoke'})).success, isFalse);
      expect((await run({'type': 'permission', 'action': 'grant'})).success,
          isFalse,
          reason: 'a runtime cannot grant a permission on the user\'s behalf; '
              'accepting the word would be the worst possible silence');
      expect((await run({'type': 'permission'})).success, isFalse);
      expect((await run({'type': 'permission.telepathy'})).success, isFalse);
    });
  });

  group('event', () {
    Future<ActionResult> run(Map<String, dynamic> action) =>
        handler.execute(action, contextFor(null));

    test('emitting records the payload and a timestamp', () async {
      final result = await run({
        'type': 'event',
        'event': 'cart-updated',
        'data': {'count': 2},
      });

      expect(result.success, isTrue);
      expect(stateManager.get('_events.cart-updated.data'), {'count': 2});
      expect(stateManager.get('_events.cart-updated.timestamp'), isA<String>(),
          reason: 'the timestamp is how a listener tells a fresh emit from the '
              'one it already handled');
    });

    test('an event with no name is refused', () async {
      expect((await run({'type': 'event'})).success, isFalse);
      expect((await run({'type': 'event', 'event': ''})).success, isFalse);
    });

    test('an unknown event sub-action is refused', () async {
      final result =
          await run({'type': 'event', 'event': 'x', 'action': 'listen'});
      expect(result.success, isFalse,
          reason: 'only `emit` exists — accepting `listen` would leave a '
              'document believing it had subscribed');
    });
  });

  group('cancel', () {
    Future<ActionResult> run(Map<String, dynamic> action) =>
        handler.execute(action, contextFor(null));

    test('it raises the cancellation flag the target checks', () async {
      final result = await run({'type': 'cancel', 'target': 'upload'});

      expect(result.success, isTrue);
      expect(stateManager.get('_cancellations.upload'), isTrue);
    });

    test('the onCancel callback runs', () async {
      await run({
        'type': 'cancel',
        'target': 'upload',
        'onCancel': {
          'type': 'state',
          'action': 'set',
          'binding': 'cancelled',
          'value': true,
        },
      });

      expect(stateManager.get('cancelled'), isTrue,
          reason: 'the callback is where a document rolls its own UI back; '
              'raising the flag alone leaves a spinner turning');
    });

    test('a cancel with no target is refused', () async {
      expect((await run({'type': 'cancel'})).success, isFalse);
      expect((await run({'type': 'cancel', 'target': ''})).success, isFalse);
    });
  });

  group('identity', () {
    Future<ActionResult> run(Map<String, dynamic> action) =>
        handler.execute(action, contextFor(null));

    test('with no entry session it reports unavailable rather than failing',
        () async {
      for (final action in const [
        {'type': 'identity', 'action': 'promote'},
        {'type': 'identity', 'action': 'identity.release'},
      ]) {
        final result = await run(Map<String, dynamic>.from(action));

        expect(result.success, isTrue);
        final data = result.data as Map<String, dynamic>;
        expect(data['supported'], isFalse,
            reason: '§8.9.6 — a document written against 8.9 degrades to its '
                'guest rendering; an error would make it show a failure the '
                'user cannot act on');
        expect(data['changed'], isFalse);
        expect(data['outcome'], isNotNull);
      }
    });

    test('an identity action with no sub-operation is refused', () async {
      final result = await run({'type': 'identity'});
      expect(result.success, isFalse);
      expect(result.error, contains('sub-operation'));
    });

    test('on a host with no identity support even a typo reads as '
        'unavailable — pinned', () async {
      // The session check comes BEFORE the operation switch, so on a runtime
      // that wired no promotion handler `identity.somersault` answers
      // "unavailable" rather than "unknown action". That ordering is what
      // §8.9.6 asks for — degrade to guest without making the document handle
      // an error — but it does mean a misspelled operation is invisible until
      // the document runs on a host that supports identity at all.
      final result = await run({'type': 'identity', 'action': 'somersault'});
      expect(result.success, isTrue);
      expect((result.data as Map<String, dynamic>)['supported'], isFalse);
    });

    test('a type that is not an identity action at all is refused', () async {
      final executor = IdentityActionExecutor();
      final result = await executor.execute(
          {'type': 'telepathy'}, contextFor(null));
      expect(result.success, isFalse);
      expect(result.error, contains('telepathy'));
    });
  });
}
