// `mediaPlayer` with a host that can actually play something.
//
// The widget was 79% covered and none of it was the player: with no MediaPort
// wired it reports and draws nothing, which is the branch every previous test
// took. Everything below — opening the session, the transport, the position
// bar, the waveform, the events a document listens for — had never run.
//
// A fake port stands in for the host. It is not a mock of the widget's own
// logic: it is the other side of the §6.13 contract, and the tests drive the
// widget through it exactly as a real host would.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/assets/asset_ref.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/capabilities/runtime_capabilities.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/runtime_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// A session the test drives: nothing happens on its streams unless a test
/// publishes it, the way a real player only reports what actually occurred.
class _Session implements MediaSession {
  _Session({this.withWaveform = false});

  final bool withWaveform;
  final calls = <String>[];

  final positionC = StreamController<Duration>.broadcast();
  final durationC = StreamController<Duration?>.broadcast();
  final playingC = StreamController<bool>.broadcast();
  final endedC = StreamController<void>.broadcast();
  final errorsC = StreamController<Object>.broadcast();
  final waveformC = StreamController<List<double>>.broadcast();

  @override
  Stream<Duration> get position => positionC.stream;

  @override
  Stream<Duration?> get duration => durationC.stream;

  @override
  Stream<bool> get playing => playingC.stream;

  @override
  Stream<void> get ended => endedC.stream;

  @override
  Stream<Object> get errors => errorsC.stream;

  @override
  Stream<List<double>>? get waveform => withWaveform ? waveformC.stream : null;

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> seek(Duration to) async => calls.add('seek:${to.inSeconds}');

  @override
  Future<void> setVolume(double volume) async => calls.add('volume:$volume');

  @override
  Future<void> setMuted(bool muted) async => calls.add('muted:$muted');

  @override
  Future<void> dispose() async {
    calls.add('dispose');
    await positionC.close();
    await durationC.close();
    await playingC.close();
    await endedC.close();
    await errorsC.close();
    await waveformC.close();
  }
}

class _Port implements MediaPort {
  _Port(this.session, {this.failWith});

  final _Session session;
  final Object? failWith;
  final opened = <Map<String, Object?>>[];

  @override
  Future<MediaSession> open({
    required AssetRef source,
    required AssetBytesReader readBytes,
    required bool isVideo,
    bool wantsWaveform = false,
    bool loop = false,
    bool muted = false,
    double volume = 1.0,
  }) async {
    opened.add({
      'isVideo': isVideo,
      'wantsWaveform': wantsWaveform,
      'loop': loop,
      'muted': muted,
      'volume': volume,
    });
    if (failWith != null) throw failWith!;
    return session;
  }

  @override
  Widget? videoSurface(MediaSession session) => const Text('video surface');
}

