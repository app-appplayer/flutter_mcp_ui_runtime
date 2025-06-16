library ui_definition;

import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart' as core;

/// Core models for MCP UI DSL v1.0
/// 
/// This file defines the core data structures for UI definitions
/// according to the MCP UI DSL v1.0 specification.

/// Type of UI definition
enum UIDefinitionType {
  /// Complete application with routing
  application,
  /// Single page definition
  page,
}

/// Main UI definition that can be either an application or a page
class UIDefinition {
  final UIDefinitionType type;
  final Map<String, dynamic> properties;
  final Map<String, dynamic>? routes;
  final Map<String, dynamic>? state;
  final Map<String, dynamic>? navigation;
  final Map<String, dynamic>? lifecycle;
  final Map<String, dynamic>? services;
  final Map<String, dynamic>? content;

  UIDefinition({
    required this.type,
    required this.properties,
    this.routes,
    this.state,
    this.navigation,
    this.lifecycle,
    this.services,
    this.content,
  });

  factory UIDefinition.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String?;
    UIDefinitionType type;
    
    if (typeStr == 'application') {
      type = UIDefinitionType.application;
    } else if (typeStr == 'page') {
      type = UIDefinitionType.page;
    } else {
      // Default to page for backward compatibility
      type = UIDefinitionType.page;
    }

    // For application type, extract top-level properties
    final properties = <String, dynamic>{};
    if (type == UIDefinitionType.application) {
      // Add application-specific properties
      if (json['title'] != null) properties['title'] = json['title'];
      if (json['version'] != null) properties['version'] = json['version'];
      if (json['initialRoute'] != null) properties['initialRoute'] = json['initialRoute'];
      if (json['theme'] != null) properties['theme'] = json['theme'];
    } else if (type == UIDefinitionType.page) {
      // Add page-specific properties
      if (json['title'] != null) properties['title'] = json['title'];
      if (json['route'] != null) properties['route'] = json['route'];
      if (json['themeOverride'] != null) properties['themeOverride'] = json['themeOverride'];
    }
    
    // Merge with explicit properties if any
    if (json['properties'] != null) {
      properties.addAll(Map<String, dynamic>.from(json['properties'] as Map));
    }

    return UIDefinition(
      type: type,
      properties: properties,
      routes: json['routes'] != null ? Map<String, dynamic>.from(json['routes'] as Map) : null,
      state: json['state'] != null 
        ? Map<String, dynamic>.from(json['state'] as Map) 
        : (json['initialState'] != null 
            ? {'initial': Map<String, dynamic>.from(json['initialState'] as Map)}
            : null),
      navigation: json['navigation'] != null ? Map<String, dynamic>.from(json['navigation'] as Map) : null,
      lifecycle: json['lifecycle'] != null ? Map<String, dynamic>.from(json['lifecycle'] as Map) : null,
      services: json['services'] != null ? Map<String, dynamic>.from(json['services'] as Map) : null,
      content: json['content'] != null ? Map<String, dynamic>.from(json['content'] as Map) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type == UIDefinitionType.application ? 'application' : 'page',
      'properties': properties,
      if (routes != null) 'routes': routes,
      if (state != null) 'state': state,
      if (navigation != null) 'navigation': navigation,
      if (lifecycle != null) 'lifecycle': lifecycle,
      if (services != null) 'services': services,
      if (content != null) 'content': content,
    };
  }
}

/// Application definition according to spec
class ApplicationDefinition extends core.ApplicationConfig {
  final NavigationDefinition? navigationDef;
  final LifecycleDefinition? lifecycleDef;
  final ServicesDefinition? servicesDef;

  ApplicationDefinition({
    required super.title,
    required super.version,
    required super.initialRoute,
    required super.routes,
    super.theme,
    Map<String, dynamic>? initialState,
    this.navigationDef,
    this.lifecycleDef,
    this.servicesDef,
  }) : super(
    state: initialState != null ? {'initial': initialState} : null,
    navigation: navigationDef?.toJson(),
    lifecycle: lifecycleDef?.toJson(),
    services: servicesDef?.toJson(),
  );

