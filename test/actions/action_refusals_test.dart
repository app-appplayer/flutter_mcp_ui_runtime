// What an action says when it cannot do what it was asked.
//
// §6.13 is one rule — perform, or report — and these are the branches that
// carry it: an unknown sub-action, a capability the host never wired, a
// composite whose members failed, a target that is not mounted. Every one of
// them is a line of code whose entire purpose is to be an error result, and
// none of them had ever run. A silent success here is the most expensive kind
// of failure: the document believes a sound played, a channel started, a
// player seeked, and shows a screen consistent with all of it.

import 'dart:async';

import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/capabilities/runtime_capabilities.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/runtime_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// A media session that records what it was told to do.
class _FakeSession implements MediaSession {
  final events = <String>[];
  final _playing = StreamController<bool>.broadcast();
  bool isPlaying = false;

  @override
  Stream<bool> get playing => _playing.stream;

  @override
  Stream<Duration> get position => const Stream<Duration>.empty();

  @override
  Stream<Duration?> get duration => const Stream<Duration?>.empty();

  @override
  Stream<void> get ended => const Stream<void>.empty();

  @override
  Stream<Object> get errors => const Stream<Object>.empty();

  @override
  Future<void> play() async {
    events.add('play');
    isPlaying = true;
  }

  @override
  Future<void> pause() async {
    events.add('pause');
    isPlaying = false;
  }

  @override
  Future<void> seek(Duration to) async => events.add('seek:${to.inMilliseconds}');

  @override
  Future<void> setVolume(double volume) async => events.add('volume:$volume');

  @override
  Future<void> setMuted(bool muted) async => events.add('muted:$muted');

  @override
  Stream<List<double>>? get waveform => null;

  @override
  Future<void> dispose() async => events.add('dispose');
}

/// A sound port that refuses, the way a browser does before a first gesture.
class _RefusingSound implements SoundPort {
  @override
  Future<void> play(SoundRequest request) async =>
      throw StateError('the device is muted');

  @override
  Future<void> stop({String? id}) async {}
}

class _RecordingSound implements SoundPort {
  final played = <SoundRequest>[];
  final stopped = <String?>[];

  @override
  Future<void> play(SoundRequest request) async => played.add(request);

  @override
  Future<void> stop({String? id}) async => stopped.add(id);
}

