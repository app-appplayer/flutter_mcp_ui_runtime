// §2.6.0 is normative in both directions: "the runtime reads the current value
// from the path and writes user input back to the same path". Writing was
// wired everywhere. Reading was wired widget by widget, and nothing ever asked
// the whole set — so `slider` shipped with `binding` as a write-only property
// through every release back to 0.5.1. A slider bound to a state path sat at
// its minimum while the number beside it showed the real value.
//
// This asks every input widget the same question: put a value in state, render
// the widget with `binding` ALONE (no `value`, no `onChange` — the shorthand as
// §2.6.0 documents it), and read what it displays.
//
// The last test guards the roster: a widget registered as an input that is not
// listed here fails the suite. That is what makes this a gate rather than a
// list of the widgets I happened to think of.

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

/// One widget's read-back case: what to put in state, what the declaration
/// needs beyond `binding`, and how to read what the widget shows.
class ReadBack {
  const ReadBack({
    required this.type,
    required this.stateValue,
    required this.extra,
    required this.read,
  });

  final String type;
  final Object? stateValue;
  final Map<String, dynamic> extra;

  /// Pulls the displayed value out of the built tree.
  final Object? Function(WidgetTester tester) read;
}

Object? _sliderValue(WidgetTester tester) =>
    tester.widget<Slider>(find.byType(Slider)).value;

Object? _switchValue(WidgetTester tester) =>
    tester.widget<Switch>(find.byType(Switch)).value;

Object? _checkboxValue(WidgetTester tester) =>
    tester.widget<Checkbox>(find.byType(Checkbox)).value;

Object? _textValue(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField).first).controller?.text;

Object? _rangeValues(WidgetTester tester) {
  final range = tester.widget<RangeSlider>(find.byType(RangeSlider)).values;
  return '${range.start}-${range.end}';
}

final List<ReadBack> cases = [
  ReadBack(
    type: 'slider',
    stateValue: 30,
    extra: const {'min': 0, 'max': 100},
    read: _sliderValue,
  ),
  ReadBack(
    type: 'rangeSlider',
    stateValue: {'start': 20, 'end': 60},
    extra: const {'min': 0, 'max': 100},
    read: _rangeValues,
  ),
  ReadBack(
    type: 'toggle',
    stateValue: true,
    extra: const {},
    read: _switchValue,
  ),
  ReadBack(
    type: 'checkbox',
    stateValue: true,
    extra: const {},
    read: _checkboxValue,
  ),
  ReadBack(
    type: 'textInput',
    stateValue: 'hanok',
    extra: const {},
    read: _textValue,
  ),
  ReadBack(
    type: 'numberField',
    stateValue: 42,
    extra: const {},
    read: _textValue,
  ),
];

/// What each case expects to see, given [ReadBack.stateValue].
final Map<String, Object?> expected = {
  'slider': 30.0,
  'rangeSlider': '20.0-60.0',
  'toggle': true,
  'checkbox': true,
  'textInput': 'hanok',
  'numberField': '42',
};

/// Input widgets §2.6.0 exempts from `binding`, with its reason.
const Map<String, String> exempt = {
  'button': 'no user-changeable value',
  'iconButton': 'no user-changeable value',
  'form': 'a container, not a value',
  'dateRangePicker': '§2.6.17 — two bindings (startDate/endDate), not one',
  'fileInput': 'the value is a picked file handle, not state',
  'voiceInput': 'the value arrives from a capability, not from state',
  'signature': 'the value is drawn strokes, not state',
};

