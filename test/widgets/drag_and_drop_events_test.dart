// `draggable` + `dragTarget` — the three moments a document is told about.
//
// Entering a target, leaving it again, and dropping on it are separate
// handlers, and the middle one had never fired: a board that highlights a
// column while a card is over it has no way to un-highlight it if `onDragLeave`
// never arrives, so the highlight stays on a column the user moved away from.

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

  Map<String, dynamic> record(String binding, String value) =>
      <String, dynamic>{
        'type': 'state',
        'action': 'set',
        'binding': binding,
        'value': value,
      };

  testWidgets('a drag that enters, leaves and drops reports all three',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AnimatedBuilder(
          animation: stateManager,
          builder: (_, __) => context.renderer.renderWidget(<String, dynamic>{
            'type': 'linear',
            'direction': 'vertical',
            'children': <dynamic>[
              <String, dynamic>{
                'type': 'draggable',
                'data': 'card-1',
                'child': <String, dynamic>{
                  'type': 'box',
                  'width': 80,
                  'height': 80,
                  'child': <String, dynamic>{'type': 'text', 'content': 'card'},
                },
              },
              <String, dynamic>{
                'type': 'dragTarget',
                'onDragEnter': record('phase', 'enter'),
                'onDragLeave': record('phase', 'leave'),
                'onDrop': record('phase', 'drop'),
                'child': <String, dynamic>{
                  'type': 'box',
                  'width': 200,
                  'height': 120,
                  'child': <String, dynamic>{'type': 'text', 'content': 'bin'},
                },
              },
            ],
          }, context),
        ),
      ),
    ));
    await tester.pump();

    // While a drag is in flight the feedback widget is a second copy of the
    // child, so the original is addressed by `.first`.
    final card = find.text('card').first;
    final bin = find.text('bin');

    final gesture = await tester.startGesture(tester.getCenter(card));
    await tester.pump(const Duration(milliseconds: 400));

    await gesture.moveTo(tester.getCenter(bin));
    await tester.pump();
    expect(stateManager.get<String>('phase'), 'enter',
        reason: 'entering is what a target highlights on');

    // Back out over the card again — the target must be told it lost the drag.
    await gesture.moveTo(tester.getCenter(card));
    await tester.pump();
    expect(stateManager.get<String>('phase'), 'leave',
        reason: 'without this a target that highlighted on enter stays lit '
            'under a pointer that has gone somewhere else');

    await gesture.moveTo(tester.getCenter(bin));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(stateManager.get<String>('phase'), 'drop');
  });
}
