/// Input widgets showcase: button, textInput, select, toggle, slider,
/// checkbox, radio, form.
Map<String, dynamic> inputPage() => {
      'type': 'page',
      'metadata': {'title': 'Input', 'description': 'Input widget showcase'},
      'state': {
        'initial': {
          'counter': 0,
          'sliderValue': 50,
          'toggleValue': false,
          'selectedOption': 'option1',
          'formName': '',
          'formEmail': '',
          'formResult': '',
        },
      },
      'content': {
        'type': 'singleChildScrollView',
        'padding': {'all': 16},
        'child': {
          'type': 'linear',
          'direction': 'vertical',
          'spacing': 16,
          'children': [
            _section('button variants'),
            {
              'type': 'wrap',
              'spacing': 8,
              'runSpacing': 8,
              'children': [
                {'type': 'button', 'label': 'Filled', 'variant': 'filled', 'onTap': {'type': 'tool', 'tool': 'increment', 'params': {}}},
                {'type': 'button', 'label': 'Elevated', 'variant': 'elevated', 'onTap': {'type': 'tool', 'tool': 'increment', 'params': {}}},
                {'type': 'button', 'label': 'Outlined', 'variant': 'outlined', 'onTap': {'type': 'tool', 'tool': 'increment', 'params': {}}},
                {'type': 'button', 'label': 'Text', 'variant': 'text', 'onTap': {'type': 'tool', 'tool': 'increment', 'params': {}}},
              ],
            },
            {'type': 'text', 'content': 'Counter: {{counter}}', 'style': {'fontSize': 14}},

            _section('counter (+/- buttons)'),
            {
              'type': 'linear',
              'direction': 'horizontal',
              'spacing': 8,
              'alignment': 'center',
              'children': [
                {'type': 'button', 'label': ' - ', 'variant': 'filled', 'onTap': {'type': 'tool', 'tool': 'decrement', 'params': {}}},
                {'type': 'text', 'content': '{{counter}}', 'style': {'fontSize': 32, 'fontWeight': 'bold'}},
                {'type': 'button', 'label': ' + ', 'variant': 'filled', 'onTap': {'type': 'tool', 'tool': 'increment', 'params': {}}},
                {'type': 'button', 'label': 'Reset', 'variant': 'outlined', 'onTap': {'type': 'tool', 'tool': 'reset', 'params': {}}},
              ],
            },

            _section('textInput'),
            {
              'type': 'textInput',
              'label': 'Name',
              'placeholder': 'Enter your name',
              'binding': 'formName',
            },
            {
              'type': 'textInput',
              'label': 'Email',
              'placeholder': 'user@example.com',
              'inputType': 'email',
              'binding': 'formEmail',
            },

            _section('select (dropdown)'),
            {
              'type': 'select',
              'label': 'Choose option',
              'binding': 'selectedOption',
              'options': [
                {'value': 'option1', 'label': 'Option A'},
                {'value': 'option2', 'label': 'Option B'},
                {'value': 'option3', 'label': 'Option C'},
              ],
            },
            {'type': 'text', 'content': 'Selected: {{selectedOption}}', 'style': {'fontSize': 12, 'color': '#666666'}},

            _section('toggle'),
            {
              'type': 'toggle',
              'label': 'Enable notifications',
              'binding': 'toggleValue',
            },
            {'type': 'text', 'content': 'Toggle: {{toggleValue}}', 'style': {'fontSize': 12, 'color': '#666666'}},

            _section('slider'),
            {
              'type': 'slider',
              'min': 0,
              'max': 100,
              'value': '{{sliderValue}}',
              'binding': 'sliderValue',
            },
            {'type': 'text', 'content': 'Value: {{sliderValue}}', 'style': {'fontSize': 12, 'color': '#666666'}},

            _section('checkbox'),
            {
              'type': 'checkbox',
              'label': 'I agree to the terms',
              'binding': 'toggleValue',
            },

            _section('form submit'),
            {
              'type': 'button',
              'label': 'Submit form',
              'variant': 'filled',
              'onTap': {
                'type': 'tool',
                'tool': 'submitForm',
                'params': {
                  'name': '{{formName}}',
                  'email': '{{formEmail}}',
                },
              },
            },
            {
              'type': 'text',
              'content': '{{formResult}}',
              'style': {'fontSize': 14, 'color': '#4CAF50'},
            },

            {'type': 'sizedBox', 'height': 24},
          ],
        },
      },
    };

Map<String, dynamic> _section(String title) => {
      'type': 'text',
      'content': title,
      'style': {'fontSize': 16, 'fontWeight': 'bold', 'color': '#2196F3'},
    };
