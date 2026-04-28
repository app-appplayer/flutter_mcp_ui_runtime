import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/i18n/i18n_manager.dart';

void main() {
  late I18nManager manager;

  setUp(() {
    manager = I18nManager.instance;
    manager.clear();
    manager.setLocale('en');
    manager.setFallbackLocale('en');
  });

  // TC-016: I18n binding expressions
  group('TC-016: I18n binding expressions', () {
    test('Normal: resolveI18nString resolves i18n:key format', () {
      manager.loadLocaleTranslations('en', {
        'greeting': 'Hello',
      });

      expect(manager.resolveI18nString('i18n:greeting'), equals('Hello'));
    });

    test('Normal: resolveI18nString with parameter interpolation', () {
      manager.loadLocaleTranslations('en', {
        'greeting': 'Hello, {name}!',
      });

      final result = manager.resolveI18nString('i18n:greeting:name=World');
      expect(result, equals('Hello, World!'));
    });

    test('Normal: resolveI18nString resolves nested key', () {
      manager.loadLocaleTranslations('en', {
        'nav': {'home': 'Home'},
      });

      expect(manager.resolveI18nString('i18n:nav.home'), equals('Home'));
    });

    test('Boundary: resolveI18nString with missing key returns key name', () {
      manager.loadLocaleTranslations('en', {'a': 'b'});

      expect(manager.resolveI18nString('i18n:missing'), equals('missing'));
    });

    test('Boundary: non-i18n-prefixed string returned as-is', () {
      expect(manager.resolveI18nString('plain text'), equals('plain text'));
    });

    test('Boundary: null input returns null', () {
      expect(manager.resolveI18nString(null), isNull);
    });

    test('Normal: resolve() with String delegates to resolveI18nString', () {
      manager.loadLocaleTranslations('en', {'title': 'My App'});

      expect(manager.resolve('i18n:title'), equals('My App'));
    });

    test('Normal: resolve() with non-String returns value as-is', () {
      expect(manager.resolve(42), equals(42));
      expect(manager.resolve(true), equals(true));
      expect(manager.resolve(null), isNull);
    });

    test('Normal: resolve() with plain string returns it unchanged', () {
      expect(manager.resolve('just text'), equals('just text'));
    });

    test('Normal: resolveI18nString with multiple params', () {
      manager.loadLocaleTranslations('en', {
        'msg': 'Hello {name}, you have {count} items',
      });

      final result =
          manager.resolveI18nString('i18n:msg:name=World,count=5');
      expect(result, equals('Hello World, you have 5 items'));
    });
  });

  // TC-017: I18n bindings on locale switch
  group('TC-017: I18n bindings on locale switch', () {
    test('Normal: setLocale triggers ChangeNotifier listeners', () {
      int notifyCount = 0;
      manager.addListener(() => notifyCount++);

      manager.setLocale('ko');
      expect(notifyCount, equals(1));
    });

    test('Normal: locale change causes re-resolution to new translations', () {
      manager.loadLocaleTranslations('en', {'greeting': 'Hello'});
      manager.loadLocaleTranslations('ko', {'greeting': '안녕하세요'});

      expect(manager.resolveI18nString('i18n:greeting'), equals('Hello'));

      manager.setLocale('ko');
      expect(manager.resolveI18nString('i18n:greeting'), equals('안녕하세요'));
    });

    test('Normal: multiple listeners all notified on locale change', () {
      int count1 = 0;
      int count2 = 0;
      manager.addListener(() => count1++);
      manager.addListener(() => count2++);

      manager.setLocale('fr');
      expect(count1, equals(1));
      expect(count2, equals(1));
    });

    test('Normal: loadLocaleTranslations also triggers notification', () {
      int notifyCount = 0;
      manager.addListener(() => notifyCount++);

      manager.loadLocaleTranslations('en', {'key': 'value'});
      expect(notifyCount, equals(1));
    });

    test('Normal: format types re-resolve with new locale', () {
      manager.setLocale('en');
      final enResult = manager.formatNumber(1234567);
      expect(enResult, equals('1,234,567'));

      manager.setLocale('de');
      final deResult = manager.formatNumber(1234567);
      expect(deResult, equals('1.234.567'));
    });
  });
}
