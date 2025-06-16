import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'demo_definitions.dart';

/// Simple demo app to test state updates
class SimpleDemoApp extends StatefulWidget {
  const SimpleDemoApp({super.key});

  @override
  State<SimpleDemoApp> createState() => _SimpleDemoAppState();
}

class _SimpleDemoAppState extends State<SimpleDemoApp> {
  MCPUIRuntime? _runtime;
  Map<String, dynamic> _state = {};
  
  @override
  void initState() {
    super.initState();
    _initializeRuntime();
  }
  
  Future<void> _initializeRuntime() async {
    _runtime = MCPUIRuntime();
    
    // Initialize with State & Bindings demo
    await _runtime!.initialize(stateAndBindingsDemo);
    
    // Get initial state from the definition
    final initialState = stateAndBindingsDemo['runtime']?['services']?['state']?['initialState'] ?? {};
    setState(() {
      _state = Map<String, dynamic>.from(initialState);
    });
  }
  
  void _handleToolCall(String tool, Map<String, dynamic> args) {
    debugPrint('Tool called: $tool with args: $args');
    
    setState(() {
      switch (tool) {
        case 'increment':
          _state['counter'] = (_state['counter'] ?? 0) + 1;
          break;
        case 'decrement':
          _state['counter'] = (_state['counter'] ?? 0) - 1;
          break;
        case 'reset':
          _state['counter'] = 0;
          _state['message'] = 'Reset completed';
          break;
        case 'showMessage':
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(args['message'] ?? 'Hello!'),
              duration: const Duration(seconds: 2),
            ),
          );
          break;
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple State Demo',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('State & Bindings Demo'),
        ),
        body: _runtime == null
            ? const Center(child: CircularProgressIndicator())
            : _runtime!.buildUI(
                context: context,
                initialState: _state,
                onToolCall: _handleToolCall,
              ),
      ),
    );
  }
  
  @override
  void dispose() {
    _runtime?.destroy();
    super.dispose();
  }
}

void main() {
  runApp(const SimpleDemoApp());
}