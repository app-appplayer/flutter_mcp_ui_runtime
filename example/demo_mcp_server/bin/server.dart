import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:mcp_server/mcp_server.dart';

/// Demo MCP Server Application
/// 
/// This example demonstrates how to create an MCP server that:
/// 1. Provides UI definitions using the MCP UI DSL v1.0 specification
/// 2. Handles tool calls for user interactions
/// 3. Supports resource subscriptions for real-time data updates
/// 
/// The server defines:
/// - An application with tab navigation and theme
/// - Multiple pages (counter, temperature monitors)
/// - Tools for manipulating state (increment, decrement, reset)
/// - Resources that can be subscribed to for real-time updates
void main(List<String> args) async {
  try {
    // Create server configuration
    // This defines the server's capabilities and metadata
    final config = McpServerConfig(
      name: 'Demo MCP Server',
      version: '1.0.0',
      capabilities: ServerCapabilities(
        // Enable tool support with change notifications
        tools: ToolsCapability(
          listChanged: true,
        ),
        // Enable resource support with subscriptions
        resources: ResourcesCapability(
          listChanged: true,
          subscribe: true,
        ),
        // Enable logging capability
        logging: LoggingCapability(),
      ),
      enableDebugLogging: false,
    );

    // Create server instance
    final server = McpServer.createServer(config);

    // Create STDIO transport for communication
    // The server will communicate via stdin/stdout with the client
    final transportResult = McpServer.createStdioTransport();
    final transport = transportResult.get();

    // Connect server to transport
    server.connect(transport);

    // Initialize server with our custom handler
    // MCPUIServer contains all the application logic
    final serverHandler = MCPUIServer(server);
    await serverHandler.initialize();

    // Server is now running and ready for connections
    // Keep the process alive indefinitely
    await Completer<void>().future;
  } catch (e, stackTrace) {
    // Log errors to stderr (stdout is reserved for MCP protocol)
    stderr.writeln('Error starting server: $e');
    stderr.writeln('Stack trace: $stackTrace');
    exit(1);
  }
}

/// Main server handler that manages UI definitions and state
/// 
/// This class demonstrates how to:
/// - Define UI resources using MCP UI DSL v1.0
/// - Handle tool calls to update state
/// - Manage resource subscriptions for real-time updates
class MCPUIServer {
  final Server server;
  
  // Application state - simple counter for the counter page
  int _counter = 0;
  
  // Temperature monitoring state for extended mode
  // Simulates a temperature sensor with real-time updates
  double _temperature = 20.0;
  Timer? _temperatureTimer;
  Set<String> _temperatureSubscribers = {}; // Track subscribers
  
  // Temperature monitoring state for standard mode
  // Demonstrates the difference between standard and extended notifications
  double _standardTemperature = 20.0;
  Timer? _standardTemperatureTimer;
  Set<String> _standardTemperatureSubscribers = {}; // Track standard subscribers

  MCPUIServer(this.server);

  /// Helper method to log debug messages to stderr
  void _log(String message) {
    stderr.writeln('[demo_mcp_server] $message');
  }

  void _setupSubscriptionHandlers() {
    // For now, assume we always have subscribers when notifications are sent
    // TODO: Implement proper subscription tracking when MCP server library supports it
    _log('Subscription handlers setup (simplified)');
  }

  /// Initializes the server with resources and tools
  Future<void> initialize() async {
    // Register all UI resources (application and pages)
    _registerResources();
    
    // Register all tools (actions that can be triggered from UI)
    _registerTools();
    
    // Setup handlers for resource subscriptions
    _setupSubscriptionHandlers();
    
    // Start simulating temperature changes for demo purposes
    _startTemperatureSimulation();
    _startStandardTemperatureSimulation();
  }

