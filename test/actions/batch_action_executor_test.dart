import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
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
  late BindingEngine bindingEngine;

  setUp(() {
    actionHandler = ActionHandler();
    stateManager = StateManager();
    bindingEngine = BindingEngine();
    final themeManager = ThemeManager.instance;
    themeManager.reset();
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

  tearDown(() {
    bindingEngine.dispose();
    stateManager.dispose();
  });

  group('TC-055: BatchActionExecutor — sequential batch', () {
    test('TC-055 Normal: sequential batch executes all actions in order', () async {
      stateManager.set('a', 0);
      stateManager.set('b', 0);

      final result = await actionHandler.execute(
        {
          'type': 'batch',
          'actions': [
            {'type': 'state', 'action': 'set', 'binding': 'a', 'value': 1},
            {'type': 'state', 'action': 'set', 'binding': 'b', 'value': 2},
          ],
        },
        context,
      );

      expect(result.success, isTrue);
      expect(stateManager.get<int>('a'), equals(1));
      expect(stateManager.get<int>('b'), equals(2));
    });

    test('TC-055 Normal: order matters for sequential execution', () async {
      stateManager.set('counter', 0);

      final result = await actionHandler.execute(
        {
          'type': 'batch',
          'actions': [
            {'type': 'state', 'action': 'set', 'binding': 'counter', 'value': 10},
            {'type': 'state', 'action': 'increment', 'binding': 'counter', 'amount': 5},
          ],
        },
        context,
      );

      expect(result.success, isTrue);
      // First sets to 10, then increments by 5 = 15
      expect(stateManager.get<num>('counter'), equals(15));
    });

    test('TC-055 Boundary: single action in batch', () async {
      final result = await actionHandler.execute(
        {
          'type': 'batch',
          'actions': [
            {'type': 'state', 'action': 'set', 'binding': 'x', 'value': 42},
          ],
        },
        context,
      );

      expect(result.success, isTrue);
      expect(stateManager.get<int>('x'), equals(42));
    });
  });

  group('TC-056: BatchActionExecutor — parallel batch', () {
    test('TC-056 Normal: parallel batch executes all actions', () async {
      final result = await actionHandler.execute(
        {
          'type': 'batch',
          'actions': [
            {'type': 'state', 'action': 'set', 'binding': 'p1', 'value': 1},
            {'type': 'state', 'action': 'set', 'binding': 'p2', 'value': 2},
            {'type': 'state', 'action': 'set', 'binding': 'p3', 'value': 3},
          ],
          'parallel': true,
        },
        context,
      );

      expect(result.success, isTrue);
      expect(stateManager.get<int>('p1'), equals(1));
      expect(stateManager.get<int>('p2'), equals(2));
      expect(stateManager.get<int>('p3'), equals(3));
    });

    test('TC-056 Boundary: parallel with single action', () async {
      final result = await actionHandler.execute(
        {
          'type': 'batch',
          'actions': [
            {'type': 'state', 'action': 'set', 'binding': 'solo', 'value': 99},
          ],
          'parallel': true,
        },
        context,
      );

      expect(result.success, isTrue);
      expect(stateManager.get<int>('solo'), equals(99));
    });
  });

  group('TC-057: BatchActionExecutor — stopOnError: true', () {
    test('TC-057 Normal: stops execution when action fails with stopOnError true', () async {
      // Register a tool that fails to cause an error mid-batch
      stateManager.set('first', 0);
      stateManager.set('third', 0);

      final result = await actionHandler.execute(
        {
          'type': 'batch',
          'stopOnError': true,
          'actions': [
            {'type': 'state', 'action': 'set', 'binding': 'first', 'value': 1},
            // This will fail because 'unknownAction' is not a valid state action
            {'type': 'state', 'action': 'unknownAction', 'binding': 'second'},
            {'type': 'state', 'action': 'set', 'binding': 'third', 'value': 3},
          ],
        },
        context,
      );

      expect(result.success, isFalse);
      // First action executed
      expect(stateManager.get<int>('first'), equals(1));
      // Third action should NOT have executed due to stopOnError
      expect(stateManager.get<int>('third'), equals(0));
    });

    test('TC-057 Boundary: first action fails, no subsequent actions execute', () async {
      stateManager.set('after', 0);

      final result = await actionHandler.execute(
        {
          'type': 'batch',
          'stopOnError': true,
          'actions': [
            {'type': 'state', 'action': 'unknownAction', 'binding': 'x'},
            {'type': 'state', 'action': 'set', 'binding': 'after', 'value': 1},
          ],
        },
        context,
      );

      expect(result.success, isFalse);
      expect(stateManager.get<int>('after'), equals(0));
    });
  });

  group('TC-058: BatchActionExecutor — stopOnError: false (default)', () {
    test('TC-058 Normal: continues execution when action fails with default stopOnError', () async {
      stateManager.set('first', 0);
      stateManager.set('third', 0);

      final result = await actionHandler.execute(
        {
          'type': 'batch',
          'actions': [
            {'type': 'state', 'action': 'set', 'binding': 'first', 'value': 1},
            {'type': 'state', 'action': 'unknownAction', 'binding': 'second'},
            {'type': 'state', 'action': 'set', 'binding': 'third', 'value': 3},
          ],
        },
        context,
      );

      // Default stopOnError is false, so batch returns success
      expect(result.success, isTrue);
      // Both first and third actions should have executed
      expect(stateManager.get<int>('first'), equals(1));
      expect(stateManager.get<int>('third'), equals(3));
    });

    test('TC-058 Normal: explicit stopOnError: false continues on failure', () async {
      stateManager.set('after', 0);

      final result = await actionHandler.execute(
        {
          'type': 'batch',
          'stopOnError': false,
          'actions': [
            {'type': 'state', 'action': 'unknownAction', 'binding': 'x'},
            {'type': 'state', 'action': 'set', 'binding': 'after', 'value': 1},
          ],
        },
        context,
      );

      expect(result.success, isTrue);
      expect(stateManager.get<int>('after'), equals(1));
    });
  });

  group('TC-059: BatchActionExecutor — empty actions list', () {
    test('TC-059 Error: empty actions list returns error', () async {
      final result = await actionHandler.execute(
        {
          'type': 'batch',
          'actions': [],
        },
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Actions list is required'));
    });

    test('TC-059 Error: null actions returns error', () async {
      final result = await actionHandler.execute(
        {'type': 'batch'},
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Actions list is required'));
    });
  });

  group('TC-060: ConditionalActionExecutor — then branch', () {
    test('TC-060 Normal: executes then action when condition is true', () async {
      stateManager.set('flag', true);

      final result = await actionHandler.execute(
        {
          'type': 'conditional',
          'condition': '{{flag}}',
          'then': {
            'type': 'state',
            'action': 'set',
            'binding': 'result',
            'value': 'then_executed',
          },
          'else': {
            'type': 'state',
            'action': 'set',
            'binding': 'result',
            'value': 'else_executed',
          },
        },
        context,
      );

      expect(result.success, isTrue);
      expect(stateManager.get<String>('result'), equals('then_executed'));
    });

    test('TC-060 Normal: state-backed true condition executes then branch', () async {
      stateManager.set('cond', true);

      final result = await actionHandler.execute(
        {
          'type': 'conditional',
          'condition': '{{cond}}',
          'then': {
            'type': 'state',
            'action': 'set',
            'binding': 'result',
            'value': 'yes',
          },
        },
        context,
      );

      expect(result.success, isTrue);
      expect(stateManager.get<String>('result'), equals('yes'));
    });

    test('TC-060 Boundary: condition true without else branch', () async {
      stateManager.set('cond', true);

      final result = await actionHandler.execute(
        {
          'type': 'conditional',
          'condition': '{{cond}}',
          'then': {
            'type': 'state',
            'action': 'set',
            'binding': 'hit',
            'value': true,
          },
        },
        context,
      );

      expect(result.success, isTrue);
      expect(stateManager.get<bool>('hit'), isTrue);
    });
  });

  group('TC-061: ConditionalActionExecutor — else branch', () {
    test('TC-061 Normal: executes else action when condition is false', () async {
      stateManager.set('flag', false);

      final result = await actionHandler.execute(
        {
          'type': 'conditional',
          'condition': '{{flag}}',
          'then': {
            'type': 'state',
            'action': 'set',
            'binding': 'result',
            'value': 'then_executed',
          },
          'else': {
            'type': 'state',
            'action': 'set',
            'binding': 'result',
            'value': 'else_executed',
          },
        },
        context,
      );

      expect(result.success, isTrue);
      expect(stateManager.get<String>('result'), equals('else_executed'));
    });

    test('TC-061 Boundary: condition false without else branch returns success', () async {
      stateManager.set('cond', false);

      final result = await actionHandler.execute(
        {
          'type': 'conditional',
          'condition': '{{cond}}',
          'then': {
            'type': 'state',
            'action': 'set',
            'binding': 'hit',
            'value': true,
          },
        },
        context,
      );

      // No else branch, returns success without executing anything
      expect(result.success, isTrue);
      expect(stateManager.get('hit'), isNull);
    });

    test('TC-061 Error: missing condition returns error', () async {
      final result = await actionHandler.execute(
        {
          'type': 'conditional',
          'then': {
            'type': 'state',
            'action': 'set',
            'binding': 'x',
            'value': 1,
          },
        },
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Condition is required'));
    });
  });

  group('TC-062: ParallelActionExecutor and SequenceActionExecutor', () {
    test('TC-062 Normal: parallel executor runs all actions concurrently', () async {
      final result = await actionHandler.execute(
        {
          'type': 'parallel',
          'actions': [
            {'type': 'state', 'action': 'set', 'binding': 'p1', 'value': 10},
            {'type': 'state', 'action': 'set', 'binding': 'p2', 'value': 20},
          ],
        },
        context,
      );

      expect(result.success, isTrue);
      expect(stateManager.get<int>('p1'), equals(10));
      expect(stateManager.get<int>('p2'), equals(20));
    });

    test('TC-062 Normal: sequence executor runs actions in order with stopOnError', () async {
      stateManager.set('counter', 0);

      final result = await actionHandler.execute(
        {
          'type': 'sequence',
          'actions': [
            {'type': 'state', 'action': 'set', 'binding': 'counter', 'value': 5},
            {'type': 'state', 'action': 'increment', 'binding': 'counter', 'amount': 3},
          ],
          'stopOnError': true,
        },
        context,
      );

      expect(result.success, isTrue);
      expect(stateManager.get<num>('counter'), equals(8));
    });

    test('TC-062 Normal: sequence with stopOnError true stops on failure', () async {
      stateManager.set('after', 0);

      final result = await actionHandler.execute(
        {
          'type': 'sequence',
          'stopOnError': true,
          'actions': [
            {'type': 'state', 'action': 'unknownAction', 'binding': 'x'},
            {'type': 'state', 'action': 'set', 'binding': 'after', 'value': 1},
          ],
        },
        context,
      );

      expect(result.success, isFalse);
      expect(stateManager.get<int>('after'), equals(0));
    });

    test('TC-062 Boundary: parallel with empty actions returns error', () async {
      final result = await actionHandler.execute(
        {
          'type': 'parallel',
          'actions': [],
        },
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Actions list is required'));
    });

    test('TC-062 Boundary: sequence with empty actions returns error', () async {
      final result = await actionHandler.execute(
        {
          'type': 'sequence',
          'actions': [],
        },
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Actions list is required'));
    });

    test('TC-062 Error: parallel reports error when any action fails', () async {
      final result = await actionHandler.execute(
        {
          'type': 'parallel',
          'actions': [
            {'type': 'state', 'action': 'set', 'binding': 'ok', 'value': 1},
            {'type': 'state', 'action': 'unknownAction', 'binding': 'fail'},
          ],
        },
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('failed'));
    });
  });
}
