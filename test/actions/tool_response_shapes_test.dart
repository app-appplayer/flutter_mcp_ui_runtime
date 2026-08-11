// What the runtime does with what a tool answers.
//
// §3.10 / §4.4 name three response shapes — the MCP wire envelope, a plain
// map, and a legacy `{success, result}` wrapper — plus the loading binding
// that has to be cleared on every exit from the call, successful or not. Those
// exits were the uncovered part, and a loading flag that is set and never
// cleared is a spinner that turns forever over a screen that already has its
// data.

import 'dart:convert';

import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_result.dart';
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
    handler = ActionHandler();
    stateManager = StateManager()..initialize(<String, dynamic>{});
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
    );
  });

  /// Registers a tool answering [answer], or throwing [failWith].
  void tool(dynamic answer, {Object? failWith, Duration? delay}) {
    handler.registerToolExecutor('fetch', (params) async {
      if (delay != null) await Future<void>.delayed(delay);
      if (failWith != null) throw failWith;
      return answer;
    });
  }

  Future<ActionResult> call([Map<String, dynamic> extra = const {}]) =>
      handler.execute({'type': 'tool', 'tool': 'fetch', ...extra}, context);

  group('the MCP wire shape', () {
    test('is unwrapped and its body merged into state', () async {
      tool({
        'content': [
          {'type': 'text', 'text': jsonEncode({'rows': 3, 'total': 12})},
        ],
        'isError': false,
      });

      final result = await call();

      expect(result.success, isTrue);
      expect(stateManager.get('rows'), 3,
          reason: 'a host forwarding CallToolResult.toJson verbatim is the '
              'ordinary case; leaving the envelope unopened puts `content` '
              'into state and nothing a document can bind to');
      expect(stateManager.get('total'), 12);
    });

    test('isError: true is a failure, and nothing is merged', () async {
      tool({
        'content': [
          {'type': 'text', 'text': jsonEncode({'message': 'no such record'})},
        ],
        'isError': true,
      });

      final result = await call();

      expect(result.success, isFalse);
      expect(result.error, contains('no such record'),
          reason: 'the server said why; repeating "tool execution failed" '
              'throws that away');
      expect(stateManager.state.containsKey('message'), isFalse,
          reason: 'merging an error body would put the error text into the '
              'fields a screen is bound to');
    });

    test('an isError body that is not a map is still reported', () async {
      tool({
        'content': [
          {'type': 'text', 'text': 'plain failure text'},
        ],
        'isError': true,
      });

      final result = await call();
      expect(result.success, isFalse);
      expect(result.error, contains('plain failure'));
    });

    test('a map carrying `content` that is not the wire shape is left alone',
        () async {
      tool({'content': 'the article body', 'title': 'Ada'});

      final result = await call();

      expect(result.success, isTrue);
      expect(stateManager.get('content'), 'the article body',
          reason: 'a document whose data legitimately has a `content` field '
              'must not have it unwrapped out from under it');
      expect(stateManager.get('title'), 'Ada');
    });
  });

  group('the legacy envelope', () {
    test('success: true merges the inner result', () async {
      tool({
        'success': true,
        'result': {'rows': 2},
      });

      final result = await call();

      expect(result.success, isTrue);
      expect(stateManager.get('rows'), 2);
    });

    test('success: false is a failure carrying the envelope message',
        () async {
      tool({'success': false, 'error': 'permission denied'});

      final result = await call();

      expect(result.success, isFalse);
      expect(result.error, 'permission denied');
    });
  });

  group('a plain response', () {
    test('top-level keys auto-merge (§3.10)', () async {
      tool({'temperature': 21, 'unit': 'C'});

      await call();

      expect(stateManager.get('temperature'), 21);
      expect(stateManager.get('unit'), 'C');
    });

    test('bindResult puts the whole answer at one path instead', () async {
      tool({'temperature': 21});

      await call({'bindResult': 'reading'});

      expect(stateManager.get('reading'), {'temperature': 21});
      expect(stateManager.state.containsKey('temperature'), isFalse,
          reason: 'an explicit bindResult is a document saying where it wants '
              'the answer — merging as well would scatter it twice');
    });

    test('a non-map answer is returned without merging anything', () async {
      tool('just a string');

      final result = await call();

      expect(result.success, isTrue);
      expect(result.data, 'just a string');
    });

    test('a map with non-string keys is normalised before merging', () async {
      tool(<dynamic, dynamic>{'rows': 1});

      await call();

      expect(stateManager.get('rows'), 1,
          reason: 'jsonDecode hands back Map<dynamic, dynamic>; refusing it '
              'would drop the answer of any tool decoded that way');
    });
  });

  group('the loading binding', () {
    test('is raised for the call and lowered on success', () async {
      tool({'rows': 1}, delay: const Duration(milliseconds: 30));

      final pending = call({'loading': 'busy'});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(stateManager.get('busy'), isTrue,
          reason: 'the spinner has to be up while the call is out, not after');

      await pending;
      expect(stateManager.get('busy'), isFalse);
    });

    test('is lowered when the tool fails', () async {
      tool(null, failWith: StateError('server down'));

      final result = await call({'loading': 'busy'});

      expect(result.success, isFalse);
      expect(stateManager.get('busy'), isFalse,
          reason: 'a spinner left turning after a failure is the most common '
              'shape of a stuck screen');
    });

    test('is lowered when the wire shape reports an error', () async {
      tool({
        'content': [
          {'type': 'text', 'text': jsonEncode({'message': 'nope'})},
        ],
        'isError': true,
      });

      await call({'loading': 'busy'});
      expect(stateManager.get('busy'), isFalse);
    });

    test('the map form sets the flag; its `text` and `indicator` cannot land '
        '— pinned', () async {
      // §4.20 defines `loading` as `{binding, indicator}` and says the runtime
      // sets the binding to a BOOLEAN. The implementation also tries to write
      // `<binding>.text` and `<binding>.indicator`, and those writes can never
      // take effect: the binding itself already holds `true`, so a nested set
      // under a scalar is dropped (StateManager warns and moves on).
      //
      // Recorded rather than "fixed" in either direction — making them land
      // would mean either changing what `{{isLoading}}` resolves to (breaking
      // every document binding it as a bool) or inventing a state path the
      // spec does not define. That is a spec decision, not a test fix.
      tool({'rows': 1}, delay: const Duration(milliseconds: 30));

      final pending = call({
        'loading': {
          'binding': 'busy',
          'text': 'Fetching rows…',
          'indicator': 'linear',
        },
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(stateManager.get('busy'), isTrue,
          reason: 'the flag itself is the part §4.20 specifies, and it works');
      expect(stateManager.get('busy.text'), isNull);
      expect(stateManager.get('busy.indicator'), isNull);

      await pending;
      expect(stateManager.get('busy'), isFalse);
    });
  });

  group('timeout and retry', () {
    test('a call that overruns its timeout is reported', () async {
      tool({'rows': 1}, delay: const Duration(seconds: 2));

      final result = await call({'timeout': 60});

      expect(result.success, isFalse);
      expect(result.error, contains('timed out'),
          reason: 'a document that waits forever cannot show the user '
              'anything — the timeout is what turns a hang into a message');
    });

    test('onTimeout runs when the call overruns', () async {
      tool({'rows': 1}, delay: const Duration(seconds: 2));

      await call({
        'timeout': 60,
        'onTimeout': {
          'type': 'state',
          'action': 'set',
          'binding': 'timedOut',
          'value': true,
        },
      });

      expect(stateManager.get('timedOut'), isTrue);
    });

    test('a failing call is retried up to maxAttempts', () async {
      var attempts = 0;
      handler.registerToolExecutor('fetch', (params) async {
        attempts++;
        if (attempts < 3) throw StateError('transient');
        return {'rows': attempts};
      });

      final result = await call({
        'retry': {'maxAttempts': 3, 'delay': 10, 'backoff': 'fixed'},
      });

      expect(result.success, isTrue);
      expect(attempts, 3,
          reason: 'giving up on the first transient failure is what makes a '
              'flaky network look like a broken app');
      expect(stateManager.get('rows'), 3);
    });

    test('retries stop at the ceiling and the last error is reported',
        () async {
      var attempts = 0;
      handler.registerToolExecutor('fetch', (params) async {
        attempts++;
        throw StateError('always down');
      });

      final result = await call({
        'retry': {'maxAttempts': 2, 'delay': 10, 'backoff': 'linear'},
      });

      expect(attempts, 2);
      expect(result.success, isFalse);
      expect(result.error, contains('always down'));
    });

    test('retryOn narrows which failures are worth repeating', () async {
      var attempts = 0;
      handler.registerToolExecutor('fetch', (params) async {
        attempts++;
        throw StateError('permission denied');
      });

      final result = await call({
        'retry': {
          'maxAttempts': 3,
          'delay': 10,
          'retryOn': ['timeout', 'unavailable'],
        },
      });

      expect(attempts, 1,
          reason: 'a permission failure will not fix itself — retrying it '
              'three times only delays telling the user');
      expect(result.success, isFalse);
    });

    test('exponential backoff still lands within its attempt budget',
        () async {
      var attempts = 0;
      handler.registerToolExecutor('fetch', (params) async {
        attempts++;
        if (attempts < 2) throw StateError('transient');
        return {'ok': true};
      });

      final result = await call({
        'retry': {
          'maxAttempts': 3,
          'delay': 10,
          'backoff': 'exponential',
          'multiplier': 2,
          'maxDelay': 40,
        },
      });

      expect(result.success, isTrue);
      expect(attempts, 2);
    });
  });

  group('what cannot be called', () {
    test('the deprecated `args` key is refused rather than ignored', () async {
      tool({'rows': 1});

      await expectLater(
        handler.execute(
            {'type': 'tool', 'tool': 'fetch', 'args': <String, dynamic>{}},
            context),
        throwsA(isA<ArgumentError>()),
        reason: 'silently ignoring `args` would send an empty params map and '
            'the tool would answer for the wrong question',
      );
    });

    test('params are resolved against state before the call', () async {
      stateManager.set('query', 'ada');
      final seen = <Map<String, dynamic>>[];
      handler.registerToolExecutor('fetch', (params) async {
        seen.add(Map<String, dynamic>.from(params as Map));
        return {'ok': true};
      });

      await call({
        'params': {'q': '{{query}}', 'limit': 10},
      });

      expect(seen.single, {'q': 'ada', 'limit': 10},
          reason: 'sending the literal braces would search for the string '
              '"{{query}}"');
    });

    test('a params value that is not a map is treated as none', () async {
      final seen = <Map<String, dynamic>>[];
      handler.registerToolExecutor('fetch', (params) async {
        seen.add(Map<String, dynamic>.from(params as Map));
        return {'ok': true};
      });

      await call({'params': 'not a map'});

      expect(seen.single, isEmpty);
    });
  });
}
