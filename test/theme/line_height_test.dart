import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// Line height under both names the 1.4 spec gives it — `lineHeight`
/// (05_Theme §5.4.2: below 16 a multiplier, 16 and up px) and the
/// `TextStyle` primitive's `height` (a multiplier) — in the theme and in a
/// widget `style`, through the application path a bundle actually takes.
void main() {
  Future<MCPUIRuntime> render(
    WidgetTester tester, {
    required Map<String, dynamic> typography,
    required Map<String, dynamic> content,
  }) async {
    final runtime = MCPUIRuntime();
    await runtime.initialize(
      {
        'type': 'application',
        'title': 'LineHeight',
        'version': '1.0.0',
        'initialRoute': '/',
        'theme': {'typography': typography},
        'routes': {'/': 'ui://pages/home'},
      },
      pageLoader: (uri) async => {'type': 'page', 'content': content},
    );
    await tester
        .pumpWidget(MaterialApp(home: Scaffold(body: runtime.buildUI())));
    await tester.pumpAndSettle();
    return runtime;
  }

  double? heightOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.height;

  group('theme typography', () {
    final cases = <String, (Map<String, dynamic>, double)>{
      'lineHeight px (≥16) divides by fontSize': (
        {'fontSize': 57, 'lineHeight': 64},
        64 / 57
      ),
      'lineHeight below 16 is a multiplier': (
        {'fontSize': 57, 'lineHeight': 1.5},
        1.5
      ),
      'height is a multiplier': ({'fontSize': 57, 'height': 1.123}, 1.123),
      'lineHeight wins over height': (
        {'fontSize': 32, 'lineHeight': 64, 'height': 3},
        2.0
      ),
    };
    cases.forEach((label, c) {
      testWidgets('variant — $label', (tester) async {
        final runtime = await render(tester,
            typography: {'displayLarge': c.$1},
            content: {'type': 'text', 'text': 'X', 'variant': 'displayLarge'});
        expect(heightOf(tester, 'X'), closeTo(c.$2, 1e-9));
        runtime.destroy();
      });

      testWidgets('binding style ≡ variant — $label', (tester) async {
        final runtime = await render(tester, typography: {
          'displayLarge': c.$1
        }, content: {
          'type': 'linear',
          'direction': 'vertical',
          'children': [
            {'type': 'text', 'text': 'V', 'variant': 'displayLarge'},
            {
              'type': 'text',
              'text': 'B',
              'style': '{{theme.typography.displayLarge}}'
            },
          ],
        });
        expect(heightOf(tester, 'B'), closeTo(c.$2, 1e-9));
        expect(heightOf(tester, 'B'), heightOf(tester, 'V'));
        runtime.destroy();
      });
    });

    test('both ThemeManager paths agree', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      final tm = ThemeManager();
      tm.setTheme({
        'typography': {
          'displayLarge': {'fontSize': 57, 'height': 1.123},
          'bodyLarge': {'fontSize': 16, 'lineHeight': 1.5},
        },
      });
      expect(tm.currentTheme.textTheme.displayLarge?.height, 1.123);
      expect(tm.getTextStyleValue('displayLarge')?.height, 1.123);
      expect(tm.currentTheme.textTheme.bodyLarge?.height, 1.5);
      expect(tm.getTextStyleValue('bodyLarge')?.height, 1.5);
      tm.reset();
    });
  });

  group('widget style', () {
    const theme = {
      'displayLarge': {'fontSize': 57, 'lineHeight': 64},
    };

    testWidgets('text style lineHeight px uses its own fontSize',
        (tester) async {
      final runtime = await render(tester, typography: theme, content: {
        'type': 'text',
        'text': 'X',
        'style': {'fontSize': 20, 'lineHeight': 30},
      });
      expect(heightOf(tester, 'X'), 1.5);
      runtime.destroy();
    });

    testWidgets('text style lineHeight px over a variant uses its size',
        (tester) async {
      final runtime = await render(tester, typography: theme, content: {
        'type': 'text',
        'text': 'X',
        'variant': 'displayLarge',
        'style': {'lineHeight': 114},
      });
      expect(heightOf(tester, 'X'), closeTo(114 / 57, 1e-9));
      runtime.destroy();
    });

    testWidgets('text style height stays a multiplier', (tester) async {
      final runtime = await render(tester, typography: theme, content: {
        'type': 'text',
        'text': 'X',
        'style': {'fontSize': 20, 'height': 1.25},
      });
      expect(heightOf(tester, 'X'), 1.25);
      runtime.destroy();
    });

    testWidgets('richText span style reads lineHeight', (tester) async {
      final runtime = await render(tester, typography: theme, content: {
        'type': 'richText',
        'spans': [
          {
            'text': 'S',
            'style': {'fontSize': 20, 'lineHeight': 40}
          },
        ],
      });
      final rich = tester.widget<RichText>(find.byType(RichText).first);
      final span = (rich.text as TextSpan).children!.first as TextSpan;
      expect(span.style?.height, 2.0);
      runtime.destroy();
    });

    testWidgets('textField style reads lineHeight', (tester) async {
      final runtime = await render(tester, typography: theme, content: {
        'type': 'textField',
        'label': 'L',
        'style': {'fontSize': 20, 'lineHeight': 1.4},
      });
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.style?.height, 1.4);
      runtime.destroy();
    });
  });

  testWidgets('a calculator display written with height fits its box',
      (tester) async {
    // The display that overflowed: a 140-high box with 16 padding holding a
    // displayLarge line and a headlineMedium line 4 apart — 104 of the 108
    // it has, once the theme's line heights apply.
    final runtime = await render(tester, typography: {
      'displayLarge': {'fontSize': 57, 'height': 1.123},
      'headlineMedium': {'fontSize': 28, 'height': 1.286},
    }, content: {
      'type': 'box',
      'height': 140,
      'padding': 16,
      'child': {
        'type': 'linear',
        'direction': 'vertical',
        'gap': 4,
        'children': [
          {'type': 'text', 'text': 'E', 'variant': 'displayLarge'},
          {'type': 'text', 'text': 'R', 'variant': 'headlineMedium'},
        ],
      },
    });
    expect(heightOf(tester, 'E'), 1.123);
    expect(heightOf(tester, 'R'), 1.286);
    expect(
        tester.getSize(find.text('E')).height +
            4 +
            tester.getSize(find.text('R')).height,
        lessThanOrEqualTo(108));
    expect(tester.takeException(), isNull);
    runtime.destroy();
  });
}
