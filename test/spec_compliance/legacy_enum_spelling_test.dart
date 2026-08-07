// The pre-1.3 spellings render, and validate.
//
// §17.1.3 spells multi-word enum values in camelCase, and this file used to
// pin the other half of that decision as "legacy spellings live in the
// implementation, not the canonical surface" — declared nowhere, rendered
// anyway. That split cannot hold: `initialize` validates the document and
// throws before the first frame, so a bundle carrying `space-between` never
// reached the factory branch written to render it. The test passed because it
// called the factory directly, which no real document does.
//
// So both spellings validate, and the canonical one is what the prose, the
// description and an editor's completion list advertise. Being non-canonical
// is a matter of what is recommended, not of what loads.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';

void main() {
  group('the registry declares the canonical spelling only', () {
    for (final pair in const <List<String>>[
      ['spaceBetween', 'space-between'],
      ['spaceAround', 'space-around'],
      ['spaceEvenly', 'space-evenly'],
    ]) {
      test('${pair[0]} and ${pair[1]} both load', () {
        expect(
            validateMcpUiDslWidget(<String, dynamic>{
              'type': 'linear',
              'children': <dynamic>[],
              'distribution': pair[0],
            }).isValid,
            isTrue);
        expect(
            validateMcpUiDslWidget(<String, dynamic>{
              'type': 'linear',
              'children': <dynamic>[],
              'distribution': pair[1],
            }).isValid,
            isTrue,
            reason: 'the runtime renders ${pair[1]}; rejecting it here stops '
                'the whole document at initialize');
      });
    }

    test('the QR letters load the same way', () {
      expect(
          validateMcpUiDslWidget(<String, dynamic>{
            'type': 'qrCode',
            'value': 'x',
            'errorCorrection': 'high',
          }).isValid,
          isTrue);
      expect(
          validateMcpUiDslWidget(<String, dynamic>{
            'type': 'qrCode',
            'value': 'x',
            'errorCorrection': 'H',
          }).isValid,
          isTrue,
          reason: 'the factory maps H to high; a code that renders must not '
              'be a document that refuses to open');
    });
  });

  testWidgets('the legacy spelling still lays out', (tester) async {
    // Validation says the document opens; this says the layout is the same
    // one the canonical spelling produces. Both halves, or the value is
    // accepted at the door and then ignored.
    final registry = WidgetRegistry();
    DefaultWidgets.registerAll(registry);
    final renderer = Renderer(
      widgetRegistry: registry,
      stateManager: StateManager(),
      bindingEngine: BindingEngine(),
      actionHandler: ActionHandler(),
    );
    final context = RenderContext(
      renderer: renderer,
      stateManager: StateManager(),
      bindingEngine: BindingEngine(),
      actionHandler: ActionHandler(),
      themeManager: ThemeManager(),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: renderer.renderWidget(<String, dynamic>{
          'type': 'linear',
          'direction': 'horizontal',
          'distribution': 'space-between',
          'children': <dynamic>[
            <String, dynamic>{'type': 'text', 'content': 'a'},
            <String, dynamic>{'type': 'text', 'content': 'b'},
          ],
        }, context),
      ),
    ));
    await tester.pump();

    final row = tester.widget<Row>(find.byType(Row));
    expect(row.mainAxisAlignment, MainAxisAlignment.spaceBetween,
        reason: 'the legacy spelling must still reach the same layout');
  });
}