  /// Registers all UI and data resources with the MCP server
  /// 
  /// Resources are identified by URIs and return JSON data:
  /// - ui://app - Main application definition
  /// - ui://pages/* - Individual page definitions
  /// - data://* - Data resources for subscriptions
  void _registerResources() {
    // Main Application Resource
    // This defines the overall application structure, theme, and navigation
    server.addResource(
      uri: 'ui://app',
      name: 'Demo MCP Application',
      description: 'MCP Demo application with multiple pages',
      mimeType: 'application/json',
      handler: _handleApplicationResource,
    );
    
    // Counter Page Resource
    // A simple interactive page with increment/decrement buttons
    server.addResource(
      uri: 'ui://pages/counter',
      name: 'Counter Page',
      description: 'Simple counter demo page',
      mimeType: 'application/json',
      handler: _handleCounterPageResource,
    );
    
    // Temperature Monitor Page (Standard Mode)
    // Demonstrates standard MCP subscriptions (URI only in notifications)
    server.addResource(
      uri: 'ui://pages/temperature-standard',
      name: 'Temperature Monitor (Standard)',
      description: 'Temperature monitoring with standard MCP subscription',
      mimeType: 'application/json',
      handler: _handleTemperatureStandardPageResource,
    );
    
    // Temperature Monitor Page (Extended Mode)
    // Demonstrates extended subscriptions (URI + content in notifications)
    server.addResource(
      uri: 'ui://pages/temperature',
      name: 'Temperature Monitor',
      description: 'Real-time temperature monitoring with subscription',
      mimeType: 'application/json',
      handler: _handleTemperaturePageResource,
    );
    
    // Temperature Data Resource (Extended)
    // Returns current temperature value, supports subscriptions
    server.addResource(
      uri: 'data://temperature',
      name: 'Temperature Data',
      description: 'Current temperature value',
      mimeType: 'application/json',
      handler: _handleTemperatureDataResource,
    );
    
    // Temperature Data Resource (Standard)
    // Returns current temperature value, supports standard subscriptions
    server.addResource(
      uri: 'data://temperature-standard',
      name: 'Temperature Data (Standard)',
      description: 'Current temperature value for standard subscription',
      mimeType: 'application/json',
      handler: _handleTemperatureStandardDataResource,
    );
  }

  /// Registers tools that can be called from the UI
  /// 
  /// Tools are functions that:
  /// - Perform actions (like updating state)
  /// - Return results as JSON
  /// - Can be triggered by UI interactions (button clicks, etc.)
  void _registerTools() {
    // Increment tool - increases counter by 1
    server.addTool(
      name: 'increment',
      description: 'Increment the counter by 1',
      inputSchema: {
        'type': 'object',
        'properties': {}  // No parameters needed
      },
      handler: _handleIncrement,
    );

    // Decrement tool - decreases counter by 1
    server.addTool(
      name: 'decrement',
      description: 'Decrement the counter by 1',
      inputSchema: {
        'type': 'object',
        'properties': {}  // No parameters needed
      },
      handler: _handleDecrement,
    );

    // Reset tool - sets counter back to 0
    server.addTool(
      name: 'reset',
      description: 'Reset the counter to 0',
      inputSchema: {
        'type': 'object',
        'properties': {}  // No parameters needed
      },
      handler: _handleReset,
    );
  }

  // Resource Handlers
  
