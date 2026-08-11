// The edges of the action executors: what happens when an action names
// something that is not there, when a custom executor throws, and when a
// handler answers "not mine".
//
// Every one of these ends in either a result the document can read or a
// silence. The silences are the defects — an action that fails and reports
// success leaves a button that looks like it worked.

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

/// A host object carrying only the resource callbacks. `RenderContext.engine`
/// is untyped precisely so a host can pass its own.
class _Host {
  _Host({this.onResourceSubscribe, this.onResourceList});

  final Function(String, String)? onResourceSubscribe;
  final Function(String, String)? onResourceList;
}

/// An executor that fails in whatever way the test asks for.
class _ThrowingExecutor extends ActionExecutor {
  _ThrowingExecutor(this.error);

  final Object error;

  @override
  Future<ActionResult> execute(
    Map<String, dynamic> action,
    RenderContext context,
  ) async {
    throw error;
  }
}

void main() {
  late StateManager stateManager;
  late ActionHandler actionHandler;
  late RenderContext context;

  setUp(() {
    stateManager = StateManager()..initialize(<String, dynamic>{});
    final registry = WidgetRegistry();
    DefaultWidgets.registerAll(registry);
    final bindingEngine = BindingEngine();
    actionHandler = ActionHandler();
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
  });

  Future<ActionResult> run(Map<String, dynamic> action) =>
      actionHandler.execute(action, context);

  group('an executor that throws', () {
    test('an ordinary failure comes back as an error result', () async {
      actionHandler.registerExecutor('boom', _ThrowingExecutor(
          StateError('the backend refused')));

      final result = await run(<String, dynamic>{'type': 'boom'});

      expect(result.success, isFalse,
          reason: 'an exception swallowed into a success is the one answer a '
              'document cannot recover from — it takes the next step');
      expect(result.error, contains('the backend refused'));
    });

    test('a validation failure is raised rather than wrapped', () async {
      actionHandler.registerExecutor(
          'invalid', _ThrowingExecutor(ArgumentError('name must be set')));

      await expectLater(run(<String, dynamic>{'type': 'invalid'}),
          throwsA(isA<ArgumentError>()),
          reason: 'an argument error is the document being wrong, not the '
              'call failing; wrapping it as a result hides a bug that will '
              'happen every single time');
    });

    test('a "required" failure is raised the same way', () async {
      actionHandler.registerExecutor(
          'missing', _ThrowingExecutor(Exception('field is required')));

      await expectLater(run(<String, dynamic>{'type': 'missing'}),
          throwsA(isA<Exception>()));
    });
  });

  group('the test executors', () {
    test('the widget-shuffling actions answer success', () async {
      for (final type in const [
        'addRandomWidget',
        'deleteRandomWidget',
        'shuffleWidgets',
      ]) {
        expect((await run(<String, dynamic>{'type': type})).success, isTrue,
            reason: '$type exists so a demo document runs; a failure here '
                'would read as the runtime rejecting the document');
      }
    });
  });

  group('cancel', () {
    test('it raises the signal the target action reads', () async {
      final result = await run(<String, dynamic>{
        'type': 'cancel',
        'target': 'upload',
      });

      expect(result.success, isTrue);
      expect(stateManager.get('_cancellations.upload'), isTrue);
    });

    test('with no target it refuses rather than cancelling everything',
        () async {
      expect((await run(<String, dynamic>{'type': 'cancel'})).success, isFalse);
      expect(
          (await run(<String, dynamic>{'type': 'cancel', 'target': ''}))
              .success,
          isFalse);
    });

    test('a callback that throws does not take the cancel down with it',
        () async {
      actionHandler.registerExecutor(
          'boom', _ThrowingExecutor(StateError('cleanup failed')));

      final result = await run(<String, dynamic>{
        'type': 'cancel',
        'target': 'upload',
        'onCancel': <String, dynamic>{'type': 'boom'},
      });

      expect(result.success, isTrue,
          reason: 'the cancellation already happened; reporting it as failed '
              'because a callback threw would leave the document thinking the '
              'work is still running');
      expect(stateManager.get('_cancellations.upload'), isTrue);
    });
  });

  group('media actions', () {
    test('a media action nobody defined is named', () async {
      stateManager.set('player', 'p1');

      final result = await run(<String, dynamic>{
        'type': 'media.rewind',
        'target': 'p1',
      });

      expect(result.success, isFalse,
          reason: 'a media verb the runtime does not implement has to say so; '
              'a silent success is a transport that never moved');
      expect(result.error, contains('Unknown action type'),
          reason: 'and it is dispatch that says it — only the four verbs of '
              '§4.9b are registered, so this never reaches the media '
              'executor. Naming the layer keeps this from passing on the '
              'wrong refusal');
    });
  });

  group('channel actions', () {
    test('with no manager wired it says so rather than pretending', () async {
      final result = await run(<String, dynamic>{
        'type': 'channel',
        'channel': 'feed',
        'action': 'start',
      });

      expect(result.success, isFalse);
      expect(result.error, contains('ChannelManager'),
          reason: 'a document whose channel action silently succeeds waits '
              'forever for data that was never subscribed to');
    });
  });
  // `resource.list` prefers a dedicated host callback and falls back to the
  // subscribe one for hosts that only wired that. A collection binding is
  // read with `.length`, `for` and index access, so the fallback has to
  // deliver a LIST even when the older callback wrote a single value.
  group('resource.list on a host that only wired subscribe', () {
    RenderContext contextWith({
      Function(String, String)? subscribe,
      Function(String, String)? list,
    }) =>
        RenderContext(
          renderer: context.renderer,
          stateManager: stateManager,
          bindingEngine: context.bindingEngine,
          actionHandler: actionHandler,
          themeManager: ThemeManager.instance,
          // The callbacks are read off the engine, which is deliberately
          // untyped so a host can supply its own object.
          engine: _Host(onResourceSubscribe: subscribe, onResourceList: list),
        );

    test('a scalar written by the old callback is wrapped into a list',
        () async {
      final ctx = contextWith(subscribe: (uri, binding) async {
        stateManager.set(binding, 'only-one');
      });

      final result = await actionHandler.execute(<String, dynamic>{
        'type': 'resource',
        'action': 'list',
        'uri': 'ui://files',
        'binding': 'files',
      }, ctx);

      expect(result.success, isTrue);
      expect(stateManager.get('files'), <dynamic>['only-one'],
          reason: 'a collection binding is iterated; a bare string there '
              'renders as a list of characters or as nothing at all');
    });

    test('a list the old callback wrote is left as it is', () async {
      final ctx = contextWith(subscribe: (uri, binding) async {
        stateManager.set(binding, <dynamic>['a', 'b']);
      });

      await actionHandler.execute(<String, dynamic>{
        'type': 'resource',
        'action': 'list',
        'uri': 'ui://files',
        'binding': 'files',
      }, ctx);

      expect(stateManager.get('files'), <dynamic>['a', 'b'],
          reason: 'wrapping a list again would bury every row one level down');
    });

    test('the dedicated callback wins when both are wired', () async {
      var subscribeCalled = false;
      final ctx = contextWith(
        subscribe: (uri, binding) async => subscribeCalled = true,
        list: (uri, binding) async =>
            stateManager.set(binding, <dynamic>['from-list']),
      );

      await actionHandler.execute(<String, dynamic>{
        'type': 'resource',
        'action': 'list',
        'uri': 'ui://files',
        'binding': 'files',
      }, ctx);

      expect(subscribeCalled, isFalse);
      expect(stateManager.get('files'), <dynamic>['from-list']);
    });

    test('a callback that throws is reported, not swallowed', () async {
      final ctx = contextWith(
        list: (uri, binding) async => throw StateError('directory gone'),
      );

      final result = await actionHandler.execute(<String, dynamic>{
        'type': 'resource',
        'action': 'list',
        'uri': 'ui://files',
      }, ctx);

      expect(result.success, isFalse);
      expect(result.error, contains('directory gone'));
    });
  });
  // The catch of last resort in every executor. Each one turns a throw into a
  // result the document can read; without it the exception escapes into
  // whatever called the action — a gesture handler, a lifecycle hook — and
  // takes the frame with it.
  group('an executor whose work throws mid-flight', () {
    test('a batch reports the failure rather than escaping', () async {
      actionHandler.registerExecutor(
          'boom', _ThrowingExecutor(StateError('mid-flight')));

      final result = await run(<String, dynamic>{
        'type': 'batch',
        'stopOnError': true,
        'actions': <dynamic>[
          <String, dynamic>{'type': 'boom'},
        ],
      });

      expect(result.success, isFalse,
          reason: 'a batch told to stop on error has to report the one it '
              'stopped on; the default is graceful degradation, which is a '
              'different contract');
      expect(result.error, isNotNull);
    });

    test('a sequence stops at the failure and says so', () async {
      actionHandler.registerExecutor(
          'boom', _ThrowingExecutor(StateError('mid-flight')));

      final result = await run(<String, dynamic>{
        'type': 'sequence',
        'actions': <dynamic>[
          set('first', true),
          <String, dynamic>{'type': 'boom'},
          set('third', true),
        ],
      });

      expect(result.success, isFalse);
      expect(stateManager.get('first'), isTrue);
      expect(stateManager.get('third'), isNull,
          reason: 'a sequence is ordered on purpose; carrying on past a '
              'failure runs steps against a state the failed one never '
              'produced');
    });

    test('a conditional whose branch throws reports it', () async {
      actionHandler.registerExecutor(
          'boom', _ThrowingExecutor(StateError('mid-flight')));

      final result = await run(<String, dynamic>{
        'type': 'conditional',
        'condition': true,
        'then': <String, dynamic>{'type': 'boom'},
      });

      expect(result.success, isFalse);
    });
  });
}

Map<String, dynamic> set(String binding, Object? value) => <String, dynamic>{
      'type': 'state',
      'action': 'set',
      'binding': binding,
      'value': value,
    };
