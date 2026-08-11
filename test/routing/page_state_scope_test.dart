// `MCPPageWidget` and the page-state scope around it.
//
// A routed page is where a document's `initialState`, its page-scope channels
// and its lifecycle hooks all land. The seeding rule matters most: a page must
// not overwrite state the app already holds, or navigating back to a page
// would discard whatever the user did while away.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/models/ui_definition.dart';
import 'package:flutter_mcp_ui_runtime/src/routing/page_state_scope.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/runtime_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late RuntimeEngine engine;

  setUp(() async {
    engine = RuntimeEngine(enableDebugMode: false);
    await engine.initialize(definition: <String, dynamic>{
      'type': 'page',
      'content': <String, dynamic>{'type': 'text', 'content': 'root'},
    });
  });

  tearDown(() async {
    NavigationActionExecutor.clearOnExitCallback();
    await engine.destroy();
  });

  PageDefinition page({
    String? title,
    Map<String, dynamic>? initialState,
    Map<String, dynamic>? content,
  }) =>
      PageDefinition(
        title: title,
        route: '/jobs',
        content: content ??
            <String, dynamic>{'type': 'text', 'content': 'page body'},
        initialState: initialState,
      );

  Future<void> mount(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(home: child));
    await tester.pumpAndSettle();
  }

  group('PageStateNotifier', () {
    test('holds a copy of the initial state, not the caller’s map', () {
      final initial = <String, dynamic>{'count': 1};
      final notifier = PageStateNotifier(initial);

      notifier.updateState('count', 2);

      expect(notifier.state['count'], 2);
      expect(initial['count'], 1,
          reason: 'a page that writes through to the definition it was built '
              'from changes what the next mount starts with');
    });

    test('every write notifies', () {
      final notifier = PageStateNotifier(<String, dynamic>{});
      var notifications = 0;
      notifier.addListener(() => notifications++);

      notifier.updateState('a', 1);
      notifier.updateAll(<String, dynamic>{'b': 2, 'c': 3});

      expect(notifications, 2);
      expect(notifier.state, {'a': 1, 'b': 2, 'c': 3});
    });
  });

  group('PageStateScope', () {
    testWidgets('a descendant reads the page state through it', (tester) async {
      Map<String, dynamic>? seen;

      await mount(
        tester,
        MCPPageScopeWrapper(
          pageDefinition: page(initialState: <String, dynamic>{'count': 1}),
          routePath: '/jobs',
          runtimeEngine: engine,
          child: Builder(builder: (ctx) {
            seen = PageStateScope.of(ctx)!.pageState;
            return const SizedBox.shrink();
          }),
        ),
      );

      expect(seen, {'count': 1});
    });

    testWidgets('outside a scope there is nothing to read', (tester) async {
      PageStateScope? seen;

      await mount(
        tester,
        Builder(builder: (ctx) {
          seen = PageStateScope.of(ctx);
          return const SizedBox.shrink();
        }),
      );

      expect(seen, isNull,
          reason: 'a scope that answers when absent would hand a widget some '
              'other page’s state');
    });
  });

  group('MCPPageWidget', () {
    testWidgets('renders its content', (tester) async {
      await mount(
        tester,
        MCPPageWidget(pageDefinition: page(), runtimeEngine: engine),
      );

      expect(find.text('page body'), findsOneWidget);
    });

    testWidgets('seeds initial state without overwriting what is already there',
        (tester) async {
      engine.stateManager.set('filter', 'mine');

      await mount(
        tester,
        MCPPageWidget(
          pageDefinition: page(initialState: <String, dynamic>{
            'filter': 'all',
            'sort': 'newest',
          }),
          runtimeEngine: engine,
        ),
      );

      expect(engine.stateManager.get('filter'), 'mine',
          reason: 'returning to a page must not discard what the user did '
              'while they were away');
      expect(engine.stateManager.get('sort'), 'newest');
    });

    testWidgets('a titled page gets its own bar when no shell provides one',
        (tester) async {
      await mount(
        tester,
        MCPPageWidget(
          pageDefinition: page(title: 'Jobs'),
          runtimeEngine: engine,
        ),
      );

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Jobs'), findsOneWidget);
    });

    testWidgets('an outer Scaffold suppresses the duplicate bar',
        (tester) async {
      await mount(
        tester,
        Scaffold(
          appBar: AppBar(title: const Text('Shell')),
          body: MCPPageWidget(
            pageDefinition: page(title: 'Jobs'),
            runtimeEngine: engine,
          ),
        ),
      );

      expect(find.text('Jobs'), findsNothing,
          reason: 'two title bars stacked is what a host sees when the runtime '
              'insists on its own');
      expect(find.text('Shell'), findsOneWidget);
    });

    testWidgets('an untitled page has no bar at all', (tester) async {
      await mount(
        tester,
        MCPPageWidget(pageDefinition: page(), runtimeEngine: engine),
      );

      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('a host that can be exited gets a close button',
        (tester) async {
      var exited = false;
      NavigationActionExecutor.setOnExitCallback(() => exited = true);

      await mount(
        tester,
        MCPPageWidget(
          pageDefinition: page(title: 'Jobs'),
          runtimeEngine: engine,
        ),
      );

      await tester.tap(find.byKey(const Key('mcp.page.close')));
      await tester.pumpAndSettle();

      expect(exited, isTrue,
          reason: '§4.3.2 — the close affordance exists only when the host '
              'registered somewhere to go');
    });

    testWidgets('with no host exit there is no close button', (tester) async {
      await mount(
        tester,
        MCPPageWidget(
          pageDefinition: page(title: 'Jobs'),
          runtimeEngine: engine,
        ),
      );

      expect(find.byKey(const Key('mcp.page.close')), findsNothing);
    });

    testWidgets('page-scope channels are registered on mount', (tester) async {
      final definition = PageDefinition(
        title: 'Jobs',
        route: '/jobs',
        content: <String, dynamic>{'type': 'text', 'content': 'page body'},
        channels: <String, ChannelConfig>{
          'telemetry': ChannelConfig.fromJson(<String, dynamic>{
            'type': 'client.poll',
            'autoStart': false,
            'autoDispose': true,
            'params': <String, dynamic>{'interval': 60000},
          }),
        },
      );

      await mount(
        tester,
        MCPPageWidget(pageDefinition: definition, runtimeEngine: engine),
      );

      expect(engine.channelManager.hasChannel('telemetry'), isTrue,
          reason: '§4.13 — a page that declares a channel and never opens it '
              'renders a live view of nothing');
    });

    testWidgets('leaving a page pauses it and coming back resumes it',
        (tester) async {
      Widget build(bool isActive) => MaterialApp(
            home: MCPPageWidget(
              pageDefinition: page(),
              runtimeEngine: engine,
              isActive: isActive,
            ),
          );

      await tester.pumpWidget(build(true));
      await tester.pumpAndSettle();

      await tester.pumpWidget(build(false));
      await tester.pumpAndSettle();
      await tester.pumpWidget(build(true));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('page body'), findsOneWidget);
    });
  });
}
