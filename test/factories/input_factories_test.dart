// Input widget factory tests: TC-203 through TC-225
// Covers button, textInput, select, toggle, slider, checkbox, numberField,
// dateField, timeField, radioGroup, checkboxGroup, radio, colorPicker,
// dateRangePicker, segmentedControl, rangeSlider, iconButton, form,
// textFormField, datePicker, timePicker, stepper, and numberStepper.

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

  // Helper to pump a page definition through the runtime
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

  // ===========================================================================
  // TC-203: ButtonWidgetFactory
  // ===========================================================================
  group('TC-203: ButtonWidgetFactory', () {
    testWidgets('TC-203a: renders button with label and variant',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'button',
        'label': 'Click Me',
        'variant': 'elevated',
      });
      expect(find.text('Click Me'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('TC-203b: renders disabled button with no action',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'button',
        'label': '',
        'disabled': true,
      });
      // Empty label still renders a button
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ===========================================================================
  // TC-204: TextInputWidgetFactory (textField / textInput)
  // ===========================================================================
  group('TC-204: TextInputWidgetFactory', () {
    testWidgets('TC-204a: renders textInput with placeholder and label',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'textInput',
        'label': 'Username',
        'placeholder': 'Enter username',
      });
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('TC-204b: textInput with binding and validation',
        (tester) async {
      await pumpPage(
        tester,
        content: {
          'type': 'textInput',
          'label': 'Email',
          'value': '{{email}}',
          'binding': 'email',
          'validation': {
            'required': true,
          },
        },
        initialState: {'email': 'user@test.com'},
      );
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  // ===========================================================================
  // TC-205: DropdownWidgetFactory (select)
  // ===========================================================================
  group('TC-205: DropdownWidgetFactory', () {
    testWidgets('TC-205a: renders select with options and value',
        (tester) async {
      await pumpPage(
        tester,
        content: {
          'type': 'select',
          'value': 'opt1',
          'options': [
            {'value': 'opt1', 'label': 'Option 1'},
            {'value': 'opt2', 'label': 'Option 2'},
            {'value': 'opt3', 'label': 'Option 3'},
          ],
          'binding': 'selected',
        },
        initialState: {'selected': 'opt1'},
      );
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-205b: select with empty options list', (tester) async {
      await pumpPage(tester, content: {
        'type': 'select',
        'options': <Map<String, dynamic>>[],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ===========================================================================
  // TC-206: SwitchWidgetFactory (toggle)
  // ===========================================================================
  group('TC-206: SwitchWidgetFactory', () {
    testWidgets('TC-206a: renders toggle with value binding', (tester) async {
      await pumpPage(
        tester,
        content: {
          'type': 'toggle',
          'value': '{{enabled}}',
          'binding': 'enabled',
        },
        initialState: {'enabled': true},
      );
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('TC-206b: toggle with false value', (tester) async {
      await pumpPage(
        tester,
        content: {
          'type': 'toggle',
          'value': '{{enabled}}',
          'binding': 'enabled',
        },
        initialState: {'enabled': false},
      );
      expect(find.byType(Switch), findsOneWidget);
    });
  });

  // ===========================================================================
  // TC-207: SliderWidgetFactory
  // ===========================================================================
  group('TC-207: SliderWidgetFactory', () {
    testWidgets('TC-207a: renders slider with min, max, value', (tester) async {
      await pumpPage(tester, content: {
        'type': 'slider',
        'min': 0,
        'max': 100,
        'value': 50,
      });
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('TC-207b: slider with binding and boundary values',
        (tester) async {
      await pumpPage(
        tester,
        content: {
          'type': 'slider',
          'min': 0,
          'max': 1,
          'value': '{{volume}}',
          'binding': 'volume',
        },
        initialState: {'volume': 0},
      );
      expect(find.byType(Slider), findsOneWidget);
    });
  });

  // ===========================================================================
  // TC-208: CheckboxWidgetFactory
  // ===========================================================================
  group('TC-208: CheckboxWidgetFactory', () {
    testWidgets('TC-208a: renders checkbox with value and label',
        (tester) async {
      await pumpPage(
        tester,
        content: {
          'type': 'checkbox',
          'value': '{{agreed}}',
          'binding': 'agreed',
          'label': 'I agree to terms',
          'onChange': {
            'type': 'state',
            'action': 'set',
            'binding': 'agreed',
            'value': '{{event.value}}',
          },
        },
        initialState: {'agreed': false},
      );
      // With label, CheckboxListTile is used
      expect(find.text('I agree to terms'), findsOneWidget);
    });

    testWidgets('TC-208b: checkbox without label', (tester) async {
      await pumpPage(
        tester,
        content: {
          'type': 'checkbox',
          'value': false,
        },
      );
      expect(find.byType(Checkbox), findsOneWidget);
    });
  });

  // ===========================================================================
  // TC-209: NumberFieldWidgetFactory
  // ===========================================================================
  group('TC-209: NumberFieldWidgetFactory', () {
    testWidgets('TC-209a: renders numberField with min, max, step',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'numberField',
        'label': 'Quantity',
        'min': 0,
        'max': 99,
        'step': 1,
        'value': 5,
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('TC-209b: numberField with zero value', (tester) async {
      await pumpPage(tester, content: {
        'type': 'numberField',
        'label': 'Count',
        'min': 0,
        'max': 10,
        'value': 0,
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ===========================================================================
  // TC-210: DateFieldWidgetFactory
  // ===========================================================================
  group('TC-210: DateFieldWidgetFactory', () {
    testWidgets('TC-210a: renders dateField with label', (tester) async {
      await pumpPage(tester, content: {
        'type': 'dateField',
        'label': 'Birthday',
      });
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('TC-210b: dateField with binding and date constraints',
        (tester) async {
      await pumpPage(
        tester,
        content: {
          'type': 'dateField',
          'label': 'Start Date',
          'binding': 'startDate',
          'firstDate': '2020-01-01',
          'lastDate': '2030-12-31',
        },
        initialState: {'startDate': '2024-06-15'},
      );
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  // ===========================================================================
  // TC-211: TimeFieldWidgetFactory
  // ===========================================================================
  group('TC-211: TimeFieldWidgetFactory', () {
    testWidgets('TC-211a: renders timeField with label', (tester) async {
      await pumpPage(tester, content: {
        'type': 'timeField',
        'label': 'Alarm Time',
      });
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('TC-211b: timeField with 24-hour format', (tester) async {
      await pumpPage(tester, content: {
        'type': 'timeField',
        'label': 'Meeting',
        'use24HourFormat': true,
      });
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  // ===========================================================================
  // TC-212: RadioGroupWidgetFactory
  // ===========================================================================
  group('TC-212: RadioGroupWidgetFactory', () {
    testWidgets('TC-212a: renders radioGroup with options and value',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'radioGroup',
        'value': 'a',
        'options': [
          {'value': 'a', 'label': 'Alpha'},
          {'value': 'b', 'label': 'Beta'},
          {'value': 'c', 'label': 'Gamma'},
        ],
      });
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Gamma'), findsOneWidget);
    });

    testWidgets('TC-212b: radioGroup with empty options', (tester) async {
      await pumpPage(tester, content: {
        'type': 'radioGroup',
        'value': '',
        'options': <Map<String, dynamic>>[],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ===========================================================================
  // TC-213: CheckboxGroupWidgetFactory
  // ===========================================================================
  group('TC-213: CheckboxGroupWidgetFactory', () {
    testWidgets('TC-213a: renders checkboxGroup with options', (tester) async {
      await pumpPage(tester, content: {
        'type': 'checkboxGroup',
        'options': [
          {'value': 'x', 'label': 'Option X'},
          {'value': 'y', 'label': 'Option Y'},
          {'value': 'z', 'label': 'Option Z'},
        ],
      });
      expect(find.text('Option X'), findsOneWidget);
      expect(find.text('Option Y'), findsOneWidget);
      expect(find.text('Option Z'), findsOneWidget);
    });

    testWidgets('TC-213b: checkboxGroup with empty options', (tester) async {
      await pumpPage(tester, content: {
        'type': 'checkboxGroup',
        'options': <Map<String, dynamic>>[],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ===========================================================================
  // TC-214: RadioWidgetFactory
  // ===========================================================================
  group('TC-214: RadioWidgetFactory', () {
    testWidgets('TC-214a: renders radio with value and groupValue',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'radio',
        'value': 'opt1',
        'groupValue': 'opt1',
      });
      expect(find.byType(Radio<dynamic>), findsOneWidget);
    });

    testWidgets('TC-214b: radio with unselected groupValue', (tester) async {
      await pumpPage(tester, content: {
        'type': 'radio',
        'value': 'opt1',
        'groupValue': 'opt2',
      });
      expect(find.byType(Radio<dynamic>), findsOneWidget);
    });
  });

  // ===========================================================================
  // TC-215: ColorPickerWidgetFactory
  // ===========================================================================
  group('TC-215: ColorPickerWidgetFactory', () {
    testWidgets('TC-215a: renders colorPicker with value', (tester) async {
      await pumpPage(tester, content: {
        'type': 'colorPicker',
        'value': '#FF0000',
      });
      // Color picker renders a Wrap with color swatches
      expect(find.byType(Wrap), findsOneWidget);
    });

    testWidgets('TC-215b: colorPicker with label and disabled state',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'colorPicker',
        'value': '#0000FF',
        'label': 'Pick a color',
        'enabled': false,
      });
      expect(find.text('Pick a color'), findsOneWidget);
    });
  });

  // ===========================================================================
  // TC-216: DateRangePickerWidgetFactory
  // ===========================================================================
  group('TC-216: DateRangePickerWidgetFactory', () {
    testWidgets('TC-216a: renders dateRangePicker with label', (tester) async {
      await pumpPage(tester, content: {
        'type': 'dateRangePicker',
        'label': 'Period',
      });
      // Should render with "Select date range" text when no dates set
      expect(find.text('Select date range'), findsOneWidget);
    });

    testWidgets('TC-216b: dateRangePicker with start and end bindings',
        (tester) async {
      await pumpPage(
        tester,
        content: {
          'type': 'dateRangePicker',
          'label': 'Trip Dates',
          'startBinding': 'tripStart',
          'endBinding': 'tripEnd',
        },
        initialState: {
          'tripStart': '2024-07-01',
          'tripEnd': '2024-07-15',
        },
      );
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ===========================================================================
  // TC-217: SegmentedControlWidgetFactory
  // ===========================================================================
  group('TC-217: SegmentedControlWidgetFactory', () {
    testWidgets('TC-217a: renders segmentedControl with segments and value',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'segmentedControl',
        'value': 'day',
        'options': [
          {'value': 'day', 'label': 'Day'},
          {'value': 'week', 'label': 'Week'},
          {'value': 'month', 'label': 'Month'},
        ],
      });
      expect(find.byType(SegmentedButton<String>), findsOneWidget);
    });

    testWidgets('TC-217b: segmentedControl with single segment',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'segmentedControl',
        'value': 'only',
        'options': [
          {'value': 'only', 'label': 'Only Option'},
        ],
      });
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // ===========================================================================
  // TC-218: RangeSliderWidgetFactory
  // ===========================================================================
  group('TC-218: RangeSliderWidgetFactory', () {
    testWidgets('TC-218a: renders rangeSlider with min, max, values',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'rangeSlider',
        'min': 0,
        'max': 100,
        'values': {'start': 20, 'end': 80},
      });
      expect(find.byType(RangeSlider), findsOneWidget);
    });

    testWidgets('TC-218b: rangeSlider with boundary values at extremes',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'rangeSlider',
        'min': 0,
        'max': 100,
        'values': {'start': 0, 'end': 100},
      });
      expect(find.byType(RangeSlider), findsOneWidget);
    });
  });

  // ===========================================================================
  // TC-219: IconButtonWidgetFactory
  // ===========================================================================
  group('TC-219: IconButtonWidgetFactory', () {
    testWidgets('TC-219a: renders iconButton with icon', (tester) async {
      await pumpPage(tester, content: {
        'type': 'iconButton',
        'icon': 'favorite',
      });
      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets('TC-219b: iconButton with tooltip and no action',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'iconButton',
        'icon': 'settings',
        'tooltip': 'Settings',
      });
      expect(find.byType(IconButton), findsOneWidget);
    });
  });

  // ===========================================================================
  // TC-220: FormWidgetFactory
  // ===========================================================================
  group('TC-220: FormWidgetFactory', () {
    testWidgets('TC-220a: renders form with children', (tester) async {
      await pumpPage(tester, content: {
        'type': 'form',
        'children': [
          {
            'type': 'textInput',
            'label': 'Name',
            'placeholder': 'Enter name',
          },
          {
            'type': 'button',
            'label': 'Submit',
          },
        ],
      });
      expect(find.text('Submit'), findsOneWidget);
      expect(find.byType(Form), findsOneWidget);
    });

    testWidgets('TC-220b: form with empty children list', (tester) async {
      await pumpPage(tester, content: {
        'type': 'form',
        'children': <Map<String, dynamic>>[],
      });
      expect(find.byType(Form), findsOneWidget);
    });
  });

  // ===========================================================================
  // TC-221: textFormField legacy alias routes to TextFieldWidgetFactory
  // (spec §17.3.1: textFormField is a legacy alias of textInput; §17.5.2:
  // runtimes MUST accept registered aliases)
  // ===========================================================================
  group('TC-221: textFormField alias → textInput factory', () {
    testWidgets('TC-221a: renders textFormField with validation',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'textFormField',
        'label': 'Email',
        'placeholder': 'Enter email',
        'validation': {
          'required': true,
          'email': true,
        },
      });
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('TC-221b: textFormField with obscureText for password',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'textFormField',
        'label': 'Password',
        'obscureText': true,
        'placeholder': 'Enter password',
      });
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  // ===========================================================================
  // TC-222: DatePickerWidgetFactory
  // ===========================================================================
  group('TC-222: DatePickerWidgetFactory', () {
    testWidgets('TC-222a: renders datePicker with default label',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'datePicker',
      });
      // Default label is 'Select Date'
      expect(find.text('Select Date'), findsOneWidget);
    });

    testWidgets('TC-222b: datePicker with custom label', (tester) async {
      await pumpPage(tester, content: {
        'type': 'datePicker',
        'label': 'Choose Birthday',
        'dateFormat': 'dd/MM/yyyy',
      });
      expect(find.text('Choose Birthday'), findsOneWidget);
    });
  });

  // ===========================================================================
  // TC-223: TimePickerWidgetFactory
  // ===========================================================================
  group('TC-223: TimePickerWidgetFactory', () {
    testWidgets('TC-223a: renders timePicker with default label',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'timePicker',
      });
      // Default label is 'Select Time'
      expect(find.text('Select Time'), findsOneWidget);
    });

    testWidgets('TC-223b: timePicker with custom label and 24-hour format',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'timePicker',
        'label': 'Set Alarm',
        'use24HourFormat': true,
      });
      expect(find.text('Set Alarm'), findsOneWidget);
    });
  });

  // ===========================================================================
  // TC-224: StepperWidgetFactory
  // ===========================================================================
  group('TC-224: StepperWidgetFactory', () {
    testWidgets('TC-224a: renders stepper with steps and currentStep',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'stepper',
        'currentStep': 0,
        'steps': [
          {
            'titleText': 'Step 1',
            'content': {'type': 'text', 'content': 'First step content'},
          },
          {
            'titleText': 'Step 2',
            'content': {'type': 'text', 'content': 'Second step content'},
          },
        ],
      });
      expect(find.byType(Stepper), findsOneWidget);
      expect(find.text('Step 1'), findsOneWidget);
    });

    testWidgets('TC-224b: stepper with single step', (tester) async {
      await pumpPage(tester, content: {
        'type': 'stepper',
        'currentStep': 0,
        'steps': [
          {
            'titleText': 'Only Step',
            'content': {'type': 'text', 'content': 'Content'},
          },
        ],
      });
      expect(find.byType(Stepper), findsOneWidget);
      expect(find.text('Only Step'), findsOneWidget);
    });
  });

  // ===========================================================================
  // TC-225: NumberStepperWidgetFactory
  // ===========================================================================
  group('TC-225: NumberStepperWidgetFactory', () {
    testWidgets('TC-225a: renders numberStepper with value, step, min, max',
        (tester) async {
      await pumpPage(tester, content: {
        'type': 'numberStepper',
        'value': 5,
        'step': 1,
        'min': 0,
        'max': 10,
      });
      // Displays the value as text
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('TC-225b: numberStepper at minimum boundary', (tester) async {
      await pumpPage(tester, content: {
        'type': 'numberStepper',
        'value': 0,
        'step': 1,
        'min': 0,
        'max': 100,
        'label': 'Quantity',
      });
      expect(find.text('0'), findsOneWidget);
      expect(find.text('Quantity'), findsOneWidget);
    });
  });

  // ===========================================================================
  // TC-226: Spec §2.6.0 binding shorthand contract
  // ===========================================================================
  // Input widgets with user-changeable values MUST support `binding` as a
  // standalone two-way shorthand: factory reads initial value from the state
  // path AND writes user changes back without requiring an explicit onChange.
  group('TC-226: §2.6.0 binding shorthand contract', () {
    testWidgets('TC-226a: toggle binding-only hydrates from state',
        (tester) async {
      await pumpPage(
        tester,
        content: {'type': 'toggle', 'binding': 'enabled'},
        initialState: {'enabled': true},
      );
      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.value, isTrue);
      expect(sw.onChanged, isNotNull);
    });

    testWidgets('TC-226b: toggle tap without onChange writes binding',
        (tester) async {
      await pumpPage(
        tester,
        content: {'type': 'toggle', 'binding': 'enabled'},
        initialState: {'enabled': false},
      );
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.value, isTrue);
    });

    testWidgets('TC-226c: checkbox binding-only hydrates from state',
        (tester) async {
      await pumpPage(
        tester,
        content: {'type': 'checkbox', 'binding': 'agreed'},
        initialState: {'agreed': true},
      );
      final cb = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(cb.value, isTrue);
      expect(cb.onChanged, isNotNull);
    });

    testWidgets('TC-226d: checkboxGroup top-level binding as array',
        (tester) async {
      await pumpPage(
        tester,
        content: {
          'type': 'checkboxGroup',
          'binding': 'interests',
          'options': [
            {'value': 'a', 'label': 'Alpha'},
            {'value': 'b', 'label': 'Beta'},
            {'value': 'c', 'label': 'Gamma'},
          ],
        },
        initialState: {
          'interests': ['a', 'c'],
        },
      );
      final tiles =
          tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile)).toList();
      expect(tiles.length, 3);
      expect(tiles[0].value, isTrue);
      expect(tiles[1].value, isFalse);
      expect(tiles[2].value, isTrue);
    });

    testWidgets('TC-226e: checkboxGroup toggle updates array binding',
        (tester) async {
      await pumpPage(
        tester,
        content: {
          'type': 'checkboxGroup',
          'binding': 'interests',
          'options': [
            {'value': 'a', 'label': 'Alpha'},
            {'value': 'b', 'label': 'Beta'},
          ],
        },
        initialState: {'interests': <String>[]},
      );
      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      final state = runtime.stateManager.state;
      expect(state['interests'], ['a']);
    });

    testWidgets('TC-226f: numberField binding hydrates and writes back',
        (tester) async {
      await pumpPage(
        tester,
        content: {
          'type': 'numberField',
          'binding': 'quantity',
          'min': 0,
          'max': 100,
        },
        initialState: {'quantity': 7},
      );
      expect(find.text('7'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '42');
      await tester.pump();
      expect(runtime.stateManager.state['quantity'], 42);
    });

    testWidgets('TC-226g: timePicker accepts canonical `binding`',
        (tester) async {
      await pumpPage(
        tester,
        content: {'type': 'timePicker', 'binding': 'selectedTime'},
        initialState: {'selectedTime': '09:30'},
      );
      expect(find.text('09:30'), findsOneWidget);
    });

    testWidgets('TC-226h: stepper binding hydrates currentStep',
        (tester) async {
      await pumpPage(
        tester,
        content: {
          'type': 'stepper',
          'binding': 'wizard.step',
          'steps': [
            {'titleText': 'Alpha', 'content': {'type': 'text', 'text': 'a'}},
            {'titleText': 'Beta', 'content': {'type': 'text', 'text': 'b'}},
            {'titleText': 'Gamma', 'content': {'type': 'text', 'text': 'c'}},
          ],
        },
        initialState: {
          'wizard': {'step': 1},
        },
      );
      final stepper = tester.widget<Stepper>(find.byType(Stepper));
      expect(stepper.currentStep, 1);
    });

    testWidgets('TC-226i: dateRangePicker separate startDate/endDate bindings',
        (tester) async {
      await pumpPage(
        tester,
        content: {
          'type': 'dateRangePicker',
          'startDate': 'filter.from',
          'endDate': 'filter.to',
          'label': 'Range',
        },
        initialState: {
          'filter': {'from': '2026-04-01', 'to': '2026-04-15'},
        },
      );
      expect(find.text('2026-04-01 - 2026-04-15'), findsOneWidget);
    });
  });
}