void main() {
  late StateManager stateManager;
  late RenderContext context;
  late RuntimeEngine engine;
  late _Session session;
  late _Port port;

  setUp(() async {
    engine = RuntimeEngine(enableDebugMode: false);
    await engine.initialize(definition: {
      'type': 'page',
      'content': {'type': 'box'},
    });
    stateManager = engine.stateManager;
    session = _Session();
    port = _Port(session);

    final registry = WidgetRegistry();
    DefaultWidgets.registerAll(registry);
    final bindingEngine = BindingEngine();
    final actionHandler = ActionHandler();
    context = RenderContext(
      renderer: Renderer(
        widgetRegistry: registry,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        stateManager: stateManager,
      ),
      stateManager: stateManager,
      bindingEngine: bindingEngine,
      actionHandler: actionHandler,
      themeManager: ThemeManager.instance,
      engine: engine,
    );
  });

  tearDown(() => engine.destroy());

  void wire({bool video = false, _Port? custom}) {
    engine.capabilities = RuntimeCapabilities(
      media: custom ?? port,
      mediaSupportsVideo: video,
    );
  }

  Future<void> pump(WidgetTester tester, Map<String, dynamic> definition) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AnimatedBuilder(
          animation: stateManager,
          builder: (_, __) => context.renderer.renderWidget(definition, context),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Delivers a host event and draws the frame it schedules.
  ///
  /// The session's streams are broadcast controllers: the listener runs on a
  /// microtask (first pump) and its `setState` is drawn on the next frame
  /// (second pump). One pump reads the tree before the widget has seen the
  /// event at all.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  Map<String, dynamic> audio({Map<String, dynamic> extra = const {}}) => {
        'type': 'mediaPlayer',
        'src': 'bundle://track.mp3',
        'height': 400,
        ...extra,
      };

  group('opening the session', () {
    testWidgets('an mp3 is opened as audio, without the document saying so',
        (tester) async {
      wire();
      await pump(tester, audio());

      expect(port.opened.single['isVideo'], isFalse,
          reason: '§10.6 defaults `type` to inferred; asking the host for '
              'video for an mp3 gets a black rectangle with sound');
    });

    testWidgets('a declared kind wins over the inference', (tester) async {
      // Through `mediaType`, not `type`: the widget type and §10.6's `type`
      // property are the same key, and `extractProperties` removes it — so
      // `"type": "video"` on a mediaPlayer cannot be expressed at the top
      // level of a definition at all. Recorded, not worked around.
      wire(video: true);
      await pump(tester, audio(extra: {'mediaType': 'video'}));

      expect(port.opened.single['isVideo'], isTrue);
    });

    testWidgets('the declared playback options travel to the host',
        (tester) async {
      wire();
      await pump(tester, audio(extra: {
        'loop': true,
        'muted': true,
        'volume': 0.4,
      }));

      final opened = port.opened.single;
      expect(opened['loop'], isTrue);
      expect(opened['muted'], isTrue);
      expect(opened['volume'], 0.4,
          reason: 'a volume the host never receives is a slider that moves '
              'nothing');
    });

    testWidgets('autoPlay starts playback', (tester) async {
      wire();
      await pump(tester, audio(extra: {'autoPlay': true}));

      expect(session.calls, contains('play'));
    });

    testWidgets('without autoPlay nothing starts on its own', (tester) async {
      wire();
      await pump(tester, audio());

      expect(session.calls, isEmpty,
          reason: 'a player that starts by itself is a sound the user did not '
              'ask for');
    });

    testWidgets('a player with an id is registered so actions can reach it',
        (tester) async {
      wire();
      await pump(tester, audio(extra: {'id': 'clip'}));

      expect(engine.mediaRegistry.mountedIds, contains('clip'));
    });

    testWidgets('and is unregistered when it leaves', (tester) async {
      wire();
      await pump(tester, audio(extra: {'id': 'clip'}));

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();

      expect(engine.mediaRegistry.mountedIds, isEmpty,
          reason: 'a stale entry accepts media.play and drives a player '
              'nobody can see');
      expect(session.calls, contains('dispose'));
    });

    testWidgets('a source that is not an asset reference is reported',
        (tester) async {
      wire();
      await pump(tester, {
        'type': 'mediaPlayer',
        'onError': {
          'type': 'state',
          'action': 'set',
          'binding': 'problem',
          'value': '{{event.error}}',
        },
      });

      expect(stateManager.get<String>('problem'), contains('asset reference'));
    });

    testWidgets('a host that cannot open the source reports rather than draws',
        (tester) async {
      wire(custom: _Port(session, failWith: StateError('codec missing')));
      await pump(tester, audio(extra: {
        'onError': {
          'type': 'state',
          'action': 'set',
          'binding': 'problem',
          'value': '{{event.error}}',
        },
      }));

      expect(stateManager.get<String>('problem'), contains('codec missing'));
      expect(find.byIcon(Icons.play_arrow), findsNothing,
          reason: 'a transport that cannot transport is worse than none');
    });

    testWidgets('a video document on an audio-only host is told which is missing',
        (tester) async {
      wire(); // media wired, but mediaSupportsVideo is false
      await pump(tester, {
        'type': 'mediaPlayer',
        'src': 'bundle://clip.mp4',
        'onError': {
          'type': 'state',
          'action': 'set',
          'binding': 'problem',
          'value': '{{event.error}}',
        },
      });

      expect(stateManager.get<String>('problem'), contains('video'),
          reason: 'the common embedded host is audio-only, and "no media at '
              'all" is a different thing to fix');
    });

    testWidgets('a poster still shows when the capability is missing',
        (tester) async {
      await pump(tester, {
        'type': 'mediaPlayer',
        'src': 'bundle://clip.mp4',
        // A data URI: a network poster would be answered with a 400 by the
        // test harness's HttpOverrides and the failure would be the harness's,
        // not the widget's.
        'poster':
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
      });

      expect(find.byType(Image), findsOneWidget,
          reason: 'the poster is the author\'s own content, not a facsimile '
              'of a player');
    });
  });

  group('the transport', () {
    testWidgets('play and pause drive the session', (tester) async {
      wire();
      await pump(tester, audio());

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();
      expect(session.calls, contains('play'));

      // The host reports that it started; the button follows the host, not
      // the tap.
      session.playingC.add(true);
      await settle(tester);
      expect(find.byIcon(Icons.pause), findsOneWidget);

      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump();
      expect(session.calls, contains('pause'));
    });

    testWidgets('the play state comes from the host, not from the tap',
        (tester) async {
      wire();
      await pump(tester, audio());

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow), findsOneWidget,
          reason: 'a button that flips to "pause" before the host started is '
              'a UI reporting something that has not happened');
    });

    testWidgets('onPlay and onPause fire when the host reports them',
        (tester) async {
      wire();
      await pump(tester, audio(extra: {
        'onPlay': {
          'type': 'state',
          'action': 'set',
          'binding': 'phase',
          'value': 'playing',
        },
        'onPause': {
          'type': 'state',
          'action': 'set',
          'binding': 'phase',
          'value': 'paused',
        },
      }));

      session.playingC.add(true);
      await settle(tester);
      expect(stateManager.get('phase'), 'playing');

      session.playingC.add(false);
      await settle(tester);
      expect(stateManager.get('phase'), 'paused');
    });

    testWidgets('onEnded fires when playback finishes', (tester) async {
      wire();
      await pump(tester, audio(extra: {
        'onEnded': {
          'type': 'state',
          'action': 'set',
          'binding': 'done',
          'value': true,
        },
      }));

      session.endedC.add(null);
      await settle(tester);

      expect(stateManager.get('done'), isTrue);
    });

    testWidgets('an error after playback started reaches onError',
        (tester) async {
      wire();
      await pump(tester, audio(extra: {
        'onError': {
          'type': 'state',
          'action': 'set',
          'binding': 'problem',
          'value': '{{event.error}}',
        },
      }));

      session.errorsC.add(StateError('the stream died'));
      await settle(tester);

      expect(stateManager.get<String>('problem'), contains('stream died'));
    });

    testWidgets('skip forward and back seek relative to the position',
        (tester) async {
      wire();
      await pump(tester, audio());

      session.durationC.add(const Duration(seconds: 120));
      session.positionC.add(const Duration(seconds: 30));
      await settle(tester);

      await tester.tap(find.byIcon(Icons.forward_10));
      await tester.pump();
      expect(session.calls, contains('seek:40'));

      await tester.tap(find.byIcon(Icons.replay_10));
      await tester.pump();
      expect(session.calls, contains('seek:20'));
    });

    testWidgets('a seek is clamped to the media, not past its end',
        (tester) async {
      wire();
      await pump(tester, audio());

      session.durationC.add(const Duration(seconds: 15));
      session.positionC.add(const Duration(seconds: 12));
      await settle(tester);

      await tester.tap(find.byIcon(Icons.forward_10));
      await tester.pump();

      expect(session.calls, contains('seek:15'),
          reason: 'seeking past the end is a request no player can answer');
    });

    testWidgets('onSeek reports where the user went', (tester) async {
      wire();
      await pump(tester, audio(extra: {
        'onSeek': {
          'type': 'state',
          'action': 'set',
          'binding': 'seekedTo',
          'value': '{{event.position}}',
        },
      }));

      session.durationC.add(const Duration(seconds: 100));
      session.positionC.add(const Duration(seconds: 10));
      await settle(tester);
      await tester.tap(find.byIcon(Icons.forward_10));
      await settle(tester);

      expect(stateManager.get('seekedTo'), 20.0);
    });

    testWidgets('the position bar follows the host', (tester) async {
      wire();
      await pump(tester, audio());

      session.durationC.add(const Duration(seconds: 100));
      session.positionC.add(const Duration(seconds: 25));
      await settle(tester);

      expect(tester.widget<Slider>(find.byType(Slider)).value, closeTo(0.25, 0.01),
          reason: 'a bar that does not move is the clearest possible way to '
              'look broken while working');
    });

    testWidgets('onTimeUpdate carries the current time and the duration',
        (tester) async {
      wire();
      await pump(tester, audio(extra: {
        'onTimeUpdate': {
          'type': 'state',
          'action': 'set',
          'binding': 'at',
          'value': '{{event.currentTime}}',
        },
      }));

      session.durationC.add(const Duration(seconds: 100));
      session.positionC.add(const Duration(seconds: 7));
      await settle(tester);

      expect(stateManager.get('at'), 7.0,
          reason: '§4.9b — an author building their own scrubber has no other '
              'way to know where playback is');
    });

    testWidgets('controls: false leaves the transport out', (tester) async {
      wire();
      await pump(tester, audio(extra: {'controls': false}));

      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });
  });

  group('what the player shows', () {
    testWidgets('a title and the file name are drawn for audio',
        (tester) async {
      wire();
      await pump(tester, audio(extra: {'title': 'Interview take 3'}));

      expect(find.text('Interview take 3'), findsOneWidget);
      expect(find.textContaining('track.mp3'), findsOneWidget);
    });

    testWidgets('a waveform is drawn when the host produces one',
        (tester) async {
      final waveSession = _Session(withWaveform: true);
      wire(custom: _Port(waveSession));
      await pump(tester, audio(extra: {'waveform': true}));

      expect(find.byIcon(Icons.music_note), findsOneWidget,
          reason: 'until peaks arrive there is nothing to draw but the '
              'artwork');

      waveSession.waveformC.add([0.1, 0.9, 0.4, 0.7]);
      await settle(tester);

      expect(find.byIcon(Icons.music_note), findsNothing,
          reason: 'real amplitude data replaces the placeholder square');
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('the waveform tracks the position once a duration is known',
        (tester) async {
      final waveSession = _Session(withWaveform: true);
      wire(custom: _Port(waveSession));
      await pump(tester, audio(extra: {'waveform': true}));

      waveSession.waveformC.add([0.1, 0.9, 0.4, 0.7]);
      waveSession.durationC.add(const Duration(seconds: 20));
      waveSession.positionC.add(const Duration(seconds: 5));
      await settle(tester);

      List<Object?> painters() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((p) => p.painter)
          .toList();
      final atFive = painters();

      waveSession.positionC.add(const Duration(seconds: 15));
      await settle(tester);

      expect(painters().any((p) => !atFive.any((q) => identical(p, q))), isTrue,
          reason: 'the played/remaining split is the only thing on a waveform '
              'that moves; a painter that never changes is a bar that shows '
              'the whole track as unplayed for the length of the file');
    });

    testWidgets('a waveform the host cannot produce is reported, not faked',
        (tester) async {
      wire();
      await pump(tester, audio(extra: {
        'waveform': true,
        'onError': {
          'type': 'state',
          'action': 'set',
          'binding': 'problem',
          'value': '{{event.error}}',
        },
      }));

      expect(stateManager.get<String>('problem'), contains('waveform'),
          reason: '§6.13.1 — accepting the property and drawing the ordinary '
              'artwork would look like a waveform-less track');
    });

    testWidgets('the loop and muted badges say what is on', (tester) async {
      wire();
      await pump(tester, audio(extra: {'loop': true, 'muted': true}));

      expect(find.text('Loop'), findsOneWidget);
      expect(find.text('Muted'), findsOneWidget);
      expect(find.text('Playing'), findsNothing);

      session.playingC.add(true);
      await settle(tester);
      expect(find.text('Playing'), findsOneWidget);
    });

    testWidgets('a muted player shows the muted volume icon', (tester) async {
      wire();
      await pump(tester, audio(extra: {'muted': true}));

      expect(find.byIcon(Icons.volume_off), findsOneWidget);
    });

    testWidgets('a half volume shows the quieter icon', (tester) async {
      wire();
      await pump(tester, audio(extra: {'volume': 0.2}));

      expect(find.byIcon(Icons.volume_down), findsOneWidget);
    });

    testWidgets('the volume menu opens and its slider moves', (tester) async {
      wire();
      await pump(tester, audio());

      await tester.tap(find.byIcon(Icons.volume_up));
      await tester.pumpAndSettle();
      expect(find.text('Volume'), findsOneWidget);

      await tester.tap(find.text('Mute'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.volume_off), findsOneWidget);
    });

    testWidgets('tapping the surface fades the controls out, and back',
        (tester) async {
      wire();
      await pump(tester, audio(extra: {'title': 'Take 3'}));

      double opacity() => tester
          .widget<AnimatedOpacity>(find.byType(AnimatedOpacity))
          .opacity;
      // The overlay's own IgnorePointer — Material's own widgets bring
      // others (the Slider's overlay, for one).
      bool ignoring() => tester
          .widget<IgnorePointer>(find.ancestor(
            of: find.byType(AnimatedOpacity),
            matching: find.byType(IgnorePointer),
          ).first)
          .ignoring;

      expect(opacity(), 1.0);
      expect(ignoring(), isFalse);

      // On the player's own surface — the title sits inside it — rather than
      // the first GestureDetector in the tree, which belongs to the app above.
      await tester.tap(find.text('Take 3'));
      await settle(tester);

      expect(opacity(), 0.0,
          reason: 'a full-bleed player has to be able to get out of the way');
      expect(ignoring(), isTrue,
          reason: 'faded out is not gone: an invisible play button that still '
              'takes the tap pauses the media instead of bringing the '
              'transport back');

      await tester.tap(find.text('Take 3'));
      await settle(tester);
      expect(opacity(), 1.0);
    });
  });

  group('the transport a user drives', () {
    testWidgets('dragging the position bar seeks, and reports where to',
        (tester) async {
      wire();
      await pump(tester, audio(extra: {
        'onSeek': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'seekedTo',
          'value': '{{event.position}}',
        },
      }));

      session.durationC.add(const Duration(seconds: 100));
      await settle(tester);

      final slider = find.byType(Slider).first;
      await tester.tapAt(tester.getCenter(slider));
      await settle(tester);

      expect(session.calls.where((c) => c.startsWith('seek')), isNotEmpty,
          reason: 'the bar is the only way a listener skips ahead; a slider '
              'that moves its own thumb and seeks nothing is decoration');
      expect(stateManager.get('seekedTo'), isNotNull,
          reason: 'a document that syncs a transcript to the position needs '
              'to be told where the user went');
    });

    testWidgets('the volume control sets a level and mutes at zero',
        (tester) async {
      wire();
      await pump(tester, audio());

      await tester.tap(find.byIcon(Icons.volume_up));
      await tester.pumpAndSettle();

      final slider = find.byType(Slider).last;
      await tester.tapAt(tester.getTopLeft(slider) + const Offset(2, 8));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.volume_off), findsOneWidget,
          reason: 'dragging to zero IS muting; leaving the icon at "sound on" '
              'tells the user the opposite of what they did');
    });

    testWidgets('a video player offers fullscreen, and toggles it',
        (tester) async {
      wire(video: true);
      await pump(tester, audio(extra: {
        'mediaType': 'video',
        'title': 'Take 3',
      }));

      expect(find.byIcon(Icons.fullscreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.fullscreen));
      await settle(tester);

      expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget,
          reason: 'a control that does not change state after it is pressed '
              'gives the user no way to tell whether it worked');
    });

    testWidgets('the controls hide themselves while playing', (tester) async {
      wire();
      await pump(tester, audio(extra: {'title': 'Take 3'}));

      session.playingC.add(true);
      await settle(tester);

      // The timer is armed when the controls are brought BACK — that is the
      // moment the user asked to see them, and the countdown starts there.
      await tester.tap(find.text('Take 3'));
      await settle(tester);
      await tester.tap(find.text('Take 3'));
      await settle(tester);

      // The hide timer runs on the wall clock, not on a frame.
      await tester.pump(const Duration(seconds: 4));

      expect(
          tester
              .widget<AnimatedOpacity>(find.byType(AnimatedOpacity))
              .opacity,
          0.0,
          reason: 'a transport left over a playing video covers the thing the '
              'user is watching');
    });

    testWidgets('a video with no frames yet still names what is loading',
        (tester) async {
      wire(video: true);
      await pump(tester, audio(extra: {
        'mediaType': 'video',
        'title': 'Take 3',
      }));

      expect(find.byIcon(Icons.videocam), findsOneWidget);
      expect(find.text('Take 3'), findsWidgets,
          reason: 'a black rectangle says nothing; the title is what tells '
              'the user which item they opened');
    });
  });
}
