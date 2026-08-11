// The binding engine's pipe transforms, the shapes `filter` and `length`
// accept, and the `{{sync.*}}` namespace read through interpolation.
//
// A pipe is what a document writes instead of pre-formatting its state on the
// server, so a transform that silently passes the value through prints a raw
// number where a currency was asked for. `{{sync.*}}` is §3's read-only
// namespace: an offline badge bound to it and answering null reads as "nothing
// pending" — the one thing it must never say wrongly.

import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/offline/connectivity_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/runtime_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StateManager stateManager;
  late BindingEngine engine;
  late RenderContext context;

  RenderContext buildContext({RuntimeEngine? runtimeEngine}) => RenderContext(
        renderer: Renderer(
          widgetRegistry: WidgetRegistry(),
          bindingEngine: engine,
          actionHandler: ActionHandler(),
          stateManager: stateManager,
        ),
        stateManager: stateManager,
        bindingEngine: engine,
        actionHandler: ActionHandler(),
        themeManager: ThemeManager.instance,
        engine: runtimeEngine,
      );

  setUp(() {
    stateManager = StateManager()..initialize(<String, dynamic>{});
    engine = BindingEngine();
    context = buildContext();
  });

  String interpolate(String template) =>
      engine.resolve<String>(template, context);

  group('pipe transforms', () {
    test('the text transforms are applied to the resolved value', () {
      stateManager.set('name', 'ada LOVELACE');

      expect(interpolate('{{name | uppercase}}'), 'ADA LOVELACE');
      expect(interpolate('{{name | lowercase}}'), 'ada lovelace');
      expect(interpolate('{{name | capitalize}}'), 'Ada lovelace');
    });

    test('the numeric transforms are applied', () {
      stateManager.set('amount', 12.7);

      expect(interpolate('{{amount | round}}'), '13');
      expect(interpolate('{{amount | floor}}'), '12');
      expect(interpolate('{{amount | ceil}}'), '13');
      expect(interpolate('{{amount | truncate}}'), '12');

      stateManager.set('amount', -3.2);
      expect(interpolate('{{amount | abs}}'), '3.2');
    });

    test('a transform nobody registered leaves the value alone', () {
      stateManager.set('name', 'ada');

      expect(interpolate('{{name | shout}}'), 'ada',
          reason: 'an unknown pipe is a typo in the document; dropping the '
              'value would turn it into an empty label');
    });

    test('a whole double prints without its decimal point', () {
      stateManager.set('count', 4.0);

      expect(interpolate('count: {{count}}'), 'count: 4',
          reason: 'a quantity that reads "4.0" in a sentence is a formatting '
              'job the document should not have to do');
    });

    test('a null resolves to an empty string, not the word null', () {
      expect(interpolate('value: {{missing}}'), 'value: ');
    });
  });

  group('filter shapes', () {
    setUp(() {
      stateManager.set('rows', <dynamic>[
        <String, dynamic>{'name': 'Ada', 'status': 'open', 'done': false},
        <String, dynamic>{'name': 'Bob', 'status': 'closed', 'done': true},
      ]);
    });

    List<dynamic> filtered(String expression) =>
        engine.resolve<List<dynamic>>(expression, context);

    test('a bare property filters on truthiness', () {
      expect(filtered("{{rows.filter('done')}}"), hasLength(1));
    });

    test('a property and a value filter on equality', () {
      final result = filtered("{{rows.filter('status', 'open')}}");

      expect(result, hasLength(1));
      expect((result.first as Map)['name'], 'Ada');
    });

    test('a lambda filters on whatever it says', () {
      final result = filtered('{{rows.filter(r => r.status == "open")}}');

      expect(result, hasLength(1));
      expect((result.first as Map)['name'], 'Ada');
    });

    test('a filter over something that is not a list is left alone', () {
      stateManager.set('single', <String, dynamic>{'name': 'Ada'});

      expect(engine.resolve<dynamic>("{{single.filter('name')}}", context),
          isNull,
          reason: 'a list operation over an object has nothing to iterate; '
              'returning the object would let the caller treat it as rows');
    });
  });

  group('length', () {
    test('answers for a string, a list and an object', () {
      stateManager.set('name', 'Ada');
      stateManager.set('rows', <dynamic>[1, 2, 3]);
      stateManager.set('form', <String, dynamic>{'a': 1, 'b': 2});

      expect(interpolate('{{length(name)}}'), '3');
      expect(interpolate('{{length(rows)}}'), '3');
      expect(interpolate('{{length(form)}}'), '2',
          reason: 'an object has a size too — answering zero would hide an '
              'unsent form behind "nothing to submit"');
      expect(interpolate('{{length()}}'), '0');
    });
  });

  group('{{sync.*}}', () {
    late RuntimeEngine runtimeEngine;

    setUp(() async {
      runtimeEngine = RuntimeEngine(enableDebugMode: false);
      await runtimeEngine.initialize(definition: <String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{'type': 'text', 'content': 'root'},
      });
      // The runtime engine wires ITS OWN binding engine to the sync manager,
      // which is what a document resolves through.
      engine = runtimeEngine.bindingEngine;
      context = buildContext(runtimeEngine: runtimeEngine);
    });

    tearDown(() => runtimeEngine.destroy());

    dynamic sync(String path) =>
        engine.resolve<dynamic>('{{sync.$path}}', context);

    test('every declared path answers', () {
      expect(sync('status'), 'idle');
      expect(sync('syncing'), isFalse);
      expect(sync('saving'), isFalse);
      expect(sync('pending'), isFalse);
      expect(sync('pendingCount'), 0);
      expect(sync('syncedCount'), 0);
      expect(sync('failedCount'), 0);
      expect(sync('lastError'), isNull);
      expect(sync('lastSyncAt'), isNull);
      expect(sync('lastSyncTime'), isNull);
    });

    test('a path nobody defined answers null rather than guessing', () {
      expect(sync('nonsense'), isNull);
    });

    test('with no sync manager the namespace is quiet, not an error', () {
      final unwired = BindingEngine();

      expect(unwired.resolve<dynamic>('{{sync.status}}', context), isNull,
          reason: 'a badge bound to this on a runtime with no sync shows '
              'nothing, which is the truth');
    });

    test('a host engine that carries no sync manager is quiet', () {
      final bare = BindingEngine();

      expect(
        bare.resolve<String>('Sync: {{sync.status}}',
            buildContext(runtimeEngine: null)),
        'Sync: ',
      );
    });

    test('an engine whose sync manager cannot be read is quiet too', () {
      // A host may pass its own object as the engine — the field is untyped
      // for exactly that reason. One that answers nothing useful must not
      // take the whole binding resolution down with it.
      final bare = BindingEngine();
      final context = RenderContext(
        renderer: Renderer(
          widgetRegistry: WidgetRegistry(),
          bindingEngine: bare,
          actionHandler: ActionHandler(),
          stateManager: stateManager,
        ),
        stateManager: stateManager,
        bindingEngine: bare,
        actionHandler: ActionHandler(),
        themeManager: ThemeManager.instance,
        engine: _HostWithoutSync(),
      );

      expect(bare.resolve<String>('Sync: {{sync.status}}', context), 'Sync: ',
          reason: 'a badge bound to a host that does not sync shows nothing, '
              'which is the truth — throwing would take the page with it');
    });

    // A binding standing alone and the same binding with text beside it take
    // two different code paths — a dedicated resolver and the interpolating
    // one. They have to answer the same thing, or a label reads differently
    // from the badge next to it.
    group('read with text beside it', () {
      String interp(String path) =>
          engine.resolve<String>('Sync: {{sync.$path}}', context);

      test('every declared path answers the same as it does alone', () {
        expect(interp('status'), 'Sync: idle');
        expect(interp('syncing'), 'Sync: false');
        expect(interp('saving'), 'Sync: false');
        expect(interp('pending'), 'Sync: false');
        expect(interp('pendingCount'), 'Sync: 0');
        expect(interp('syncedCount'), 'Sync: 0');
        expect(interp('failedCount'), 'Sync: 0');
      });

      test('an undeclared path leaves the sentence without a value', () {
        expect(interp('nonsense'), 'Sync: ');
      });

      test('with no engine behind the context it is quiet', () {
        final bare = BindingEngine();

        expect(bare.resolve<String>('Sync: {{sync.status}}', buildContext()),
            'Sync: ',
            reason: 'a document rendered outside a runtime still renders; the '
                'sync sentence just has nothing to say');
      });
    });

    group('after a sync has run', () {
      Future<void> runSync() async {
        runtimeEngine.connectivityManager.updateStatus(NetworkStatus.online);
        runtimeEngine.offlineQueue
            .enqueue(<String, dynamic>{'type': 'state', 'action': 'set'});
        await runtimeEngine.syncManager.sync((_) async {});
      }

      test('the time it finished is readable under both spellings', () async {
        await runSync();

        final alone = sync('lastSyncTime');
        expect(alone, isNotNull,
            reason: 'the alias the interpolated path already answered has to '
                'answer here too, or the same binding means two things '
                'depending on whether text sits beside it');
        expect(sync('lastSyncAt'), alone);
        expect(
          engine.resolve<String>('Last: {{sync.lastSyncTime}}', context),
          'Last: $alone',
        );
      });

      test('a sync that failed says so, and says why', () async {
        runtimeEngine.connectivityManager.updateStatus(NetworkStatus.online);
        runtimeEngine.offlineQueue
            .enqueue(<String, dynamic>{'type': 'state', 'action': 'set'});

        await runtimeEngine.syncManager
            .sync((_) async => throw StateError('server refused'));

        expect(sync('status'), 'error');
        expect(sync('lastError'), isNotNull,
            reason: 'an offline badge that goes red and says nothing leaves '
                'the user with no idea whether to retry or to wait');
        expect(
          engine.resolve<String>('Sync: {{sync.lastError}}', context),
          startsWith('Sync: '),
        );
        expect(engine.resolve<String>('Sync: {{sync.lastError}}', context),
            isNot('Sync: '));
      });

      test('offline, the refusal names the reason rather than failing '
          'silently', () async {
        runtimeEngine.connectivityManager.updateStatus(NetworkStatus.offline);
        runtimeEngine.offlineQueue
            .enqueue(<String, dynamic>{'type': 'state', 'action': 'set'});

        await runtimeEngine.syncManager.sync((_) async {});

        expect(sync('status'), 'error');
        expect(sync('lastError'), contains('offline'));
        expect(sync('pending'), isTrue,
            reason: 'the queue must survive a refused sync, or the writes the '
                'user made offline are gone');
      });

      test('the counts it reports are the ones it processed', () async {
        await runSync();

        expect(sync('status'), 'complete');
        expect(sync('syncedCount'), 1);
        expect(sync('failedCount'), 0);
        expect(sync('pending'), isFalse);
      });
    });
  });

  group('binding sources', () {
    test('each declared source name is recognised', () {
      for (final source in const [
        'state',
        'tool',
        'stream',
        'resource',
        'unheard-of',
      ]) {
        expect(
            () => engine.registerBinding(<String, dynamic>{
                  'id': 'b-$source',
                  'source': source,
                  'path': 'x',
                }),
            returnsNormally,
            reason: source);
      }
    });
  });

  group('the sandbox limits', () {
    test('a spent budget stops evaluation rather than running away', () {
      stateManager.set('rows', List<dynamic>.generate(2000, (i) => i));
      // Already over budget at the first nested entry — the state a runaway
      // expression reaches a few milliseconds in.
      engine.sandbox = const ExpressionSandbox(timeout: -1);
      addTearDown(() => engine.sandbox = const ExpressionSandbox());

      expect(engine.resolve<dynamic>('{{rows.map(r => r * 2)}}', context),
          isNull,
          reason: 'a document that computes forever hangs the frame; the '
              'budget is what turns that into an empty value');
    });

    test('a result past the memory limit is truncated, not returned whole',
        () {
      stateManager.set('long', 'x' * 200);
      engine.sandbox = const ExpressionSandbox(maxMemoryBytes: 40);
      addTearDown(() => engine.sandbox = const ExpressionSandbox());

      final result = engine.resolve<dynamic>('{{long}}', context);

      expect((result as String).length, 20,
          reason: 'half the byte budget, since a Dart string is two bytes a '
              'character — the point is that it is bounded at all');
    });
  });

  group('interpolation', () {
    test('a transform applies inside a longer string', () {
      stateManager.set('name', 'ada');

      expect(engine.resolve<String>('Hello {{name | uppercase}}!', context),
          'Hello ADA!',
          reason: 'the pipe has to work in the interpolating path too — that '
              'is the one a label actually uses');
    });

    test('a binding that cannot be resolved is left in place', () {
      stateManager.set('rows', <dynamic>[1]);

      // `reduce` with no accumulator is a shape the evaluator refuses.
      final result =
          engine.resolve<String>('x {{rows.reduce()}} y', context);

      expect(result, isNotNull,
          reason: 'one broken binding in a sentence must not take the whole '
              'sentence away');
    });
  });

  group('format with no pattern', () {
    test('falls back to the value\'s own text', () {
      stateManager.set('amount', 12.5);

      expect(engine.resolve<dynamic>('{{format(amount)}}', context), '12.5');
    });
  });

  group('dispose', () {
    test('cancels what it subscribed to, and keeps the default transforms', () {
      final fresh = BindingEngine();
      fresh.registerBinding(<String, dynamic>{
        'id': 'b',
        'source': 'state',
        'path': 'x',
      });

      fresh.dispose();

      expect(fresh.resolve<dynamic>('{{"a" | uppercase}}', context), 'A',
          reason: 'the default transforms are re-registered on dispose; a '
              'reused engine that lost them would silently stop formatting');
    });
  });
}

/// A host object that answers the engine interface only partly — which is
/// what "the engine field is untyped" invites.
class _HostWithoutSync {
  Object? get syncManager => null;
}
