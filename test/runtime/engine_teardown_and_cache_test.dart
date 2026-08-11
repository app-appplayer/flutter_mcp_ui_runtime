// What the engine does on the way out, and what it does with a cached app.
//
// Destroying a runtime has to release the subscriptions it opened: a document
// that is gone but still subscribed keeps a server pushing to nobody, and the
// next document over gets its updates. The cache path is the other side of the
// same question — a runtime that starts from cache has to start from the
// cached STATE too, or the screen is a fresh one wearing an old app's name.

import 'package:flutter_mcp_ui_runtime/src/runtime/runtime_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late RuntimeEngine engine;

  setUp(() => engine = RuntimeEngine(enableDebugMode: false));

  group('destroy', () {
    test('releases every resource subscription it opened', () async {
      final released = <String>[];
      await engine.initialize(definition: {
        'type': 'page',
        'content': {'type': 'box'},
      });
      engine.setResourceHandlers(
          onResourceUnsubscribe: (uri) async => released.add(uri));

      engine.registerResourceSubscription('ui://rows', 'rows');
      engine.registerResourceSubscription('ui://status', 'status');

      await engine.destroy();

      expect(released, containsAll(['ui://rows', 'ui://status']),
          reason: 'a document that is gone but still subscribed keeps a server '
              'pushing to nobody, and the next document gets its updates');
    });

    test('one unsubscribe that fails does not strand the rest', () async {
      final released = <String>[];
      await engine.initialize(definition: {
        'type': 'page',
        'content': {'type': 'box'},
      });
      engine.setResourceHandlers(onResourceUnsubscribe: (uri) async {
        if (uri.endsWith('first')) throw StateError('the socket is gone');
        released.add(uri);
      });

      engine.registerResourceSubscription('ui://first', 'a');
      engine.registerResourceSubscription('ui://second', 'b');

      await engine.destroy();

      expect(released, ['ui://second'],
          reason: 'a teardown that stops at the first failure leaves every '
              'subscription after it open for the life of the process');
    });

    test('with no unsubscribe hook it still tears down', () async {
      await engine.initialize(definition: {
        'type': 'page',
        'content': {'type': 'box'},
      });
      engine.registerResourceSubscription('ui://rows', 'rows');

      await engine.destroy();
      expect(engine.isReady, isFalse);
    });

    test('a destroy before initialize is a no-op', () async {
      await engine.destroy();
      expect(engine.isReady, isFalse);
    });

    test('runs the document\'s onDestroy hooks', () async {
      await engine.initialize(definition: {
        'type': 'page',
        'content': {'type': 'box'},
        'lifecycle': {
          'onDestroy': [
            {
              'type': 'state',
              'action': 'set',
              'binding': 'torn',
              'value': true,
            },
          ],
        },
      });

      await engine.destroy();
      // Read after destroy: the hook ran against the state that was there.
      expect(engine.stateManager.get('torn'), isTrue);
    });
  });

  group('a sandbox declared by the document', () {
    test('is applied to the binding engine', () async {
      await engine.initialize(definition: {
        'type': 'page',
        'content': {'type': 'box'},
        'sandbox': {'timeout': 50, 'maxIterations': 100},
      });

      expect(engine.bindingEngine.sandbox.timeout, 50);
      expect(engine.bindingEngine.sandbox.maxIterations, 100,
          reason: '§7 — an expression budget the runtime ignores is a budget '
              'the document cannot rely on to bound a hostile payload');

      await engine.destroy();
    });

    test('with none declared the defaults stand', () async {
      await engine.initialize(definition: {
        'type': 'page',
        'content': {'type': 'box'},
      });

      expect(engine.bindingEngine.sandbox.timeout, greaterThan(0));
      await engine.destroy();
    });
  });

  group('the theme from a runtime services block', () {
    test('is applied', () async {
      await engine.initialize(definition: {
        'type': 'page',
        'content': {'type': 'box'},
        'runtime': {
          'services': {
            'theme': {
              'colors': {'primary': '#FF0000'},
            },
          },
        },
      });

      expect(engine.themeManager.getThemeValue('color.primary'), isNotNull,
          reason: 'a theme declared in the legacy services block and never '
              'applied leaves every widget on the default scheme, with the '
              'document\'s own colours nowhere');

      await engine.destroy();
    });
  });
}
