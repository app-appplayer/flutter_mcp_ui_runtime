library showcase_definition;

/// MCP UI DSL v1.0 Showcase Application Definition
/// This file contains the complete application definition demonstrating all features

final Map<String, dynamic> showcaseDefinition = {
  'type': 'application',
  'title': 'MCP UI DSL v1.0 Showcase',
  'version': '1.0.0',
  'state': {
    'initial': {
          'appName': 'MCP UI DSL Showcase',
          'version': '1.0.0',
          'counter': 0,
          'textInput': '',
          'toggleValue': false,
          'sliderValue': 50.0,
          'selectedOption': 'option1',
          'selectedCheckboxes': <String>[],
          'selectedRadio': 'radio1',
          'notificationCount': 0,
          'dialogResult': '',
        },
  },
  'theme': {
        'mode': 'light',
        'colors': {
          'primary': '#FF2196F3',
          'secondary': '#FFFF4081',
          'background': '#FFFFFFFF',
          'surface': '#FFF5F5F5',
          'error': '#FFF44336',
          'textOnPrimary': '#FFFFFFFF',
          'textOnSecondary': '#FF000000',
          'textOnBackground': '#FF000000',
          'textOnSurface': '#FF000000',
          'textOnError': '#FFFFFFFF',
        },
        'typography': {
          'h1': {'fontSize': 32, 'fontWeight': 'bold', 'letterSpacing': -1.5},
          'h2': {'fontSize': 28, 'fontWeight': 'bold', 'letterSpacing': -0.5},
          'h3': {'fontSize': 24, 'fontWeight': 'bold'},
          'h4': {'fontSize': 20, 'fontWeight': 'bold'},
          'h5': {'fontSize': 18, 'fontWeight': 'bold'},
          'h6': {'fontSize': 16, 'fontWeight': 'bold'},
          'body1': {'fontSize': 16, 'fontWeight': 'normal'},
          'body2': {'fontSize': 14, 'fontWeight': 'normal'},
          'caption': {'fontSize': 12, 'fontWeight': 'normal'},
          'button': {'fontSize': 14, 'fontWeight': 'medium', 'textTransform': 'uppercase'},
        },
        'spacing': {
          'xs': 4,
          'sm': 8,
          'md': 16,
          'lg': 24,
          'xl': 32,
          'xxl': 48,
        },
        'borderRadius': {
          'sm': 4,
          'md': 8,
          'lg': 16,
          'xl': 24,
          'round': 9999,
        },
  },
  'navigation': {
    'type': 'drawer',
    'items': [
      {'title': 'Home', 'icon': 'home', 'route': '/home'},
      {'title': 'Layout Widgets', 'icon': 'dashboard', 'route': '/layout'},
      {'title': 'Display Widgets', 'icon': 'visibility', 'route': '/display'},
      {'title': 'Input Widgets', 'icon': 'input', 'route': '/input'},
      {'title': 'List Widgets', 'icon': 'list', 'route': '/lists'},
      {'title': 'Navigation', 'icon': 'navigation', 'route': '/navigation'},
      {'title': 'Theme System', 'icon': 'palette', 'route': '/theme'},
      {'title': 'Actions & State', 'icon': 'play_arrow', 'route': '/actions'},
      {'title': 'Advanced Features', 'icon': 'settings', 'route': '/advanced'},
    ],
  },
  'initialRoute': '/home',
  'routes': {
    '/home': 'ui://pages/home',
    '/layout': 'ui://pages/layout',
    '/display': 'ui://pages/display',
    '/input': 'ui://pages/input',
    '/lists': 'ui://pages/lists',
    '/navigation': 'ui://pages/navigation',
    '/theme': 'ui://pages/theme',
    '/actions': 'ui://pages/actions',
    '/advanced': 'ui://pages/advanced',
  },
};

/// Page definitions for the showcase
final Map<String, Map<String, dynamic>> showcasePages = {
  'ui://pages/home': _homePage,
  'ui://pages/layout': _layoutPage,
  'ui://pages/display': _displayPage,
  'ui://pages/input': _inputPage,
  'ui://pages/lists': _listsPage,
  'ui://pages/navigation': _navigationPage,
  'ui://pages/theme': _themePage,
  'ui://pages/actions': _actionsPage,
  'ui://pages/advanced': _advancedPage,
};

