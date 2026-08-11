// `WebSocketChannel` — 5% covered, and the 95% was the connection itself.
//
// This is the channel a document uses when a server pushes at it continuously,
// so its failure modes are the ones that look like "the screen froze": a
// connect that never reports, a reconnect that gives up silently, a heartbeat
// that stops without saying so.
//
// Tested against a REAL socket, served in-process on the loopback interface.
// Faking `WebSocket.connect` would test the fake; a loopback server tests the
// same code path a device runs, and costs a few milliseconds.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_mcp_ui_runtime/src/channels/channel_types/websocket_channel.dart';
import 'package:flutter_test/flutter_test.dart';

/// A one-connection echo server that the test drives.
class _Server {
  _Server(this._httpServer);

  final HttpServer _httpServer;
  final _sockets = <WebSocket>[];
  final connections = StreamController<WebSocket>.broadcast();

  static Future<_Server> start({
    void Function(WebSocket socket, dynamic message)? onMessage,
  }) async {
    final httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final server = _Server(httpServer);
    httpServer.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      server._sockets.add(socket);
      server.connections.add(socket);
      socket.listen(
        (message) => onMessage?.call(socket, message),
        onDone: () => server._sockets.remove(socket),
      );
    });
    return server;
  }

  String get url => 'ws://127.0.0.1:${_httpServer.port}';

  void push(Object message) {
    for (final socket in _sockets) {
      socket.add(message);
    }
  }

  Future<void> dropClients() async {
    for (final socket in [..._sockets]) {
      await socket.close();
    }
    _sockets.clear();
  }

  Future<void> close() async {
    await dropClients();
    await connections.close();
    await _httpServer.close(force: true);
  }
}