  factory ApplicationDefinition.fromUIDefinition(UIDefinition definition) {
    if (definition.type != UIDefinitionType.application) {
      throw ArgumentError('UI definition is not an application type');
    }

    final props = definition.properties;
    final routes = definition.routes;
    
    if (routes == null || routes.isEmpty) {
      throw ArgumentError('Application must have routes defined');
    }

    return ApplicationDefinition(
      title: props['title'] as String? ?? 'MCP Application',
      version: props['version'] as String? ?? '1.0.0',
      initialRoute: props['initialRoute'] as String? ?? '/',
      routes: Map<String, String>.from(routes),
      theme: props['theme'] as Map<String, dynamic>?,
      initialState: definition.state?['initial'] != null
          ? Map<String, dynamic>.from(definition.state!['initial'] as Map)
          : null,
      navigationDef: definition.navigation != null 
        ? NavigationDefinition.fromJson(definition.navigation!)
        : null,
      lifecycleDef: definition.lifecycle != null
        ? LifecycleDefinition.fromJson(definition.lifecycle!)
        : null,
      servicesDef: definition.services != null
        ? ServicesDefinition.fromJson(definition.services!)
        : null,
    );
  }

  NavigationDefinition? get navigationDefinition => navigationDef;
  LifecycleDefinition? get lifecycleDefinition => lifecycleDef;
  ServicesDefinition? get servicesDefinition => servicesDef;
  
  @override
  Map<String, dynamic>? get initialState => state?['initial'] != null
      ? Map<String, dynamic>.from(state!['initial'] as Map)
      : null;
}

/// Page definition according to spec
class PageDefinition extends core.PageConfig {
  final LifecycleDefinition? lifecycleDef;

  PageDefinition({
    super.title,
    super.route,
    required super.content,
    super.themeOverride,
    Map<String, dynamic>? initialState,
    this.lifecycleDef,
  }) : super(
    state: initialState != null ? {'initial': initialState} : null,
    lifecycle: lifecycleDef?.toJson(),
  );

  factory PageDefinition.fromUIDefinition(UIDefinition definition) {
    if (definition.type != UIDefinitionType.page) {
      throw ArgumentError('UI definition is not a page type');
    }

    final props = definition.properties;
    final content = definition.content;
    
    if (content == null || content.isEmpty) {
      throw ArgumentError('Page must have content defined');
    }

    return PageDefinition(
      title: props['title'] as String?,
      route: props['route'] as String?,
      content: content,
      themeOverride: props['themeOverride'] as Map<String, dynamic>?,
      initialState: definition.state?['initial'] != null
          ? Map<String, dynamic>.from(definition.state!['initial'] as Map)
          : null,
      lifecycleDef: definition.lifecycle != null
        ? LifecycleDefinition.fromJson(definition.lifecycle!)
        : null,
    );
  }

  LifecycleDefinition? get lifecycleDefinition => lifecycleDef;
  
  @override
  Map<String, dynamic>? get initialState => state?['initial'] != null
      ? Map<String, dynamic>.from(state!['initial'] as Map)
      : null;
}

/// Navigation definition
class NavigationDefinition {
  final String type; // drawer, tabs, bottom
  final List<NavigationItem> items;

  NavigationDefinition({
    required this.type,
    required this.items,
  });

