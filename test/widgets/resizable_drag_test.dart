// `resizable` — the drag itself.
//
// The widget renders, and that much was covered. What was not is the only
// thing it exists for: dragging the handle changes the size, tells the
// document how big it now is, and stays inside the bounds the document
// declared. A handle that moves the box but reports nothing leaves a layout
// the document cannot persist; one that ignores `minWidth` lets a user drag a
// panel to nothing.

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
        body: AnimatedBuilder(
          animation: stateManager,
          builder: (_, __) => context.renderer.renderWidget(definition, context),
        ),
      ),
    ));
    await tester.pump();
  }

  /// Records what the document was told, through an ordinary `state` action.
  Map<String, dynamic> record(String binding) => <String, dynamic>{
        'type': 'state',
        'action': 'set',
        'binding': binding,
        'value': '{{event}}',
      };

  Map<String, dynamic> panel({
    Map<String, dynamic> extra = const {},
  }) =>
      <String, dynamic>{
        'type': 'resizable',
        'width': 200,
        'height': 100,
        'handles': <dynamic>['bottomEnd'],
        'onResize': record('live'),
        'onResizeEnd': record('settled'),
        'child': <String, dynamic>{'type': 'text', 'content': 'panel'},
        ...extra,
      };

  /// Drags the corner handle by [by].
  Future<void> dragHandle(WidgetTester tester, Offset by) async {
    // The handle is the 16×16 square the factory positions at the corner.
    final handle = find.byWidgetPredicate(
        (w) => w is Container && w.constraints?.maxWidth == 16);
    expect(handle, findsOneWidget,
        reason: 'without a handle there is nothing to resize with');
    await tester.drag(handle, by);
    await tester.pumpAndSettle();
  }

  testWidgets('dragging the handle resizes, and reports the new size',
      (tester) async {
    await pump(tester, panel());

    await dragHandle(tester, const Offset(60, 40));

    final live = stateManager.get<dynamic>('live') as Map?;
    expect(live, isNotNull,
        reason: 'onResize is how a document follows the drag — a handle that '
            'moves the box and says nothing cannot be persisted');
    expect(live!['width'], 260);
    expect(live['height'], 140);
    expect(live['type'], 'resize');

    final settled = stateManager.get<dynamic>('settled') as Map?;
    expect(settled, isNotNull,
        reason: 'onResizeEnd is the one a document writes to storage; firing '
            'only the per-frame event means every drag costs a write');
    expect(settled!['type'], 'resizeEnd');
  });

  testWidgets('the declared bounds hold', (tester) async {
    await pump(
        tester,
        panel(extra: <String, dynamic>{
          'minWidth': 180,
          'maxWidth': 240,
          'minHeight': 80,
          'maxHeight': 120,
        }));

    await dragHandle(tester, const Offset(500, 500));
    expect((stateManager.get<dynamic>('live') as Map)['width'], 240);
    expect((stateManager.get<dynamic>('live') as Map)['height'], 120,
        reason: 'a panel a user can drag past its declared maximum is a '
            'layout the document did not agree to');

    await dragHandle(tester, const Offset(-500, -500));
    expect((stateManager.get<dynamic>('live') as Map)['width'], 180);
    expect((stateManager.get<dynamic>('live') as Map)['height'], 80,
        reason: 'and one draggable to nothing is a panel the user cannot get '
            'back');
  });

  testWidgets('keepAspectRatio ties the height to the width', (tester) async {
    await pump(
        tester,
        panel(extra: const <String, dynamic>{'keepAspectRatio': true}));

    await dragHandle(tester, const Offset(100, 0));

    final live = stateManager.get<dynamic>('live') as Map;
    expect(live['width'], 300);
    expect(live['height'], 150,
        reason: 'the declared box is 200×100, so a width of 300 is a height '
            'of 150 — a ratio that is only honoured on the axis being dragged '
            'is not a ratio');
  });
}
