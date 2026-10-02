// An application's `i18n` block (§12) read the way a player meets it: the
// document is initialised, a page is loaded, and the text on screen is read.
//
// Before this file, no released version loaded the block at all. Every part
// existed — the manager, the `{{i18n.*}}` path lookup, a loader — and every
// part had unit tests that filled the manager by hand, so they passed while a
// served document showed `intro` · `contactLabel` · `send` where its
// sentences should have been. Measured on 0.8.3 before the fix:
// `{{i18n.greeting}}` → `greeting`, `{{i18n.greeting:ko-KR}}` → empty,
// `{{i18n.itemCount({count: 5})}}` → the binding text itself,
// `{{i18n.missing}}` → `missing`.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/i18n/i18n_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/mcp_ui_runtime.dart';
import 'package:flutter_mcp_ui_runtime/src/utils/mcp_logger.dart';
import 'package:flutter_test/flutter_test.dart';

const Map<String, dynamic> _i18n = {
  'defaultLocale': 'en-US',
  'locales': ['en-US', 'ko-KR', 'ar-SA'],
  'text': {
    'en-US': {'greeting': 'Hello', 'farewell': 'Goodbye'},
    'ko-KR': {'greeting': '안녕하세요'},
    'ar-SA': {'greeting': 'مرحبا'},
  },
  'pluralization': {
    'en-US': {
      'itemCount': {
        'zero': 'No items',
        'one': '1 item',
        'other': '{count} items',
      },
    },
    'ko-KR': {
      'itemCount': {'other': '{count}개 항목'},
    },
  },
  'numberFormat': {
    'en-US': {
      'currency': {'style': 'currency', 'currency': 'USD'},
      'percent': {'style': 'percent', 'maximumFractionDigits': 1},
    },
    'ko-KR': {
      'currency': {'style': 'currency', 'currency': 'KRW'},
    },
  },
  'dateFormat': {
    'en-US': {
      'shortDate': {'year': 'numeric', 'month': '2-digit', 'day': '2-digit'},
      'isoDay': 'yyyy-MM-dd',
    },
  },
};

