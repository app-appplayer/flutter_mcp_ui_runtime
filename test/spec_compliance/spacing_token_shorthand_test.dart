// The M3 spacing-token shorthand on `box`, and the two places the registry
// disagrees with it.
//
// `02_Widgets.md §2.5` promises that `box.padding` takes a spacing token
// (`md`, or any custom slot in `theme.spacing`) resolved through
// `theme.spacing.<token>`, and that the object form also accepts
// `{token: "md"}`. The runtime delivers both — `container_factory`'s own
// `_resolveEdgeInsets` resolves the token before falling through to the
// structural shapes, and it does so for `margin` through the *same* helper.
//
// The registry does not say the same thing:
//
//   * `padding` is declared `["string", "EdgeInsets"]`, so **any** string
//     passes — `"16px"` validates, resolves to no token, and lands as no
//     inset at all. A silent zero is exactly what the `EdgeInsets` primitive
//     says validators must prevent ("a bare word is not an inset ... so
//     validators reject it rather than let it render as a silent zero").
//   * `margin` is declared bare `EdgeInsets`, so the token form is rejected
//     at authoring time even though the widget renders it.
//
// Both halves are pinned here: what the runtime actually does with each
// spelling, and what the registry says about it. The registry assertions are
// the ones that move when the declaration is fixed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_mcp_ui_runtime/src/widgets/layout/container_factory.dart';

