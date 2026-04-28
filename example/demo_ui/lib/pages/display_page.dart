/// Display widgets showcase: text, icon, image, card, badge, chip,
/// avatar, divider, progressBar, banner, tooltip.
Map<String, dynamic> displayPage() => {
      'type': 'page',
      'metadata': {'title': 'Display', 'description': 'Display widget showcase'},
      'content': {
        'type': 'singleChildScrollView',
        'padding': {'all': 16},
        'child': {
          'type': 'linear',
          'direction': 'vertical',
          'spacing': 16,
          'children': [
            _section('text'),
            {
              'type': 'text',
              'content': 'Regular body text',
              'style': {'fontSize': 16},
            },
            {
              'type': 'text',
              'content': 'Bold heading',
              'style': {'fontSize': 24, 'fontWeight': 'bold', 'color': '#2196F3'},
            },

            _section('icon'),
            {
              'type': 'linear',
              'direction': 'horizontal',
              'spacing': 16,
              'children': [
                {'type': 'icon', 'icon': 'home', 'size': 24, 'color': '#2196F3'},
                {'type': 'icon', 'icon': 'settings', 'size': 24, 'color': '#FF4081'},
                {'type': 'icon', 'icon': 'favorite', 'size': 24, 'color': '#F44336'},
                {'type': 'icon', 'icon': 'star', 'size': 24, 'color': '#FFC107'},
                {'type': 'icon', 'icon': 'check_circle', 'size': 24, 'color': '#4CAF50'},
              ],
            },

            _section('card'),
            {
              'type': 'card',
              'child': {
                'type': 'box',
                'padding': {'all': 16},
                'child': {
                  'type': 'linear',
                  'direction': 'vertical',
                  'spacing': 8,
                  'children': [
                    {'type': 'text', 'content': 'Card Title', 'style': {'fontSize': 18, 'fontWeight': 'bold'}},
                    {'type': 'text', 'content': 'Card content with description text.', 'style': {'fontSize': 14, 'color': '#666666'}},
                  ],
                },
              },
            },

            _section('badge'),
            {
              'type': 'linear',
              'direction': 'horizontal',
              'spacing': 24,
              'children': [
                {'type': 'badge', 'value': '3', 'child': {'type': 'icon', 'icon': 'mail', 'size': 28}},
                {'type': 'badge', 'value': '99+', 'child': {'type': 'icon', 'icon': 'notifications', 'size': 28}},
              ],
            },

            _section('chip'),
            {
              'type': 'wrap',
              'spacing': 8,
              'children': [
                {'type': 'chip', 'label': 'Flutter'},
                {'type': 'chip', 'label': 'MCP'},
                {'type': 'chip', 'label': 'UI DSL'},
                {'type': 'chip', 'label': 'Dart'},
              ],
            },

            _section('avatar'),
            {
              'type': 'linear',
              'direction': 'horizontal',
              'spacing': 12,
              'children': [
                {'type': 'avatar', 'label': 'AB', 'size': 40, 'backgroundColor': '#2196F3'},
                {'type': 'avatar', 'label': 'CD', 'size': 40, 'backgroundColor': '#FF4081'},
                {'type': 'avatar', 'label': 'EF', 'size': 40, 'backgroundColor': '#4CAF50'},
              ],
            },

            _section('divider'),
            {'type': 'divider'},

            _section('progressBar'),
            {
              'type': 'linear',
              'direction': 'vertical',
              'spacing': 12,
              'children': [
                {'type': 'progressBar', 'value': 0.7, 'indicatorType': 'linear'},
                {'type': 'text', 'content': '70%', 'style': {'fontSize': 12, 'color': '#666666'}},
              ],
            },

            _section('loadingIndicator'),
            {
              'type': 'linear',
              'direction': 'horizontal',
              'spacing': 24,
              'children': [
                {'type': 'loadingIndicator'},
                {'type': 'text', 'content': 'Loading...', 'style': {'fontSize': 14}},
              ],
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
