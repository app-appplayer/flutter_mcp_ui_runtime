// The `{{resources.*}}` and `{{channels.*}}` namespaces.
//
// Both are read-only views a document binds to and never writes: a resource
// the server pushed, a channel's latest payload. What matters is what they say
// when the thing is not there — a live gauge bound to a channel that was never
// declared has to read empty, not stale.

import 'package:flutter_mcp_ui_runtime/src/binding/channel_binding_resolver.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/resource_binding_resolver.dart';
import 'package:flutter_mcp_ui_runtime/src/channels/channel_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/models/ui_definition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('{{resources.*}}', () {
    late ResourceBindingResolver resolver;

    setUp(() {
      resolver = ResourceBindingResolver();
      resolver.updateResourceData('config', <String, dynamic>{
        'theme': <String, dynamic>{'mode': 'dark'},
        'rows': <dynamic>[1, 2],
      });
    });

    test('only resources expressions are claimed', () {
      expect(resolver.isResourceBinding('{{resources.config}}'), isTrue);
      expect(resolver.isResourceBinding('{{state.config}}'), isFalse);
      expect(resolver.isResourceBinding('{{resources.config'), isFalse);
      expect(resolver.extractPath('{{resources.config.theme}}'),
          'config.theme');
      expect(resolver.extractPath('{{other}}'), isNull);
      expect(resolver.resolve('{{other}}'), isNull);
    });

    test('a bare id is the whole resource', () {
      expect(resolver.resolve('{{resources.config}}'), <String, dynamic>{
        'theme': <String, dynamic>{'mode': 'dark'},
        'rows': <dynamic>[1, 2],
      });
    });

    test('a nested path walks into it', () {
      expect(resolver.resolve('{{resources.config.theme.mode}}'), 'dark');
    });

    test('a path through a scalar stops rather than guessing', () {
      expect(resolver.resolve('{{resources.config.theme.mode.deeper}}'),
          isNull);
    });

    test('a resource nobody loaded is empty, not an error', () {
      expect(resolver.resolve('{{resources.missing}}'), isNull);
      expect(resolver.resolve('{{resources.missing.field}}'), isNull);
      expect(resolver.hasResource('missing'), isFalse);
    });

    test('what is loaded can be listed, removed and cleared', () {
      resolver.updateResourceData('settings', <String, dynamic>{'a': 1});

      expect(resolver.loadedResources, containsAll(<String>['config', 'settings']));

      resolver.removeResourceData('settings');
      expect(resolver.hasResource('settings'), isFalse,
          reason: 'a resource the document unsubscribed from must stop '
              'answering, or the page shows data it no longer receives');

      resolver.clearAll();
      expect(resolver.loadedResources, isEmpty);
    });
  });

  group('{{channels.*}}', () {
    late ChannelManager channels;
    late ChannelBindingResolver resolver;

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
      resolver = ChannelBindingResolver()..setChannelManager(channels);
      resolver.updateChannelData('telemetry', <String, dynamic>{
        'temperature': 21.5,
        'sensor': <String, dynamic>{'id': 'a1'},
      });
    });

    tearDown(() => channels.dispose());

    test('only channels expressions are claimed', () {
      expect(resolver.isChannelBinding('{{channels.telemetry}}'), isTrue);
      expect(resolver.isChannelBinding('{{state.telemetry}}'), isFalse);
      expect(resolver.extractPath('{{channels.telemetry.temperature}}'),
          'telemetry.temperature');
      expect(resolver.extractPath('{{state.x}}'), isNull);
      expect(resolver.resolve('{{state.x}}'), isNull);
    });

    test('a bare id is the latest payload', () {
      expect((resolver.resolve('{{channels.telemetry}}') as Map)['temperature'],
          21.5);
    });

    test('a field and a nested field are both reachable', () {
      expect(resolver.resolve('{{channels.telemetry.temperature}}'), 21.5);
      expect(resolver.resolve('{{channels.telemetry.sensor.id}}'), 'a1');
    });

    test('`active` and `state` describe the channel itself', () {
      expect(resolver.resolve('{{channels.telemetry.active}}'), isTrue);
      expect(resolver.resolve('{{channels.telemetry.state}}'), 'disconnected',
          reason: 'a declared channel that has not started is disconnected — '
              'the badge a document shows beside a live view');
    });

    test('a channel that was never declared answers empty', () {
      expect(resolver.resolve('{{channels.nope}}'), isNull,
          reason: 'a gauge bound to a channel nobody declared must read '
              'empty rather than holding whatever was there before');
      expect(resolver.resolve('{{channels.nope.active}}'), isNull);
    });

    test('a field of a channel with no payload yet is empty', () {
      resolver.clearChannelData('telemetry');

      expect(resolver.resolve('{{channels.telemetry.temperature}}'), isNull);
      expect(resolver.resolve('{{channels.telemetry.active}}'), isTrue,
          reason: 'the channel is still declared; only its data is missing');
    });

    test('a path through a scalar stops', () {
      expect(resolver.resolve('{{channels.telemetry.temperature.deeper}}'),
          isNull);
    });

    test('clearing drops every cached payload', () {
      resolver.clearAll();

      expect(resolver.resolve('{{channels.telemetry}}'), isNull);
    });

    test('with no manager wired the data still answers', () {
      final detached = ChannelBindingResolver()
        ..updateChannelData('telemetry', <String, dynamic>{'v': 1});

      expect(detached.resolve('{{channels.telemetry.v}}'), 1,
          reason: 'a host that feeds payloads directly, with no channel '
              'manager, is a supported shape');
      expect(detached.resolve('{{channels.telemetry.active}}'), isFalse);
      expect(detached.resolve('{{channels.telemetry.state}}'), 'disconnected');
    });
  });
}