// Home Page
final Map<String, dynamic> _homePage = {
  'type': 'page',
  'metadata': {
    'title': 'Welcome',
    'description': 'MCP UI DSL v1.0 Showcase Home',
  },
  'content': {
    'type': 'singleChildScrollView',
    'child': {
      'type': 'linear',
      'direction': 'vertical',
      'padding': {'all': 20},
      'children': [
        {
          'type': 'text',
          'content': 'Welcome to MCP UI DSL v1.0 Showcase',
          'style': {
            'fontSize': '{{theme.typography.h1.fontSize}}',
            'fontWeight': '{{theme.typography.h1.fontWeight}}',
            'color': '{{theme.colors.primary}}',
          },
        },
        {'type': 'box', 'height': 20},
        {
          'type': 'text',
          'content': 'This application demonstrates all features of the MCP UI DSL v1.0 specification. Use the navigation drawer to explore different widget categories and features.',
          'style': {'fontSize': '{{theme.typography.body1.fontSize}}'},
        },
        {'type': 'box', 'height': 30},
        {
          'type': 'card',
          'padding': {'all': 16},
          'child': {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'text',
                'content': 'Key Features',
                'style': {
                  'fontSize': '{{theme.typography.h3.fontSize}}',
                  'fontWeight': 'bold',
                },
              },
              {'type': 'box', 'height': 10},
              _featureItem('Comprehensive Widget Library', 'Over 20 different widget types'),
              _featureItem('Reactive State Management', 'Built-in data binding and state updates'),
              _featureItem('Theme System', 'Full theme customization support'),
              _featureItem('Action System', 'Tool calls, navigation, and more'),
              _featureItem('Advanced Features', 'Conditional rendering, validation, and forms'),
            ],
          },
        },
      ],
    },
  },
};

// Layout Widgets Page
final Map<String, dynamic> _layoutPage = {
  'type': 'page',
  'metadata': {
    'title': 'Layout Widgets',
    'description': 'Layout widgets demonstration',
  },
  'content': {
    'type': 'singleChildScrollView',
    'child': {
      'type': 'linear',
      'direction': 'vertical',
      'padding': {'all': 20},
      'children': [
        _sectionTitle('Layout Widgets'),
        {'type': 'box', 'height': 20},
        
        // Box Widget
        _widgetDemo(
          'Box Widget',
          'Container with padding, margin, and decoration',
          {
            'type': 'box',
            'width': 200,
            'height': 100,
            'padding': {'all': 16},
            'margin': {'all': 8},
            'backgroundColor': '{{theme.colors.primary}}',
            'borderRadius': '{{theme.borderRadius.md}}',
            'child': {
              'type': 'center',
              'child': {
                'type': 'text',
                'content': 'Box with decoration',
                'style': {'color': '{{theme.colors.textOnPrimary}}'},
              },
            },
          },
        ),
        
        // Linear Widget
        _widgetDemo(
          'Linear Widget',
          'Horizontal and vertical layout',
          {
            'type': 'linear',
            'direction': 'horizontal',
            'alignment': 'center',
            'children': [
              _colorBox('#FF2196F3', 'Blue'),
              {'type': 'box', 'width': 10},
              _colorBox('#FFFF4081', 'Pink'),
              {'type': 'box', 'width': 10},
              _colorBox('#FF4CAF50', 'Green'),
            ],
          },
        ),
        
        // Stack Widget
        _widgetDemo(
          'Stack Widget',
          'Overlapping widgets with positioning',
          {
            'type': 'stack',
            'width': 200,
            'height': 150,
            'children': [
              {
                'type': 'box',
                'backgroundColor': '#FFE3F2FD',
                'borderRadius': 8,
              },
              {
                'type': 'positioned',
                'top': 10,
                'left': 10,
                'child': {
                  'type': 'text',
                  'content': 'Top Left',
                  'style': {'fontSize': 12},
                },
              },
              {
                'type': 'positioned',
                'bottom': 10,
                'right': 10,
                'child': {
                  'type': 'text',
                  'content': 'Bottom Right',
                  'style': {'fontSize': 12},
                },
              },
              {
                'type': 'center',
                'child': {
                  'type': 'icon',
                  'icon': 'star',
                  'size': 48,
                  'color': '{{theme.colors.primary}}',
                },
              },
            ],
          },
        ),
        
        // Expanded & Flexible
        _widgetDemo(
          'Expanded & Flexible',
          'Flexible space distribution',
          {
            'type': 'linear',
            'direction': 'horizontal',
            'children': [
              {
                'type': 'expanded',
                'flex': 2,
                'child': _colorBox('#FF9C27B0', 'Flex: 2'),
              },
              {'type': 'box', 'width': 10},
              {
                'type': 'expanded',
                'flex': 1,
                'child': _colorBox('#FF00BCD4', 'Flex: 1'),
              },
            ],
          },
        ),
      ],
    },
  },
};

