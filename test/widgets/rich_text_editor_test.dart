// `richTextEditor` — the toolbar that edits the text.
//
// 43% covered: the field rendered and not one toolbar button had ever been
// pressed. Each button rewrites the document's own text, so a wrong pair of
// markers is content corruption rather than a layout problem, and the two
// formats (markdown and html) produce completely different output from the
// same button.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/widgets/advanced/rich_text_editor_factory.dart';
import 'package:flutter_test/flutter_test.dart';

const _allControls = [
  'bold',
  'italic',
  'underline',
  'code',
  'link',
  'heading',
  'bulletList',
  'orderedList',
  'quote',
];

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
        body: SingleChildScrollView(
          child: context.renderer.renderWidget(definition, context),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> editor({Map<String, dynamic> extra = const {}}) => {
        'type': 'richTextEditor',
        'binding': 'body',
        ...extra,
      };

  /// Types [text], selects all of it, and presses the toolbar button.
  Future<void> wrapAll(
    WidgetTester tester,
    String text,
    IconData icon,
  ) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    field.controller!.selection =
        TextSelection(baseOffset: 0, extentOffset: text.length);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(icon));
    await tester.pumpAndSettle();
  }

  String text() => stateManager.get<String>('body') ?? '';

  group('the field', () {
    testWidgets('typing writes through to the binding', (tester) async {
      await pump(tester, editor());

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pumpAndSettle();

      expect(text(), 'hello');
    });

    testWidgets('an existing value is loaded into the field', (tester) async {
      stateManager.set('body', 'already written');
      await pump(tester, editor());

      expect(find.text('already written'), findsOneWidget);
    });

    testWidgets('the placeholder and minimum height are honoured',
        (tester) async {
      await pump(tester, editor(extra: {
        'placeholder': 'Write something',
        'minHeight': 300,
      }));

      expect(find.text('Write something'), findsOneWidget);
      final box = tester.getSize(find.byType(TextField));
      expect(box.height, greaterThanOrEqualTo(300),
          reason: 'an editor that collapses to one line is unusable for the '
              'body of a document');
    });

    testWidgets('maxLength stops the text growing past it', (tester) async {
      await pump(tester, editor(extra: {'maxLength': 5}));

      await tester.enterText(find.byType(TextField), 'far too long');
      await tester.pumpAndSettle();

      expect(text().length, 5,
          reason: 'a limit enforced only on submit tells the user after they '
              'have written the whole thing');
    });

    testWidgets('a disabled editor takes no input and offers no toolbar',
        (tester) async {
      await pump(tester, editor(extra: {'enabled': false}));

      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(find.byType(IconButton), findsNothing,
          reason: 'buttons that cannot act on a disabled field are a menu of '
              'dead ends');
    });

    testWidgets('onChange fires with the text', (tester) async {
      await pump(tester, editor(extra: {
        'onChange': {
          'type': 'state',
          'action': 'set',
          'binding': 'seen',
          'value': '{{event.value}}',
        },
      }));

      await tester.enterText(find.byType(TextField), 'typed');
      await tester.pumpAndSettle();

      expect(stateManager.get('seen'), 'typed');
    });
  });

  group('the markdown toolbar', () {
    // The DEFAULT toolbar is a subset (bold, italic, link, bulletList,
    // heading), so a test that presses `code` or `quote` has to declare them —
    // pressing a button the document never asked for would be testing a
    // toolbar nobody gets.
    Map<String, dynamic> md({List<String>? toolbar}) => editor(extra: {
          'format': 'markdown',
          'toolbar': toolbar ?? _allControls,
        });

    testWidgets('bold and italic wrap the selection', (tester) async {
      await pump(tester, md());

      await wrapAll(tester, 'word', Icons.format_bold);
      expect(text(), '**word**');

      await wrapAll(tester, 'word', Icons.format_italic);
      expect(text(), '_word_');
    });

    testWidgets('code and link wrap it too', (tester) async {
      await pump(tester, md());

      await wrapAll(tester, 'x', Icons.code);
      expect(text(), '`x`');

      await wrapAll(tester, 'label', Icons.link);
      expect(text(), '[label](https://)',
          reason: 'the closing marker carries the url placeholder, or the '
              'author is left with a half-written link');
    });

    testWidgets('heading, lists and quote prefix the line rather than '
        'wrapping it', (tester) async {
      await pump(tester, md());

      await wrapAll(tester, 'Title', Icons.title);
      expect(text(), '## Title');

      await wrapAll(tester, 'item', Icons.format_list_bulleted);
      expect(text(), '- item');

      await wrapAll(tester, 'item', Icons.format_list_numbered);
      expect(text(), '1. item');

      await wrapAll(tester, 'said', Icons.format_quote);
      expect(text(), '> said',
          reason: 'a block marker wrapped around the text instead of prefixed '
              'to the line produces markdown that renders as literal symbols');
    });

    testWidgets('a prefix goes on the line the caret is in, not the first',
        (tester) async {
      await pump(tester, md());

      await tester.enterText(find.byType(TextField), 'first\nsecond');
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      field.controller!.selection = const TextSelection.collapsed(offset: 9);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.format_list_bulleted));
      await tester.pumpAndSettle();

      expect(text(), 'first\n- second');
    });

    testWidgets('with no selection the markers are inserted at the caret',
        (tester) async {
      await pump(tester, md());

      await tester.enterText(find.byType(TextField), 'ab');
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      field.controller!.selection = const TextSelection.collapsed(offset: 1);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.format_bold));
      await tester.pumpAndSettle();

      expect(text(), 'a****b');
      expect(field.controller!.selection.baseOffset, 3,
          reason: 'the caret lands between the markers so the next keystroke '
              'is inside the emphasis');
    });

    testWidgets('underline is not offered in markdown', (tester) async {
      await pump(tester, md(toolbar: ['bold', 'underline']));

      expect(find.byIcon(Icons.format_bold), findsOneWidget);
      expect(find.byIcon(Icons.format_underlined), findsNothing,
          reason: 'markdown has no underline — offering a button that writes '
              'raw html into a markdown document is worse than omitting it');
    });
  });

  group('the html toolbar', () {
    testWidgets('the same buttons write tags instead of markers',
        (tester) async {
      await pump(tester,
          editor(extra: {'format': 'html', 'toolbar': _allControls}));

      await wrapAll(tester, 'word', Icons.format_bold);
      expect(text(), '<strong>word</strong>');

      await wrapAll(tester, 'word', Icons.format_italic);
      expect(text(), '<em>word</em>');

      await wrapAll(tester, 'word', Icons.format_underlined);
      expect(text(), '<u>word</u>');

      await wrapAll(tester, 'Title', Icons.title);
      expect(text(), '<h2>Title</h2>',
          reason: 'in html a heading is a wrap, not a line prefix — the two '
              'formats share a button and not an implementation');
    });

    testWidgets('lists and quote wrap as elements', (tester) async {
      await pump(tester,
          editor(extra: {'format': 'html', 'toolbar': _allControls}));

      await wrapAll(tester, 'item', Icons.format_list_bulleted);
      expect(text(), '<ul><li>item</li></ul>');

      await wrapAll(tester, 'said', Icons.format_quote);
      expect(text(), '<blockquote>said</blockquote>');
    });
  });

  group('the declared toolbar', () {
    testWidgets('only the named controls are offered', (tester) async {
      await pump(tester, editor(extra: {
        'format': 'markdown',
        'toolbar': ['bold', 'quote'],
      }));

      expect(find.byIcon(Icons.format_bold), findsOneWidget);
      expect(find.byIcon(Icons.format_quote), findsOneWidget);
      expect(find.byIcon(Icons.format_italic), findsNothing,
          reason: '§10.27 — a control absent from the toolbar is absent as a '
              'shortcut too, or the toolbar lies about what the document may '
              'contain');
      expect(find.byIcon(Icons.link), findsNothing);
    });

    testWidgets('an empty toolbar leaves the field alone', (tester) async {
      await pump(tester, editor(extra: {'toolbar': <String>[]}));

      expect(find.byType(IconButton), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('a toolbar naming something unknown is ignored, not fatal',
        (tester) async {
      await pump(tester, editor(extra: {
        'toolbar': ['bold', 'telepathy'],
      }));

      expect(find.byIcon(Icons.format_bold), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every button carries a tooltip', (tester) async {
      await pump(tester,
          editor(extra: {'format': 'markdown', 'toolbar': _allControls}));

      final tooltips = tester
          .widgetList<Tooltip>(find.byType(Tooltip))
          .map((t) => t.message)
          .toList();
      expect(tooltips, contains('Bold'));
      expect(tooltips, contains('Quote'),
          reason: 'an icon-only toolbar with no tooltips is unreadable to a '
              'screen reader and to anyone unsure what the glyph means');
    });
  });
  // What the editor writes out is what the next screen renders and what the
  // server stores. §10.27/§7.5 admit a small set of tags and nothing else, so
  // the filter is the whole of the safety here — and a link is the one place
  // a destination survives, which is exactly where a script URL would ride in.
  group('what the editor writes out', () {
    test('the admitted tags survive', () {
      expect(sanitizeRichText('<p>a <strong>b</strong> <em>c</em></p>'),
          '<p>a <strong>b</strong> <em>c</em></p>');
      expect(sanitizeRichText('<ul><li>one</li></ul>'),
          '<ul><li>one</li></ul>');
    });

    test('anything outside the set is stripped, and its text kept', () {
      expect(sanitizeRichText('<script>alert(1)</script>hello'),
          'alert(1)hello',
          reason: 'stripped rather than escaped: escaping renders the markup '
              'as visible text, which reads as corruption and still carries '
              'the payload to the next consumer');
      expect(sanitizeRichText('<div class="x">body</div>'), 'body');
    });

    test('a link keeps its destination', () {
      expect(sanitizeRichText('<a href="https://example.com">go</a>'),
          '<a href="https://example.com">go</a>',
          reason: 'dropping the href leaves a link that goes nowhere, which '
              'is worse than no link at all');
    });

    test('an image keeps its source under the right attribute', () {
      expect(sanitizeRichText('<img src="https://example.com/a.png">'),
          '<img src="https://example.com/a.png">');
    });

    test('a script destination is dropped, and the element kept', () {
      for (final hostile in const [
        'javascript:alert(1)',
        'JavaScript:alert(1)',
        'vbscript:msgbox',
        'file:///etc/passwd',
      ]) {
        expect(sanitizeRichText('<a href="$hostile">go</a>'), '<a>go</a>',
            reason: '$hostile is not a destination; keeping it would carry an '
                'executable URL into whatever renders this next');
      }
    });

    test('attributes other than the destination are dropped', () {
      expect(sanitizeRichText('<a href="https://x.test" onclick="bad()">g</a>'),
          '<a href="https://x.test">g</a>',
          reason: 'an event handler that survives the editor is a handler '
              'nobody wrote into the document');
    });

    test('an unterminated tag drops the remainder rather than guessing', () {
      expect(sanitizeRichText('safe <a href="'), 'safe ');
    });

    test('markdown is filtered by the same rule', () {
      expect(sanitizeRichText('**bold** <script>x</script>', markdown: true),
          '**bold** x',
          reason: 'markdown carries no tags of its own, so the risk is inline '
              'HTML — the same filter has to apply');
    });
  });

  group('the editor loads what it is given', () {
    testWidgets('a literal value is loaded when no binding is declared',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'richTextEditor',
        'value': 'from the document',
      });

      expect(find.text('from the document'), findsOneWidget,
          reason: 'a preview pane with no binding still has to show what the '
              'document handed it');
    });
  });
}
