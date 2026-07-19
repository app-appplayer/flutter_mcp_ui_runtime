import 'dart:async';

import 'package:flutter_mcp_ui_runtime/src/channels/channel_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/channels/channel_types/mcp_stream_channel.dart';
import 'package:flutter_mcp_ui_runtime/src/models/ui_definition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('McpStreamChannel', () {
    test('forwards every source push as a channel message', () async {
      final source = StreamController<dynamic>.broadcast();
      final channel = McpStreamChannel(
        uri: 'ble://scan',
        open: (uri, params) => source.stream,
      );

      final received = <dynamic>[];
      await channel.start();
      final sub = channel.stream.listen(received.add);

      source.add({'deviceId': 'p1', 'rssi': -42});
      source.add({'deviceId': 'p2', 'rssi': -70});
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(2));
      expect(received.first['deviceId'], 'p1');
      expect(channel.isActive, isTrue);

      await sub.cancel();
      await channel.stop();
      await source.close();
      expect(channel.isActive, isFalse);
    });

    test('passes uri + subscribe params to the resolver', () async {
      String? seenUri;
      Map<String, dynamic>? seenParams;
      final channel = McpStreamChannel(
        uri: 'ble://scan',
        params: const {'minRssi': -70},
        open: (uri, params) {
          seenUri = uri;
          seenParams = params;
          return const Stream<dynamic>.empty();
        },
      );

      await channel.start();
      expect(seenUri, 'ble://scan');
      expect(seenParams, {'minRssi': -70});
      await channel.stop();
    });

    test('throws when no source is registered for the uri', () async {
      final channel = McpStreamChannel(
        uri: 'ble://scan',
        open: (uri, params) => null,
      );
      expect(channel.start, throwsStateError);
    });
  });

  group('ChannelManager client.mcpStream', () {
    test('creates a live channel through the injected resolver', () async {
      final source = StreamController<dynamic>.broadcast();
      final manager = ChannelManager()
        ..streamSourceResolver = (uri, params) => source.stream;

      final delivered = <dynamic>[];
      manager.onData = (_, data) => delivered.add(data);

      await manager.initChannel(
        'scan',
        ChannelConfig(
          type: 'client.mcpStream',
          params: const {'uri': 'ble://scan', 'params': {'minRssi': -70}},
        ),
      );
      await manager.startChannel('scan');

      source.add({'name': 'Galaxy', 'rssi': -42});
      await Future<void>.delayed(Duration.zero);

      expect(delivered, isNotEmpty);
      expect(delivered.last['name'], 'Galaxy');

      await manager.dispose();
      await source.close();
    });

    test('creates the channel even before a resolver is wired (late-bind)',
        () async {
      // The host registers the source AFTER runtime init, so channel creation
      // must not require the resolver — resolution is deferred to start().
      final manager = ChannelManager();
      await manager.initChannel(
        'scan',
        ChannelConfig(type: 'client.mcpStream', params: const {'uri': 'ble://scan'}),
      );
      // Wiring the resolver afterwards makes the channel functional.
      final source = StreamController<dynamic>.broadcast();
      manager.streamSourceResolver = (uri, params) => source.stream;
      final delivered = <dynamic>[];
      manager.onData = (_, data) => delivered.add(data);
      await manager.startChannel('scan');
      source.add({'name': 'Late'});
      await Future<void>.delayed(Duration.zero);
      expect(delivered.last['name'], 'Late');
      await manager.dispose();
      await source.close();
    });
  });
}
