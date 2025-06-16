import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:mcp_server/mcp_server.dart';

void main(List<String> args) async {
  try {
    // Create server configuration using the correct API
    final config = McpServerConfig(
      name: 'Demo MCP Server',
      version: '1.0.0',
      capabilities: ServerCapabilities(
        tools: ToolsCapability(
          listChanged: true,
        ),
        resources: ResourcesCapability(
          listChanged: true,
          subscribe: true,
        ),
        logging: LoggingCapability(),
      ),
      enableDebugLogging: true,
    );

    // Create server using the factory method
    final server = McpServer.createServer(config);

    // Create stdio transport
    final transportResult = McpServer.createStdioTransport();
    final transport = transportResult.get();

    // Connect server to transport
    server.connect(transport);

    // Initialize server with resources and tools
    final serverHandler = MCPUIServer(server);
    await serverHandler.initialize();

    // Server started - ready for STDIO communication
    
    // Keep server running
    await Completer<void>().future;
  } catch (e, stackTrace) {
    // Log error to stderr (not stdout which is used for MCP communication)
    stderr.writeln('Error starting server: $e');
    stderr.writeln('Stack trace: $stackTrace');
    exit(1);
  }
}

class MCPUIServer {
  final Server server;
  
  // Server state - simple counter
  int _counter = 0;
  
  // Temperature monitoring state
  double _temperature = 20.0;
  Timer? _temperatureTimer;
  Set<String> _temperatureSubscribers = {}; // Track subscribers
  
  // Standard mode temperature
  double _standardTemperature = 20.0;
  Timer? _standardTemperatureTimer;
  Set<String> _standardTemperatureSubscribers = {}; // Track standard subscribers

  MCPUIServer(this.server);

  void _log(String message) {
    stderr.writeln('[demo_mcp_server] $message');
  }

  void _setupSubscriptionHandlers() {
    // For now, assume we always have subscribers when notifications are sent
    // TODO: Implement proper subscription tracking when MCP server library supports it
    _log('Subscription handlers setup (simplified)');
  }

  Future<void> initialize() async {
    // Register UI Resources
    _registerResources();
    
    // Register Tools
    _registerTools();
    
    // Setup subscription handlers
    _setupSubscriptionHandlers();
    
    // Start temperature simulation
    _startTemperatureSimulation();
    _startStandardTemperatureSimulation();
  }

  void _registerResources() {
    // Main Application Resource
    server.addResource(
      uri: 'ui://app',
      name: 'Demo MCP Application',
      description: 'MCP Demo application with multiple pages',
      mimeType: 'application/json',
      handler: _handleApplicationResource,
    );
    
    // Page Resources
    server.addResource(
      uri: 'ui://pages/counter',
      name: 'Counter Page',
      description: 'Simple counter demo page',
      mimeType: 'application/json',
      handler: _handleCounterPageResource,
    );
    
    server.addResource(
      uri: 'ui://pages/temperature-standard',
      name: 'Temperature Monitor (Standard)',
      description: 'Temperature monitoring with standard MCP subscription',
      mimeType: 'application/json',
      handler: _handleTemperatureStandardPageResource,
    );
    
    server.addResource(
      uri: 'ui://pages/temperature',
      name: 'Temperature Monitor',
      description: 'Real-time temperature monitoring with subscription',
      mimeType: 'application/json',
      handler: _handleTemperaturePageResource,
    );
    
    // Temperature Data Resource (for extended subscription)
    server.addResource(
      uri: 'data://temperature',
      name: 'Temperature Data',
      description: 'Current temperature value',
      mimeType: 'application/json',
      handler: _handleTemperatureDataResource,
    );
    
    // Standard Temperature Data Resource (for standard subscription)
    server.addResource(
      uri: 'data://temperature-standard',
      name: 'Temperature Data (Standard)',
      description: 'Current temperature value for standard subscription',
      mimeType: 'application/json',
      handler: _handleTemperatureStandardDataResource,
    );
  }

  void _registerTools() {
    // Counter tools
    server.addTool(
      name: 'increment',
      description: 'Increment the counter by 1',
      inputSchema: {
        'type': 'object',
        'properties': {}
      },
      handler: _handleIncrement,
    );

    server.addTool(
      name: 'decrement',
      description: 'Decrement the counter by 1',
      inputSchema: {
        'type': 'object',
        'properties': {}
      },
      handler: _handleDecrement,
    );

    server.addTool(
      name: 'reset',
      description: 'Reset the counter to 0',
      inputSchema: {
        'type': 'object',
        'properties': {}
      },
      handler: _handleReset,
    );
  }

