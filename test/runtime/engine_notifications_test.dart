// `RuntimeEngine`'s resource-notification paths.
//
// This is what turns a server push into a state change: a subscription maps a
// URI to a binding, and a notification lands its content there. A push that
// finds no binding, or carries no content, has to be a no-op — writing null
// would blank a live panel, and writing to the wrong binding would put one
// resource's data under another's name.

import 'dart:convert';

import 'package:flutter_mcp_ui_runtime/src/runtime/runtime_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RuntimeEngine engine;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    engine = RuntimeEngine(enableDebugMode: true);
    await engine.initialize(definition: <String, dynamic>{
      'type': 'page',
      'content': <String, dynamic>{'type': 'text', 'content': 'root'},
    });
  });

  tearDown(() => engine.destroy());

  group('subscriptions', () {
    test('a URI maps to its binding, and unregistering removes it', () {
      engine.registerResourceSubscription('ui://rows', 'rows');

      expect(engine.getBindingForUri('ui://rows'), 'rows');

      engine.unregisterResourceSubscription('ui://rows');
      expect(engine.getBindingForUri('ui://rows'), isNull,
          reason: 'a subscription the document dropped must stop writing, or '
              'a closed panel keeps updating in the background');
    });
  });

  group('handleResourceNotification', () {
    test('content lands at the subscribed binding', () {
      engine.registerResourceSubscription('ui://rows', 'rows');

      engine.handleResourceNotification('ui://rows', <String, dynamic>{
        'content': <dynamic>[1, 2, 3],
      });

      expect(engine.stateManager.get('rows'), <dynamic>[1, 2, 3]);
    });

    test('a push with no content leaves the binding alone', () {
      engine.registerResourceSubscription('ui://rows', 'rows');
      engine.stateManager.set('rows', <dynamic>[1]);

      engine.handleResourceNotification('ui://rows', <String, dynamic>{});

      expect(engine.stateManager.get('rows'), <dynamic>[1],
          reason: 'writing null on an empty push would blank a live panel');
    });

    test('a push for a URI nobody subscribed to is a no-op', () {
      engine.handleResourceNotification('ui://unknown', <String, dynamic>{
        'content': <dynamic>[1],
      });

      expect(engine.stateManager.get('unknown'), isNull);
    });
  });

  group('handleMCPNotification', () {
    test('a notification with no URI is ignored', () async {
      await engine.handleMCPNotification(<String, dynamic>{});

      expect(engine.stateManager.state.keys, isNot(contains('rows')));
    });

    test('the extended form parses the wrapped text and stores it', () async {
      engine.registerResourceSubscription('ui://rows', 'rows');
      engine.stateManager.set('notificationCount', 0);

      await engine.handleMCPNotification(<String, dynamic>{
        'uri': 'ui://rows',
        'content': <String, dynamic>{
          'text': jsonEncode(<String, dynamic>{'total': 3}),
        },
      });

      expect(engine.stateManager.get('rows'), <String, dynamic>{'total': 3},
          reason: 'the wrapper carries the payload as a JSON string; storing '
              'the string itself would make every binding under it read as '
              'text');
      expect(engine.stateManager.get('notificationCount'), 1,
          reason: 'the count is what a badge binds to; leaving it still makes '
              'the badge say nothing arrived');
    });

    test('text that will not parse leaves the binding alone', () async {
      engine.registerResourceSubscription('ui://rows', 'rows');
      engine.stateManager.set('rows', <dynamic>[1]);

      await engine.handleMCPNotification(<String, dynamic>{
        'uri': 'ui://rows',
        'content': <String, dynamic>{'text': 'not json'},
      });

      expect(engine.stateManager.get('rows'), <dynamic>[1]);
    });

    test('content with no text wrapper is stored as it arrived', () async {
      engine.registerResourceSubscription('ui://rows', 'rows');

      await engine.handleMCPNotification(<String, dynamic>{
        'uri': 'ui://rows',
        'content': <String, dynamic>{'total': 5},
      });

      expect(engine.stateManager.get('rows'), <String, dynamic>{'total': 5});
    });

    test('the standard form reads the resource through the host', () async {
      engine.registerResourceSubscription('ui://rows', 'rows');
      engine.stateManager.set('notificationCount', 2);

      await engine.handleMCPNotification(
        <String, dynamic>{'uri': 'ui://rows'},
        resourceReader: (uri) async =>
            jsonEncode(<String, dynamic>{'total': 7}),
      );

      expect(engine.stateManager.get('rows'), <String, dynamic>{'total': 7});
      expect(engine.stateManager.get('notificationCount'), 3);
    });

    test('a reader that fails leaves the binding alone', () async {
      engine.registerResourceSubscription('ui://rows', 'rows');
      engine.stateManager.set('rows', <dynamic>[1]);

      await engine.handleMCPNotification(
        <String, dynamic>{'uri': 'ui://rows'},
        resourceReader: (uri) async => throw StateError('gone'),
      );

      expect(engine.stateManager.get('rows'), <dynamic>[1],
          reason: 'a failed read is not new data; clearing the panel would '
              'lose what the user was looking at');
    });

    test('the standard form with no reader is a no-op', () async {
      engine.registerResourceSubscription('ui://rows', 'rows');

      await engine.handleMCPNotification(<String, dynamic>{'uri': 'ui://rows'});

      expect(engine.stateManager.get('rows'), isNull);
    });

    test('a notification for an unsubscribed URI writes nothing', () async {
      await engine.handleMCPNotification(<String, dynamic>{
        'uri': 'ui://unknown',
        'content': <String, dynamic>{'total': 1},
      });

      expect(engine.stateManager.get('unknown'), isNull);
    });
  });
}