// Display Widgets Page
final Map<String, dynamic> _displayPage = {
  'type': 'page',
  'metadata': {
    'title': 'Display Widgets',
    'description': 'Display widgets demonstration',
  },
  'content': {
    'type': 'singleChildScrollView',
    'child': {
      'type': 'linear',
      'direction': 'vertical',
      'padding': {'all': 20},
      'children': [
        _sectionTitle('Display Widgets'),
        {'type': 'box', 'height': 20},
        
        // Text Widget
        _widgetDemo(
          'Text Widget',
          'Basic text display with styling',
          {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'text',
                'content': 'This is a heading',
                'style': {
                  'fontSize': '{{theme.typography.h3.fontSize}}',
                  'fontWeight': 'bold',
                  'color': '{{theme.colors.primary}}',
                },
              },
              {'type': 'box', 'height': 10},
              {
                'type': 'text',
                'content': 'This is body text with normal styling',
                'style': {'fontSize': '{{theme.typography.body1.fontSize}}'},
              },
            ],
          },
        ),
        
        // RichText Widget
        _widgetDemo(
          'RichText Widget',
          'Text with multiple styles',
          {
            'type': 'richText',
            'spans': [
              {'text': 'This is ', 'style': {'color': '#FF000000'}},
              {'text': 'rich', 'style': {'color': '#FFF44336', 'fontWeight': 'bold'}},
              {'text': ' text with ', 'style': {'color': '#FF000000'}},
              {'text': 'multiple', 'style': {'color': '#FF2196F3', 'fontStyle': 'italic'}},
              {'text': ' styles', 'style': {'color': '#FF4CAF50', 'fontSize': 20}},
            ],
          },
        ),
        
        // Icon Widget
        _widgetDemo(
          'Icon Widget',
          'Material icons with customization',
          {
            'type': 'linear',
            'direction': 'horizontal',
            'alignment': 'center',
            'children': [
              {'type': 'icon', 'icon': 'home', 'size': 32, 'color': '{{theme.colors.primary}}'},
              {'type': 'box', 'width': 20},
              {'type': 'icon', 'icon': 'favorite', 'size': 40, 'color': '#FFF44336'},
              {'type': 'box', 'width': 20},
              {'type': 'icon', 'icon': 'star', 'size': 48, 'color': '#FFFFC107'},
            ],
          },
        ),
        
        // Image Widget
        _widgetDemo(
          'Image Widget',
          'Network and asset images',
          {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'text',
                'content': 'Images can be loaded from network URLs or local assets',
                'style': {'fontSize': 14, 'color': '#FF666666'},
              },
              {'type': 'box', 'height': 10},
              {
                'type': 'box',
                'width': 150,
                'height': 150,
                'backgroundColor': '#FFE0E0E0',
                'borderRadius': 8,
                'child': {
                  'type': 'center',
                  'child': {
                    'type': 'text',
                    'content': 'Image Placeholder',
                    'style': {'color': '#FF666666'},
                  },
                },
              },
            ],
          },
        ),
        
        // Card Widget
        _widgetDemo(
          'Card Widget',
          'Material design card with elevation',
          {
            'type': 'card',
            'elevation': 4,
            'padding': {'all': 16},
            'child': {
              'type': 'linear',
              'direction': 'vertical',
              'children': [
                {
                  'type': 'text',
                  'content': 'Card Title',
                  'style': {'fontSize': 18, 'fontWeight': 'bold'},
                },
                {'type': 'box', 'height': 8},
                {
                  'type': 'text',
                  'content': 'This is a card widget with elevation and padding. Cards are great for grouping related content.',
                },
              ],
            },
          },
        ),
        
        // Badge Widget
        _widgetDemo(
          'Badge Widget',
          'Notification badges',
          {
            'type': 'linear',
            'direction': 'horizontal',
            'alignment': 'center',
            'children': [
              {
                'type': 'badge',
                'content': '3',
                'child': {'type': 'icon', 'icon': 'notifications', 'size': 32},
              },
              {'type': 'box', 'width': 30},
              {
                'type': 'badge',
                'content': '99+',
                'backgroundColor': '#FFF44336',
                'child': {'type': 'icon', 'icon': 'mail', 'size': 32},
              },
              {'type': 'box', 'width': 30},
              {
                'type': 'badge',
                'content': 'NEW',
                'backgroundColor': '#FF4CAF50',
                'child': {
                  'type': 'button',
                  'label': 'Updates',
                  'variant': 'outlined',
                },
              },
            ],
          },
        ),
      ],
    },
  },
};

