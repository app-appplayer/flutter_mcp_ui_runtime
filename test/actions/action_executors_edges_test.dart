// The action executors' refusal paths.
//
// Every executor answers an `ActionResult`, and the uncovered half of this file
// was almost entirely the failures: an action with its required field missing,
// a channel nobody declared, a sound with no capability behind it, a media
// command naming a player that is not there. None of those throw — they answer
// an error the document is supposed to read, so an executor that answers
// SUCCESS for a thing it did not do is invisible until a user notices nothing
// happened.

import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ActionHandler handler;
  late StateManager stateManager;
  late RenderContext context;

  setUp(() {
    stateManager = StateManager()..initialize(<String, dynamic>{'count': 1});
    handler = ActionHandler();
    final engine = BindingEngine();
    context = RenderContext(
      renderer: Renderer(
        widgetRegistry: WidgetRegistry(),
        bindingEngine: engine,
        actionHandler: handler,
        stateManager: stateManager,
      ),
      stateManager: stateManager,
      actionHandler: handler,
      themeManager: ThemeManager(),
      bindingEngine: engine,
      buildContext: null,
    );
  });

  Future<dynamic> run(Map<String, dynamic> action) =>
      handler.execute(action, context);

  group('an action that is not properly declared', () {
    test('an unknown action type is refused rather than ignored', () async {
      final result = await run({'type': 'teleport'});
      expect(result.success, isFalse,
          reason: 'answering success for an action nobody implemented is how a '
              'document appears to work while doing nothing');
    });

    test('a batch keeps going past a failed child, by design', () async {
      // `stopOnError` defaults to false — graceful degradation, stated in the
      // executor. Pinned rather than changed: a batch that aborted on the
      // first failure would take working actions down with a broken one, and
      // a document that wants all-or-nothing can say `stopOnError: true`.
      final result = await run({
        'type': 'batch',
        'actions': [
          {'type': 'state', 'action': 'set', 'binding': 'count', 'value': 2},
          {'type': 'teleport'},
        ],
      });
      expect(result.success, isTrue);
      expect(stateManager.get('count'), 2,
          reason: 'the actions before the failure still ran');
    });

    test('a conditional with no branch declared is not an error', () async {
      final result = await run({
        'type': 'conditional',
        'condition': '{{missing}}',
      });
      expect(result.success, isTrue);
    });
  });

  group('channel actions', () {
    test('a channel action with no sub-type is refused by name', () async {
      final result = await run({'type': 'channel'});
      expect(result.success, isFalse);
      expect(result.error, contains('action'),
          reason: 'the message names the missing field, which is what an '
              'author needs to fix it');
    });

    test('an unknown channel sub-type is named in the error', () async {
      final result = await run({'type': 'channel.telepathy', 'channel': 'x'});
      expect(result.success, isFalse);
      expect(result.error, contains('telepathy'));
    });

    test('a channel action with no manager wired says so', () async {
      final result = await run({'type': 'channel.start', 'channel': 'feed'});
      expect(result.success, isFalse,
          reason: 'a document that starts a channel on a host with no channel '
              'support has to be told, not left waiting for data');
    });
  });

  group('sound and media without a capability', () {
    test('sound.play reports the capability, not a generic failure', () async {
      final result = await run({
        'type': 'sound.play',
        'source': 'bundle://assets/tone.mp3',
      });
      expect(result.success, isFalse);
      expect(result.error, contains('sound'),
          reason: '§6.13.2 — the absence is a capability fact, and the document '
              'is entitled to know which capability');
    });

    test('sound.play with no source is refused before the capability check',
        () async {
      final result = await run({'type': 'sound.play'});
      expect(result.success, isFalse);
      expect(result.error, contains('source'));
    });

    test('a media command with no player id is refused by name', () async {
      for (final type in const [
        'media.play',
        'media.pause',
        'media.toggle',
        'media.seek',
      ]) {
        final result = await run({'type': type});
        expect(result.success, isFalse, reason: '$type needs a target');
        expect(result.error, contains('player'),
            reason: '$type must name what is missing');
      }
    });

    test('a media command naming a player that is not there is refused',
        () async {
      final result = await run({'type': 'media.play', 'playerId': 'ghost'});
      expect(result.success, isFalse);
    });
  });

  group('resource actions', () {
    test('subscribe with no host hook is reported', () async {
      // The fix this file once pinned the absence of. A host with no resource
      // handler used to log a warning and answer SUCCESS, so a document sat
      // waiting for data nobody had arranged to send. The tests that encoded
      // that were written from the implementation ("should still return
      // success"), not from the contract, and have been rewritten alongside
      // this one.
      final result = await run({
        'type': 'resource',
        'action': 'subscribe',
        'uri': 'mcp://resource/report',
        'binding': 'report',
      });
      expect(result.success, isFalse);
      expect(result.error, contains('subscribe'));
    });

    test('an unknown resource sub-action is refused', () async {
      final result = await run({'type': 'resource', 'action': 'teleport'});
      expect(result.success, isFalse);
    });
  });

  group('identity actions', () {
    test('an unknown identity action is named', () async {
      final result = await run({'type': 'identity.somersault'});
      expect(result.success, isFalse);
      expect(result.error, contains('identity'));
    });

    test('a declared identity op with no entry session answers, not throws',
        () async {
      // §8.9: a runtime with no entry context has no identity to act on. The
      // op is known (`promote` / `release`), so what matters is that the
      // document gets an answer it can branch on rather than an exception out
      // of a button.
      for (final op in const ['promote', 'release']) {
        final result = await run({'type': 'identity', 'action': op});
        expect(result, isNotNull, reason: 'identity.$op must answer');
      }
    });
  });

  group('state actions', () {
    test('set, increment, toggle and append reach state', () async {
      await run({'type': 'state', 'action': 'set', 'binding': 'count', 'value': 5});
      expect(stateManager.get('count'), 5);

      await run({'type': 'state', 'action': 'increment', 'binding': 'count'});
      expect(stateManager.get('count'), 6);

      await run({'type': 'state', 'action': 'set', 'binding': 'flag', 'value': false});
      await run({'type': 'state', 'action': 'toggle', 'binding': 'flag'});
      expect(stateManager.get('flag'), isTrue);

      await run({'type': 'state', 'action': 'set', 'binding': 'rows', 'value': <dynamic>[]});
      await run({'type': 'state', 'action': 'append', 'binding': 'rows', 'value': 'a'});
      expect(stateManager.get('rows'), ['a']);
    });

    test('a state action with no binding is reported, not thrown', () async {
      // Previously an exception, which travelled out of `ActionHandler.execute`
      // into whatever tapped the button and took the page down over one
      // malformed action.
      final result = await run({'type': 'state', 'action': 'set', 'value': 1});
      expect(result.success, isFalse);
      expect(result.error, contains('binding'));
    });

    test('an unknown state sub-action is refused', () async {
      final result =
          await run({'type': 'state', 'action': 'teleport', 'binding': 'count'});
      expect(result.success, isFalse);
    });
  });

  group('navigation without a navigator', () {
    test('every navigation action answers rather than throwing', () async {
      // `buildContext` is null here, which is what a headless render (a
      // dashboard tile, a test, a server-side pass) looks like. Nothing can
      // move, and each action says so rather than throwing into the caller.
      for (final action in const [
        {'type': 'navigation', 'action': 'push', 'route': '/next'},
        {'type': 'navigation', 'action': 'pop'},
        {'type': 'navigation', 'action': 'popToRoot'},
        {'type': 'navigation', 'action': 'replace', 'route': '/other'},
      ]) {
        final result = await run(Map<String, dynamic>.from(action));
        expect(result, isNotNull, reason: '$action must answer something');
      }
    });

    test('an unknown navigation action is refused, like every other one',
        () async {
      // The no-navigator answer comes first, so on a headless host a typo in
      // `action` reads the same as a real route that could not be opened.
      // Both are failures now, which is the honest answer: nothing moved
      // either way, and the message names the host's missing navigator.
      final result = await run({'type': 'navigation', 'action': 'teleport'});
      expect(result.success, isFalse);
    });
  });

  test('openUrl reports whether a host handler is wired', () {
    // A document linking out on a host that never wired the callback should be
    // able to find that out rather than tapping into silence.
    expect(NavigationActionExecutor.hasOnOpenUrl, isA<bool>());
  });
}