  // Resource Handlers
  
  Future<ReadResourceResult> _handleApplicationResource(String uri, Map<String, dynamic> params) async {
    final appDefinition = {
      'type': 'application',
      'title': 'MCP Demo App',
      'theme': {
        'mode': 'light',
        'colors': {
          'primary': '#2196F3',
          'secondary': '#FF4081',
          'background': '#FFFFFF',
          'surface': '#F5F5F5',
          'error': '#F44336',
          'onPrimary': '#FFFFFF',
          'onSecondary': '#000000',
          'onBackground': '#000000',
          'onSurface': '#000000',
          'onError': '#FFFFFF',
        },
        'typography': {
          'h1': {
            'fontSize': 32,
            'fontWeight': 'bold',
            'letterSpacing': -1.5
          },
          'h2': {
            'fontSize': 28,
            'fontWeight': 'bold',
            'letterSpacing': -0.5
          },
          'body1': {
            'fontSize': 16,
            'fontWeight': 'normal',
            'letterSpacing': 0.5
          },
          'body2': {
            'fontSize': 14,
            'fontWeight': 'normal',
            'letterSpacing': 0.25
          },
        },
        'spacing': {
          'xs': 4,
          'sm': 8,
          'md': 16,
          'lg': 24,
          'xl': 32,
        },
        'borderRadius': {
          'sm': 4,
          'md': 8,
          'lg': 16,
          'xl': 24,
        },
      },
      'navigation': {
        'type': 'tabs',
        'tabs': [
          {
            'label': 'Counter',
            'icon': 'calculate',
            'route': '/counter',
          },
          {
            'label': 'Standard',
            'icon': 'thermostat',
            'route': '/temperature-standard',
          },
          {
            'label': 'Extended',
            'icon': 'speed',
            'route': '/temperature',
          },
        ],
      },
      'initialRoute': '/counter',
      'routes': {
        '/counter': 'ui://pages/counter',
        '/temperature-standard': 'ui://pages/temperature-standard',
        '/temperature': 'ui://pages/temperature',
      },
      'initialState': {
        'appName': 'MCP Demo',
        'version': '1.0.0',
        'themeMode': 'light',
      },
    };

    return ReadResourceResult(
      contents: [
        ResourceContentInfo(
          uri: uri,
          mimeType: 'application/json',
          text: jsonEncode(appDefinition),
        ),
      ],
    );
  }
  
  Future<ReadResourceResult> _handleCounterPageResource(String uri, Map<String, dynamic> params) async {
    final counterDefinition = {
      'type': 'page',
      'content': {
        'type': 'center',
        'child': {
          'type': 'column',
          'mainAxisAlignment': 'center',
          'children': [
            {
              'type': 'text',
              'content': 'Simple Counter Demo',
              'style': {
                'fontSize': '{{theme.typography.h1.fontSize}}',
                'fontWeight': '{{theme.typography.h1.fontWeight}}',
                'color': '{{theme.colors.primary}}'
              },
            },
            {
              'type': 'text',
              'content': 'Counter: {{counter}}',
              'style': {
                'fontSize': '{{theme.typography.body1.fontSize}}',
                'color': '{{theme.colors.onBackground}}'
              },
            },
            {
              'type': 'row',
              'mainAxisAlignment': 'center',
              'children': [
                {
                  'type': 'button',
                  'label': '-',
                  'style': 'elevated',
                  'onTap': {
                    'type': 'tool',
                    'tool': 'decrement',
                    'args': {},
                  },
                },
                {
                  'type': 'button',
                  'label': '+',
                  'style': 'elevated',
                  'onTap': {
                    'type': 'tool',
                    'tool': 'increment',
                    'args': {},
                  },
                },
                {
                  'type': 'button',
                  'label': 'Reset',
                  'style': 'outlined',
                  'onTap': {
                    'type': 'tool',
                    'tool': 'reset',
                    'args': {},
                  },
                },
              ],
            },
          ],
        },
      },
      'state': {
        'initial': {
          'counter': _counter,
        },
      },
    };

    return ReadResourceResult(
      contents: [
        ResourceContentInfo(
          uri: uri,
          mimeType: 'application/json',
          text: jsonEncode(counterDefinition),
        ),
      ],
    );
  }

  // Tool Handlers

  Future<CallToolResult> _handleIncrement(Map<String, dynamic> arguments) async {
    _counter++;
    
    return CallToolResult(
      content: [
        TextContent(
          text: jsonEncode({'counter': _counter}),
        ),
      ],
      isError: false,
    );
  }

