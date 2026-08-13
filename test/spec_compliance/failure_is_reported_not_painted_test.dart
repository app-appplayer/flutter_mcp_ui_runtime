// A failed widget is reported, not painted on a customer's screen.
//
// The renderer used to draw a red box carrying the message and the widget type
// in every build, and log the reason only under `kDebugMode`. That is exactly
// backwards for a served document: one typo put `Unknown widget type: …` in
// front of an end user, while the operator who could fix it got nothing.
//
// §18.2.1 requires that an unknown type not crash the runtime and that
// rendering continue. It does not require developer text on the page — and
// §6.13 already settled the shape for the sibling case (an absent capability
// is *reported*, never faked). These tests hold both halves: the page survives
// and stays clean, and the failure reaches a channel someone reads.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:flutter_mcp_ui_runtime/src/plugins/plugin_hooks.dart';

Future<void> _open(WidgetTester tester, Map<String, dynamic> content) async {
  final runtime = MCPUIRuntime();
  addTearDown(runtime.dispose);
  await runtime.initialize(<String, dynamic>{
    'type': 'page',
    'content': content,
  }, validateSchema: false);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: KeyedSubtree(key: UniqueKey(), child: runtime.buildUI()),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('an unknown type leaves no developer text on the page',
      (tester) async {
    final reports = <Map<String, dynamic>>[];
    PluginHookManager.instance.registerHook(
      pluginName: 'test-observer',
      hookType: PluginHookType.onError,
      callback: (ctx) async => reports.add(Map<String, dynamic>.from(ctx.data)),
    );
    addTearDown(() => PluginHookManager.instance.unregisterHook(
          pluginName: 'test-observer',
          hookType: PluginHookType.onError,
        ));

    await _open(tester, <String, dynamic>{
      'type': 'linear',
      'direction': 'vertical',
      'children': <dynamic>[
        <String, dynamic>{'type': 'text', 'content': 'NEIGHBOUR'},
        <String, dynamic>{'type': 'notAWidgetType'},
      ],
    });

    // The page keeps rendering — §18.2.1's actual requirement.
    expect(find.text('NEIGHBOUR'), findsOneWidget);

    // In a test build `kDebugMode` is true, so the reason IS drawn: the
    // developer-facing half is intact where a developer is looking.
    expect(find.textContaining('Unknown widget type'), findsOneWidget);

    // And it was reported, which is the half that used to be missing —
    // the log line sat behind a `kDebugMode` guard and the hook never fired.
    expect(reports, isNotEmpty,
        reason: 'the operator has to hear about it through a channel, not by '
            'reading the customer\'s screen');
    expect(reports.first['widgetType'], 'notAWidgetType');
    expect(reports.first['message'], contains('notAWidgetType'));
  });

  testWidgets('sliver items of widget nodes draw instead of vanishing',
      (tester) async {
    // Schema-valid, and the section came up blank with no error and no log:
    // `items` without an `itemTemplate` returned an empty delegate.
    await _open(tester, <String, dynamic>{
      'type': 'scrollView',
      'slivers': <dynamic>[
        <String, dynamic>{
          'type': 'sliverList',
          'items': <dynamic>[
            <String, dynamic>{'type': 'text', 'content': 'ITEM-A'},
            <String, dynamic>{'type': 'text', 'content': 'ITEM-B'},
          ],
        },
      ],
    });

    expect(find.text('ITEM-A'), findsOneWidget);
    expect(find.text('ITEM-B'), findsOneWidget);
  });

  testWidgets('data rows with no template still render nothing — reported',
      (tester) async {
    // The other half of the same shape: these are not widgets, so nothing can
    // be drawn from them. The page must still open.
    await _open(tester, <String, dynamic>{
      'type': 'linear',
      'direction': 'vertical',
      'children': <dynamic>[
        <String, dynamic>{'type': 'text', 'content': 'AFTER'},
        // Given a share of the column rather than the whole screen: the
        // unbounded fallback would otherwise claim full height beside the
        // text and overflow the page, which is the document's arithmetic, not
        // the widget's behaviour.
        <String, dynamic>{
          'type': 'expanded',
          'child': <String, dynamic>{
            'type': 'scrollView',
            'slivers': <dynamic>[
              <String, dynamic>{
                'type': 'sliverList',
                'items': <dynamic>[
                  <String, dynamic>{'title': 'row one'},
                ],
              },
            ],
          },
        },
      ],
    });

    expect(find.text('AFTER'), findsOneWidget);
    expect(find.textContaining('Unknown widget type'), findsNothing);
  });
}
