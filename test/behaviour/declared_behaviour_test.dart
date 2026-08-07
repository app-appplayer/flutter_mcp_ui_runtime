// Behaviour tests — spec §6.13.
//
// The rest of this suite asks whether a widget is REGISTERED and whether it
// DRAWS. Both were true of a media player that decoded nothing, a web view that
// announced a page load it never performed, and a map that drew a rectangle
// where tiles belong — 5,565 tests stayed green while none of it worked.
//
// So these tests ask three different questions:
//
//   1. does the declared PROPERTY reach the rendered result,
//   2. is the declared BEHAVIOUR actually performed (observed at the port,
//      which is the only place the effect is real), and
//   3. when the capability is absent, is that REPORTED rather than faked.
//
// A test that only pumps a widget and finds it cannot fail on any of these.

import 'dart:async';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

// ---------------------------------------------------------------------------
// Fakes that record what the document actually asked the platform to do.
// ---------------------------------------------------------------------------

class _RecordingSoundPort implements SoundPort {
  final List<SoundRequest> played = [];
  final List<Uint8List?> bytesOffered = [];
  final List<String?> stopped = [];
  Object? failWith;

  @override
  Future<void> play(SoundRequest request) async {
    if (failWith != null) throw failWith!;
    played.add(request);
    // What a host with no URI to open would do: ask for the bytes.
    bytesOffered.add(await request.readBytes());
  }

  @override
  Future<void> stop({String? id}) async => stopped.add(id);
}

class _FakeSession implements MediaSession {
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration?>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _ended = StreamController<void>.broadcast();
  final _errors = StreamController<Object>.broadcast();

  int playCalls = 0;
  int pauseCalls = 0;
  Duration? seekedTo;
  bool disposed = false;

  @override
  Stream<Duration> get position => _position.stream;
  @override
  Stream<Duration?> get duration => _duration.stream;
  @override
  Stream<bool> get playing => _playing.stream;
  @override
  Stream<void> get ended => _ended.stream;
  @override
  Stream<Object> get errors => _errors.stream;

  /// Amplitude data this fake hands over, when the test is about a host that
  /// has some. Null is the common case, and the one the report exists for.
  List<double>? peaks;

  @override
  Stream<List<double>>? get waveform =>
      peaks == null ? null : Stream<List<double>>.value(peaks!);

  @override
  Future<void> play() async {
    playCalls++;
    _playing.add(true);
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    _playing.add(false);
  }

  @override
  Future<void> seek(Duration position) async => seekedTo = position;
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> setMuted(bool muted) async {}
  @override
  Future<void> dispose() async {
    disposed = true;
    await _position.close();
    await _duration.close();
    await _playing.close();
    await _ended.close();
    await _errors.close();
  }

  void emitPosition(Duration d) => _position.add(d);
  void emitDuration(Duration d) => _duration.add(d);
  void emitEnded() => _ended.add(null);
}

class _FakeMediaPort implements MediaPort {
  _FakeMediaPort({this.video = false, this.peaks});

  final bool video;

  /// Amplitude data this port's session will offer, if any.
  final List<double>? peaks;
  final List<AssetRef> opened = [];

  /// What the widget told the host it needed — a host only pays for amplitude
  /// data when the document asked (§10.6).
  final List<bool> askedForWaveform = [];
  final List<bool> openedAsVideo = [];
  _FakeSession? session;

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
    opened.add(source);
    openedAsVideo.add(isVideo);
    askedForWaveform.add(wantsWaveform);
    return session = (_FakeSession()..peaks = peaks);
  }

  @override
  Widget? videoSurface(MediaSession session) =>
      video ? const Placeholder(key: ValueKey('video-surface')) : null;
}

// ---------------------------------------------------------------------------