  Future<CallToolResult> _handleDecrement(Map<String, dynamic> arguments) async {
    _counter--;
    
    return CallToolResult(
      content: [
        TextContent(
          text: jsonEncode({'counter': _counter}),
        ),
      ],
      isError: false,
    );
  }

  Future<CallToolResult> _handleReset(Map<String, dynamic> arguments) async {
    _counter = 0;
    
    return CallToolResult(
      content: [
        TextContent(
          text: jsonEncode({'counter': _counter}),
        ),
      ],
      isError: false,
    );
  }
  
  // Temperature Standard Page Handler
  
  Future<ReadResourceResult> _handleTemperatureStandardPageResource(String uri, Map<String, dynamic> params) async {
    final temperatureDefinition = {
      'type': 'page',
      'content': {
        'type': 'center',
        'child': {
          'type': 'column',
          'mainAxisAlignment': 'center',
          'children': [
            {
              'type': 'text',
              'content': 'Temperature Monitor (Standard Mode)',
              'style': {'fontSize': 24, 'fontWeight': 'bold'},
            },
            {
              'type': 'sizedBox',
              'height': 20,
            },
            {
              'type': 'container',
              'padding': 20,
              'decoration': {
                'borderRadius': 10,
                'color': '#f0f0f0',
              },
              'child': {
                'type': 'column',
                'children': [
                  {
                    'type': 'text',
                    'content': 'Current Temperature',
                    'style': {'fontSize': 16},
                  },
                  {
                    'type': 'text',
                    'content': '{{temperature}}°C',
                    'style': {'fontSize': 36, 'fontWeight': 'bold'},
                  },
                ],
              },
            },
            {
              'type': 'sizedBox',
              'height': 20,
            },
            {
              'type': 'text',
              'content': 'Subscription Status: {{subscriptionStatus}}',
              'style': {'fontSize': 14},
            },
            {
              'type': 'text',
              'content': 'Mode: Standard (URI only)',
              'style': {'fontSize': 12, 'color': '#666666'},
            },
            {
              'type': 'text',
              'content': 'Notifications Received: {{notificationCount || 0}}',
              'style': {'fontSize': 12, 'color': '#666666'},
            },
            {
              'type': 'sizedBox',
              'height': 20,
            },
            {
              'type': 'row',
              'mainAxisAlignment': 'center',
              'children': [
                {
                  'type': 'button',
                  'label': 'Subscribe',
                  'style': 'elevated',
                  'onTap': {
                    'type': 'resource',
                    'action': 'subscribe',
                    'uri': 'data://temperature-standard',
                    'binding': 'temperature',
                  },
                },
                {
                  'type': 'sizedBox',
                  'width': 10,
                },
                {
                  'type': 'button',
                  'label': 'Unsubscribe',
                  'style': 'outlined',
                  'onTap': {
                    'type': 'resource',
                    'action': 'unsubscribe',
                    'uri': 'data://temperature-standard',
                  },
                },
              ],
            },
          ],
        },
      },
      'state': {
        'initial': {
          'temperature': _standardTemperature,
          'subscriptionStatus': 'Not subscribed',
          'notificationCount': 0,
        },
      },
    };

    return ReadResourceResult(
      contents: [
        ResourceContentInfo(
          uri: uri,
          mimeType: 'application/json',
          text: jsonEncode(temperatureDefinition),
        ),
      ],
    );
  }
  
  // Temperature Page Handler
  