// Input Widgets Page
final Map<String, dynamic> _inputPage = {
  'type': 'page',
  'metadata': {
    'title': 'Input Widgets',
    'description': 'Input widgets demonstration',
  },
  'content': {
    'type': 'singleChildScrollView',
    'child': {
      'type': 'linear',
      'direction': 'vertical',
      'padding': {'all': 20},
      'children': [
        _sectionTitle('Input Widgets'),
        {'type': 'box', 'height': 20},
        
        // Button Widget
        _widgetDemo(
          'Button Widget',
          'Different button styles',
          {
            'type': 'linear',
            'direction': 'horizontal',
            'alignment': 'center',
            'children': [
              {
                'type': 'button',
                'label': 'Elevated',
                'variant': 'elevated',
                'click': {
                  'type': 'state',
                  'action': 'increment',
                  'binding': 'counter',
                },
              },
              {'type': 'box', 'width': 10},
              {
                'type': 'button',
                'label': 'Outlined',
                'variant': 'outlined',
                'click': {
                  'type': 'state',
                  'action': 'decrement',
                  'binding': 'counter',
                },
              },
              {'type': 'box', 'width': 10},
              {
                'type': 'button',
                'label': 'Text',
                'style': 'text',
                'click': {
                  'type': 'state',
                  'action': 'set',
                  'binding': 'counter',
                  'value': 0,
                },
              },
            ],
          },
        ),
        
        // Counter Display
        {
          'type': 'center',
          'child': {
            'type': 'text',
            'content': 'Counter: {{counter}}',
            'style': {'fontSize': 24, 'fontWeight': 'bold'},
          },
        },
        {'type': 'box', 'height': 20},
        
        // TextInput Widget
        _widgetDemo(
          'TextInput Widget',
          'Text input fields',
          {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'textInput',
                'value': '{{textInput}}',
                'label': 'Enter text',
                'placeholder': 'Type something...',
                'change': {
                  'type': 'state',
                  'action': 'set',
                  'binding': 'textInput',
                  'value': '{{event.value}}',
                },
              },
              {'type': 'box', 'height': 10},
              {
                'type': 'text',
                'content': 'You typed: {{textInput}}',
                'style': {'fontSize': 14, 'color': '#FF666666'},
              },
            ],
          },
        ),
        
        // Toggle Widget
        _widgetDemo(
          'Toggle Widget',
          'Switch toggle',
          {
            'type': 'linear',
            'direction': 'horizontal',
            'alignment': 'center',
            'children': [
              {
                'type': 'toggle',
                'value': '{{toggleValue}}',
                'change': {
                  'type': 'state',
                  'action': 'toggle',
                  'binding': 'toggleValue',
                },
              },
              {'type': 'box', 'width': 10},
              {
                'type': 'text',
                'content': 'Toggle is {{toggleValue ? "ON" : "OFF"}}',
              },
            ],
          },
        ),
        
        // Dialog Button Demo
        _widgetDemo(
          'Dialog Actions',
          'Show different types of dialogs',
          {
            'type': 'linear',
            'direction': 'horizontal',
            'alignment': 'center',
            'children': [
              {
                'type': 'button',
                'label': 'Alert Dialog',
                'variant': 'elevated',
                'click': {
                  'type': 'dialog',
                  'dialog': {
                    'type': 'alert',
                    'title': 'Alert Dialog',
                    'content': 'This is an alert dialog example',
                    'actions': [
                      {
                        'label': 'OK',
                        'action': 'close',
                        'primary': true,
                      },
                    ],
                  },
                },
              },
              {'type': 'box', 'width': 10},
              {
                'type': 'button',
                'label': 'Confirm Dialog',
                'variant': 'outlined',
                'click': {
                  'type': 'dialog',
                  'dialog': {
                    'type': 'alert',
                    'title': 'Confirm Action',
                    'content': 'Are you sure you want to proceed?',
                    'actions': [
                      {
                        'label': 'Cancel',
                        'action': 'close',
                      },
                      {
                        'label': 'Confirm',
                        'action': {
                          'type': 'state',
                          'action': 'set',
                          'binding': 'dialogResult',
                          'value': 'confirmed',
                        },
                        'primary': true,
                      },
                    ],
                  },
                },
              },
              {'type': 'box', 'width': 10},
              {
                'type': 'text',
                'content': 'Result: {{dialogResult}}',
              },
            ],
          },
        ),
        
        // Slider Widget
        _widgetDemo(
          'Slider Widget',
          'Value slider',
          {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'slider',
                'value': '{{sliderValue}}',
                'min': 0,
                'max': 100,
                'change': {
                  'type': 'state',
                  'action': 'set',
                  'binding': 'sliderValue',
                  'value': '{{event.value}}',
                },
              },
              {'type': 'box', 'height': 10},
              {
                'type': 'text',
                'content': 'Value: {{sliderValue}}',
                'style': {'fontSize': 14},
              },
            ],
          },
        ),
        
        // Select Widget
        _widgetDemo(
          'Select Widget',
          'Dropdown selection',
          {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'select',
                'value': '{{selectedOption}}',
                'items': [
                  {'value': 'option1', 'label': 'Option 1'},
                  {'value': 'option2', 'label': 'Option 2'},
                  {'value': 'option3', 'label': 'Option 3'},
                ],
                'change': {
                  'type': 'state',
                  'action': 'set',
                  'binding': 'selectedOption',
                  'value': '{{event.value}}',
                },
              },
              {'type': 'box', 'height': 10},
              {
                'type': 'text',
                'content': 'Selected: {{selectedOption}}',
                'style': {'fontSize': 14, 'color': '#FF666666'},
              },
            ],
          },
        ),
      ],
    },
  },
};

