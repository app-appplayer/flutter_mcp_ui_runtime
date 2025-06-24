/// MCP UI Runtime - Core runtime implementation
/// 
/// ## Navigation System Overview
/// 
/// The runtime supports two navigation paradigms that work together:
/// 
/// ### 1. Route-based Navigation (Traditional Flutter)
/// - Used when navigationDefinition is null
/// - Creates MaterialApp with named routes
/// - Navigation actions use route names directly
/// - Works with standard Flutter Navigator
/// 
/// ### 2. Index-based Navigation (ApplicationShell)
/// - Used when navigationDefinition exists (drawer/tabs/bottom)
/// - Creates MaterialApp with home widget (ApplicationShell)
/// - Navigation is managed by index internally
/// - Navigation actions are converted from routes to indices
/// 
/// ### How Navigation Actions Work
/// 
/// When a button triggers a navigation action:
/// 1. NavigationActionExecutor receives the action
/// 2. It checks for navigation handlers in order:
///    - Context handler (highest priority)
///    - Renderer handler
///    - Global handler (set by ApplicationShell)
/// 3. ApplicationShell's handler converts route to index
/// 4. The UI updates to show the new page
/// 
/// This design allows navigation actions to work consistently
/// regardless of the navigation type (drawer/tabs/bottom/routes).
library mcp_ui_runtime;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'runtime/runtime_engine.dart';
import 'state/state_manager.dart';
import 'renderer/render_context.dart';
import 'routing/page_state_scope.dart';
import 'theme/theme_manager.dart';
import 'utils/mcp_logger.dart';
import 'models/ui_definition.dart';
import 'services/navigation_service.dart';

/// Main MCP UI Runtime class that provides the entry point for using the runtime
class MCPUIRuntime {
  MCPUIRuntime({
    this.enableDebugMode = kDebugMode,
  }) : _logger = MCPLogger('MCPUIRuntime', enableLogging: enableDebugMode);

  final bool enableDebugMode;
  final MCPLogger _logger;

  RuntimeEngine? _engine;
  bool _isInitialized = false;

  /// Gets the runtime engine instance
  RuntimeEngine? get engine => _engine;

  /// Gets whether the runtime is initialized
  bool get isInitialized => _isInitialized;
  
  /// Gets the state manager
  StateManager get stateManager {
    if (!_isInitialized || _engine == null) {
      throw StateError('Runtime must be initialized before accessing stateManager');
    }
    return _engine!.stateManager;
  }
  
  /// Gets the theme manager
  ThemeManager get themeManager {
    if (!_isInitialized || _engine == null) {
      throw StateError('Runtime must be initialized before accessing themeManager');
    }
    return _engine!.themeManager;
  }
  
  /// Gets the UI definition
  Map<String, dynamic>? getUIDefinition() {
    return _engine?.uiDefinition;
  }
  
  /// Renders the UI widget
  Widget render() {
    return buildUI();
  }

  /// Initializes the runtime with the provided definition
  Future<void> initialize(Map<String, dynamic> definition, {
    Function(String)? pageLoader,
    bool useCache = true,
  }) async {
    if (_isInitialized) {
      throw StateError('MCP UI Runtime is already initialized');
    }

    _engine = RuntimeEngine(
      enableDebugMode: enableDebugMode,
    );

    await _engine!.initialize(
      definition: definition,
      pageLoader: pageLoader,
      useCache: useCache,
    );
    _isInitialized = true;

    _logger.info('Initialized successfully');
  }

  /// Builds the UI widget from the runtime configuration
  Widget buildUI({
    BuildContext? context,
    Map<String, dynamic>? initialState,
    Function(String, Map<String, dynamic>)? onToolCall,
    Function(String, String)? onResourceSubscribe,
    Function(String)? onResourceUnsubscribe,
  }) {
    if (!_isInitialized || _engine == null) {
      throw StateError('MCP UI Runtime must be initialized before building UI');
    }

    final uiDefinition = _engine!.uiDefinition;
    if (uiDefinition == null) {
      throw StateError('No UI definition found in runtime configuration');
    }

    return MCPRuntimeWidget(
      engine: _engine!,
      uiDefinition: uiDefinition,
      initialState: initialState,
      onToolCall: onToolCall,
      onResourceSubscribe: onResourceSubscribe,
      onResourceUnsubscribe: onResourceUnsubscribe,
    );
  }

