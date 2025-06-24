import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:mcp_client/mcp_client.dart';

/// Demo MCP Client Application
/// 
/// This example demonstrates how to create a Flutter application that:
/// 1. Connects to an MCP server via STDIO transport
/// 2. Loads UI definitions from the server
/// 3. Renders dynamic UI using flutter_mcp_ui_runtime
/// 4. Handles tool calls and resource subscriptions
/// 
/// The client is completely UI-agnostic - it doesn't know anything about
/// the specific UI structure, just renders what the server provides.
void main() {
  runApp(const MCPClientApp());
}

/// Root widget for the MCP Client app
/// 
/// Provides the basic Material app wrapper for the demo.
/// The actual MCP functionality is handled by MCPClientDemo.
class MCPClientApp extends StatelessWidget {
  const MCPClientApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MCP Client',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const MCPClientDemo(),
    );
  }
}

/// Main demo widget that handles MCP client connection and UI rendering
/// 
/// This widget demonstrates the complete lifecycle of an MCP UI client:
/// - Connecting to an MCP server
/// - Loading application definitions
/// - Rendering dynamic UI
/// - Handling user interactions
class MCPClientDemo extends StatefulWidget {
  const MCPClientDemo({super.key});

  @override
  State<MCPClientDemo> createState() => _MCPClientDemoState();
}

class _MCPClientDemoState extends State<MCPClientDemo> {
  /// MCP client instance for server communication
  Client? _mcpClient;
  
  /// Runtime instance that renders the UI
  MCPUIRuntime? _runtime;
  
  /// Error message if connection fails
  String? _error;
  
  /// Helper method to log debug messages to stderr
  /// (stdout is reserved for MCP protocol communication)
  void _log(String message) {
    if (kDebugMode) {
      stderr.writeln('[demo_mcp_client] $message');
    }
  }

  @override
  void initState() {
    super.initState();
    _connectToMCPServer();
  }
  
  @override
  void dispose() {
    _runtime?.destroy();
    _mcpClient?.dispose();
    super.dispose();
  }
  
  /// Connects to the MCP server and initializes the client
  /// 
  /// This method:
  /// 1. Creates an MCP client with STDIO transport
  /// 2. Launches the server process (dart run bin/server.dart)
  /// 3. Establishes the MCP connection
  /// 4. Sets up notification handlers for real-time updates
  /// 5. Loads the application UI definition
  Future<void> _connectToMCPServer() async {
    try {
      _log('Connecting to MCP server...');
      
      // Create client configuration
      // The client identifies itself to the server with a name and version
      final config = McpClient.simpleConfig(
        name: 'Flutter Counter Demo Client',
        version: '1.0.0',
        enableDebugLogging: kDebugMode,
      );
      
      // Create STDIO transport configuration
      // This launches the server process and communicates via stdin/stdout
      final transportConfig = TransportConfig.stdio(
        command: 'dart',
        arguments: ['run', 'bin/server.dart'],
        workingDirectory: '../demo_mcp_server',
      );
      
      // Connect to server
      final clientResult = await McpClient.createAndConnect(
        config: config,
        transportConfig: transportConfig,
      );
      
      if (clientResult.isFailure) {
        throw Exception('Failed to connect: ${clientResult.failureOrNull}');
      }
      
      _mcpClient = clientResult.get();
      _log('Connected successfully!');
      
      // Setup notification handlers for resource updates
      _setupNotificationHandlers();
      
      // Load the application UI definition from the server
      await _loadApplication();
      
    } catch (e, stack) {
      _log('Failed to connect: $e');
      _log('Stack trace: $stack');
      setState(() {
        _error = e.toString();
      });
    }
  }
  