void main() {
  late MCPUIRuntime runtime;

  setUp(() => runtime = MCPUIRuntime());
  tearDown(() => runtime.destroy());

  Future<void> pump(
    WidgetTester tester,
    Map<String, dynamic> content, {
    RuntimeCapabilities capabilities = RuntimeCapabilities.none,
    AssetResolver? assetResolver,
    Map<String, dynamic>? initialState,
  }) async {
    final definition = <String, dynamic>{'type': 'page', 'content': content};
    if (initialState != null) {
      definition['runtime'] = {
        'services': {
          'state': {'initialState': initialState},
        },
      };
    }
    await runtime.initialize(definition);
    runtime.engine.capabilities = capabilities;
    if (assetResolver != null) runtime.engine.assetResolver = assetResolver;
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: runtime.buildUI())),
    );
    await tester.pump();
  }

  group('sound.play — the effect is observed at the port', () {
    testWidgets('a tap plays the declared source with its settings',
        (tester) async {
      final port = _RecordingSoundPort();
      await pump(
        tester,
        {
          'type': 'button',
          'label': 'beep',
          'click': {
            'type': 'sound.play',
            'source': 'https://example.com/beep.mp3',
            'volume': 0.25,
            'id': 'beep-1',
          },
        },
        capabilities: RuntimeCapabilities(sound: port),
      );

      await tester.tap(find.text('beep'));
      await tester.pumpAndSettle();

      expect(port.played, hasLength(1),
          reason: 'the sound must reach the platform, not just the handler');
      expect(port.played.single.source.uri, 'https://example.com/beep.mp3');
      expect(port.played.single.volume, 0.25,
          reason: 'a declared volume that never reaches the port is a setting '
              'the author cannot hear');
      expect(port.played.single.id, 'beep-1');
    });

    testWidgets('a binding is resolved before the platform is asked',
        (tester) async {
      final port = _RecordingSoundPort();
      await pump(
        tester,
        {
          'type': 'button',
          'label': 'beep',
          'click': {'type': 'sound.play', 'source': '{{clip}}'},
        },
        capabilities: RuntimeCapabilities(sound: port),
        initialState: {'clip': 'https://example.com/from-state.mp3'},
      );

      await tester.tap(find.text('beep'));
      await tester.pumpAndSettle();

      expect(port.played.single.source.uri,
          'https://example.com/from-state.mp3');
    });

    testWidgets('with no sound capability the document is told, not ignored',
        (tester) async {
      await pump(
        tester,
        {
          'type': 'button',
          'label': 'beep',
          'click': {
            'type': 'sound.play',
            'source': 'https://example.com/beep.mp3',
            'onError': {
              'type': 'state',
              'action': 'set',
              'binding': 'failure',
              'value': '{{event.message}}',
            },
          },
        },
        initialState: {'failure': ''},
      );

      await tester.tap(find.text('beep'));
      await tester.pumpAndSettle();

      final failure = runtime.stateManager.get<String>('failure') ?? '';
      expect(failure, contains('capability unavailable'),
          reason: 'silence and a working speaker are indistinguishable to the '
              'author unless the runtime says which one it was');
    });

    testWidgets('a bundled sound is readable, exactly as a bundled image is',
        (tester) async {
      final port = _RecordingSoundPort();
      final beep = Uint8List.fromList([0, 1, 2, 3]);
      await pump(
        tester,
        {
          'type': 'button',
          'label': 'beep',
          'click': {
            'type': 'sound.play',
            'source': 'bundle://assets/beep.mp3',
          },
        },
        capabilities: RuntimeCapabilities(sound: port),
        assetResolver: AssetResolver(bundleReader: (path) async => beep),
      );

      await tester.tap(find.text('beep'));
      await tester.pumpAndSettle();

      expect(port.played.single.source.uri, 'bundle://assets/beep.mp3');
      expect(port.bytesOffered.single, beep,
          reason: 'an app that ships a picture ships the beep the same way — '
              'the image working while the sound does not is drift, not a rule');
    });

    testWidgets('a looping sound without an id is refused', (tester) async {
      final port = _RecordingSoundPort();
      await pump(
        tester,
        {
          'type': 'button',
          'label': 'beep',
          'click': {
            'type': 'sound.play',
            'source': 'https://example.com/beep.mp3',
            'loop': true,
          },
        },
        capabilities: RuntimeCapabilities(sound: port),
      );

      await tester.tap(find.text('beep'));
      await tester.pumpAndSettle();

      expect(port.played, isEmpty,
          reason: 'a loop nobody can stop plays until the app closes');
    });
  });

  group('mediaPlayer — playback is the port, not a timer', () {
    testWidgets('opens the declared source and reflects real position',
        (tester) async {
      final port = _FakeMediaPort();
      await pump(
        tester,
        {
          'type': 'mediaPlayer',
          'source': 'https://example.com/horse.mp3',
          'mediaType': 'audio',
        },
        capabilities: RuntimeCapabilities(media: port),
      );
      await tester.pumpAndSettle();

      expect(port.opened.single.uri, 'https://example.com/horse.mp3');
      expect(port.openedAsVideo.single, isFalse);

      port.session!.emitDuration(const Duration(seconds: 90));
      port.session!.emitPosition(const Duration(seconds: 12));
      // Two pumps: the stream event lands, then the frame that shows it.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // The transport shows what the platform reports, so a player that decodes
      // nothing shows nothing moving.
      expect(find.textContaining('00:12'), findsWidgets,
          reason: 'the transport shows the position the platform reports');
      expect(find.textContaining('01:30'), findsWidgets,
          reason: 'and the length it reports, not the property default');
    });

    testWidgets('onPlay fires when the platform starts, not when tapped',
        (tester) async {
      final port = _FakeMediaPort();
      await pump(
        tester,
        {
          'type': 'mediaPlayer',
          'source': 'https://example.com/horse.mp3',
          'mediaType': 'audio',
          'autoPlay': true,
          'onPlay': {
            'type': 'state',
            'action': 'set',
            'binding': 'started',
            'value': true,
          },
        },
        capabilities: RuntimeCapabilities(media: port),
        initialState: {'started': false},
      );
      await tester.pumpAndSettle();

      expect(port.session!.playCalls, 1,
          reason: 'autoPlay must reach the platform');
      expect(runtime.stateManager.get<bool>('started'), isTrue);
    });

    testWidgets('no media capability draws no player and reports',
        (tester) async {
      await pump(
        tester,
        {
          'type': 'mediaPlayer',
          'source': 'https://example.com/horse.mp3',
          'mediaType': 'audio',
          'onError': {
            'type': 'state',
            'action': 'set',
            'binding': 'failure',
            'value': '{{event.error}}',
          },
        },
        initialState: {'failure': ''},
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_arrow), findsNothing,
          reason: 'a transport that cannot transport is the facsimile §6.13.1 '
              'forbids');
      expect(runtime.stateManager.get<String>('failure') ?? '',
          contains('capability unavailable'));
    });

    testWidgets('video asked of an audio-only port is reported, not drawn',
        (tester) async {
      final port = _FakeMediaPort(); // audio only
      await pump(
        tester,
        {
          'type': 'mediaPlayer',
          'source': 'https://example.com/clip.mp4',
          'mediaType': 'video',
          'onError': {
            'type': 'state',
            'action': 'set',
            'binding': 'failure',
            'value': '{{event.error}}',
          },
        },
        capabilities: RuntimeCapabilities(media: port), // mediaSupportsVideo: false
        initialState: {'failure': ''},
      );
      await tester.pumpAndSettle();

      expect(port.opened, isEmpty);
      expect(runtime.stateManager.get<String>('failure') ?? '',
          contains('video'));
    });
  });

  group('media actions — a hidden transport is not a dead end (§4.9b)', () {
    testWidgets('an mp3 with no mediaType is opened as audio', (tester) async {
      // §10.6 declares the default `inferred`. Reading it as `video` meant a
      // document that pointed at an mp3 and said nothing asked the host for
      // the video capability — a black rectangle with sound, or a report that
      // video is unavailable on a host that has audio.
      final port = _FakeMediaPort();
      await pump(
        tester,
        {
          'type': 'mediaPlayer',
          'source': 'https://example.com/lecture.mp3',
        },
        capabilities: RuntimeCapabilities(media: port),
      );
      await tester.pumpAndSettle();
      expect(port.openedAsVideo, [false]);
    });

    testWidgets('the legacy `src` spelling is inferred from too', (tester) async {
      // The player opens `src ?? source`; inference read `source` alone, so a
      // document using the alias pointed at an mp3 and still asked for video.
      final port = _FakeMediaPort();
      await pump(
        tester,
        {
          'type': 'mediaPlayer',
          'src': 'https://example.com/lecture.mp3',
        },
        capabilities: RuntimeCapabilities(media: port),
      );
      await tester.pumpAndSettle();
      expect(port.openedAsVideo, [false]);
    });

    testWidgets('a declared mediaType still wins over the source',
        (tester) async {
      final port = _FakeMediaPort(video: true);
      await pump(
        tester,
        {
          'type': 'mediaPlayer',
          'source': 'https://example.com/clip.mp3',
          'mediaType': 'video',
        },
        capabilities:
            RuntimeCapabilities(media: port, mediaSupportsVideo: true),
      );
      await tester.pumpAndSettle();
      expect(port.openedAsVideo, [true]);
    });

    testWidgets('media.play drives the player the document named',
        (tester) async {
      final port = _FakeMediaPort();
      await pump(
        tester,
        {
          'type': 'linear',
          'direction': 'vertical',
          'children': [
            {
              'type': 'mediaPlayer',
              'id': 'lecture',
              'controls': false,
              'source': 'https://example.com/lecture.mp3',
              'mediaType': 'audio',
            },
            {
              'type': 'button',
              'label': 'play',
              'click': {'type': 'media.play', 'id': 'lecture'},
            },
          ],
        },
        capabilities: RuntimeCapabilities(media: port),
      );
      await tester.pumpAndSettle();

      expect(port.session!.playCalls, 0);
      await tester.tap(find.text('play'));
      await tester.pumpAndSettle();
      expect(port.session!.playCalls, 1,
          reason: 'hiding the built-in transport must not remove the ability '
              'to build one');
    });

    testWidgets('a player that draws no waveform does not ask the host for one',
        (tester) async {
      final port = _FakeMediaPort();
      await pump(
        tester,
        {
          'type': 'mediaPlayer',
          'source': 'https://example.com/lecture.mp3',
          'mediaType': 'audio',
        },
        capabilities: RuntimeCapabilities(media: port),
      );
      await tester.pumpAndSettle();
      expect(port.askedForWaveform, [false],
          reason: 'amplitude data costs the whole file to read and decode');
    });

    testWidgets('media.seek reaches the platform in seconds', (tester) async {
      final port = _FakeMediaPort();
      await pump(
        tester,
        {
          'type': 'linear',
          'direction': 'vertical',
          'children': [
            {
              'type': 'mediaPlayer',
              'id': 'lecture',
              'source': 'https://example.com/lecture.mp3',
              'mediaType': 'audio',
            },
            {
              'type': 'button',
              'label': 'skip',
              'click': {'type': 'media.seek', 'id': 'lecture', 'position': 42},
            },
          ],
        },
        capabilities: RuntimeCapabilities(media: port),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('skip'));
      await tester.pumpAndSettle();
      expect(port.session!.seekedTo, const Duration(seconds: 42));
    });

    testWidgets('an id that is not mounted is reported, not ignored',
        (tester) async {
      await pump(
        tester,
        {
          'type': 'button',
          'label': 'play',
          'click': {
            'type': 'media.play',
            'id': 'ghost',
            'onError': {
              'type': 'state',
              'action': 'set',
              'binding': 'failure',
              'value': '{{event.message}}',
            },
          },
        },
        initialState: {'failure': ''},
      );
      await tester.tap(find.text('play'));
      await tester.pumpAndSettle();
      expect(runtime.stateManager.get<String>('failure') ?? '',
          contains('ghost'),
          reason: 'doing nothing looks the same as a player that refused');
    });

    testWidgets('onTimeUpdate carries the position the platform reports',
        (tester) async {
      final port = _FakeMediaPort();
      await pump(
        tester,
        {
          'type': 'mediaPlayer',
          'id': 'lecture',
          'controls': false,
          'source': 'https://example.com/lecture.mp3',
          'mediaType': 'audio',
          'onTimeUpdate': {
            'type': 'state',
            'action': 'set',
            'binding': 'at',
            'value': '{{event.currentTime}}',
          },
        },
        capabilities: RuntimeCapabilities(media: port),
        initialState: {'at': 0},
      );
      await tester.pumpAndSettle();

      port.session!.emitPosition(const Duration(seconds: 7));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(runtime.stateManager.get('at'), 7.0,
          reason: 'a custom scrubber has no other source of truth');
    });

    testWidgets('a waveform the host produced is drawn, not just accepted',
        (tester) async {
      final port = _FakeMediaPort(peaks: [0.1, 0.9, 0.4, 1.0]);
      await pump(
        tester,
        {
          'type': 'mediaPlayer',
          'source': 'https://example.com/lecture.wav',
          'mediaType': 'audio',
          'waveform': true,
          'onError': {
            'type': 'state',
            'action': 'set',
            'binding': 'failure',
            'value': '{{event.error}}',
          },
        },
        capabilities: RuntimeCapabilities(media: port),
        initialState: {'failure': ''},
      );
      await tester.pumpAndSettle();

      expect(runtime.stateManager.get<String>('failure') ?? '', isEmpty,
          reason: 'the host produced the data — there is nothing to report');
      final painters = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where((c) => c.painter.runtimeType.toString() == '_WaveformPainter');
      expect(painters, isNotEmpty,
          reason: 'taking the amplitude data and drawing the same music-note '
              'square is the silence 6.13.1 forbids');
    });

    testWidgets('waveform asked of a host that has none is reported',
        (tester) async {
      final port = _FakeMediaPort();
      await pump(
        tester,
        {
          'type': 'mediaPlayer',
          'source': 'https://example.com/lecture.mp3',
          'mediaType': 'audio',
          'waveform': true,
          'onError': {
            'type': 'state',
            'action': 'set',
            'binding': 'failure',
            'value': '{{event.error}}',
          },
        },
        capabilities: RuntimeCapabilities(media: port),
        initialState: {'failure': ''},
      );
      await tester.pumpAndSettle();

      expect(runtime.stateManager.get<String>('failure') ?? '',
          contains('waveform'),
          reason: 'accepting the property and drawing nothing is the silence '
              '6.13.1 forbids');
      expect(port.askedForWaveform, [true],
          reason: 'a host that could produce amplitude data would never be '
              'asked for it');
    });
  });

  group('declared settings reach what is drawn', () {
    testWidgets('controls:false removes the transport, not just its opacity',
        (tester) async {
      final port = _FakeMediaPort();
      await pump(
        tester,
        {
          'type': 'mediaPlayer',
          'source': 'https://example.com/horse.mp3',
          'mediaType': 'audio',
          'controls': false,
        },
        capabilities: RuntimeCapabilities(media: port),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_arrow), findsNothing);
      expect(find.byIcon(Icons.pause), findsNothing);
    });

    testWidgets('controls:true draws the transport', (tester) async {
      final port = _FakeMediaPort();
      await pump(
        tester,
        {
          'type': 'mediaPlayer',
          'source': 'https://example.com/horse.mp3',
          'mediaType': 'audio',
          'controls': true,
        },
        capabilities: RuntimeCapabilities(media: port),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_arrow), findsWidgets);
    });
  });

  group('webView — the host surface, or the truth', () {
    testWidgets('the hosted surface is what renders, and its events reach '
        'the document', (tester) async {
      late SurfaceEvents captured;
      await pump(
        tester,
        {
          'type': 'webView',
          'url': 'https://example.com',
          'onPageFinished': {
            'type': 'state',
            'action': 'set',
            'binding': 'loaded',
            'value': true,
          },
        },
        capabilities: RuntimeCapabilities(
          webViewBuilder: (context, properties, events, assets) {
            captured = events;
            return const Placeholder(key: ValueKey('host-webview'));
          },
        ),
        initialState: {'loaded': false},
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('host-webview')), findsOneWidget);

      captured.emit('onPageFinished');
      await tester.pumpAndSettle();
      expect(runtime.stateManager.get<bool>('loaded'), isTrue,
          reason: 'a host that draws content the document cannot react to is '
              'disconnected in a different way');
    });

    testWidgets('with no engine nothing is drawn in its place', (tester) async {
      await pump(
        tester,
        {'type': 'webView', 'url': 'https://example.com'},
      );
      await tester.pumpAndSettle();

      // The URL used to be rendered as text after a fake "load finished".
      expect(find.textContaining('example.com'), findsNothing);
    });
  });
}