  /// Handles MCP notification
  Future<void> handleNotification(
    Map<String, dynamic> notification, {
    Function(String)? resourceReader,
  }) async {
    if (!_isInitialized || _engine == null) {
      _logger.warning('Cannot handle notification - runtime not initialized');
      return;
    }
    
    _logger.debug('Handling notification: $notification');
    
    // Check notification method
    final method = notification['method'] as String?;
    final params = notification['params'] as Map<String, dynamic>?;
    
    if (method == 'notifications/resources/updated' && params != null) {
      // Handle resource update notification
      await _engine!.handleMCPNotification(params, resourceReader: resourceReader);
    } else {
      _logger.debug('Ignoring notification with method: $method');
    }
  }
  
  /// Register resource subscription for tracking
  void registerResourceSubscription(String uri, String binding) {
    if (!_isInitialized || _engine == null) {
      throw StateError('Runtime must be initialized');
    }
    _engine!.registerResourceSubscription(uri, binding);
  }
  
  /// Unregister resource subscription
  void unregisterResourceSubscription(String uri) {
    if (!_isInitialized || _engine == null) {
      throw StateError('Runtime must be initialized');
    }
    _engine!.unregisterResourceSubscription(uri);
  }
  
  /// Get binding for a URI
  String? getBindingForUri(String uri) {
    if (!_isInitialized || _engine == null) {
      return null;
    }
    return _engine!.getBindingForUri(uri);
  }
  
  /// Update state directly (for manual state updates)
  void updateState(String binding, dynamic value) {
    if (!_isInitialized || _engine == null) {
      throw StateError('Runtime must be initialized');
    }
    _engine!.stateManager.set(binding, value);
  }
  
  /// Handle error
  void handleError(String error) {
    _logger.error(error);
  }

  /// Register a tool executor function
  void registerToolExecutor(String toolName, Function executor) {
    if (!_isInitialized || _engine == null) {
      throw StateError('Runtime must be initialized before registering tool executors');
    }
    _engine!.actionHandler.registerToolExecutor(toolName, executor);
  }

  /// Destroys the runtime and cleans up resources
  Future<void> destroy() async {
    if (_engine != null) {
      await _engine!.destroy();
      _engine = null;
    }
    _isInitialized = false;

    _logger.info('Destroyed');
  }

}

/// Widget that renders the MCP UI using the runtime engine
class MCPRuntimeWidget extends StatefulWidget {
  const MCPRuntimeWidget({
    super.key,
    required this.engine,
    required this.uiDefinition,
    this.initialState,
    this.onToolCall,
    this.onResourceSubscribe,
    this.onResourceUnsubscribe,
  });

  final RuntimeEngine engine;
  final Map<String, dynamic> uiDefinition;
  final Map<String, dynamic>? initialState;
  final Function(String, Map<String, dynamic>)? onToolCall;
  final Function(String, String)? onResourceSubscribe;
  final Function(String)? onResourceUnsubscribe;

  @override
  State<MCPRuntimeWidget> createState() => _MCPRuntimeWidgetState();
}