  /// Loads the application UI definition from the server
  /// 
  /// This method:
  /// 1. Reads the 'ui://app' resource which contains the main application definition
  /// 2. Parses the JSON response
  /// 3. Initializes the MCP UI Runtime with the definition
  /// 4. Provides a pageLoader callback for loading individual pages
  /// 
  /// The runtime handles all UI rendering - this client just provides
  /// the data and callbacks.
  Future<void> _loadApplication() async {
    if (_mcpClient == null) return;
    
    try {
      _log('Loading application...');
      
      // Read the main application resource from the server
      // The 'ui://app' resource contains the application structure,
      // theme, navigation, and routes
      final resource = await _mcpClient!.readResource('ui://app');
      final content = resource.contents.first;
      final text = content.text;
      
      if (text == null) {
        throw Exception('No text content in resource');
      }
      
      // Parse the application definition
      final definition = jsonDecode(text) as Map<String, dynamic>;
      _log('Application definition loaded: ${definition['type']}');
      
      // Initialize the MCP UI Runtime
      // The runtime will handle all UI rendering based on the definition
      _runtime = MCPUIRuntime(enableDebugMode: true);
      
      await _runtime!.initialize(
        definition,
        // Provide a page loader callback
        // This is called when the runtime needs to load a page
        pageLoader: (uri) async {
          _log('Loading page: $uri');
          final pageResource = await _mcpClient!.readResource(uri);
          final pageContent = pageResource.contents.first;
          final text = pageContent.text ?? '{}';
          return jsonDecode(text);
        },
      );
      
      _log('Application loaded successfully!');
      
      // Update UI to show the loaded application
      setState(() {});
      
    } catch (e) {
      _log('Failed to load application: $e');
      setState(() {
        _error = 'Failed to load application: $e';
      });
    }
  }

