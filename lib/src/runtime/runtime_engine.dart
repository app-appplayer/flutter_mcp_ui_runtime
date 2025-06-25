import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../renderer/render_context.dart';
import '../renderer/renderer.dart';
import 'lifecycle_manager.dart';
import 'service_registry.dart';
import 'cache_manager.dart';
import 'widget_registry.dart';
import 'default_widgets.dart';
import '../binding/binding_engine.dart';
import '../actions/action_handler.dart';
import '../state/state_manager.dart';
import '../services/navigation_service.dart';
import '../services/dialog_service.dart';
import '../services/notification_service.dart';
import '../notifications/notification_manager.dart';
import '../models/ui_definition.dart';
import '../routing/route_manager.dart';
import 'background_service_manager.dart';
import '../theme/theme_manager.dart';
import '../utils/mcp_logger.dart';
import '../state/computed_manager.dart';

/// The main runtime engine that manages the MCP UI Runtime lifecycle
/// and coordinates all runtime services.
class RuntimeEngine with ChangeNotifier {
  RuntimeEngine({
    this.enableDebugMode = kDebugMode,
  }) : _logger = MCPLogger('RuntimeEngine', enableLogging: enableDebugMode) {
    // Initialize core components in constructor so they're available immediately
    _initializeCoreComponents();
  }

  final bool enableDebugMode;
  final MCPLogger _logger;

  // Core components
  late final LifecycleManager _lifecycleManager;
  late final ServiceRegistry _serviceRegistry;
  late final NotificationManager _notificationManager;
  late final CacheManager _cacheManager;
  late final BackgroundServiceManager _backgroundServiceManager;

  // Modern rendering system
  late final WidgetRegistry _widgetRegistry;
  late final BindingEngine _bindingEngine;
  late final ActionHandler _actionHandler;
  late final StateManager _stateManager;
  late final Renderer _renderer;
  late final ThemeManager _themeManager;
  late final ComputedManager _computedManager;

  // Public getters for page rendering
  Renderer get renderer => _renderer;
  StateManager get stateManager => _stateManager;
  BindingEngine get bindingEngine => _bindingEngine;
  ActionHandler get actionHandler => _actionHandler;
  ThemeManager get themeManager => _themeManager;
  LifecycleManager get lifecycle => _lifecycleManager;

  // Runtime state
  bool _isInitialized = false;
  bool _isReady = false;
  Map<String, dynamic>? _runtimeConfig;
  Map<String, dynamic>? _uiDefinition;

  // Application support
  UIDefinition? _parsedUIDefinition;
  ApplicationDefinition? _applicationDefinition;
  RouteManager? _routeManager;
  Function(String)? _pageLoader;

  // Resource handlers
  Function(String, String)? _onResourceSubscribe;
  Function(String)? _onResourceUnsubscribe;

  // Resource subscription tracking
  final Map<String, String> _resourceSubscriptions = {}; // URI -> binding

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isReady => _isReady;
  ServiceRegistry get services => _serviceRegistry;
  NotificationManager get notifications => _notificationManager;
  CacheManager get cache => _cacheManager;
  Map<String, dynamic>? get runtimeConfig => _runtimeConfig;
  Map<String, dynamic>? get uiDefinition => _uiDefinition;
  UIDefinition? get parsedUIDefinition => _parsedUIDefinition;
  ApplicationDefinition? get applicationDefinition => _applicationDefinition;
  RouteManager? get routeManager => _routeManager;
  bool get isApplication => _applicationDefinition != null;
  WidgetRegistry get widgetRegistry => _widgetRegistry;

  // Resource handler getters
  Function(String, String)? get onResourceSubscribe => _onResourceSubscribe;
  Function(String)? get onResourceUnsubscribe => _onResourceUnsubscribe;

  // Set resource handlers
  void setResourceHandlers({
    Function(String, String)? onResourceSubscribe,
    Function(String)? onResourceUnsubscribe,
  }) {
    _onResourceSubscribe = onResourceSubscribe;
    _onResourceUnsubscribe = onResourceUnsubscribe;
  }

