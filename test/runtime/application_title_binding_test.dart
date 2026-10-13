// The application title is a string like any other (spec §3.1: a binding is
// any string containing `{{ }}`), so the shell resolves it — `{{i18n.*}}`,
// state, any binding — and draws it again when the locale or the state
// changes. It used to be put on screen as written.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/mcp_ui_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MCPUIRuntime runtime;

  setUp(() => runtime = MCPUIRuntime(enableDebugMode: false));
  tearDown(() {
    NavigationActionExecutor.clearOnExitCallback();
    return runtime.dispose();
  });

  Map<String, dynamic> application({
    required String title,
    required String navigationType,
    int items = 2,
  }) =>
      {
        'type': 'application',
        'title': title,
        'version': '1.0.0',
        'initialRoute': '/home',
        'routes': {'/home': 'home', '/jobs': 'jobs'},
        'state': {
          'initial': {'user': 'Kim'},
        },
        'i18n': {
          'defaultLocale': 'en-US',
          'locales': ['en-US', 'ko-KR'],
          'text': {
            'en-US': {'appTitle': 'Notices', 'home': 'Home', 'jobs': 'Jobs'},
            'ko-KR': {'appTitle': '공지', 'home': '홈', 'jobs': '작업'},
          },
        },
        'navigation': {
          'type': navigationType,
          'items': [
            {'label': '{{i18n.home}}', 'route': '/home', 'icon': 'home'},
            if (items > 1)
              {
                'label': '{{i18n.jobs}} ({{user}})',
                'route': '/jobs',
                'icon': 'list'
              },
          ],
        },
      };

  Future<Map<String, dynamic>> pageFor(String route) async => {
        'type': 'page',
        'content': {'type': 'text', 'content': 'page: $route'},
      };

  Future<void> mount(
      WidgetTester tester, Map<String, dynamic> definition) async {
    await runtime.initialize(definition, pageLoader: pageFor);
    await tester.pumpWidget(MaterialApp(home: runtime.buildUI()));
    await settle(tester);
  }

  Finder inAppBar(String text) =>
      find.descendant(of: find.byType(AppBar), matching: find.text(text));

  for (final type in ['bottomNavigation', 'tabs', 'drawer', 'rail']) {
    testWidgets('$type shell: an i18n title is resolved and follows the locale',
        (tester) async {
      await mount(tester,
          application(title: '{{i18n.appTitle}}', navigationType: type));

      expect(find.text('{{i18n.appTitle}}'), findsNothing);
      expect(inAppBar('Notices'), findsOneWidget);

      runtime.setLocale('ko-KR');
      await settle(tester);
      expect(inAppBar('공지'), findsOneWidget);
      expect(inAppBar('Notices'), findsNothing);
    });
  }

  for (final type in ['bottomNavigation', 'tabs', 'drawer', 'rail']) {
    testWidgets(
        '$type shell: item labels resolve their bindings and follow '
        'the locale and the state', (tester) async {
      await mount(
          tester, application(title: 'Field Kit', navigationType: type));
      if (type == 'drawer') {
        await tester.tap(find.byTooltip('Open navigation menu'));
        await settle(tester);
      }

      expect(find.textContaining('{{'), findsNothing);
      expect(find.text('Home'), findsWidgets);
      expect(find.text('Jobs (Kim)'), findsWidgets);

      runtime.setLocale('ko-KR');
      runtime.engine.stateManager.set('user', 'Lee');
      await settle(tester);
      expect(find.text('홈'), findsWidgets);
      expect(find.text('작업 (Lee)'), findsWidgets);
      expect(find.text('Jobs (Kim)'), findsNothing);
    });
  }

  testWidgets('a single-page shell resolves its title too', (tester) async {
    await mount(
        tester,
        application(
            title: '{{i18n.appTitle}}',
            navigationType: 'bottomNavigation',
            items: 1));
    expect(inAppBar('Notices'), findsOneWidget);
  });

  testWidgets('a state binding in the title is resolved and follows the state',
      (tester) async {
    await mount(
        tester,
        application(
            title: '{{user}} · {{i18n.appTitle}}',
            navigationType: 'bottomNavigation'));
    expect(inAppBar('Kim · Notices'), findsOneWidget);

    runtime.engine.stateManager.set('user', 'Lee');
    await settle(tester);
    expect(inAppBar('Lee · Notices'), findsOneWidget);
  });

  testWidgets('the drawer header shows the resolved title', (tester) async {
    await mount(tester,
        application(title: '{{i18n.appTitle}}', navigationType: 'drawer'));
    await tester.tap(find.byTooltip('Open navigation menu'));
    await settle(tester);
    expect(
        find.descendant(
            of: find.byType(DrawerHeader), matching: find.text('Notices')),
        findsOneWidget);
  });

  testWidgets('the window title (MaterialApp) is the resolved title',
      (tester) async {
    await mount(
        tester,
        application(
            title: '{{i18n.appTitle}}', navigationType: 'bottomNavigation'));
    final titles =
        tester.widgetList<Title>(find.byType(Title)).map((t) => t.title);
    expect(titles, contains('Notices'));
    expect(titles, isNot(contains('{{i18n.appTitle}}')));
  });

  testWidgets('a plain title is shown as written', (tester) async {
    await mount(tester,
        application(title: 'Field Kit', navigationType: 'bottomNavigation'));
    expect(inAppBar('Field Kit'), findsOneWidget);
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}
