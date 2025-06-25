import 'package:flutter/material.dart';
import '../runtime/service_registry.dart';

/// Navigation service for managing app navigation
class NavigationService extends RuntimeService {
  // Singleton instance
  static NavigationService? _instance;
  static NavigationService get instance {
    _instance ??= NavigationService._internal();
    return _instance!;
  }

  NavigationService._internal();

  // Factory constructor returns singleton instance
  factory NavigationService({bool enableDebugMode = false}) {
    return instance;
  }

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final List<Route<dynamic>> _routeStack = [];
  final Map<String, WidgetBuilder> _routes = {};
  final Map<String, dynamic> _routeGuards = {};
  bool _preventNavigation = false;

  /// Gets the current navigator state
  NavigatorState? get navigator => navigatorKey.currentState;

  /// Gets the current route name
  String? get currentRoute =>
      _routeStack.isNotEmpty ? _routeStack.last.settings.name : null;

  /// Gets the route stack
  List<String> get routeStack => _routeStack
      .where((route) => route.settings.name != null)
      .map((route) => route.settings.name!)
      .toList();

  /// Navigates to a named route
  Future<T?> navigateTo<T>(
    String routeName, {
    Object? arguments,
    bool replace = false,
    bool clearStack = false,
  }) async {
    if (_preventNavigation) {
      if (enableDebugMode) {
        debugPrint('NavigationService: Navigation prevented');
      }
      return null;
    }

    // Check route guard
    if (!await _checkRouteGuard(routeName, arguments)) {
      if (enableDebugMode) {
        debugPrint(
            'NavigationService: Route guard prevented navigation to "$routeName"');
      }
      return null;
    }

    if (navigator == null) {
      throw StateError('Navigator not initialized');
    }

    try {
      if (clearStack) {
        return await navigator!.pushNamedAndRemoveUntil<T>(
          routeName,
          (route) => false,
          arguments: arguments,
        );
      } else if (replace) {
        return await navigator!.pushReplacementNamed<T, T>(
          routeName,
          arguments: arguments,
        );
      } else {
        return await navigator!.pushNamed<T>(
          routeName,
          arguments: arguments,
        );
      }
    } catch (error) {
      if (enableDebugMode) {
        debugPrint(
            'NavigationService: Error navigating to "$routeName": $error');
      }
      rethrow;
    }
  }

  /// Goes back to the previous route
  void goBack<T>([T? result]) {
    if (navigator == null) {
      throw StateError('Navigator not initialized');
    }

    if (navigator!.canPop()) {
      navigator!.pop<T>(result);
    } else {
      if (enableDebugMode) {
        debugPrint('NavigationService: Cannot go back - no routes to pop');
      }
    }
  }

  /// Checks if navigation can go back
  bool canGoBack() {
    return navigator?.canPop() ?? false;
  }

  /// Pops routes until a specific route is reached
  void popUntil(String routeName) {
    if (navigator == null) {
      throw StateError('Navigator not initialized');
    }

    navigator!.popUntil((route) => route.settings.name == routeName);
  }

  /// Registers a route
  void registerRoute(String name, WidgetBuilder builder) {
    _routes[name] = builder;

    if (enableDebugMode) {
      debugPrint('NavigationService: Registered route "$name"');
    }
  }

  /// Registers multiple routes
  void registerRoutes(Map<String, WidgetBuilder> routes) {
    _routes.addAll(routes);

    if (enableDebugMode) {
      debugPrint('NavigationService: Registered ${routes.length} routes');
    }
  }

  /// Gets registered routes
  Map<String, WidgetBuilder> get routes => Map.from(_routes);

  /// Adds a route guard
  void addRouteGuard(String routeName, Future<bool> Function(Object?) guard) {
    _routeGuards[routeName] = guard;

    if (enableDebugMode) {
      debugPrint('NavigationService: Added route guard for "$routeName"');
    }
  }

  /// Removes a route guard
  void removeRouteGuard(String routeName) {
    _routeGuards.remove(routeName);

    if (enableDebugMode) {
      debugPrint('NavigationService: Removed route guard for "$routeName"');
    }
  }

  /// Prevents navigation temporarily
  void preventNavigation() {
    _preventNavigation = true;

    if (enableDebugMode) {
      debugPrint('NavigationService: Navigation prevented');
    }
  }

  /// Allows navigation
  void allowNavigation() {
    _preventNavigation = false;

    if (enableDebugMode) {
      debugPrint('NavigationService: Navigation allowed');
    }
  }

