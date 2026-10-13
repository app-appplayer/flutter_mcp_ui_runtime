// The registry `placement` table against the runtime.
//
// `validateMcpUiDslPlacement` (core) says where `expanded` / `flexible` /
// `spacer` / `positioned` / `animatedPositioned` may sit. This renders every
// shape the table has an opinion on and checks that the runtime agrees: a
// shape the check accepts lays out, a shape it rejects raises Flutter's
// "Incorrect use of ParentDataWidget". A table that drifts from the runtime
// either blocks working pages or lets broken ones through.

import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_test/flutter_test.dart';

const _text = {'type': 'text', 'content': 'x'};

Map<String, dynamic> _child(String type) => switch (type) {
      'spacer' => {'type': 'spacer'},
      'positioned' || 'animatedPositioned' => {
          'type': type,
          'top': 0,
          'left': 0,
          'child': _text,
        },
      _ => {'type': type, 'child': _text},
    };

/// Places [child] in a parent shape. Each shape keeps a sibling so a flex or
/// stack parent has something else to lay out.
typedef _Shape = Map<String, dynamic> Function(Map<String, dynamic> child);

final _shapes = <String, _Shape>{
  'root': (c) => c,
  'linear': (c) => {
        'type': 'linear',
        'direction': 'horizontal',
        'children': [c, _text],
      },
  'linear wrap': (c) => {
        'type': 'linear',
        'direction': 'horizontal',
        'wrap': true,
        'children': [c, _text],
      },
  'stack': (c) => {
        'type': 'stack',
        'children': [_text, c],
      },
  'indexedStack': (c) => {
        'type': 'indexedStack',
        'index': 0,
        'children': [c],
      },
  'linear > decorated box': (c) => {
        'type': 'linear',
        'direction': 'horizontal',
        'children': [
          {'type': 'box', 'padding': 4, 'color': '#FF0000', 'child': c},
          _text,
        ],
      },
  'linear > conditional': (c) => {
        'type': 'linear',
        'direction': 'horizontal',
        'children': [
          {'type': 'conditional', 'condition': true, 'then': c},
          _text,
        ],
      },
  'linear > conditional else': (c) => {
        'type': 'linear',
        'direction': 'horizontal',
        'children': [
          {'type': 'conditional', 'condition': false, 'then': _text, 'else': c},
          _text,
        ],
      },
  'linear > visibility': (c) => {
        'type': 'linear',
        'direction': 'horizontal',
        'children': [
          {'type': 'visibility', 'visible': true, 'child': c},
          _text,
        ],
      },
  'linear > visibility maintainState': (c) => {
        'type': 'linear',
        'direction': 'horizontal',
        'children': [
          {
            'type': 'visibility',
            'visible': true,
            'maintainState': true,
            'child': c,
          },
          _text,
        ],
      },
  'stack > conditional': (c) => {
        'type': 'stack',
        'children': [
          _text,
          {'type': 'conditional', 'condition': true, 'then': c},
        ],
      },
  'stepper step content': (c) => {
        'type': 'stepper',
        'steps': [
          {'title': 'One', 'content': c},
        ],
      },
  'table cell': (c) => {
        'type': 'table',
        'rows': [
          {
            'cells': [c, _text],
          },
        ],
      },
  'richText widget span': (c) => {
        'type': 'richText',
        'spans': [
          {'text': 'a'},
          {'widget': c},
        ],
      },
  'scrollView sliverList children': (c) => {
        'type': 'scrollView',
        'slivers': [
          {
            'type': 'sliverList',
            'children': [c],
          },
        ],
      },
  'stack > visibility': (c) => {
        'type': 'stack',
        'children': [
          _text,
          {'type': 'visibility', 'visible': true, 'child': c},
        ],
      },
};

/// Shapes the runtime cannot judge because it does not build the position
/// at all (a spec <-> runtime gap, recorded where it is tracked).
const _runtimeGaps = <String, String>{
  'richText widget span':
      'the runtime does not render Span.widget (WidgetSpan) yet, so nothing is laid out',
};

const _children = [
  'expanded',
  'flexible',
  'spacer',
  'positioned',
  'animatedPositioned',
];

void main() {
  Renderer build() {
    final registry = WidgetRegistry();
    DefaultWidgets.registerAll(registry);
    return Renderer(
      widgetRegistry: registry,
      bindingEngine: BindingEngine(),
      actionHandler: ActionHandler(),
      stateManager: StateManager()..initialize(<String, dynamic>{}),
    );
  }

  for (final shape in _shapes.entries) {
    for (final type in _children) {
      final content = shape.value(_child(type));
      final gap = _runtimeGaps[shape.key];
      final accepted = validateMcpUiDslPlacement(content).isValid;

      testWidgets(
          '$type in ${shape.key}: '
          '${accepted ? 'accepted and lays out' : 'rejected and breaks'}',
          skip: gap != null, (tester) async {
        final errors = <FlutterErrorDetails>[];
        final previous = FlutterError.onError;
        FlutterError.onError = errors.add;
        try {
          await tester.pumpWidget(MaterialApp(
            home: build().renderPage({'type': 'page', 'content': content}),
          ));
          await tester.pump();
        } finally {
          FlutterError.onError = previous;
        }
        final broke = errors.any((e) =>
            e.exceptionAsString().contains('Incorrect use of ParentDataWidget'));
        expect(broke, !accepted,
            reason: accepted
                ? 'the placement check accepts a shape the runtime cannot lay out'
                : 'the placement check rejects a shape the runtime lays out');
      });
    }
  }
}