  // Register a resource subscription
  void registerResourceSubscription(String uri, String binding) {
    _resourceSubscriptions[uri] = binding;
    _logger.debug('Registered subscription: $uri -> $binding');
  }

  // Unregister a resource subscription
  void unregisterResourceSubscription(String uri) {
    final binding = _resourceSubscriptions.remove(uri);
    if (binding != null) {
      _logger.debug('Unregistered subscription: $uri -> $binding');
    }
  }

  // Get binding for a URI
  String? getBindingForUri(String uri) {
    return _resourceSubscriptions[uri];
  }

  // Handle resource notification from MCP
  void handleResourceNotification(String uri, Map<String, dynamic> data) {
    _logger.debug('=== RUNTIME NOTIFICATION ===');
    _logger.debug('URI: $uri');
    _logger.debug('Subscriptions: $_resourceSubscriptions');

    // Find the binding for this URI
    final binding = getBindingForUri(uri);
    _logger.debug('Binding found: $binding');

    if (binding != null) {
      // Extract the content data
      final content = data['content'];

      if (content != null) {
        // If the content has a field with the same name as the binding, use that value
        // Otherwise, use the entire content
        final value =
            (content is Map<String, dynamic> && content.containsKey(binding))
                ? content[binding]
                : content;

        _logger.debug('Updating state: $binding = $value');
        _stateManager.set(binding, value);
        _logger.debug('State updated via StateManager listener');
      } else {
        _logger.warning('No content in notification data');
      }
    } else {
      _logger.warning('No binding found for URI: $uri');
    }
    _logger.debug('=== RUNTIME NOTIFICATION END ===');
  }

  /// Initializes the runtime engine with the provided configuration
  Future<void> initialize({
    required Map<String, dynamic> definition,
    RenderContext? context,
    bool useCache = true,
    Function(String)? pageLoader,
  }) async {
    if (_isInitialized) {
      throw StateError('Runtime engine is already initialized');
    }

    try {
      if (enableDebugMode) {
        _logger.info('Initializing...');
      }

      // Try to load from cache if enabled
      Map<String, dynamic> finalDefinition = definition;
      if (useCache) {
        final cachedApp = await _tryLoadFromCache(definition);
        if (cachedApp != null) {
          finalDefinition = cachedApp;
        }
      }

      // Store page loader if provided
      _pageLoader = pageLoader;

      // Initialize with the definition
      await _initializeWithDefinition(finalDefinition, context);

      // Cache the app after successful initialization
      if (useCache) {
        await _cacheApp(finalDefinition);
      }

      _isInitialized = true;

      if (enableDebugMode) {
        _logger.info('Initialization complete');
      }

      // Automatically mark as ready after initialization - this will notify listeners
      await markReady();
    } catch (error, stackTrace) {
      if (enableDebugMode) {
        _logger.error('Initialization failed', error, stackTrace);
      }
      rethrow;
    }
  }

  /// Initializes with the MCP runtime definition
  Future<void> _initializeWithDefinition(
    Map<String, dynamic> definition,
    RenderContext? context,
  ) async {
    // Check if this is a new v1.0 format (application or page)
    if (definition['type'] == 'application' || definition['type'] == 'page') {
      await _initializeV1Format(definition, context);
      return;
    }

    // v1.0 spec only supports application or page types
    throw ArgumentError('Definition must be a valid application or page type');
  }