  factory NavigationDefinition.fromJson(Map<String, dynamic> json) {
    // Support both 'items' and 'tabs' for backward compatibility
    final itemsList = json['items'] as List<dynamic>? ?? 
                     json['tabs'] as List<dynamic>? ?? [];
    
    return NavigationDefinition(
      type: json['type'] as String? ?? 'drawer',
      items: itemsList.map((item) => NavigationItem.fromJson(item as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}

/// Navigation item
class NavigationItem {
  final String title;
  final String route;
  final String? icon;

  NavigationItem({
    required this.title,
    required this.route,
    this.icon,
  });

  factory NavigationItem.fromJson(Map<String, dynamic> json) {
    return NavigationItem(
      title: (json['title'] ?? json['label']) as String,
      route: json['route'] as String,
      icon: json['icon'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'route': route,
      if (icon != null) 'icon': icon,
    };
  }
}

/// Lifecycle definition
class LifecycleDefinition {
  final List<Map<String, dynamic>>? onInitialize;
  final List<Map<String, dynamic>>? onReady;
  final List<Map<String, dynamic>>? onMount;
  final List<Map<String, dynamic>>? onUnmount;
  final List<Map<String, dynamic>>? onDestroy;
  final List<Map<String, dynamic>>? onEnter;
  final List<Map<String, dynamic>>? onLeave;
  final List<Map<String, dynamic>>? onResume;
  final List<Map<String, dynamic>>? onPause;

  LifecycleDefinition({
    this.onInitialize,
    this.onReady,
    this.onMount,
    this.onUnmount,
    this.onDestroy,
    this.onEnter,
    this.onLeave,
    this.onResume,
    this.onPause,
  });

  factory LifecycleDefinition.fromJson(Map<String, dynamic> json) {
    return LifecycleDefinition(
      onInitialize: _parseActions(json['onInitialize']),
      onReady: _parseActions(json['onReady']),
      onMount: _parseActions(json['onMount']),
      onUnmount: _parseActions(json['onUnmount']),
      onDestroy: _parseActions(json['onDestroy']),
      onEnter: _parseActions(json['onEnter']),
      onLeave: _parseActions(json['onLeave']),
      onResume: _parseActions(json['onResume']),
      onPause: _parseActions(json['onPause']),
    );
  }

  static List<Map<String, dynamic>>? _parseActions(dynamic actions) {
    if (actions == null) return null;
    if (actions is List) {
      return actions.cast<Map<String, dynamic>>();
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      if (onInitialize != null) 'onInitialize': onInitialize,
      if (onReady != null) 'onReady': onReady,
      if (onMount != null) 'onMount': onMount,
      if (onUnmount != null) 'onUnmount': onUnmount,
      if (onDestroy != null) 'onDestroy': onDestroy,
      if (onEnter != null) 'onEnter': onEnter,
      if (onLeave != null) 'onLeave': onLeave,
      if (onResume != null) 'onResume': onResume,
      if (onPause != null) 'onPause': onPause,
    };
  }
}

/// Services definition
class ServicesDefinition {
  final Map<String, dynamic>? state;
  final Map<String, dynamic>? navigation;
  final Map<String, dynamic>? dialog;
  final Map<String, dynamic>? notification;
  final Map<String, dynamic>? backgroundServices;

  ServicesDefinition({
    this.state,
    this.navigation,
    this.dialog,
    this.notification,
    this.backgroundServices,
  });

  factory ServicesDefinition.fromJson(Map<String, dynamic> json) {
    return ServicesDefinition(
      state: json['state'] as Map<String, dynamic>?,
      navigation: json['navigation'] as Map<String, dynamic>?,
      dialog: json['dialog'] as Map<String, dynamic>?,
      notification: json['notification'] as Map<String, dynamic>?,
      backgroundServices: json['backgroundServices'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (state != null) 'state': state,
      if (navigation != null) 'navigation': navigation,
      if (dialog != null) 'dialog': dialog,
      if (notification != null) 'notification': notification,
      if (backgroundServices != null) 'backgroundServices': backgroundServices,
    };
  }
}

/// Background service definition
class BackgroundServiceDefinition {
  final String id;
  final BackgroundServiceType type;
  final String tool;
  final Map<String, dynamic>? params;
  final int? interval; // for periodic
  final String? schedule; // for scheduled
  final List<String>? events; // for event-based
  final Map<String, dynamic>? constraints;
  final bool runInBackground;
  final String priority;

  BackgroundServiceDefinition({
    required this.id,
    required this.type,
    required this.tool,
    this.params,
    this.interval,
    this.schedule,
    this.events,
    this.constraints,
    this.runInBackground = true,
    this.priority = 'normal',
  });

  factory BackgroundServiceDefinition.fromJson(String id, Map<String, dynamic> json) {
    final typeStr = json['type'] as String;
    BackgroundServiceType type;
    
    switch (typeStr) {
      case 'periodic':
        type = BackgroundServiceType.periodic;
        break;
      case 'scheduled':
        type = BackgroundServiceType.scheduled;
        break;
      case 'continuous':
        type = BackgroundServiceType.continuous;
        break;
      case 'event':
        type = BackgroundServiceType.event;
        break;
      case 'oneoff':
        type = BackgroundServiceType.oneoff;
        break;
      default:
        throw ArgumentError('Unknown background service type: $typeStr');
    }

    return BackgroundServiceDefinition(
      id: id,
      type: type,
      tool: json['tool'] as String,
      params: json['params'] as Map<String, dynamic>?,
      interval: json['interval'] as int?,
      schedule: json['schedule'] as String?,
      events: (json['events'] as List<dynamic>?)?.cast<String>(),
      constraints: json['constraints'] as Map<String, dynamic>?,
      runInBackground: json['runInBackground'] as bool? ?? true,
      priority: json['priority'] as String? ?? 'normal',
    );
  }
}

/// Types of background services
enum BackgroundServiceType {
  periodic,   // Runs at regular intervals
  scheduled,  // Runs at specific times (cron-like)
  continuous, // Runs continuously
  event,      // Triggered by events
  oneoff,     // Runs once after delay
}