class _MCPRuntimeWidgetState extends State<MCPRuntimeWidget> with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    
    // Add lifecycle observer
    WidgetsBinding.instance.addObserver(this);

    // Register onToolCall callback if provided
    if (widget.onToolCall != null) {
      widget.engine.actionHandler.registerToolExecutor('default', widget.onToolCall!);
    }
    
    // Register resource handlers if provided
    widget.engine.setResourceHandlers(
      onResourceSubscribe: widget.onResourceSubscribe,
      onResourceUnsubscribe: widget.onResourceUnsubscribe,
    );
    
    // Initialize state if provided
    if (widget.initialState != null) {
      widget.engine.stateManager.setState(widget.initialState!);
    }

    // Mark runtime as ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.engine.markReady();
    });
  }

  @override
  void dispose() {
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
            
            if (widget.engine.enableDebugMode) {
              MCPLogger('MCPRuntimeWidget').debug('Building application with navigation: ${appDefinition.navigationDefinition?.type}');
            }
            
            if (appDefinition.navigationDefinition != null) {
              // Build with navigation wrapper
              final navKey = NavigationService.instance.navigatorKey;
              MCPLogger('MCPRuntimeWidget').debug('Creating MaterialApp with navigatorKey for ApplicationShell: $navKey');
              
              return MaterialApp(
                navigatorKey: navKey,  // Essential for dialogs and navigation to work
                title: appDefinition.title,
                theme: widget.engine.themeManager.toFlutterTheme(),
                darkTheme: widget.engine.themeManager.toFlutterTheme(isDark: true),
                themeMode: widget.engine.themeManager.flutterThemeMode,
                debugShowCheckedModeBanner: false,
                home: _ApplicationShell(
                  engine: widget.engine,
                  appDefinition: appDefinition,
                  onToolCall: widget.onToolCall,
                  onResourceSubscribe: widget.onResourceSubscribe,
                  onResourceUnsubscribe: widget.onResourceUnsubscribe,
                ),
              );
            } else {
              // Build simple routing without navigation wrapper
              final navKey = NavigationService.instance.navigatorKey;
              MCPLogger('MCPRuntimeWidget').debug('Creating MaterialApp with navigatorKey for routing: $navKey');
              
              return MaterialApp(
                navigatorKey: navKey,  // Essential for dialogs and navigation to work
                title: appDefinition.title,
                theme: widget.engine.themeManager.toFlutterTheme(),
                darkTheme: widget.engine.themeManager.toFlutterTheme(isDark: true),
                themeMode: widget.engine.themeManager.flutterThemeMode,
                debugShowCheckedModeBanner: false,
                initialRoute: widget.engine.routeManager!.initialRoute,
                routes: widget.engine.routeManager!.generateRoutes(context),
              );
            }
          } else {
            // Render single page UI
            // Check if UI definition has appBar and body at top level
            final hasAppBar = widget.uiDefinition.containsKey('appBar');
            final hasBody = widget.uiDefinition.containsKey('body');
            
            if (hasAppBar || hasBody) {
              // Auto-create scaffold for platform-independent UI definitions
              final renderContext = _createRenderContext();
              return Scaffold(
                appBar: hasAppBar ? widget.engine.renderer.renderWidget(widget.uiDefinition['appBar'], renderContext) as AppBar? : null,
                body: hasBody ? widget.engine.renderer.renderWidget(widget.uiDefinition['body'], renderContext) : Container(),
              );
            } else {
              // Use modern renderer for page content
              if (widget.engine.parsedUIDefinition?.type == UIDefinitionType.page) {
                return widget.engine.renderer.renderPage(widget.engine.parsedUIDefinition!.toJson());
              } else {
                // Render as widget using modern renderer
                return widget.engine.renderer.renderWidget(widget.uiDefinition, _createRenderContext());
              }
            }
          }
        } catch (error) {
          if (widget.engine.enableDebugMode) {
            MCPLogger('MCPRuntimeWidget').error('Error rendering UI', error);
          }

          return ErrorWidget(error);
        }
      },
    );
  }

  /// Creates a render context for the modern renderer
  RenderContext _createRenderContext() {
    return RenderContext(
      renderer: widget.engine.renderer,
      stateManager: widget.engine.stateManager,
      bindingEngine: widget.engine.bindingEngine,
      actionHandler: widget.engine.actionHandler,
      themeManager: ThemeManager(), // Create a basic theme manager
      buildContext: context,
      engine: widget.engine,
    );
  }

  /// Creates a render context for the modern renderer
}

