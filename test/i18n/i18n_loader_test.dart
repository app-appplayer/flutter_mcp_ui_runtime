import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/i18n/i18n_loader.dart';
import 'package:flutter_mcp_ui_runtime/src/i18n/i18n_manager.dart';

void main() {
  late I18nManager manager;

  setUp(() {
    manager = I18nManager.instance;
    manager.clear();
    manager.setLocale('en');
    manager.setFallbackLocale('en');
  });

  group('TC-124: I18nLoader — static methods', () {
    test('Normal: loadFromMap loads translations into I18nManager', () async {
      await I18nLoader.loadFromMap({
        'en': {'greeting': 'Hello', 'farewell': 'Goodbye'},
        'ko': {'greeting': '안녕하세요', 'farewell': '안녕히 가세요'},
      });

      expect(manager.translate('greeting'), equals('Hello'));
    });

    test('Normal: loadFromMap with nested keys → dot notation access', () async {
      await I18nLoader.loadFromMap({
        'en': {
          'nav': {
            'home': 'Home',
            'settings': 'Settings',
          },
        },
      });

      expect(manager.translate('nav.home'), equals('Home'));
      expect(manager.translate('nav.settings'), equals('Settings'));
    });

    test('Normal: loadFromMcpFormat loads MCP UI DSL i18n block', () async {
      await I18nLoader.loadFromMcpFormat({
        'locales': ['en', 'es'],
        'defaultLocale': 'en',
        'translations': {
          'en': {'title': 'My App', 'welcome': 'Welcome {name}'},
          'es': {'title': 'Mi App', 'welcome': 'Bienvenido {name}'},
        },
      });

      expect(manager.translate('title'), equals('My App'));
    });

    test('Normal: loadFromMcpFormat sets fallback locale from defaultLocale', () async {
      await I18nLoader.loadFromMcpFormat({
        'defaultLocale': 'en',
        'translations': {
          'en': {'fallbackKey': 'Fallback Value'},
        },
      });

      // Switch to a locale with no translations
      I18nLoader.setLocale('fr');
      // Should fall back to 'en'
      expect(manager.translate('fallbackKey'), equals('Fallback Value'));
    });

    test('Normal: setLocale changes the current locale in I18nManager', () {
      I18nLoader.setLocale('ko');
      expect(manager.currentLocale, equals('ko'));
    });

    test('Normal: loadFromMcpFormat without defaultLocale defaults to en', () async {
      await I18nLoader.loadFromMcpFormat({
        'translations': {
          'en': {'key': 'value'},
        },
      });

      expect(manager.fallbackLocale, equals('en'));
    });

    test('Boundary: loadFromMap with empty map → no translations loaded', () async {
      await I18nLoader.loadFromMap({});
      expect(manager.translate('anyKey'), equals('anyKey'));
    });

    test('Boundary: loadFromMcpFormat with null translations → no error', () async {
      await I18nLoader.loadFromMcpFormat({
        'defaultLocale': 'en',
      });
      // Should not throw
    });

    test('Normal: locale switch after loading → correct translations', () async {
      await I18nLoader.loadFromMap({
        'en': {'greeting': 'Hello'},
        'ko': {'greeting': '안녕하세요'},
      });

      I18nLoader.setLocale('ko');
      expect(manager.translate('greeting'), equals('안녕하세요'));

      I18nLoader.setLocale('en');
      expect(manager.translate('greeting'), equals('Hello'));
    });
  });

  // TC-025: I18nLoader — loadFromMap
  group('TC-025: I18nLoader — loadFromMap', () {
    test('Normal: accepts Map keyed by locale code and loads all locales', () async {
      await I18nLoader.loadFromMap({
        'en': {'greeting': 'Hello', 'farewell': 'Goodbye'},
        'ko': {'greeting': '안녕하세요', 'farewell': '안녕히 가세요'},
        'ja': {'greeting': 'こんにちは'},
      });

      expect(manager.translate('greeting'), equals('Hello'));
      expect(manager.isLocaleSupported('en'), isTrue);
      expect(manager.isLocaleSupported('ko'), isTrue);
      expect(manager.isLocaleSupported('ja'), isTrue);

      manager.setLocale('ko');
      expect(manager.translate('greeting'), equals('안녕하세요'));
    });

    test('Boundary: empty map — no translations loaded', () async {
      await I18nLoader.loadFromMap({});
      expect(manager.getSupportedLocales(), isEmpty);
      expect(manager.translate('anyKey'), equals('anyKey'));
    });
  });

  // TC-026: I18nLoader — loadFromMcpFormat
  group('TC-026: I18nLoader — loadFromMcpFormat', () {
    test('Normal: parses full MCP i18n config including defaultLocale and translations', () async {
      await I18nLoader.loadFromMcpFormat({
        'defaultLocale': 'en',
        'translations': {
          'en': {'title': 'My App', 'nav': {'home': 'Home'}},
          'es': {'title': 'Mi App', 'nav': {'home': 'Inicio'}},
        },
      });

      expect(manager.translate('title'), equals('My App'));
      expect(manager.fallbackLocale, equals('en'));
      expect(manager.isLocaleSupported('es'), isTrue);
    });

    test('Normal: defaultLocale set as fallback locale', () async {
      await I18nLoader.loadFromMcpFormat({
        'defaultLocale': 'es',
        'translations': {
          'es': {'greeting': 'Hola'},
        },
      });

      expect(manager.fallbackLocale, equals('es'));
    });

    test('Boundary: config with only translations (no remoteUrl) — loads inline only', () async {
      await I18nLoader.loadFromMcpFormat({
        'defaultLocale': 'en',
        'translations': {
          'en': {'key': 'value'},
        },
        // No remoteUrl field
      });

      expect(manager.translate('key'), equals('value'));
      expect(manager.getSupportedLocales(), contains('en'));
    });
  });

  // TC-027: I18nLoader — setLocale
  group('TC-027: I18nLoader — setLocale', () {
    test('Normal: parses locale string and delegates to I18nManager', () {
      I18nLoader.setLocale('ko-KR');
      expect(manager.currentLocale, equals('ko-KR'));
    });

    test('Boundary: simple locale code without region — sets locale correctly', () {
      I18nLoader.setLocale('en');
      expect(manager.currentLocale, equals('en'));

      I18nLoader.setLocale('ja');
      expect(manager.currentLocale, equals('ja'));
    });
  });

  // TC-006: I18nLoader — loadFromAsset
  group('TC-006: I18nLoader — loadFromAsset', () {
    test('Normal: loads JSON from asset and populates I18nManager', () async {
      // loadFromAsset uses rootBundle which requires Flutter test bindings.
      // Here we verify the method exists and handles errors gracefully
      // when an asset path does not exist in the test environment.
      TestWidgetsFlutterBinding.ensureInitialized();

      // Non-existent asset path should not throw (error is caught internally)
      await I18nLoader.loadFromAsset('assets/i18n/nonexistent.json');

      // No translations should be loaded from a missing asset
      expect(manager.translate('anyKey'), equals('anyKey'));
    });

    test('Boundary: empty asset path — error handled gracefully', () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      // Empty path should be handled without throwing
      await I18nLoader.loadFromAsset('');
      expect(manager.getSupportedLocales(), isEmpty);
    });

    test('Error: non-existent asset path — no translations loaded', () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      await I18nLoader.loadFromAsset('assets/i18n/does_not_exist.json');
      expect(manager.translate('greeting'), equals('greeting'));
    });
  });

  // TC-007: I18nLoader — loadFromRemote (error handling)
  group('TC-007: I18nLoader — loadFromRemote', () {
    test('Error: invalid URL — remote loading fails gracefully', () async {
      // loadTranslations with a remoteUrl that is unreachable
      // The I18nManager catches the error internally
      await manager.loadTranslations({
        'remoteUrl': 'http://invalid.test.url.nonexistent/i18n.json',
        'translations': {
          'en': {'fallback': 'Local Value'},
        },
      });

      // Local translations should still be available despite remote failure
      expect(manager.translate('fallback'), equals('Local Value'));
    });

    test('Error: malformed URL — error caught and logged', () async {
      await manager.loadTranslations({
        'remoteUrl': '://not-a-valid-url',
        'translations': {
          'en': {'key': 'value'},
        },
      });

      // Local translations remain accessible
      expect(manager.translate('key'), equals('value'));
    });

    test('Normal: remoteUrl null — only local translations loaded', () async {
      await manager.loadTranslations({
        'translations': {
          'en': {'greeting': 'Hello'},
        },
      });

      expect(manager.translate('greeting'), equals('Hello'));
    });
  });

  // TC-008: I18nLoader — loadFromMcpFormat (MCP format parsing)
  group('TC-008: I18nLoader — loadFromMcpFormat (MCP format)', () {
    test('Normal: parses defaultLocale and sets as fallback', () async {
      await I18nLoader.loadFromMcpFormat({
        'defaultLocale': 'es',
        'translations': {
          'es': {'greeting': 'Hola'},
        },
      });

      expect(manager.fallbackLocale, equals('es'));
    });

    test('Normal: parses translations for multiple locales', () async {
      await I18nLoader.loadFromMcpFormat({
        'defaultLocale': 'en',
        'translations': {
          'en': {'title': 'App', 'nav': {'home': 'Home'}},
          'ko': {'title': '앱', 'nav': {'home': '홈'}},
        },
      });

      expect(manager.translate('title'), equals('App'));
      expect(manager.translate('nav.home'), equals('Home'));

      manager.setLocale('ko');
      expect(manager.translate('title'), equals('앱'));
      expect(manager.translate('nav.home'), equals('홈'));
    });

    test('Normal: remoteUrl field is passed through to loadTranslations', () async {
      // remoteUrl with invalid host — should fail gracefully
      await I18nLoader.loadFromMcpFormat({
        'defaultLocale': 'en',
        'translations': {
          'en': {'key': 'value'},
        },
        'remoteUrl': 'http://invalid.nonexistent.test/i18n.json',
      });

      // Local translations should still work
      expect(manager.translate('key'), equals('value'));
    });

    test('Boundary: missing translations field — no error', () async {
      await I18nLoader.loadFromMcpFormat({
        'defaultLocale': 'en',
      });

      expect(manager.translate('anyKey'), equals('anyKey'));
    });

    test('Boundary: empty translations map — no translations loaded', () async {
      await I18nLoader.loadFromMcpFormat({
        'defaultLocale': 'en',
        'translations': <String, dynamic>{},
      });

      expect(manager.getSupportedLocales(), isEmpty);
    });
  });
}
