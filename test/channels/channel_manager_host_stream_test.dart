// What a channel is FOR: data arriving from outside and reaching the document.
//
// The lifecycle file beside this one covers which channel gets built and when
// it is disposed. This one covers the half that has never been exercised —
// a live source pushing values through the manager's hooks and out to a
// subscriber, and stopping when the subscription is dropped. A channel whose
// lifecycle is correct and whose data never arrives is a screen that has
// quietly stopped updating.
//
// The source is supplied through `client.mcpStream`, whose resolver the HOST
// registers (`registerStreamSource`). Nothing is bent for the test: that is
// the seam a real host uses, and the alternative — a file watcher or a poller
// — would measure the OS instead of the manager.

import 'dart:async';

import 'package:flutter_mcp_ui_runtime/src/channels/channel_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/models/ui_definition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ChannelManager manager;
  late StreamController<dynamic> source;

  Future<void> registerStreamChannel(String id) => manager.initChannel(
        id,
        ChannelConfig(
          type: 'client.mcpStream',
          params: {'uri': 'mcp://feed/$id'},
          // `autoStart` defaults to FALSE on the config object (the document's
          // `lifecycle.autoStart` is what usually turns it on), so a channel
          // built without it is registered and silent — which is exactly the
          // "lifecycle correct, data never arrives" shape this file is about.
          autoStart: true,
        ),
      );

  setUp(() {
    source = StreamController<dynamic>.broadcast();
    manager = ChannelManager()
      ..streamSourceResolver = (uri, params) => source.stream;
  });

  tearDown(() async {
    await manager.dispose();
    await source.close();
  });

  test('a subscriber hears what the source pushes', () async {
    await registerStreamChannel('feed');
    final heard = <dynamic>[];
    manager.subscribe('feed', heard.add);

    source.add({'temperature': 21});
    await Future<void>.delayed(Duration.zero);

    expect(heard, [
      {'temperature': 21}
    ]);
  });

  test('the manager reports data, errors and connection through its hooks',
      () async {
    final data = <dynamic>[];
    final errors = <dynamic>[];
    final connected = <String>[];

    manager.onData = (id, d) => data.add(d);
    manager.onError = (id, e) => errors.add(e);
    manager.onConnect = connected.add;

    await registerStreamChannel('feed');
    source.add(1);
    source.addError(StateError('dropped'));
    await Future<void>.delayed(Duration.zero);

    expect(data, [1]);
    expect(errors, hasLength(1),
        reason: 'an error on the wire has to reach the document, or the screen '
            'just stops updating with no reason given');
    expect(connected, contains('feed'));
  });

  test('an unsubscribed listener stops hearing', () async {
    await registerStreamChannel('feed');
    final heard = <dynamic>[];
    final subscription = manager.subscribe('feed', heard.add);

    source.add(1);
    await Future<void>.delayed(Duration.zero);

    manager.unsubscribeListener(subscription!);
    source.add(2);
    await Future<void>.delayed(Duration.zero);

    expect(heard, [1], reason: 'a listener that keeps firing after the page '
        'that owned it is gone is a leak with a callback attached');
  });

  test('two subscribers both hear the same value', () async {
    await registerStreamChannel('feed');
    final a = <dynamic>[];
    final b = <dynamic>[];
    manager.subscribe('feed', a.add);
    manager.subscribe('feed', b.add);

    source.add('tick');
    await Future<void>.delayed(Duration.zero);

    expect(a, ['tick']);
    expect(b, ['tick'],
        reason: 'the stream is broadcast: a second widget binding to the same '
            'channel must not steal the first one\'s data');
  });

  test('subscribing to a channel that does not exist answers null', () async {
    expect(manager.subscribe('ghost', (_) {}), isNull);
  });

  test('a disposed channel stops delivering', () async {
    await registerStreamChannel('feed');
    final heard = <dynamic>[];
    manager.subscribe('feed', heard.add);

    source.add(1);
    await Future<void>.delayed(Duration.zero);
    await manager.disposeChannel('feed');
    source.add(2);
    await Future<void>.delayed(Duration.zero);

    expect(heard, [1]);
  });
}