  /// Initializes with v1.0 format (application or page)
  Future<void> _initializeV1Format(
    Map<String, dynamic> definition,
    RenderContext? context,
  ) async {
    // Parse UI definition
    _parsedUIDefinition = UIDefinition.fromJson(definition);

    // Store the appropriate UI definition based on type
    if (_parsedUIDefinition!.type == UIDefinitionType.page) {
      // For page type, store the full definition but extract content for rendering
      _uiDefinition = definition;
    } else {
      // For application type and others, store the raw definition
      _uiDefinition = definition;
    }

    // Set the state manager in theme manager for custom theme values
    _themeManager.setStateManager(_stateManager);

    // Set up state change forwarding to trigger UI rebuilds
    _stateManager.addListener(() {
      _logger.debug('StateManager change detected, forwarding to UI...');
      notifyListeners(); // Forward state changes to UI
    });

    // Register all default widgets
    DefaultWidgets.registerAll(_widgetRegistry);

    // Create modern renderer
    _renderer = Renderer(
      widgetRegistry: _widgetRegistry,
      bindingEngine: _bindingEngine,
      actionHandler: _actionHandler,
      stateManager: _stateManager,
      engine: this,
    );

    // Register core services
    await _registerCoreServices();

    // Set up lifecycle manager with action handler and render context
    final rootContext = _renderer.createRootContext(null);
    _lifecycleManager.setActionHandler(_actionHandler, rootContext);

    // Handle application type
    if (_parsedUIDefinition!.type == UIDefinitionType.application) {
      if (_pageLoader == null) {
        throw ArgumentError('Page loader is required for application type');
      }

      _applicationDefinition =
          ApplicationDefinition.fromUIDefinition(_parsedUIDefinition!);

      // Create route manager
      _routeManager = RouteManager(
        appDefinition: _applicationDefinition!,
        pageLoader: _pageLoader!,
        runtimeEngine: this,
      );

      // Initialize theme from application definition
      if (_applicationDefinition!.theme != null) {
        _themeManager.setTheme(_applicationDefinition!.theme!);
      }

      // Check for theme in runtime.services.theme (MCP UI DSL standard location)
      final runtimeServices = definition['runtime']?['services'];
      if (runtimeServices != null && runtimeServices['theme'] != null) {
        _logger.debug('Setting theme from runtime.services.theme');
        _themeManager
            .setTheme(runtimeServices['theme'] as Map<String, dynamic>);
      }

      // Initialize global app state
      if (_applicationDefinition!.initialState != null) {
        _stateManager.setState(_applicationDefinition!.initialState!);
        _logger.debug(
            'Initialized app state in StateManager with ${_applicationDefinition!.initialState!.length} keys');
      }

      // Initialize services from application definition
      if (_applicationDefinition!.servicesDefinition != null) {
        await _initializeServicesV1(
            _applicationDefinition!.servicesDefinition!);

        // Start background services
        if (_applicationDefinition!.servicesDefinition!.backgroundServices !=
            null) {
          await _startBackgroundServices(
              _applicationDefinition!.servicesDefinition!.backgroundServices!);
        }
      }

      // Set runtime config for lifecycle compatibility
      _runtimeConfig = {
        'lifecycle': _applicationDefinition!.lifecycleDefinition != null
            ? _lifecycleToJson(_applicationDefinition!.lifecycleDefinition!)
            : null,
        'services': _applicationDefinition!.servicesDefinition != null
            ? _servicesToJson(_applicationDefinition!.servicesDefinition!)
            : null,
      };
    } else {
      // Handle page type
      final pageDefinition =
          PageDefinition.fromUIDefinition(_parsedUIDefinition!);

      // Initialize services from page runtime definition if present
      final runtimeServices =
          definition['runtime']?['services'] as Map<String, dynamic>?;
      if (runtimeServices != null) {
        // Initialize state if present
        final stateConfig = runtimeServices['state'] as Map<String, dynamic>?;
        if (stateConfig != null && stateConfig['initialState'] != null) {
          final initialState =
              stateConfig['initialState'] as Map<String, dynamic>;

          // Initialize StateManager directly (this is what the renderer uses)
          _stateManager.initialize(initialState);

          // StateManager is already initialized above
          _logger.debug('Page state initialized in StateManager');
        }
      }

      // Set runtime config for lifecycle compatibility
      _runtimeConfig = {
        'lifecycle': pageDefinition.lifecycleDefinition != null
            ? _lifecycleToJson(pageDefinition.lifecycleDefinition!)
            : null,
        'services': runtimeServices,
      };
    }

    // Execute lifecycle hooks
    final lifecycle = _parsedUIDefinition!.type == UIDefinitionType.application
        ? _applicationDefinition?.lifecycleDefinition
        : (_parsedUIDefinition!.type == UIDefinitionType.page
            ? PageDefinition.fromUIDefinition(_parsedUIDefinition!)
                .lifecycleDefinition
            : null);

    if (lifecycle != null && lifecycle.onInitialize != null) {
      await _lifecycleManager.executeLifecycleHooks(
        LifecycleEvent.initialize,
        lifecycle.onInitialize!,
      );
    }
  }