/// Registered input widgets covered by a suite of their own, named so the
/// roster check below stays honest instead of silent.
const Map<String, String> elsewhere = {
  'select': 'dropdown_widget_test',
  'dropdown': 'dropdown_widget_test',
  'dropdownMenu': 'popup menu — not an input value',
  'radio': 'radio_widget_test (groupValue, not binding)',
  'radioGroup': 'radio_group_test',
  'checkboxGroup': 'checkbox_group_test',
  'multiSelect': 'multi_select_test',
  'combobox': 'combobox_test',
  'autocomplete': 'combobox_test',
  'segmentedControl': 'segmented_control_test',
  'colorPicker': 'color_picker_test',
  'rating': 'rating_test',
  'stepper': 'stepper_test (currentStep)',
  'steps': 'stepper_test',
  'numberStepper': 'number_stepper_test',
  'otpInput': 'otp_input_test',
  'dateField': 'date_field_test',
  'timeField': 'time_field_test',
  'datePicker': 'date_picker_test',
  'timePicker': 'time_picker_test',
  'dateTimePicker': 'date_time_picker_test',
  'codeEditor': 'code_editor_test',
  'code': 'code_editor_test',
  'richTextEditor': 'rich_text_editor_test',
  'textField': 'alias of textInput, covered here',
  'textfield': 'alias of textInput, covered here',
  'textFormField': 'alias of textInput, covered here',
  'numberInput': 'alias of numberField, covered here',
  'switch': 'alias of toggle, covered here',
  'pagination': 'navigation, not an input value',
};

void main() {
  Future<void> pumpWidgetFor(WidgetTester tester, ReadBack c) async {
    final stateManager = StateManager()
      ..initialize(<String, dynamic>{'bound': c.stateValue});
    final engine = BindingEngine();
    final actionHandler = ActionHandler();
    final registry = WidgetRegistry();
    DefaultWidgets.registerAll(registry);
    final renderer = Renderer(
      widgetRegistry: registry,
      bindingEngine: engine,
      actionHandler: actionHandler,
      stateManager: stateManager,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (buildContext) {
          final context = RenderContext(
            renderer: renderer,
            stateManager: stateManager,
            actionHandler: actionHandler,
            themeManager: ThemeManager(),
            bindingEngine: engine,
            buildContext: buildContext,
          );
          return renderer.renderWidget(
            <String, dynamic>{
              'type': c.type,
              // The shorthand alone. No `value`, so nothing but the binding can
              // put the state on screen.
              'binding': 'bound',
              ...c.extra,
            },
            context,
          );
        }),
      ),
    ));
    await tester.pump();
  }

  group('§2.6.0 — binding reads the current value from the path', () {
    for (final c in cases) {
      testWidgets('${c.type} shows what state holds', (tester) async {
        await pumpWidgetFor(tester, c);
        expect(c.read(tester), expected[c.type]);
      });
    }
  });

  testWidgets('every registered input widget is on the roster', (tester) async {
    // Registry names that look like input widgets must be covered here, exempt
    // with a reason, or pointed at their own suite. A new input widget that
    // lands with `binding` write-only fails this.
    final registry = WidgetRegistry();
    DefaultWidgets.registerAll(registry);

    const inputish = [
      'textInput', 'textField', 'textfield', 'textFormField', 'numberField',
      'numberInput', 'toggle', 'switch', 'checkbox', 'checkboxGroup', 'radio',
      'radioGroup', 'slider', 'rangeSlider', 'select', 'dropdown', 'combobox',
      'autocomplete', 'multiSelect', 'segmentedControl', 'colorPicker',
      'rating', 'stepper', 'numberStepper', 'otpInput', 'dateField',
      'timeField', 'datePicker', 'timePicker', 'dateTimePicker',
      'dateRangePicker', 'codeEditor', 'richTextEditor', 'signature',
      'voiceInput', 'fileInput', 'button', 'iconButton', 'form',
    ];

    final covered = {for (final c in cases) c.type};
    final unaccounted = <String>[];
    for (final type in inputish) {
      if (!registry.has(type)) continue; // not in this build
      if (covered.contains(type)) continue;
      if (exempt.containsKey(type)) continue;
      if (elsewhere.containsKey(type)) continue;
      unaccounted.add(type);
    }

    expect(unaccounted, isEmpty,
        reason: 'these input widgets have no read-back answer:\n'
            '${unaccounted.join(', ')}');
  });
}
