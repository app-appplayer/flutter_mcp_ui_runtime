import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:mcp_client/mcp_client.dart';

void main() {
  runApp(const MCPClientApp());
}

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

class MCPClientDemo extends StatefulWidget {
  const MCPClientDemo({super.key});

  @override
  State<MCPClientDemo> createState() => _MCPClientDemoState();
}

class _MCPClientDemoState extends State<MCPClientDemo> {
  Client? _mcpClient;
  MCPUIRuntime? _runtime;
  bool _isConnected = false;
  bool _isConnecting = false;
  String _connectionError = '';
  
  Map<String, dynamic>? _currentDefinition;
  
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
  
  Future<void> _connectToMCPServer() async {
    setState(() {
      _isConnecting = true;
      _connectionError = '';
    });
    
    try {
      _log('Connecting to MCP server...');
      
      // Create client configuration
      final config = McpClient.simpleConfig(
        name: 'Flutter Counter Demo Client',
        version: '1.0.0',
        enableDebugLogging: kDebugMode,
      );
      
      // Create STDIO transport
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
      
      setState(() {
        _isConnected = true;
        _isConnecting = false;
      });
      
      _log('Connected successfully!');
      
      // Setup notification handlers
      _setupNotificationHandlers();
      
      // Load application
      await _loadApplication();
      
    } catch (e) {
      _log('Failed to connect: $e');
      setState(() {
        _isConnecting = false;
        _connectionError = e.toString();
      });
    }
  }
  
  Future<void> _loadApplication() async {
    if (_mcpClient == null) return;
    
    try {
      _log('Loading application...');
      
      // Read application resource
      final resource = await _mcpClient!.readResource('ui://app');
      final content = resource.contents.first;
      final text = content.text;
      
      if (text == null) {
        throw Exception('No text content in resource');
      }
      
      final definition = jsonDecode(text) as Map<String, dynamic>;
      _log('Application definition loaded: ${definition['type']}');
      
      // Initialize runtime with page loader and disable cache
      _runtime = MCPUIRuntime(enableDebugMode: true);
      await _runtime!.initialize(
        definition,
        pageLoader: (uri) async {
          _log('Loading page: $uri');
          final pageResource = await _mcpClient!.readResource(uri);
          final pageContent = pageResource.contents.first;
          final text = pageContent.text ?? '{}';
          return jsonDecode(text);
        },
        useCache: false,  // Disable caching to ensure real-time updates
      );
      
      
      setState(() {
        _currentDefinition = definition;
      });
      
      _log('Application loaded successfully!');
      
    } catch (e) {
      _log('Failed to load application: $e');
      setState(() {
        _connectionError = 'Failed to load application: $e';
      });
    }
  }