  Future<ReadResourceResult> _handleTemperaturePageResource(String uri, Map<String, dynamic> params) async {
    final temperatureDefinition = {
      'type': 'page',
      'content': {
        'type': 'center',
        'child': {
          'type': 'column',
          'mainAxisAlignment': 'center',
          'children': [
            {
              'type': 'text',
              'content': 'Temperature Monitor',
              'style': {'fontSize': 24, 'fontWeight': 'bold'},
            },
            {
              'type': 'sizedBox',
              'height': 20,
            },
            {
              'type': 'container',
              'padding': 20,
              'decoration': {
                'borderRadius': 10,
                'color': '#f0f0f0',
              },
              'child': {
                'type': 'column',
                'children': [
                  {
                    'type': 'text',
                    'content': 'Current Temperature',
                    'style': {'fontSize': 16},
                  },
                  {
                    'type': 'text',
                    'content': '{{temperature}}°C',
                    'style': {'fontSize': 36, 'fontWeight': 'bold'},
                  },
                ],
              },
            },
            {
              'type': 'sizedBox',
              'height': 20,
            },
            {
              'type': 'text',
              'content': 'Subscription Status: {{subscriptionStatus}}',
              'style': {'fontSize': 14},
            },
            {
              'type': 'text',
              'content': 'Mode: Extended (URI + content)',
              'style': {'fontSize': 12, 'color': '#666666'},
            },
            {
              'type': 'text',
              'content': 'Notifications Received: {{notificationCount || 0}}',
              'style': {'fontSize': 12, 'color': '#666666'},
            },
            {
              'type': 'sizedBox',
              'height': 20,
            },
            {
              'type': 'row',
              'mainAxisAlignment': 'center',
              'children': [
                {
                  'type': 'button',
                  'label': 'Subscribe',
                  'style': 'elevated',
                  'onTap': {
                    'type': 'resource',
                    'action': 'subscribe',
                    'uri': 'data://temperature',
                    'binding': 'temperature',
                  },
                },
                {
                  'type': 'sizedBox',
                  'width': 10,
                },
                {
                  'type': 'button',
                  'label': 'Unsubscribe',
                  'style': 'outlined',
                  'onTap': {
                    'type': 'resource',
                    'action': 'unsubscribe',
                    'uri': 'data://temperature',
                  },
                },
              ],
            },
          ],
        },
      },
      'state': {
        'initial': {
          'temperature': _temperature,
          'subscriptionStatus': 'Not subscribed',
          'notificationCount': 0,
        },
      },
    };

    return ReadResourceResult(
      contents: [
        ResourceContentInfo(
          uri: uri,
          mimeType: 'application/json',
          text: jsonEncode(temperatureDefinition),
        ),
      ],
    );
  }
  
  Future<ReadResourceResult> _handleTemperatureDataResource(String uri, Map<String, dynamic> params) async {
    return ReadResourceResult(
      contents: [
        ResourceContentInfo(
          uri: uri,
          mimeType: 'application/json',
          text: jsonEncode({'temperature': _temperature}),
        ),
      ],
    );
  }
  
  Future<ReadResourceResult> _handleTemperatureStandardDataResource(String uri, Map<String, dynamic> params) async {
    return ReadResourceResult(
      contents: [
        ResourceContentInfo(
          uri: uri,
          mimeType: 'application/json',
          text: jsonEncode({'temperature': _standardTemperature}),
        ),
      ],
    );
  }
  
  // Temperature simulation
  void _startTemperatureSimulation() {
    final random = Random();
    
    _temperatureTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Generate random temperature between 15°C and 30°C
      _temperature = 15.0 + random.nextDouble() * 15.0;
      
      // Round to 1 decimal place
      _temperature = double.parse(_temperature.toStringAsFixed(1));
      
      // Notify all subscribers about temperature change
      _notifyTemperatureSubscribers();
    });
  }
  
  void _notifyTemperatureSubscribers() {
    // Send MCP notifications to all subscribers
    final notificationData = {'temperature': _temperature};
    final jsonData = jsonEncode(notificationData);
    
    _log('Sending temperature notification: $_temperature°C');
    _log('Notification JSON: $jsonData');
    
    // Debug: Check server state
    _log('Server connected: ${server.isConnected}');
    _log('Server capabilities: ${server.capabilities.toJson()}');
    
    server.notifyResourceUpdated(
      'data://temperature',
      content: ResourceContent(
        uri: 'data://temperature',
        text: jsonData,
        mimeType: 'application/json',
      ),
    );
    _log('Temperature notification sent via MCP');
  }
  
  // Standard temperature simulation
  void _startStandardTemperatureSimulation() {
    final random = Random();
    
    _standardTemperatureTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Generate random temperature between 15°C and 30°C
      _standardTemperature = 15.0 + random.nextDouble() * 15.0;
      
      // Round to 1 decimal place
      _standardTemperature = double.parse(_standardTemperature.toStringAsFixed(1));
      
      // Notify all subscribers about temperature change
      _notifyStandardTemperatureSubscribers();
    });
  }
  
  void _notifyStandardTemperatureSubscribers() {
    // Send MCP notifications with URI only (standard mode)
    _log('Sending standard temperature notification (URI only)');
    _log('Standard temperature: $_standardTemperature°C');
    
    // In standard mode, we only send the URI - no content
    server.notifyResourceUpdated(
      'data://temperature-standard',
      // No content parameter - this is standard mode
    );
    _log('Standard temperature notification sent (URI only)');
  }
  
  void dispose() {
    _temperatureTimer?.cancel();
    _standardTemperatureTimer?.cancel();
  }
}