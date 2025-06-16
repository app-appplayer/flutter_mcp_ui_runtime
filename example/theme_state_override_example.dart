import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

/// Example demonstrating how to override theme values through state management
void main() {
  runApp(ThemeStateOverrideExample());
}

class ThemeStateOverrideExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Theme State Override Example',
      home: ThemeOverrideDemo(),
    );
  }
}

class ThemeOverrideDemo extends StatefulWidget {
  @override
  _ThemeOverrideDemoState createState() => _ThemeOverrideDemoState();
}

class _ThemeOverrideDemoState extends State<ThemeOverrideDemo> {
  late MCPUIRuntime runtime;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeRuntime();
  }

  Future<void> _initializeRuntime() async {
    runtime = MCPUIRuntime();
    
    // Define a simple UI with theme-aware components
    final definition = {
      'type': 'container',
      'properties': {
        'padding': {'all': 16},
      },
      'child': {
        'type': 'column',
        'properties': {
          'crossAxisAlignment': 'stretch',
          'spacing': 16,
        },
        'children': [
          {
            'type': 'text',
            'content': 'Theme Override Example',
            'properties': {
              'style': {
                'fontSize': 24,
                'fontWeight': 'bold',
                'color': {'binding': 'theme.colors.primary'},
              }
            }
          },
          {
            'type': 'container',
            'properties': {
              'padding': {'all': 16},
              'decoration': {
                'color': {'binding': 'theme.colors.surface'},
                'borderRadius': {'binding': 'theme.borderRadius.md'},
              },
            },
            'child': {
              'type': 'text',
              'content': 'This container uses theme colors and border radius',
              'properties': {
                'style': {
                  'color': {'binding': 'theme.colors.onSurface'},
                }
              }
            }
          },
          {
            'type': 'row',
            'properties': {
              'spacing': 8,
            },
            'children': [
              {
                'type': 'button',
                'properties': {
                  'text': 'Blue Theme',
                  'onPressed': {
                    'type': 'setState',
                    'updates': {
                      'theme.colors.primary': '#2196f3',
                      'theme.colors.surface': '#e3f2fd',
                      'theme.borderRadius.md': 8,
                    }
                  }
                }
              },
              {
                'type': 'button',
                'properties': {
                  'text': 'Green Theme',
                  'onPressed': {
                    'type': 'setState',
                    'updates': {
                      'theme.colors.primary': '#4caf50',
                      'theme.colors.surface': '#e8f5e9',
                      'theme.borderRadius.md': 16,
                    }
                  }
                }
              },
              {
                'type': 'button',
                'properties': {
                  'text': 'Reset',
                  'onPressed': {
                    'type': 'setState',
                    'updates': {
                      'theme.colors.primary': null,
                      'theme.colors.surface': null,
                      'theme.borderRadius.md': null,
                    }
                  }
                }
              },
            ]
          },
          {
            'type': 'text',
            'content': 'Current theme values:',
            'properties': {
              'style': {'fontWeight': 'bold'}
            }
          },
          {
            'type': 'text',
            'content': {'binding': '"Primary: " + (state.theme.colors.primary || "#2196f3")'},
          },
          {
            'type': 'text',
            'content': {'binding': '"Surface: " + (state.theme.colors.surface || "#f5f5f5")'},
          },
          {
            'type': 'text',
            'content': {'binding': '"Border Radius: " + (state.theme.borderRadius.md || 8)'},
          },
        ]
      }
    };

    await runtime.initialize(definition);
    
    // Set initial state
    runtime.updateState('theme', {
      'colors': {},
      'borderRadius': {},
    });
    
    setState(() {
      _isInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Theme State Override Demo'),
      ),
      body: _isInitialized
          ? runtime.buildUI()
          : Center(child: CircularProgressIndicator()),
    );
  }
}