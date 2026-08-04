// Channels carrying actual data.
//
// The lifecycle tests next to this file check registration; this one drives a
// real source through `client.mcpStream`, which is the seam a host wires
// (`registerStreamSource`). What it pins is the part that is invisible from
// the outside: whether starting a channel actually subscribes, whether state
// follows, whether stopping lets go, and whether a restart re-subscribes
// rather than leaving a dead channel reporting connected.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/channels/channel_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/models/ui_definition.dart';

void main() {
  late ChannelManager manager;
  late StreamController<dynamic> source;
  var opened = 0;

  setUp(() {
    opened = 0;
    source = StreamController<dynamic>.broadcast();
    manager = ChannelManager()
      ..streamSourceResolver = (uri, params) {
        opened++;
        return source.stream;
      };
  });

  tearDown(() async {
    for (final id in List<String>.from(manager.channelIds)) {
      await manager.disposeChannel(id);
    }
    await source.close();
  });

  ChannelConfig streamConfig({bool autoStart = true}) => ChannelConfig(
        type: 'client.mcpStream',
        autoStart: autoStart,
        params: <String, dynamic>{
          'uri': 'mcp://server/feed',
          'params': <String, dynamic>{'topic': 'temperature'},
        },
      );

  test('autoStart subscribes and payloads reach the channel stream', () async {
    final seen = <dynamic>[];
    await manager.initChannel('feed', streamConfig());
    manager.getStream('feed')!.listen(seen.add);

    source.add(<String, dynamic>{'celsius': 21});
    await Future<void>.delayed(Duration.zero);

    expect(opened, 1, reason: 'the host resolver is what opens the source');
    expect(seen, hasLength(1));
    expect((seen.single as Map)['celsius'], 21);
    expect(manager.getChannelState('feed'), ChannelState.connected);
  });

  test('autoStart: false stays quiet until started', () async {
    final seen = <dynamic>[];
    await manager.initChannel('feed', streamConfig(autoStart: false));
    manager.getStream('feed')!.listen(seen.add);

    source.add('ignored');
    await Future<void>.delayed(Duration.zero);
    expect(seen, isEmpty, reason: 'nothing subscribed yet');
    expect(manager.getChannelState('feed'), ChannelState.disconnected);

    await manager.startChannel('feed');
    source.add('heard');
    await Future<void>.delayed(Duration.zero);

    expect(seen, <dynamic>['heard']);
    expect(manager.getChannelState('feed'), ChannelState.connected);
  });

  test('stopping lets go of the source', () async {
    final seen = <dynamic>[];
    await manager.initChannel('feed', streamConfig());
    manager.getStream('feed')!.listen(seen.add);

    source.add('before');
    await Future<void>.delayed(Duration.zero);
    await manager.stopChannel('feed');
    source.add('after');
    await Future<void>.delayed(Duration.zero);

    expect(seen, <dynamic>['before'],
        reason: 'a stopped channel that keeps delivering is a leak the '
            'document cannot see');
    expect(manager.getChannelState('feed'), ChannelState.disconnected);
  });

  test('restart re-subscribes rather than reporting a dead channel', () async {
    final seen = <dynamic>[];
    await manager.initChannel('feed', streamConfig());
    manager.getStream('feed')!.listen(seen.add);

    await manager.restartChannel('feed');
    source.add('after restart');
    await Future<void>.delayed(Duration.zero);

    expect(seen, contains('after restart'));
    expect(manager.getChannelState('feed'), ChannelState.connected);
    expect(opened, greaterThan(1), reason: 'a restart opens the source again');
  });

  test('toggle turns a running channel off and a stopped one on', () async {
    await manager.initChannel('feed', streamConfig());
    expect(manager.getChannelState('feed'), ChannelState.connected);

    await manager.toggleChannel('feed');
    expect(manager.getChannelState('feed'), ChannelState.disconnected);

    await manager.toggleChannel('feed');
    expect(manager.getChannelState('feed'), ChannelState.connected);
  });

  test('a source that errors is reported through onError', () async {
    Object? reported;
    manager.onError = (channelId, error) => reported = error;

    await manager.initChannel('feed', streamConfig());
    source.addError(StateError('source failed'));
    await Future<void>.delayed(Duration.zero);

    expect(reported, isNotNull,
        reason: 'an error the manager swallows leaves the document showing '
            'its last good value forever');
  });

  test('disposing while running unsubscribes and drops the stream', () async {
    await manager.initChannel('feed', streamConfig());
    await manager.disposeChannel('feed');

    expect(manager.hasChannel('feed'), isFalse);
    expect(manager.getStream('feed'), isNull);
    expect(() => source.add('after dispose'), returnsNormally);
  });
}
