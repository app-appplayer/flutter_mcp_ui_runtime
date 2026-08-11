// `text` — the typography properties, and the drop cap.
//
// The transform, the weight vocabulary and the scale factor are the properties
// an author reaches for when the default does not fit, and each of them is a
// separate arm nobody had run. The drop cap is a whole layout of its own: it
// measures the cap, indents the first lines around it, and continues below —
// and every one of those steps was uncovered.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StateManager stateManager;
  late RenderContext context;

  setUp(() {
    stateManager = StateManager()..initialize(<String, dynamic>{});
    final registry = WidgetRegistry();
    DefaultWidgets.registerAll(registry);
    final bindingEngine = BindingEngine();
    final actionHandler = ActionHandler();
    context = RenderContext(
      renderer: Renderer(
        widgetRegistry: registry,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        stateManager: stateManager,
      ),
      stateManager: stateManager,
      bindingEngine: bindingEngine,
      actionHandler: actionHandler,
      themeManager: ThemeManager.instance,
    );
  });

  Future<void> pump(WidgetTester tester, Map<String, dynamic> definition) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          child: AnimatedBuilder(
            animation: stateManager,
            builder: (_, __) =>
                context.renderer.renderWidget(definition, context),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Text textWidget(WidgetTester tester) =>
      tester.widget<Text>(find.byType(Text).first);

  group('textTransform', () {
    testWidgets('uppercase, lowercase and capitalize each change the string',
        (tester) async {
      await pump(tester, {
        'type': 'text',
        'content': 'ada lovelace',
        'textTransform': 'uppercase',
      });
      expect(find.text('ADA LOVELACE'), findsOneWidget);

      await pump(tester, {
        'type': 'text',
        'content': 'ADA',
        'textTransform': 'lowercase',
      });
      expect(find.text('ada'), findsOneWidget);

      await pump(tester, {
        'type': 'text',
        'content': 'ada lovelace',
        'textTransform': 'capitalize',
      });
      expect(find.text('Ada lovelace'), findsOneWidget,
          reason: 'capitalize is the first letter, not title case — a '
              'transform that title-cases a sentence rewrites names in it');
    });

    testWidgets('capitalize on empty text is not a crash', (tester) async {
      await pump(tester, {
        'type': 'text',
        'content': '',
        'textTransform': 'capitalize',
      });

      expect(tester.takeException(), isNull);
    });

    testWidgets('an unknown transform leaves the text alone', (tester) async {
      await pump(tester, {
        'type': 'text',
        'content': 'ada',
        'textTransform': 'reverse',
      });

      expect(find.text('ada'), findsOneWidget);
    });

    testWidgets('the transform applies to a bound value too', (tester) async {
      stateManager.set('name', 'ada');
      await pump(tester, {
        'type': 'text',
        'content': '{{name}}',
        'textTransform': 'uppercase',
      });

      expect(find.text('ADA'), findsOneWidget);
    });
  });

  group('font weight', () {
    testWidgets('every named weight is read', (tester) async {
      for (final entry in const {
        'w700': FontWeight.w700,
        'extraBold': FontWeight.w800,
        'w800': FontWeight.w800,
        'black': FontWeight.w900,
        'w900': FontWeight.w900,
      }.entries) {
        await pump(tester, {
          'type': 'text',
          'content': 'weighted',
          'style': {'fontWeight': entry.key},
        });

        expect(textWidget(tester).style!.fontWeight, entry.value,
            reason: 'fontWeight "${entry.key}"');
      }
    });

    testWidgets('a numeric weight is read, as a number or a string',
        (tester) async {
      await pump(tester, {
        'type': 'text',
        'content': 'weighted',
        'style': {'fontWeight': 600},
      });
      expect(textWidget(tester).style!.fontWeight, FontWeight.w600);

      await pump(tester, {
        'type': 'text',
        'content': 'weighted',
        'style': {'fontWeight': '600'},
      });
      expect(textWidget(tester).style!.fontWeight, FontWeight.w600,
          reason: 'a weight carried through JSON as a string is still the '
              'weight the author wrote');
    });

    testWidgets('a weight off the scale is ignored rather than clamped',
        (tester) async {
      await pump(tester, {
        'type': 'text',
        'content': 'weighted',
        'style': {'fontWeight': 650},
      });
      expect(textWidget(tester).style?.fontWeight, isNull);

      await pump(tester, {
        'type': 'text',
        'content': 'weighted',
        'style': {'fontWeight': 1200},
      });
      expect(textWidget(tester).style?.fontWeight, isNull,
          reason: 'silently rounding to the nearest weight would make a typo '
              'look deliberate');
    });
  });

  group('layout properties', () {
    testWidgets('textScaleFactor scales the text', (tester) async {
      await pump(tester, {
        'type': 'text',
        'content': 'scaled',
        'textScaleFactor': 2.0,
      });

      expect(textWidget(tester).textScaler, TextScaler.linear(2.0));
    });

    testWidgets('with no scale factor the ambient scaler is used',
        (tester) async {
      await pump(tester, {'type': 'text', 'content': 'plain'});

      expect(textWidget(tester).textScaler, isNull,
          reason: 'pinning a scaler the document did not ask for would ignore '
              'the reader\'s own text-size setting');
    });

    testWidgets('maxLines, softWrap, overflow and direction are read',
        (tester) async {
      await pump(tester, {
        'type': 'text',
        'content': 'a long line of text',
        'maxLines': 2,
        'softWrap': false,
        'overflow': 'ellipsis',
        'textDirection': 'rtl',
      });

      final text = textWidget(tester);
      expect(text.maxLines, 2);
      expect(text.softWrap, isFalse);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(text.textDirection, TextDirection.rtl);
    });

    testWidgets('a semantics label is carried, under either spelling',
        (tester) async {
      await pump(tester, {
        'type': 'text',
        'content': '42°',
        'semanticsLabel': '42 degrees',
      });
      expect(textWidget(tester).semanticsLabel, '42 degrees');

      await pump(tester, {
        'type': 'text',
        'content': '42°',
        'ariaLabel': '42 degrees',
      });
      expect(textWidget(tester).semanticsLabel, '42 degrees',
          reason: '§13 — the symbol on screen is not what a screen reader '
              'should say');
    });
  });

  group('a drop cap', () {
    testWidgets('sets the first letter apart and keeps the rest of the text',
        (tester) async {
      await pump(tester, {
        'type': 'text',
        'content': 'Once upon a time there was a runtime that drew what it '
            'was given, and said so when it could not.',
        'dropCap': {'lines': 3},
      });

      // The cap is its own Text, larger than the body.
      final texts = tester.widgetList<Text>(find.byType(Text)).toList();
      expect(texts.length, greaterThanOrEqualTo(2),
          reason: 'the cap and the indented body are separate runs');
      expect(find.text('O'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a declared glyph replaces the first letter', (tester) async {
      await pump(tester, {
        'type': 'text',
        'content': 'Once upon a time, in a runtime far away, a document was '
            'rendered exactly as written.',
        'dropCap': {'glyph': '❦', 'lines': 2},
      });

      expect(find.text('❦'), findsOneWidget);
    });

    testWidgets('a declared cap style is applied', (tester) async {
      await pump(tester, {
        'type': 'text',
        'content': 'Once upon a time there was a runtime.',
        'dropCap': {
          'lines': 2,
          'style': {'color': '#FF0000'},
        },
      });

      final cap = tester.widgetList<Text>(find.byType(Text))
          .firstWhere((t) => t.data == 'O');
      expect(cap.style!.color, const Color(0xFFFF0000));
    });

    testWidgets('short text still renders with a cap', (tester) async {
      await pump(tester, {
        'type': 'text',
        'content': 'Ok',
        'dropCap': {'lines': 3},
      });

      expect(find.text('O'), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: 'text shorter than the cap is the shape a heading takes '
              'while it is being typed');
    });

    testWidgets('empty text with a drop cap is not a crash', (tester) async {
      await pump(tester, {
        'type': 'text',
        'content': '',
        'dropCap': {'lines': 3},
      });

      expect(tester.takeException(), isNull);
    });

    testWidgets('an unbounded width falls back to the screen width',
        (tester) async {
      // A drop cap inside a horizontal scroller has no bounded width to
      // measure against; measuring against zero would put every glyph on its
      // own line.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: context.renderer.renderWidget({
              'type': 'text',
              'content': 'Once upon a time there was a runtime.',
              'dropCap': {'lines': 2},
            }, context),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('O'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
