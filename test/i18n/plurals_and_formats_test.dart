// Plural categories and locale formatting.
//
// A plural rule that answers the wrong category shows the wrong string —
// "1 items", or a Russian count in the genitive plural for a number that needs
// the nominative. It is invisible to anyone who does not read the language,
// which is exactly why it needs a test per family rather than a spot check.

import 'package:flutter_mcp_ui_runtime/src/i18n/i18n_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late I18nManager i18n;

  setUp(() {
    i18n = I18nManager.instance..clear();
  });

  tearDown(() => I18nManager.instance.clear());

  /// The category [count] falls into for [locale].
  ///
  /// Read through `plural`, which is the API a document uses: with no
  /// translations loaded the key falls through unchanged, so the suffix it
  /// asked for is exactly the category it chose.
  String category(String locale, int count) {
    i18n.setLocale(locale);
    return i18n.plural('items', count).split('.').last;
  }

  group('plural categories', () {
    test('English: one and other, with zero named separately', () {
      expect(category('en', 0), 'zero');
      expect(category('en', 1), 'one');
      expect(category('en', 2), 'other');
      expect(category('en', 21), 'other');
    });

    test('Russian: one, few and many turn on the last two digits', () {
      expect(category('ru', 0), 'zero');
      expect(category('ru', 1), 'one');
      expect(category('ru', 21), 'one',
          reason: '21 ends in 1 and is not 11 — the same form as 1');
      expect(category('ru', 11), 'many',
          reason: '11 is the exception the mod-100 test exists for');
      expect(category('ru', 3), 'few');
      expect(category('ru', 23), 'few');
      expect(category('ru', 13), 'many');
      expect(category('ru', 5), 'many');
    });

    test('Ukrainian follows the same rule', () {
      expect(category('uk', 21), 'one');
      expect(category('uk', 3), 'few');
      expect(category('uk', 13), 'many');
    });

    test('Polish: one only for exactly one', () {
      expect(category('pl', 1), 'one');
      expect(category('pl', 21), 'many',
          reason: 'Polish differs from Russian here, which is why they cannot '
              'share a branch');
      expect(category('pl', 3), 'few');
      expect(category('pl', 13), 'many');
    });

    test('Arabic: zero, one, two, few, many', () {
      expect(category('ar', 0), 'zero');
      expect(category('ar', 1), 'one');
      expect(category('ar', 2), 'two');
      expect(category('ar', 5), 'few');
      expect(category('ar', 15), 'many');
      expect(category('ar', 200), 'other');
    });

    test('Hebrew: zero, one, two, other', () {
      expect(category('he', 0), 'zero');
      expect(category('he', 1), 'one');
      expect(category('he', 2), 'two');
      expect(category('he', 3), 'other');
    });

    test('Korean, Japanese, Chinese, Thai and Vietnamese have no plural form',
        () {
      for (final locale in const ['ko', 'ja', 'zh', 'th', 'vi']) {
        expect(category(locale, 1), 'other', reason: locale);
        expect(category(locale, 5), 'other', reason: locale);
        expect(category(locale, 0), 'zero', reason: locale);
      }
    });

    test('an unknown locale falls back to the English shape', () {
      expect(category('xx', 0), 'zero');
      expect(category('xx', 1), 'one');
      expect(category('xx', 7), 'other');
    });

    test('a regioned locale is read by its language', () {
      expect(category('ru-RU', 11), 'many');
      expect(category('pt_BR', 1), 'one');
    });
  });

  group('text direction', () {
    test('an explicit setting overrides the locale', () {
      i18n.setLocale('ar');
      expect(i18n.isRtl(rtlSetting: 'false'), isFalse,
          reason: 'a document that lays itself out LTR in an RTL locale has '
              'said so deliberately');

      i18n.setLocale('en');
      expect(i18n.isRtl(rtlSetting: 'true'), isTrue);
      expect(i18n.isRtl(rtlSetting: 'auto'), isFalse);
    });

    test('the RTL locales are RTL and the rest are not', () {
      for (final locale in const ['ar', 'he', 'fa', 'ur']) {
        i18n.setLocale(locale);
        expect(i18n.isRtl(), isTrue, reason: locale);
      }

      for (final locale in const ['en', 'ko', 'de']) {
        i18n.setLocale(locale);
        expect(i18n.isRtl(), isFalse, reason: locale);
      }
    });
  });

  group('currency', () {
    test('each locale has a default currency', () {
      expect(i18n.formatCurrency(1234.5, locale: 'en'), startsWith(r'$'));
      expect(i18n.formatCurrency(1234.5, locale: 'ko'), startsWith('₩'));
      expect(i18n.formatCurrency(1234.5, locale: 'ja'), startsWith('¥'));
      expect(i18n.formatCurrency(1234.5, locale: 'de'), startsWith('€'));
      expect(i18n.formatCurrency(1234.5, locale: 'ru'), startsWith('₽'));
      expect(i18n.formatCurrency(1234.5, locale: 'zh'), startsWith('¥'));
      expect(i18n.formatCurrency(1234.5, locale: 'xx'), startsWith(r'$'),
          reason: 'an unknown locale still has to produce a price');
    });

    test('a declared currency wins over the locale default', () {
      expect(i18n.formatCurrency(10, locale: 'ko', currency: 'GBP'),
          startsWith('£'));
    });

    test('a currency with no symbol is named instead of dropped', () {
      expect(i18n.formatCurrency(10, currency: 'SEK'), contains('SEK'),
          reason: 'a price with no currency at all is a number the reader '
              'cannot act on');
    });

    test('the amount is grouped and carries two decimals', () {
      expect(i18n.formatCurrency(1234.5, locale: 'en'), r'$1,234.50');
    });
  });

  group('numbers and dates', () {
    test('grouping follows the locale', () {
      expect(i18n.formatNumber(1234567, locale: 'en'), '1,234,567');
      expect(i18n.formatNumber(1234567, locale: 'de'), contains('.'),
          reason: 'a German reader parses 1.234.567 as one number and '
              '1,234,567 as something else entirely');
    });

    test('a date formats with its pattern, or with a default', () {
      final date = DateTime(2026, 3, 9, 14, 5);

      expect(i18n.formatDate(date), '3/9/2026');
      expect(i18n.formatDate(date, pattern: 'yyyy-MM-dd'), '2026-03-09');
    });
  });

  group('translations', () {
    test('a key that exists is reported as existing', () async {
      await i18n.loadTranslations({
        'fallbackLocale': 'en',
        'translations': {
          'en': {
            'greeting': 'Hello',
            'nested': {'deep': 'Found'},
          },
        },
      });
      i18n.setLocale('en');

      expect(i18n.hasKey('greeting'), isTrue);
      expect(i18n.hasKey('nested.deep'), isTrue);
      expect(i18n.hasKey('nested.missing'), isFalse);
      expect(i18n.hasKey('nothing'), isFalse);
    });

    test('the keys of the current locale are readable', () async {
      await i18n.loadTranslations({
        'fallbackLocale': 'en',
        'translations': {
          'en': {'greeting': 'Hello', 'farewell': 'Bye'},
        },
      });
      i18n.setLocale('en');

      expect(i18n.translationKeys, {'greeting', 'farewell'});

      i18n.setLocale('ko');
      expect(i18n.translationKeys, isEmpty,
          reason: 'a locale with no translations has no keys, rather than the '
              'previous locale\'s');
    });

    test('a missing key falls back to the fallback locale', () async {
      await i18n.loadTranslations({
        'fallbackLocale': 'en',
        'translations': {
          'en': {'greeting': 'Hello'},
          'ko': <String, dynamic>{},
        },
      });
      i18n.setLocale('ko');

      expect(i18n.translate('greeting'), 'Hello',
          reason: 'an untranslated string showing the key is worse than '
              'showing the original language');
    });

    test('parameters are interpolated', () async {
      await i18n.loadTranslations({
        'fallbackLocale': 'en',
        'translations': {
          'en': {'greeting': 'Hello {name}'},
        },
      });
      i18n.setLocale('en');

      expect(i18n.translate('greeting', params: {'name': 'Ada'}), 'Hello Ada');
    });
  });
}