  /// Initialize services for v1.0 format
  Future<void> _initializeServicesV1(ServicesDefinition services) async {
    // Initialize state
    if (services.state != null) {
      final initialState =
          services.state!['initialState'] as Map<String, dynamic>?;
      if (initialState != null) {
        _stateManager.setState(initialState);
        _logger.debug('Initialized service state in StateManager');
      }

      // Set up computed properties
      final computed = services.state!['computed'] as Map<String, dynamic>?;
      if (computed != null) {
        _initializeComputedProperties(computed);
      }

      // Set up watchers
      final watchers = services.state!['watchers'] as List<dynamic>?;
      if (watchers != null) {
        _initializeWatchers(watchers);
      }
    }

    // Initialize navigation service
    if (services.navigation != null) {
      final navService = _serviceRegistry.get<NavigationService>('navigation');
      if (navService != null) {
        // TODO: Configure navigation service
      }
    }

    // Initialize other services...
  }

  /// Start background services
  Future<void> _startBackgroundServices(
      Map<String, dynamic> servicesConfig) async {
    final services = <String, BackgroundServiceDefinition>{};

    for (final entry in servicesConfig.entries) {
      final serviceId = entry.key;
      final serviceConfig = entry.value as Map<String, dynamic>;

      try {
        final serviceDef =
            BackgroundServiceDefinition.fromJson(serviceId, serviceConfig);
        services[serviceId] = serviceDef;
      } catch (error) {
        if (enableDebugMode) {
          _logger.error('Error parsing background service "$serviceId"', error);
        }
      }
    }

    if (services.isNotEmpty) {
      await _backgroundServiceManager.startServices(services);
    }
  }

  /// Handles MCP notification for resource updates
  void handleNotification(String uri, Map<String, dynamic> data) {
    _logger.debug(
        'RuntimeEngine handling notification for URI: $uri with data: $data');

    // Forward to notification manager for additional processing
    // Notification manager is initialized during runtime setup

    // Update state based on notification
    final binding = data['binding'] as String?;
    if (binding != null) {
      final value = data['value'];
      _logger.debug('Updating binding $binding with value: $value');
      _stateManager.set(binding, value);
    }
  }

