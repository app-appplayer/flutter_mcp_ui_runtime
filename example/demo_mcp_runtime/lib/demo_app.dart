import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'debug_panel.dart';
import 'demo_definitions.dart';

/// Logger for demo app
final _logger = MCPLogger('DemoApp');

/// Demo app showcasing comprehensive MCP UI Runtime features
class MCPUIRuntimeDemoApp extends StatelessWidget {
  const MCPUIRuntimeDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MCP UI Runtime Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const DemoHomePage(),
    );
  }
}

class DemoHomePage extends StatefulWidget {
  const DemoHomePage({super.key});

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage> {
  int selectedDemoIndex = 0;
  bool _showDebugPanel = false;
  Map<String, dynamic> _currentState = {};
  final Map<int, MCPUIRuntime> _runtimeCache = {};
  StateService? _currentStateService;
  
  @override
  void initState() {
    super.initState();
    _currentState = _getInitialState(selectedDemoIndex);
  }
  
  @override
  void dispose() {
    // Clear runtime cache
    _runtimeCache.clear();
    super.dispose();
  }
  
  late final List<DemoItem> demos = [
    DemoItem(
      title: '📄 Page Type Demo',
      description: 'Single page UI definition',
      jsonDefinition: pageTypeDemo,
    ),
    DemoItem(
      title: '📱 Application Type Demo',
      description: 'Multi-page application with navigation',
      jsonDefinition: applicationTypeDemo,
    ),
    DemoItem(
      title: '🧭 Navigation Demo',
      description: 'Drawer, tabs, and bottom navigation',
      jsonDefinition: navigationDemo,
    ),
    DemoItem(
      title: '🚀 Lifecycle Management',
      description: 'Runtime lifecycle with hooks',
      jsonDefinition: lifecycleManagementDemo,
    ),
    DemoItem(
      title: '⚙️ Background Services',
      description: 'Periodic, scheduled, and event-based services',
      jsonDefinition: backgroundServicesDemo,
    ),
    DemoItem(
      title: '⚡ State & Bindings',
      description: 'Advanced state management and bindings',
      jsonDefinition: stateAndBindingsDemo,
    ),
    DemoItem(
      title: '🔔 Notifications System',
      description: 'Real-time notifications and channels',
      jsonDefinition: notificationSystemDemo,
    ),
    DemoItem(
      title: '🔧 Tool Integration',
      description: 'MCP tool calls and integrations',
      jsonDefinition: toolIntegrationDemo,
    ),
  ];

  Map<String, dynamic> _getInitialState(int index) {
    return demos[index].jsonDefinition['runtime']?['services']?['state']?['initialState'] ?? {};
  }

  Future<void> _updateStateService(MCPUIRuntime runtime) async {
    // For now, skip StateService integration to avoid complexity
    // TODO: Implement proper StateService integration when runtime is stable
    _currentStateService = null;
    if (_currentStateService != null) {
      // Listen to state changes from the runtime's state service
      _currentStateService!.addListener(() {
        if (mounted) {
          setState(() {
            _currentState = Map<String, dynamic>.from(_currentStateService!.state);
          });
        }
      });
    }
  }

  void _updateState(String key, dynamic value) {
    // Use runtime's state service if available, otherwise fall back to local state
    if (_currentStateService != null) {
      _currentStateService!.setValue(key, value);
    } else {
      setState(() {
        _currentState[key] = value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MCP UI Runtime Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(_showDebugPanel ? Icons.bug_report : Icons.bug_report_outlined),
            onPressed: () {
              setState(() {
                _showDebugPanel = !_showDebugPanel;
              });
            },
            tooltip: 'Toggle Debug Panel',
          ),
        ],
      ),
      body: Row(
        children: [
          // Demo Selection Panel
          Container(
            width: 300,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: const Text(
                    'Runtime Features',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: demos.length,
                    itemBuilder: (context, index) {
                      final demo = demos[index];
                      final isSelected = selectedDemoIndex == index;
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        elevation: isSelected ? 4 : 1,
                        color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : null,
                        child: ListTile(
                          title: Text(demo.title),
                          subtitle: Text(demo.description),
                          selected: isSelected,
                          onTap: () {
                            setState(() {
                              selectedDemoIndex = index;
                              _currentState = _getInitialState(index);
                            });
                            // Update state service for new demo
                            _getOrCreateRuntime(index).then(_updateStateService);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Demo Display Area
          Expanded(
            flex: 2,
            child: Column(
              children: [
                // Demo Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              demos[selectedDemoIndex].title,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              demos[selectedDemoIndex].description,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => Dialog.fullscreen(
                              child: Scaffold(
                                appBar: AppBar(
                                  title: Text(demos[selectedDemoIndex].title),
                                  leading: IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () => Navigator.of(context).pop(),
                                  ),
                                ),
                                body: FutureBuilder<MCPUIRuntime>(
                                  future: _getOrCreateRuntime(selectedDemoIndex),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasError) {
                                      return Center(
                                        child: Text('Error: ${snapshot.error}',
                                          style: const TextStyle(color: Colors.red)),
                                      );
                                    }
                                    
                                    if (!snapshot.hasData) {
                                      return const Center(child: CircularProgressIndicator());
                                    }
                                    
                                    final runtime = snapshot.data!;
                                    return runtime.buildUI(
                                      context: context,
                                      initialState: _currentState,
                                      onToolCall: (tool, args) {
                                        _handleToolCall(runtime, tool, args);
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.fullscreen),
                        label: const Text('Full Screen'),
                      ),
                    ],
                  ),
                ),
                
                // Demo Content
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: _buildDemoContent(),
                  ),
                ),
              ],
            ),
          ),
          
          // Debug Panel (conditionally shown)
          if (_showDebugPanel)
            Container(
              width: 350,
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: Colors.grey.shade300)),
              ),
              child: DebugPanel(
                jsonDefinition: demos[selectedDemoIndex].jsonDefinition,
                currentState: _currentState,
                onStateChange: _updateState,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDemoContent() {
    // Cache the runtime for each demo to avoid re-initialization
    return FutureBuilder<MCPUIRuntime>(
      key: ValueKey(selectedDemoIndex),
      future: _getOrCreateRuntime(selectedDemoIndex),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red)),
          );
        }
        
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final runtime = snapshot.data!;
        return runtime.buildUI(
          context: context,
          initialState: _currentState,
          onToolCall: (tool, args) {
            _handleToolCall(runtime, tool, args);
          },
        );
      },
    );
  }
  
  Future<MCPUIRuntime> _getOrCreateRuntime(int index) async {
    if (!_runtimeCache.containsKey(index)) {
      final runtime = MCPUIRuntime();
      final definition = demos[index].jsonDefinition;
      
      // Check if this is an application type that needs a page loader
      String? Function(String)? pageLoader;
      if (definition['type'] == 'application') {
        pageLoader = (route) {
          // Return mock page definitions for application type demos
          return '''
          {
            "type": "page",
            "content": {
              "type": "center",
              "child": {
                "type": "text",
                "value": "Page: $route",
                "style": {"fontSize": 18}
              }
            }
          }
          ''';
        };
      }
      
      await runtime.initialize(
        definition,
        pageLoader: pageLoader,
      );
      _runtimeCache[index] = runtime;
      
      // Update state service for this runtime
      await _updateStateService(runtime);
    }
    return _runtimeCache[index]!;
  }



  Future<Map<String, dynamic>> _handleToolCall(MCPUIRuntime runtime, String tool, Map<String, dynamic> args) async {
    _logger.info('Tool called: $tool with args: $args');
    
    // Simulate MCP server tool execution
    try {
      switch (tool) {
        case 'increment':
          final currentValue = runtime.stateManager.get<int>('counter') ?? 0;
          final newValue = currentValue + 1;
          
          // Simulate server-side state update (this would normally be done by the server)
          runtime.stateManager.set('counter', newValue);
          runtime.stateManager.set('doubleCounter', newValue * 2);
          runtime.stateManager.set('isPositive', newValue > 0);
          
          // Sync local state for debug panel
          setState(() {
            _currentState['counter'] = newValue;
            _currentState['doubleCounter'] = newValue * 2;
            _currentState['isPositive'] = newValue > 0;
          });
          
          // Return success response like a real MCP server would
          return {
            'success': true,
            'result': newValue,
            'message': 'Counter incremented successfully'
          };
      case 'decrement':
        final currentValue = runtime.stateManager.get<int>('counter') ?? 0;
        final newValue = currentValue - 1;
        
        runtime.stateManager.set('counter', newValue);
        runtime.stateManager.set('doubleCounter', newValue * 2);
        runtime.stateManager.set('isPositive', newValue > 0);
        
        setState(() {
          _currentState['counter'] = newValue;
          _currentState['doubleCounter'] = newValue * 2;
          _currentState['isPositive'] = newValue > 0;
        });
        
        return {
          'success': true,
          'result': newValue,
          'message': 'Counter decremented successfully'
        };
      case 'reset':
        runtime.stateManager.set('counter', 0);
        runtime.stateManager.set('message', 'Reset completed');
        runtime.stateManager.set('doubleCounter', 0);
        runtime.stateManager.set('isPositive', false);
        
        setState(() {
          _currentState['counter'] = 0;
          _currentState['message'] = 'Reset completed';
          _currentState['doubleCounter'] = 0;
          _currentState['isPositive'] = false;
        });
        
        return {
          'success': true,
          'result': 0,
          'message': 'Counter reset successfully'
        };
      case 'updateName':
        final newName = args['newName'] ?? 'Unknown';
        runtime.stateManager.set('name', newName);
        setState(() {
          _currentState['name'] = newName;
        });
        return {
          'success': true,
          'result': newName,
          'message': 'Name updated successfully'
        };
      case 'toggleStatus':
        final currentStatus = runtime.stateManager.get<String>('status') ?? 'Offline';
        final newStatus = currentStatus == 'Online' ? 'Offline' : 'Online';
        runtime.stateManager.set('status', newStatus);
        setState(() {
          _currentState['status'] = newStatus;
        });
        return {
          'success': true,
          'result': newStatus,
          'message': 'Status toggled successfully'
        };
      case 'showMessage':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(args['message'] ?? 'Hello from tool call!'),
            duration: const Duration(seconds: 2),
          ),
        );
        return {
          'success': true,
          'result': null,
          'message': 'Message shown successfully'
        };
      case 'addNotification':
        final newNotification = {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'title': args['title'] ?? 'New Notification',
          'message': args['message'] ?? 'This is a test notification',
          'timestamp': DateTime.now().toIso8601String(),
        };
        
        final notifications = List.from(runtime.stateManager.get<List>('notifications') ?? []);
        notifications.add(newNotification);
        runtime.stateManager.set('notifications', notifications);
        setState(() {
          _currentState['notifications'] = notifications;
        });
        return {
          'success': true,
          'result': newNotification,
          'message': 'Notification added successfully'
        };
      case 'startPeriodicService':
        return {
          'success': true,
          'result': null,
          'message': 'Periodic service started!'
        };
      case 'scheduleService':
        return {
          'success': true,
          'result': null,
          'message': 'Service scheduled!'
        };
      case 'enableEventService':
        return {
          'success': true,
          'result': null,
          'message': 'Event service enabled!'
        };
      case 'getSystemInfo':
        final systemInfo = {
          'platform': 'flutter',
          'version': '3.10.0',
          'runtime': 'MCP UI Runtime 1.0',
          'timestamp': DateTime.now().toIso8601String(),
        };
        runtime.stateManager.set('systemInfo', systemInfo);
        setState(() {
          _currentState['systemInfo'] = systemInfo;
        });
        return {
          'success': true,
          'result': systemInfo,
          'message': 'System info updated!'
        };
      case 'startBackgroundTask':
        return {
          'success': true,
          'result': null,
          'message': 'Background task started!'
        };
      case 'clearCache':
        final lastCleared = DateTime.now().toIso8601String();
        runtime.stateManager.set('cacheSize', 0);
        runtime.stateManager.set('lastCleared', lastCleared);
        setState(() {
          _currentState['cacheSize'] = 0;
          _currentState['lastCleared'] = lastCleared;
        });
        return {
          'success': true,
          'result': {'cacheSize': 0, 'lastCleared': lastCleared},
          'message': 'Cache cleared successfully'
        };
      case 'refreshData':
        runtime.stateManager.set('loading', true);
        
        final toolCalls = List.from(runtime.stateManager.get<List>('toolCalls') ?? []);
        toolCalls.add({
          'tool': tool,
          'timestamp': DateTime.now().toIso8601String(),
        });
        runtime.stateManager.set('toolCalls', toolCalls);
        
        setState(() {
          _currentState['loading'] = true;
          _currentState['toolCalls'] = toolCalls;
        });
        
        // Simulate async refresh
        Future.delayed(const Duration(seconds: 2), () {
          final timestamp = DateTime.now().toIso8601String();
          final currentVersion = runtime.stateManager.get<int>('dataVersion') ?? 0;
          
          runtime.stateManager.set('loading', false);
          runtime.stateManager.set('lastRefresh', timestamp);
          runtime.stateManager.set('dataVersion', currentVersion + 1);
          
          setState(() {
            _currentState['loading'] = false;
            _currentState['lastRefresh'] = timestamp;
            _currentState['dataVersion'] = currentVersion + 1;
          });
        });
        return {
          'success': true,
          'result': null,
          'message': 'Data refresh started'
        };
      default:
        return {
          'success': true,
          'result': null,
          'message': 'Tool executed: $tool'
        };
    }
    } catch (e) {
      // Return error response if something goes wrong
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Tool execution failed: $tool'
      };
    }
  }
}

class DemoItem {
  const DemoItem({
    required this.title,
    required this.description,
    required this.jsonDefinition,
  });

  final String title;
  final String description;
  final Map<String, dynamic> jsonDefinition;
}