void main() {
  late ActionHandler handler;
  late StateManager stateManager;
  late RenderContext context;
  late RuntimeEngine engine;

  setUp(() async {
    handler = ActionHandler();
    stateManager = StateManager()..initialize(<String, dynamic>{});
    engine = RuntimeEngine(enableDebugMode: false);
    await engine.initialize(definition: {
      'type': 'page',
      'content': {'type': 'box'},
    });
    final bindingEngine = BindingEngine();
    context = RenderContext(
      renderer: Renderer(
        widgetRegistry: WidgetRegistry(),
        bindingEngine: bindingEngine,
        actionHandler: handler,
        stateManager: stateManager,
      ),
      stateManager: stateManager,
      bindingEngine: bindingEngine,
      actionHandler: handler,
      themeManager: ThemeManager.instance,
      engine: engine,
    );
  });

  tearDown(() => engine.destroy());

  Future<dynamic> run(Map<String, dynamic> action) =>
      handler.execute(action, context);

  group('composite actions', () {
    test('a parallel run with no actions is refused', () async {
      final result = await run({'type': 'parallel', 'actions': <dynamic>[]});
      expect(result.success, isFalse);
      expect(result.error, contains('required'));
    });

    test('a failing member fails the whole parallel run, and fires onAnyError',
        () async {
      handler.registerToolExecutor('boom', (params) async {
        throw StateError('down');
      });

      final result = await run({
        'type': 'parallel',
        'actions': [
          {'type': 'state', 'action': 'set', 'binding': 'a', 'value': 1},
          {'type': 'tool', 'tool': 'boom'},
        ],
        'onAnyError': {
          'type': 'state',
          'action': 'set',
          'binding': 'reported',
          'value': true,
        },
        'onAllComplete': {
          'type': 'state',
          'action': 'set',
          'binding': 'finished',
          'value': true,
        },
      });

      expect(result.success, isFalse,
          reason: 'reporting success because two of three worked leaves the '
              'document showing a half-applied change as a whole one');
      expect(stateManager.get('reported'), isTrue);
      expect(stateManager.get('finished'), isTrue,
          reason: 'onAllComplete means completed, not succeeded');
      expect(stateManager.get('a'), 1);
    });

    test('a sequence stops at the first failure by default', () async {
      handler.registerToolExecutor('boom', (params) async {
        throw StateError('down');
      });

      final result = await run({
        'type': 'sequence',
        'actions': [
          {'type': 'tool', 'tool': 'boom'},
          {'type': 'state', 'action': 'set', 'binding': 'after', 'value': 1},
        ],
      });

      expect(result.success, isFalse);
      expect(stateManager.get('after'), isNull,
          reason: 'a sequence is ordered because each step depends on the one '
              'before; continuing past a failure applies the rest to a state '
              'that never happened');
    });

    test('stopOnError: false runs the rest and reports completion', () async {
      handler.registerToolExecutor('boom', (params) async {
        throw StateError('down');
      });

      final result = await run({
        'type': 'sequence',
        'stopOnError': false,
        'actions': [
          {'type': 'tool', 'tool': 'boom'},
          {'type': 'state', 'action': 'set', 'binding': 'after', 'value': 1},
        ],
        'onComplete': {
          'type': 'state',
          'action': 'set',
          'binding': 'done',
          'value': true,
        },
      });

      expect(stateManager.get('after'), 1);
      expect(stateManager.get('done'), isTrue);
      expect(result.success, isTrue);
    });

    test('a sequence with no actions is refused', () async {
      final result = await run({'type': 'sequence', 'actions': <dynamic>[]});
      expect(result.success, isFalse);
    });
  });

  group('channel', () {
    test('a bare channel action with no sub-operation is refused', () async {
      final result = await run({'type': 'channel', 'channel': 'readings'});
      expect(result.success, isFalse);
      expect(result.error, contains('sub-operation'));
    });

    test('with no ChannelManager wired the action reports rather than passes',
        () async {
      final result = await run({
        'type': 'channel',
        'action': 'start',
        'channel': 'readings',
      });

      expect(result.success, isFalse);
      expect(result.error, contains('ChannelManager'),
          reason: 'a host that never wired channels must not answer "started" '
              'to a document that then waits for data');
    });

    test('an unknown sub-action on a declared channel is named in the refusal',
        () async {
      final wired = RuntimeEngine(enableDebugMode: false);
      addTearDown(wired.destroy);
      await wired.initialize(definition: {
        'type': 'page',
        'content': {'type': 'box'},
        'channels': {
          'readings': {
            'type': 'client.poll',
            'interval': 600000,
            'autoStart': false,
          },
        },
      });
      final wiredContext = RenderContext(
        renderer: wired.renderer,
        stateManager: wired.stateManager,
        bindingEngine: wired.bindingEngine,
        actionHandler: wired.actionHandler,
        themeManager: wired.themeManager,
        engine: wired,
      );

      final result = await wired.actionHandler.execute({
        'type': 'channel',
        'action': 'rewind',
        'channel': 'readings',
      }, wiredContext);

      expect(result.success, isFalse);
      expect(result.error, contains('rewind'),
          reason: 'a document written against a later revision has to be told '
              'which operation this runtime does not have');
    });

    test('a channel action with no channel name is refused', () async {
      final result = await run({'type': 'channel', 'action': 'start'});
      expect(result.success, isFalse);
      expect(result.error, contains('name'));
    });

    test('an undeclared channel is reported as NOT_FOUND, not shrugged off',
        () async {
      final wired = RuntimeEngine(enableDebugMode: false);
      addTearDown(wired.destroy);
      await wired.initialize(definition: {
        'type': 'page',
        'content': {'type': 'box'},
      });
      final wiredContext = RenderContext(
        renderer: wired.renderer,
        stateManager: wired.stateManager,
        bindingEngine: wired.bindingEngine,
        actionHandler: wired.actionHandler,
        themeManager: wired.themeManager,
        engine: wired,
      );

      final result = await wired.actionHandler.execute({
        'type': 'channel',
        'action': 'start',
        'channel': 'nosuch',
      }, wiredContext);
      expect(result.success, isFalse);
      expect(result.errorCode, 'NOT_FOUND',
          reason: 'a page waiting on a channel that was never declared waits '
              'forever, and its onError never fires if this reports success');

      // §17.3.4 keeps the flat form working, including its errors.
      final legacy = await wired.actionHandler.execute({
        'type': 'channel.start',
        'channel': 'nosuch',
      }, wiredContext);
      expect(legacy.errorCode, 'NOT_FOUND');
    });
  });

  group('sound', () {
    test('with no sound port wired, play reports rather than beeping silently',
        () async {
      final result = await run({
        'type': 'sound.play',
        'source': 'bundle://beep.mp3',
      });

      expect(result.success, isFalse);
      expect(result.errorCode, 'CAPABILITY_UNAVAILABLE',
          reason: 'a beep that does nothing is indistinguishable from a muted '
              'device, and the author cannot tell which they shipped');
    });

    test('stop with no port reports too', () async {
      final result = await run({'type': 'sound.stop'});
      expect(result.success, isFalse);
    });

    test('play with no source is refused', () async {
      engine.capabilities = RuntimeCapabilities(sound: _RecordingSound());

      final result = await run({'type': 'sound.play'});
      expect(result.success, isFalse);
      expect(result.error, contains('AssetRef'));
    });

    test('an unnamed loop is refused, because nothing could stop it', () async {
      engine.capabilities = RuntimeCapabilities(sound: _RecordingSound());

      final result = await run({
        'type': 'sound.play',
        'source': 'bundle://siren.mp3',
        'loop': true,
      });

      expect(result.success, isFalse);
      expect(result.error, contains('id'),
          reason: '§4.9a — a looping sound with no id plays until the app '
              'closes');
    });

    test('a named loop reaches the port', () async {
      final port = _RecordingSound();
      engine.capabilities = RuntimeCapabilities(sound: port);

      final result = await run({
        'type': 'sound.play',
        'source': 'bundle://siren.mp3',
        'loop': true,
        'id': 'siren',
        'volume': 0.5,
      });

      expect(result.success, isTrue);
      expect(port.played.single.id, 'siren');
      expect(port.played.single.loop, isTrue);
      expect(port.played.single.volume, 0.5);
    });

    test('stop names the sound it stops', () async {
      final port = _RecordingSound();
      engine.capabilities = RuntimeCapabilities(sound: port);

      await run({'type': 'sound.stop', 'id': 'siren'});
      expect(port.stopped.single, 'siren');
    });

    test('a host refusal is reported as SOUND_REFUSED', () async {
      engine.capabilities = RuntimeCapabilities(sound: _RefusingSound());

      final result = await run({
        'type': 'sound.play',
        'source': 'bundle://beep.mp3',
      });

      expect(result.success, isFalse);
      expect(result.errorCode, 'SOUND_REFUSED');
      expect(result.error, contains('muted'));
    });
  });

  group('media', () {
    test('an action with no id is refused', () async {
      final result = await run({'type': 'media.play'});
      expect(result.success, isFalse);
      expect(result.error, contains('id'));
    });

    test('an id that is not mounted is reported, with what is', () async {
      engine.mediaRegistry.register('other', _FakeSession());

      final result = await run({'type': 'media.play', 'id': 'missing'});

      expect(result.errorCode, 'MEDIA_TARGET_NOT_FOUND');
      expect(result.errorDetails!['mounted'], ['other'],
          reason: 'naming a player that is not mounted and doing nothing looks '
              'exactly like a player that is there and refusing');
    });

    test('play, pause and seek reach the session', () async {
      final session = _FakeSession();
      engine.mediaRegistry.register('clip', session);

      await run({'type': 'media.play', 'id': 'clip'});
      await run({'type': 'media.pause', 'id': 'clip'});
      await run({'type': 'media.seek', 'id': 'clip', 'position': 2.5});

      expect(session.events, ['play', 'pause', 'seek:2500']);
    });

    test('seek with no position is refused', () async {
      engine.mediaRegistry.register('clip', _FakeSession());

      final result = await run({'type': 'media.seek', 'id': 'clip'});
      expect(result.success, isFalse);
      expect(result.error, contains('position'));
    });

    test('toggle asks the session what it is doing, and does the other thing',
        () async {
      final session = _FakeSession();
      engine.mediaRegistry.register('clip', session);

      // Nothing has been published on `playing`, so the read times out and
      // toggle treats the player as stopped — which is the safe direction: it
      // starts rather than silently doing nothing.
      final result = await run({'type': 'media.toggle', 'id': 'clip'});

      expect(result.success, isTrue);
      expect(session.events, ['play']);
    });

    // Two different refusals wear the same shape on screen, and reading one
    // for the other is how this test used to pass without measuring anything:
    // `media.rewind` never reaches the media executor at all, because the
    // handler only registers the four verbs the spec names. The assertion
    // `error contains 'media.rewind'` was satisfied by the handler's own
    // "Unknown action type" line — the executor's default branch had never
    // run. Both refusals are now named by the layer that issues them.
    test('a media verb the handler does not register never reaches the player',
        () async {
      engine.mediaRegistry.register('clip', _FakeSession());

      final result = await run({'type': 'media.rewind', 'id': 'clip'});
      expect(result.success, isFalse);
      expect(result.error, contains('Unknown action type'),
          reason: 'the refusal comes from dispatch, not from the media '
              'executor — a test that cannot tell them apart proves neither');
    });

    test('the media executor names a verb it was handed but does not know',
        () async {
      engine.mediaRegistry.register('clip', _FakeSession());

      final result = await MediaActionExecutor()
          .execute({'type': 'media.rewind', 'id': 'clip'}, context);

      expect(result.success, isFalse);
      expect(result.error, contains('unknown media action'),
          reason: 'a host may register this executor under its own key; the '
              'default branch is what answers then');
    });

    test('a session that throws is reported as MEDIA_FAILED', () async {
      engine.mediaRegistry.register('clip', _ThrowingSession());

      final result = await run({'type': 'media.play', 'id': 'clip'});
      expect(result.errorCode, 'MEDIA_FAILED');
    });
  });

  group('identity and permission', () {
    test('a bare identity action with no sub-operation is refused', () async {
      final result = await run({'type': 'identity'});
      expect(result.success, isFalse);
      expect(result.error, contains('sub-operation'));
    });

    test('an unknown identity sub-action is named', () async {
      final result = await run({'type': 'identity', 'action': 'impersonate'});
      expect(result.success, isFalse);
      expect(result.error, contains('impersonate'));
    });

    test('a bare permission action with no sub-operation is refused', () async {
      final result = await run({'type': 'permission'});
      expect(result.success, isFalse);
      expect(result.error, contains('sub-operation'));
    });

    test('an unknown permission sub-action is named', () async {
      final result = await run({'type': 'permission', 'action': 'grant'});
      expect(result.success, isFalse);
      expect(result.error, contains('grant'),
          reason: 'a runtime that silently ignores `permission.grant` would '
              'leave a document believing it had been granted');
    });
  });
}

class _ThrowingSession extends _FakeSession {
  @override
  Future<void> play() async => throw StateError('the decoder gave up');
}