void main() {
  late MCPUIRuntime runtime;

  setUp(() => runtime = MCPUIRuntime(enableDebugMode: false));
  tearDown(() => runtime.dispose());

  Future<void> mount(
    WidgetTester tester,
    List<String> lines, {
    List<Locale> hostLocales = const [Locale('en', 'US')],
    Map<String, dynamic>? i18n = _i18n,
    Map<String, dynamic> state = const {},
  }) async {
    tester.platformDispatcher.localesTestValue = hostLocales;
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await runtime.initialize({
      'type': 'application',
      'title': 'Shop',
      'version': '1.0.0',
      'initialRoute': '/home',
      'routes': {'/home': 'home'},
      if (i18n != null) 'i18n': i18n,
      if (state.isNotEmpty) 'state': {'initial': state},
    },
        pageLoader: (route) async => {
              'type': 'page',
              'content': {
                'type': 'linear',
                'direction': 'vertical',
                'children': [
                  for (final line in lines) {'type': 'text', 'content': line},
                ],
              },
            });
    await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  group('the first locale (§12.6)', () {
    testWidgets(
        'is defaultLocale when the host language is not in the '
        'document', (tester) async {
      await mount(tester, ['{{i18n.greeting}}'],
          hostLocales: const [Locale('fr', 'FR')]);
      expect(find.text('Hello'), findsOneWidget);
      expect(runtime.locale, 'en-US');
    });

    testWidgets('is the host language when the document carries it',
        (tester) async {
      await mount(tester, ['{{i18n.greeting}}'],
          hostLocales: const [Locale('ko', 'KR')]);
      expect(find.text('안녕하세요'), findsOneWidget);
    });

    testWidgets('matches on language when the region differs', (tester) async {
      await mount(tester, ['{{i18n.greeting}}'],
          hostLocales: const [Locale('ko')]);
      expect(find.text('안녕하세요'), findsOneWidget);
      expect(runtime.locale, 'ko-KR');
    });
  });

  group('fallback (§12.7)', () {
    testWidgets('a key the active locale lacks reads the default locale',
        (tester) async {
      await mount(tester, ['{{i18n.farewell}}'],
          hostLocales: const [Locale('ko', 'KR')]);
      expect(find.text('Goodbye'), findsOneWidget);
    });

    testWidgets('a key missing everywhere shows a marker and warns once',
        (tester) async {
      final warnings = <String>[];
      MCPLogger.onRecord = (record) {
        if (record.level == 'WARN' && record.message.contains('missing')) {
          warnings.add(record.message);
        }
      };
      addTearDown(() => MCPLogger.onRecord = null);

      await mount(tester, ['{{i18n.missing}}', 'again {{i18n.missing}}']);
      expect(find.text('!!missing'), findsOneWidget);
      expect(find.text('again !!missing'), findsOneWidget);
      expect(warnings, hasLength(1));
    });
  });

  testWidgets('the explicit-locale form reads that locale (§12.2.3)',
      (tester) async {
    await mount(
        tester, ['{{i18n.greeting:ko-KR}}', 'x {{i18n.greeting:ko-KR}}']);
    expect(find.text('안녕하세요'), findsOneWidget);
    expect(find.text('x 안녕하세요'), findsOneWidget);
  });

  group('pluralization (§12.3)', () {
    testWidgets('selects the form by count, inside a sentence too',
        (tester) async {
      await mount(tester, [
        '{{i18n.itemCount({count: 0})}}',
        '{{i18n.itemCount({count: 1})}}',
        'Cart: {{i18n.itemCount({count: 1234})}}',
        '{{i18n.itemCount({count: cart.count})}}',
      ], state: {
        'cart': {'count': 5},
      });
      expect(find.text('No items'), findsOneWidget);
      expect(find.text('1 item'), findsOneWidget);
      expect(find.text('Cart: 1,234 items'), findsOneWidget);
      expect(find.text('5 items'), findsOneWidget);
    });

    testWidgets('a locale with one category uses `other`', (tester) async {
      await mount(tester, ['{{i18n.itemCount({count: 1})}}'],
          hostLocales: const [Locale('ko', 'KR')]);
      expect(find.text('1개 항목'), findsOneWidget);
    });
  });

  group('number and date formats (§12.4, §12.5)', () {
    testWidgets('format for the active locale', (tester) async {
      await mount(tester, [
        '{{i18n.currency(price)}}',
        '{{i18n.percent(ratio)}}',
        '{{i18n.shortDate(day)}}',
        '{{i18n.isoDay(day)}}',
      ], state: {
        'price': 1234.5,
        'ratio': 0.256,
        'day': '2026-10-02',
      });
      expect(find.text('\$1,234.50'), findsOneWidget);
      expect(find.text('25.6%'), findsOneWidget);
      expect(find.text('10/02/2026'), findsOneWidget);
      expect(find.text('2026-10-02'), findsOneWidget);
    });

    testWidgets('a locale with its own descriptor uses it', (tester) async {
      await mount(tester, ['{{i18n.currency(price)}}'],
          hostLocales: const [Locale('ko', 'KR')], state: {'price': 1234.5});
      expect(find.text('₩1,235'), findsOneWidget);
    });
  });

  testWidgets('switching the locale redraws every binding (§12.6)',
      (tester) async {
    await mount(
        tester, ['{{i18n.greeting}}', '{{i18n.itemCount({count: 3})}}']);
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('3 items'), findsOneWidget);

    runtime.setLocale('ko-KR');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(runtime.locale, 'ko-KR');
    expect(find.text('안녕하세요'), findsOneWidget);
    expect(find.text('3개 항목'), findsOneWidget);
  });

  group('direction (§12.8)', () {
    testWidgets('an RTL locale lays the page out right to left',
        (tester) async {
      await mount(tester, ['{{i18n.greeting}}'],
          hostLocales: const [Locale('ar', 'SA')]);
      expect(find.text('مرحبا'), findsOneWidget);
      expect(Directionality.of(tester.element(find.text('مرحبا'))),
          TextDirection.rtl);
    });

    testWidgets("the document's textDirection overrides the script",
        (tester) async {
      await mount(tester, [
        '{{i18n.greeting}}'
      ], hostLocales: const [
        Locale('ar', 'SA')
      ], i18n: {
        ..._i18n,
        'textDirection': {'ar-SA': 'ltr'},
      });
      expect(Directionality.of(tester.element(find.text('مرحبا'))),
          TextDirection.ltr);
    });

    testWidgets('a document without i18n keeps its host direction',
        (tester) async {
      await mount(tester, ['plain'],
          hostLocales: const [Locale('ar', 'SA')], i18n: null);
      expect(Directionality.of(tester.element(find.text('plain'))),
          TextDirection.ltr);
    });
  });

  test('each manager holds its own document', () async {
    final first = I18nManager.scoped();
    final second = I18nManager.scoped();
    await first.loadDefinition({
      'defaultLocale': 'en',
      'text': {
        'en': {'title': 'First'},
      },
    });
    await second.loadDefinition({
      'defaultLocale': 'en',
      'text': {
        'en': {'title': 'Second'},
      },
    });
    second.setLocale('ko');

    expect(first.translate('title'), 'First');
    expect(second.translate('title'), 'Second');
    expect(first.currentLocale, 'en');
    expect(identical(first, I18nManager.instance), isFalse);
  });
}
