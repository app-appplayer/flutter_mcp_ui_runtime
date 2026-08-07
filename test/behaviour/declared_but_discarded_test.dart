// Properties that were read and thrown away.
//
// Each of these was found the same way: a factory parsed the property into a
// local variable, marked it `// ignore: unused_local_variable`, and rendered as
// if the document had never mentioned it. The schema accepted the property,
// the widget built, every existing test passed, and the setting did nothing.
//
// A test per property, asking only what an author would ask: I declared this —
// did anything change?

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

void main() {
  final live = <MCPUIRuntime>[];
  tearDown(() {
    for (final r in live) {
      r.destroy();
    }
    live.clear();
  });

  var seq = 0;

  Future<MCPUIRuntime> pump(
    WidgetTester tester,
    Map<String, dynamic> content, {
    Map<String, dynamic>? initialState,
  }) async {
    // A distinct key per render. Without it the second render in a test
    // reuses the first one's elements and comes back EMPTY — every
    // "with the setting off, the thing is gone" assertion would pass against
    // a blank page, which is how a test can be green and prove nothing.
    final key = ValueKey('page-${seq++}');
    final runtime = MCPUIRuntime();
    live.add(runtime);
    final definition = <String, dynamic>{'type': 'page', 'content': content};
    if (initialState != null) {
      definition['runtime'] = {
        'services': {
          'state': {'initialState': initialState},
        },
      };
    }
    await runtime.initialize(definition);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: KeyedSubtree(key: key, child: runtime.buildUI())),
      ),
    );
    // Fixed pumps, not pumpAndSettle: a page rendered earlier in the same test
    // may still be running frames of its own, and waiting for the whole tree
    // to go quiet then never returns.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    return runtime;
  }

  group('tree', () {
    testWidgets('onNodeTap fires without selectable', (tester) async {
      // `onSelect` only fires when `selectable` is on, so a tree that declared
      // only `onNodeTap` had no working tap at all.
      final runtime = await pump(
        tester,
        {
          'type': 'tree',
          'data': [
            {'id': 'a', 'label': 'Root'},
          ],
          'onNodeTap': {
            'type': 'state',
            'action': 'set',
            'binding': 'tapped',
            'value': '{{event.label}}',
          },
        },
        initialState: {'tapped': ''},
      );

      await tester.tap(find.text('Root'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(runtime.stateManager.get<String>('tapped'), 'Root');
    });

    testWidgets('childrenKey names where the children are', (tester) async {
      await pump(tester, {
        'type': 'tree',
        'childrenKey': 'items',
        'initiallyExpanded': true,
        'data': [
          {
            'id': 'a',
            'label': 'Root',
            'items': [
              {'id': 'b', 'label': 'Leaf'},
            ],
          },
        ],
      });
      expect(find.text('Leaf'), findsOneWidget,
          reason: 'the tree read `children` and showed only the roots');
    });
  });

  group('tree drag', () {
    testWidgets('a dragged node reports where it landed', (tester) async {
      final runtime = await pump(
        tester,
        {
          'type': 'tree',
          'draggable': true,
          'initiallyExpanded': true,
          'data': [
            {'id': 'a', 'label': 'Alpha'},
            {'id': 'b', 'label': 'Beta'},
          ],
          'onDrop': {
            'type': 'state',
            'action': 'set',
            'binding': 'moved',
            'value': '{{event.item.id}}->{{event.target.id}}',
          },
        },
        initialState: {'moved': ''},
      );

      final from = tester.getCenter(find.text('Alpha'));
      final to = tester.getCenter(find.text('Beta'));
      final gesture = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 600)); // long press
      await gesture.moveTo(to);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));

      expect(runtime.stateManager.get<String>('moved'), 'a->b',
          reason: 'draggable: true offered no drag, and the onDrop its own '
              'description names was not even declared');
    });

    testWidgets('a tree that is not draggable stays put', (tester) async {
      final runtime = await pump(
        tester,
        {
          'type': 'tree',
          'initiallyExpanded': true,
          'data': [
            {'id': 'a', 'label': 'Alpha'},
            {'id': 'b', 'label': 'Beta'},
          ],
          'onDrop': {
            'type': 'state',
            'action': 'set',
            'binding': 'moved',
            'value': 'moved',
          },
        },
        initialState: {'moved': ''},
      );
      final gesture = await tester.startGesture(tester.getCenter(find.text('Alpha')));
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(tester.getCenter(find.text('Beta')));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));
      expect(runtime.stateManager.get<String>('moved'), '',
          reason: 'dragging works without the property being declared');
    });
  });

  group('textInput', () {
    testWidgets('onFocus fires when the field takes focus', (tester) async {
      final runtime = await pump(
        tester,
        {
          'type': 'linear',
          'direction': 'vertical',
          'children': [
            {
              'type': 'textInput',
              'label': 'Name',
              'onFocus': {
                'type': 'state',
                'action': 'set',
                'binding': 'focused',
                'value': true,
              },
            },
          ],
        },
        initialState: {'focused': false},
      );

      await tester.tap(find.byType(TextField));
      await tester.pump(const Duration(milliseconds: 350));
      expect(runtime.stateManager.get<bool>('focused'), isTrue,
          reason: '`onBlur` beside it worked; this one was dropped');
    });
  });

  group('rating', () {
    testWidgets('the declared icon is the glyph drawn', (tester) async {
      await pump(tester, {
        'type': 'rating',
        'value': 2,
        'max': 3,
        'icon': 'favorite',
      });
      expect(find.byIcon(Icons.favorite), findsWidgets,
          reason: 'a rating declaring hearts drew stars');
      expect(find.byIcon(Icons.star), findsNothing);
    });
  });

  group('colorPicker', () {
    testWidgets('showLabel decides whether the hex is shown', (tester) async {
      await pump(tester, {
        'type': 'colorPicker',
        'value': '#FF0000',
        'pickerType': 'palette',
      });
      expect(find.text('#FF0000'), findsOneWidget);

      await pump(tester, {
        'type': 'colorPicker',
        'value': '#FF0000',
        'pickerType': 'palette',
        'showLabel': false,
      });
      expect(find.text('#FF0000'), findsNothing,
          reason: 'showLabel: false still printed the hex');
    });

    testWidgets('showAlpha adds the channel, and the value carries it',
        (tester) async {
      final runtime = await pump(
        tester,
        {
          'type': 'colorPicker',
          'binding': 'colour',
          'pickerType': 'palette',
          'showAlpha': true,
        },
        initialState: {'colour': '#FF0000'},
      );
      expect(find.byType(Slider), findsOneWidget,
          reason: 'showAlpha: true offered no way to set alpha');

      await tester.tap(find.byType(InkWell).first);
      await tester.pump(const Duration(milliseconds: 350));
      expect(runtime.stateManager.get<String>('colour'), startsWith('#FF'),
          reason: 'with alpha enabled the written value must carry it');
      expect(runtime.stateManager.get<String>('colour')!.length, 9);
    });

    testWidgets('pickerType decides what is offered', (tester) async {
      await pump(tester, {
        'type': 'colorPicker',
        'value': '#FF0000',
        'pickerType': 'palette',
      });
      final paletteSwatches = tester.widgetList(find.byType(InkWell)).length;

      await pump(tester, {
        'type': 'colorPicker',
        'value': '#FF0000',
        'pickerType': 'wheel',
      });
      final wheelSwatches = tester.widgetList(find.byType(InkWell)).length;
      expect(wheelSwatches, lessThan(paletteSwatches),
          reason: 'every pickerType drew the same palette');
    });

    testWidgets('enableHistory remembers what was picked', (tester) async {
      await pump(
        tester,
        {
          'type': 'colorPicker',
          'binding': 'history.colour',
          'pickerType': 'palette',
          'enableHistory': true,
        },
        initialState: {
          'history': {'colour': '#000000'},
        },
      );
      final before = tester.widgetList(find.byType(InkWell)).length;
      await tester.tap(find.byType(InkWell).first);
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.widgetList(find.byType(InkWell)).length,
          greaterThan(before),
          reason: 'enableHistory: true kept no history');
    });
  });

  group('codeEditor', () {
    testWidgets('Tab indents by tabSize instead of leaving the field',
        (tester) async {
      await pump(tester, {
        'type': 'codeEditor',
        'value': '',
        'language': 'dart',
        'tabSize': 4,
      });

      await tester.tap(find.byType(TextField));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump(const Duration(milliseconds: 350));

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, '    ',
          reason: 'Tab in a code editor must indent, by the declared amount');
    });
  });
}
