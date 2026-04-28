// Draggable + DragTarget factory integration.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  late MCPUIRuntime runtime;

  setUp(() {
    runtime = MCPUIRuntime();
  });

  tearDown(() {
    runtime.destroy();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    required Map<String, dynamic> content,
    Map<String, dynamic>? initialState,
  }) async {
    final definition = <String, dynamic>{
      'type': 'page',
      'content': content,
    };
    if (initialState != null) {
      definition['runtime'] = {
        'services': {
          'state': {'initialState': initialState},
        },
      };
    }
    await runtime.initialize(definition);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: runtime.buildUI())),
    );
    await tester.pump();
  }

  testWidgets('drop on dragTarget inside scrollView still fires onDrop',
      (tester) async {
    await pumpPage(
      tester,
      content: {
        'type': 'singleChildScrollView',
        'child': {
          'type': 'linear',
          'direction': 'vertical',
          'children': [
            {
              'type': 'linear',
              'direction': 'horizontal',
              'children': [
                {
                  'type': 'draggable',
                  'data': 'payload-scroll',
                  'child': {
                    'type': 'box',
                    'width': 60,
                    'height': 60,
                    'decoration': {'color': '#2196F3'},
                  },
                  'feedback': {
                    'type': 'box',
                    'width': 60,
                    'height': 60,
                    'decoration': {'color': '#64B5F6'},
                  },
                },
                {
                  'type': 'dragTarget',
                  'onDrop': {
                    'type': 'state', 'action': 'set',
                    'binding': 'scrollDropped', 'value': '{{event.data}}',
                  },
                  'builder': {
                    'type': 'box',
                    'width': 100,
                    'height': 100,
                    'decoration': {'color': '#E8F5E9'},
                  },
                },
              ],
            },
          ],
        },
      },
      initialState: {'scrollDropped': 'none'},
    );
    final draggable = find.byType(Draggable<Object>);
    final target = find.byType(DragTarget<Object>);
    final gesture = await tester.startGesture(tester.getCenter(draggable));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(runtime.stateManager.state['scrollDropped'], 'payload-scroll');
  });

  testWidgets('drop on dragTarget writes onDrop binding', (tester) async {
    await pumpPage(
      tester,
      content: {
        'type': 'linear',
        'direction': 'horizontal',
        'children': [
          {
            'type': 'draggable',
            'data': 'payload-1',
            'child': {
              'type': 'box',
              'width': 60,
              'height': 60,
              'decoration': {'color': '#2196F3'},
            },
            'feedback': {
              'type': 'box',
              'width': 60,
              'height': 60,
              'decoration': {'color': '#64B5F6'},
            },
          },
          {
            'type': 'dragTarget',
            'onDrop': {
              'type': 'state', 'action': 'set',
              'binding': 'dropped', 'value': '{{event.data}}',
            },
            'builder': {
              'type': 'box',
              'width': 100,
              'height': 100,
              'decoration': {'color': '#E8F5E9'},
            },
          },
        ],
      },
      initialState: {'dropped': 'none'},
    );

    final draggable = find.byType(Draggable<Object>);
    final target = find.byType(DragTarget<Object>);
    expect(draggable, findsOneWidget);
    expect(target, findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(draggable));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(runtime.stateManager.state['dropped'], 'payload-1');
  });
}