void main() {
  late _Server server;

  setUp(() async => server = await _Server.start());
  tearDown(() async => server.close());

  Future<dynamic> firstWhere(
    Stream<dynamic> stream,
    bool Function(dynamic) test, {
    Duration timeout = const Duration(seconds: 5),
  }) =>
      stream.firstWhere(test).timeout(timeout);

  test('start connects, and the `connected` event cannot be observed', () async {
    final channel = WebSocketChannel(url: server.url, autoReconnect: false);
    addTearDown(channel.stop);

    await channel.start();
    expect(channel.isActive, isTrue);

    // Worth pinning rather than papering over: `start()` creates the broadcast
    // controller AND awaits `_connect()`, which emits `{type: connected}`
    // before `start` returns. A broadcast stream drops events that have no
    // listener, and the stream cannot be reached until `start` gives it back —
    // so that first event is unobservable by construction. A document showing
    // "connected" has to read `isActive`, not wait for the event.
    final events = <dynamic>[];
    final subscription = channel.stream.listen(events.add);
    addTearDown(subscription.cancel);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(events.where((e) => e is Map && e['type'] == 'connected'), isEmpty);
  });

  test('a JSON message arrives decoded, a plain one arrives as text',
      () async {
    final channel = WebSocketChannel(url: server.url, autoReconnect: false);
    addTearDown(channel.stop);
    await channel.start();

    final received = <dynamic>[];
    final subscription = channel.stream.listen(received.add);
    addTearDown(subscription.cancel);

    server.push(jsonEncode({'temperature': 21}));
    server.push('just text');
    await Future<void>.delayed(const Duration(milliseconds: 200));

    // Every payload arrives wrapped: `{type: message, data: …, timestamp: …}`.
    // The wrapper is what a document binds through (`{{channels.x.data}}`), so
    // it is part of the contract rather than noise.
    final payloads = received
        .whereType<Map>()
        .where((e) => e['type'] == 'message')
        .map((e) => e['data'])
        .toList();

    expect(
      payloads.any((p) =>
          p is Map && p['temperature'] == 21 && p.length == 1),
      isTrue,
      reason: 'a document binds to fields, so JSON has to arrive decoded',
    );
    expect(payloads, contains('just text'),
        reason: 'and text that is not JSON must not be dropped for it');
  });

  test('send reaches the server', () async {
    final fromClient = Completer<dynamic>();
    await server.close();
    server = await _Server.start(
      onMessage: (_, message) {
        if (!fromClient.isCompleted) fromClient.complete(message);
      },
    );

    final channel = WebSocketChannel(url: server.url, autoReconnect: false);
    addTearDown(channel.stop);
    await channel.start();

    channel.send({'command': 'refresh'});
    expect(await fromClient.future.timeout(const Duration(seconds: 5)),
        jsonEncode({'command': 'refresh'}),
        reason: 'a map is sent as JSON — the server cannot read a Dart Map');
  });

  test('sending before the socket is up throws, and that is the contract', () {
    // Pinned as it is. A `channel.send` action fired from a button before the
    // connection lands raises this, and the action handler is what turns it
    // into a reported failure — the widget must not have to guard it itself,
    // but it must also not silently swallow the message.
    final channel = WebSocketChannel(url: server.url, autoReconnect: false);
    expect(() => channel.send('too early'), throwsStateError);
  });

  test('a dropped connection is announced', () async {
    final channel = WebSocketChannel(url: server.url, autoReconnect: false);
    addTearDown(channel.stop);
    await channel.start();

    await server.dropClients();
    final event = await firstWhere(
      channel.stream,
      (e) => e is Map && (e['type'] == 'disconnected' || e['type'] == 'error'),
    );

    expect(event['type'], isNotNull);
    expect(channel.isActive, isFalse,
        reason: 'a channel that reports active after the socket is gone makes '
            'every downstream decision on a lie');
  });

  test('autoReconnect dials again after a drop', () async {
    final channel = WebSocketChannel(
      url: server.url,
      autoReconnect: true,
      reconnectDelay: 50,
      maxReconnectAttempts: 3,
    );
    addTearDown(channel.stop);

    final connects = <dynamic>[];
    await channel.start();
    final subscription = channel.stream.listen((event) {
      if (event is Map && event['type'] == 'connected') connects.add(event);
    });
    addTearDown(subscription.cancel);

    await Future<void>.delayed(const Duration(milliseconds: 100));
    await server.dropClients();
    await Future<void>.delayed(const Duration(milliseconds: 800));

    // The first `connected` is unobservable (see the first test); the RECONNECT
    // is the one a listener can see, and it is the one that matters.
    expect(connects, isNotEmpty,
        reason: 'the point of autoReconnect is the second connection');
    expect(channel.isActive, isTrue);
  });

  test('a connection that cannot be made is reported, not thrown', () async {
    // Port 1 on loopback: nothing listens there, and the failure has to reach
    // the document rather than the zone.
    final channel = WebSocketChannel(
      url: 'ws://127.0.0.1:1',
      autoReconnect: false,
    );
    addTearDown(channel.stop);

    await channel.start();
    // The error is emitted inside `start()` for the same reason `connected` is
    // — what a caller can check afterwards is the state.
    expect(channel.isActive, isFalse);
  });

  test('stop closes the socket and the stream stays quiet', () async {
    final channel = WebSocketChannel(url: server.url, autoReconnect: false);
    await channel.start();

    await channel.stop();
    expect(channel.isActive, isFalse);

    // Nothing after a stop: a channel that keeps delivering is why a disposed
    // page can still write to state.
    final after = <dynamic>[];
    final subscription = channel.stream.listen(after.add);
    addTearDown(subscription.cancel);
    server.push('after stop');
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(after, isEmpty);
  });

  test('a heartbeat is sent on the declared interval', () async {
    final beats = <dynamic>[];
    await server.close();
    server = await _Server.start(onMessage: (_, message) => beats.add(message));

    final channel = WebSocketChannel(
      url: server.url,
      autoReconnect: false,
      heartbeatInterval: 60,
      heartbeatMessage: 'ping',
    );
    addTearDown(channel.stop);

    await channel.start();
    await Future<void>.delayed(const Duration(milliseconds: 250));

    expect(beats.where((b) => b == 'ping').length, greaterThanOrEqualTo(2),
        reason: 'a heartbeat that stops is how a half-open connection stays '
            'undetected for hours');
  });

  test('a scalar is sent as text and a map as JSON', () async {
    final seen = <dynamic>[];
    final server = await _Server.start(
      onMessage: (socket, message) => seen.add(message),
    );
    addTearDown(server.close);

    final channel = WebSocketChannel(url: server.url, autoReconnect: false);
    addTearDown(channel.stop);
    await channel.start();

    channel.send('plain');
    channel.send(<String, dynamic>{'v': 1});
    channel.send(<dynamic>[1, 2]);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(seen, contains('plain'),
        reason: 'a scalar sent as JSON would arrive quoted, and the server '
            'would read a different value than the document sent');
    expect(seen, contains('{"v":1}'));
    expect(seen, contains('[1,2]'));
  });

  test('sending before the socket is open is refused by name', () {
    final channel = WebSocketChannel(url: 'ws://127.0.0.1:1', autoReconnect: false);

    expect(() => channel.send('x'), throwsStateError,
        reason: 'a send that vanishes leaves the document believing the other '
            'end heard it');
  });

  test('a peer that goes away leaves the channel inactive', () async {
    final server = await _Server.start();
    addTearDown(server.close);

    final channel = WebSocketChannel(url: server.url, autoReconnect: false);
    addTearDown(channel.stop);
    await channel.start();

    final errors = <Object>[];
    channel.stream.listen((_) {}, onError: errors.add);

    // Closing the peer abruptly is what a dropped connection looks like.
    server.push('ok');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await server.dropClients();
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(channel.isActive, isFalse,
        reason: 'a channel that still reports itself active after the peer '
            'went away leaves the page waiting for data that cannot come');
  });

  test('a heartbeat with no answer reports a timeout', () async {
    // The server never answers, which is exactly the half-open case the
    // timeout exists to catch.
    final server = await _Server.start();
    addTearDown(server.close);

    final channel = WebSocketChannel(
      url: server.url,
      autoReconnect: false,
      // The timeout has to be well inside the interval: the next ping is
      // what cancels the previous timer, so equal values race.
      heartbeatInterval: 200,
      heartbeatTimeout: 50,
    );
    addTearDown(channel.stop);

    final errors = <Object>[];
    await channel.start();
    channel.stream.listen((_) {}, onError: errors.add);

    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(errors.map((e) => e.toString()), contains('Heartbeat timeout'),
        reason: 'a heartbeat that pings and never checks for the answer '
            'detects nothing at all');
  });

  test('a heartbeat timeout with autoReconnect on dials again', () async {
    // The half-open case is the one reconnection exists for: the socket is
    // still open as far as the OS is concerned, so nothing arrives as a
    // disconnect, and only the unanswered heartbeat notices. A timeout that
    // reports the error but does not redial leaves the page dead on a
    // connection that will never carry anything again.
    final server = await _Server.start();
    addTearDown(server.close);

    final channel = WebSocketChannel(
      url: server.url,
      autoReconnect: true,
      maxReconnectAttempts: 2,
      reconnectDelay: 20,
      heartbeatInterval: 400,
      heartbeatTimeout: 40,
    );
    addTearDown(channel.stop);

    await channel.start();
    final events = <dynamic>[];
    channel.stream.listen((e) => events.add(e), onError: (_) {});

    await Future<void>.delayed(const Duration(milliseconds: 600));

    expect(events.whereType<Map>().map((e) => e['type']),
        contains('reconnecting'),
        reason: 'the timeout has to stop the dead heartbeat and schedule a '
            'new connection, not just complain');
  });

  test('a peer that breaks the protocol is announced as a disconnect',
      () async {
    // Why this channel has no `onError` arm on its socket.
    //
    // A client `WebSocket` turns every failure it can have into a close: the
    // SDK's reader catches the error, sends a close frame, and closes its
    // controller. Nothing is ever added as an error, so a handler there would
    // be a report that never fires — and a reader of this code would take it
    // for the place failures are reported. `disconnected`, with the close
    // code, is the report.
    //
    // A server that upgrades by hand, so the test keeps the raw socket and
    // can put bytes on it that no well-behaved peer would send.
    // `WebSocketTransformer.upgrade` would give back a `WebSocket`, which can
    // only send valid frames.
    final raw = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => raw.close(force: true));
    Socket? peer;

    raw.listen((request) async {
      final key = request.headers.value('sec-websocket-key')!;
      final accept = base64.encode(sha1
          .convert(utf8.encode('${key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11'))
          .bytes);
      final socket = await request.response.detachSocket(writeHeaders: false);
      peer = socket;
      socket.write('HTTP/1.1 101 Switching Protocols\r\n'
          'Upgrade: websocket\r\n'
          'Connection: Upgrade\r\n'
          'Sec-WebSocket-Accept: $accept\r\n\r\n');
      await socket.flush();
    });

    final channel = WebSocketChannel(
      url: 'ws://127.0.0.1:${raw.port}',
      autoReconnect: false,
    );
    addTearDown(channel.stop);
    await channel.start();
    expect(channel.isActive, isTrue,
        reason: 'the hand-rolled handshake has to be accepted, or this test '
            'is measuring a failed connection instead of a broken frame');

    final events = <dynamic>[];
    final done = Completer<void>();
    channel.stream.listen((Object? e) {
      events.add(e);
      if (e is Map && e['type'] == 'disconnected' && !done.isCompleted) {
        done.complete();
      }
    }, onError: (Object e) {
      events.add(e);
      if (!done.isCompleted) done.complete();
    });

    // FIN + all three reserved bits + a reserved opcode: rejected by any
    // conforming reader.
    peer!.add(<int>[0xFF, 0x00]);
    await peer!.flush();

    await done.future.timeout(const Duration(seconds: 5),
        onTimeout: () => throw TestFailure(
            'the socket failed and the document was told nothing — a screen '
            'bound to this channel waits forever'));

    expect(events.whereType<Map>().map((e) => e['type']),
        contains('disconnected'),
        reason: 'this is the only report a broken connection produces, so if '
            'it is missing the page has no way to know');
    expect(channel.isActive, isFalse);
  });
}
