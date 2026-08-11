// `markdown` — the widget a document uses when its content is prose.
//
// The parser was 78% covered by tests that rendered a paragraph. What was not
// covered is every block that is not a paragraph — headings, fenced code,
// lists, rules, quotes — and every inline form, including the link, which is
// the only part of this widget a user can interact with.
//
// The tests read the built tree rather than the string: a parser that drops a
// heading still leaves a Markdown widget on screen, and the text of the
// heading is often still there as body text, so "the words are present" proves
// nothing. What proves it is the style the words are carrying.

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
        body: AnimatedBuilder(
          animation: stateManager,
          builder: (_, __) => context.renderer.renderWidget(definition, context),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> md(WidgetTester tester, String text,
          {Map<String, dynamic> extra = const {}}) =>
      pump(tester, {'type': 'markdown', 'text': text, ...extra});

  /// Every inline span the tree carries, flattened.
  List<TextSpan> spans(WidgetTester tester) {
    final out = <TextSpan>[];
    void walk(InlineSpan span) {
      if (span is TextSpan) {
        out.add(span);
        for (final child in span.children ?? const <InlineSpan>[]) {
          walk(child);
        }
      }
    }

    for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
      walk(rich.text);
    }
    return out;
  }

  TextSpan spanFor(WidgetTester tester, String text) =>
      spans(tester).firstWhere((s) => s.text == text,
          orElse: () => throw StateError(
              'no span carries "$text"; spans were '
              '${spans(tester).map((s) => s.text).toList()}'));

  group('the content itself', () {
    testWidgets('`text` is the canonical key', (tester) async {
      await md(tester, 'plain prose');
      expect(find.textContaining('plain prose', findRichText: true),
          findsOneWidget);
    });

    testWidgets('`content` is still accepted (§18.2.10)', (tester) async {
      await pump(tester, {'type': 'markdown', 'content': 'legacy prose'});
      expect(find.textContaining('legacy prose', findRichText: true),
          findsOneWidget);
    });

    testWidgets('the text is resolved from state', (tester) async {
      stateManager.set('article', 'from the server');
      await md(tester, '{{article}}');
      expect(find.textContaining('from the server', findRichText: true),
          findsOneWidget);
    });

    testWidgets('empty content is an empty widget, not a failure',
        (tester) async {
      await pump(tester, {'type': 'markdown'});
      expect(tester.takeException(), isNull);
    });
  });

  group('block elements', () {
    testWidgets('a heading is larger and bolder than the prose below it',
        (tester) async {
      await md(tester, '# The title\n\nthe body');

      final title = spanFor(tester, 'The title');
      expect(title.style!.fontWeight, FontWeight.bold);
      expect(title.style!.fontSize, 24,
          reason: 'a heading that renders as body text is a document without '
              'structure — and the words are still all there, which is why '
              'this has to be checked as style');
    });

    testWidgets('each heading level gets its own size', (tester) async {
      await md(tester, '# one\n## two\n### three\n#### four\n##### five\n###### six');

      final sizes = [
        for (final t in ['one', 'two', 'three', 'four', 'five', 'six'])
          spanFor(tester, t).style!.fontSize,
      ];
      expect(sizes, [24.0, 22.0, 20.0, 18.0, 16.0, 14.0]);
    });

    testWidgets('more than six hashes still renders as the smallest heading',
        (tester) async {
      await md(tester, '####### too deep');

      expect(spanFor(tester, 'too deep').style!.fontSize, 14.0,
          reason: 'clamping beats an index out of range on the size table');
    });

    testWidgets('a fenced code block keeps its lines and its font',
        (tester) async {
      await md(tester, 'before\n\n```dart\nvoid main() {\n  run();\n}\n```\n\nafter');

      final code = tester.widget<Text>(
          find.text('void main() {\n  run();\n}'));
      expect(code.style!.fontFamily, 'monospace',
          reason: 'code reflowed as prose is code the reader cannot copy');
      expect(find.textContaining('before', findRichText: true), findsOneWidget);
      expect(find.textContaining('after', findRichText: true), findsOneWidget);
    });

    testWidgets('an unclosed code block still renders what it holds',
        (tester) async {
      await md(tester, '```\nnever closed');

      expect(find.text('never closed'), findsOneWidget,
          reason: 'a truncated document — a stream cut short — must not lose '
              'its last block entirely');
    });

    testWidgets('a bulleted list gets bullets and its text', (tester) async {
      await md(tester, '- first\n- second\n* third\n+ fourth');

      expect(find.text('•'), findsNWidgets(4));
      for (final t in ['first', 'second', 'third', 'fourth']) {
        expect(spanFor(tester, t).text, t);
      }
    });

    testWidgets('a numbered list keeps its own numbers', (tester) async {
      await md(tester, '1. first\n2. second\n7. seventh');

      expect(find.text('1.'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);
      expect(find.text('7.'), findsOneWidget,
          reason: 'renumbering from 1 rewrites a document that deliberately '
              'starts elsewhere');
    });

    testWidgets('a horizontal rule becomes a divider', (tester) async {
      await md(tester, 'above\n\n---\n\nbelow');
      expect(find.byType(Divider), findsOneWidget);

      await md(tester, 'above\n\n***\n\nbelow');
      expect(find.byType(Divider), findsOneWidget);

      await md(tester, 'above\n\n___\n\nbelow');
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('a blockquote is italic', (tester) async {
      await md(tester, '> quoted words');

      expect(spanFor(tester, 'quoted words').style!.fontStyle,
          FontStyle.italic);
    });

    testWidgets('consecutive lines join into one paragraph', (tester) async {
      await md(tester, 'one line\nand another\n\na second paragraph');

      expect(spanFor(tester, 'one line and another').text,
          'one line and another',
          reason: 'a hard break per source line is not what markdown means');
    });
  });

  group('inline styles', () {
    testWidgets('bold, both spellings', (tester) async {
      await md(tester, 'a **strong** and an __also strong__ word');

      expect(spanFor(tester, 'strong').style!.fontWeight, FontWeight.bold);
      expect(spanFor(tester, 'also strong').style!.fontWeight, FontWeight.bold);
    });

    testWidgets('italic, both spellings', (tester) async {
      await md(tester, 'an *emphasis* and an _also emphasis_ word');

      expect(spanFor(tester, 'emphasis').style!.fontStyle, FontStyle.italic);
      expect(spanFor(tester, 'also emphasis').style!.fontStyle,
          FontStyle.italic);
    });

    testWidgets('inline code carries the code background', (tester) async {
      await md(tester, 'call `runMe()` first',
          extra: {'codeBackgroundColor': '#FF0000'});

      final code = spanFor(tester, 'runMe()');
      expect(code.style!.fontFamily, 'monospace');
      expect(code.style!.backgroundColor, const Color(0xFFFF0000));
    });

    testWidgets('the text around a match is kept', (tester) async {
      await md(tester, 'before **bold** after');

      final texts = spans(tester).map((s) => s.text).toList();
      expect(texts, containsAll(<String>['before ', 'bold', ' after']),
          reason: 'a parser that keeps only the matches deletes the sentence '
              'around them');
    });
  });

  group('links', () {
    testWidgets('a link is drawn in the link colour and underlined',
        (tester) async {
      await md(tester, 'see [the docs](https://example.test) for more',
          extra: {'linkColor': '#00FF00'});

      final link = tester.widget<Text>(find.text('the docs'));
      expect(link.style!.color, const Color(0xFF00FF00));
      expect(link.style!.decoration, TextDecoration.underline,
          reason: 'a link that looks like prose is a link nobody taps');
    });

    testWidgets('tapping one reports the url through `event.url`',
        (tester) async {
      await md(tester, 'see [the docs](https://example.test)', extra: {
        'onLinkTap': {
          'type': 'state',
          'action': 'set',
          'binding': 'opened',
          'value': '{{event.url}}',
        },
      });

      await tester.tap(find.text('the docs'));
      await tester.pumpAndSettle();

      expect(stateManager.get('opened'), 'https://example.test',
          reason: 'the runtime does not open URLs itself — handing the '
              'document the url is the entire contract');
    });

    testWidgets('a link with no handler is inert rather than fatal',
        (tester) async {
      await md(tester, 'see [the docs](https://example.test)');

      await tester.tap(find.text('the docs'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('presentation', () {
    testWidgets('selectable prose can be selected', (tester) async {
      await md(tester, 'selectable prose', extra: {'selectable': true});

      expect(
          find.descendant(
            of: find.byType(SelectableText),
            matching: find.textContaining('selectable prose', findRichText: true),
          ),
          findsOneWidget);
    });

    testWidgets('a selectable code block is a SelectableText', (tester) async {
      await md(tester, '```\ncopy me\n```', extra: {'selectable': true});

      expect(
          find.descendant(
            of: find.byType(SelectableText),
            matching: find.text('copy me'),
          ),
          findsOneWidget,
          reason: 'code the reader cannot select is code they have to retype');
    });

    testWidgets('textColor and fontSize reach the prose', (tester) async {
      await md(tester, 'coloured prose',
          extra: {'textColor': '#123456', 'fontSize': 21});

      final span = spanFor(tester, 'coloured prose');
      expect(span.style!.color, const Color(0xFF123456));
      expect(span.style!.fontSize, 21);
    });

    testWidgets('with no textColor the prose takes the ambient theme colour',
        (tester) async {
      // Written history: RichText does not inherit DefaultTextStyle, so an
      // uncoloured span painted with no colour at all — white on white in a
      // card.
      await md(tester, 'inheriting prose');

      expect(spanFor(tester, 'inheriting prose').style!.color, isNotNull,
          reason: 'an uncoloured span is invisible on exactly the surfaces '
              'where it matters');
    });

    testWidgets('width and height constrain the box', (tester) async {
      await md(tester, 'sized prose', extra: {'width': 200, 'height': 100});

      final box = tester.getSize(find.byType(SizedBox).first);
      expect(box.width, 200);
      expect(box.height, 100);
    });

    testWidgets('a backgroundColor is painted', (tester) async {
      await md(tester, 'prose', extra: {'backgroundColor': '#FF00FF'});

      final container = tester.widgetList<Container>(find.byType(Container))
          .firstWhere((c) => c.decoration is BoxDecoration &&
              (c.decoration! as BoxDecoration).color == const Color(0xFFFF00FF));
      expect(container, isNotNull);
    });
  });
}
