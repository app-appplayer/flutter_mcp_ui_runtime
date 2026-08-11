// `markdown` — the block boundaries.
//
// Each block kind has the same job at its start: flush whatever paragraph text
// was accumulating before it. A boundary that forgets to flush swallows the
// sentence before the heading, and the document reads as though the author
// never wrote it.

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

  Future<void> render(WidgetTester tester, String markdown) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: context.renderer.renderWidget(<String, dynamic>{
            'type': 'markdown',
            'content': markdown,
          }, context),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Every block kind, each preceded by a sentence that must survive it.
  group('a paragraph is flushed before every block', () {
    testWidgets('before a heading', (tester) async {
      await render(tester, 'before the heading\n# Heading');

      expect(find.textContaining('before the heading', findRichText: true), findsOneWidget,
          reason: 'the sentence the author wrote above a heading is not part '
              'of the heading, and it must not be swallowed by it');
      expect(find.textContaining('Heading', findRichText: true), findsWidgets);
    });

    testWidgets('before a horizontal rule', (tester) async {
      await render(tester, 'before the rule\n---');

      expect(find.textContaining('before the rule', findRichText: true), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('before a list item', (tester) async {
      await render(tester, 'before the list\n- first\n- second');

      expect(find.textContaining('before the list', findRichText: true), findsOneWidget);
      expect(find.textContaining('first', findRichText: true), findsWidgets);
    });

    testWidgets('before a numbered list item', (tester) async {
      await render(tester, 'before the list\n1. first');

      expect(find.textContaining('before the list', findRichText: true), findsOneWidget);
      expect(find.textContaining('first', findRichText: true), findsWidgets);
    });

    testWidgets('before a blockquote', (tester) async {
      await render(tester, 'before the quote\n> quoted');

      expect(find.textContaining('before the quote', findRichText: true), findsOneWidget);
      expect(find.textContaining('quoted', findRichText: true), findsWidgets);
    });

    testWidgets('before a fenced code block', (tester) async {
      await render(tester, 'before the code\n```dart\nvoid main() {}\n```');

      expect(find.textContaining('before the code', findRichText: true), findsOneWidget);
      expect(find.textContaining('void main() {}', findRichText: true), findsWidgets,
          reason: 'the fence is what tells the reader this is code; losing '
              'the body loses the point of the block');
    });

    testWidgets('an empty line ends the paragraph', (tester) async {
      await render(tester, 'first paragraph\n\nsecond paragraph');

      expect(find.textContaining('first paragraph', findRichText: true), findsOneWidget);
      expect(find.textContaining('second paragraph', findRichText: true), findsOneWidget);
    });
  });

  group('inline spans', () {
    testWidgets('plain text with no markers is still rendered',
        (tester) async {
      await render(tester, 'just a sentence with no markers at all');

      expect(find.textContaining('just a sentence', findRichText: true), findsOneWidget,
          reason: 'the fallback span is the common case — most lines carry no '
              'emphasis at all');
    });

    testWidgets('bold and italic runs are kept alongside plain text',
        (tester) async {
      await render(tester, 'plain **bold** and *italic* together');

      expect(find.byType(RichText), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('a fenced block with no language', () {
    testWidgets('still renders its body', (tester) async {
      await render(tester, '```\nplain code\n```');

      expect(find.textContaining('plain code', findRichText: true), findsWidgets);
    });
  });
}