// Lists Page
final Map<String, dynamic> _listsPage = {
  'type': 'page',
  'metadata': {
    'title': 'List Widgets',
    'description': 'List and grid widgets demonstration',
  },
  'content': {
    'type': 'singleChildScrollView',
    'child': {
      'type': 'linear',
      'direction': 'vertical',
      'padding': {'all': 20},
      'children': [
        _sectionTitle('List Widgets'),
        {'type': 'box', 'height': 20},
        
        // List Widget
        _widgetDemo(
          'List Widget',
          'Scrollable list with items',
          {
            'type': 'box',
            'height': 200,
            'child': {
              'type': 'list',
              'items': List.generate(10, (i) => ({
                'type': 'listTile',
                'title': 'List Item ${i + 1}',
                'subtitle': 'Subtitle for item ${i + 1}',
                'leading': {
                  'type': 'icon',
                  'icon': 'folder',
                  'color': '{{theme.colors.primary}}',
                },
                'trailing': {
                  'type': 'icon',
                  'icon': 'arrow_forward',
                },
                'click': {
                  'type': 'state',
                  'action': 'set',
                  'binding': 'selectedOption',
                  'value': 'item${i + 1}',
                },
              })),
            },
          },
        ),
        
        // Grid Widget
        _widgetDemo(
          'Grid Widget',
          'Grid layout with cards',
          {
            'type': 'box',
            'height': 300,
            'child': {
              'type': 'grid',
              'columns': 2,
              'spacing': 10,
              'items': List.generate(6, (i) => ({
                'type': 'card',
                'padding': {'all': 16},
                'child': {
                  'type': 'center',
                  'child': {
                    'type': 'linear',
                    'direction': 'vertical',
                    'alignment': 'center',
                    'children': [
                      {
                        'type': 'icon',
                        'icon': ['home', 'star', 'favorite', 'settings', 'info', 'help'][i],
                        'size': 48,
                        'color': '{{theme.colors.primary}}',
                      },
                      {'type': 'box', 'height': 8},
                      {
                        'type': 'text',
                        'content': 'Grid ${i + 1}',
                        'style': {'fontSize': 14},
                      },
                    ],
                  },
                },
              })),
            },
          },
        ),
      ],
    },
  },
};

// Navigation Page
final Map<String, dynamic> _navigationPage = {
  'type': 'page',
  'metadata': {
    'title': 'Navigation',
    'description': 'Navigation patterns demonstration',
  },
  'content': {
    'type': 'singleChildScrollView',
    'child': {
      'type': 'linear',
      'direction': 'vertical',
      'padding': {'all': 20},
      'children': [
        _sectionTitle('Navigation Patterns'),
        {'type': 'box', 'height': 20},
        
        {
          'type': 'text',
          'content': 'MCP UI DSL supports various navigation patterns:',
          'style': {'fontSize': 16},
        },
        {'type': 'box', 'height': 20},
        
        // Navigation Types
        _widgetDemo(
          'Navigation Types',
          'Different navigation patterns',
          {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              _navigationItem('Drawer Navigation', 'Slide-out navigation drawer (current app uses this)'),
              _navigationItem('Tab Navigation', 'Bottom tab bar navigation'),
              _navigationItem('Route Navigation', 'Direct route-based navigation'),
              _navigationItem('Dialog Navigation', 'Modal dialogs and sheets'),
            ],
          },
        ),
        
        // Navigation Actions
        _widgetDemo(
          'Navigation Actions',
          'Different ways to navigate',
          {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'button',
                'label': 'Navigate to Home',
                'variant': 'elevated',
                'click': {
                  'type': 'navigation',
                  'action': 'push',
                  'route': '/home',
                },
              },
              {'type': 'box', 'height': 10},
              {
                'type': 'button',
                'label': 'Open Dialog',
                'variant': 'outlined',
                'click': {
                  'type': 'dialog',
                  'dialog': {
                    'title': 'Sample Dialog',
                    'content': 'This is a dialog opened via navigation action',
                    'actions': [
                      {'label': 'Cancel', 'action': 'close'},
                      {'label': 'OK', 'action': 'close', 'primary': true},
                    ],
                  },
                },
              },
            ],
          },
        ),
      ],
    },
  },
};

