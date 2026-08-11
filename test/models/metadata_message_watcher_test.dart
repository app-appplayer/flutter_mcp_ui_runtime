// Three small models and one resolver, each of which some other component
// trusts without checking: `DslAppMetadata` (what a launcher shows for an
// app), `ChannelMessage` (what crosses a live channel), `StateWatcher` (what
// decides whether a watch fires) and the `{{permissions.*}}` resolver (what a
// document reads to decide whether to offer a capability at all).

import 'package:flutter_mcp_ui_runtime/src/binding/permission_binding_resolver.dart';
import 'package:flutter_mcp_ui_runtime/src/channels/channel_message.dart';
import 'package:flutter_mcp_ui_runtime/src/models/app_metadata.dart';
import 'package:flutter_mcp_ui_runtime/src/models/ui_definition.dart';
import 'package:flutter_mcp_ui_runtime/src/permissions/permission_checker.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_watcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DslAppMetadata', () {
    test('reads the §11.1 shape, and survives the round trip', () {
      const json = <String, dynamic>{
        'id': 'com.example.jobs',
        'title': 'Jobs',
        'version': '2.1.0',
        'description': 'Field jobs',
        'icon': 'https://example.com/icon.png',
        'category': 'productivity',
        'publisher': <String, dynamic>{
          'name': 'Example Ltd',
          'website': 'https://example.com',
          'logo': 'https://example.com/logo.png',
          'email': 'hello@example.com',
        },
        'timestamps': <String, dynamic>{
          'createdAt': '2026-01-02T03:04:05Z',
          'updatedAt': '2026-02-03T04:05:06Z',
        },
        'screenshots': <dynamic>['a.png', 'b.png'],
      };

      final metadata = DslAppMetadata.fromJson(json);
      expect(metadata.id, 'com.example.jobs');
      expect(metadata.title, 'Jobs');
      expect(metadata.version, '2.1.0');
      expect(metadata.publisher!.url, 'https://example.com');
      expect(metadata.timestamps!.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(metadata.screenshots, ['a.png', 'b.png']);

      final out = metadata.toJson();
      expect(out['publisher']['website'], 'https://example.com',
          reason: '§11.2 names the field `website`; emitting `url` would make '
              'the runtime unable to read back what it just wrote');
      expect(out['timestamps']['createdAt'], '2026-01-02T03:04:05.000Z');
      expect(DslAppMetadata.fromJson(out), metadata);
    });

    test('a publisher stored the bundle-manifest way is read too', () {
      final metadata = DslAppMetadata.fromJson(<String, dynamic>{
        'title': 'Jobs',
        'version': '1.0.0',
        'publisher': <String, dynamic>{
          'name': 'Example Ltd',
          'url': 'https://example.com',
        },
      });

      expect(metadata.publisher!.url, 'https://example.com');
    });

    test('a nameless publisher is no publisher', () {
      expect(
          DslAppMetadata.fromJson(<String, dynamic>{
            'title': 'Jobs',
            'version': '1.0.0',
            'publisher': <String, dynamic>{'website': 'https://example.com'},
          }).publisher,
          isNull,
          reason: 'a card that shows a link with nobody behind it is worse '
              'than a card with no publisher line');

      expect(
          DslAppMetadata.fromJson(<String, dynamic>{
            'title': 'Jobs',
            'version': '1.0.0',
            'publisher': 'Example Ltd',
          }).publisher,
          isNull);
    });

    test('`name` stands in for a missing `title`, and the rest may be absent',
        () {
      final metadata =
          DslAppMetadata.fromJson(<String, dynamic>{'name': 'Jobs'});

      expect(metadata.title, 'Jobs');
      expect(metadata.version, '');
      expect(metadata.timestamps, isNull);
      expect(metadata.splash, isNull);
      expect(metadata.screenshots, isNull);
      expect(metadata.toJson().containsKey('description'), isFalse,
          reason: 'an absent field must not be emitted as null — §11.6 shapes '
              'are read by servers that distinguish the two');
    });

    test('unparseable timestamps are dropped rather than guessed at', () {
      final stamps = TimestampInfo.fromJson(<String, dynamic>{
        'createdAt': 'last Tuesday',
        'updatedAt': 1234567,
      });

      expect(stamps.createdAt, isNull);
      expect(stamps.updatedAt, isNull);
      expect(stamps.toJson(), isEmpty);
    });

    test('local timestamps are normalised to UTC', () {
      final stamps = TimestampInfo.fromJson(
          <String, dynamic>{'createdAt': '2026-01-02T03:04:05+09:00'});

      expect(stamps.createdAt, DateTime.utc(2026, 1, 1, 18, 4, 5));
      expect(stamps.toJson()['createdAt'], '2026-01-01T18:04:05.000Z');
    });

    test('equality ignores the fields a launcher does not key on', () {
      DslAppMetadata build({List<String>? screenshots}) => DslAppMetadata(
            id: 'a',
            title: 'Jobs',
            version: '1.0.0',
            screenshots: screenshots,
          );

      expect(build(), build(screenshots: <String>['a.png']));
      expect(build().hashCode, build(screenshots: <String>['a.png']).hashCode);
      expect(build(), isNot(DslAppMetadata(title: 'Jobs', version: '1.0.1')));
    });
  });

  group('ChannelMessage', () {
    test('inbound and outbound differ only in direction, and ids are unique',
        () {
      final inbound = ChannelMessage.inbound('telemetry', {'v': 1});
      final outbound = ChannelMessage.outbound('telemetry', {'v': 1});

      expect(inbound.direction, ChannelMessageDirection.serverToClient);
      expect(outbound.direction, ChannelMessageDirection.clientToServer);
      expect(inbound.id, isNot(outbound.id),
          reason: 'two messages sharing an id let a de-duplicating consumer '
              'drop one of them');
      expect(inbound.type, ChannelMessageType.message);
      expect(inbound.sequence, isNull);
    });

    test('a message survives the round trip through JSON', () {
      final original = ChannelMessage.outbound(
        'telemetry',
        {'temperature': 21.5},
        sequence: 7,
        type: ChannelMessageType.control,
      );

      final restored = ChannelMessage.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.channel, 'telemetry');
      expect(restored.direction, ChannelMessageDirection.clientToServer);
      expect(restored.type, ChannelMessageType.control);
      expect(restored.payload, {'temperature': 21.5});
      expect(restored.sequence, 7);
      expect(restored.timestamp, original.timestamp,
          reason: 'the timestamp is what orders a replayed channel; a receiver '
              'that stamps its own arrival time reorders history');
    });

    test('an absent sequence is left out rather than sent as null', () {
      expect(ChannelMessage.inbound('t', 1).toJson().containsKey('sequence'),
          isFalse);
    });

    test('a message missing every field still parses', () {
      final message = ChannelMessage.fromJson(<String, dynamic>{});

      expect(message.id, startsWith('msg_'));
      expect(message.channel, '');
      expect(message.direction, ChannelMessageDirection.serverToClient,
          reason: 'inbound is the safe reading — treating an unlabelled '
              'message as outbound would send it back to the server');
      expect(message.type, ChannelMessageType.message);
      expect(message.payload, isNull);
    });

    test('the message types are read from their names', () {
      ChannelMessageType typeOf(String? raw) =>
          ChannelMessage.fromJson(<String, dynamic>{'type': raw}).type;

      expect(typeOf('control'), ChannelMessageType.control);
      expect(typeOf('error'), ChannelMessageType.error);
      expect(typeOf('message'), ChannelMessageType.message);
      expect(typeOf('anything else'), ChannelMessageType.message);
      expect(typeOf(null), ChannelMessageType.message);
    });

    test('toString names the message without dumping its payload', () {
      final message =
          ChannelMessage.outbound('telemetry', {'secret': 'x'}, sequence: 3);

      final text = message.toString();
      expect(text, contains('telemetry'));
      expect(text, contains('seq=3'));
      expect(text, isNot(contains('secret')),
          reason: 'a channel carries whatever the document sends; logging the '
              'payload by default puts it in every log line');
    });
  });

  group('StateWatcher', () {
    test('the first trigger only records — it does not fire', () async {
      final seen = <List<dynamic>>[];
      final watcher = StateWatcher(
        path: 'count',
        onChange: (newValue, oldValue) async => seen.add([newValue, oldValue]),
      );

      await watcher.trigger(1, null);

      expect(seen, isEmpty,
          reason: 'the first value is what the watch starts FROM; firing on it '
              'would run every watcher once at load');
      expect(watcher.isInitialized, isTrue);
      expect(watcher.lastValue, 1);
    });

    test('a change fires, an unchanged value does not', () async {
      final seen = <List<dynamic>>[];
      final watcher = StateWatcher(
        path: 'count',
        onChange: (newValue, oldValue) async => seen.add([newValue, oldValue]),
      );

      await watcher.trigger(1, null);
      await watcher.trigger(2, 1);
      await watcher.trigger(2, 2);

      expect(seen, [
        [2, 1]
      ]);
      expect(watcher.lastValue, 2);
    });

    test('a condition that refuses stops the callback', () async {
      var fired = 0;
      final watcher = StateWatcher(
        path: 'count',
        condition: (newValue, oldValue) => (newValue as int) > 10,
        onChange: (_, __) async => fired++,
      );

      await watcher.trigger(1, null);
      await watcher.trigger(2, 1);
      expect(fired, 0);

      await watcher.trigger(20, 2);
      expect(fired, 1);
    });

    test('a debounced watcher fires once, with the last value', () async {
      final seen = <dynamic>[];
      final watcher = StateWatcher(
        path: 'query',
        debounceMs: 20,
        onChange: (newValue, _) async => seen.add(newValue),
      );

      await watcher.trigger('a', null);
      await watcher.trigger('ab', 'a');
      await watcher.trigger('abc', 'ab');

      expect(seen, isEmpty, reason: 'nothing fires while typing continues');

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(seen, ['abc'],
          reason: 'a debounce that fires every keystroke is not a debounce; '
              'one that fires the FIRST value searches for what was abandoned');
      expect(watcher.lastValue, 'abc');
    });

    test('a callback that throws is rethrown rather than swallowed', () async {
      final watcher = StateWatcher(
        path: 'count',
        onChange: (_, __) async => throw StateError('handler broke'),
      );

      await watcher.trigger(1, null);
      await expectLater(watcher.trigger(2, 1), throwsStateError);
    });

    test('fromConfig reads the path and the debounce', () {
      final watcher = StateWatcher.fromConfig(
          <String, dynamic>{'path': 'jobs.count', 'debounceMs': 250});

      expect(watcher.path, 'jobs.count');
      expect(watcher.debounceMs, 250);
      expect(StateWatcher.fromConfig(<String, dynamic>{'path': 'a'}).debounceMs,
          0);
      expect(watcher.toString(), contains('jobs.count'));
    });
  });

  group('StateWatcherGroup', () {
    test('holds watchers, and hands back a list that cannot be edited', () {
      final group = StateWatcherGroup(name: 'jobs');
      final watcher = StateWatcher(path: 'a', onChange: (_, __) async {});

      group.add(watcher);
      expect(group.count, 1);
      expect(group.watchers, [watcher]);
      expect(
          () => group.watchers.add(
              StateWatcher(path: 'b', onChange: (_, __) async {})),
          throwsUnsupportedError,
          reason: 'a caller that edits the returned list changes the group '
              'without the group knowing');

      group.remove(watcher);
      expect(group.count, 0);

      group.add(watcher);
      group.clear();
      expect(group.count, 0);
      expect(group.toString(), contains('jobs'));
    });

    test('one failing watcher does not stop the ones after it', () async {
      final group = StateWatcherGroup();
      var reached = false;

      group.add(StateWatcher(
        path: 'a',
        onChange: (_, __) async => throw StateError('broke'),
      ));
      group.add(StateWatcher(
        path: 'b',
        onChange: (_, __) async => reached = true,
      ));

      await group.triggerAll(1, null);
      await group.triggerAll(2, 1);

      expect(reached, isTrue,
          reason: 'watchers are independent; one broken handler taking the '
              'rest of them down is a single document breaking a page');
    });
  });

  group('{{permissions.*}}', () {
    late PermissionBindingResolver resolver;

    setUp(() => resolver = PermissionBindingResolver());

    test('only permissions expressions are claimed', () {
      expect(resolver.isPermissionBinding('{{permissions.shell}}'), isTrue);
      expect(resolver.isPermissionBinding('{{state.shell}}'), isFalse);
      expect(resolver.isPermissionBinding('{{permissions.shell'), isFalse);
      expect(resolver.extractPath('{{permissions.file.read}}'), 'file.read');
      expect(resolver.extractPath('{{other}}'), isNull);
      expect(resolver.resolve('{{other}}'), isNull);
    });

    test('with no checker every permission reads false', () {
      expect(resolver.resolve('{{permissions.shell}}'), isFalse,
          reason: 'an unconfigured runtime must not tell a document it may '
              'run a shell; fail-closed is the only safe default');
    });

    test('each supported path answers from the configured permissions', () {
      resolver.initialize(PermissionsConfig.fromJson(<String, dynamic>{
        'file.read': <String, dynamic>{
          'allowedPaths': <dynamic>['/'],
        },
        'system.clipboard': true,
        'notification': true,
      }));

      expect(resolver.resolve('{{permissions.file.read}}'), isTrue);
      expect(resolver.resolve('{{permissions.file.write}}'), isFalse);
      expect(resolver.resolve('{{permissions.network.http}}'), isFalse);
      expect(resolver.resolve('{{permissions.shell}}'), isFalse);
      expect(resolver.resolve('{{permissions.system.exec}}'), isFalse);
      expect(resolver.resolve('{{permissions.clipboard}}'), isTrue);
      expect(resolver.resolve('{{permissions.system.clipboard}}'), isTrue);
      expect(resolver.resolve('{{permissions.notification}}'), isTrue);
      expect(resolver.resolve('{{permissions.systemInfo}}'), isFalse);
      expect(resolver.resolve('{{permissions.system.info}}'), isFalse);
    });

    test('a `.status` suffix reads the same permission', () {
      resolver.initialize(PermissionsConfig.fromJson(
          <String, dynamic>{'system.clipboard': true}));

      expect(resolver.resolve('{{permissions.clipboard.status}}'), isTrue,
          reason: '§7 documents both spellings; a document written the long '
              'way would otherwise hide the button it is allowed to show');
    });

    test('an unknown path is refused rather than assumed', () {
      resolver.initialize(PermissionsConfig.fromJson(<String, dynamic>{}));

      expect(resolver.resolve('{{permissions.camera}}'), isFalse);
    });

    test('a checker may be supplied directly', () {
      resolver.setChecker(PermissionChecker(PermissionsConfig.fromJson(
          <String, dynamic>{'notification': true})));

      expect(resolver.resolve('{{permissions.notification}}'), isTrue);
    });

    test('the supported paths are the ones that answer', () {
      resolver.initialize(PermissionsConfig.fromJson(<String, dynamic>{}));

      for (final path in PermissionBindingResolver.supportedPaths) {
        expect(resolver.resolve('{{permissions.$path}}'), isA<bool>(),
            reason: '$path is advertised as supported');
      }
    });
  });
}
