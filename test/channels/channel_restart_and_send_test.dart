// A channel that fails, and a channel that is written to.
//
// The restart ladder (`restartOnError`, `maxRestarts`, the three backoff
// shapes) is what stands between a dropped socket and a screen that stops
// updating for the rest of the session — and none of it had run. Neither had
// the outbound path: sending TO a channel, its rate limit, and the refusal
// when the channel is not there.

import 'dart:async';

import 'package:flutter_mcp_ui_runtime/src/channels/channel_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/models/ui_definition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ChannelManager manager;
  late List<StreamController<dynamic>> sources;
  late int opens;

  setUp(() {
    sources = [];
    opens = 0;
    manager = ChannelManager()
      ..streamSourceResolver = (uri, params) {
        opens++;
        final controller = StreamController<dynamic>.broadcast();
        sources.add(controller);
        return controller.stream;
      };
  });

  tearDown(() async {
    for (final id in List<String>.from(manager.channelIds)) {
      await manager.disposeChannel(id);
    }
    for (final s in sources) {
      if (!s.isClosed) await s.close();
    }
  });

  ChannelConfig stream({Map<String, dynamic> params = const {}}) => ChannelConfig(
        type: 'client.mcpStream',
        autoStart: true,
        params: <String, dynamic>{
          'uri': 'mcp://server/feed',
          ...params,
        },
      );

  /// Waits until [test] holds, or gives up. Bounded by iterations rather than
  /// by the wall clock so a busy machine cannot decide the outcome.
  Future<void> waitUntil(bool Function() test) async {
    for (var i = 0; i < 200 && !test(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  group('a channel that errors', () {
    test('is restarted when the document asked for it', () async {
      await manager.initChannel(
        'feed',
        stream(params: {'restartOnError': true, 'restartDelay': 5}),
      );

      sources.first.addError(StateError('the socket dropped'));
      await waitUntil(() =>
          manager.getChannelState('feed') != ChannelState.disconnected);

      expect(manager.getChannelState('feed'),
          isNot(ChannelState.disconnected),
          reason: 'a dropped socket that is never reopened is a screen that '
              'stops updating for the rest of the session, with nothing said');
      expect(manager.getChannelState('feed'), isNot(ChannelState.failed));
    });

    test('is not restarted when the document did not ask', () async {
      await manager.initChannel('feed', stream());

      sources.first.addError(StateError('the socket dropped'));
      await waitUntil(() => manager.getChannelState('feed') == ChannelState.disconnected);

      expect(opens, 1,
          reason: 'reconnecting a channel the document did not mark as '
              'restartable reopens a stream it may be paying for');
    });

    test('a successful restart restores the budget', () async {
      await manager.initChannel(
        'feed',
        stream(params: {
          'restartOnError': true,
          'maxRestarts': 1,
          'restartDelay': 5,
        }),
      );

      // Two drops, one more than the ceiling — but the channel came back
      // between them, so the second is a fresh first failure rather than the
      // one that gives up. A flaky connection over a long session must not
      // exhaust a budget it keeps repaying.
      for (var attempt = 0; attempt < 2; attempt++) {
        for (final source in sources) {
          if (!source.isClosed) source.addError(StateError('down again'));
        }
        await waitUntil(() =>
            manager.getChannelState('feed') == ChannelState.connected ||
            manager.getChannelState('feed') == ChannelState.failed);
      }

      expect(manager.getChannelState('feed'), isNot(ChannelState.failed),
          reason: 'the ceiling counts CONSECUTIVE failures; a reconnect that '
              'succeeded is the channel working');
    });

    for (final backoff in const ['exponential', 'linear', 'fixed']) {
      test('$backoff backoff still brings the channel back', () async {
        await manager.initChannel(
          'feed',
          stream(params: {
            'restartOnError': true,
            'restartDelay': 5,
            'restartBackoff': backoff,
          }),
        );

        sources.first.addError(StateError('down'));
        await waitUntil(() =>
            manager.getChannelState('feed') != ChannelState.disconnected);

        expect(manager.getChannelState('feed'), isNot(ChannelState.failed),
            reason: 'the backoff decides HOW LONG to wait, never whether to '
                'come back at all');
      });
    }

    test('the error reaches the host callback', () async {
      Object? seen;
      manager.onError = (id, error) => seen = error;
      await manager.initChannel('feed', stream());

      sources.first.addError(StateError('the socket dropped'));
      await waitUntil(() => seen != null);

      expect(seen.toString(), contains('socket dropped'),
          reason: 'the host is what surfaces this to the document — swallowing '
              'it leaves a channel silently dead');
    });
  });

  group('sending to a channel', () {
    test('an unknown channel is refused by name', () async {
      await expectLater(
        manager.sendToChannel('nosuch', {'ping': true}),
        throwsA(isA<StateError>()),
        reason: 'a send into nothing that returns quietly leaves the document '
            'believing it spoke');
    });

    test('a one-way channel refuses the send and says why', () async {
      await manager.initChannel('feed', stream());

      await expectLater(
        manager.sendToChannel('feed', {'ping': true}),
        throwsA(isA<UnsupportedError>()),
        reason: 'an inbound stream that accepts a send and drops it leaves '
            'the document believing it spoke — the refusal names the channel, '
            'its type, and what was not delivered',
      );
    });

    // The outbound rate limiter sits above this refusal and can only be
    // reached on a channel that CAN send (a WebSocket), which needs a real
    // socket to open. Recorded rather than faked: a fake two-way channel here
    // would exercise the test's own class, not the manager's dispatch.
  });

  group('what a document reads off the channel', () {
    test('a map payload merges into the channel data', () async {
      await manager.initChannel('feed', stream());
      manager.getStream('feed')!.listen((_) {});

      sources.first.add({'temperature': 21});
      await waitUntil(
          () => manager.getChannelData('feed')?['temperature'] != null);

      expect(manager.getChannelData('feed')!['temperature'], 21);
      expect(manager.getChannelData('feed', 'temperature'),
          {'temperature': 21},
          reason: 'binding by key is how `{{channels.feed.temperature}}` '
              'resolves');
    });

    test('a scalar payload is readable as `value`', () async {
      await manager.initChannel('feed', stream());
      manager.getStream('feed')!.listen((_) {});

      sources.first.add(42);
      await waitUntil(() => manager.getChannelData('feed')?['value'] != null);

      expect(manager.getChannelData('feed')!['value'], 42,
          reason: 'a document binds to a path; a bare number with no path to '
              'bind to would be unreadable');
    });

    test('channel data for an unknown channel is null', () {
      expect(manager.getChannelData('nosuch'), isNull);
    });
  });
}
