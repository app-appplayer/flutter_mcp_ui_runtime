// `{{sync.*}}` — what a document is allowed to know about its own offline
// queue — and the list functions that were still uncovered beside it.
//
// The sync namespace is how an offline-capable document draws its "3 changes
// waiting" badge and its spinner. Every path in it was uncovered, so a badge
// bound to `{{sync.pendingCount}}` had never been shown to resolve to
// anything. A binding that answers null renders as an empty string: the badge
// disappears and the user believes everything is saved.

import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/runtime_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sync.* with an engine behind it', () {
    late RuntimeEngine engine;
    late RenderContext context;

    setUp(() async {
      engine = RuntimeEngine(enableDebugMode: false);
      await engine.initialize(definition: {
        'type': 'page',
        'content': {'type': 'text', 'content': 'x'},
      });
      context = engine.renderer.createRootContext(null);
    });

    tearDown(() => engine.destroy());

    dynamic resolve(String expression) =>
        context.resolve<dynamic>(expression);

    test('status, pending and the counts all answer', () {
      // A freshly built engine has an idle queue — the point is that each path
      // resolves to a VALUE rather than to null, because null renders as an
      // empty badge and reads as "nothing pending".
      //
      // This is what caught the defect: `SyncBindingResolver` intercepts
      // `{{sync.*}}` before the binding engine's own path handling and holds
      // its own SyncManager reference, and NOTHING in the runtime ever set it.
      // Every sync binding answered null, and the engine-backed fallback
      // further down was unreachable.
      expect(resolve('{{sync.status}}'), isA<String>());
      expect(resolve('{{sync.pending}}'), isA<bool>());
      expect(resolve('{{sync.pendingCount}}'), isA<int>());
      expect(resolve('{{sync.syncedCount}}'), isA<int>());
      expect(resolve('{{sync.failedCount}}'), isA<int>());
    });

    test('saving and syncing are the same question, asked two ways', () {
      expect(resolve('{{sync.saving}}'), resolve('{{sync.syncing}}'),
          reason: 'a document writing either spelling must get the same '
              'answer, or a spinner appears for one and not the other');
      expect(resolve('{{sync.syncing}}'), isFalse);
    });

    test('lastSyncAt and lastSyncTime are the same path', () {
      expect(resolve('{{sync.lastSyncAt}}'), resolve('{{sync.lastSyncTime}}'));
    });

    test('lastError is null until something fails', () {
      expect(resolve('{{sync.lastError}}'), isNull);
    });

    test('a sync path nobody implements answers null rather than a guess', () {
      expect(resolve('{{sync.telepathy}}'), isNull,
          reason: 'inventing a value for an unknown path would put a number '
              'on screen that means nothing');
    });
  });

  group('sync.* with no engine', () {
    test('answers null instead of throwing', () {
      // A context built without an engine is what a widget test or a headless
      // render has. The badge simply does not draw; it must not take the page
      // down.
      final stateManager = StateManager()..initialize(<String, dynamic>{});
      final bindingEngine = BindingEngine();
      final actionHandler = ActionHandler();
      final context = RenderContext(
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

      expect(context.resolve<dynamic>('{{sync.status}}'), isNull);
      expect(context.resolve<dynamic>('{{sync.pendingCount}}'), isNull);
    });
  });

  group('the list functions that were still uncovered', () {
    late RenderContext context;
    late StateManager stateManager;

    setUp(() {
      stateManager = StateManager()
        ..initialize(<String, dynamic>{
          'rows': [
            {'name': 'Ada', 'status': 'active'},
            {'name': 'Bob', 'status': 'archived'},
            {'name': 'Cy', 'status': 'active'},
          ],
          'words': ['alpha', 'beta'],
          'sentence': 'the quick brown fox',
        });
      final bindingEngine = BindingEngine();
      final actionHandler = ActionHandler();
      context = RenderContext(
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
    });

    dynamic resolve(String expression) => context.resolve<dynamic>(expression);

    test('filter by property and value keeps only the matches', () {
      final result = resolve("{{filter(rows, 'status', 'active')}}") as List;
      expect(result.map((r) => r['name']), ['Ada', 'Cy'],
          reason: 'the three-argument form is what a document writes to show '
              'one tab of a list; returning everything reads as a filter that '
              'matched all rows');
    });

    test('the DSL spelling of filter is the two- and three-argument form', () {
      // The engine also accepts an object shorthand
      // (`filter(list, {property:…, value:…})`) internally, but the expression
      // parser has no object literal — so it is unreachable from a document
      // and §3\'s own list (`filter(items, 'active')`,
      // `filter(items, 'status', 'done')`) is the whole surface.
      final truthy = resolve("{{filter(rows, 'status')}}") as List;
      expect(truthy, hasLength(3),
          reason: 'every row has a non-empty status, so the truthy shorthand '
              'keeps them all');
      final matched = resolve("{{filter(rows, 'status', 'archived')}}") as List;
      expect(matched.map((r) => r['name']), ['Bob']);
    });

    test('map extracts a property from every item', () {
      expect(resolve("{{map(rows, 'name')}}"), ['Ada', 'Bob', 'Cy']);
    });

    test('contains answers for a list as well as a string', () {
      expect(resolve("{{contains(words, 'beta')}}"), isTrue);
      expect(resolve("{{contains(words, 'gamma')}}"), isFalse);
      expect(resolve("{{contains(sentence, 'quick')}}"), isTrue);
    });

    test('substring takes one or two indices', () {
      expect(resolve('{{substring(sentence, 4)}}'), 'quick brown fox');
      expect(resolve('{{substring(sentence, 4, 9)}}'), 'quick');
    });

    test('replace changes every occurrence, not just the first', () {
      expect(resolve("{{replace('a-b-c', '-', '+')}}"), 'a+b+c',
          reason: 'replacing only the first is the classic surprise here — a '
              'formatter for a path or a phone number would come out half '
              'converted');
    });

    test('a function given the wrong shapes answers null rather than throwing',
        () {
      expect(resolve("{{substring(rows, 1)}}"), isNull);
      expect(resolve("{{map('not a list', 'name')}}"), isNull);
    });
  });

  // A host object is a `dynamic` on this side of the import cycle, so what it
  // does when asked is entirely up to it — including throwing. That is not a
  // hypothetical: the engine is held as `dynamic` precisely so hosts can pass
  // their own, and an extension getter that does not resolve on a dynamic
  // receiver already threw here once (`{{sync.status}}` came back empty for
  // exactly that reason). What must not happen is the throw leaving the
  // binding: one bad getter would take down every interpolation on the page.
  group('sync.* when the host object misbehaves', () {
    RenderContext contextWithEngine(dynamic engine) {
      final stateManager = StateManager()..initialize(<String, dynamic>{});
      final bindingEngine = BindingEngine();
      final actionHandler = ActionHandler();
      return RenderContext(
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
        engine: engine,
      );
    }

    test('a sync manager that throws reads as nothing, not as an exception',
        () {
      final context = contextWithEngine(_ThrowingSyncEngine());

      expect(context.resolve<dynamic>('{{sync.status}}'), isNull);
      expect(context.resolve<dynamic>('{{sync.pendingCount}}'), isNull);
      expect(context.resolve<dynamic>('Queue: {{sync.pendingCount}}'),
          'Queue: ',
          reason: 'interpolation has to survive it too — the sentence around '
              'the value is the rest of the screen');
    });

    test('an engine with no sync manager is silent rather than broken', () {
      final context = contextWithEngine(_NoSyncEngine());
      expect(context.resolve<dynamic>('{{sync.status}}'), isNull);
    });
  });
}

/// A host object whose `syncManager` blows up when read.
class _ThrowingSyncEngine {
  Object get syncManager => throw StateError('sync subsystem is down');
}

/// A host object that simply has no sync subsystem.
class _NoSyncEngine {
  Object? get syncManager => null;
}
