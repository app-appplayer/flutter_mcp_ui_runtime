// An embedded application shows its `dashboard`.
//
// §11.9 makes `dashboard` the application's account of itself when embedded,
// and §2.13.1 embeds `ui://app` on that basis. Only `routes` was read, so an
// application that presented itself the way the spec asks for rendered as
// "Unavailable".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';

void main() {
  late Renderer renderer;

  setUp(() {
    final registry = WidgetRegistry();
    DefaultWidgets.registerAll(registry);
    renderer = Renderer(
      widgetRegistry: registry,
      stateManager: StateManager(),
      bindingEngine: BindingEngine(),
      actionHandler: ActionHandler(),
    );
  });

  Future<void> embed(WidgetTester tester, Map<String, dynamic> app) async {
    renderer.definitionResolver = (ref, origin) async => app;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => renderer.renderWidget(
              <String, dynamic>{
                'type': 'view',
                'source': <String, dynamic>{r'$ref': 'ui://app'},
              },
              renderer.createRootContext(ctx),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('dashboard.content is what an embedded application renders',
      (tester) async {
    await embed(tester, <String, dynamic>{
      'type': 'application',
      'title': 'Boiler',
      'routes': <String, dynamic>{},
      'dashboard': <String, dynamic>{
        'content': <String, dynamic>{
          'type': 'text',
          'content': 'DASHBOARD-TILE',
        },
      },
    });

    expect(find.text('DASHBOARD-TILE'), findsOneWidget);
    expect(find.text('Unavailable'), findsNothing);
  });

  testWidgets('without a dashboard it falls back to the initial route',
      (tester) async {
    await embed(tester, <String, dynamic>{
      'type': 'application',
      'title': 'Boiler',
      'initialRoute': '/',
      'routes': <String, dynamic>{
        '/': <String, dynamic>{
          'type': 'page',
          'content': <String, dynamic>{
            'type': 'text',
            'content': 'ROUTE-CONTENT',
          },
        },
      },
    });

    expect(find.text('ROUTE-CONTENT'), findsOneWidget);
  });
}
