// `layoutBuilder`, `pageView`, `gridView` and `offlineFallback`.
//
// Four widgets that pick between shapes: the widest matching breakpoint, the
// page a swipe landed on, a column count, online versus offline content. In
// each case the wrong pick renders perfectly — a phone layout on a desktop, a
// page change nobody is told about, an offline card over a live connection.

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

  Future<void> pumpAt(
    WidgetTester tester,
    double width,
    Map<String, dynamic> definition,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
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

  Future<void> pump(WidgetTester tester, Map<String, dynamic> definition) =>
      pumpAt(tester, 400, definition);

  Map<String, dynamic> text(String content) =>
      <String, dynamic>{'type': 'text', 'content': content};

  group('layoutBuilder', () {
    Map<String, dynamic> responsive() => <String, dynamic>{
          'type': 'layoutBuilder',
          'breakpoints': <String, dynamic>{'narrow': 0, 'wide': 600},
          'layouts': <String, dynamic>{
            'narrow': text('narrow'),
            'wide': text('wide'),
          },
          'default': text('fallback'),
        };

    testWidgets('the widest matching breakpoint wins', (tester) async {
      await pumpAt(tester, 700, responsive());

      expect(find.text('wide'), findsOneWidget,
          reason: 'the breakpoints are sorted descending so the largest match '
              'is found first; taking the first declared instead would make '
              'the order of the map decide the layout');
    });

    testWidgets('a narrow box takes the narrow layout', (tester) async {
      await pumpAt(tester, 300, responsive());

      expect(find.text('narrow'), findsOneWidget);
    });

    testWidgets('with no breakpoints at all the default is used',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'layoutBuilder',
        'default': text('fallback'),
      });

      expect(find.text('fallback'), findsOneWidget);
    });

    testWidgets('a breakpoint with no layout falls through to the default',
        (tester) async {
      await pumpAt(tester, 700, <String, dynamic>{
        'type': 'layoutBuilder',
        'breakpoints': <String, dynamic>{'wide': 600},
        'layouts': <String, dynamic>{},
        'child': text('fallback'),
      });

      expect(find.text('fallback'), findsOneWidget,
          reason: 'a declared breakpoint with nothing behind it is an '
              'incomplete document, not a reason to draw nothing');
    });

    testWidgets('with nothing declared it draws nothing', (tester) async {
      await pump(tester, <String, dynamic>{'type': 'layoutBuilder'});

      expect(tester.takeException(), isNull);
    });
  });

  group('pageView', () {
    Map<String, dynamic> pages({Map<String, dynamic> extra = const {}}) =>
        <String, dynamic>{
          'type': 'pageView',
          'children': <dynamic>[text('one'), text('two'), text('three')],
          ...extra,
        };

    testWidgets('starts on the declared page', (tester) async {
      await pump(tester, pages(extra: <String, dynamic>{'initialPage': 1}));

      expect(find.text('two'), findsOneWidget);
    });

    testWidgets('a swipe reports the page it landed on', (tester) async {
      await pump(tester, pages(extra: <String, dynamic>{
        'onPageChanged': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'page',
          'value': '{{event.page}}',
        },
      }));

      await tester.drag(find.byType(PageView), const Offset(-380, 0));
      await tester.pumpAndSettle();

      expect(stateManager.get('page'), 1,
          reason: 'a carousel that moves and tells the document nothing '
              'leaves the dots underneath it pointing at the first slide');
    });

    testWidgets('a looping pageView wraps past the last page',
        (tester) async {
      await pump(tester, pages(extra: <String, dynamic>{
        'loop': true,
        'initialPage': 2,
        'onChange': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'page',
          'value': '{{event.index}}',
        },
      }));

      await tester.drag(find.byType(PageView), const Offset(-380, 0));
      await tester.pumpAndSettle();

      expect(find.text('one'), findsOneWidget,
          reason: 'a loop that stops at the end is not a loop; the third '
              'slide has to be followed by the first');
      expect(stateManager.get('page'), 3,
          reason: '`onChange` is the accepted alias of `onPageChanged`');
    });
  });

  group('gridView', () {
    testWidgets('a column count given as a string is read', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'grid',
        'columns': '2',
        'items': <dynamic>[text('a'), text('b'), text('c')],
      });

      expect(find.text('a'), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: 'a column count that arrives as a string — which is what a '
              'binding produces — must not collapse the grid to one column');
    });

    testWidgets('a max extent lays the grid out by width', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'grid',
        'maxCrossAxisExtent': 120,
        'items': <dynamic>[text('a'), text('b')],
      });

      final grid = tester.widget<GridView>(find.byType(GridView));
      expect(grid.gridDelegate,
          isA<SliverGridDelegateWithMaxCrossAxisExtent>());
    });

    testWidgets('direct children are each rendered', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'grid',
        'columns': 2,
        'items': <dynamic>[text('a'), text('b'), text('c'), text('d')],
      });

      expect(find.text('a'), findsOneWidget);
      expect(find.text('d'), findsOneWidget);
    });
  });

  group('offlineFallback', () {
    testWidgets('online content shows while the connection is up',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'offlineFallback',
        'isOnline': true,
        'online': text('live data'),
        'offline': text('cached copy'),
      });

      expect(find.text('live data'), findsOneWidget);
      expect(find.text('cached copy'), findsNothing);
    });

    testWidgets('the declared offline content shows when it is down',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'offlineFallback',
        'isOnline': false,
        'online': text('live data'),
        'offline': text('cached copy'),
      });

      expect(find.text('cached copy'), findsOneWidget);
    });

    testWidgets('with no offline content declared it says so itself, and '
        'offers a retry', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'offlineFallback',
        'isOnline': false,
        'message': 'No connection',
        'icon': 'wifi',
        'onRetry': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'retried',
          'value': true,
        },
      });

      expect(find.text('No connection'), findsOneWidget);
      expect(find.byIcon(Icons.wifi), findsOneWidget);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(stateManager.get('retried'), isTrue,
          reason: 'the retry is the only thing a user can do about an offline '
              'card; a button that does nothing is worse than none');
    });

    testWidgets('the retry can be suppressed', (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'offlineFallback',
        'isOnline': false,
        'showRetry': false,
        'onRetry': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'retried',
          'value': true,
        },
      });

      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('an unknown connection state shows the online content',
        (tester) async {
      await pump(tester, <String, dynamic>{
        'type': 'offlineFallback',
        'online': text('live data'),
        'offline': text('cached copy'),
      });

      expect(find.text('live data'), findsOneWidget,
          reason: 'assuming offline before anything is known would hide a '
              'working page behind a cached one');
    });
  });
}