  /// Handles tool calls from the UI
  /// 
  /// When a user interacts with the UI (e.g., clicks a button), the runtime
  /// may trigger a tool call. This method:
  /// 1. Sends the tool call to the MCP server
  /// 2. Receives the response
  /// 3. Updates the UI state with any changes
  /// 
  /// For example, clicking an "increment" button calls the "increment" tool,
  /// which returns the new counter value.
  Future<void> _handleToolCall(String tool, Map<String, dynamic> params) async {
    _log('Tool call: $tool with params: $params');
    
    if (_mcpClient == null) {
      _log('Cannot execute tool: not connected');
      return;
    }
    
    try {
      // Call the tool on the MCP server
      // The server executes the tool and returns the result
      final result = await _mcpClient!.callTool(tool, params);
      _log('Tool result: ${result.content.length} content items');
      
      if (result.content.isNotEmpty) {
        final firstContent = result.content.first;
        if (firstContent is TextContent) {
          try {
            // Parse the JSON response from the server
            // The response typically contains state updates
            final responseData = jsonDecode(firstContent.text) as Map<String, dynamic>;
            _log('Parsed response: $responseData');
            
            // Update the runtime state with the server response
            // This automatically triggers UI updates through the runtime's
            // binding system
            if (_runtime?.isInitialized == true) {
              // Update any state keys returned by the tool
              responseData.forEach((key, value) {
                _runtime!.stateManager.set(key, value);
                _log('Updated $key state to: $value');
              });
            }
            
          } catch (e) {
            _log('Failed to parse tool response: $e');
          }
        }
      }
      
    } catch (e) {
      _log('Tool execution failed: $e');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tool failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// Handles resource subscription actions from the UI
  /// 
  /// Resources in MCP can be subscribed to for real-time updates.
  /// This method handles:
  /// - subscribe: Start receiving updates when a resource changes
  /// - unsubscribe: Stop receiving updates
  /// 
  /// When subscribed, the server will send notifications whenever the
  /// resource data changes, which are handled by _setupNotificationHandlers.
  /// 
  /// @param action The action to perform ('subscribe' or 'unsubscribe')
  /// @param resource The resource URI to subscribe to (e.g., 'data://temperature')
  /// @param binding The state key to bind the resource data to
  Future<void> _handleResourceAction(String action, String resource, [String? binding]) async {
    _log('Resource $action called: $resource${binding != null ? ' -> $binding' : ''}');
    
    if (_mcpClient == null) {
      _log('Cannot execute resource action: not connected');
      return;
    }
    
    try {
      if (action == 'subscribe') {
        // Subscribe to the resource via MCP protocol
        _log('Calling MCP subscribeResource for: $resource');
        await _mcpClient!.subscribeResource(resource);
        _log('Successfully subscribed to: $resource');
        
        // Register the subscription with the runtime
        // This tells the runtime which state key to update when
        // notifications are received for this resource
        if (binding != null && _runtime?.isInitialized == true) {
          _runtime!.registerResourceSubscription(resource, binding);
          _log('Registered subscription mapping: $resource -> $binding');
        }
        
        // Update UI to show subscription status
        if (_runtime?.isInitialized == true) {
          _runtime!.stateManager.set('subscriptionStatus', 'Subscribed');
          _runtime!.stateManager.set('notificationCount', 0);
          _log('Updated subscription status to: Subscribed');
          
          // Read initial data from the resource
          // This ensures the UI shows current data immediately
          try {
            final resourceData = await _mcpClient!.readResource(resource);
            final content = resourceData.contents.first;
            final text = content.text;
            if (text != null) {
              final data = jsonDecode(text);
              _log('Initial resource data: $data');
              // Update state with resource data
              data.forEach((key, value) {
                _runtime!.stateManager.set(key, value);
              });
            }
          } catch (e) {
            _log('Failed to read initial resource data: $e');
          }
        }
      } else if (action == 'unsubscribe') {
        // Unsubscribe from the resource
        _log('Calling MCP unsubscribeResource for: $resource');
        await _mcpClient!.unsubscribeResource(resource);
        _log('Successfully unsubscribed from: $resource');
        
        // Remove the subscription from the runtime
        if (_runtime?.isInitialized == true) {
          _runtime!.unregisterResourceSubscription(resource);
          _log('Unregistered subscription mapping for: $resource');
        }
        
        // Update UI to show unsubscribed status
        if (_runtime?.isInitialized == true) {
          _runtime!.stateManager.set('subscriptionStatus', 'Not subscribed');
          _log('Updated subscription status to: Not subscribed');
        }
      }
      
    } catch (e) {
      _log('Resource $action failed: $e');
    }
  }
  
  /// Sets up handlers for MCP notifications
  /// 
  /// The MCP protocol supports notifications for real-time updates.
  /// This method registers a handler for resource update notifications.
  /// 
  /// When a subscribed resource changes on the server, it sends a
  /// 'notifications/resources/updated' notification. The runtime then:
  /// 1. Identifies which state key is bound to the resource
  /// 2. Updates the state with the new data
  /// 3. Triggers UI updates automatically
  void _setupNotificationHandlers() {
    if (_mcpClient == null) return;
    
    _log('Setting up notification handlers...');
    
    // Register handler for resource update notifications
    // This is called whenever a subscribed resource changes on the server
    _mcpClient!.onNotification('notifications/resources/updated', (params) async {
      _log('=== NOTIFICATION RECEIVED ===');
      _log('Method: notifications/resources/updated');
      _log('Params: $params');
      
      if (_runtime?.isInitialized == true) {
        // Pass the notification to the runtime for processing
        // The runtime will:
        // 1. Extract the resource URI from the notification
        // 2. Find the state binding for that resource
        // 3. Update the state with the new data
        await _runtime!.handleNotification(
          {
            'method': 'notifications/resources/updated',
            'params': params,
          },
          // Provide a resource reader callback for standard mode
          // (when the notification doesn't include the data)
          resourceReader: (uri) async {
            final resource = await _mcpClient!.readResource(uri);
            return resource.contents.first.text ?? '{}';
          },
        );
      }
      
      _log('=== NOTIFICATION END ===');
    });
    
    _log('Notification handlers setup complete');
  }
  

  @override
  Widget build(BuildContext context) {
    // The build method is simple - it delegates all UI rendering to the runtime
    
    // If runtime is initialized, let it handle all UI rendering
    if (_runtime?.isInitialized == true) {
      return _runtime!.buildUI(
        context: context,
        // Provide callbacks for user interactions
        onToolCall: _handleToolCall,
        onResourceSubscribe: (uri, binding) async {
          await _handleResourceAction('subscribe', uri, binding);
        },
        onResourceUnsubscribe: (uri) async {
          await _handleResourceAction('unsubscribe', uri);
        },
      );
    }
    
    // Show error state if connection failed
    if (_error != null) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Error: $_error'),
          ),
        ),
      );
    }
    
    // Show loading state while connecting
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}