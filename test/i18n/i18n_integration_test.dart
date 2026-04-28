import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/i18n/i18n_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/i18n/i18n_loader.dart';

void main() {
  late I18nManager manager;

  setUp(() {
    manager = I18nManager.instance;
    manager.clear();
    manager.setLocale('en');
    manager.setFallbackLocale('en');
  });

  // TC-018: Full locale switch lifecycle
  group('TC-018: Full locale switch lifecycle', () {
    test('Normal: load translations, switch locale, verify translations change',
        () async {
      await I18nLoader.loadFromMcpFormat({
        'defaultLocale': 'en',
        'translations': {
          'en': {
            'greeting': 'Hello',
            'nav': {'home': 'Home', 'settings': 'Settings'},
          },
          'ko': {
            'greeting': '안녕하세요',
            'nav': {'home': '홈', 'settings': '설정'},
          },
          'ja': {
            'greeting': 'こんにちは',
            'nav': {'home': 'ホーム', 'settings': '設定'},
          },
        },
      });

      // Verify initial locale
      expect(manager.currentLocale, equals('en'));
      expect(manager.translate('greeting'), equals('Hello'));
      expect(manager.translate('nav.home'), equals('Home'));

      // Switch to Korean
      manager.setLocale('ko');
      expect(manager.currentLocale, equals('ko'));
      expect(manager.translate('greeting'), equals('안녕하세요'));
      expect(manager.translate('nav.home'), equals('홈'));

      // Switch to Japanese
      manager.setLocale('ja');
      expect(manager.currentLocale, equals('ja'));
      expect(manager.translate('greeting'), equals('こんにちは'));
      expect(manager.translate('nav.settings'), equals('設定'));
    });

    test('Normal: translations cached — second switch uses cached data', () async {
      await I18nLoader.loadFromMap({
        'en': {'greeting': 'Hello'},
        'ko': {'greeting': '안녕하세요'},
      });

      // Switch to ko and back to en
      manager.setLocale('ko');
      expect(manager.translate('greeting'), equals('안녕하세요'));

      manager.setLocale('en');
      expect(manager.translate('greeting'), equals('Hello'));

      // Switch back to ko again — still works from cache
      manager.setLocale('ko');
      expect(manager.translate('greeting'), equals('안녕하세요'));
    });

    test('Normal: RTL direction updates on locale switch with auto mode', () async {
      await I18nLoader.loadFromMap({
        'en': {'greeting': 'Hello'},
        'ar': {'greeting': 'مرحبا'},
      });

      manager.setLocale('en');
      expect(manager.isRtl(), isFalse);

      manager.setLocale('ar');
      expect(manager.isRtl(), isTrue);

      // Switch back to LTR locale
      manager.setLocale('en');
      expect(manager.isRtl(), isFalse);
    });

    test('Boundary: switch to locale with no translations — fallback used', () async {
      await I18nLoader.loadFromMcpFormat({
        'defaultLocale': 'en',
        'translations': {
          'en': {'greeting': 'Hello'},
        },
      });

      manager.setLocale('fr');
      // Falls back to 'en' fallback locale
      expect(manager.translate('greeting'), equals('Hello'));
    });

    test('Normal: listener notified on each locale switch', () async {
      await I18nLoader.loadFromMap({
        'en': {'greeting': 'Hello'},
        'ko': {'greeting': '안녕하세요'},
      });

      int notifyCount = 0;
      manager.addListener(() => notifyCount++);

      manager.setLocale('ko');
      manager.setLocale('en');
      manager.setLocale('ko');

      expect(notifyCount, equals(3));
    });

    test('Normal: i18n binding resolution updates after locale switch', () async {
      await I18nLoader.loadFromMap({
        'en': {'title': 'My App'},
        'ko': {'title': '내 앱'},
      });

      expect(manager.resolveI18nString('i18n:title'), equals('My App'));

      manager.setLocale('ko');
      expect(manager.resolveI18nString('i18n:title'), equals('내 앱'));
    });
  });

  // TC-019: Plugin lifecycle for i18n
  group('TC-019: Plugin lifecycle for i18n', () {
    test('Normal: load translations from config and verify supported locales',
        () async {
      final i18nConfig = {
        'defaultLocale': 'en',
        'translations': {
          'en': {'greeting': 'Hello', 'farewell': 'Goodbye'},
          'ko': {'greeting': '안녕하세요', 'farewell': '안녕히 가세요'},
          'ja': {'greeting': 'こんにちは', 'farewell': 'さようなら'},
        },
      };

      await I18nLoader.loadFromMcpFormat(i18nConfig);

      // Verify all locales are supported
      final supportedLocales = manager.getSupportedLocales();
      expect(supportedLocales, containsAll(['en', 'ko', 'ja']));
      expect(supportedLocales.length, equals(3));
    });

    test('Normal: fallback locale set from config', () async {
      await I18nLoader.loadFromMcpFormat({
        'defaultLocale': 'ko',
        'translations': {
          'ko': {'greeting': '안녕하세요'},
        },
      });

      expect(manager.fallbackLocale, equals('ko'));
    });

    test('Normal: translations accessible after loading from config', () async {
      await I18nLoader.loadFromMcpFormat({
        'defaultLocale': 'en',
        'translations': {
          'en': {
            'app': {'title': 'Test App', 'version': '1.0'},
          },
        },
      });

      expect(manager.translate('app.title'), equals('Test App'));
      expect(manager.translate('app.version'), equals('1.0'));
    });

    test('Boundary: plugin disabled (no translations) — bindings return keys', () {
      // Simulate no translations loaded (plugin disabled)
      expect(manager.translate('greeting'), equals('greeting'));
      expect(manager.resolveI18nString('i18n:title'), equals('title'));
    });

    test('Normal: setLocale via I18nLoader updates I18nManager', () async {
      await I18nLoader.loadFromMcpFormat({
        'defaultLocale': 'en',
        'translations': {
          'en': {'greeting': 'Hello'},
          'ko': {'greeting': '안녕하세요'},
        },
      });

      I18nLoader.setLocale('ko');
      expect(manager.currentLocale, equals('ko'));
      expect(manager.translate('greeting'), equals('안녕하세요'));
    });

    test('Normal: hasKey works after plugin initialization', () async {
      await I18nLoader.loadFromMcpFormat({
        'defaultLocale': 'en',
        'translations': {
          'en': {'greeting': 'Hello', 'nav': {'home': 'Home'}},
        },
      });

      expect(manager.hasKey('greeting'), isTrue);
      expect(manager.hasKey('nav.home'), isTrue);
      expect(manager.hasKey('nonexistent'), isFalse);
    });
  });
}
