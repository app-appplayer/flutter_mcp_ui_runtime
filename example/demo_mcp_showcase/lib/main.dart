import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'showcase_definition.dart';

void main() {
  runApp(const MCPShowcaseApp());
}

class MCPShowcaseApp extends StatelessWidget {
  const MCPShowcaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShowcaseScreen();
  }
}

class ShowcaseScreen extends StatefulWidget {
  const ShowcaseScreen({super.key});

  @override
  State<ShowcaseScreen> createState() => _ShowcaseScreenState();
}

class _ShowcaseScreenState extends State<ShowcaseScreen> {
  MCPUIRuntime? _runtime;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeRuntime();
  }

  Future<void> _initializeRuntime() async {
    try {
      _runtime = MCPUIRuntime(enableDebugMode: true);
      
      // No tool handlers needed - using state actions directly in the JSON
      
      await _runtime!.initialize(
        showcaseDefinition,
        pageLoader: (uri) async {
          // Handle page loading for the showcase
          return showcasePages[uri] ?? {};
        },
      );
      
      // Navigation handler is now registered inside _ApplicationShell
      // so we don't need to register it here
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _runtime?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_error != null) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error loading showcase: $_error',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _runtime!.buildUI(context: context);
  }
}