// Theme Page
final Map<String, dynamic> _themePage = {
  'type': 'page',
  'metadata': {
    'title': 'Theme System',
    'description': 'Theme customization demonstration',
  },
  'content': {
    'type': 'singleChildScrollView',
    'child': {
      'type': 'linear',
      'direction': 'vertical',
      'padding': {'all': 20},
      'children': [
        _sectionTitle('Theme System'),
        {'type': 'box', 'height': 20},
        
        // Colors
        _widgetDemo(
          'Color Palette',
          'Theme colors with dynamic binding',
          {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              _colorSwatch('Primary', '{{theme.colors.primary}}'),
              _colorSwatch('Secondary', '{{theme.colors.secondary}}'),
              _colorSwatch('Background', '{{theme.colors.background}}'),
              _colorSwatch('Surface', '{{theme.colors.surface}}'),
              _colorSwatch('Error', '{{theme.colors.error}}'),
            ],
          },
        ),
        
        // Typography
        _widgetDemo(
          'Typography',
          'Text styles from theme',
          {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'text',
                'content': 'Heading 1',
                'style': {
                  'fontSize': '{{theme.typography.h1.fontSize}}',
                  'fontWeight': '{{theme.typography.h1.fontWeight}}',
                },
              },
              {
                'type': 'text',
                'content': 'Heading 2',
                'style': {
                  'fontSize': '{{theme.typography.h2.fontSize}}',
                  'fontWeight': '{{theme.typography.h2.fontWeight}}',
                },
              },
              {
                'type': 'text',
                'content': 'Body Text 1',
                'style': {
                  'fontSize': '{{theme.typography.body1.fontSize}}',
                },
              },
              {
                'type': 'text',
                'content': 'Caption Text',
                'style': {
                  'fontSize': '{{theme.typography.caption.fontSize}}',
                  'color': '#FF666666',
                },
              },
            ],
          },
        ),
        
        // Spacing
        _widgetDemo(
          'Spacing System',
          'Consistent spacing values',
          {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              _spacingDemo('xs', '{{theme.spacing.xs}}'),
              _spacingDemo('sm', '{{theme.spacing.sm}}'),
              _spacingDemo('md', '{{theme.spacing.md}}'),
              _spacingDemo('lg', '{{theme.spacing.lg}}'),
              _spacingDemo('xl', '{{theme.spacing.xl}}'),
            ],
          },
        ),
      ],
    },
  },
};

// Actions & State Page
final Map<String, dynamic> _actionsPage = {
  'type': 'page',
  'metadata': {
    'title': 'Actions & State',
    'description': 'State management and actions demonstration',
  },
  'content': {
    'type': 'singleChildScrollView',
    'child': {
      'type': 'linear',
      'direction': 'vertical',
      'padding': {'all': 20},
      'children': [
        _sectionTitle('Actions & State Management'),
        {'type': 'box', 'height': 20},
        
        // State Display
        _widgetDemo(
          'Current State',
          'Live state values',
          {
            'type': 'card',
            'padding': {'all': 16},
            'child': {
              'type': 'linear',
              'direction': 'vertical',
              'children': [
                _stateItem('Counter', '{{counter}}'),
                _stateItem('Text Input', '{{textInput || "(empty)"}}'),
                _stateItem('Toggle Value', '{{toggleValue}}'),
                _stateItem('Slider Value', '{{sliderValue}}'),
                _stateItem('Selected Option', '{{selectedOption}}'),
              ],
            },
          },
        ),
        
        // Action Types
        _widgetDemo(
          'Action Types',
          'Different action types in MCP UI DSL',
          {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'text',
                'content': '1. Tool Actions',
                'style': {'fontWeight': 'bold'},
              },
              {
                'type': 'text',
                'content': 'Execute server-side tools with parameters',
                'style': {'fontSize': 14, 'color': '#FF666666'},
              },
              {'type': 'box', 'height': 10},
              {
                'type': 'text',
                'content': '2. Navigation Actions',
                'style': {'fontWeight': 'bold'},
              },
              {
                'type': 'text',
                'content': 'Navigate between pages and routes',
                'style': {'fontSize': 14, 'color': '#FF666666'},
              },
              {'type': 'box', 'height': 10},
              {
                'type': 'text',
                'content': '3. State Actions',
                'style': {'fontWeight': 'bold'},
              },
              {
                'type': 'text',
                'content': 'Direct state updates and bindings',
                'style': {'fontSize': 14, 'color': '#FF666666'},
              },
              {'type': 'box', 'height': 10},
              {
                'type': 'text',
                'content': '4. Resource Actions',
                'style': {'fontWeight': 'bold'},
              },
              {
                'type': 'text',
                'content': 'Subscribe/unsubscribe to resource updates',
                'style': {'fontSize': 14, 'color': '#FF666666'},
              },
            ],
          },
        ),
        
        // Batch Actions
        _widgetDemo(
          'Batch Actions',
          'Multiple actions in sequence',
          {
            'type': 'button',
            'label': 'Execute Batch Action',
            'variant': 'elevated',
            'click': {
              'type': 'batch',
              'actions': [
                {'type': 'state', 'action': 'set', 'binding': 'counter', 'value': 0},
                {'type': 'state', 'action': 'set', 'binding': 'textInput', 'value': 'Batch executed!'},
                {'type': 'state', 'action': 'toggle', 'binding': 'toggleValue'},
              ],
            },
          },
        ),
      ],
    },
  },
};

