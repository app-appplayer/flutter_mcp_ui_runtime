// What a widget does when the behaviour it declares is not available here.
//
// §6.13.2: report, do not pretend. The report is the only thing a document
// gets — the widget itself draws nothing — so an `onError` that never fires
// leaves an empty rectangle where a map or an animation belongs, with no way
// for the page to say "not on this device" or fall back to a still image.

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
        body: context.renderer.renderWidget(definition, context),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> report(String binding, String value) =>
      <String, dynamic>{
        'type': 'state',
        'action': 'set',
        'binding': binding,
        'value': value,
      };

  for (final widget in const [
    <String, dynamic>{'type': 'lottieAnimation', 'src': 'ui://anim.json'},
    <String, dynamic>{'type': 'map', 'latitude': 1, 'longitude': 2},
  ]) {
    final type = widget['type'] as String;

    testWidgets('$type reports the absence through onError', (tester) async {
      await pump(tester, <String, dynamic>{
        ...widget,
        'onError': report('message', '{{event.message}}'),
      });

      expect(stateManager.get<String>('message'), isNotNull,
          reason: 'the widget draws nothing, so the report is the only thing '
              'the document gets; without it the page shows an empty box and '
              'cannot fall back');
      expect(stateManager.get<String>('message')!.toLowerCase(),
          contains(type == 'map' ? 'map' : 'lottie'),
          reason: 'the message has to name what is missing, or a page with '
              'two absent capabilities cannot tell which one failed');
    });

    testWidgets('$type carries the code and the widget-level spelling too',
        (tester) async {
      await pump(tester, <String, dynamic>{
        ...widget,
        'onError': <String, dynamic>{
          'type': 'batch',
          'actions': <dynamic>[
            report('code', '{{event.code}}'),
            report('error', '{{event.error}}'),
          ],
        },
      });

      expect(stateManager.get<String>('code'), 'CAPABILITY_UNAVAILABLE',
          reason: 'a document branching on the code needs one it can compare '
              'against rather than a sentence');
      expect(stateManager.get<String>('error'), isNotNull,
          reason: 'the widget sections of the spec spell this `event.error`; '
              'both spellings carry the same failure so a document written '
              'against either reads it');
    });

    testWidgets('$type draws nothing at all', (tester) async {
      await pump(tester, widget);

      expect(tester.takeException(), isNull,
          reason: 'a document that declared no onError still has to render');
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('$type reports once, not on every frame', (tester) async {
      await pump(tester, <String, dynamic>{
        ...widget,
        'onError': <String, dynamic>{
          'type': 'state',
          'action': 'increment',
          'binding': 'reports',
          'value': 1,
        },
      });
      stateManager.set('reports', 0);

      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(stateManager.get<int>('reports'), 0,
          reason: 'an absence reported on every frame turns one missing '
              'capability into a stream of identical errors');
    });
  }
}
