// `client.storage` — the store a document keeps between screens.
//
// A key that goes to the wrong place, a removal that reports success without
// removing anything, or a read that cannot tell "not set yet" from "set to
// this": each leaves a screen showing yesterday's value with nothing to say
// why. The origin scope is the sharpest of these — two devices on one screen
// sharing a key space read each other's settings as their own.

import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_result.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/client_actions/executors/storage_action_executor.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StorageActionExecutor executor;
  late RenderContext context;

  RenderContext contextFor({Map<String, dynamic>? origin}) {
    final stateManager = StateManager()..initialize(<String, dynamic>{});
    final bindingEngine = BindingEngine();
    final actionHandler = ActionHandler();
    final base = RenderContext(
      renderer: Renderer(
        widgetRegistry: WidgetRegistry(),
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        stateManager: stateManager,
      ),
      stateManager: stateManager,
      bindingEngine: bindingEngine,
      actionHandler: actionHandler,
      themeManager: ThemeManager.instance,
    );
    // `origin` is a settable field on the context, inherited by children.
    return origin == null ? base : (base..origin = origin);
  }

  setUp(() {
    executor = StorageActionExecutor();
    context = contextFor();
  });

  Future<ActionResult> run(
    String type,
    Map<String, dynamic> action, {
    RenderContext? on,
  }) =>
      executor.execute(type, action, on ?? context);

  group('a round trip', () {
    test('what was set comes back, and the read says it was there', () async {
      await run('client.storage.set',
          <String, dynamic>{'key': 'draft', 'value': 'hello'});

      final read =
          await run('client.storage.get', <String, dynamic>{'key': 'draft'});

      expect(read.data?['value'], 'hello');
      expect(read.data?['exists'], isTrue);
    });

    test('the nested params spelling is read as well as the flat one',
        () async {
      await run('client.storage.set', <String, dynamic>{
        'params': <String, dynamic>{'key': 'k', 'value': 42},
      });

      final read = await run('client.storage.get', <String, dynamic>{
        'params': <String, dynamic>{'key': 'k'},
      });

      expect(read.data?['value'], 42,
          reason: 'both spellings are in the field; reading only one makes '
              'half the documents store nothing');
    });
  });

  group('what the store reports', () {
    test('a missing key falls back, and says it was missing', () async {
      final read = await run('client.storage.get', <String, dynamic>{
        'key': 'nothing',
        'defaultValue': 'fallback',
      });

      expect(read.data?['value'], 'fallback');
      expect(read.data?['exists'], isFalse,
          reason: 'a default that reads identically to a stored value hides '
              'the difference between "not set yet" and "set to this"');
    });

    test('a removal says whether there was anything to remove', () async {
      await run('client.storage.set',
          <String, dynamic>{'key': 'draft', 'value': 'x'});

      final first =
          await run('client.storage.remove', <String, dynamic>{'key': 'draft'});
      expect(first.data?['removed'], isTrue);

      final second =
          await run('client.storage.remove', <String, dynamic>{'key': 'draft'});
      expect(second.data?['removed'], isFalse,
          reason: 'a document clearing a draft twice needs to know the second '
              'call found nothing, not that it succeeded again');
    });
  });

  group('the refusals', () {
    test('every verb refuses a call with no key, by name', () async {
      for (final type in const [
        'client.storage.set',
        'client.storage.get',
        'client.storage.remove',
      ]) {
        final result = await run(type, <String, dynamic>{});
        expect(result.success, isFalse, reason: type);
        expect(result.errorCode, 'MISSING_PARAM', reason: type);
      }
    });

    test('a verb the store does not implement is named', () async {
      final result =
          await run('client.storage.drop', <String, dynamic>{'key': 'x'});

      expect(result.success, isFalse);
      expect(result.errorCode, 'UNKNOWN_ACTION',
          reason: 'a silent success here is data the document believes it '
              'saved');
    });
  });

  group('the origin scope', () {
    test('two embedded subtrees do not share a key space', () async {
      final boardA = contextFor(origin: <String, dynamic>{'connection': 'a'});
      final boardB = contextFor(origin: <String, dynamic>{'connection': 'b'});

      await run('client.storage.set',
          <String, dynamic>{'key': 'config', 'value': 'from A'},
          on: boardA);
      await run('client.storage.set',
          <String, dynamic>{'key': 'config', 'value': 'from B'},
          on: boardB);

      expect(
        (await run('client.storage.get', <String, dynamic>{'key': 'config'},
                on: boardA))
            .data?['value'],
        'from A',
        reason: 'a screen showing two devices has them sharing one key space '
            'without this, so the second to write silently overwrites the '
            'first and each reads the other back as its own',
      );
      expect(
        (await run('client.storage.get', <String, dynamic>{'key': 'config'},
                on: boardB))
            .data?['value'],
        'from B',
      );
    });

    test('an unscoped document does not see an origin\'s keys', () async {
      final board = contextFor(origin: <String, dynamic>{'connection': 'a'});
      await run('client.storage.set',
          <String, dynamic>{'key': 'config', 'value': 'board'},
          on: board);

      final read =
          await run('client.storage.get', <String, dynamic>{'key': 'config'});

      expect(read.data?['exists'], isFalse);
    });

    test('an origin with no connection id is not scoped at all', () async {
      final anonymous = contextFor(origin: <String, dynamic>{'note': 'x'});

      await run('client.storage.set',
          <String, dynamic>{'key': 'config', 'value': 'shared'},
          on: anonymous);

      expect(
        (await run('client.storage.get', <String, dynamic>{'key': 'config'}))
            .data?['value'],
        'shared',
        reason: 'inventing a scope from an origin that carries no identity '
            'would hide the value from the document that wrote it',
      );
    });
  });

  group('the utility surface a host drives', () {
    test('keys lists what is stored, and clear empties it', () async {
      await run('client.storage.set',
          <String, dynamic>{'key': 'a', 'value': 1});
      await run('client.storage.set',
          <String, dynamic>{'key': 'b', 'value': 2});

      expect(executor.keys, containsAll(<String>['a', 'b']));

      executor.clear();

      expect(executor.keys, isEmpty);
      expect(
          (await run('client.storage.get', <String, dynamic>{'key': 'a'}))
              .data?['exists'],
          isFalse,
          reason: 'a host clearing storage on sign-out must not leave the '
              'previous session readable');
    });
  });
}
