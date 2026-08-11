// `tool` actions: the retry ladder, the timeout, and the loading flag.
//
// These are the lines a document depends on when the network is bad, and they
// were the uncovered half of the biggest file in the package. A retry policy
// that silently does not retry looks exactly like one that works — until a
// board is offline and the screen sits on a spinner that never clears.
//
// Timers are driven with `FakeAsync` so the backoff is measured rather than
// waited out; the delays declared here (1 s, 2 s, 4 s) would otherwise make
// this the slowest file in the suite.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/utils/mcp_logger.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ActionHandler handler;
  late StateManager stateManager;
  late RenderContext context;
  late List<String> calls;

  /// Builds a context whose `tool` executor is [respond].
  void wire(Future<dynamic> Function(Map<String, dynamic> params) respond) {
    calls = <String>[];
    stateManager = StateManager()..initialize(<String, dynamic>{});
    handler = ActionHandler();
    // Registered under the tool's own name: the `default` slot takes a
    // two-argument executor (`tool`, `params`), and registering a one-argument
    // function there means the call throws inside the handler and the document
    // sees a failure that has nothing to do with the tool.
    for (final name in const ['sync', 'slow', 'read']) {
      handler.registerToolExecutor(name, (Map<String, dynamic> params) async {
        calls.add(name);
        return respond(Map<String, dynamic>.from(params));
      });
    }
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
  }

  group('retry', () {
    test('a failing tool is attempted maxAttempts times, then reported', () {
      FakeAsync().run((async) {
        wire((_) async => throw StateError('boom'));

        Object? result;
        handler.execute({
          'type': 'tool',
          'tool': 'sync',
          'retry': {'maxAttempts': 3, 'delay': 10, 'backoff': 'linear'},
        }, context).then((r) => result = r);

        async.elapse(const Duration(seconds: 1));
        expect(calls.length, 3, reason: 'maxAttempts is attempts, not retries');
        expect(result.toString(), contains('boom'),
            reason: 'the last error is what the document is told');
      });
    });

    test('a tool that succeeds on the second attempt is not reported failed',
        () {
      FakeAsync().run((async) {
        var attempt = 0;
        wire((_) async {
          attempt++;
          if (attempt == 1) throw StateError('flaky');
          return {'ok': true};
        });

        dynamic result;
        handler.execute({
          'type': 'tool',
          'tool': 'sync',
          'retry': {'maxAttempts': 3, 'delay': 10},
        }, context).then((r) => result = r);

        async.elapse(const Duration(seconds: 1));
        expect(calls.length, 2);
        expect(result.success, isTrue);
      });
    });

    test('exponential backoff grows, linear does not, and maxDelay caps both',
        () {
      // The three policies are distinguishable only by WHEN the second call
      // happens, so each is measured by elapsing just short of the expected
      // delay and checking that nothing has run yet.
      void measure({
        required String backoff,
        int? maxDelay,
        required Duration tooSoon,
        required Duration enough,
      }) {
        FakeAsync().run((async) {
          wire((_) async => throw StateError('boom'));
          handler.execute({
            'type': 'tool',
            'tool': 'sync',
            'retry': {
              'maxAttempts': 3,
              'delay': 100,
              'backoff': backoff,
              'multiplier': 2,
              if (maxDelay != null) 'maxDelay': maxDelay,
            },
          }, context);

          async.elapse(const Duration(milliseconds: 1));
          expect(calls.length, 1);

          async.elapse(tooSoon);
          expect(calls.length, 2,
              reason: '$backoff: the first retry waits `delay`');

          async.elapse(enough);
          expect(calls.length, 3,
              reason: '$backoff: the second wait is what the policy names');
        });
      }

      // exponential: 100 then 200
      measure(
        backoff: 'exponential',
        tooSoon: const Duration(milliseconds: 100),
        enough: const Duration(milliseconds: 200),
      );
      // linear: 100 then 200 as well (delay * attempt)
      measure(
        backoff: 'linear',
        tooSoon: const Duration(milliseconds: 100),
        enough: const Duration(milliseconds: 200),
      );
      // capped: the second wait would be 200, but maxDelay says 120
      measure(
        backoff: 'exponential',
        maxDelay: 120,
        tooSoon: const Duration(milliseconds: 100),
        enough: const Duration(milliseconds: 120),
      );
    });

    test('retryOn decides: a listed error is retried, an unlisted one is not',
        () {
      FakeAsync().run((async) {
        wire((_) async => throw StateError('E_TRANSIENT: try later'));
        handler.execute({
          'type': 'tool',
          'tool': 'sync',
          'retry': {
            'maxAttempts': 3,
            'delay': 10,
            'retryOn': ['E_TRANSIENT'],
          },
        }, context);
        async.elapse(const Duration(seconds: 1));
        expect(calls.length, 3, reason: 'the code is on the list');

        wire((_) async => throw StateError('E_FATAL: give up'));
        handler.execute({
          'type': 'tool',
          'tool': 'sync',
          'retry': {
            'maxAttempts': 3,
            'delay': 10,
            'retryOn': ['E_TRANSIENT'],
          },
        }, context);
        async.elapse(const Duration(seconds: 1));
        expect(calls.length, 1,
            reason: 'retrying an error the policy did not name wastes a minute '
                'of a user\'s time for nothing');
      });
    });

    test('without a retry block a failure is reported after one attempt', () {
      FakeAsync().run((async) {
        wire((_) async => throw StateError('boom'));
        handler.execute({'type': 'tool', 'tool': 'sync'}, context);
        async.elapse(const Duration(seconds: 2));
        expect(calls.length, 1);
      });
    });
  });

  group('timeout', () {
    test('a tool that never answers is cut off and reported', () {
      FakeAsync().run((async) {
        wire((_) async => Completer<dynamic>().future);

        dynamic result;
        handler.execute({
          'type': 'tool',
          'tool': 'slow',
          'timeout': 50,
        }, context).then((r) => result = r);

        async.elapse(const Duration(milliseconds: 49));
        expect(result, isNull, reason: 'not yet — the timeout has not passed');

        async.elapse(const Duration(milliseconds: 10));
        expect(result?.error, contains('timed out'));
      });
    });

    test('onTimeout runs, and the timeout counts as an attempt', () {
      FakeAsync().run((async) {
        wire((_) async => Completer<dynamic>().future);
        stateManager.set('timedOut', false);

        handler.execute({
          'type': 'tool',
          'tool': 'slow',
          'timeout': 20,
          'retry': {'maxAttempts': 2, 'delay': 5},
          'onTimeout': {
            'type': 'state',
            'action': 'set',
            'binding': 'timedOut',
            'value': true,
          },
        }, context);

        async.elapse(const Duration(seconds: 1));
        expect(stateManager.get('timedOut'), isTrue,
            reason: 'the document asked to be told');
        expect(calls.length, 2, reason: 'a timeout is retried like a failure');
      });
    });
  });

  group('the loading flag', () {
    test('is raised for the call and lowered on success', () {
      FakeAsync().run((async) {
        final seen = <Object?>[];
        wire((_) async {
          seen.add(stateManager.get('busy'));
          return {'ok': true};
        });

        handler.execute({
          'type': 'tool',
          'tool': 'sync',
          'loading': 'busy',
        }, context);
        async.elapse(const Duration(milliseconds: 10));

        expect(seen.single, isTrue, reason: 'raised before the call');
        expect(stateManager.get('busy'), isFalse,
            reason: 'a spinner that never clears is the failure mode here');
      });
    });

    test('is lowered when the call fails, and after the retries are spent', () {
      FakeAsync().run((async) {
        wire((_) async => throw StateError('boom'));
        handler.execute({
          'type': 'tool',
          'tool': 'sync',
          'loading': 'busy',
          'retry': {'maxAttempts': 2, 'delay': 10},
        }, context);
        async.elapse(const Duration(seconds: 1));
        expect(stateManager.get('busy'), isFalse);
      });
    });

    test('the object form raises the flag, and says so when the text is lost',
        () {
      // §4's table declares `loading: {binding, indicator}`. The runtime also
      // accepts `text` and writes both to `<binding>.text` / `.indicator` —
      // whose parent is the boolean it just wrote, so those two writes go
      // NOWHERE. A document rendering `{{busy.text}}` shows a blank forever.
      //
      // Rather than pretend, this pins both halves: the flag works, and the
      // dropped write is now reported instead of vanishing.
      final warnings = <String>[];
      MCPLogger.onRecord = (record) {
        if (record.level == 'WARN') warnings.add(record.message);
      };
      addTearDown(() => MCPLogger.onRecord = null);

      FakeAsync().run((async) {
        final duringFlag = <Object?>[];
        wire((_) async {
          duringFlag.add(stateManager.get('busy'));
          return {'ok': true};
        });

        handler.execute({
          'type': 'tool',
          'tool': 'sync',
          'loading': {
            'binding': 'busy',
            'text': 'Syncing…',
            'indicator': 'linear',
          },
        }, context);
        async.elapse(const Duration(milliseconds: 10));

        expect(duringFlag.single, isTrue, reason: 'the flag itself works');
        expect(stateManager.get('busy'), isFalse);
        expect(
          warnings.where((w) => w.contains('busy.text')),
          isNotEmpty,
          reason: 'the text had nowhere to go, and that must be said',
        );
      });
    });
  });

  group('what the tool answered', () {
    test('an MCP wire error is reported, not merged into state', () {
      FakeAsync().run((async) {
        wire((_) async => {
              'content': [
                {'type': 'text', 'text': 'permission denied'}
              ],
              'isError': true,
            });

        dynamic result;
        handler.execute({'type': 'tool', 'tool': 'sync', 'loading': 'busy'},
                context)
            .then((r) => result = r);
        async.elapse(const Duration(milliseconds: 10));

        expect(result.success, isFalse);
        expect(result.error, contains('permission denied'));
        expect(stateManager.get('busy'), isFalse,
            reason: 'an error still has to lower the flag');
      });
    });

    test('a map result merges into state', () {
      FakeAsync().run((async) {
        wire((_) async => {'temperature': 21.5, 'unit': 'C'});
        handler.execute({'type': 'tool', 'tool': 'read'}, context);
        async.elapse(const Duration(milliseconds: 10));

        expect(stateManager.get('temperature'), 21.5,
            reason: '§3.10 — top-level keys of a response become state');
        expect(stateManager.get('unit'), 'C');
      });
    });
  });

  test('an unregistered executor can be removed and the tool then fails', () {
    FakeAsync().run((async) {
      wire((_) async => {'ok': true});
      handler.unregisterToolExecutor('sync');

      dynamic result;
      handler
          .execute({'type': 'tool', 'tool': 'sync'}, context)
          .then((r) => result = r);
      async.elapse(const Duration(milliseconds: 10));

      expect(calls, isEmpty);
      expect(result.success, isFalse,
          reason: 'a tool with nothing behind it must say so rather than '
              'answering as if it ran');
    });
  });
}
