// The scrollers in a parent that gives them no size, and the spacing between
// their items.
//
// Both are the shapes an author reaches by accident. A list inside a `Row`
// with an `Expanded` sibling has unbounded width, and a scroller in unbounded
// space asserts at layout time — a red screen, not a layout mistake anyone can
// see. `itemSpacing` is the opposite: it is asked for on purpose, and a value
// that is read and dropped leaves rows touching with nothing said.

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

  Widget render(Map<String, dynamic> definition) =>
      context.renderer.renderWidget(definition, context);

  /// The scroller sits where its parent measures it in one axis only — the
  /// shape that used to assert.
  Future<void> pumpUnboundedWidth(
    WidgetTester tester,
    Map<String, dynamic> definition,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Row(
          children: <Widget>[render(definition)],
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> pumpUnboundedHeight(
    WidgetTester tester,
    Map<String, dynamic> definition,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: <Widget>[render(definition)],
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> text(String content) =>
      <String, dynamic>{'type': 'text', 'content': content};

  group('a list with no bound along its scroll axis', () {
    testWidgets('a horizontal list in a Row falls back to the viewport width',
        (tester) async {
      await pumpUnboundedWidth(tester, <String, dynamic>{
        'type': 'listView',
        'scrollDirection': 'horizontal',
        'children': <dynamic>[text('a'), text('b')],
      });

      expect(tester.takeException(), isNull,
          reason: 'a horizontal viewport with unbounded width asserts at '
              'layout time; the whole screen goes red for what is only a '
              'missing size');
      expect(find.text('a'), findsOneWidget);
      expect(tester.getSize(find.byType(ListView)).width,
          tester.view.physicalSize.width / tester.view.devicePixelRatio);
    });

    testWidgets('a vertical list in a Column falls back to the viewport height',
        (tester) async {
      await pumpUnboundedHeight(tester, <String, dynamic>{
        'type': 'listView',
        'children': <dynamic>[text('a'), text('b')],
      });

      expect(tester.takeException(), isNull);
      expect(find.text('a'), findsOneWidget);
    });

    testWidgets('a grid in a Column is given a height too', (tester) async {
      await pumpUnboundedHeight(tester, <String, dynamic>{
        'type': 'grid',
        'columns': 2,
        'items': <dynamic>[text('a'), text('b')],
      });

      expect(tester.takeException(), isNull);
      expect(find.text('a'), findsOneWidget);
    });

    testWidgets('a scrollView in a Column is given a height', (tester) async {
      await pumpUnboundedHeight(tester, <String, dynamic>{
        'type': 'scrollView',
        'child': <String, dynamic>{
          'type': 'column',
          'children': <dynamic>[text('a')],
        },
      });

      expect(tester.takeException(), isNull);
      expect(find.text('a'), findsOneWidget);
    });
  });

  group('itemSpacing', () {
    /// The gap between the first two items, measured on screen.
    double gapBetween(WidgetTester tester, String first, String second,
        {required bool horizontal}) {
      final a = tester.getRect(find.text(first));
      final b = tester.getRect(find.text(second));
      return horizontal ? b.left - a.right : b.top - a.bottom;
    }

    testWidgets('separates the children of a vertical list', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: render(<String, dynamic>{
            'type': 'listView',
            'itemSpacing': 40,
            'children': <dynamic>[text('a'), text('b')],
          }),
        ),
      ));
      await tester.pumpAndSettle();

      expect(gapBetween(tester, 'a', 'b', horizontal: false),
          greaterThanOrEqualTo(40));
    });

    testWidgets('separates a horizontal list along its own axis',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 100,
            child: render(<String, dynamic>{
              'type': 'listView',
              'scrollDirection': 'horizontal',
              'itemSpacing': 40,
              'children': <dynamic>[text('a'), text('b')],
            }),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(gapBetween(tester, 'a', 'b', horizontal: true),
          greaterThanOrEqualTo(40),
          reason: 'a horizontal list separated vertically leaves its items '
              'touching, which is the one thing itemSpacing was asked for');
    });

    testWidgets('separates a bound list, in both directions', (tester) async {
      stateManager.set('rows', <dynamic>['a', 'b']);

      Future<void> pumpBound(String direction) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 200,
              child: render(<String, dynamic>{
                'type': 'listView',
                'scrollDirection': direction,
                'itemSpacing': 40,
                'items': '{{rows}}',
                'itemTemplate': <String, dynamic>{
                  'type': 'text',
                  'content': '{{item}}',
                },
              }),
            ),
          ),
        ));
        await tester.pumpAndSettle();
      }

      await pumpBound('vertical');
      expect(gapBetween(tester, 'a', 'b', horizontal: false),
          greaterThanOrEqualTo(40));

      await pumpBound('horizontal');
      expect(gapBetween(tester, 'a', 'b', horizontal: true),
          greaterThanOrEqualTo(40));
    });

    testWidgets('separates a counted list, in both directions',
        (tester) async {
      Future<void> pumpCounted(String direction) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 200,
              child: render(<String, dynamic>{
                'type': 'listView',
                'scrollDirection': direction,
                'itemSpacing': 40,
                'itemCount': 2,
                'itemBuilder': <String, dynamic>{
                  'type': 'text',
                  'content': 'row {{index}}',
                },
              }),
            ),
          ),
        ));
        await tester.pumpAndSettle();
      }

      await pumpCounted('vertical');
      expect(gapBetween(tester, 'row 0', 'row 1', horizontal: false),
          greaterThanOrEqualTo(40));

      await pumpCounted('horizontal');
      expect(gapBetween(tester, 'row 0', 'row 1', horizontal: true),
          greaterThanOrEqualTo(40));
    });
  });
  group('the shapes a scroller accepts', () {
    testWidgets('a non-primary scrollView in a Column is given a height',
        (tester) async {
      await pumpUnboundedHeight(tester, <String, dynamic>{
        'type': 'scrollView',
        'primary': false,
        'children': <dynamic>[text('a'), text('b')],
      });

      expect(tester.takeException(), isNull,
          reason: 'a scroller that is not the primary one still needs a '
              'bound along its axis; without it the viewport asserts');
      expect(find.text('a'), findsOneWidget);
    });

    testWidgets('a non-primary scrollView in a bounded box is left alone',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 120,
            width: 200,
            child: render(<String, dynamic>{
              'type': 'scrollView',
              'primary': false,
              'children': <dynamic>[text('a')],
            }),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(SingleChildScrollView)).height, 120,
          reason: 'a parent that already gave a size must not be overridden '
              'with the viewport height');
    });

    testWidgets('a grid built from items given inline and a template',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: render(<String, dynamic>{
            'type': 'grid',
            'columns': 2,
            'items': <dynamic>['Ada', 'Bob'],
            'itemTemplate': <String, dynamic>{
              'type': 'text',
              'content': '{{item}}',
            },
          }),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Ada'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget,
          reason: 'a literal list beside a template is the shortest way to '
              'write a fixed grid; ignoring it renders an empty one');
    });

    testWidgets('a pageView takes children declared beside its properties',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: render(<String, dynamic>{
            'type': 'pageView',
            'properties': <String, dynamic>{'initialPage': 1},
            'children': <dynamic>[text('one'), text('two')],
          }),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('one').evaluate().length + find.text('two').evaluate().length,
          greaterThan(0),
          reason: 'children beside an explicit `properties` block are the '
              'older spelling; dropping them renders an empty carousel');
    });

    testWidgets('a pageView with no children renders empty rather than '
        'throwing', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: render(<String, dynamic>{'type': 'pageView'})),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