  /// Handles MCP notification with automatic mode detection
  /// Supports both standard (URI only) and extended (URI + content) modes
  Future<void> handleMCPNotification(
    Map<String, dynamic> params, {
    Function(String)? resourceReader,
  }) async {
    _logger.debug('=== MCP NOTIFICATION ===');
    _logger.debug('Params: $params');

    final uri = params['uri'] as String?;
    if (uri == null) {
      _logger.warning('No URI in notification params');
      return;
    }

    // Find binding for this URI
    final binding = getBindingForUri(uri);
    if (binding == null) {
      _logger.warning('No binding found for URI: $uri');
      return;
    }

    _logger.debug('Binding found: $binding');

    // Check if content is included (extended mode)
    if (params.containsKey('content')) {
      // Extended mode: content included in notification
      _logger.debug('Extended mode detected - using content from notification');

      final contentData = params['content'];
      _logger.debug('Content data type: ${contentData.runtimeType}');
      _logger.debug('Content data: $contentData');

      if (contentData is Map<String, dynamic>) {
        // Check if it's a ResourceContentInfo structure
        if (contentData.containsKey('text')) {
          // Parse the text content
          final text = contentData['text'] as String?;
          if (text != null) {
            try {
              final parsedData = jsonDecode(text);
              _logger.debug('Parsed text content: $parsedData');

              // Extract value based on binding name
              final value = (parsedData is Map<String, dynamic> &&
                      parsedData.containsKey(binding))
                  ? parsedData[binding]
                  : parsedData;

              _logger.debug('Updating state: $binding = $value');
              _stateManager.set(binding, value);
            } catch (e) {
              _logger.error('Failed to parse text content: $e');
            }
          }
        } else {
          // Direct content (might not have text wrapper)
          final value = contentData.containsKey(binding)
              ? contentData[binding]
              : contentData;

          _logger.debug('Updating state: $binding = $value');
          _stateManager.set(binding, value);
        }

        // Update notification count if it exists in state
        final currentCount = _stateManager.get('notificationCount');
        if (currentCount != null && currentCount is int) {
          _stateManager.set('notificationCount', currentCount + 1);
        }

        notifyListeners();
      }
    } else {
      // Standard mode: need to read resource
      _logger.debug('Standard mode detected - reading resource');

      if (resourceReader != null) {
        try {
          final resourceContent = await resourceReader(uri);
          final data = jsonDecode(resourceContent);

          // Extract value based on binding name
          final value =
              (data is Map<String, dynamic> && data.containsKey(binding))
                  ? data[binding]
                  : data;

          _logger.debug('Updating state: $binding = $value');
          _stateManager.set(binding, value);

          // Update notification count if it exists in state
          final currentCount = _stateManager.get('notificationCount');
          if (currentCount != null && currentCount is int) {
            _stateManager.set('notificationCount', currentCount + 1);
          }

          notifyListeners();
        } catch (e) {
          _logger.error('Failed to read resource: $e');
        }
      } else {
        _logger.warning('Standard mode but no resource reader provided');
      }
    }

    _logger.debug('=== MCP NOTIFICATION END ===');
  }

  /// Marks the runtime as ready and executes onReady lifecycle hooks
  Future<void> markReady() async {
    if (!_isInitialized) {
      throw StateError(
          'Runtime engine must be initialized before marking ready');
    }

    if (_isReady) return;

    _isReady = true;

    if (enableDebugMode) {
      _logger.info('Marked as ready');
    }

    // Execute onReady lifecycle hooks
    final lifecycle = _parsedUIDefinition?.type == UIDefinitionType.application
        ? _applicationDefinition?.lifecycleDefinition
        : (_parsedUIDefinition?.type == UIDefinitionType.page
            ? PageDefinition.fromUIDefinition(_parsedUIDefinition!)
                .lifecycleDefinition
            : null);

    if (lifecycle != null && lifecycle.onReady != null) {
      await _lifecycleManager.executeLifecycleHooks(
        LifecycleEvent.ready,
        lifecycle.onReady!,
      );
    } else if (_runtimeConfig?['lifecycle']?['onReady'] != null) {
      // Fallback to runtime config for legacy format
      await _lifecycleManager.executeLifecycleHooks(
        LifecycleEvent.ready,
        _runtimeConfig!['lifecycle']['onReady'] as List<dynamic>,
      );
    }

    notifyListeners();
  }

  /// Handles application pause events
  Future<void> pause() async {
    if (!_isReady) return;

    if (enableDebugMode) {
      _logger.info('Paused');
    }

    // Execute onPause lifecycle hooks
    if (_runtimeConfig?['lifecycle']?['onPause'] != null) {
      await _lifecycleManager.executeLifecycleHooks(
        LifecycleEvent.pause,
        _runtimeConfig!['lifecycle']['onPause'] as List<dynamic>,
      );
    }
  }

