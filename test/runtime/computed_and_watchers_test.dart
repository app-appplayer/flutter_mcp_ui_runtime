// `computed` and `watch` declared in a definition, end to end.
//
// The engine wires both at initialize time and nothing had exercised that
// path. A computed property that never recomputes shows a stale number with
// no error; a watcher that never fires means the side effect a document
// depends on — a fetch, a toast, a derived write — simply does not happen.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  late MCPUIRuntime runtime;

  /// §3.8 / §3.9 put `computed` and `watchers` inside the `state` block, and
  /// a computed value is the expression itself, not a `{expression, …}` wrap.
  Future<void> boot(Map<String, dynamic> stateExtra) async {
    runtime = MCPUIRuntime();
    await runtime.initialize(<String, dynamic>{
      'type': 'page',
      'state': <String, dynamic>{
        'initial': <String, dynamic>{'count': 1, 'log': '', 'hits': 0},
        ...stateExtra,
      },
      'content': <String, dynamic>{'type': 'text', 'content': 'x'},
    });
  }

  tearDown(() async => runtime.destroy());

  group('computed', () {
    test('a declared computed property resolves', () async {
      await boot(<String, dynamic>{
        'computed': <String, dynamic>{'mirror': '{{count}}'},
      });

      expect(runtime.engine.computedManager.getComputed('mirror'), 1);
    });

    test('it follows its dependency', () async {
      await boot(<String, dynamic>{
        'computed': <String, dynamic>{'mirror': '{{count}}'},
      });

      runtime.stateManager.set('count', 42);
      expect(runtime.engine.computedManager.getComputed('mirror'), 42,
          reason: 'a computed value that keeps its first answer is a cache '
              'with no invalidation, which shows yesterday\'s number');
    });

    test('a computed entry with no expression is skipped, not fatal',
        () async {
      await boot(<String, dynamic>{
        'computed': <String, dynamic>{'broken': 42},
      });

      expect(runtime.isInitialized, isTrue);
      expect(runtime.engine.computedManager.getComputed('broken'), isNull);
    });
  });

  group('watchers', () {
    test('a declared watcher runs its actions on change', () async {
      await boot(<String, dynamic>{
        'watchers': <dynamic>[
          <String, dynamic>{
            'watch': 'count',
            'actions': <dynamic>[
              <String, dynamic>{
                'type': 'state',
                'action': 'increment',
                'binding': 'hits',
                'value': 1,
              },
            ],
          },
        ],
      });

      runtime.stateManager.set('count', 2);
      await Future<void>.delayed(Duration.zero);

      expect(runtime.stateManager.get<int>('hits'), 1);
    });

    test('the handler sees the new value and the old one', () async {
      await boot(<String, dynamic>{
        'watchers': <dynamic>[
          <String, dynamic>{
            'watch': 'count',
            'actions': <dynamic>[
              <String, dynamic>{
                'type': 'state',
                'action': 'set',
                'binding': 'log',
                'value': '{{oldValue}}->{{value}}',
              },
            ],
          },
        ],
      });

      runtime.stateManager.set('count', 7);
      await Future<void>.delayed(Duration.zero);

      expect(runtime.stateManager.get<String>('log'), '1->7',
          reason: 'a watcher that cannot see what changed can only re-read '
              'state, which is what it was trying to avoid');
    });

    test('the implementation key spelling still works', () async {
      await boot(<String, dynamic>{
        'watchers': <dynamic>[
          <String, dynamic>{
            'path': 'count',
            'handler': <String, dynamic>{
              'type': 'state',
              'action': 'increment',
              'binding': 'hits',
              'value': 1,
            },
          },
        ],
      });

      runtime.stateManager.set('count', 3);
      await Future<void>.delayed(Duration.zero);

      expect(runtime.stateManager.get<int>('hits'), 1);
    });

    test('a watcher with no actions is skipped rather than throwing',
        () async {
      await boot(<String, dynamic>{
        'watchers': <dynamic>[
          <String, dynamic>{'watch': 'count'},
        ],
      });

      runtime.stateManager.set('count', 5);
      await Future<void>.delayed(Duration.zero);

      expect(runtime.isInitialized, isTrue);
      expect(runtime.stateManager.get<int>('hits'), 0);
    });
  });
}