  /// Shows a dialog
  Future<T?> showDialogModal<T>({
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    Color? barrierColor,
    String? barrierLabel,
    bool useSafeArea = true,
    bool useRootNavigator = true,
    RouteSettings? routeSettings,
  }) async {
    final context = navigatorKey.currentContext;
    if (context == null) {
      throw StateError('No context available for dialog');
    }

    return await showDialog<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor ?? Colors.black54,
      barrierLabel: barrierLabel,
      useSafeArea: useSafeArea,
      useRootNavigator: useRootNavigator,
      routeSettings: routeSettings,
    );
  }

  /// Shows a bottom sheet
  Future<T?> showBottomSheet<T>({
    required WidgetBuilder builder,
    Color? backgroundColor,
    double? elevation,
    ShapeBorder? shape,
    Clip? clipBehavior,
    BoxConstraints? constraints,
    bool? enableDrag,
    bool isDismissible = true,
    bool isScrollControlled = false,
    bool useRootNavigator = false,
    RouteSettings? routeSettings,
  }) async {
    final context = navigatorKey.currentContext;
    if (context == null) {
      throw StateError('No context available for bottom sheet');
    }

    return await showModalBottomSheet<T>(
      context: context,
      builder: builder,
      backgroundColor: backgroundColor,
      elevation: elevation,
      shape: shape,
      clipBehavior: clipBehavior,
      constraints: constraints,
      barrierColor: Colors.black54,
      isScrollControlled: isScrollControlled,
      useRootNavigator: useRootNavigator,
      isDismissible: isDismissible,
      enableDrag: enableDrag ?? isDismissible,
      routeSettings: routeSettings,
    );
  }

  /// Shows a snackbar
  void showSnackBar({
    required String message,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
    Color? backgroundColor,
    double? elevation,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
    ShapeBorder? shape,
    SnackBarBehavior? behavior,
    double? width,
  }) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      throw StateError('No context available for snackbar');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        action: action,
        backgroundColor: backgroundColor,
        elevation: elevation,
        margin: margin,
        padding: padding,
        shape: shape,
        behavior: behavior ?? SnackBarBehavior.floating,
        width: width,
      ),
    );
  }

  /// Creates a route observer to track route changes
  RouteObserver<PageRoute> createRouteObserver() {
    return _MCPRouteObserver(
      onPushed: (route, previousRoute) {
        _routeStack.add(route);
        if (enableDebugMode) {
          debugPrint(
              'NavigationService: Pushed route "${route.settings.name}"');
        }
      },
      onPopped: (route, previousRoute) {
        _routeStack.remove(route);
        if (enableDebugMode) {
          debugPrint(
              'NavigationService: Popped route "${route.settings.name}"');
        }
      },
      onRemoved: (route, previousRoute) {
        _routeStack.remove(route);
        if (enableDebugMode) {
          debugPrint(
              'NavigationService: Removed route "${route.settings.name}"');
        }
      },
      onReplaced: (newRoute, oldRoute) {
        final index = _routeStack.indexOf(oldRoute!);
        if (index != -1) {
          _routeStack[index] = newRoute!;
        }
        if (enableDebugMode) {
          debugPrint(
              'NavigationService: Replaced route "${oldRoute.settings.name}" with "${newRoute?.settings.name}"');
        }
      },
    );
  }

  @override
  Future<void> onInitialize(Map<String, dynamic> config) async {
    // Register routes from config
    final routesConfig = config['routes'] as Map<String, dynamic>?;
    if (routesConfig != null) {
      // Routes would be created from JSON definitions
      if (enableDebugMode) {
        debugPrint(
            'NavigationService: Configured ${routesConfig.length} routes');
      }
    }

    // Setup route guards from config
    final guardsConfig = config['guards'] as Map<String, dynamic>?;
    if (guardsConfig != null) {
      // Guards would be created from JSON definitions
      if (enableDebugMode) {
        debugPrint(
            'NavigationService: Configured ${guardsConfig.length} route guards');
      }
    }
  }

  @override
  Future<void> onDispose() async {
    _routes.clear();
    _routeGuards.clear();
    _routeStack.clear();
    _preventNavigation = false;
  }

  /// Reset singleton instance (for testing only)
  @visibleForTesting
  static void resetInstance() {
    _instance = null;
  }

  /// Checks if a route guard allows navigation
  Future<bool> _checkRouteGuard(String routeName, Object? arguments) async {
    final guard = _routeGuards[routeName];
    if (guard == null) return true;

    try {
      return await (guard as Future<bool> Function(Object?))(arguments);
    } catch (error) {
      if (enableDebugMode) {
        debugPrint(
            'NavigationService: Error in route guard for "$routeName": $error');
      }
      return false;
    }
  }
}

/// Custom route observer for tracking navigation
class _MCPRouteObserver extends RouteObserver<PageRoute> {
  _MCPRouteObserver({
    this.onPushed,
    this.onPopped,
    this.onRemoved,
    this.onReplaced,
  });

  final void Function(Route<dynamic> route, Route<dynamic>? previousRoute)?
      onPushed;
  final void Function(Route<dynamic> route, Route<dynamic>? previousRoute)?
      onPopped;
  final void Function(Route<dynamic> route, Route<dynamic>? previousRoute)?
      onRemoved;
  final void Function(Route<dynamic>? newRoute, Route<dynamic>? oldRoute)?
      onReplaced;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    onPushed?.call(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    onPopped?.call(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    onRemoved?.call(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    onReplaced?.call(newRoute, oldRoute);
  }
}
