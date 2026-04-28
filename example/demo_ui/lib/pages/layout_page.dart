/// Layout widgets showcase: linear, box, center, stack, padding, sizedBox,
/// expanded, flexible, spacer, wrap, conditional, visibility.
Map<String, dynamic> layoutPage() => {
      'type': 'page',
      'metadata': {'title': 'Layout', 'description': 'Layout widget showcase'},
      'content': {
        'type': 'singleChildScrollView',
        'padding': {'all': 16},
        'child': {
          'type': 'linear',
          'direction': 'vertical',
          'children': [
            _section('linear (vertical + horizontal)'),
            {
              'type': 'linear',
              'direction': 'horizontal',
              'spacing': 8,
              'children': [
                _colorBox('#2196F3', 'A', 60),
                _colorBox('#FF4081', 'B', 60),
                _colorBox('#4CAF50', 'C', 60),
              ],
            },
            _gap(16),

            _section('center'),
            {
              'type': 'box',
              'height': 80,
              'decoration': {'color': '#F5F5F5', 'borderRadius': 8},
              'child': {
                'type': 'center',
                'child': {'type': 'text', 'content': 'Centered content'},
              },
            },
            _gap(16),

            _section('stack + positioned'),
            {
              'type': 'box',
              'height': 120,
              'decoration': {'color': '#E3F2FD', 'borderRadius': 8},
              'child': {
                'type': 'stack',
                'children': [
                  {
                    'type': 'positioned',
                    'top': 8,
                    'left': 8,
                    'child': _colorBox('#2196F3', '1', 40),
                  },
                  {
                    'type': 'positioned',
                    'top': 30,
                    'left': 30,
                    'child': _colorBox('#FF4081', '2', 40),
                  },
                  {
                    'type': 'positioned',
                    'bottom': 8,
                    'right': 8,
                    'child': _colorBox('#4CAF50', '3', 40),
                  },
                ],
              },
            },
            _gap(16),

            _section('wrap'),
            {
              'type': 'wrap',
              'spacing': 8,
              'runSpacing': 8,
              'children': List.generate(
                  8,
                  (i) => {
                        'type': 'chip',
                        'label': 'Tag ${i + 1}',
                      }),
            },
            _gap(16),

            _section('expanded + flexible'),
            {
              'type': 'linear',
              'direction': 'horizontal',
              'children': [
                {
                  'type': 'expanded',
                  'flex': 2,
                  'child': _colorBox('#2196F3', 'flex:2', 40),
                },
                {'type': 'sizedBox', 'width': 8},
                {
                  'type': 'expanded',
                  'flex': 1,
                  'child': _colorBox('#FF4081', 'flex:1', 40),
                },
              ],
            },
            _gap(16),

            _section('conditional'),
            {
              'type': 'conditional',
              'condition': '{{darkMode}}',
              'then': {
                'type': 'text',
                'content': 'Dark mode is ON',
                'style': {'color': '#FF4081', 'fontWeight': 'bold'},
              },
              'else': {
                'type': 'text',
                'content': 'Dark mode is OFF',
                'style': {'color': '#2196F3'},
              },
            },
            {'type': 'sizedBox', 'height': 8},
            {
              'type': 'button',
              'label': 'Toggle dark mode',
              'variant': 'outlined',
              'onTap': {'type': 'tool', 'tool': 'toggleDarkMode', 'params': {}},
            },
            _gap(24),
          ],
        },
      },
      'state': {
        'initial': {'darkMode': false},
      },
    };

Map<String, dynamic> _section(String title) => {
      'type': 'box',
      'padding': {'vertical': 8},
      'child': {
        'type': 'text',
        'content': title,
        'style': {'fontSize': 16, 'fontWeight': 'bold', 'color': '#2196F3'},
      },
    };

Map<String, dynamic> _gap(double h) => {'type': 'sizedBox', 'height': h};

Map<String, dynamic> _colorBox(String color, String label, double size) => {
      'type': 'box',
      'width': size,
      'height': size,
      'decoration': {'color': color, 'borderRadius': 6},
      'child': {
        'type': 'center',
        'child': {
          'type': 'text',
          'content': label,
          'style': {'color': '#FFFFFF', 'fontWeight': 'bold'},
        },
      },
    };