/// Application shell widget that handles navigation
/// 
/// This widget manages navigation for applications with drawer, tabs, or bottom navigation.
/// It bridges two navigation systems:
/// 
/// 1. **Index-based navigation**: Used internally by drawer/tabs/bottom navigation
///    - Tracks current page by index (_currentIndex)
///    - Updates UI by changing the displayed page widget
/// 
/// 2. **Route-based navigation**: Used by navigation actions from buttons
///    - Uses route names (e.g., '/home', '/settings')
///    - Handled through NavigationActionExecutor
/// 
/// The bridge works as follows:
/// - When the app starts, a navigation handler is registered
/// - This handler intercepts route-based navigation actions
/// - It converts route names to indices and updates _currentIndex
/// - The UI rebuilds to show the new page
/// 
/// This allows buttons with navigation actions to work seamlessly with
/// drawer/tab/bottom navigation, even though they use different systems.
class _ApplicationShell extends StatefulWidget {
  final RuntimeEngine engine;
  final ApplicationDefinition appDefinition;
  final Function(String, Map<String, dynamic>)? onToolCall;
  final Function(String, String)? onResourceSubscribe;
  final Function(String)? onResourceUnsubscribe;

  const _ApplicationShell({
    required this.engine,
    required this.appDefinition,
    this.onToolCall,
    this.onResourceSubscribe,
    this.onResourceUnsubscribe,
  });

  @override
  State<_ApplicationShell> createState() => _ApplicationShellState();
}

class _ApplicationShellState extends State<_ApplicationShell> {
  int _currentIndex = 0;
  final Map<String, PageDefinition> _pageDefinitionCache = {};

  @override
  void initState() {
    super.initState();
    
    // Find initial route index based on the application's initial route
    if (widget.appDefinition.navigationDefinition != null) {
      final initialRoute = widget.appDefinition.initialRoute;
      final index = widget.appDefinition.navigationDefinition!.items
          .indexWhere((item) => item.route == initialRoute);
      if (index >= 0) {
        _currentIndex = index;
      }
    }
    
    // Register a navigation handler that converts route-based navigation to index-based
    // This allows navigation actions from buttons to work with the ApplicationShell's
    // index-based navigation system
    _registerNavigationHandler();
  }

  Future<PageDefinition> _loadPageDefinition(String route) async {
    // Check cache first
    if (_pageDefinitionCache.containsKey(route)) {
      return _pageDefinitionCache[route]!;
    }


    try {
      // Get page URI from route
      final pageUri = widget.appDefinition.routes[route];
      if (pageUri == null) {
        throw Exception('No page URI found for route: $route');
      }

      // Load page definition
      final pageJson = await widget.engine.routeManager!.pageLoader(pageUri);
      final uiDef = UIDefinition.fromJson(pageJson as Map<String, dynamic>);
      final pageDefinition = PageDefinition.fromUIDefinition(uiDef);
      
      // Cache the page definition only
      _pageDefinitionCache[route] = pageDefinition;
      
      
      return pageDefinition;
    } catch (e) {
      
      throw Exception('Error loading page: $e');
    }
  }
  
  /// Registers a navigation handler that bridges route-based navigation actions
  /// with the ApplicationShell's index-based navigation system
  void _registerNavigationHandler() {
    // Create a navigation handler that converts routes to indices
    bool navigationHandler(String action, String route, Map<String, dynamic> params) {
      // Only handle navigation actions for this ApplicationShell
      if (action != 'push' && action != 'replace') {
        return false; // Let other handlers process this
      }
      
      // Find the index for the given route
      final navItems = widget.appDefinition.navigationDefinition?.items ?? [];
      final targetIndex = navItems.indexWhere((item) => item.route == route);
      
      if (targetIndex >= 0) {
        // Route found, update the current index to navigate
        if (mounted) {
          setState(() {
            _currentIndex = targetIndex;
          });
        }
        return true; // Navigation handled successfully
      }
      
      // Route not found in navigation items
      return false;
    }
    
    // Register the handler with the action handler
    widget.engine.actionHandler.registerNavigationHandler(navigationHandler);
  }
  