  Future<void> _handleToolCall(String tool, Map<String, dynamic> args) async {
    _log('Tool call: $tool with args: $args');
    
    if (!_isConnected || _mcpClient == null) {
      _log('Cannot execute tool: not connected');
      return;
    }
    
    try {
      // Call tool on MCP server
      final result = await _mcpClient!.callTool(tool, args);
      _log('Tool result: ${result.content.length} content items');
      
      if (result.content.isNotEmpty) {
        final firstContent = result.content.first;
        if (firstContent is TextContent) {
          try {
            // Parse JSON response
            final responseData = jsonDecode(firstContent.text) as Map<String, dynamic>;
            _log('Parsed response: $responseData');
            
            // Update runtime state with server response
            if (_runtime?.isInitialized == true && responseData.containsKey('counter')) {
              _runtime!.stateManager.set('counter', responseData['counter']);
              _log('Updated counter state to: ${responseData['counter']}');
            }
            
          } catch (e) {
            _log('Failed to parse tool response: $e');
          }
        }
      }
      
    } catch (e) {
      _log('Tool execution failed: $e');
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
  
  Future<void> _handleResourceSubscribe(String uri, String binding) async {
    _log('Resource subscribe called: $uri -> $binding');
    
    if (!_isConnected || _mcpClient == null) {
      _log('Cannot subscribe: not connected');
      return;
    }
    
    try {
      // Subscribe to resource via MCP
      _log('Calling MCP subscribeResource for: $uri');
      await _mcpClient!.subscribeResource(uri);
      _log('Successfully subscribed to: $uri');
      
      // Update subscription status in UI
      if (_runtime?.isInitialized == true) {
        _runtime!.stateManager.set('subscriptionStatus', 'Subscribed');
        _runtime!.stateManager.set('notificationCount', 0);
        _log('Updated subscription status to: Subscribed');
        
        // Request initial temperature value to verify connection
        try {
          final resource = await _mcpClient!.readResource('data://temperature');
          final content = resource.contents.first;
          final text = content.text;
          if (text != null) {
            final data = jsonDecode(text);
            _log('Initial temperature data: $data');
            _runtime!.stateManager.set('temperature', data['temperature']);
          }
        } catch (e) {
          _log('Failed to read initial temperature: $e');
        }
      }
      
    } catch (e) {
      _log('Subscribe failed: $e');
    }
  }
  
  Future<void> _handleResourceUnsubscribe(String uri) async {
    _log('Resource unsubscribe called: $uri');
    
    if (!_isConnected || _mcpClient == null) {
      _log('Cannot unsubscribe: not connected');
      return;
    }
    
    try {
      // Unsubscribe from resource via MCP
      _log('Calling MCP unsubscribeResource for: $uri');
      await _mcpClient!.unsubscribeResource(uri);
      _log('Successfully unsubscribed from: $uri');
      
      // Update subscription status in UI
      if (_runtime?.isInitialized == true) {
        _runtime!.stateManager.set('subscriptionStatus', 'Not subscribed');
        _log('Updated subscription status to: Not subscribed');
      }
      
    } catch (e) {
      _log('Unsubscribe failed: $e');
    }
  }
  
  void _setupNotificationHandlers() {
    if (_mcpClient == null) return;
    
    _log('Setting up notification handlers...');
    
    // Set up a single notification handler that passes all notifications to runtime
    // Runtime will internally handle different notification types
    final notificationHandler = (String method, Function(Map<String, dynamic>) handler) {
      _mcpClient!.onNotification(method, handler);
    };
    
    // For now, we need to register for specific notification types we care about
    notificationHandler('notifications/resources/updated', (params) async {
      _log('=== NOTIFICATION RECEIVED ===');
      _log('Method: notifications/resources/updated');
      _log('Params: $params');
      
      if (_runtime?.isInitialized == true) {
        // Create notification object as per spec
        final notification = {
          'method': 'notifications/resources/updated',
          'params': params,
        };
        
        // Pass to runtime with resource reader
        await _runtime!.handleNotification(
          notification,
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
    // If we have an application loaded, let the runtime handle the UI
    if (_currentDefinition != null && _runtime?.isInitialized == true) {
      try {
        return _runtime!.buildUI(
          context: context,
          onToolCall: _handleToolCall,
          onResourceSubscribe: _handleResourceSubscribe,
          onResourceUnsubscribe: _handleResourceUnsubscribe,
        );
      } catch (e) {
        return _buildErrorScaffold(e);
      }
    }
    
    // Otherwise show connection status
    return Scaffold(
      appBar: AppBar(
        title: const Text('MCP Client'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isConnecting ? null : _connectToMCPServer,
            tooltip: 'Reconnect',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }
  
  Widget _buildStatusBar() {
    Color backgroundColor;
    String statusText;
    IconData icon;
    
    if (_isConnecting) {
      backgroundColor = Colors.blue.shade50;
      statusText = 'Connecting to MCP server...';
      icon = Icons.sync;
    } else if (_isConnected) {
      backgroundColor = Colors.green.shade50;
      statusText = 'Connected - Application Ready';
      icon = Icons.check_circle;
    } else {
      backgroundColor = Colors.red.shade50;
      statusText = 'Disconnected - $_connectionError';
      icon = Icons.error;
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      color: backgroundColor,
      child: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBody() {
    if (_isConnecting) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Connecting to MCP server...'),
          ],
        ),
      );
    }
    
    if (_currentDefinition != null && _runtime?.isInitialized == true) {
      return const Center(
        child: Text('Application is rendering above'),
      );
    }
    
    if (!_isConnected) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Failed to connect to MCP server',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _connectionError,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _connectToMCPServer,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Connection'),
            ),
          ],
        ),
      );
    }
    
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
  
  Widget _buildErrorScaffold(dynamic error) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MCP Client - Error'),
        backgroundColor: Colors.red,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Error rendering application',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _connectToMCPServer,
              icon: const Icon(Icons.refresh),
              label: const Text('Reconnect'),
            ),
          ],
        ),
      ),
    );
  }
}