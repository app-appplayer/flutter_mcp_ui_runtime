// `table`'s per-column sizing and row decoration, `richText`'s nested spans,
// and `image`'s fallback chain.
//
// All three are properties a document declares once and then trusts: a column
// width, a bold run inside a sentence, a stand-in when a picture will not
// load. Each of them fails by rendering something plausible — an evenly
// divided table, an unstyled sentence, an empty box — so nothing on screen
// says the declaration was dropped.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_mcp_ui_runtime/src/assets/asset_resolver.dart';
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

  Future<void> pump(WidgetTester tester, Map<String, dynamic> definition,
      {double width = 400}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: context.renderer.renderWidget(definition, context),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> cell(String content) =>
      <String, dynamic>{'type': 'text', 'content': content};

  group('table', () {
    Map<String, dynamic> table({Map<String, dynamic> extra = const {}}) =>
        <String, dynamic>{
          'type': 'table',
          'rows': <dynamic>[
            <String, dynamic>{
              'cells': <dynamic>[cell('a1'), cell('b1')],
              ...(extra['rowExtra'] as Map<String, dynamic>? ?? const {}),
            },
          ],
          ...extra..remove('rowExtra'),
        };

    testWidgets('a numeric column width is honoured', (tester) async {
      await pump(tester, table(extra: <String, dynamic>{
        'columnWidths': <String, dynamic>{'0': 120},
      }));

      expect(tester.getSize(find.text('a1')).width, lessThanOrEqualTo(120));
      expect(tester.getRect(find.text('b1')).left, greaterThanOrEqualTo(120),
          reason: 'a declared width that is dropped leaves every column the '
              'same size, which reads as a table that was never configured');
    });

    testWidgets('a width given as a numeric string is read the same way',
        (tester) async {
      await pump(tester, table(extra: <String, dynamic>{
        'columnWidths': <String, dynamic>{'0': '120'},
      }));

      expect(tester.getRect(find.text('b1')).left, greaterThanOrEqualTo(120),
          reason: 'a width that arrives as a string — which is what a binding '
              'produces — must not fall through to the default');
    });

    testWidgets('a key that is not a column index is skipped, not fatal',
        (tester) async {
      await pump(tester, table(extra: <String, dynamic>{
        'columnWidths': <String, dynamic>{'name': 120, '0': 100},
      }));

      expect(tester.takeException(), isNull,
          reason: 'one bad key must not cost the whole table');
      expect(find.text('a1'), findsOneWidget);
    });

    testWidgets('a row decoration paints its colour and border',
        (tester) async {
      await pump(tester, table(extra: <String, dynamic>{
        'rowExtra': <String, dynamic>{
          'decoration': <String, dynamic>{
            'color': '#FFEEEE',
            'border': <String, dynamic>{'color': '#FF0000', 'width': 2},
          },
        },
      }));

      // `TableRow` is not a widget in the tree, so the decoration is read
      // off the rendered `Table` itself.
      final rendered = tester.widget<Table>(find.byType(Table));
      final decoration =
          rendered.children.first.decoration as BoxDecoration?;
      expect(decoration?.color, const Color(0xFFFFEEEE));
      expect(decoration?.border, isNotNull,
          reason: 'a row border a document declared and the runtime dropped '
              'makes a highlighted row indistinguishable from any other');
    });

    testWidgets('a border with no colour falls back to the theme',
        (tester) async {
      await pump(tester, table(extra: <String, dynamic>{
        'border': <String, dynamic>{'width': 3},
        'rowExtra': <String, dynamic>{
          'decoration': <String, dynamic>{
            'border': <String, dynamic>{'width': 1},
          },
        },
      }));

      final rendered = tester.widget<Table>(find.byType(Table));
      expect(rendered.border, isNotNull);
      expect(rendered.border!.top.width, 3);
    });
  });

  group('richText', () {
    testWidgets('a span with children carries its own text and theirs',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'richText',
        'spans': <dynamic>[
          <String, dynamic>{
            'text': 'Total: ',
            'children': <dynamic>[
              <String, dynamic>{
                'text': '42',
                'style': <String, dynamic>{'fontWeight': 'bold'},
              },
              <String, dynamic>{'text': ' items'},
            ],
          },
        ],
      });

      final rich = tester.widget<RichText>(find.byType(RichText));
      expect(rich.text.toPlainText(), 'Total: 42 items',
          reason: 'a nested run dropped takes the number out of the sentence '
              'and leaves the label reading "Total: "');

      final outer = rich.text as TextSpan;
      final nested = (outer.children!.first as TextSpan).children!;
      expect((nested.first as TextSpan).style?.fontWeight, FontWeight.bold);
    });

    testWidgets('a text scale factor is applied', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'richText',
        'textScaleFactor': 2.0,
        'spans': <dynamic>[
          <String, dynamic>{'text': 'big'},
        ],
      });

      final rich = tester.widget<RichText>(find.byType(RichText));
      expect(rich.textScaler, const TextScaler.linear(2.0),
          reason: 'an accessibility scale that is read and dropped leaves the '
              'text at the size the author never chose');
    });

    testWidgets('a span reads a binding', (tester) async {
      stateManager.set('name', 'Ada');
      await pump(tester, <String, dynamic>{
        'type': 'richText',
        'spans': <dynamic>[
          <String, dynamic>{'text': 'Hello '},
          <String, dynamic>{'text': '{{name}}'},
        ],
      });

      final rich = tester.widget<RichText>(find.byType(RichText));
      expect(rich.text.toPlainText(), 'Hello Ada');
    });
  });

  group('image', () {
    testWidgets('a declared loading widget is what shows while bytes are '
        'awaited', (tester) async {
      // A vector behind an asynchronous scheme is the one image shape with a
      // wait to fill, and `loading` exists for exactly that wait.
      const svg = '<svg xmlns="http://www.w3.org/2000/svg" width="8" '
          'height="8"><rect width="8" height="8" fill="#FF0000"/></svg>';
      final resolver = AssetResolver(
          bundleReader: (path) async => Uint8List.fromList(utf8.encode(svg)));
      final hosted = RenderContext(
        renderer: context.renderer,
        stateManager: stateManager,
        bindingEngine: context.bindingEngine,
        actionHandler: context.actionHandler,
        themeManager: ThemeManager.instance,
        engine: _AssetHost(resolver),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: hosted.renderer.renderWidget(<String, dynamic>{
              'type': 'image',
              'src': 'bundle://logo.svg',
              'loading': <String, dynamic>{
                'type': 'text',
                'content': 'fetching',
              },
              'width': 8,
              'height': 8,
            }, hosted),
          ),
        ),
      ));
      expect(find.text('fetching'), findsOneWidget,
          reason: 'a declared loading widget that never appears leaves the '
              'author believing the image loads instantly on every device');

      await tester.pumpAndSettle();
      expect(find.text('fetching'), findsNothing,
          reason: 'and it has to go away once the bytes are in');
    });

    testWidgets('a source it cannot resolve shows the declared error text',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'image',
        'src': 'nonsense://thing',
        'errorWidget': 'No picture',
        'width': 100,
        'height': 100,
      });

      expect(find.text('No picture'), findsOneWidget,
          reason: 'a reference the runtime cannot read must say so in the '
              'space the picture would have taken, not leave a blank the '
              'author reads as a layout bug');
      expect(find.byIcon(Icons.error), findsOneWidget);
    });

    testWidgets('with no text it still marks the space', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'image',
        'src': 'nonsense://thing',
        'width': 100,
        'height': 100,
      });

      expect(find.byIcon(Icons.error), findsOneWidget,
          reason: 'an empty box is indistinguishable from a picture that is '
              'still loading');
    });

    testWidgets('a declared fallback widget replaces the picture entirely',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'image',
        'src': 'nonsense://thing',
        'fallback': <String, dynamic>{
          'type': 'text',
          'content': 'Avatar unavailable',
        },
      });

      expect(find.text('Avatar unavailable'), findsOneWidget);
    });

    testWidgets('a fallback URL is fetched before the error card',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'image',
        'src': 'nonsense://thing',
        'fallbackUrl': 'https://example.com/default.png',
        'errorWidget': 'no picture',
        'width': 80,
        'height': 80,
      });

      final images = tester.widgetList<Image>(find.byType(Image));
      expect(images, isNotEmpty,
          reason: 'the second URL is the whole point of declaring it; going '
              'straight to the error card ignores what the author supplied');
      expect(
        images.first.image,
        isA<NetworkImage>().having(
            (i) => i.url, 'url', 'https://example.com/default.png'),
      );

      // The loopback in `flutter_test` refuses every request, so the fallback
      // fails too and the error card is what stays on screen.
      await tester.pumpAndSettle();
      expect(find.text('no picture'), findsOneWidget);
    });

    testWidgets('`fallbackBehavior: hide` leaves nothing at all',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'image',
        'src': 'nonsense://thing',
        'fallbackBehavior': 'hide',
        'errorWidget': 'broken',
      });

      expect(find.text('broken'), findsNothing,
          reason: 'a document that asked for the space to collapse must not '
              'get an error card in the layout instead');
    });

    testWidgets('an empty source is the same refusal', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'image',
        'src': '',
        'errorWidget': 'no source',
      });

      expect(find.byType(Image), findsNothing);
      expect(find.text('no source'), findsOneWidget);
    });
  });
}

/// A host object carrying only an asset resolver — `RenderContext.engine` is
/// untyped so a host can pass its own.
class _AssetHost {
  _AssetHost(this.assetResolver);

  final AssetResolver assetResolver;
}
