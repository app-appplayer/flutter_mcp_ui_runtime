import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/state/computed_property.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/i18n/i18n_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';

void main() {
  group('MCP UI DSL v1.0 Complete Specification Compliance', () {
    late StateManager stateManager;
    late ThemeManager themeManager;
    late I18nManager i18nManager;
    late ActionHandler actionHandler;
    late BindingEngine bindingEngine;
    late WidgetRegistry widgetRegistry;
    late Renderer renderer;
    late RenderContext context;

    setUp(() {
      stateManager = StateManager();
      themeManager = ThemeManager();
      themeManager.reset();
      i18nManager = I18nManager.instance;
      i18nManager.clear();
      actionHandler = ActionHandler();
      bindingEngine = BindingEngine();
      widgetRegistry = WidgetRegistry();
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

    group('Theme Mode Support', () {
      test('should support all theme modes', () {
        // Test light mode
        themeManager.setThemeMode('light');
        expect(themeManager.themeMode, equals('light'));
        expect(themeManager.flutterThemeMode.name, equals('light'));

        // Test dark mode
        themeManager.setThemeMode('dark');
        expect(themeManager.themeMode, equals('dark'));
        expect(themeManager.flutterThemeMode.name, equals('dark'));

        // Test system mode
        themeManager.setThemeMode('system');
        expect(themeManager.themeMode, equals('system'));
        expect(themeManager.flutterThemeMode.name, equals('system'));
      });

      test('should support theme mode in configuration', () {
        final themeConfig = {
          'mode': 'dark',
          'colors': {
            'primary': '#ff5722',
          },
        };

        themeManager.setTheme(themeConfig);
        expect(themeManager.themeMode, equals('dark'));
        expect(themeManager.getThemeValue('colors.primary'), equals('#ff5722'));
      });

      test('should support dynamic theme mode changes via state', () {
        // Connect ThemeManager with StateManager first
        themeManager.setStateManager(stateManager);
        
        stateManager.set('theme.mode', 'dark');
        expect(themeManager.getThemeValue('mode'), equals('dark'));
        expect(themeManager.flutterThemeMode.name, equals('dark'));
      });
    });

    group('Action Parameter Specification', () {
      test('should only accept params parameter', () {
        actionHandler.registerToolExecutor('testTool', (params) async {
          return {'success': true, 'result': {'receivedParams': params}};
        });

        final action = {
          'type': 'tool',
          'tool': 'testTool',
          'params': {
            'message': 'Hello World',
            'count': 42,
          },
        };

        expect(
          () => actionHandler.execute(action, context),
          returnsNormally,
        );
      });

      test('should reject deprecated args parameter', () {
        actionHandler.registerToolExecutor('testTool', (params) async {
          return {'success': true, 'result': {'receivedParams': params}};
        });

        final action = {
          'type': 'tool',
          'tool': 'testTool',
          'args': {
            'message': 'Hello World',
            'count': 42,
          },
        };

        expect(
          () => actionHandler.execute(action, context),
          throwsArgumentError,
        );
      });
    });

    group('Color Parsing Specification', () {
      test('should support 8-digit AARRGGBB color format', () {
        final color8Digit = themeManager.getThemeValue('colors.primary');
        expect(color8Digit, isNotNull);

        // Test with custom 8-digit color
        themeManager.setTheme({
          'colors': {
            'custom': '#80ff5722', // 50% opacity orange
          }
        });

        final customColor = themeManager.getThemeValue('colors.custom');
        expect(customColor, equals('#80ff5722'));
      });

      test('should support 6-digit RRGGBB color format', () {
        themeManager.setTheme({
          'colors': {
            'custom': '#ff5722', // Orange
          }
        });

        final customColor = themeManager.getThemeValue('colors.custom');
        expect(customColor, equals('#ff5722'));
      });

      test('should support 3-digit RGB color format', () {
        themeManager.setTheme({
          'colors': {
            'custom': '#f57', // Short orange
          }
        });

        final customColor = themeManager.getThemeValue('colors.custom');
        expect(customColor, equals('#f57'));
      });
    });

    group('Computed Properties', () {
      test('should register and compute properties', () {
        stateManager.set('firstName', 'John');
        stateManager.set('lastName', 'Doe');

        // Register a simple computed property with a basic function
        final property = ComputedProperty(
          name: 'fullName',
          expression: 'firstName + " " + lastName',
          dependencies: ['firstName', 'lastName'],
          compute: (state) {
            final first = state['firstName']?.toString() ?? '';
            final last = state['lastName']?.toString() ?? '';
            return '$first $last';
          },
        );
        
        stateManager.registerComputedProperty('fullName', property);

        final fullName = stateManager.get<String>('fullName');
        expect(fullName, equals('John Doe'));
      });

      test('should invalidate computed properties when dependencies change', () {
        stateManager.set('count', 5);
        
        final property = ComputedProperty(
          name: 'doubled',
          expression: 'count * 2',
          dependencies: ['count'],
          compute: (state) {
            final count = state['count'] as int? ?? 0;
            return count * 2;
          },
        );
        
        stateManager.registerComputedProperty('doubled', property);

        expect(stateManager.get<int>('doubled'), equals(10));

        stateManager.set('count', 7);
        expect(stateManager.get<int>('doubled'), equals(14));
      });

      test('should detect circular dependencies', () {
        // Create circular dependency between two computed properties
        final property1 = ComputedProperty(
          name: 'circular1',
          expression: 'circular2 + 1',
          dependencies: ['circular2'],
          compute: (state) {
            // This will try to get circular2, which will cause infinite recursion
            final circular2 = (state['circular2'] as int? ?? 0);
            return circular2 + 1;
          },
        );

        final property2 = ComputedProperty(
          name: 'circular2',
          expression: 'circular1 + 1',
          dependencies: ['circular1'],
          compute: (state) {
            // This will try to get circular1, which will cause infinite recursion
            final circular1 = (state['circular1'] as int? ?? 0);
            return circular1 + 1;
          },
        );

        stateManager.registerComputedProperty('circular1', property1);
        stateManager.registerComputedProperty('circular2', property2);

        expect(
          () => stateManager.get('circular1'),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('Internationalization (i18n)', () {
      test('should load and resolve translations', () async {
        await i18nManager.loadTranslations({
          'translations': {
            'en': {
              'hello': 'Hello',
              'welcome': 'Welcome {name}',
            },
            'ko': {
              'hello': '안녕하세요',
              'welcome': '{name}님 환영합니다',
            },
          },
        });

        // English
        i18nManager.setLocale('en');
        expect(i18nManager.translate('hello'), equals('Hello'));
        expect(i18nManager.translate('welcome', params: {'name': 'John'}), equals('Welcome John'));

        // Korean
        i18nManager.setLocale('ko');
        expect(i18nManager.translate('hello'), equals('안녕하세요'));
        expect(i18nManager.translate('welcome', params: {'name': '철수'}), equals('철수님 환영합니다'));
      });

      test('should fall back to default locale', () async {
        await i18nManager.loadTranslations({
          'translations': {
            'en': {'hello': 'Hello'},
          },
          'fallbackLocale': 'en',
        });
        i18nManager.setLocale('fr'); // Unsupported locale

        expect(i18nManager.translate('hello'), equals('Hello')); // Falls back to English
      });

      test('should resolve i18n strings in format "i18n:key"', () async {
        await i18nManager.loadTranslations({
          'translations': {
            'en': {'greeting': 'Hello World'},
          },
        });
        i18nManager.setLocale('en');

        final resolved = i18nManager.resolveI18nString('i18n:greeting');
        expect(resolved, equals('Hello World'));

        final nonI18n = i18nManager.resolveI18nString('regular text');
        expect(nonI18n, equals('regular text'));
      });
    });

    group('Event Handler Specification', () {
      test('should use v1.0 event handler names only', () {
        // This test ensures we're not using legacy event handler names
        final textFieldDef = {
          'type': 'TextField',
          'properties': {
            'value': 'test',
            'change': {
              'type': 'setState',
              'params': {'test': 'value'}
            }
          }
        };

        // Should work with v1.0 'change' event
        expect(() => renderer.renderWidget(textFieldDef, context), returnsNormally);

        // Legacy 'onChange' should not be supported anymore
        final legacyDef = {
          'type': 'TextField',
          'properties': {
            'value': 'test',
            'onChange': {
              'type': 'setState',
              'params': {'test': 'value'}
            }
          }
        };

        // This should not have any fallback support
        final widget = renderer.renderWidget(legacyDef, context);
        expect(widget, isNotNull); // Widget should still render but without event handler
      });
    });

    group('State Management Specification', () {
      test('should support nested state paths', () {
        stateManager.set('user.profile.name', 'John Doe');
        stateManager.set('user.profile.age', 30);
        stateManager.set('user.settings.theme', 'dark');

        expect(stateManager.get('user.profile.name'), equals('John Doe'));
        expect(stateManager.get('user.profile.age'), equals(30));
        expect(stateManager.get('user.settings.theme'), equals('dark'));
      });

      test('should support array operations', () {
        stateManager.set('items', ['a', 'b', 'c']);
        
        stateManager.append('items', 'd');
        expect(stateManager.get<List>('items'), equals(['a', 'b', 'c', 'd']));

        stateManager.removeAt('items', 1);
        expect(stateManager.get<List>('items'), equals(['a', 'c', 'd']));

        // Manual insert operation
        final items = stateManager.get<List>('items') ?? [];
        final newItems = List.from(items)..insert(1, 'b');
        stateManager.set('items', newItems);
        expect(stateManager.get<List>('items'), equals(['a', 'b', 'c', 'd']));
      });
    });

    group('Integration Test', () {
      test('should work together - theme mode, i18n, computed properties, and actions', () async {
        // Setup i18n
        await i18nManager.loadTranslations({
          'translations': {
            'en': {
              'greeting': 'Hello {name}',
              'theme_mode': 'Current theme: {mode}',
            },
          },
        });
        i18nManager.setLocale('en');

        // Setup state
        stateManager.set('user.name', 'John');
        stateManager.set('theme.mode', 'dark');

        // Setup computed property
        final greetingProperty = ComputedProperty(
          name: 'greeting_message',
          expression: 'greeting with user.name',
          dependencies: ['user.name'],
          compute: (state) {
            final userName = state['user']?['name']?.toString() ?? 'Anonymous';
            return 'Hello $userName';
          },
        );
        stateManager.registerComputedProperty('greeting_message', greetingProperty);

        // Setup theme (connect with state manager first)
        themeManager.setStateManager(stateManager);
        themeManager.setTheme({
          'mode': 'dark',
          'colors': {
            'primary': '#ff5722',
          }
        });

        // Setup action
        actionHandler.registerToolExecutor('updateUser', (params) async {
          stateManager.set('user.name', params['name']);
          return {'success': true, 'result': {'updated': true}};
        });

        // Test all components work together
        expect(themeManager.themeMode, equals('dark'));
        expect(themeManager.getThemeValue('colors.primary'), equals('#ff5722'));
        expect(i18nManager.translate('greeting', params: {'name': 'John'}), equals('Hello John'));
        expect(stateManager.get('user.name'), equals('John'));

        // Test action execution changes computed property
        final action = {
          'type': 'tool',
          'tool': 'updateUser',
          'params': {'name': 'Jane'},
        };

        expect(() => actionHandler.execute(action, context), returnsNormally);
        expect(stateManager.get('user.name'), equals('Jane'));
      });
    });
  });
}