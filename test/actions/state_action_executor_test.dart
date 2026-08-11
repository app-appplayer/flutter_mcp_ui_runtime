import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_result.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';

void main() {
  late ActionHandler actionHandler;
  late RenderContext context;
  late StateManager stateManager;

  setUp(() {
    actionHandler = ActionHandler();
    stateManager = StateManager();
    final bindingEngine = BindingEngine();
    final themeManager = ThemeManager();
    final widgetRegistry = WidgetRegistry();
    final renderer = Renderer(
      widgetRegistry: widgetRegistry,
      bindingEngine: bindingEngine,
      actionHandler: actionHandler,
      stateManager: stateManager,
    );

    context = RenderContext(
      renderer: renderer,
      stateManager: stateManager,
      bindingEngine: bindingEngine,
      actionHandler: actionHandler,
      themeManager: themeManager,
    );
  });

  /// Helper to execute a state action
  Future<ActionResult> executeState(Map<String, dynamic> action) {
    return actionHandler.execute({...action, 'type': 'state'}, context);
  }

  group('TC-013: StateActionExecutor — set', () {
    test('TC-013 Normal: set counter to 0', () async {
      final result = await executeState({
        'action': 'set',
        'binding': 'counter',
        'value': 0,
      });
      expect(result.success, isTrue);
      expect(stateManager.get<int>('counter'), equals(0));
    });

    test('TC-013 Normal: Uses binding key from action map', () async {
      await executeState({
        'action': 'set',
        'binding': 'name',
        'value': 'Alice',
      });
      expect(stateManager.get<String>('name'), equals('Alice'));
    });

    test('TC-013 Normal: Uses path key as fallback', () async {
      await executeState({
        'action': 'set',
        'path': 'altPath',
        'value': 42,
      });
      expect(stateManager.get<int>('altPath'), equals(42));
    });

    test('TC-013 Boundary: Set to null value', () async {
      stateManager.set('key', 'old');
      await executeState({
        'action': 'set',
        'binding': 'key',
        'value': null,
      });
      expect(stateManager.get('key'), isNull);
    });

    test('TC-013 Boundary: Set with deeply nested binding path', () async {
      await executeState({
        'action': 'set',
        'binding': 'deep.nested.path',
        'value': 'deep',
      });
      expect(stateManager.get<String>('deep.nested.path'), equals('deep'));
    });

    test('TC-013 Error: a set with no binding is reported, not thrown',
        () async {
      // This used to assert `throwsA(isA<Exception>())`. The exception left
      // the executor, travelled through `ActionHandler.execute` and out of
      // whatever tapped the button — so a document with one missing `binding`
      // took the page down instead of failing one action. §6.13: the runtime
      // reports what it could not do.
      final result = await actionHandler.execute(
        {'type': 'state', 'action': 'set', 'value': 1},
        context,
      );
      expect(result.success, isFalse);
      expect(result.error, contains('binding'),
          reason: 'the message has to name the missing key, which is the '
              'entire fix an author needs');
    });
  });

  group('TC-014: StateActionExecutor — increment', () {
    test('TC-014 Normal: increment counter by 1 (default)', () async {
      stateManager.set('counter', 5);
      await executeState({
        'action': 'increment',
        'binding': 'counter',
      });
      expect(stateManager.get<num>('counter'), equals(6));
    });

    test('TC-014 Normal: increment counter by custom amount', () async {
      stateManager.set('counter', 5);
      await executeState({
        'action': 'increment',
        'binding': 'counter',
        'amount': 5,
      });
      expect(stateManager.get<num>('counter'), equals(10));
    });

    test('TC-014 Normal: amount key takes priority over value key', () async {
      stateManager.set('counter', 0);
      await executeState({
        'action': 'increment',
        'binding': 'counter',
        'amount': 10,
        'value': 3,
      });
      expect(stateManager.get<num>('counter'), equals(10));
    });

    test('TC-014 Boundary: Increment null treated as 0 + amount', () async {
      await executeState({
        'action': 'increment',
        'binding': 'unset',
      });
      expect(stateManager.get<num>('unset'), equals(1));
    });

    test('TC-014 Boundary: Increment by 0 results in no change', () async {
      stateManager.set('counter', 5);
      await executeState({
        'action': 'increment',
        'binding': 'counter',
        'amount': 0,
      });
      expect(stateManager.get<num>('counter'), equals(5));
    });
  });

  group('TC-015: StateActionExecutor — decrement', () {
    test('TC-015 Normal: decrement counter by 1 (default)', () async {
      stateManager.set('counter', 10);
      await executeState({
        'action': 'decrement',
        'binding': 'counter',
      });
      expect(stateManager.get<num>('counter'), equals(9));
    });

    test('TC-015 Normal: decrement counter by custom amount', () async {
      stateManager.set('counter', 10);
      await executeState({
        'action': 'decrement',
        'binding': 'counter',
        'amount': 3,
      });
      expect(stateManager.get<num>('counter'), equals(7));
    });

    test('TC-015 Normal: amount key takes priority over value key', () async {
      stateManager.set('counter', 10);
      await executeState({
        'action': 'decrement',
        'binding': 'counter',
        'amount': 7,
        'value': 2,
      });
      expect(stateManager.get<num>('counter'), equals(3));
    });

    test('TC-015 Boundary: Decrement null treated as 0 - amount', () async {
      await executeState({
        'action': 'decrement',
        'binding': 'unset',
      });
      expect(stateManager.get<num>('unset'), equals(-1));
    });

    test('TC-015 Boundary: Decrement resulting in negative value allowed', () async {
      stateManager.set('counter', 3);
      await executeState({
        'action': 'decrement',
        'binding': 'counter',
        'amount': 10,
      });
      expect(stateManager.get<num>('counter'), equals(-7));
    });
  });

  group('TC-016: StateActionExecutor — toggle', () {
    test('TC-016 Normal: toggle inverts boolean value true to false', () async {
      stateManager.set('isVisible', true);
      await executeState({
        'action': 'toggle',
        'binding': 'isVisible',
      });
      expect(stateManager.get<bool>('isVisible'), isFalse);
    });

    test('TC-016 Normal: toggle inverts boolean value false to true', () async {
      stateManager.set('isVisible', false);
      await executeState({
        'action': 'toggle',
        'binding': 'isVisible',
      });
      expect(stateManager.get<bool>('isVisible'), isTrue);
    });

    test('TC-016 Boundary: Toggle null becomes true', () async {
      await executeState({
        'action': 'toggle',
        'binding': 'unset',
      });
      expect(stateManager.get<bool>('unset'), isTrue);
    });

    test('TC-016 Boundary: Toggle twice returns to original', () async {
      stateManager.set('flag', true);
      await executeState({'action': 'toggle', 'binding': 'flag'});
      await executeState({'action': 'toggle', 'binding': 'flag'});
      expect(stateManager.get<bool>('flag'), isTrue);
    });
  });

  group('TC-017: StateActionExecutor — append', () {
    test('TC-017 Normal: append adds item to end of list', () async {
      stateManager.set('items', [1, 2, 3]);
      await executeState({
        'action': 'append',
        'binding': 'items',
        'value': 4,
      });
      expect(stateManager.get<List>('items'), equals([1, 2, 3, 4]));
    });

    test('TC-017 Normal: Existing list items preserved', () async {
      stateManager.set('items', ['a', 'b']);
      await executeState({
        'action': 'append',
        'binding': 'items',
        'value': 'c',
      });
      final items = stateManager.get<List>('items')!;
      expect(items, equals(['a', 'b', 'c']));
    });

    test('TC-017 Boundary: Append to null creates new list', () async {
      await executeState({
        'action': 'append',
        'binding': 'items',
        'value': 'first',
      });
      expect(stateManager.get<List>('items'), equals(['first']));
    });

    test('TC-017 Boundary: Append to empty list', () async {
      stateManager.set('items', []);
      await executeState({
        'action': 'append',
        'binding': 'items',
        'value': 'only',
      });
      expect(stateManager.get<List>('items'), equals(['only']));
    });
  });

  group('TC-018: StateActionExecutor — push', () {
    test('TC-018 Normal: push is alias for append', () async {
      stateManager.set('items', [1, 2]);
      await executeState({
        'action': 'push',
        'binding': 'items',
        'value': 3,
      });
      expect(stateManager.get<List>('items'), equals([1, 2, 3]));
    });

    test('TC-018 Boundary: Push to null creates new list', () async {
      await executeState({
        'action': 'push',
        'binding': 'items',
        'value': 'first',
      });
      expect(stateManager.get<List>('items'), equals(['first']));
    });

    test('TC-018 Boundary: Push to empty list', () async {
      stateManager.set('items', []);
      await executeState({
        'action': 'push',
        'binding': 'items',
        'value': 'only',
      });
      expect(stateManager.get<List>('items'), equals(['only']));
    });
  });

  group('TC-019: StateActionExecutor — pop', () {
    test('TC-019 Normal: pop removes last element from list', () async {
      stateManager.set('items', [1, 2, 3]);
      await executeState({
        'action': 'pop',
        'binding': 'items',
      });
      expect(stateManager.get<List>('items'), equals([1, 2]));
    });

    test('TC-019 Boundary: Pop from single-item list leaves empty list', () async {
      stateManager.set('items', ['only']);
      await executeState({
        'action': 'pop',
        'binding': 'items',
      });
      expect(stateManager.get<List>('items'), equals([]));
    });

    test('TC-019 Boundary: Pop from empty list is no-op', () async {
      stateManager.set('items', []);
      await executeState({
        'action': 'pop',
        'binding': 'items',
      });
      expect(stateManager.get<List>('items'), equals([]));
    });
  });

  group('TC-020: StateActionExecutor — remove', () {
    test('TC-020 Normal: remove by value removes first occurrence', () async {
      stateManager.set('items', ['a', 'b', 'c']);
      await executeState({
        'action': 'remove',
        'binding': 'items',
        'value': 'b',
      });
      expect(stateManager.get<List>('items'), equals(['a', 'c']));
    });

    test('TC-020 Normal: remove by index when index key present', () async {
      stateManager.set('items', ['a', 'b', 'c', 'd']);
      await executeState({
        'action': 'remove',
        'binding': 'items',
        'index': 2,
      });
      expect(stateManager.get<List>('items'), equals(['a', 'b', 'd']));
    });

    test('TC-020 Boundary: Remove non-existent value is no-op', () async {
      stateManager.set('items', [1, 2, 3]);
      await executeState({
        'action': 'remove',
        'binding': 'items',
        'value': 99,
      });
      expect(stateManager.get<List>('items'), equals([1, 2, 3]));
    });

    test('TC-020 Boundary: Remove from empty list is no-op', () async {
      stateManager.set('items', []);
      await executeState({
        'action': 'remove',
        'binding': 'items',
        'value': 'x',
      });
      expect(stateManager.get<List>('items'), equals([]));
    });
  });

  group('TC-021: StateActionExecutor — removeAt', () {
    test('TC-021 Normal: removeAt removes at specified index', () async {
      stateManager.set('items', ['a', 'b', 'c', 'd']);
      await executeState({
        'action': 'removeAt',
        'binding': 'items',
        'index': 1,
      });
      expect(stateManager.get<List>('items'), equals(['a', 'c', 'd']));
    });

    test('TC-021 Normal: Accepts value key as fallback for index', () async {
      stateManager.set('items', ['a', 'b', 'c']);
      await executeState({
        'action': 'removeAt',
        'binding': 'items',
        'value': 0,
      });
      expect(stateManager.get<List>('items'), equals(['b', 'c']));
    });

    test('TC-021 Boundary: removeAt index 0 removes first element', () async {
      stateManager.set('items', ['a', 'b', 'c']);
      await executeState({
        'action': 'removeAt',
        'binding': 'items',
        'index': 0,
      });
      expect(stateManager.get<List>('items'), equals(['b', 'c']));
    });

    test('TC-021 Boundary: removeAt last valid index removes last element', () async {
      stateManager.set('items', ['a', 'b', 'c']);
      await executeState({
        'action': 'removeAt',
        'binding': 'items',
        'index': 2,
      });
      expect(stateManager.get<List>('items'), equals(['a', 'b']));
    });

    test('TC-021 Error: removeAt with out-of-bounds index is no-op', () async {
      stateManager.set('items', ['a', 'b']);
      await executeState({
        'action': 'removeAt',
        'binding': 'items',
        'index': 5,
      });
      // Out-of-bounds index silently does nothing
      expect(stateManager.get<List>('items'), equals(['a', 'b']));
    });

    test('TC-021 Error: Missing index returns error result', () async {
      stateManager.set('items', ['a', 'b']);
      final result = await executeState({
        'action': 'removeAt',
        'binding': 'items',
      });
      expect(result.success, isFalse);
      expect(result.error, contains('Index is required'));
    });
  });

  group('TC-022: StateActionExecutor — scope resolution', () {
    test('TC-022 Normal: Mutations go through context.setValue()', () async {
      await executeState({
        'action': 'set',
        'binding': 'counter',
        'value': 42,
      });
      // context.setValue delegates to stateManager.set for non-prefixed paths
      expect(stateManager.get<int>('counter'), equals(42));
    });

    test('TC-022 Normal: Multiple set actions work in sequence', () async {
      await executeState({'action': 'set', 'binding': 'a', 'value': 1});
      await executeState({'action': 'set', 'binding': 'b', 'value': 2});
      expect(stateManager.get<int>('a'), equals(1));
      expect(stateManager.get<int>('b'), equals(2));
    });

    test('TC-022 Boundary: Deeply nested path sets correctly', () async {
      await executeState({
        'action': 'set',
        'binding': 'deep.nested.value',
        'value': 'found',
      });
      expect(stateManager.get<String>('deep.nested.value'), equals('found'));
    });

    test('TC-022 Normal: Unknown state action returns error', () async {
      final result = await executeState({
        'action': 'unknownAction',
        'binding': 'test',
      });
      expect(result.success, isFalse);
      expect(result.error, contains('Unknown state action'));
    });
  });
}
