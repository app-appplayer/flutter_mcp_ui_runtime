// Host exit affordance tests — spec §2.8.1 / §4.3.2 / §6.6.1.
// Verifies the runtime-inserted close button on the `headerBar.actions`
// trailing edge, plus visibility rules and customization hooks.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  late MCPUIRuntime runtime;

  setUp(() {
    runtime = MCPUIRuntime();
    NavigationActionExecutor.clearOnExitCallback();
  });

  tearDown(() {
    runtime.destroy();
    NavigationActionExecutor.clearOnExitCallback();
  });

  Future<void> pumpHeaderBar(
    WidgetTester tester, {
    required Map<String, dynamic> headerBar,
    VoidCallback? onExit,
  }) async {
    final definition = <String, dynamic>{
      'type': 'page',
      'content': {
        'type': 'linear',
        'direction': 'vertical',
        'children': [
          headerBar,
          {'type': 'text', 'text': 'body'},
        ],
      },
    };
    await runtime.initialize(definition);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: runtime.buildUI(onExit: onExit)),
      ),
    );
    await tester.pump();
  }

  group('TC-227: Host exit affordance (spec §2.8.1 / §4.3.2)', () {
    testWidgets('TC-227a: no close button when onExit is not registered',
        (tester) async {
      await pumpHeaderBar(
        tester,
        headerBar: {
          'type': 'headerBar',
          'title': 'My App',
          'actions': [
            {'type': 'iconButton', 'icon': 'search'},
          ],
        },
      );
      // Only the app-defined action is present.
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('TC-227b: close button appended to actions trailing edge when onExit registered',
        (tester) async {
      await pumpHeaderBar(
        tester,
        headerBar: {
          'type': 'headerBar',
          'title': 'My App',
          'actions': [
            {'type': 'iconButton', 'icon': 'search'},
            {'type': 'iconButton', 'icon': 'settings'},
          ],
        },
        onExit: () {},
      );
      // App-defined actions preserved, close button appended.
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('TC-227c: close button invokes onExit callback',
        (tester) async {
      var exitCount = 0;
      await pumpHeaderBar(
        tester,
        headerBar: {
          'type': 'headerBar',
          'title': 'My App',
        },
        onExit: () => exitCount++,
      );
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(exitCount, 1);
    });

    testWidgets('TC-227d: exitButton: false suppresses the host close button',
        (tester) async {
      await pumpHeaderBar(
        tester,
        headerBar: {
          'type': 'headerBar',
          'title': 'My App',
          'exitButton': false,
          'actions': [
            {'type': 'iconButton', 'icon': 'search'},
          ],
        },
        onExit: () {},
      );
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('TC-227e: exitButton config overrides icon and tooltip',
        (tester) async {
      await pumpHeaderBar(
        tester,
        headerBar: {
          'type': 'headerBar',
          'title': 'My App',
          'exitButton': {
            'icon': 'exit_to_app',
            'tooltip': 'Quit',
          },
        },
        onExit: () {},
      );
      expect(find.byIcon(Icons.exit_to_app), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.byTooltip('Quit'), findsOneWidget);
    });

    testWidgets('TC-227f: explicit exitApp action invokes onExit even without UI button',
        (tester) async {
      var exitCount = 0;
      await pumpHeaderBar(
        tester,
        headerBar: {
          'type': 'headerBar',
          'title': 'My App',
          'exitButton': false,
        },
        onExit: () => exitCount++,
      );
      // Close button suppressed by config — but the explicit action path still works.
      expect(find.byIcon(Icons.close), findsNothing);
      NavigationActionExecutor.invokeOnExit();
      expect(exitCount, 1);
    });
  });
}