  /// Handles application resume events
  Future<void> resume() async {
    if (!_isReady) return;

    if (enableDebugMode) {
      _logger.info('Resumed');
    }

    // Execute onResume lifecycle hooks
    if (_runtimeConfig?['lifecycle']?['onResume'] != null) {
      await _lifecycleManager.executeLifecycleHooks(
        LifecycleEvent.resume,
        _runtimeConfig!['lifecycle']['onResume'] as List<dynamic>,
      );
    }
  }

  /// Destroys the runtime and cleans up resources
  Future<void> destroy() async {
    if (!_isInitialized) return;

    if (enableDebugMode) {
      _logger.info('Destroying...');
    }

    // Execute onDestroy lifecycle hooks
    if (_runtimeConfig?['lifecycle']?['onDestroy'] != null) {
      await _lifecycleManager.executeLifecycleHooks(
        LifecycleEvent.destroy,
        _runtimeConfig!['lifecycle']['onDestroy'] as List<dynamic>,
      );
    }

    // Cleanup services
    await _backgroundServiceManager.dispose();
    await _serviceRegistry.dispose();
    await _notificationManager.dispose();
    _lifecycleManager.dispose();

    _isInitialized = false;
    _isReady = false;
    _runtimeConfig = null;
    _uiDefinition = null;

    if (enableDebugMode) {
      _logger.info('Destroyed');
    }

    notifyListeners();
  }

  /// Registers core runtime services
  Future<void> _registerCoreServices() async {
    // Note: StateService is no longer registered as we use StateManager directly
    // This is kept for backward compatibility with services that might expect it
    // TODO: Remove this comment after verifying no services depend on StateService

    // Register NavigationService
    _serviceRegistry.register(
      'navigation',
      NavigationService(enableDebugMode: enableDebugMode),
    );

    // Register DialogService
    _serviceRegistry.register(
      'dialogs',
      DialogService(enableDebugMode: enableDebugMode),
    );

    // Register NotificationService
    _serviceRegistry.register(
      'notifications',
      NotificationService(
        notificationManager: _notificationManager,
        enableDebugMode: enableDebugMode,
      ),
    );
  }

  /// Tries to load app from cache
  Future<Map<String, dynamic>?> _tryLoadFromCache(
      Map<String, dynamic> definition) async {
    try {
      // v1.0 format: application type has properties at top level
      if (definition['type'] == 'application') {
        final domain = definition['domain'] as String?;
        final id = definition['id'] as String?;
        final version = definition['version'] as String?;

        if (domain == null || id == null || version == null) {
          return null;
        }

        final cachedApp = _cacheManager.getCachedApp(domain, id);
        if (cachedApp != null) {
          // Check if we need to update
          if (_cacheManager.isUpdateAvailable(domain, id, version)) {
            if (enableDebugMode) {
              _logger.info('Update available for $domain:$id');
            }
            // Still use cached version but mark for update
            // In production, you might want to trigger an update check
          }

          // Load cached state if available
          final appKey = '$domain:$id';
          final cachedState = _cacheManager.getCachedState(appKey);
          if (cachedState != null) {
            // Merge cached state into StateManager
            _stateManager.setState(cachedState);
            _logger.debug('Loaded cached state into StateManager');
          }

          return cachedApp.definition;
        }
      }
    } catch (error) {
      if (enableDebugMode) {
        _logger.error('Error loading from cache', error);
      }
    }

    return null;
  }

  /// Caches the app definition
  Future<void> _cacheApp(Map<String, dynamic> definition) async {
    try {
      final cachedApp = CachedApp.fromDefinition(definition);
      await _cacheManager.cacheApp(cachedApp);

      // Also cache the current state
      final appKey = '${cachedApp.domain}:${cachedApp.id}';
      await _cacheManager.cacheState(appKey, _stateManager.getState());
      _logger.debug('Cached current state from StateManager');
    } catch (error) {
      if (enableDebugMode) {
        _logger.error('Error caching app', error);
      }
    }
  }

  @override
  void dispose() {
    if (_isInitialized) {
      destroy().catchError((error) {
        // Ignore errors during disposal
        if (enableDebugMode) {
          _logger.error('Error during disposal', error);
        }
      });
    }
    super.dispose();
  }

