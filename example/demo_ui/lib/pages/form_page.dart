/// Form widgets showcase: form, radioGroup, checkboxGroup,
/// segmentedControl, numberField, dateField, timePicker, textFormField.
Map<String, dynamic> formPage() => {
      'type': 'page',
      'metadata': {'title': 'Form', 'description': 'Form widget showcase'},
      'state': {
        'initial': {
          'gender': 'male',
          'interests': <String>[],
          'viewMode': 'grid',
          'quantity': 1,
          'rating': 3,
          'formName': '',
          'formEmail': '',
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
            _section('radioGroup'),
            {
              'type': 'radioGroup',
              'label': 'Gender',
              'binding': 'gender',
              'options': [
                {'value': 'male', 'label': 'Male'},
                {'value': 'female', 'label': 'Female'},
                {'value': 'other', 'label': 'Other'},
              ],
            },
            {'type': 'text', 'content': 'Selected: {{gender}}', 'style': {'fontSize': 12, 'color': '#666666'}},

            _section('checkboxGroup'),
            {
              'type': 'checkboxGroup',
              'label': 'Interests',
              'binding': 'interests',
              'options': [
                {'value': 'flutter', 'label': 'Flutter'},
                {'value': 'mcp', 'label': 'MCP'},
                {'value': 'ai', 'label': 'AI'},
                {'value': 'web', 'label': 'Web'},
              ],
            },

            _section('segmentedControl'),
            {
              'type': 'segmentedControl',
              'binding': 'viewMode',
              'options': [
                {'value': 'grid', 'label': 'Grid'},
                {'value': 'list', 'label': 'List'},
                {'value': 'card', 'label': 'Card'},
              ],
            },
            {'type': 'text', 'content': 'Mode: {{viewMode}}', 'style': {'fontSize': 12, 'color': '#666666'}},

            _section('numberField'),
            {
              'type': 'numberField',
              'label': 'Quantity',
              'binding': 'quantity',
              'min': 0,
              'max': 100,
            },

            _section('textFormField (with validation)'),
            {
              'type': 'form',
              'children': [
                {
                  'type': 'textFormField',
                  'label': 'Name',
                  'placeholder': 'Enter name',
                  'binding': 'formName',
                  'validation': [
                    {'rule': 'required', 'message': 'Name is required'},
                  ],
                },
                {'type': 'sizedBox', 'height': 8},
                {
                  'type': 'textFormField',
                  'label': 'Email',
                  'placeholder': 'user@example.com',
                  'inputType': 'email',
                  'binding': 'formEmail',
                  'validation': [
                    {'rule': 'required', 'message': 'Email is required'},
                    {'rule': 'email', 'message': 'Invalid email format'},
                  ],
                },
                {'type': 'sizedBox', 'height': 12},
                {
                  'type': 'button',
                  'label': 'Submit',
                  'variant': 'filled',
                  'onTap': {
                    'type': 'tool',
                    'tool': 'submitForm',
                    'params': {'name': '{{formName}}', 'email': '{{formEmail}}'},
                  },
                },
              ],
            },

            _section('dateField'),
            {
              'type': 'dateField',
              'label': 'Select date',
              'binding': 'selectedDate',
            },

            _section('timePicker'),
            {
              'type': 'timePicker',
              'label': 'Select time',
              'binding': 'selectedTime',
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
