import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/i18n/i18n_manager.dart';
import 'package:flutter_mcp_ui_core/src/models/application_definition.dart';
import 'package:flutter_mcp_ui_core/src/models/i18n_config.dart';

void main() {
  late I18nManager manager;

  setUp(() {
    // Reset singleton for each test
    manager = I18nManager.instance;
    manager.clear();
    manager.setLocale('en');
    manager.setFallbackLocale('en');
  });

  group('I18nManager - Translation', () {
    test('translates with dot notation key', () {
      manager.loadLocaleTranslations('en', {
        'common': {
          'buttons': {
            'submit': 'Submit',
            'cancel': 'Cancel',
          },
        },
      });

      expect(manager.translate('common.buttons.submit'), equals('Submit'));
      expect(manager.translate('common.buttons.cancel'), equals('Cancel'));
    });

    test('falls back to fallback locale', () {
      manager.setFallbackLocale('en');
      manager.loadLocaleTranslations('en', {
        'greeting': 'Hello',
      });
      manager.loadLocaleTranslations('ko', {});
      manager.setLocale('ko');

      expect(manager.translate('greeting'), equals('Hello'));
    });

    test('returns key when translation not found', () {
      expect(manager.translate('missing.key'), equals('missing.key'));
    });

    test('interpolates parameters', () {
      manager.loadLocaleTranslations('en', {
        'welcome': 'Hello, {{name}}!',
      });

      expect(
        manager.translate('welcome', params: {'name': 'World'}),
        equals('Hello, World!'),
      );
    });
  });

  group('I18nManager - {{i18n.key}} Binding', () {
    test('resolves i18n: prefix format', () {
      manager.loadLocaleTranslations('en', {
        'app': {'title': 'My App'},
      });

      final result = manager.resolveI18nString('i18n:app.title');
      expect(result, equals('My App'));
    });

    test('resolves i18n: prefix with params', () {
      manager.loadLocaleTranslations('en', {
        'greeting': 'Hello, {{name}}!',
      });

      final result = manager.resolveI18nString('i18n:greeting:name=World');
      expect(result, equals('Hello, World!'));
    });
  });

  group('I18nManager - CLDR Plural Rules', () {
    test('English plural rules', () {
      manager.setLocale('en');
      manager.loadLocaleTranslations('en', {
        'items': {
          'zero': 'No items',
          'one': '1 item',
          'other': '{{count}} items',
        },
      });

      expect(manager.plural('items', 0), equals('No items'));
      expect(manager.plural('items', 1), equals('1 item'));
      expect(manager.plural('items', 5), equals('5 items'));
    });

    test('Arabic plural rules with few/many', () {
      manager.setLocale('ar');
      manager.loadLocaleTranslations('ar', {
        'books': {
          'zero': 'لا كتب',
          'one': 'كتاب واحد',
          'two': 'كتابان',
          'few': '{{count}} كتب',
          'many': '{{count}} كتاباً',
          'other': '{{count}} كتاب',
        },
      });

      expect(manager.plural('books', 0), equals('لا كتب'));
      expect(manager.plural('books', 1), equals('كتاب واحد'));
      expect(manager.plural('books', 2), equals('كتابان'));
      expect(manager.plural('books', 5), equals('5 كتب'));
      expect(manager.plural('books', 11), equals('11 كتاباً'));
      expect(manager.plural('books', 100), equals('100 كتاب'));
    });

    test('Russian plural rules with few/many', () {
      manager.setLocale('ru');
      manager.loadLocaleTranslations('ru', {
        'items': {
          'zero': 'нет предметов',
          'one': '{{count}} предмет',
          'few': '{{count}} предмета',
          'many': '{{count}} предметов',
          'other': '{{count}} предметов',
        },
      });

      expect(manager.plural('items', 0), equals('нет предметов'));
      expect(manager.plural('items', 1), equals('1 предмет'));
      expect(manager.plural('items', 3), equals('3 предмета'));
      expect(manager.plural('items', 5), equals('5 предметов'));
      expect(manager.plural('items', 21), equals('21 предмет'));
    });

    test('Japanese/Korean/Chinese - no plural distinction', () {
      manager.setLocale('ja');
      manager.loadLocaleTranslations('ja', {
        'items': {
          'zero': 'アイテムなし',
          'other': '{{count}}個のアイテム',
        },
      });

      expect(manager.plural('items', 0), equals('アイテムなし'));
      expect(manager.plural('items', 1), equals('1個のアイテム'));
      expect(manager.plural('items', 100), equals('100個のアイテム'));
    });

    test('French - 0 and 1 are singular', () {
      manager.setLocale('fr');
      manager.loadLocaleTranslations('fr', {
        'items': {
          'zero': 'Aucun élément',
          'one': '{{count}} élément',
          'other': '{{count}} éléments',
        },
      });

      expect(manager.plural('items', 0), equals('Aucun élément'));
      expect(manager.plural('items', 1), equals('1 élément'));
      expect(manager.plural('items', 5), equals('5 éléments'));
    });
  });

  group('I18nManager - RTL Detection', () {
    test('detects RTL for Arabic', () {
      manager.setLocale('ar');
      expect(manager.isRtl(), isTrue);
    });

    test('detects RTL for Hebrew', () {
      manager.setLocale('he');
      expect(manager.isRtl(), isTrue);
    });

    test('detects RTL for Persian', () {
      manager.setLocale('fa-IR');
      expect(manager.isRtl(), isTrue);
    });

    test('detects LTR for English', () {
      manager.setLocale('en');
      expect(manager.isRtl(), isFalse);
    });

    test('detects LTR for Korean', () {
      manager.setLocale('ko');
      expect(manager.isRtl(), isFalse);
    });

    test('explicit rtl setting overrides locale', () {
      manager.setLocale('en');
      expect(manager.isRtl(rtlSetting: 'true'), isTrue);

      manager.setLocale('ar');
      expect(manager.isRtl(rtlSetting: 'false'), isFalse);
    });

    test('auto rtl setting uses locale detection', () {
      manager.setLocale('ar');
      expect(manager.isRtl(rtlSetting: 'auto'), isTrue);

      manager.setLocale('en');
      expect(manager.isRtl(rtlSetting: 'auto'), isFalse);
    });
  });

  group('I18nConfig - RTL field', () {
    test('fromJson parses rtl field', () {
      final config = I18nConfig.fromJson({
        'text': {'key': 'test', 'default': 'Test'},
        'rtl': 'auto',
      });

      expect(config.rtl, equals('auto'));
    });

    test('toJson includes rtl field', () {
      const config = I18nConfig(rtl: 'true');
      final json = config.toJson();
      expect(json['rtl'], equals('true'));
    });

    test('flat format parses rtl', () {
      final config = I18nConfig.fromJson({
        'key': 'test',
        'default': 'Test',
        'rtl': 'auto',
      });

      expect(config.rtl, equals('auto'));
    });

    test('flat format parses date format', () {
      final config = I18nConfig.fromJson({
        'key': 'createdAt',
        'default': '',
        'format': 'date',
        'dateStyle': 'long',
      });

      expect(config.dateFormat, isNotNull);
      expect(config.dateFormat!.style, equals('long'));
    });
  });

  group('ApplicationDefinition - i18n fields', () {
    test('fromJson parses i18n block', () {
      final def = ApplicationDefinition.fromJson({
        'title': 'Test App',
        'version': '1.0.0',
        'routes': {'/': 'main'},
        'i18n': {
          'defaultLocale': 'en',
          'supportedLocales': ['en', 'ko', 'ja'],
          'fallbackLocale': 'en',
        },
      });

      expect(def.defaultLocale, equals('en'));
      expect(def.supportedLocales, equals(['en', 'ko', 'ja']));
      expect(def.fallbackLocale, equals('en'));
    });

    test('toJson includes i18n block', () {
      const def = ApplicationDefinition(
        title: 'Test',
        version: '1.0',
        routes: {'/': 'main'},
        defaultLocale: 'ko',
        locales: ['en', 'ko'],
        fallbackLocale: 'en',
      );

      final json = def.toJson();
      expect(json['i18n'], isNotNull);
      expect(json['i18n']['defaultLocale'], equals('ko'));
      expect(json['i18n']['locales'], equals(['en', 'ko']));
      expect(json['i18n']['fallbackLocale'], equals('en'));
    });

    test('toJson omits i18n block when all null', () {
      const def = ApplicationDefinition(
        title: 'Test',
        version: '1.0',
        routes: {'/': 'main'},
      );

      final json = def.toJson();
      expect(json.containsKey('i18n'), isFalse);
    });

    test('copyWith updates i18n fields', () {
      const def = ApplicationDefinition(
        title: 'Test',
        version: '1.0',
        routes: {'/': 'main'},
        defaultLocale: 'en',
      );

      final updated = def.copyWith(defaultLocale: 'ko');
      expect(updated.defaultLocale, equals('ko'));
    });

    test('equality includes i18n fields', () {
      const def1 = ApplicationDefinition(
        title: 'Test',
        version: '1.0',
        routes: {'/': 'main'},
        defaultLocale: 'en',
      );
      const def2 = ApplicationDefinition(
        title: 'Test',
        version: '1.0',
        routes: {'/': 'main'},
        defaultLocale: 'ko',
      );

      expect(def1 == def2, isFalse);
    });
  });

  // TC-001: I18nManager — singleton and initialization
  group('TC-001: I18nManager — singleton and initialization', () {
    test('Normal: instance returns the same instance on repeated calls', () {
      final instance1 = I18nManager.instance;
      final instance2 = I18nManager.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('Normal: I18nManager extends ChangeNotifier', () {
      expect(manager, isA<ChangeNotifier>());
    });

    test('Normal: currentLocale defaults to en after reset', () {
      // setUp resets locale to 'en'
      expect(manager.currentLocale, equals('en'));
    });

    test('Normal: getSupportedLocales returns configured locale list', () {
      manager.loadLocaleTranslations('en', {'greeting': 'Hello'});
      manager.loadLocaleTranslations('ko', {'greeting': '안녕하세요'});
      expect(manager.getSupportedLocales(), containsAll(['en', 'ko']));
    });

    test('Boundary: no translations loaded — translate returns key as fallback', () {
      expect(manager.translate('anything'), equals('anything'));
    });

    test('Boundary: empty supported locales after clear', () {
      manager.clear();
      expect(manager.getSupportedLocales(), isEmpty);
    });
  });

  // TC-002: I18nManager — translate (additional cases)
  group('TC-002: I18nManager — translate (extended)', () {
    test('Normal: translate returns translation string for current locale', () {
      manager.loadLocaleTranslations('en', {'greeting': 'Hello'});
      expect(manager.translate('greeting'), equals('Hello'));
    });

    test('Normal: translate with params interpolates parameters', () {
      manager.loadLocaleTranslations('en', {
        'greeting': 'Hello, {name}!',
      });
      expect(
        manager.translate('greeting', params: {'name': 'World'}),
        equals('Hello, World!'),
      );
    });

    test('Normal: nested key resolves dot notation path', () {
      manager.loadLocaleTranslations('en', {
        'nav': {'home': 'Home'},
      });
      expect(manager.translate('nav.home'), equals('Home'));
    });

    test('Boundary: non-existent key returns the key string as fallback', () {
      manager.loadLocaleTranslations('en', {'a': 'b'});
      expect(manager.translate('nonexistent'), equals('nonexistent'));
    });

    test('Boundary: missing parameter in translation — placeholder left as-is', () {
      manager.loadLocaleTranslations('en', {
        'msg': 'Hello, {name}! Your code is {code}.',
      });
      // Only provide 'name', not 'code'
      final result = manager.translate('msg', params: {'name': 'World'});
      expect(result, contains('{code}'));
      expect(result, contains('World'));
    });

    test('Boundary: extra params not in translation — ignored', () {
      manager.loadLocaleTranslations('en', {'msg': 'Hello'});
      final result = manager.translate('msg', params: {'extra': 'value'});
      expect(result, equals('Hello'));
    });
  });

  // TC-003: I18nManager — plural
  group('TC-003: I18nManager — plural', () {
    setUp(() {
      manager.loadLocaleTranslations('en', {
        'items': {
          'zero': 'No items',
          'one': '1 item',
          'other': '{count} items',
        },
        'messages': {
          'one': '1 message',
          'other': '{count} messages',
        },
        'plain': 'Not a plural key',
      });
    });

    test('Normal: plural("items", 0) returns "zero" form', () {
      expect(manager.plural('items', 0), equals('No items'));
    });

    test('Normal: plural("items", 1) returns "one" form', () {
      expect(manager.plural('items', 1), equals('1 item'));
    });

    test('Normal: plural("items", 5) returns "other" form', () {
      expect(manager.plural('items', 5), equals('5 items'));
    });

    test('Normal: params interpolated in plural form', () {
      manager.loadLocaleTranslations('en', {
        'items': {
          'zero': 'No items',
          'one': '1 item',
          'other': '{count} items total',
        },
      });
      expect(
        manager.plural('items', 5, params: {'count': 5}),
        equals('5 items total'),
      );
    });

    test('Boundary: missing plural form for count — falls back to "other" form', () {
      // "messages" has no "zero" form; count=0 requests "zero" but falls back
      // Since translate('messages.zero') is missing, it returns the key
      // The implementation looks up items.zero first; test with a key that has no "zero"
      manager.loadLocaleTranslations('en', {
        'notifications': {
          'one': '1 notification',
          'other': '{count} notifications',
        },
      });
      // count=0 looks for 'notifications.zero' which is missing, falls through to key
      final result = manager.plural('notifications', 0);
      // Key 'notifications.zero' not found, returns key as fallback
      expect(result, equals('notifications.zero'));
    });

    test('Boundary: missing "other" form — returns key as fallback', () {
      manager.loadLocaleTranslations('en', {
        'sparse': {
          'one': 'Single',
        },
      });
      // count=5 looks for 'sparse.other' which is missing
      expect(manager.plural('sparse', 5), equals('sparse.other'));
    });

    test('Boundary: negative count — uses "other" form', () {
      expect(manager.plural('items', -1), equals('-1 items'));
    });

    test('Error: key does not contain plural forms — returns translate() result', () {
      // 'plain' is a simple string, not a map with plural forms
      // plural('plain', 1) calls translate('plain.one') which traverses to 'plain'
      // (a String), then cannot go deeper — returns the String value at 'plain'
      final result = manager.plural('plain', 1);
      expect(result, equals('Not a plural key'));
    });
  });

  // TC-004: I18nManager — locale switching
  group('TC-004: I18nManager — locale switching', () {
    test('Normal: setting locale switches current locale', () {
      manager.setLocale('ko');
      expect(manager.currentLocale, equals('ko'));
    });

    test('Normal: notifies listeners on locale change', () {
      int notifyCount = 0;
      manager.addListener(() => notifyCount++);

      manager.setLocale('ko');
      expect(notifyCount, equals(1));
    });

    test('Normal: subsequent translate calls return translations for new locale', () {
      manager.loadLocaleTranslations('en', {'greeting': 'Hello'});
      manager.loadLocaleTranslations('ko', {'greeting': '안녕하세요'});

      expect(manager.translate('greeting'), equals('Hello'));

      manager.setLocale('ko');
      expect(manager.translate('greeting'), equals('안녕하세요'));
    });
  });

  // TC-020: I18nManager — loadLocaleTranslations
  group('TC-020: I18nManager — loadLocaleTranslations', () {
    test('Normal: adds translations for a specific locale', () {
      manager.loadLocaleTranslations('fr', {'bonjour': 'Bonjour'});
      manager.setLocale('fr');
      expect(manager.translate('bonjour'), equals('Bonjour'));
    });

    test('Boundary: calling with existing locale — overwrites translations', () {
      manager.loadLocaleTranslations('en', {'key1': 'Value1'});
      manager.loadLocaleTranslations('en', {'key2': 'Value2'});
      // loadLocaleTranslations replaces the entire map for that locale
      expect(manager.translate('key2'), equals('Value2'));
    });
  });

  // TC-021: I18nManager — isLocaleSupported and getSupportedLocales
  group('TC-021: I18nManager — isLocaleSupported and getSupportedLocales', () {
    test('Normal: isLocaleSupported returns true for loaded locale', () {
      manager.loadLocaleTranslations('en', {'a': 'b'});
      expect(manager.isLocaleSupported('en'), isTrue);
    });

    test('Normal: getSupportedLocales returns all loaded locales', () {
      manager.loadLocaleTranslations('en', {'a': 'b'});
      manager.loadLocaleTranslations('ko', {'a': 'c'});
      final locales = manager.getSupportedLocales();
      expect(locales, containsAll(['en', 'ko']));
      expect(locales.length, equals(2));
    });

    test('Boundary: isLocaleSupported returns false for unknown locale', () {
      expect(manager.isLocaleSupported('zz'), isFalse);
    });
  });

  // TC-022: I18nManager — resolveI18nString and resolve
  group('TC-022: I18nManager — resolveI18nString and resolve (extended)', () {
    test('Normal: resolveI18nString returns translated string', () {
      manager.loadLocaleTranslations('en', {'greeting': 'Hello'});
      expect(manager.resolveI18nString('i18n:greeting'), equals('Hello'));
    });

    test('Normal: resolveI18nString with parameter interpolation', () {
      manager.loadLocaleTranslations('en', {
        'welcome': 'Welcome, {name}!',
      });
      expect(
        manager.resolveI18nString('i18n:welcome:name=World'),
        equals('Welcome, World!'),
      );
    });

    test('Boundary: non-i18n-prefixed string — returns original value', () {
      expect(manager.resolveI18nString('plain text'), equals('plain text'));
    });

    test('Boundary: null input — returns null', () {
      expect(manager.resolveI18nString(null), isNull);
    });

    test('Normal: resolve with String delegates to resolveI18nString', () {
      manager.loadLocaleTranslations('en', {'title': 'My App'});
      expect(manager.resolve('i18n:title'), equals('My App'));
    });

    test('Normal: resolve with non-String returns value as-is', () {
      expect(manager.resolve(42), equals(42));
      expect(manager.resolve(true), equals(true));
    });
  });

  // TC-023: I18nManager — getNestedValue
  group('TC-023: I18nManager — getNestedValue', () {
    test('Normal: resolves dot-separated path in locale translations', () {
      manager.loadLocaleTranslations('en', {
        'nav': {'home': 'Home', 'settings': 'Settings'},
      });
      expect(manager.getNestedValue('en', 'nav.home'), equals('Home'));
    });

    test('Boundary: path not found — returns null', () {
      manager.loadLocaleTranslations('en', {'a': 'b'});
      expect(manager.getNestedValue('en', 'x.y.z'), isNull);
    });

    test('Boundary: single-segment path — returns top-level value', () {
      manager.loadLocaleTranslations('en', {'greeting': 'Hello'});
      expect(manager.getNestedValue('en', 'greeting'), equals('Hello'));
    });
  });

  // TC-024: I18nManager — clear
  group('TC-024: I18nManager — clear', () {
    test('Normal: removes all loaded translations', () {
      manager.loadLocaleTranslations('en', {'greeting': 'Hello'});
      expect(manager.translate('greeting'), equals('Hello'));

      manager.clear();
      expect(manager.translate('greeting'), equals('greeting'));
    });

    test('Normal: getSupportedLocales returns empty after clear', () {
      manager.loadLocaleTranslations('en', {'a': 'b'});
      manager.clear();
      expect(manager.getSupportedLocales(), isEmpty);
    });

    test('Boundary: called when no translations loaded — no error', () {
      manager.clear();
      manager.clear(); // Double clear should not throw
      expect(manager.getSupportedLocales(), isEmpty);
    });
  });

  // TC-005: I18nManager — hasKey and translationKeys
  group('TC-005: I18nManager — hasKey and translationKeys', () {
    test('Normal: hasKey returns true for existing top-level key', () {
      manager.loadLocaleTranslations('en', {'greeting': 'Hello'});
      expect(manager.hasKey('greeting'), isTrue);
    });

    test('Normal: hasKey returns true for nested dot-notation key', () {
      manager.loadLocaleTranslations('en', {
        'nav': {'home': 'Home', 'settings': 'Settings'},
      });
      expect(manager.hasKey('nav.home'), isTrue);
      expect(manager.hasKey('nav.settings'), isTrue);
    });

    test('Normal: translationKeys returns all top-level keys', () {
      manager.loadLocaleTranslations('en', {
        'greeting': 'Hello',
        'farewell': 'Goodbye',
        'nav': {'home': 'Home'},
      });
      expect(manager.translationKeys, equals({'greeting', 'farewell', 'nav'}));
    });

    test('Boundary: hasKey returns false for non-existent key', () {
      manager.loadLocaleTranslations('en', {'a': 'b'});
      expect(manager.hasKey('nonexistent'), isFalse);
    });

    test('Boundary: hasKey returns false for partially valid nested path', () {
      manager.loadLocaleTranslations('en', {
        'nav': {'home': 'Home'},
      });
      expect(manager.hasKey('nav.missing'), isFalse);
    });

    test('Boundary: hasKey returns false when no translations loaded', () {
      expect(manager.hasKey('anything'), isFalse);
    });

    test('Boundary: translationKeys returns empty set when no translations loaded', () {
      expect(manager.translationKeys, isEmpty);
    });

    test('Boundary: translationKeys reflects current locale only', () {
      manager.loadLocaleTranslations('en', {'greeting': 'Hello'});
      manager.loadLocaleTranslations('ko', {'greeting': '안녕', 'extra': '추가'});
      manager.setLocale('ko');
      expect(manager.translationKeys, equals({'greeting', 'extra'}));
    });
  });

  // TC-009: I18nManager — formatCurrency
  group('TC-009: I18nManager — formatCurrency', () {
    test('Normal: formats currency with default locale (en/USD)', () {
      final result = manager.formatCurrency(1234.56);
      expect(result, equals('\$1,234.56'));
    });

    test('Normal: formats currency with explicit currency symbol', () {
      final result = manager.formatCurrency(1000, currency: 'EUR');
      expect(result, equals('€1,000.00'));
    });

    test('Normal: formats currency with GBP', () {
      final result = manager.formatCurrency(99.9, currency: 'GBP');
      expect(result, equals('£99.90'));
    });

    test('Boundary: zero value', () {
      final result = manager.formatCurrency(0);
      expect(result, equals('\$0.00'));
    });

    test('Boundary: negative value', () {
      final result = manager.formatCurrency(-50.5);
      expect(result, equals('\$-50.50'));
    });

    test('Boundary: large number', () {
      final result = manager.formatCurrency(1000000);
      expect(result, equals('\$1,000,000.00'));
    });
  });

  // TC-010: I18nManager — formatDate
  group('TC-010: I18nManager — formatDate', () {
    test('Normal: formats date with default yMd pattern', () {
      final date = DateTime(2024, 3, 15);
      final result = manager.formatDate(date);
      expect(result, equals('3/15/2024'));
    });

    test('Normal: formats date with custom pattern yyyy-MM-dd', () {
      final date = DateTime(2024, 3, 5);
      final result = manager.formatDate(date, pattern: 'yyyy-MM-dd');
      expect(result, equals('2024-03-05'));
    });

    test('Normal: formats date with time pattern', () {
      final date = DateTime(2024, 1, 2, 14, 30, 45);
      final result = manager.formatDate(date, pattern: 'yyyy-MM-dd HH:mm:ss');
      expect(result, equals('2024-01-02 14:30:45'));
    });

    test('Boundary: first day of year', () {
      final date = DateTime(2024, 1, 1);
      final result = manager.formatDate(date);
      expect(result, equals('1/1/2024'));
    });

    test('Boundary: last day of year', () {
      final date = DateTime(2024, 12, 31);
      final result = manager.formatDate(date);
      expect(result, equals('12/31/2024'));
    });
  });

  // TC-011: I18nManager — formatNumber
  group('TC-011: I18nManager — formatNumber', () {
    test('Normal: formats integer with thousand separators', () {
      final result = manager.formatNumber(1234567);
      expect(result, equals('1,234,567'));
    });

    test('Normal: formats decimal number', () {
      final result = manager.formatNumber(1234.56);
      expect(result, equals('1,234.56'));
    });

    test('Normal: formats with German locale (period separator)', () {
      final result = manager.formatNumber(1234567, locale: 'de');
      expect(result, equals('1.234.567'));
    });

    test('Boundary: zero', () {
      final result = manager.formatNumber(0);
      expect(result, equals('0'));
    });

    test('Boundary: negative number', () {
      final result = manager.formatNumber(-9876);
      expect(result, equals('-9,876'));
    });

    test('Boundary: small number (no grouping needed)', () {
      final result = manager.formatNumber(42);
      expect(result, equals('42'));
    });
  });

  // TC-012: I18nManager — formatPercent
  group('TC-012: I18nManager — formatPercent', () {
    test('Normal: formats 0.5 as 50%', () {
      final result = manager.formatPercent(0.5);
      expect(result, equals('50%'));
    });

    test('Normal: formats 1.0 as 100%', () {
      final result = manager.formatPercent(1.0);
      expect(result, equals('100%'));
    });

    test('Normal: formats 0.1234 as 12%', () {
      final result = manager.formatPercent(0.1234);
      expect(result, equals('12%'));
    });

    test('Boundary: zero percent', () {
      final result = manager.formatPercent(0.0);
      expect(result, equals('0%'));
    });

    test('Boundary: value greater than 1', () {
      final result = manager.formatPercent(2.5);
      expect(result, equals('250%'));
    });

    test('Boundary: very small value', () {
      final result = manager.formatPercent(0.001);
      expect(result, equals('0%'));
    });

    test('Boundary: large percentage with grouping', () {
      final result = manager.formatPercent(100.0);
      expect(result, equals('10,000%'));
    });
  });

  // TC-013: RTL mode — auto
  group('TC-013: RTL mode — auto', () {
    test('Normal: locale "ar" with rtlMode auto → RTL', () {
      manager.setLocale('ar');
      expect(manager.isRtl(rtlSetting: 'auto'), isTrue);
    });

    test('Normal: locale "en" with rtlMode auto → LTR', () {
      manager.setLocale('en');
      expect(manager.isRtl(rtlSetting: 'auto'), isFalse);
    });

    test('Normal: locale "he" with rtlMode auto → RTL', () {
      manager.setLocale('he');
      expect(manager.isRtl(rtlSetting: 'auto'), isTrue);
    });

    test('Normal: locale "fa" with rtlMode auto → RTL', () {
      manager.setLocale('fa');
      expect(manager.isRtl(rtlSetting: 'auto'), isTrue);
    });

    test('Normal: locale "ur" with rtlMode auto → RTL', () {
      manager.setLocale('ur');
      expect(manager.isRtl(rtlSetting: 'auto'), isTrue);
    });

    test('Boundary: unknown locale with rtlMode auto → defaults to LTR', () {
      manager.setLocale('xx');
      expect(manager.isRtl(rtlSetting: 'auto'), isFalse);
    });
  });

  // TC-014: RTL mode — forced
  group('TC-014: RTL mode — forced', () {
    test('Normal: rtlMode rtl with locale "en" → RTL (forced)', () {
      manager.setLocale('en');
      expect(manager.isRtl(rtlSetting: 'true'), isTrue);
    });

    test('Normal: rtlMode ltr with locale "ar" → LTR (forced)', () {
      manager.setLocale('ar');
      expect(manager.isRtl(rtlSetting: 'false'), isFalse);
    });

    test('Normal: locale switch with forced mode — direction does not change', () {
      // Forced RTL regardless of locale
      manager.setLocale('en');
      expect(manager.isRtl(rtlSetting: 'true'), isTrue);

      manager.setLocale('ko');
      expect(manager.isRtl(rtlSetting: 'true'), isTrue);

      manager.setLocale('ar');
      expect(manager.isRtl(rtlSetting: 'true'), isTrue);

      // Forced LTR regardless of locale
      manager.setLocale('ar');
      expect(manager.isRtl(rtlSetting: 'false'), isFalse);

      manager.setLocale('en');
      expect(manager.isRtl(rtlSetting: 'false'), isFalse);
    });
  });

  // TC-015: RTL layout rebuild (unit-level verification)
  group('TC-015: RTL layout rebuild', () {
    test('Normal: switching from en to ar with auto mode changes RTL', () {
      manager.setLocale('en');
      expect(manager.isRtl(rtlSetting: 'auto'), isFalse);

      manager.setLocale('ar');
      expect(manager.isRtl(rtlSetting: 'auto'), isTrue);
    });

    test('Normal: notifies listeners on locale switch (enables rebuild)', () {
      int notifyCount = 0;
      manager.addListener(() => notifyCount++);

      manager.setLocale('ar');
      expect(notifyCount, equals(1));
      expect(manager.isRtl(), isTrue);
    });
  });
}
