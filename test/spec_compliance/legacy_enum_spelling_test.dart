// The pre-1.3 spellings still render; they are not declared.
//
// §17.1.3 spells multi-word enum values in camelCase, and 1.3 decided that
// legacy spellings live in the implementation rather than the canonical
// surface. Both halves have to hold at once: a document written before that
// rule keeps drawing, and an editor offering values does not offer the old
// ones. Pinning only one half lets the other drift — which is how
// `space-between` came to be declared in the registry while the prose named
// `spaceBetween` two lines above it.

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
      test('${pair[0]} is declared, ${pair[1]} is not', () {
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
            isFalse,
            reason: '${pair[1]} is a legacy spelling, not a declared value');
      });
    }

    test('the QR levels follow the same split', () {
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
          isFalse,
          reason: 'the standard\'s single letters are legacy, not declared');
    });
  });

  testWidgets('the legacy spelling still lays out', (tester) async {
    // Rendered through the factory rather than a validated document, which is
    // exactly the position a legacy spelling occupies: the runtime honours it,
    // the registry does not advertise it.
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
