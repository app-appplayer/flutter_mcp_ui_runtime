/// Interactive & navigation widgets showcase: gestureDetector, inkWell,
/// tooltip, pageView, floatingActionButton, popupMenuButton, draggable.
Map<String, dynamic> interactivePage() => {
      'type': 'page',
      'metadata': {'title': 'Interactive', 'description': 'Interactive widget showcase'},
      'state': {
        'initial': {
          'tapCount': 0,
          'lastGesture': 'none',
          'menuChoice': '',
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
            _section('gestureDetector'),
            {
              'type': 'gestureDetector',
              'onTap': {'type': 'state', 'action': 'set', 'binding': 'lastGesture', 'value': 'tap'},
              'onDoubleTap': {'type': 'state', 'action': 'set', 'binding': 'lastGesture', 'value': 'double-tap'},
              'onLongPress': {'type': 'state', 'action': 'set', 'binding': 'lastGesture', 'value': 'long-press'},
              'child': {
                'type': 'box',
                'height': 80,
                'decoration': {'color': '#E3F2FD', 'borderRadius': 8},
                'child': {
                  'type': 'center',
                  'child': {
                    'type': 'text',
                    'content': 'Tap / Double-tap / Long-press here',
                    'style': {'fontSize': 14},
                  },
                },
              },
            },
            {'type': 'text', 'content': 'Last gesture: {{lastGesture}}', 'style': {'fontSize': 12, 'color': '#666666'}},

            _section('inkWell'),
            {
              'type': 'inkWell',
              'onTap': {'type': 'state', 'action': 'increment', 'binding': 'tapCount'},
              'child': {
                'type': 'box',
                'padding': {'all': 16},
                'decoration': {'color': '#FFF3E0', 'borderRadius': 8},
                'child': {
                  'type': 'text',
                  'content': 'Tap me (with ripple) — tapped {{tapCount}} times',
                },
              },
            },

            _section('tooltip'),
            {
              'type': 'tooltip',
              'message': 'This is a tooltip! Hover or long-press to see it.',
              'child': {
                'type': 'chip',
                'label': 'Hover for tooltip',
              },
            },

            _section('popupMenuButton'),
            {
              'type': 'popupMenuButton',
              'icon': 'more_vert',
              'items': [
                {'value': 'edit', 'label': 'Edit'},
                {'value': 'copy', 'label': 'Copy'},
                {'value': 'delete', 'label': 'Delete'},
              ],
              'onSelect': {'type': 'state', 'action': 'set', 'binding': 'menuChoice', 'value': '{{event.value}}'},
            },
            {'type': 'text', 'content': 'Menu choice: {{menuChoice}}', 'style': {'fontSize': 12, 'color': '#666666'}},

            _section('image'),
            {
              'type': 'image',
              'src': 'https://via.placeholder.com/200x100/2196F3/FFFFFF?text=MCP+UI',
              'width': 200,
              'height': 100,
              'fit': 'cover',
            },

            _section('placeholder'),
            {
              'type': 'placeholder',
              'fallbackWidth': 200,
              'fallbackHeight': 60,
            },

            _section('banner'),
            {
              'type': 'banner',
              'message': 'This is an info banner message.',
              'severity': 'info',
            },

            _section('rich text'),
            {
              'type': 'richText',
              'spans': [
                {'text': 'Rich ', 'style': {'fontWeight': 'bold'}},
                {'text': 'text ', 'style': {'color': '#2196F3'}},
                {'text': 'with ', 'style': {'fontStyle': 'italic'}},
                {'text': 'spans', 'style': {'color': '#FF4081', 'fontWeight': 'bold'}},
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
