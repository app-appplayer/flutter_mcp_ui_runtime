import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';

void main() {
  group('Action Parameter Validation', () {
    late ActionHandler actionHandler;
    late RenderContext context;
    
    setUp(() {
      actionHandler = ActionHandler();
      
      final stateManager = StateManager();
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
      
      // Register a test tool
      actionHandler.registerToolExecutor('testTool', (params) async {
        return {'success': true, 'result': {'receivedParams': params}};
      });
    });
    
    group('MCP UI DSL v1.0 Spec Compliance', () {
      test('should accept params parameter', () async {
        final action = {
          'type': 'tool',
          'tool': 'testTool',
          'params': {
            'message': 'Hello World',
            'count': 42,
          },
        };
        
        final result = await actionHandler.execute(action, context);
        
        expect(result.success, isTrue);
        expect(result.data, isNotNull);
        expect(result.data['receivedParams'], {
          'message': 'Hello World',
          'count': 42,
        });
      });
      
      test('should reject deprecated args parameter', () async {
        final action = {
          'type': 'tool',
          'tool': 'testTool',
          'args': {  // deprecated parameter
            'message': 'Hello World',
            'count': 42,
          },
        };
        
        expect(
          () => actionHandler.execute(action, context),
          throwsArgumentError,
        );
      });
      
      test('should reject mixed params and args parameters', () async {
        final action = {
          'type': 'tool',
          'tool': 'testTool',
          'params': {
            'message': 'Hello World',
          },
          'args': {  // deprecated parameter - should cause error
            'count': 42,
          },
        };
        
        expect(
          () => actionHandler.execute(action, context),
          throwsArgumentError,
        );
      });
      
      test('should work with empty params', () async {
        final action = {
          'type': 'tool',
          'tool': 'testTool',
          'params': {},
        };
        
        final result = await actionHandler.execute(action, context);
        
        expect(result.success, isTrue);
        expect(result.data['receivedParams'], {});
      });
      
      test('should work without params field', () async {
        final action = {
          'type': 'tool',
          'tool': 'testTool',
          // No params field
        };
        
        final result = await actionHandler.execute(action, context);
        
        expect(result.success, isTrue);
        expect(result.data['receivedParams'], {});
      });
    });
    
    group('Parameter Types', () {
      test('should handle various parameter types', () async {
        final action = {
          'type': 'tool',
          'tool': 'testTool',
          'params': {
            'string': 'test',
            'number': 123,
            'boolean': true,
            'list': [1, 2, 3],
            'map': {'nested': 'value'},
            'null': null,
          },
        };
        
        final result = await actionHandler.execute(action, context);
        
        expect(result.success, isTrue);
        expect(result.data['receivedParams'], {
          'string': 'test',
          'number': 123,
          'boolean': true,
          'list': [1, 2, 3],
          'map': {'nested': 'value'},
          'null': null,
        });
      });
      
      test('should convert Map<dynamic, dynamic> to Map<String, dynamic>', () async {
        final dynamicMap = <dynamic, dynamic>{
          'key1': 'value1',
          'key2': 123,
        };
        
        final action = {
          'type': 'tool',
          'tool': 'testTool',
          'params': dynamicMap,
        };
        
        final result = await actionHandler.execute(action, context);
        
        expect(result.success, isTrue);
        expect(result.data['receivedParams'], {
          'key1': 'value1',
          'key2': 123,
        });
      });
    });
    
    group('Error Handling', () {
      test('should provide clear error message for args usage', () async {
        final action = {
          'type': 'tool',
          'tool': 'testTool',
          'args': {'test': 'value'},
        };
        
        try {
          await actionHandler.execute(action, context);
          fail('Should have thrown ArgumentError');
        } catch (e) {
          expect(e, isA<ArgumentError>());
          expect(e.toString(), contains('Use "params" instead of deprecated "args"'));
        }
      });
    });
  });
}