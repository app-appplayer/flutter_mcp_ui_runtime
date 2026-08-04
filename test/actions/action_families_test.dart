// The action families that had no coverage: batch, conditional, channel
// control, and the state operations beyond `set`. Each of these decides
// whether the *rest* of a document's work happens, so a wrong answer here is
// not a wrong pixel — it is a step that never ran.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  late MCPUIRuntime runtime;

  Future<MCPUIRuntime> boot([Map<String, dynamic>? initial]) async {
    final rt = MCPUIRuntime();
    await rt.initialize(<String, dynamic>{
      'type': 'page',
      if (initial != null)
        'state': <String, dynamic>{'initial': initial},
      'content': <String, dynamic>{'type': 'text', 'content': 'x'},
    });
    return rt;
  }

  Future<ActionResult> run(Map<String, dynamic> action) => runtime
      .engine.actionHandler
      .execute(action, runtime.engine.renderer.createRootContext(null));

  tearDown(() async => runtime.destroy());

  group('state operations', () {
    setUp(() async {
      runtime = await boot(<String, dynamic>{
        'count': 1,
        'items': <dynamic>['a'],
        'flag': false,
      });
    });

    test('increment and decrement move by the given amount', () async {
      await run(<String, dynamic>{
        'type': 'state',
        'action': 'increment',
        'binding': 'count',
        'value': 4,
      });
      expect(runtime.stateManager.get<int>('count'), 5);

      await run(<String, dynamic>{
        'type': 'state',
        'action': 'decrement',
        'binding': 'count',
        'value': 2,
      });
      expect(runtime.stateManager.get<int>('count'), 3);
    });

    test('toggle flips a boolean', () async {
      await run(<String, dynamic>{
        'type': 'state',
        'action': 'toggle',
        'binding': 'flag',
      });
      expect(runtime.stateManager.get<bool>('flag'), isTrue);
    });

    test('append adds to a list without replacing it', () async {
      await run(<String, dynamic>{
        'type': 'state',
        'action': 'append',
        'binding': 'items',
        'value': 'b',
      });
      expect(runtime.stateManager.get<List>('items'), <dynamic>['a', 'b']);
    });

    test('remove takes a value back out', () async {
      await run(<String, dynamic>{
        'type': 'state',
        'action': 'append',
        'binding': 'items',
        'value': 'b',
      });
      await run(<String, dynamic>{
        'type': 'state',
        'action': 'remove',
        'binding': 'items',
        'value': 'a',
      });
      expect(runtime.stateManager.get<List>('items'), <dynamic>['b']);
    });

    test('an unknown state action is reported, not ignored', () async {
      final result = await run(<String, dynamic>{
        'type': 'state',
        'action': 'levitate',
        'binding': 'count',
      });
      expect(result.success, isFalse,
          reason: 'silently succeeding on an unknown verb means a typo in a '
              'document looks like a working action');
    });
  });

  group('batch', () {
    setUp(() async => runtime = await boot(<String, dynamic>{'n': 0}));

    test('runs every action in order', () async {
      await run(<String, dynamic>{
        'type': 'batch',
        'actions': <dynamic>[
          <String, dynamic>{
            'type': 'state',
            'action': 'set',
            'binding': 'n',
            'value': 1
          },
          <String, dynamic>{
            'type': 'state',
            'action': 'increment',
            'binding': 'n',
            'value': 10
          },
        ],
      });
      expect(runtime.stateManager.get<int>('n'), 11);
    });

    test('an empty batch succeeds', () async {
      final result = await run(<String, dynamic>{
        'type': 'batch',
        'actions': <dynamic>[],
      });
      expect(result.success, isTrue);
    });
  });

  group('conditional', () {
    setUp(() async =>
        runtime = await boot(<String, dynamic>{'ok': true, 'n': 0}));

    test('takes the then branch when the condition holds', () async {
      await run(<String, dynamic>{
        'type': 'conditional',
        'condition': '{{ok}}',
        'then': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'n',
          'value': 1,
        },
        'else': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'n',
          'value': 2,
        },
      });
      expect(runtime.stateManager.get<int>('n'), 1);
    });

    test('takes the else branch when it does not', () async {
      runtime.stateManager.set('ok', false);
      await run(<String, dynamic>{
        'type': 'conditional',
        'condition': '{{ok}}',
        'then': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'n',
          'value': 1,
        },
        'else': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'n',
          'value': 2,
        },
      });
      expect(runtime.stateManager.get<int>('n'), 2);
    });

    test('a false condition with no else is still a success', () async {
      runtime.stateManager.set('ok', false);
      final result = await run(<String, dynamic>{
        'type': 'conditional',
        'condition': '{{ok}}',
        'then': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'n',
          'value': 1,
        },
      });
      expect(result.success, isTrue);
      expect(runtime.stateManager.get<int>('n'), 0);
    });
  });

  group('channel control', () {
    setUp(() async => runtime = await boot());

    test('an unknown sub-action is named in the error', () async {
      final result = await run(<String, dynamic>{
        'type': 'channel',
        'action': 'levitate',
        'channel': 'feed',
      });
      expect(result.success, isFalse);
      expect(result.error, contains('levitate'));
    });

    test('acting on an unknown channel fails rather than reporting success',
        () async {
      final result = await run(<String, dynamic>{
        'type': 'channel',
        'action': 'start',
        'channel': 'nope',
      });
      expect(result.success, isFalse,
          reason: 'a start that reports success on a channel that does not '
              'exist leaves a document waiting for data forever');
    });
  });

  group('unknown action types', () {
    setUp(() async => runtime = await boot());

    test('are reported with the type named', () async {
      final result = await run(<String, dynamic>{'type': 'telepathy'});
      expect(result.success, isFalse);
      expect(result.error, contains('telepathy'));
    });

    test('an action with no type at all is refused', () async {
      final result = await run(<String, dynamic>{'action': 'set'});
      expect(result.success, isFalse);
    });
  });
}
