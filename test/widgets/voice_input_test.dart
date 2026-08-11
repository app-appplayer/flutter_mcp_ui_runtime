// `voiceInput` — the whole of what happens once capture is running.
//
// The platform split resolves to a no-op stub anywhere but a browser, so off
// the web the widget could only ever take its "not available" branch. What
// sits below that branch is not browser code: the transcript reaching its
// binding, the events a document listens for, the indicator that tells a user
// the microphone is live, and the maximum duration that turns it off again. A
// microphone with no visible state, or one that keeps running past the
// ceiling the document set, is the failure that matters most here — nobody
// can see it happening.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/widgets/input/platform/speech.dart';
import 'package:flutter_mcp_ui_runtime/src/widgets/input/voice_input_factory.dart';
import 'package:flutter_test/flutter_test.dart';

/// A capture session the test drives, standing in for the browser's.
class _FakeSession implements SpeechSession {
  bool stopped = false;

  @override
  void stop() => stopped = true;
}

void main() {
  late StateManager stateManager;
  late RenderContext context;

  // The last session handed out, and the callbacks it was started with.
  _FakeSession? session;
  late void Function(String, bool) emitResult;
  late void Function(String) emitError;
  late void Function() emitEnd;
  late Map<String, Object?> startedWith;

  setUp(() {
    stateManager = StateManager()..initialize(<String, dynamic>{});
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
    );

    session = null;
    startedWith = <String, Object?>{};
    debugSpeechSupported = true;
    debugStartSpeech = ({
      required String? language,
      required bool continuous,
      required bool interimResults,
      required void Function(String, bool) onResult,
      required void Function(String) onError,
      required void Function() onEnd,
    }) {
      startedWith = <String, Object?>{
        'language': language,
        'continuous': continuous,
        'interimResults': interimResults,
      };
      emitResult = onResult;
      emitError = onError;
      emitEnd = onEnd;
      return session = _FakeSession();
    };
  });

  tearDown(() {
    debugSpeechSupported = null;
    debugStartSpeech = null;
  });

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
  }

  Map<String, dynamic> set(String binding, Object? value) => <String, dynamic>{
        'type': 'state',
        'action': 'set',
        'binding': binding,
        'value': value,
      };

  Map<String, dynamic> input({Map<String, dynamic> extra = const {}}) =>
      <String, dynamic>{
        'type': 'voiceInput',
        'binding': 'transcript',
        ...extra,
      };

  Future<void> tapMic(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.mic));
    await tester.pump();
  }

  group('with no speech on this platform', () {
    testWidgets('the control says so rather than doing nothing',
        (tester) async {
      debugSpeechSupported = false;
      await pump(tester, input(extra: <String, dynamic>{
        'onError': set('error', '{{event.message}}'),
      }));

      await tapMic(tester);

      expect(stateManager.get<String>('error'), isNotNull,
          reason: 'a microphone button that renders and does nothing is worse '
              'than one that reports it cannot run');
      expect(find.text('Listening'), findsNothing);
    });

    testWidgets('a session that will not start is reported too',
        (tester) async {
      debugStartSpeech = ({
        required String? language,
        required bool continuous,
        required bool interimResults,
        required void Function(String, bool) onResult,
        required void Function(String) onError,
        required void Function() onEnd,
      }) =>
          null;
      await pump(tester, input(extra: <String, dynamic>{
        'onError': set('error', '{{event.message}}'),
      }));

      await tapMic(tester);

      expect(stateManager.get<String>('error'), contains('could not start'));
      expect(find.text('Listening'), findsNothing,
          reason: 'showing a live-capture indicator over a session that never '
              'opened tells the user the room is being recorded when it is '
              'not');
    });
  });

  group('once capture is running', () {
    testWidgets('the declared options are what the session is opened with',
        (tester) async {
      await pump(tester, input(extra: <String, dynamic>{
        'language': 'ko-KR',
        'continuous': true,
        'interimResults': true,
      }));

      await tapMic(tester);

      expect(startedWith, <String, Object?>{
        'language': 'ko-KR',
        'continuous': true,
        'interimResults': true,
      }, reason: 'a dictation field opened in the wrong language transcribes '
          'nonsense, and one opened without interim results shows nothing '
          'until the speaker stops');
    });

    testWidgets('the user is told the microphone is live', (tester) async {
      await pump(tester, input(extra: <String, dynamic>{
        'onStart': set('started', true),
      }));

      await tapMic(tester);

      expect(find.text('Listening'), findsOneWidget,
          reason: 'a live microphone with no visible state is the one thing '
              'this control must never be');
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsOneWidget);
      expect(stateManager.get('started'), isTrue,
          reason: 'onStart fires after the grant, not before');
    });

    testWidgets('the waveform can be turned off, and the words cannot',
        (tester) async {
      await pump(tester, input(extra: <String, dynamic>{
        'showWaveform': false,
      }));

      await tapMic(tester);

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Listening'), findsOneWidget,
          reason: 'silence about a live microphone is the wrong default, so '
              'the label stays even when the waveform is hidden');
    });

    testWidgets('a transcript lands at its binding, and is reported',
        (tester) async {
      await pump(tester, input(extra: <String, dynamic>{
        'onResult': set('lastFinal', '{{event.isFinal}}'),
      }));
      await tapMic(tester);

      emitResult('hello th', false);
      await tester.pump();
      expect(stateManager.get<String>('transcript'), 'hello th',
          reason: 'an interim transcript is what makes dictation feel live; '
              'holding it back until the speaker stops is the same as having '
              'no interim results at all');
      expect(stateManager.get('lastFinal'), isFalse);

      emitResult('hello there', true);
      await tester.pump();
      expect(stateManager.get<String>('transcript'), 'hello there');
      expect(stateManager.get('lastFinal'), isTrue);
    });

    testWidgets('a pad with no binding still reports through its event',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'voiceInput',
        'onResult': set('heard', '{{event.value}}'),
      });
      await tapMic(tester);

      emitResult('hello', true);
      await tester.pump();

      expect(stateManager.get<String>('heard'), 'hello');
    });

    testWidgets('tapping stop ends the session and takes the indicator down',
        (tester) async {
      await pump(tester, input());
      await tapMic(tester);

      await tester.tap(find.byIcon(Icons.stop));
      await tester.pump();

      expect(session!.stopped, isTrue,
          reason: 'a stop that only changes the icon leaves the microphone '
              'open for the life of the page');
      expect(find.text('Listening'), findsNothing);
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets('a session that ends on its own is reported and cleared',
        (tester) async {
      await pump(tester, input(extra: <String, dynamic>{
        'onEnd': set('ended', true),
      }));
      await tapMic(tester);

      emitEnd();
      await tester.pump();

      expect(stateManager.get('ended'), isTrue);
      expect(find.text('Listening'), findsNothing,
          reason: 'a browser that closes the session on silence leaves the '
              'indicator up unless the widget hears about it');
    });

    testWidgets('an error mid-capture ends it rather than leaving it live',
        (tester) async {
      await pump(tester, input(extra: <String, dynamic>{
        'onError': set('error', '{{event.message}}'),
      }));
      await tapMic(tester);

      emitError('no-speech');
      await tester.pump();

      expect(stateManager.get<String>('error'), 'no-speech');
      expect(find.text('Listening'), findsNothing);
    });

    testWidgets('the declared maximum duration turns the microphone off',
        (tester) async {
      await pump(tester, input(extra: <String, dynamic>{'maxDuration': 5}));
      await tapMic(tester);

      expect(find.text('Listening'), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));

      expect(session!.stopped, isTrue,
          reason: 'a microphone with no ceiling is a microphone left on');
      expect(find.text('Listening'), findsNothing);
    });

    testWidgets('a disabled control cannot be started at all', (tester) async {
      await pump(tester, input(extra: <String, dynamic>{'enabled': false}));

      final button = tester.widget<IconButton>(find.byType(IconButton));
      expect(button.onPressed, isNull);
    });
  });
}