  /// Convert LifecycleDefinition to JSON
  Map<String, dynamic> _lifecycleToJson(LifecycleDefinition lifecycle) {
    return {
      if (lifecycle.onInitialize != null)
        'onInitialize': lifecycle.onInitialize,
      if (lifecycle.onReady != null) 'onReady': lifecycle.onReady,
      if (lifecycle.onMount != null) 'onMount': lifecycle.onMount,
      if (lifecycle.onUnmount != null) 'onUnmount': lifecycle.onUnmount,
      if (lifecycle.onDestroy != null) 'onDestroy': lifecycle.onDestroy,
      if (lifecycle.onEnter != null) 'onEnter': lifecycle.onEnter,
      if (lifecycle.onLeave != null) 'onLeave': lifecycle.onLeave,
      if (lifecycle.onResume != null) 'onResume': lifecycle.onResume,
      if (lifecycle.onPause != null) 'onPause': lifecycle.onPause,
    };
  }

  /// Convert ServicesDefinition to JSON
  Map<String, dynamic> _servicesToJson(ServicesDefinition services) {
    return {
      if (services.state != null) 'state': services.state,
      if (services.navigation != null) 'navigation': services.navigation,
      if (services.dialog != null) 'dialog': services.dialog,
      if (services.notification != null) 'notification': services.notification,
      if (services.backgroundServices != null)
        'backgroundServices': services.backgroundServices,
    };
  }

  /// Initialize computed properties
  void _initializeComputedProperties(Map<String, dynamic> computed) {
    for (final entry in computed.entries) {
      final key = entry.key;
      final config = entry.value as Map<String, dynamic>;

      final expression = config['expression'] as String?;
      final dependencies =
          (config['dependencies'] as List?)?.cast<String>() ?? [];

      if (expression != null) {
        _computedManager.registerComputed(
          key,
          ComputedConfig(
            expression: expression,
            dependencies: dependencies,
          ),
        );
      }
    }
  }

  /// Initialize watchers
  void _initializeWatchers(List<dynamic> watchers) {
    for (final watcherDef in watchers) {
      if (watcherDef is Map<String, dynamic>) {
        final path = watcherDef['path'] as String?;
        final handler = watcherDef['handler'] as Map<String, dynamic>?;
        final immediate = watcherDef['immediate'] as bool? ?? false;
        final deep = watcherDef['deep'] as bool? ?? false;

        if (path != null && handler != null) {
          _computedManager.registerWatcher(
            path,
            WatcherConfig(
              handler: (value, oldValue) {
                // Execute the handler action
                final watchContext =
                    renderer.createRootContext(null).createChildContext(
                  variables: {
                    'value': value,
                    'oldValue': oldValue,
                  },
                );
                _actionHandler.execute(handler, watchContext);
              },
              immediate: immediate,
              deep: deep,
            ),
          );
        }
      }
    }
  }

  /// Initialize core components that need to be available immediately
  void _initializeCoreComponents() {
    // Initialize these components so they're available before initialize() is called
    _lifecycleManager = LifecycleManager(
      enableDebugMode: enableDebugMode,
    );

    _serviceRegistry = ServiceRegistry(
      enableDebugMode: enableDebugMode,
    );

    _widgetRegistry = WidgetRegistry();
    _bindingEngine = BindingEngine();
    _actionHandler = ActionHandler();
    _stateManager = StateManager();
    _themeManager = ThemeManager();
    _computedManager = ComputedManager(
      stateManager: _stateManager,
      bindingEngine: _bindingEngine,
    );

    _notificationManager = NotificationManager(
      enableDebugMode: enableDebugMode,
    );

    _cacheManager = CacheManager(
      enableDebugMode: enableDebugMode,
    );

    _backgroundServiceManager = BackgroundServiceManager(
      enableDebugMode: enableDebugMode,
      actionHandler: _actionHandler,
      stateManager: _stateManager,
    );
  }
}
