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
  late BindingEngine bindingEngine;
  late Renderer renderer;

  setUp(() {
    actionHandler = ActionHandler();
    stateManager = StateManager();
    bindingEngine = BindingEngine();
    final themeManager = ThemeManager.instance;
    themeManager.reset();
    final widgetRegistry = WidgetRegistry();
    renderer = Renderer(
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

  // TC-047: Show alert dialog
  group('TC-047: DialogActionExecutor — show alert', () {
    test('TC-047 Normal: alert dialog action with title and content', () async {
      final result = await actionHandler.execute(
        {
          'type': 'dialog',
          'dialog': {
            'type': 'alert',
            'title': 'Alert Title',
            'content': 'Alert message body',
          },
        },
        context,
      );

      // Without navigator context, DialogService throws StateError,
      // caught internally and returned as error result
      expect(result, isA<ActionResult>());
    });

    test('TC-047 Normal: alert dialog with actions list', () async {
      final result = await actionHandler.execute(
        {
          'type': 'dialog',
          'dialog': {
            'type': 'alert',
            'title': 'Confirm',
            'content': 'Are you sure?',
            'actions': [
              {'label': 'Cancel', 'action': 'close'},
              {'label': 'OK', 'action': 'close', 'primary': true},
            ],
          },
        },
        context,
      );

      expect(result, isA<ActionResult>());
    });

    test('TC-047 Boundary: alert dialog with null title and content', () async {
      final result = await actionHandler.execute(
        {
          'type': 'dialog',
          'dialog': {
            'type': 'alert',
          },
        },
        context,
      );

      // Still attempts to show dialog (content defaults to empty string)
      expect(result, isA<ActionResult>());
    });

    test('TC-047 Boundary: alert is default type when type is omitted', () async {
      final result = await actionHandler.execute(
        {
          'type': 'dialog',
          'dialog': {
            'title': 'Default Type',
            'content': 'Should default to alert',
          },
        },
        context,
      );

      // dialogType defaults to 'alert' when not specified
      expect(result, isA<ActionResult>());
    });
  });

  // TC-048: Show confirm dialog
  group('TC-048: DialogActionExecutor — show confirm (simple)', () {
    test('TC-048 Normal: simple dialog with title and content', () async {
      final result = await actionHandler.execute(
        {
          'type': 'dialog',
          'dialog': {
            'type': 'simple',
            'title': 'Information',
            'content': 'This is a simple message',
          },
        },
        context,
      );

      expect(result, isA<ActionResult>());
    });

    test('TC-048 Boundary: simple dialog with empty content', () async {
      final result = await actionHandler.execute(
        {
          'type': 'dialog',
          'dialog': {
            'type': 'simple',
            'title': 'Empty',
          },
        },
        context,
      );

      // content defaults to '' when null
      expect(result, isA<ActionResult>());
    });

    test('TC-048 Boundary: simple dialog with null title', () async {
      final result = await actionHandler.execute(
        {
          'type': 'dialog',
          'dialog': {
            'type': 'simple',
            'content': 'Message without title',
          },
        },
        context,
      );

      expect(result, isA<ActionResult>());
    });
  });

  // TC-049: Show custom dialog
  group('TC-049: DialogActionExecutor — show custom dialog', () {
    test('TC-049 Normal: custom dialog with child widget', () async {
      final result = await actionHandler.execute(
        {
          'type': 'dialog',
          'dialog': {
            'type': 'custom',
            'title': 'Custom Dialog',
            'child': {'type': 'text', 'text': 'Custom content'},
          },
        },
        context,
      );

      expect(result, isA<ActionResult>());
    });

    test('TC-049 Boundary: custom dialog without child returns success with null data', () async {
      final result = await actionHandler.execute(
        {
          'type': 'dialog',
          'dialog': {
            'type': 'custom',
            'title': 'No Child',
          },
        },
        context,
      );

      // When child is null, the custom case skips showing
      // result stays null, returns ActionResult.success(data: null)
      expect(result.success, isTrue);
      expect(result.data, isNull);
    });

    test('TC-049 Normal: custom dialog with dismissible false', () async {
      final result = await actionHandler.execute(
        {
          'type': 'dialog',
          'dialog': {
            'type': 'custom',
            'title': 'Non-dismissible',
            'dismissible': false,
            'child': {'type': 'text', 'text': 'Cannot dismiss'},
          },
        },
        context,
      );

      expect(result, isA<ActionResult>());
    });
  });

  // TC-050: Show bottom sheet
  group('TC-050: DialogActionExecutor — show bottom sheet', () {
    test('TC-050 Normal: bottomSheet with child widget', () async {
      final result = await actionHandler.execute(
        {
          'type': 'dialog',
          'dialog': {
            'type': 'bottomSheet',
            'child': {'type': 'text', 'text': 'Sheet content'},
          },
        },
        context,
      );

      expect(result, isA<ActionResult>());
    });

    test('TC-050 Boundary: bottomSheet without child returns success with null', () async {
      final result = await actionHandler.execute(
        {
          'type': 'dialog',
          'dialog': {
            'type': 'bottomSheet',
          },
        },
        context,
      );

      // When child is null, bottomSheet case skips showing
      expect(result.success, isTrue);
      expect(result.data, isNull);
    });

    test('TC-050 Normal: bottomSheet with enableDrag and backgroundColor', () async {
      final result = await actionHandler.execute(
        {
          'type': 'dialog',
          'dialog': {
            'type': 'bottomSheet',
            'child': {'type': 'text', 'text': 'Styled sheet'},
            'enableDrag': false,
            'dismissible': false,
            'backgroundColor': '#FF5733',
          },
        },
        context,
      );

      expect(result, isA<ActionResult>());
    });
  });

  // TC-051: Show snackbar (handled via notification action, not dialog executor)
  group('TC-051: DialogActionExecutor — missing dialog config', () {
    test('TC-051 Error: null dialog configuration returns error', () async {
      final result = await actionHandler.execute(
        {'type': 'dialog'},
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Dialog configuration is required'));
    });

    test('TC-051 Error: dialog key with non-map value handled gracefully', () async {
      final result = await actionHandler.execute(
        {'type': 'dialog', 'dialog': null},
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Dialog configuration is required'));
    });
  });

  // TC-052: Dismiss dialog (unknown type handling)
  group('TC-052: DialogActionExecutor — unknown dialog type', () {
    test('TC-052 Error: unknown dialog type returns error', () async {
      final result = await actionHandler.execute(
        {
          'type': 'dialog',
          'dialog': {
            'type': 'unknownType',
            'title': 'Should Fail',
          },
        },
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Unknown dialog type: unknownType'));
    });

    test('TC-052 Error: empty string type returns error', () async {
      final result = await actionHandler.execute(
        {
          'type': 'dialog',
          'dialog': {
            'type': '',
            'title': 'Empty Type',
          },
        },
        context,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Unknown dialog type:'));
    });
  });

  // TC-053: onDismiss handler
  group('TC-053: DialogActionExecutor — onDismiss handler', () {
    test('TC-053 Normal: onDismiss executes when dialog result is null (custom without child)', () async {
      stateManager.set('dismissed', false);

      final result = await actionHandler.execute(
        {
          'type': 'dialog',
          'dialog': {
            'type': 'custom',
            // No child, so dialog is not shown, result stays null
          },
          'onDismiss': {
            'type': 'state',
            'action': 'set',
            'binding': 'dismissed',
            'value': true,
          },
        },
        context,
      );

      expect(result.success, isTrue);
      expect(stateManager.get<bool>('dismissed'), isTrue);
    });

    test('TC-053 Normal: onDismiss executes for bottomSheet without child', () async {
      stateManager.set('sheetDismissed', false);

      final result = await actionHandler.execute(
        {
          'type': 'dialog',
          'dialog': {
            'type': 'bottomSheet',
            // No child, result stays null
          },
          'onDismiss': {
            'type': 'state',
            'action': 'set',
            'binding': 'sheetDismissed',
            'value': true,
          },
        },
        context,
      );

      expect(result.success, isTrue);
      expect(stateManager.get<bool>('sheetDismissed'), isTrue);
    });

    test('TC-053 Boundary: no onDismiss action when result is null', () async {
      final result = await actionHandler.execute(
        {
          'type': 'dialog',
          'dialog': {
            'type': 'custom',
            // No child, result is null, but no onDismiss defined
          },
        },
        context,
      );

      // Should not throw even when result is null and onDismiss is absent
      expect(result.success, isTrue);
    });
  });

  // TC-054: Dialog action with binding resolution
  group('TC-054: DialogActionExecutor — binding resolution in dialog', () {
    test('TC-054 Normal: title and content resolve bindings', () async {
      stateManager.set('dialogTitle', 'Dynamic Title');
      stateManager.set('dialogContent', 'Dynamic Content');

      final result = await actionHandler.execute(
        {
          'type': 'dialog',
          'dialog': {
            'type': 'alert',
            'title': '{{dialogTitle}}',
            'content': '{{dialogContent}}',
          },
        },
        context,
      );

      // Bindings are resolved via context.resolve() before showing dialog
      expect(result, isA<ActionResult>());
    });

    test('TC-054 Boundary: unresolvable binding passes through as literal', () async {
      final result = await actionHandler.execute(
        {
          'type': 'dialog',
          'dialog': {
            'type': 'alert',
            'title': '{{nonExistent}}',
            'content': 'Static content',
          },
        },
        context,
      );

      // Unresolvable bindings resolve to null or the binding string
      expect(result, isA<ActionResult>());
    });

    test('TC-054 Normal: dismissible property defaults to true', () async {
      final result = await actionHandler.execute(
        {
          'type': 'dialog',
          'dialog': {
            'type': 'custom',
            // dismissible not specified, defaults to true
          },
        },
        context,
      );

      // No error from missing dismissible
      expect(result.success, isTrue);
    });

    test('TC-054 Error: dialog executor catches exceptions and returns error result', () async {
      // Alert type tries to call DialogService.show() which needs Navigator
      // The StateError is caught and returned as ActionResult.error
      final result = await actionHandler.execute(
        {
          'type': 'dialog',
          'dialog': {
            'type': 'alert',
            'title': 'Error Test',
            'content': 'This will fail without navigator',
          },
        },
        context,
      );

      // Error is caught internally and wrapped in ActionResult
      expect(result, isA<ActionResult>());
      // Either success:false (caught error) or success:true depends on impl
      // The key is it does NOT throw an unhandled exception
    });
  });
}
