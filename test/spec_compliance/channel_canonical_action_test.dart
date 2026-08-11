// Canonical channel action dispatch — spec §4.13 bare sub-op
// (`{type: 'channel', action: 'start'}`) must resolve through
// `_executors['channel']` to `ChannelActionExecutor` and call the
// registered ChannelManager's startChannel/stopChannel/etc.
//
// The existing flat/dotted legacy forms must continue to work so authors
// on older bundles don't break (§17.3.4).

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

class _RecordingChannelManager extends ChannelManager {
  final started = <String>[];
  final stopped = <String>[];
  final sent = <List<dynamic>>[];
  final Set<String> _channels = {};

  void register(String id) => _channels.add(id);

  @override
  Future<void> sendToChannel(String channelId, dynamic data) async {
    sent.add([channelId, data]);
  }

  @override
  Future<void> startChannel(String channelId) async {
    started.add(channelId);
  }

  @override
  Future<void> stopChannel(String channelId) async {
    stopped.add(channelId);
  }

  @override
  bool hasChannel(String channelId) => _channels.contains(channelId);
}

void main() {
  group('§4.13 canonical channel action dispatch', () {
    late MCPUIRuntime runtime;
    late _RecordingChannelManager manager;

    setUp(() async {
      runtime = MCPUIRuntime();
      await runtime.initialize({
        'type': 'page',
        'content': {'type': 'text', 'text': 'noop'},
      });
      manager = _RecordingChannelManager()..register('tempPoll');
      runtime.engine.actionHandler.setChannelManager(manager);
    });

    tearDown(() async {
      await runtime.dispose();
    });

    Future<bool> fire(Map<String, dynamic> action) async {
      final ctx = runtime.engine.renderer.createRootContext(null);
      final result = await runtime.engine.actionHandler.execute(action, ctx);
      return result.success;
    }

    testWidgets('bare sub-op `start` triggers startChannel', (tester) async {
      expect(
          await fire({
            'type': 'channel',
            'action': 'start',
            'channel': 'tempPoll',
          }),
          isTrue);
      expect(manager.started, ['tempPoll']);
    });

    testWidgets('bare sub-op `stop` triggers stopChannel', (tester) async {
      expect(
          await fire({
            'type': 'channel',
            'action': 'stop',
            'channel': 'tempPoll',
          }),
          isTrue);
      expect(manager.stopped, ['tempPoll']);
    });

    testWidgets('legacy dotted sub-op `channel.start` still accepted',
        (tester) async {
      expect(
          await fire({
            'type': 'channel',
            'action': 'channel.start',
            'channel': 'tempPoll',
          }),
          isTrue);
      expect(manager.started, ['tempPoll']);
    });

    testWidgets('legacy flat shape `type: channel.start` still accepted',
        (tester) async {
      expect(
          await fire({
            'type': 'channel.start',
            'channel': 'tempPoll',
          }),
          isTrue);
      expect(manager.started, ['tempPoll']);
    });

    testWidgets('canonical channel sub-op without `action` key fails cleanly',
        (tester) async {
      expect(
          await fire({
            'type': 'channel',
            'channel': 'tempPoll',
          }),
          isFalse,
          reason: 'missing action sub-op must be rejected, not silent no-op');
    });

    testWidgets('`send` carries the payload to the channel', (tester) async {
      expect(
          await fire({
            'type': 'channel',
            'action': 'send',
            'channel': 'tempPoll',
            'data': {'command': 'reset'},
          }),
          isTrue);

      expect(manager.sent, [
        ['tempPoll', {'command': 'reset'}]
      ], reason: 'the only outbound sub-op — a document that reports success '
          'without the manager ever being called has a control that does '
          'nothing and looks like it worked');
    });
  });
}
