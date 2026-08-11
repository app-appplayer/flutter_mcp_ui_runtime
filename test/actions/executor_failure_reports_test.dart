// The failure branches of the executors: the lines that only run when the
// document is wrong, or when the thing the document asked for fails.
//
// Every one of them ends in a result the document can read. That is the whole
// point of them — and none of them had ever run, so nothing said whether the
// state they leave behind is the state a document can recover from. A tool
// that throws while a `loading` flag is up is the sharpest case: if the flag
// is not lowered, the spinner spins for the rest of the session over a screen
// that will never change.

import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_result.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StateManager stateManager;
  late ActionHandler actionHandler;
  late BindingEngine bindingEngine;
  late Renderer renderer;
  late RenderContext context;

  RenderContext contextWith({
    bool Function(String, String, Map<String, dynamic>)? navigationHandler,
    Future<dynamic> Function(String, String, String, dynamic)? resourceHandler,
  }) =>
      RenderContext(
        renderer: renderer,
        stateManager: stateManager,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        themeManager: ThemeManager.instance,
        navigationHandler: navigationHandler,
        resourceHandler: resourceHandler,
      );

  setUp(() {
    stateManager = StateManager()..initialize(<String, dynamic>{});
    final registry = WidgetRegistry();
    DefaultWidgets.registerAll(registry);
    bindingEngine = BindingEngine();
    actionHandler = ActionHandler();
    renderer = Renderer(
      widgetRegistry: registry,
      bindingEngine: bindingEngine,
      actionHandler: actionHandler,
      stateManager: stateManager,
    );
    context = contextWith();
  });

  Future<ActionResult> run(Map<String, dynamic> action,
          [RenderContext? ctx]) =>
      actionHandler.execute(action, ctx ?? context);

  group('a tool action whose params cannot be read', () {
    test('a params map that is not keyed by strings is reported, not thrown',
        () async {
      actionHandler.registerToolExecutor('save', (params) async => 'ok');

      final result = await run(<String, dynamic>{
        'type': 'tool',
        'tool': 'save',
        // A JSON decoder hands back `Map<dynamic, dynamic>`; one non-string
        // key in it (a number used as an id, most often) makes the conversion
        // throw halfway through.
        'params': <dynamic, dynamic>{1: 'a', 'name': 'b'},
      });

      expect(result.success, isFalse);
      expect(result.error, contains('Error extracting params'),
          reason: 'an exception escaping here would take down whatever ran '
              'the action — a button tap, a lifecycle hook — instead of '
              'telling the document which action it was');
    });
  });

  group('a tool that throws while a loading flag is up', () {
    test('the flag, its text and its indicator all come back down', () async {
      actionHandler.registerToolExecutor('fetch', (params) async {
        throw StateError('the backend is down');
      });

      final result = await run(<String, dynamic>{
        'type': 'tool',
        'tool': 'fetch',
        'loading': <String, dynamic>{
          'binding': 'busy',
          'text': 'Loading…',
          'indicator': 'circular',
        },
      });

      expect(result.success, isFalse);
      expect(result.error, contains('the backend is down'));
      expect(stateManager.get('busy'), isFalse,
          reason: 'a spinner that outlives the failure is the failure the '
              'user sees: the screen never changes again and nothing says '
              'why');
      expect(stateManager.get('busy.text'), isNull);
      expect(stateManager.get('busy.indicator'), isNull);
    });

    test('a result that cannot be merged still lowers the flag', () async {
      // The failure is not in the call — it succeeded — but in reading what
      // came back: a decoder that hands over `Map<dynamic, dynamic>` with one
      // non-string key fails the conversion on the way into page state. That
      // happens after the retry loop, so it is the outer guard that has to
      // put the screen back.
      actionHandler.registerToolExecutor(
          'fetch', (params) async => <dynamic, dynamic>{1: 'a', 'ok': true});

      final result = await run(<String, dynamic>{
        'type': 'tool',
        'tool': 'fetch',
        'loading': <String, dynamic>{
          'binding': 'busy',
          'text': 'Loading…',
          'indicator': 'circular',
        },
      });

      expect(result.success, isFalse);
      expect(stateManager.get('busy'), isFalse,
          reason: 'the call is over either way; a flag left up here is a '
              'spinner over a screen that will never change');
      expect(stateManager.get('busy.text'), isNull);
      expect(stateManager.get('busy.indicator'), isNull);
    });

    test('and on success the same three come down', () async {
      actionHandler.registerToolExecutor('fetch', (params) async => 'done');

      final result = await run(<String, dynamic>{
        'type': 'tool',
        'tool': 'fetch',
        'bindResult': 'answer',
        'loading': <String, dynamic>{
          'binding': 'busy',
          'text': 'Loading…',
          'indicator': 'linear',
        },
      });

      expect(result.success, isTrue);
      expect(stateManager.get('answer'), 'done');
      expect(stateManager.get('busy'), isFalse);
      expect(stateManager.get('busy.text'), isNull);
      expect(stateManager.get('busy.indicator'), isNull);
    });
  });

  group('navigation', () {
    test('a tab index reaches the host handler alongside the route', () async {
      Map<String, dynamic>? seen;
      String? seenRoute;
      final ctx = contextWith(navigationHandler: (action, route, params) {
        seenRoute = route;
        seen = params;
        return true;
      });

      final result = await run(<String, dynamic>{
        'type': 'navigation',
        'action': 'push',
        'route': '/orders',
        'index': 2,
        'params': <String, dynamic>{'filter': 'open'},
      }, ctx);

      expect(result.success, isTrue);
      expect(seenRoute, '/orders');
      expect(seen, <String, dynamic>{'filter': 'open', 'index': 2},
          reason: 'a shell that switches tabs reads `index`; dropping it left '
              'the tab strip on the old tab while the route changed under it');
    });
  });

  group('state actions on a value of the wrong type', () {
    test('toggling a string reports rather than throwing', () async {
      stateManager.set('flag', 'true');

      final result = await run(<String, dynamic>{
        'type': 'state',
        'action': 'toggle',
        'binding': 'flag',
      });

      expect(result.success, isFalse,
          reason: 'a document whose state arrived from a server as the string '
              '"true" is wrong in a way it can be told about; an uncaught '
              'cast would instead surface as a red box far from the cause');
      expect(stateManager.get('flag'), 'true',
          reason: 'and the value is left as it was, not half-written');
    });

    test('incrementing by something that is not a number is reported',
        () async {
      stateManager.set('count', 1);

      final result = await run(<String, dynamic>{
        'type': 'state',
        'action': 'increment',
        'binding': 'count',
        'amount': 'lots',
      });

      expect(result.success, isFalse);
      expect(stateManager.get('count'), 1);
    });
  });

  group('resource actions', () {
    test('an HTTP-style read binds its result where the document asked',
        () async {
      final ctx = contextWith(
        resourceHandler: (resource, method, target, data) async =>
            <String, dynamic>{'id': 7},
      );

      final result = await run(<String, dynamic>{
        'type': 'resource',
        'method': 'GET',
        'binding': 'orders',
        'resource': 'catalogue',
        'bindResult': 'lastResponse',
      }, ctx);

      expect(result.success, isTrue);
      expect(stateManager.get('lastResponse'), <String, dynamic>{'id': 7},
          reason: 'without this the response is returned to a caller that has '
              'nowhere to put it — the document declared the destination');
    });
  });

  group('composite actions holding something that is not an action', () {
    // `actions: ['reload']` — a list of names rather than a list of actions.
    // It is an ordinary authoring slip, and every one of the three composites
    // reaches the same cast.
    for (final type in const ['batch', 'parallel', 'sequence']) {
      test('$type reports the cast instead of escaping', () async {
        final result = await run(<String, dynamic>{
          'type': type,
          'actions': <dynamic>['reload'],
        });

        expect(result.success, isFalse,
            reason: 'an exception here escapes into whatever ran the '
                'composite, and the document is told nothing about which of '
                'its members was malformed');
        expect(result.error, isNotNull);
      });
    }
  });

  group('cancel', () {
    test('a callback that raises rather than failing still leaves the '
        'cancellation raised', () async {
      // `ActionHandler` re-raises argument errors (the document is wrong in a
      // way that will happen every time) instead of wrapping them in a
      // result — so this is the path where `handleAction` throws.
      actionHandler.registerExecutor('bad', _RaisingExecutor());

      final result = await run(<String, dynamic>{
        'type': 'cancel',
        'target': 'upload',
        'onCancel': <String, dynamic>{'type': 'bad'},
      });

      expect(result.success, isTrue);
      expect(stateManager.get('_cancellations.upload'), isTrue,
          reason: 'the cancel already happened; letting the callback take it '
              'down would leave the target running with nothing watching');
    });
  });
}

class _RaisingExecutor extends ActionExecutor {
  @override
  Future<ActionResult> execute(
    Map<String, dynamic> action,
    RenderContext context,
  ) async {
    throw ArgumentError('onCancel is not configured');
  }
}