// Advanced Features Page
final Map<String, dynamic> _advancedPage = {
  'type': 'page',
  'metadata': {
    'title': 'Advanced Features',
    'description': 'Advanced MCP UI DSL features',
  },
  'content': {
    'type': 'singleChildScrollView',
    'child': {
      'type': 'linear',
      'direction': 'vertical',
      'padding': {'all': 20},
      'children': [
        _sectionTitle('Advanced Features'),
        {'type': 'box', 'height': 20},
        
        // Conditional Rendering
        _widgetDemo(
          'Conditional Rendering',
          'Show/hide widgets based on state',
          {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'button',
                'label': 'Toggle Visibility',
                'variant': 'elevated',
                'click': {'type': 'state', 'action': 'toggle', 'binding': 'toggleValue'},
              },
              {'type': 'box', 'height': 10},
              {
                'type': 'conditional',
                'condition': '{{toggleValue}}',
                'true': {
                  'type': 'card',
                  'padding': {'all': 16},
                  'child': {
                    'type': 'text',
                    'content': 'This card is visible when toggle is ON',
                    'style': {'color': '{{theme.colors.primary}}'},
                  },
                },
                'false': {
                  'type': 'card',
                  'padding': {'all': 16},
                  'child': {
                    'type': 'text',
                    'content': 'This card is visible when toggle is OFF',
                    'style': {'color': '{{theme.colors.error}}'},
                  },
                },
              },
            ],
          },
        ),
        
        // Forms
        _widgetDemo(
          'Form Handling',
          'Form with validation',
          {
            'type': 'form',
            'id': 'sampleForm',
            'validation': {
              'validateOnSubmit': true,
            },
            'child': {
              'type': 'linear',
              'direction': 'vertical',
              'children': [
                {
                  'type': 'textInput',
                  'name': 'username',
                  'label': 'Username',
                  'required': true,
                  'validation': {
                    'minLength': 3,
                    'maxLength': 20,
                    'pattern': '^[a-zA-Z0-9_]+\$',
                  },
                },
                {'type': 'box', 'height': 10},
                {
                  'type': 'textInput',
                  'name': 'email',
                  'label': 'Email',
                  'inputType': 'email',
                  'required': true,
                },
                {'type': 'box', 'height': 10},
                {
                  'type': 'textInput',
                  'name': 'password',
                  'label': 'Password',
                  'inputType': 'password',
                  'required': true,
                  'validation': {
                    'minLength': 8,
                  },
                },
                {'type': 'box', 'height': 20},
                {
                  'type': 'button',
                  'label': 'Submit Form',
                  'variant': 'elevated',
                  'click': {
                    'type': 'form',
                    'action': 'submit',
                    'form': 'sampleForm',
                  },
                },
              ],
            },
          },
        ),
        
        // Custom Widgets
        _widgetDemo(
          'Template Widgets',
          'Reusable widget templates',
          {
            'type': 'card',
            'padding': {'all': 16},
            'child': {
              'type': 'linear',
              'direction': 'horizontal',
              'children': [
                {
                  'type': 'icon',
                  'icon': 'info',
                  'size': 48,
                  'color': '{{theme.colors.primary}}',
                },
                {'type': 'box', 'width': 16},
                {
                  'type': 'expanded',
                  'child': {
                    'type': 'linear',
                    'direction': 'vertical',
                    'children': [
                      {
                        'type': 'text',
                        'content': 'Template Example',
                        'style': {'fontSize': 18, 'fontWeight': 'bold'},
                      },
                      {'type': 'box', 'height': 8},
                      {
                        'type': 'text',
                        'content': 'This demonstrates how reusable UI patterns can be created in MCP UI DSL v1.0 using composition.',
                      },
                    ],
                  },
                },
              ],
            },
          },
        ),
      ],
    },
  },
};

