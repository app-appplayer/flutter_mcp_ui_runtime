/// Advanced widgets showcase: canvas, animatedContainer, chart, table.
Map<String, dynamic> advancedPage() => {
      'type': 'page',
      'metadata': {'title': 'Advanced', 'description': 'Advanced widget showcase'},
      'state': {
        'initial': {
          'expanded': false,
          'progress': 0.65,
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
            _section('canvas (v1.3)'),
            {
              'type': 'canvas',
              'width': 280,
              'height': 150,
              'backgroundColor': '#F5F5F5',
              'commands': [
                {'op': 'rect', 'x': 10, 'y': 10, 'width': 80, 'height': 60, 'fill': '#2196F3', 'cornerRadius': 8},
                {'op': 'circle', 'cx': 160, 'cy': 40, 'radius': 30, 'fill': '#FF4081'},
                {'op': 'line', 'x1': 10, 'y1': 90, 'x2': 270, 'y2': 90, 'stroke': '#E0E0E0', 'strokeWidth': 2},
                {'op': 'text', 'content': 'Canvas drawing', 'x': 10, 'y': 120, 'fontSize': 14, 'color': '#333333'},
                {'op': 'arc', 'cx': 240, 'cy': 40, 'radius': 25, 'startAngle': 0, 'endAngle': 4.2, 'stroke': '#4CAF50', 'strokeWidth': 4, 'strokeCap': 'round'},
              ],
            },

            _section('animatedContainer'),
            {
              'type': 'animatedContainer',
              'duration': 300,
              'curve': 'easeInOut',
              'width': '{{expanded ? 280 : 140}}',
              'height': '{{expanded ? 100 : 50}}',
              'decoration': {
                'color': '{{expanded ? "#FF4081" : "#2196F3"}}',
                'borderRadius': 8,
              },
              'child': {
                'type': 'center',
                'child': {
                  'type': 'text',
                  'content': '{{expanded ? "Expanded!" : "Tap to expand"}}',
                  'style': {'color': '#FFFFFF', 'fontWeight': 'bold'},
                },
              },
            },
            {
              'type': 'button',
              'label': 'Toggle size',
              'variant': 'outlined',
              'onTap': {'type': 'state', 'action': 'toggle', 'binding': 'expanded'},
            },

            _section('opacity (v1.3)'),
            {
              'type': 'linear',
              'direction': 'horizontal',
              'spacing': 16,
              'children': [
                {
                  'type': 'opacity',
                  'opacity': 1.0,
                  'child': _colorBox('#2196F3', '100%'),
                },
                {
                  'type': 'opacity',
                  'opacity': 0.6,
                  'child': _colorBox('#2196F3', '60%'),
                },
                {
                  'type': 'opacity',
                  'opacity': 0.3,
                  'child': _colorBox('#2196F3', '30%'),
                },
              ],
            },

            _section('transform (v1.3)'),
            {
              'type': 'linear',
              'direction': 'horizontal',
              'spacing': 24,
              'children': [
                {
                  'type': 'transform',
                  'rotate': 0.3,
                  'child': _colorBox('#FF4081', 'Rot'),
                },
                {
                  'type': 'transform',
                  'scale': 1.2,
                  'child': _colorBox('#4CAF50', 'Scale'),
                },
              ],
            },

            _section('markdown'),
            {
              'type': 'card',
              'child': {
                'type': 'box',
                'padding': {'all': 12},
                'child': {
                  'type': 'markdown',
                  'content': '# Heading\n\n**Bold** and *italic* text.\n\n- Item 1\n- Item 2\n\n`inline code`',
                },
              },
            },

            _section('table'),
            {
              'type': 'table',
              'columns': [
                {'key': 'name', 'label': 'Name'},
                {'key': 'type', 'label': 'Type'},
                {'key': 'version', 'label': 'Version'},
              ],
              'rows': [
                {'name': 'Flutter', 'type': 'Framework', 'version': '3.10'},
                {'name': 'Dart', 'type': 'Language', 'version': '3.0'},
                {'name': 'MCP UI DSL', 'type': 'Spec', 'version': '1.3'},
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

Map<String, dynamic> _colorBox(String color, String label) => {
      'type': 'box',
      'width': 60,
      'height': 60,
      'decoration': {'color': color, 'borderRadius': 8},
      'child': {
        'type': 'center',
        'child': {
          'type': 'text',
          'content': label,
          'style': {'color': '#FFFFFF', 'fontSize': 12, 'fontWeight': 'bold'},
        },
      },
    };
