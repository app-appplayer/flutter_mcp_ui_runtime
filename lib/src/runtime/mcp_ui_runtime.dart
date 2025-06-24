import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'runtime_engine.dart';
import 'widget_registry.dart';
import '../renderer/renderer.dart';
import '../actions/action_handler.dart';
import '../state/state_manager.dart';
import '../theme/theme_manager.dart';
import '../i18n/i18n_manager.dart';
import '../utils/mcp_logger.dart';
import '../services/navigation_service.dart';

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
  bool Function(String action, String route, Map<String, dynamic> params)? _navigationHandler;
  final Map<String, Future<dynamic> Function(String method, String target, dynamic data)> _resourceHandlers = {};

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
    
    // Pass navigation handler to renderer and action handler if already registered
    if (_navigationHandler != null) {
      _engine.renderer.navigationHandler = _navigationHandler;
      _engine.actionHandler.registerNavigationHandler(_navigationHandler!);
    }
    
    // Pass resource handler to renderer if any registered
    if (_resourceHandlers.isNotEmpty) {
      _engine.renderer.resourceHandler = _createResourceHandlerWrapper();
    }

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

    // Register tool call handler as a default fallback
    if (onToolCall != null) {
      _actionHandler.registerToolExecutor('default', (tool, params) async {
        // Call the user's callback with tool name and params
        onToolCall(tool, params);
        // Return empty success response
        return {'success': true};
      });
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
  
  /// Execute an action directly (primarily for testing purposes)
  Future<void> executeAction(Map<String, dynamic> action) async {
    if (!_isInitialized) {
      throw StateError('Runtime must be initialized before executing actions');
    }
    
    // Create a minimal render context for action execution
    final context = _engine.renderer.createRootContext(null);
    await _engine.actionHandler.execute(action, context);
  }

  /// Register a resource handler
  void registerResourceHandler(String resource, Future<dynamic> Function(String method, String target, dynamic data) handler) {
    _resourceHandlers[resource] = handler;
    
    // Pass to renderer if initialized
    if (_isInitialized) {
      _engine.renderer.resourceHandler = _createResourceHandlerWrapper();
    }
    
    _logger.debug('Resource handler registered for: $resource');
  }
  
  /// Create a wrapper function that routes to the appropriate resource handler
  Future<dynamic> Function(String resource, String method, String target, dynamic data) _createResourceHandlerWrapper() {
    return (String resource, String method, String target, dynamic data) async {
      final handler = _resourceHandlers[resource];
      if (handler != null) {
        return await handler(method, target, data);
      }
      throw Exception('No handler registered for resource: $resource');
    };
  }

  /// Register a navigation handler  
  void registerNavigationHandler(bool Function(String action, String route, Map<String, dynamic> params) handler) {
    _logger.info('registerNavigationHandler called, isInitialized=$_isInitialized');
    _navigationHandler = handler;
    
    // Set global handler for navigation actions in ActionHandler
    if (_isInitialized) {
      _logger.info('Calling engine.actionHandler.registerNavigationHandler');
      _engine.actionHandler.registerNavigationHandler(handler);
      _logger.info('engine.actionHandler.registerNavigationHandler called');
    } else {
      _logger.info('Runtime not initialized, storing handler for later');
    }
    
    // Pass to renderer if initialized
    if (_isInitialized) {
      _logger.info('Setting navigation handler on renderer (was ${_engine.renderer.navigationHandler != null})');
      _engine.renderer.navigationHandler = handler;
      _logger.info('Navigation handler set on renderer (now ${_engine.renderer.navigationHandler != null})');
      // Force rebuild to pick up new handler by triggering a state change
      _stateManager.set('_internal_handler_update', DateTime.now().millisecondsSinceEpoch);
    }
    _logger.info('Navigation handler registered');
  }

  /// Destroys the runtime and cleans up resources
  Future<void> destroy() async {
    await _engine.destroy();
    _isInitialized = false;
    
    // Clear global navigation handler to prevent state leaking between tests
    NavigationActionExecutor.clearGlobalNavigationHandler();
    
    // Reset theme manager singleton
    ThemeManager.instance.reset();
    
    // Clear i18n manager
    I18nManager.instance.clear();

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
    
    // Don't listen to state changes directly - AnimatedBuilder already listens to engine
    // which forwards state changes from StateManager

    // Mark runtime as ready if not already marked
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.engine.isReady) {
        widget.engine.markReady();
      }
    });
  }

  @override
  void dispose() {
    // No need to remove state listener since we're not adding one
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
              final navKey = NavigationService.instance.navigatorKey;
              widget.runtime._logger.debug('Creating MaterialApp with navigatorKey: $navKey');
              widget.runtime._logger.debug('NavigatorKey hashCode: ${navKey.hashCode}');
              
              return MaterialApp(
                navigatorKey: navKey,
                title: appDefinition.title,
                theme: widget.engine.themeManager.currentTheme,
                initialRoute: widget.engine.routeManager!.initialRoute,
                routes: widget.engine.routeManager!.generateRoutes(context),
              );
            } else {
              // Build simple routing without navigation wrapper
              final navKey = NavigationService.instance.navigatorKey;
              widget.runtime._logger.debug('Creating MaterialApp with navigatorKey: $navKey');
              widget.runtime._logger.debug('NavigatorKey hashCode: ${navKey.hashCode}');
              
              return MaterialApp(
                navigatorKey: navKey,
                title: appDefinition.title,
                theme: widget.engine.themeManager.currentTheme,
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
    if (widget.runtime.enableDebugMode) {
      widget.runtime._logger.debug('_renderPage called with definition: ${jsonEncode(definition)}');
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