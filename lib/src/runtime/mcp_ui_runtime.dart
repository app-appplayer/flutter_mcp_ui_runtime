import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'runtime_engine.dart';
import 'widget_registry.dart';
import '../renderer/renderer.dart';
import '../actions/action_handler.dart';
import '../state/state_manager.dart';
import '../utils/mcp_logger.dart';

/// Main MCP UI Runtime class that provides the entry point for using the runtime
class MCPUIRuntime {
  MCPUIRuntime({
    this.enableDebugMode = kDebugMode,
  }) : _logger = MCPLogger('MCPUIRuntime', enableLogging: enableDebugMode) {
    _initialize();
  }

  final bool enableDebugMode;
  final MCPLogger _logger;

  // Core components
  late final RuntimeEngine _engine;
  late final WidgetRegistry _widgetRegistry;
  late final ActionHandler _actionHandler;
  late final StateManager _stateManager;

  bool _isInitialized = false;

  /// Initialize the runtime
  void _initialize() {
    // Create core components
    _widgetRegistry = WidgetRegistry();
    _actionHandler = ActionHandler();
    _stateManager = StateManager();
    // ThemeManager is accessed as singleton when needed

    // Create runtime engine
    _engine = RuntimeEngine(enableDebugMode: enableDebugMode);
  }

  /// Gets the runtime engine instance
  RuntimeEngine get engine => _engine;

  /// Gets the widget registry
  WidgetRegistry get widgetRegistry => _widgetRegistry;

  /// Gets the renderer
  Renderer get renderer => _engine.renderer;

  /// Gets the state manager
  StateManager get stateManager => _engine.stateManager;
  
  /// Gets the action handler
  ActionHandler get actionHandler => _engine.actionHandler;

  /// Gets whether the runtime is initialized
  bool get isInitialized => _isInitialized;

  /// Register a custom widget
  void registerWidget(String type, factory) {
    _widgetRegistry.register(type, factory);
  }

  /// Register a custom tool executor
  void registerToolExecutor(String toolName, Function executor) {
    if (_isInitialized) {
      // Use the engine's action handler after initialization
      _engine.actionHandler.registerToolExecutor(toolName, executor);
    } else {
      // Use the local action handler before initialization
      _actionHandler.registerToolExecutor(toolName, executor);
    }
  }

  /// Initializes the runtime with the provided definition
  Future<void> initialize(
    Map<String, dynamic> definition, {
    Function(String)? pageLoader,
  }) async {
    if (_isInitialized) {
      throw StateError('MCP UI Runtime is already initialized');
    }

    await _engine.initialize(
      definition: definition,
      pageLoader: pageLoader,
    );
    
    _isInitialized = true;

    _logger.info('Initialized successfully');
  }

  /// Builds the UI widget from the runtime configuration
  Widget buildUI({
    BuildContext? context,
    Map<String, dynamic>? initialState,
    Function(String, Map<String, dynamic>)? onToolCall,
  }) {
    if (!_isInitialized) {
      throw StateError('MCP UI Runtime must be initialized before building UI');
    }

    final uiDefinition = _engine.uiDefinition;
    if (uiDefinition == null) {
      throw StateError('No UI definition found in runtime configuration');
    }

    // Set initial state if provided
    if (initialState != null) {
      _stateManager.setState(initialState);
    }

    // Register tool call handler
    if (onToolCall != null) {
      _actionHandler.registerToolExecutor('default', onToolCall);
    }

    return MCPRuntimeWidget(
      runtime: this,
      engine: _engine,
      renderer: _engine.renderer,
      uiDefinition: uiDefinition,
    );
  }

  /// Updates a state value
  void updateState(String key, dynamic value) {
    _engine.stateManager.set(key, value);
  }
  
  /// Gets a state value
  T? getState<T>(String key) {
    return _engine.stateManager.get<T>(key);
  }
  
  /// Destroys the runtime and cleans up resources
  Future<void> destroy() async {
    await _engine.destroy();
    _isInitialized = false;

    _logger.info('Destroyed');
  }
}

/// Widget that renders the MCP UI using the runtime engine
class MCPRuntimeWidget extends StatefulWidget {
  const MCPRuntimeWidget({
    super.key,
    required this.runtime,
    required this.engine,
    required this.renderer,
    required this.uiDefinition,
  });

  final MCPUIRuntime runtime;
  final RuntimeEngine engine;
  final Renderer renderer;
  final Map<String, dynamic> uiDefinition;

  @override
  State<MCPRuntimeWidget> createState() => _MCPRuntimeWidgetState();
}

