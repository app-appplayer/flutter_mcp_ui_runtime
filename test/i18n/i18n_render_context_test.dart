import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/i18n/i18n_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';

void main() {
  group('TC-125: I18n integration with RenderContext', () {
    late RenderContext renderContext;
    late StateManager stateManager;
    late BindingEngine bindingEngine;
    late ActionHandler actionHandler;
    late ThemeManager themeManager;
    late WidgetRegistry widgetRegistry;
    late Renderer renderer;

    setUp(() {
      stateManager = StateManager();
      bindingEngine = BindingEngine();
      actionHandler = ActionHandler();
      themeManager = ThemeManager.instance;
      themeManager.reset();
      widgetRegistry = WidgetRegistry();

      renderer = Renderer(
        widgetRegistry: widgetRegistry,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        stateManager: stateManager,
      );

      renderContext = RenderContext(
        renderer: renderer,
        stateManager: stateManager,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        themeManager: themeManager,
      );

      // Set up I18nManager with test translations
      I18nManager.instance.clear();
      I18nManager.instance.loadLocaleTranslations('en', {
        'greeting': 'Hello',
        'welcome': 'Welcome, {{name}}!',
        'app': {
          'title': 'My Application',
          'description': 'A test application',
        },
      });
      I18nManager.instance.loadLocaleTranslations('ko', {
        'greeting': '안녕하세요',
        'welcome': '환영합니다, {{name}}!',
        'app': {
          'title': '내 애플리케이션',
          'description': '테스트 애플리케이션',
        },
      });
      I18nManager.instance.setLocale('en');
    });

    tearDown(() {
      I18nManager.instance.clear();
      stateManager.dispose();
    });

    test('Normal: resolve "i18n:greeting" → translated string through RenderContext', () {
      final result = renderContext.resolve<String>('i18n:greeting');
      expect(result, equals('Hello'));
    });

    test('Normal: resolve "i18n:app.title" → nested key resolution', () {
      final result = renderContext.resolve<String>('i18n:app.title');
      expect(result, equals('My Application'));
    });

    test('Normal: resolve i18n with params "i18n:welcome:name=World"', () {
      final result = renderContext.resolve<String>('i18n:welcome:name=World');
      expect(result, equals('Welcome, World!'));
    });

    test('Normal: locale switching changes resolved values', () {
      final enResult = renderContext.resolve<String>('i18n:greeting');
      expect(enResult, equals('Hello'));

      I18nManager.instance.setLocale('ko');
      final koResult = renderContext.resolve<String>('i18n:greeting');
      expect(koResult, equals('안녕하세요'));
    });

    test('Boundary: non-i18n string → returned as-is', () {
      final result = renderContext.resolve<String>('regular text');
      expect(result, equals('regular text'));
    });

    test('Boundary: missing i18n key → returns key as fallback', () {
      final result = renderContext.resolve<String>('i18n:nonexistent.key');
      expect(result, equals('nonexistent.key'));
    });

    test('Error: null value → resolve returns null', () {
      final result = renderContext.resolve<dynamic>(null);
      expect(result, isNull);
    });
  });
}
