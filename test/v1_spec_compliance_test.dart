import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/validation/validation_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/validation/validation_rules.dart' as rules;

void main() {
  group('MCP UI DSL v1.0 Compliance Tests', () {
    late WidgetRegistry widgetRegistry;
    late StateManager stateManager;
    late ThemeManager themeManager;
    
    setUp(() {
      widgetRegistry = WidgetRegistry();
      DefaultWidgets.registerAll(widgetRegistry);
      stateManager = StateManager();
      themeManager = ThemeManager();
    });

    group('Widget Type Registration', () {
      test('should register v1.0 widget type aliases', () {
        // Layout widgets
        expect(widgetRegistry.has('linear'), isTrue, reason: 'linear widget should be registered');
        expect(widgetRegistry.has('box'), isTrue, reason: 'box widget should be registered');
        
        // Input widgets
        expect(widgetRegistry.has('textInput'), isTrue, reason: 'textInput widget should be registered');
        expect(widgetRegistry.has('switch'), isTrue, reason: 'switch widget should be registered (v1.0 uses switch not toggle)');
        expect(widgetRegistry.has('select'), isTrue, reason: 'select widget should be registered');
        
        // List widgets
        expect(widgetRegistry.has('list'), isTrue, reason: 'list widget should be registered');
        expect(widgetRegistry.has('grid'), isTrue, reason: 'grid widget should be registered');
        
        // Navigation widgets
        expect(widgetRegistry.has('headerBar'), isTrue, reason: 'headerBar widget should be registered');
        expect(widgetRegistry.has('bottomNav'), isTrue, reason: 'bottomNav widget should be registered (v1.0 spec)');
        
        // Scroll widgets
        expect(widgetRegistry.has('scrollView'), isTrue, reason: 'scrollView widget should be registered');
        
        // Progress indicators
        expect(widgetRegistry.has('loadingIndicator'), isTrue, reason: 'loadingIndicator widget should be registered');
      });
      
      test('should maintain backward compatibility with Flutter widget names', () {
        // Legacy names should still work
        expect(widgetRegistry.has('container'), isTrue);
        expect(widgetRegistry.has('textfield'), isTrue);
        expect(widgetRegistry.has('switch'), isTrue);
        expect(widgetRegistry.has('dropdown'), isTrue);
        expect(widgetRegistry.has('listview'), isTrue);
        expect(widgetRegistry.has('gridview'), isTrue);
        expect(widgetRegistry.has('appbar'), isTrue);
        expect(widgetRegistry.has('bottomnavigationbar'), isTrue);
      });
    });

    group('State Management', () {
      test('should support local. prefix for page-local state', () {
        final context = RenderContext(
          renderer: Renderer(
            widgetRegistry: widgetRegistry,
            bindingEngine: BindingEngine(),
            actionHandler: ActionHandler(),
            stateManager: stateManager,
            engine: null,
          ),
          stateManager: stateManager,
          bindingEngine: BindingEngine(),
          actionHandler: ActionHandler(),
          themeManager: themeManager,
        );
        
        // Set local state
        context.setState('local.counter', 10);
        expect(context.getState<int>('local.counter'), equals(10));
        
        // Local state should not affect global state
        expect(stateManager.get<int>('counter'), isNull);
      });
      
      test('should support app. prefix for global state', () {
        final context = RenderContext(
          renderer: Renderer(
            widgetRegistry: widgetRegistry,
            bindingEngine: BindingEngine(),
            actionHandler: ActionHandler(),
            stateManager: stateManager,
            engine: null,
          ),
          stateManager: stateManager,
          bindingEngine: BindingEngine(),
          actionHandler: ActionHandler(),
          themeManager: themeManager,
        );
        
        // Set global state
        context.setState('app.username', 'John');
        expect(context.getState<String>('app.username'), equals('John'));
        
        // Should be accessible through state manager
        expect(stateManager.get<String>('username'), equals('John'));
      });
      
      test('should support no prefix for backward compatibility', () {
        final context = RenderContext(
          renderer: Renderer(
            widgetRegistry: widgetRegistry,
            bindingEngine: BindingEngine(),
            actionHandler: ActionHandler(),
            stateManager: stateManager,
            engine: null,
          ),
          stateManager: stateManager,
          bindingEngine: BindingEngine(),
          actionHandler: ActionHandler(),
          themeManager: themeManager,
        );
        
        // Set state without prefix (defaults to global)
        context.setState('count', 5);
        expect(context.getState<int>('count'), equals(5));
        expect(stateManager.get<int>('count'), equals(5));
      });
    });

    group('Theme Support', () {
      test('should support v1.0 textOn* color names', () {
        final themeData = {
          'colors': {
            'primary': '#2196F3',
            'textOnPrimary': '#FFFFFF',
            'secondary': '#FF4081',
            'textOnSecondary': '#000000',
          },
        };
        
        themeManager.setTheme(themeData);
        
        // Should use textOnPrimary for onPrimary
        final flutterTheme = themeManager.currentTheme;
        expect(flutterTheme.colorScheme.onPrimary.value, equals(0xFFFFFFFF));
        expect(flutterTheme.colorScheme.onSecondary.value, equals(0xFF000000));
      });
      
      test('should fallback to legacy on* names', () {
        final themeData = {
          'colors': {
            'primary': '#2196F3',
            'onPrimary': '#FFFFFF',
            'secondary': '#FF4081',
            'onSecondary': '#000000',
          },
        };
        
        themeManager.setTheme(themeData);
        
        // Should still work with legacy names
        final flutterTheme = themeManager.currentTheme;
        expect(flutterTheme.colorScheme.onPrimary.value, equals(0xFFFFFFFF));
        expect(flutterTheme.colorScheme.onSecondary.value, equals(0xFF000000));
      });
    });

    group('Validation System', () {
      test('should parse validation rules from v1.0 format', () {
        final validation = [
          {'type': 'required'},
          {'type': 'minLength', 'value': 3},
          {'type': 'maxLength', 'value': 20},
        ];
        
        final rules = ValidationEngine.parseValidation(validation);
        
        expect(rules.length, equals(3));
        expect(rules.any((r) => r.type == ValidationRuleType.required), isTrue);
        expect(rules.any((r) => r.type == ValidationRuleType.minLength), isTrue);
        expect(rules.any((r) => r.type == ValidationRuleType.maxLength), isTrue);
      });
      
      test('should validate required fields', () {
        final rules = ValidationEngine.parseValidation([
          {'type': 'required', 'message': 'This field is required'},
        ]);
        
        expect(ValidationEngine.validate(null, rules).isValid, isFalse);
        expect(ValidationEngine.validate('', rules).isValid, isFalse);
        expect(ValidationEngine.validate('value', rules).isValid, isTrue);
      });
      
      test('should validate email format', () {
        final rules = ValidationEngine.parseValidation([
          {'type': 'email', 'message': 'Invalid email'},
        ]);
        
        expect(ValidationEngine.validate('invalid', rules).isValid, isFalse);
        expect(ValidationEngine.validate('test@example.com', rules).isValid, isTrue);
      });
    });

    group('Event System', () {
      test('should support v1.0 dash notation event names', () {
        // PropertyKeys should define dash notation events
        expect(rules.PropertyKeys.doubleClick, equals('doubleClick'));
        expect(rules.PropertyKeys.rightClick, equals('rightClick'));
        expect(rules.PropertyKeys.longPress, equals('longPress'));
      });
    });
  });
}