  /// Handles requests for the main application resource
  /// 
  /// Returns the application definition following MCP UI DSL v1.0 spec:
  /// - type: 'application' (required)
  /// - title: Application title
  /// - theme: Theme configuration with colors, typography, spacing
  /// - navigation: Navigation structure (tabs, drawer, bottom)
  /// - routes: Mapping of routes to page resources
  /// - state: Initial application state
  Future<ReadResourceResult> _handleApplicationResource(String uri, Map<String, dynamic> params) async {
    final appDefinition = {
      'type': 'application',
      'title': 'MCP Demo App',
      'version': '1.0.0',
      'initialRoute': '/counter',
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
        'items': [
          {
            'title': 'Counter',
            'icon': 'calculate',
            'route': '/counter',
          },
          {
            'title': 'Standard',
            'icon': 'thermostat',
            'route': '/temperature-standard',
          },
          {
            'title': 'Extended',
            'icon': 'speed',
            'route': '/temperature',
          },
        ],
      },
      'state': {
        'initial': {
          'appName': 'MCP Demo',
          'version': '1.0.0',
          'themeMode': 'light',
        },
      },
      'routes': {
        '/counter': 'ui://pages/counter',
        '/temperature-standard': 'ui://pages/temperature-standard',
        '/temperature': 'ui://pages/temperature',
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
  
  /// Handles requests for the counter page resource
  /// 
  /// Returns a page definition with:
  /// - Metadata about the page
  /// - Initial state (current counter value)
  /// - UI content structure using MCP UI DSL widgets
  /// - Button actions that trigger tools
  Future<ReadResourceResult> _handleCounterPageResource(String uri, Map<String, dynamic> params) async {
    final counterDefinition = {
      'type': 'page',
      'metadata': {
        'title': 'Counter Demo',
        'description': 'Simple counter demonstration',
      },
      'runtime': {
        'services': {
          'state': {
            'initialState': {
              'counter': _counter,  // Provide current counter value
            },
          },
        },
      },
      'content': {
        'type': 'center',
        'child': {
          'type': 'linear',
          'direction': 'vertical',
          'alignment': 'center',
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
                'color': '{{theme.colors.textOnBackground}}'
              },
            },
            {
              'type': 'linear',
              'direction': 'horizontal',
              'alignment': 'center',
              'children': [
                {
                  'type': 'button',
                  'label': '-',
                  'variant': 'elevated',
                  'click': {
                    'type': 'tool',
                    'tool': 'decrement',
                    'params': {},
                  },
                },
                {
                  'type': 'button',
                  'label': '+',
                  'variant': 'elevated',
                  'click': {
                    'type': 'tool',
                    'tool': 'increment',
                    'params': {},
                  },
                },
                {
                  'type': 'button',
                  'label': 'Reset',
                  'variant': 'outlined',
                  'click': {
                    'type': 'tool',
                    'tool': 'reset',
                    'params': {},
                  },
                },
              ],
            },
          ],
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

  /// Handles the 'increment' tool call
  /// Increases the counter by 1 and returns the new value
  Future<CallToolResult> _handleIncrement(Map<String, dynamic> arguments) async {
    _counter++;
    
    // Return the updated state as JSON
    // The client will update its state with this value
    return CallToolResult(
      content: [
        TextContent(
          text: jsonEncode({'counter': _counter}),
        ),
      ],
      isError: false,
    );
  }

  /// Handles the 'decrement' tool call
  /// Decreases the counter by 1 and returns the new value
  Future<CallToolResult> _handleDecrement(Map<String, dynamic> arguments) async {
    _counter--;
    
    // Return the updated state as JSON
    return CallToolResult(
      content: [
        TextContent(
          text: jsonEncode({'counter': _counter}),
        ),
      ],
      isError: false,
    );
  }

  /// Handles the 'reset' tool call
  /// Resets the counter to 0 and returns the new value
  Future<CallToolResult> _handleReset(Map<String, dynamic> arguments) async {
    _counter = 0;
    
    // Return the updated state as JSON
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
  
  /// Handles requests for the standard temperature monitor page
  /// 
  /// This page demonstrates standard MCP subscriptions where:
  /// - Notifications contain only the resource URI
  /// - Client must read the resource to get updated data
  /// - More network calls but follows standard MCP protocol
  Future<ReadResourceResult> _handleTemperatureStandardPageResource(String uri, Map<String, dynamic> params) async {
    final temperatureDefinition = {
      'type': 'page',
      'metadata': {
        'title': 'Temperature Monitor (Standard)',
        'description': 'Temperature monitoring with standard MCP subscription',
      },
      'runtime': {
        'services': {
          'state': {
            'initialState': {
              'temperature': _standardTemperature,
              'subscriptionStatus': 'Not subscribed',
              'notificationCount': 0,
            },
          },
        },
      },
      'content': {
        'type': 'center',
        'child': {
          'type': 'linear',
          'direction': 'vertical',
          'alignment': 'center',
          'children': [
            {
              'type': 'text',
              'content': 'Temperature Monitor (Standard Mode)',
              'style': {'fontSize': 24, 'fontWeight': 'bold'},
            },
            {
              'type': 'box',
              'height': 20,
            },
            {
              'type': 'box',
              'padding': {'all': 20},
              'backgroundColor': '#FFf0f0f0',
              'borderRadius': 10,
              'child': {
                'type': 'linear',
                'direction': 'vertical',
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
              'type': 'box',
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
              'type': 'box',
              'height': 20,
            },
            {
              'type': 'linear',
              'direction': 'horizontal',
              'alignment': 'center',
              'children': [
                {
                  'type': 'button',
                  'label': 'Subscribe',
                  'variant': 'elevated',
                  'click': {
                    'type': 'resource',
                    'action': 'subscribe',
                    'uri': 'data://temperature-standard',
                    'binding': 'temperature',
                  },
                },
                {
                  'type': 'box',
                  'width': 10,
                },
                {
                  'type': 'button',
                  'label': 'Unsubscribe',
                  'variant': 'outlined',
                  'click': {
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
  
  /// Handles requests for the extended temperature monitor page
  /// 
  /// This page demonstrates extended MCP subscriptions where:
  /// - Notifications include both URI and content
  /// - Client gets data directly in notifications
  /// - More efficient for frequent updates
  Future<ReadResourceResult> _handleTemperaturePageResource(String uri, Map<String, dynamic> params) async {
    final temperatureDefinition = {
      'type': 'page',
      'metadata': {
        'title': 'Temperature Monitor (Extended)',
        'description': 'Real-time temperature monitoring with extended subscription',
      },
      'runtime': {
        'services': {
          'state': {
            'initialState': {
              'temperature': _temperature,
              'subscriptionStatus': 'Not subscribed',
              'notificationCount': 0,
            },
          },
        },
      },
      'content': {
        'type': 'center',
        'child': {
          'type': 'linear',
          'direction': 'vertical',
          'alignment': 'center',
          'children': [
            {
              'type': 'text',
              'content': 'Temperature Monitor',
              'style': {'fontSize': 24, 'fontWeight': 'bold'},
            },
            {
              'type': 'box',
              'height': 20,
            },
            {
              'type': 'box',
              'padding': {'all': 20},
              'backgroundColor': '#FFf0f0f0',
              'borderRadius': 10,
              'child': {
                'type': 'linear',
                'direction': 'vertical',
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
              'type': 'box',
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
              'type': 'box',
              'height': 20,
            },
            {
              'type': 'linear',
              'direction': 'horizontal',
              'alignment': 'center',
              'children': [
                {
                  'type': 'button',
                  'label': 'Subscribe',
                  'variant': 'elevated',
                  'click': {
                    'type': 'resource',
                    'action': 'subscribe',
                    'uri': 'data://temperature',
                    'binding': 'temperature',
                  },
                },
                {
                  'type': 'box',
                  'width': 10,
                },
                {
                  'type': 'button',
                  'label': 'Unsubscribe',
                  'variant': 'outlined',
                  'click': {
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
  
  /// Starts simulating temperature changes for demo purposes
  /// 
  /// In a real application, this would read from actual sensors.
  /// Here we generate random temperatures between 15-30°C every second.
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
  
  /// Sends notifications to all subscribers of the temperature resource
  /// 
  /// This demonstrates extended mode notifications where:
  /// - The notification includes the resource content
  /// - Clients don't need to make additional calls to get the data
  void _notifyTemperatureSubscribers() {
    // Prepare the temperature data
    final notificationData = {'temperature': _temperature};
    final jsonData = jsonEncode(notificationData);
    
    _log('Sending temperature notification: $_temperature°C');
    _log('Notification JSON: $jsonData');
    
    // Debug: Check server state
    _log('Server connected: ${server.isConnected}');
    _log('Server capabilities: ${server.capabilities.toJson()}');
    
    // Send extended notification with content included
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
  
  /// Sends notifications for standard mode subscriptions
  /// 
  /// This demonstrates standard mode notifications where:
  /// - Only the resource URI is sent
  /// - Clients must call readResource to get the updated data
  /// - Follows the standard MCP protocol specification
  void _notifyStandardTemperatureSubscribers() {
    _log('Sending standard temperature notification (URI only)');
    _log('Standard temperature: $_standardTemperature°C');
    
    // In standard mode, we only send the URI - no content
    // Clients will receive the notification and must read the resource
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