  @override
  void dispose() {
    // Clean up page definition cache when disposing
    _pageDefinitionCache.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navigation = widget.appDefinition.navigationDefinition;
    
    if (navigation == null) {
      // No navigation, just show the initial route
      return FutureBuilder<PageDefinition>(
        future: _loadPageDefinition(widget.appDefinition.initialRoute),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            // Wrap in AnimatedBuilder to listen to StateManager changes
            return AnimatedBuilder(
              animation: widget.engine.stateManager,
              builder: (context, child) {
                return MCPPageWidget(
                  pageDefinition: snapshot.data!,
                  runtimeEngine: widget.engine,
                );
              },
            );
          } else if (snapshot.hasError) {
            return _buildErrorPage(snapshot.error);
          } else {
            return _buildLoadingPage();
          }
        },
      );
    }

    // Get current route
    final currentRoute = navigation.items[_currentIndex].route;

    switch (navigation.type) {
      case 'tabs':
        return DefaultTabController(
          length: navigation.items.length,
          initialIndex: _currentIndex,
          child: Scaffold(
            appBar: AppBar(
              title: Text(widget.appDefinition.title),
              bottom: TabBar(
                tabs: navigation.items.map((item) => Tab(
                  text: item.title,
                  icon: item.icon != null ? Icon(_getIconData(item.icon!)) : null,
                )).toList(),
              ),
            ),
            body: TabBarView(
              children: navigation.items.map((navItem) {
                final route = navItem.route;
                return FutureBuilder<PageDefinition>(
                  key: ValueKey(route),
                  future: _loadPageDefinition(route),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      // Wrap in AnimatedBuilder to listen to StateManager changes
                      return AnimatedBuilder(
                        animation: widget.engine.stateManager,
                        builder: (context, child) {
                          return MCPPageWidget(
                            pageDefinition: snapshot.data!,
                            runtimeEngine: widget.engine,
                          );
                        },
                      );
                    } else if (snapshot.hasError) {
                      return _buildErrorPage(snapshot.error);
                    } else {
                      return _buildLoadingPage();
                    }
                  },
                );
              }).toList(),
            ),
          ),
        );
        
      case 'bottom':
        return Scaffold(
          body: FutureBuilder<PageDefinition>(
            key: ValueKey(currentRoute),
            future: _loadPageDefinition(currentRoute),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                // Wrap in AnimatedBuilder to listen to StateManager changes
                return AnimatedBuilder(
                  animation: widget.engine.stateManager,
                  builder: (context, child) {
                    return MCPPageWidget(
                      pageDefinition: snapshot.data!,
                      runtimeEngine: widget.engine,
                    );
                  },
                );
              } else if (snapshot.hasError) {
                return _buildErrorPage(snapshot.error);
              } else {
                return _buildLoadingPage();
              }
            },
          ),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            items: navigation.items.map((item) => BottomNavigationBarItem(
              icon: Icon(_getIconData(item.icon ?? 'home')),
              label: item.title,
            )).toList(),
          ),
        );
        
      default:
        // Drawer navigation
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.appDefinition.title),
          ),
          drawer: Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                  ),
                  child: Text(
                    widget.appDefinition.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                ),
                ...navigation.items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return ListTile(
                    leading: item.icon != null ? Icon(_getIconData(item.icon!)) : null,
                    title: Text(item.title),
                    selected: index == _currentIndex,
                    onTap: () {
                      setState(() {
                        _currentIndex = index;
                      });
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          ),
          body: FutureBuilder<PageDefinition>(
            key: ValueKey(currentRoute),
            future: _loadPageDefinition(currentRoute),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                // Wrap in AnimatedBuilder to listen to StateManager changes
                return AnimatedBuilder(
                  animation: widget.engine.stateManager,
                  builder: (context, child) {
                    return MCPPageWidget(
                      pageDefinition: snapshot.data!,
                      runtimeEngine: widget.engine,
                    );
                  },
                );
              } else if (snapshot.hasError) {
                return _buildErrorPage(snapshot.error);
              } else {
                return _buildLoadingPage();
              }
            },
          ),
        );
    }
  }

  Widget _buildLoadingPage() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildErrorPage(dynamic error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          const Text(
            'Failed to load page',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'home':
      case 'dashboard':
        return Icons.home;
      case 'settings':
        return Icons.settings;
      case 'person':
      case 'profile':
        return Icons.person;
      case 'calculate':
      case 'calculator':
        return Icons.calculate;
      case 'thermostat':
      case 'temperature':
        return Icons.thermostat;
      case 'speed':
        return Icons.speed;
      default:
        return Icons.circle;
    }
  }
}

/// Convenience functions for quick runtime usage
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