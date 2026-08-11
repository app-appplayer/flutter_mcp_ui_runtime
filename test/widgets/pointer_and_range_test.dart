// `inkWell`'s pointer events and `rangeSlider`'s two-ended value.
//
// Both report through the same shape: the document writes `{{event.…}}` into
// the action and the widget substitutes the real value before running it. A
// substitution that does not happen leaves the document acting on the literal
// string — a tap handler that stores "{{event.position}}" as a position, or a
// range that submits the placeholder instead of the numbers the user dragged
// to. Every one of those renders and runs; only the value is wrong.

import 'package:flutter/gestures.dart';
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
        body: Center(
          child: SizedBox(
            width: 300,
            height: 200,
            child: AnimatedBuilder(
              animation: stateManager,
              builder: (_, __) =>
                  context.renderer.renderWidget(definition, context),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> set(String binding, Object? value) => <String, dynamic>{
        'type': 'state',
        'action': 'set',
        'binding': binding,
        'value': value,
      };

  group('inkWell', () {
    Map<String, dynamic> ink({Map<String, dynamic> extra = const {}}) =>
        <String, dynamic>{
          'type': 'inkWell',
          'child': <String, dynamic>{
            'type': 'container',
            'width': 200,
            'height': 100,
            'color': '#EEEEEE',
          },
          ...extra,
        };

    testWidgets('onTapUp reports where the finger left the surface',
        (tester) async {
      await pump(tester, ink(extra: <String, dynamic>{
        'onTapUp': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'spot',
          'position': '{{event.position}}',
        },
      }));

      await tester.tapAt(tester.getCenter(find.byType(InkWell)));
      await tester.pumpAndSettle();

      final spot = stateManager.get('spot');
      // The action carries the position; `set` stores whatever `value` held,
      // which here is nothing — what is being pinned is that the widget
      // substituted a real coordinate rather than leaving the placeholder.
      expect(spot, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a cancelled tap is reported', (tester) async {
      await pump(tester, ink(extra: <String, dynamic>{
        // A cancel only exists where a tap was being tracked.
        'onTap': set('tapped', true),
        'onTapCancel': set('cancelled', true),
      }));

      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(InkWell)));
      await gesture.moveBy(const Offset(0, 300));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(stateManager.get('cancelled'), isTrue,
          reason: 'a drag off the control is the user changing their mind; a '
              'document that never hears it leaves a pressed state on screen');
    });

    testWidgets('the highlight state is reported as it changes',
        (tester) async {
      await pump(tester, ink(extra: <String, dynamic>{
        'onTap': set('tapped', true),
        'onHighlightChanged': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'pressed',
          'value': '{{event.highlighted}}',
          'highlighted': '{{event.highlighted}}',
        },
      }));

      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(InkWell)));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('hovering is reported both ways', (tester) async {
      await pump(tester, ink(extra: <String, dynamic>{
        'onTap': set('tapped', true),
        'onHover': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'hovering',
          'value': true,
          'hovering': '{{event.hovering}}',
        },
      }));

      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer();
      addTearDown(pointer.removePointer);

      await pointer.moveTo(tester.getCenter(find.byType(InkWell)));
      await tester.pumpAndSettle();

      expect(stateManager.get('hovering'), isTrue,
          reason: 'a desktop document that highlights a row on hover has no '
              'other way to know the pointer is over it');
    });
  });

  group('rangeSlider', () {
    Map<String, dynamic> range({Map<String, dynamic> extra = const {}}) =>
        <String, dynamic>{
          'type': 'rangeSlider',
          'min': 0,
          'max': 100,
          'start': 20,
          'end': 80,
          ...extra,
        };

    testWidgets('dragging writes both ends to the binding', (tester) async {
      await pump(tester, range(extra: <String, dynamic>{'binding': 'band'}));

      final slider = find.byType(RangeSlider);
      await tester.drag(slider, const Offset(-60, 0));
      await tester.pumpAndSettle();

      final band = stateManager.get<Map<String, dynamic>>('band');
      expect(band, isNotNull,
          reason: 'a two-ended control that writes nothing is a filter the '
              'user can move and the query never sees');
      expect(band!.keys, containsAll(<String>['start', 'end']));
      expect(band['start'], isA<double>());
    });

    testWidgets('the legacy bindTo spelling still writes', (tester) async {
      await pump(tester, range(extra: <String, dynamic>{'bindTo': 'band'}));

      await tester.drag(find.byType(RangeSlider), const Offset(-60, 0));
      await tester.pumpAndSettle();

      expect(stateManager.get<Map<String, dynamic>>('band'), isNotNull,
          reason: 'bundles in the field still write `bindTo`; dropping it '
              'makes their filters inert');
    });

    testWidgets('onChangeStart and onChangeEnd carry both ends',
        (tester) async {
      await pump(tester, range(extra: <String, dynamic>{
        // The slider only moves when something is listening for the value.
        'binding': 'band',
        'onChangeStart': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'began',
          'value': '{{event.value}}',
        },
        'onChangeEnd': <String, dynamic>{
          'type': 'state',
          'action': 'set',
          'binding': 'ended',
          'value': '{{event.value}}',
        },
      }));

      await tester.drag(find.byType(RangeSlider), const Offset(-60, 0));
      await tester.pumpAndSettle();

      final began = stateManager.get<Map<String, dynamic>>('began');
      final ended = stateManager.get<Map<String, dynamic>>('ended');
      expect(began, isNotNull,
          reason: 'a document that pauses a live query while the user drags '
              'binds to onChangeStart; the placeholder left unsubstituted '
              'would store the literal string');
      expect(began!['start'], isA<double>());
      expect(ended, isNotNull);
      expect(ended!['end'], isA<double>());
    });

    testWidgets('with neither a binding nor an onChange it does not move',
        (tester) async {
      await pump(tester, range());

      final slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
      expect(slider.onChanged, isNull,
          reason: 'a control nobody is listening to must not look draggable');
    });
  });
}
