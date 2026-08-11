// `colorPicker`'s three picker types and `timeline`'s item template.
//
// A colour picker writes a hex string into state; that string is what a
// document sends to a server or paints with, so a picker that renders a
// spectrum and writes nothing looks like it worked. `timeline`'s
// `itemTemplate` is the difference between a fixed three-line entry and a
// document laying out its own — a template that is accepted and ignored
// renders the built-in shape, which reads as "the template does not do
// anything yet".

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
        body: Center(
          child: SizedBox(
            width: 320,
            height: 400,
            child: AnimatedBuilder(
              animation: stateManager,
              builder: (_, __) =>
                  context.renderer.renderWidget(definition, context),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('colorPicker', () {
    Map<String, dynamic> picker({Map<String, dynamic> extra = const {}}) =>
        <String, dynamic>{
          'type': 'colorPicker',
          'binding': 'brand',
          ...extra,
        };

    testWidgets('picking a swatch writes a hex string', (tester) async {
      await pump(tester, picker());

      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      final chosen = stateManager.get<String>('brand');
      expect(chosen, isNotNull,
          reason: 'the hex string is what the document sends or paints with; '
              'a picker that shows a palette and writes nothing looks like it '
              'worked');
      expect(chosen, startsWith('#'));
      expect(chosen!.length, 7,
          reason: 'without showAlpha the value is #RRGGBB — an eight-digit '
              'value would reach a server that cannot read it');
    });

    testWidgets('the spectrum picker turns a tap position into a hue',
        (tester) async {
      await pump(tester, picker(extra: <String, dynamic>{
        'pickerType': 'wheel',
      }));

      // Tap a third of the way along the spectrum bar.
      final bar = find.byType(GestureDetector).first;
      final rect = tester.getRect(bar);
      await tester.tapAt(Offset(rect.left + rect.width / 3, rect.center.dy));
      await tester.pumpAndSettle();

      expect(stateManager.get<String>('brand'), isNotNull,
          reason: 'a spectrum that paints a gradient and answers no colour is '
              'a decoration, not a control');
    });

    testWidgets('showAlpha adds a slider, and the value carries the alpha',
        (tester) async {
      stateManager.set('brand', '#FF0000');
      await pump(tester, picker(extra: <String, dynamic>{'showAlpha': true}));

      expect(find.byType(Slider), findsOneWidget);

      await tester.drag(find.byType(Slider), const Offset(-40, 0));
      await tester.pumpAndSettle();

      final chosen = stateManager.get<String>('brand');
      expect(chosen, isNotNull);
      expect(chosen!.length, 9,
          reason: 'an alpha the user set and the value does not carry is a '
              'transparency that disappears on save');
    });

    testWidgets('a disabled picker takes no colour', (tester) async {
      await pump(tester, picker(extra: <String, dynamic>{'enabled': false}));

      await tester.tap(find.byType(InkWell).first, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(stateManager.get('brand'), isNull);
    });

    testWidgets('history keeps what was picked, most recent first',
        (tester) async {
      await pump(tester, picker(extra: <String, dynamic>{
        'enableHistory': true,
      }));

      final swatches = find.byType(InkWell);
      await tester.tap(swatches.at(0));
      await tester.pumpAndSettle();
      final first = stateManager.get<String>('brand');

      await tester.tap(find.byType(InkWell).at(1));
      await tester.pumpAndSettle();

      expect(stateManager.get<String>('brand'), isNot(first),
          reason: 'a history that swallows the next pick makes the control '
              'stop responding after the first use');
    });
  });

  group('timeline', () {
    Map<String, dynamic> timeline({Map<String, dynamic> extra = const {}}) =>
        <String, dynamic>{
          'type': 'timeline',
          'items': <dynamic>[
            <String, dynamic>{'title': 'Ordered', 'time': '09:00'},
            <String, dynamic>{'title': 'Shipped', 'time': '11:00'},
          ],
          ...extra,
        };

    testWidgets('the built-in entry shows the title and the time',
        (tester) async {
      await pump(tester, timeline());

      expect(find.text('Ordered'), findsOneWidget);
      expect(find.text('11:00'), findsOneWidget);
    });

    testWidgets('an itemTemplate replaces the built-in entry and sees its '
        'position', (tester) async {
      await pump(tester, timeline(extra: <String, dynamic>{
        'itemTemplate': <String, dynamic>{
          'type': 'text',
          'content': '{{item.title}} first={{isFirst}} last={{isLast}}',
        },
      }));

      expect(find.text('Ordered first=true last=false'), findsOneWidget,
          reason: 'a template that is accepted and ignored renders the '
              'built-in shape, which reads as "the template does nothing yet"');
      expect(find.text('Shipped first=false last=true'), findsOneWidget);
    });

    testWidgets('a declared icon is drawn on the node', (tester) async {
      await pump(tester, timeline(extra: <String, dynamic>{
        'items': <dynamic>[
          <String, dynamic>{'title': 'Delivered', 'icon': 'check'},
        ],
      }));

      expect(find.byIcon(Icons.check), findsOneWidget,
          reason: 'the icon is how a timeline says which step this is without '
              'the reader parsing the label');
    });
  });
}