// Helper functions for creating consistent widget demos
Map<String, dynamic> _widgetDemo(String title, String description, Map<String, dynamic> widget) {
  return {
    'type': 'card',
    'margin': {'bottom': 20},
    'padding': {'all': 16},
    'child': {
      'type': 'linear',
      'direction': 'vertical',
      'children': [
        {
          'type': 'text',
          'content': title,
          'style': {'fontSize': 18, 'fontWeight': 'bold'},
        },
        {'type': 'box', 'height': 8},
        {
          'type': 'text',
          'content': description,
          'style': {'fontSize': 14, 'color': '#FF666666'},
        },
        {'type': 'box', 'height': 16},
        widget,
      ],
    },
  };
}

Map<String, dynamic> _sectionTitle(String title) {
  return {
    'type': 'text',
    'content': title,
    'style': {
      'fontSize': '{{theme.typography.h2.fontSize}}',
      'fontWeight': '{{theme.typography.h2.fontWeight}}',
      'color': '{{theme.colors.primary}}',
    },
  };
}

Map<String, dynamic> _colorBox(String color, String label) {
  return {
    'type': 'linear',
    'direction': 'vertical',
    'alignment': 'center',
    'children': [
      {
        'type': 'box',
        'width': 60,
        'height': 60,
        'backgroundColor': color,
        'borderRadius': 8,
      },
      {'type': 'box', 'height': 8},
      {
        'type': 'text',
        'content': label,
        'style': {'fontSize': 12},
      },
    ],
  };
}

Map<String, dynamic> _featureItem(String title, String description) {
  return {
    'type': 'padding',
    'padding': {'vertical': 8},
    'child': {
      'type': 'linear',
      'direction': 'horizontal',
      'children': [
        {
          'type': 'icon',
          'icon': 'check_circle',
          'size': 20,
          'color': '{{theme.colors.primary}}',
        },
        {'type': 'box', 'width': 12},
        {
          'type': 'expanded',
          'child': {
            'type': 'linear',
            'direction': 'vertical',
            'children': [
              {
                'type': 'text',
                'content': title,
                'style': {'fontWeight': 'bold'},
              },
              {
                'type': 'text',
                'content': description,
                'style': {'fontSize': 14, 'color': '#FF666666'},
              },
            ],
          },
        },
      ],
    },
  };
}

Map<String, dynamic> _navigationItem(String title, String description) {
  return {
    'type': 'listTile',
    'title': title,
    'subtitle': description,
    'leading': {
      'type': 'icon',
      'icon': 'navigation',
      'color': '{{theme.colors.primary}}',
    },
  };
}

Map<String, dynamic> _colorSwatch(String name, String colorBinding) {
  return {
    'type': 'padding',
    'padding': {'vertical': 8},
    'child': {
      'type': 'linear',
      'direction': 'horizontal',
      'alignment': 'center',
      'children': [
        {
          'type': 'box',
          'width': 60,
          'height': 40,
          'backgroundColor': colorBinding,
          'borderRadius': 4,
        },
        {'type': 'box', 'width': 16},
        {
          'type': 'expanded',
          'child': {
            'type': 'text',
            'content': name,
            'style': {'fontSize': 16},
          },
        },
        {
          'type': 'text',
          'content': colorBinding,
          'style': {'fontSize': 12, 'color': '#FF666666'},
        },
      ],
    },
  };
}

Map<String, dynamic> _spacingDemo(String name, String spacingBinding) {
  return {
    'type': 'padding',
    'padding': {'vertical': 4},
    'child': {
      'type': 'linear',
      'direction': 'horizontal',
      'alignment': 'center',
      'children': [
        {
          'type': 'text',
          'content': name,
          'style': {'fontSize': 14, 'width': 30},
        },
        {'type': 'box', 'width': 10},
        {
          'type': 'box',
          'height': 20,
          'width': spacingBinding,
          'backgroundColor': '{{theme.colors.primary}}',
          'borderRadius': 2,
        },
        {'type': 'box', 'width': 10},
        {
          'type': 'text',
          'content': '${spacingBinding}px',
          'style': {'fontSize': 12, 'color': '#FF666666'},
        },
      ],
    },
  };
}

Map<String, dynamic> _stateItem(String name, String valueBinding) {
  return {
    'type': 'padding',
    'padding': {'vertical': 4},
    'child': {
      'type': 'linear',
      'direction': 'horizontal',
      'children': [
        {
          'type': 'expanded',
          'child': {
            'type': 'text',
            'content': '$name:',
            'style': {'fontWeight': 'bold'},
          },
        },
        {
          'type': 'text',
          'content': valueBinding,
          'style': {'color': '{{theme.colors.primary}}'},
        },
      ],
    },
  };
}