void main() {
  Map<String, dynamic> pageWith(Map<String, dynamic> boxProps) =>
      <String, dynamic>{
        'type': 'page',
        'content': <String, dynamic>{
          'type': 'box',
          ...boxProps,
          'child': <String, dynamic>{'type': 'text', 'content': 'x'},
        },
      };

  // Deliberately off the M3 baseline (md is 16 by default) and with one slot
  // the standard set does not have. A token that resolved to the *default*
  // scale would pass an assertion written against the default and prove
  // nothing about the lookup; 37 and `roomy` can only come from this map.
  //
  // The theme is installed through the host API rather than declared on the
  // definition because a `page` carries no theme — only an application does
  // (`runtime_engine.dart:562`). That is a separate question from this one.
  const themeSpacing = <String, dynamic>{
    'spacing': <String, dynamic>{'md': 37, 'roomy': 41},
  };

  // One runtime per test: a second runtime inside the same `testWidgets`
  // goes unmounted, which is how a sibling suite once "passed" while
  // measuring nothing.
  Future<Container?> box(WidgetTester tester, Map<String, dynamic> props) async {
    final runtime = MCPUIRuntime();
    await runtime.initialize(pageWith(props));
    runtime.themeManager.setTheme(themeSpacing);
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: runtime.buildUI())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final found = tester
        .widgetList<Container>(find.byType(Container))
        .where((c) => c.padding != null || c.margin != null)
        .toList();
    await runtime.destroy();
    return found.isEmpty ? null : found.first;
  }

  group('the runtime resolves the spacing token', () {
    testWidgets('padding: "md" becomes theme.spacing.md on every edge',
        (tester) async {
      final c = await box(tester, <String, dynamic>{'padding': 'md'});
      expect(c?.padding, const EdgeInsets.all(37));
    });

    testWidgets('a custom slot resolves the same way', (tester) async {
      final c = await box(tester, <String, dynamic>{'padding': 'roomy'});
      expect(c?.padding, const EdgeInsets.all(41));
    });

    testWidgets('the object form {token: "md"} resolves too', (tester) async {
      final c = await box(
          tester, <String, dynamic>{'padding': <String, dynamic>{'token': 'md'}});
      expect(c?.padding, const EdgeInsets.all(37));
    });

    testWidgets('margin takes the token through the same helper',
        (tester) async {
      final c = await box(tester, <String, dynamic>{'margin': 'md'});
      expect(c?.margin, const EdgeInsets.all(37));
    });

    // A slot the theme does not declare is still token-shaped, so the
    // registry cannot catch it — only the theme knows. It produces no inset,
    // and the runtime says so rather than leaving a silent zero.
    testWidgets('an undeclared slot produces no inset, and is reported',
        (tester) async {
      // A token unique to this test: the report fires once per distinct
      // value for the life of the process, so a shared word would make the
      // assertion depend on which suite ran first.
      const slot = 'slotNoThemeDeclares';
      // Match the record, not the substring. An earlier version of this test
      // asked only whether *some* log line mentioned the token, and passed
      // with the report deleted — the runtime debug-logs the property bag,
      // so the token appeared either way. The assertion has to name the
      // subsystem and the level, or it is measuring the debug log.
      final reports = <MCPLogRecord>[];
      final previous = MCPLogger.onRecord;
      MCPLogger.onRecord = (r) {
        if (r.logger == 'BoxSpacing' && r.level == 'WARN') reports.add(r);
      };
      try {
        final c = await box(tester, <String, dynamic>{'padding': slot});
        expect(c?.padding, isNull);
      } finally {
        MCPLogger.onRecord = previous;
      }
      expect(reports, hasLength(1),
          reason: 'an unresolved token must be reported exactly once');
      expect(reports.single.message, contains(slot));
      expect(reports.single.message, contains('theme.spacing'));
    });
  });

  group('a document that produces tokens from state', () {
    testWidgets('the reports stop once, with a line saying why',
        (tester) async {
      // A binding that yields a different token every frame — a row index, a
      // computed size — turns "report each distinct value once" into an
      // unbounded log. The cap exists so a noisy document costs one more line
      // rather than thousands.
      ContainerWidgetFactory.resetSpacingWarnings();
      addTearDown(ContainerWidgetFactory.resetSpacingWarnings);

      final reports = <MCPLogRecord>[];
      final previous = MCPLogger.onRecord;
      MCPLogger.onRecord = (r) {
        if (r.logger == 'BoxSpacing' && r.level == 'WARN') reports.add(r);
      };
      try {
        // One page carrying seventy boxes, each with a different unresolved
        // token — the shape a list built from state produces in a single
        // build.
        final runtime = MCPUIRuntime();
        await runtime.initialize(<String, dynamic>{
          'type': 'page',
          'content': <String, dynamic>{
            'type': 'linear',
            'direction': 'vertical',
            'children': <dynamic>[
              for (var i = 0; i < 70; i++)
                <String, dynamic>{'type': 'box', 'padding': 'noSuchToken$i'},
            ],
          },
        });
        await tester.pumpWidget(
            MaterialApp(home: Scaffold(body: runtime.buildUI())));
        await tester.pump();
        await runtime.destroy();
      } finally {
        MCPLogger.onRecord = previous;
      }

      expect(reports.length, lessThan(70),
          reason: 'that is the point of the cap');
      expect(reports.last.message, contains('stopped reporting'),
          reason: 'and it says so rather than just going quiet — silence '
              'reads as "the tokens started resolving"');
    });
  });

  group('the registry agrees with the runtime', () {
    Map<String, dynamic> boxNode(Map<String, dynamic> props) =>
        <String, dynamic>{'type': 'box', ...props};

    test('padding takes the token', () {
      expect(validateMcpUiDslWidget(boxNode({'padding': 'md'})).isValid, isTrue);
    });

    test('padding takes the {token} object form', () {
      final r = validateMcpUiDslWidget(
          boxNode({'padding': <String, dynamic>{'token': 'md'}}));
      expect(r.isValid, isTrue, reason: r.errors.take(2).join('\n'));
    });

    test('margin takes the token, because the widget renders it', () {
      final r = validateMcpUiDslWidget(boxNode({'margin': 'md'}));
      expect(r.isValid, isTrue, reason: r.errors.take(2).join('\n'));
    });

    // Deliberately NOT rejected. `box.padding` has admitted any string since
    // 1.4 and the runtime validates documents at load, so tightening this
    // would stop an already-published bundle from opening — a schema
    // narrowing is a bundle break, not an authoring hint. The unresolved
    // value is reported at runtime instead (see the group above). This test
    // exists to keep the next person from "fixing" it.
    test('a value that is not a token still validates — narrowing it would '
        'break published bundles', () {
      expect(validateMcpUiDslWidget(boxNode({'padding': '16px'})).isValid,
          isTrue);
      expect(validateMcpUiDslWidget(boxNode({'margin': '16px'})).isValid,
          isTrue);
    });

    test('the structural spellings are untouched', () {
      for (final form in <Object>[
        8,
        <String, dynamic>{'all': 8},
        <String, dynamic>{'horizontal': 8, 'vertical': 4},
        <String, dynamic>{'value': 8, 'unit': 'px'},
        '{{layout.pad}}',
      ]) {
        for (final slot in <String>['padding', 'margin']) {
          final r = validateMcpUiDslWidget(boxNode({slot: form}));
          expect(r.isValid, isTrue,
              reason: '$slot = $form\n${r.errors.take(2).join('\n')}');
        }
      }
    });
  });
}
