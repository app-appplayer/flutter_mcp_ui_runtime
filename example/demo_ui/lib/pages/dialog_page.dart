/// Dialog widgets showcase: alertDialog, snackBar, bottomSheet.
Map<String, dynamic> dialogPage() => {
      'type': 'page',
      'metadata': {'title': 'Dialog', 'description': 'Dialog widget showcase'},
      'state': {
        'initial': {'dialogResult': ''},
      },
      'content': {
        'type': 'singleChildScrollView',
        'padding': {'all': 16},
        'child': {
          'type': 'linear',
          'direction': 'vertical',
          'spacing': 16,
          'children': [
            _section('alertDialog'),
            {
              'type': 'button',
              'label': 'Show Alert Dialog',
              'variant': 'filled',
              'onTap': {
                'type': 'dialog',
                'dialog': {
                  'type': 'alertDialog',
                  'title': 'Alert',
                  'content': 'This is an alert dialog example.',
                  'actions': [
                    {
                      'label': 'Cancel',
                      'onTap': {'type': 'state', 'action': 'set', 'binding': 'dialogResult', 'value': 'Cancelled'},
                    },
                    {
                      'label': 'OK',
                      'onTap': {'type': 'state', 'action': 'set', 'binding': 'dialogResult', 'value': 'Confirmed'},
                    },
                  ],
                },
              },
            },
            {'type': 'text', 'content': 'Result: {{dialogResult}}', 'style': {'fontSize': 12, 'color': '#666666'}},

            _section('snackBar'),
            {
              'type': 'button',
              'label': 'Show SnackBar',
              'variant': 'outlined',
              'onTap': {
                'type': 'notification',
                'message': 'This is a snackbar message!',
              },
            },

            _section('bottomSheet'),
            {
              'type': 'button',
              'label': 'Show Bottom Sheet',
              'variant': 'outlined',
              'onTap': {
                'type': 'dialog',
                'dialog': {
                  'type': 'bottomSheet',
                  'content': {
                    'type': 'box',
                    'padding': {'all': 24},
                    'child': {
                      'type': 'linear',
                      'direction': 'vertical',
                      'spacing': 12,
                      'children': [
                        {'type': 'text', 'content': 'Bottom Sheet', 'style': {'fontSize': 20, 'fontWeight': 'bold'}},
                        {'type': 'text', 'content': 'This is a bottom sheet with custom content.'},
                        {'type': 'divider'},
                        {
                          'type': 'listTile',
                          'leading': {'type': 'icon', 'icon': 'share'},
                          'title': {'type': 'text', 'content': 'Share'},
                        },
                        {
                          'type': 'listTile',
                          'leading': {'type': 'icon', 'icon': 'link'},
                          'title': {'type': 'text', 'content': 'Copy link'},
                        },
                        {
                          'type': 'listTile',
                          'leading': {'type': 'icon', 'icon': 'delete'},
                          'title': {'type': 'text', 'content': 'Delete'},
                        },
                      ],
                    },
                  },
                },
              },
            },

            _section('simpleDialog'),
            {
              'type': 'button',
              'label': 'Show Simple Dialog',
              'variant': 'outlined',
              'onTap': {
                'type': 'dialog',
                'dialog': {
                  'type': 'simpleDialog',
                  'title': 'Select option',
                  'options': [
                    {'label': 'Option A', 'value': 'a'},
                    {'label': 'Option B', 'value': 'b'},
                    {'label': 'Option C', 'value': 'c'},
                  ],
                  'onSelect': {'type': 'state', 'action': 'set', 'binding': 'dialogResult', 'value': '{{event.value}}'},
                },
              },
            },
            {'type': 'text', 'content': 'Selected: {{dialogResult}}', 'style': {'fontSize': 12, 'color': '#666666'}},

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