class _MCPRuntimeWidgetState extends State<MCPRuntimeWidget> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    
    // Add lifecycle observer
    WidgetsBinding.instance.addObserver(this);
    
    // Listen to state changes
    widget.engine.stateManager.addListener(_onStateChanged);

    // Mark runtime as ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.engine.markReady();
    });
  }
  
  void _onStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.engine.stateManager.removeListener(_onStateChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        widget.engine.pause();
        break;
      case AppLifecycleState.resumed:
        widget.engine.resume();
        break;
      case AppLifecycleState.detached:
        widget.engine.destroy();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.engine,
      builder: (context, child) {
        if (!widget.engine.isReady) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        try {
          // Check if this is an application type
          if (widget.engine.isApplication && widget.engine.routeManager != null) {
            // Build application with routing and navigation
            final appDefinition = widget.engine.applicationDefinition!;
            
            if (appDefinition.navigation != null) {
              // Build with navigation wrapper
              // TODO: Implement NavigationBuilder
              return MaterialApp(
                title: appDefinition.title,
                initialRoute: widget.engine.routeManager!.initialRoute,
                routes: widget.engine.routeManager!.generateRoutes(context),
              );
            } else {
              // Build simple routing without navigation wrapper
              return MaterialApp(
                title: appDefinition.title,
                initialRoute: widget.engine.routeManager!.initialRoute,
                routes: widget.engine.routeManager!.generateRoutes(context),
              );
            }
          } else {
            // Render single page UI using the unified renderer
            if (widget.runtime.enableDebugMode) {
              widget.runtime._logger.debug('Rendering page with uiDefinition type: ${widget.uiDefinition['type']}');
            }
            return _renderPage(widget.uiDefinition);
          }
        } catch (error) {
          if (widget.runtime.enableDebugMode) {
            widget.runtime._logger.error('Error rendering UI', error);
          }

          return ErrorWidget(error);
        }
      },
    );
  }

  /// Render a page using the unified renderer
  Widget _renderPage(Map<String, dynamic> definition) {
    // Use stderr for debugging to avoid interfering with MCP STDIO
    stderr.writeln('[MCPUIRuntime] _renderPage called with definition: ${jsonEncode(definition)}');
    
    if (widget.runtime.enableDebugMode) {
      widget.runtime._logger.debug('_renderPage called with definition type: ${definition['type']}');
      widget.runtime._logger.debug('_renderPage definition keys: ${definition.keys.toList()}');
    }
    
    // Check if this is a page type with content
    if (definition['type'] == 'page' && definition.containsKey('content')) {
      if (widget.runtime.enableDebugMode) {
        widget.runtime._logger.debug('_renderPage: Handling page type with content');
      }
      // For page type, render the content field directly
      final content = definition['content'] as Map<String, dynamic>;
      final context = widget.renderer.createRootContext(this.context);
      return widget.renderer.renderWidget(content, context);
    }
    
    // Check if UI definition has appBar and body at top level
    final hasAppBar = definition.containsKey('appBar');
    final hasBody = definition.containsKey('body');
    
    if (hasAppBar || hasBody) {
      if (widget.runtime.enableDebugMode) {
        widget.runtime._logger.debug('_renderPage: Handling legacy format with appBar/body');
      }
      // Create a page definition for the renderer
      final pageDefinition = {
        'type': 'single',
        if (hasAppBar) 'appBar': definition['appBar'],
        if (hasBody) 'body': definition['body'],
        if (definition.containsKey('bottomBar')) 'bottomBar': definition['bottomBar'],
        if (definition.containsKey('floatingAction')) 'floatingAction': definition['floatingAction'],
      };
      
      return widget.renderer.renderPage(pageDefinition);
    } else {
      if (widget.runtime.enableDebugMode) {
        widget.runtime._logger.debug('_renderPage: Rendering as single widget, type: ${definition['type']}');
      }
      // This should never happen for page type, but handle it gracefully
      if (definition['type'] == 'page') {
        return _errorWidget('Page type must have content field');
      }
      // Render as a single widget
      final context = widget.renderer.createRootContext(this.context);
      return widget.renderer.renderWidget(definition, context);
    }
  }
  
  Widget _errorWidget(String message) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper class for quick runtime usage
class MCPUIRuntimeHelper {
  /// Renders an MCP UI specification directly
  static Widget render(
    Map<String, dynamic> definition, {
    Map<String, dynamic>? initialState,
    Function(String, Map<String, dynamic>)? onToolCall,
  }) {
    return FutureBuilder<MCPUIRuntime>(
      future: () async {
        final runtime = MCPUIRuntime();
        await runtime.initialize(definition, pageLoader: null);
        return runtime;
      }(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorWidget(snapshot.error!);
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return snapshot.data!.buildUI(
          context: context,
          initialState: initialState,
          onToolCall: onToolCall,
        );
      },
    );
  }
}