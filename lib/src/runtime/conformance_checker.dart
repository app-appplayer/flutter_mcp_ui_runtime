import '../runtime/widget_registry.dart';

/// Conformance level definitions for MCP UI DSL v1.0
enum ConformanceLevel {
  /// Core conformance - Basic widget set
  core,
  
  /// Standard conformance - Extended widget set including navigation and forms
  standard,
  
  /// Advanced conformance - Full widget set including charts, maps, etc.
  advanced,
}

/// Checker for determining conformance level support
class ConformanceChecker {
  final WidgetRegistry widgetRegistry;
  
  ConformanceChecker(this.widgetRegistry);
  
  /// Core widgets required for Core conformance
  static const List<String> coreWidgets = [
    // Layout
    'linear',
    'box',
    
    // Display
    'text',
    'image',
    'icon',
    
    // Input
    'button',
    'text-input',
    'toggle',
    'select',
    
    // Lists
    'list',
    'list-item',
  ];
  
  /// Additional widgets required for Standard conformance
  static const List<String> standardWidgets = [
    // Navigation
    'header-bar',
    'bottom-navigation',
    'tabs',
    'drawer',
    
    // Forms
    'form',
    'radio',
    'checkbox',
    'slider',
    
    // Feedback
    'dialog',
    'snackbar',
    'progress',
    
    // Layout
    'grid',
    'card',
  ];
  
  /// Additional widgets required for Advanced conformance
  static const List<String> advancedWidgets = [
    // Data visualization
    'chart',
    'map',
    
    // Media
    'media-player',
    
    // Advanced UI
    'calendar',
    'table',
    'tree',
  ];
  
  /// Check if the runtime supports a specific conformance level
  bool supportsLevel(ConformanceLevel level) {
    switch (level) {
      case ConformanceLevel.core:
        return _hasAllWidgets(coreWidgets);
      case ConformanceLevel.standard:
        return _hasAllWidgets(coreWidgets) && _hasAllWidgets(standardWidgets);
      case ConformanceLevel.advanced:
        return _hasAllWidgets(coreWidgets) && 
               _hasAllWidgets(standardWidgets) && 
               _hasAllWidgets(advancedWidgets);
    }
  }
  
  /// Get the highest conformance level supported
  ConformanceLevel getConformanceLevel() {
    if (supportsLevel(ConformanceLevel.advanced)) {
      return ConformanceLevel.advanced;
    } else if (supportsLevel(ConformanceLevel.standard)) {
      return ConformanceLevel.standard;
    } else if (supportsLevel(ConformanceLevel.core)) {
      return ConformanceLevel.core;
    }
    // If not even core is supported, return core anyway
    return ConformanceLevel.core;
  }
  
  /// Get missing widgets for a specific conformance level
  List<String> getMissingWidgets(ConformanceLevel level) {
    final missing = <String>[];
    
    // Check core widgets
    for (final widget in coreWidgets) {
      if (!widgetRegistry.has(widget)) {
        missing.add(widget);
      }
    }
    
    // Check standard widgets if needed
    if (level == ConformanceLevel.standard || level == ConformanceLevel.advanced) {
      for (final widget in standardWidgets) {
        if (!widgetRegistry.has(widget)) {
          missing.add(widget);
        }
      }
    }
    
    // Check advanced widgets if needed
    if (level == ConformanceLevel.advanced) {
      for (final widget in advancedWidgets) {
        if (!widgetRegistry.has(widget)) {
          missing.add(widget);
        }
      }
    }
    
    return missing;
  }
  
  /// Get a report of conformance support
  Map<String, dynamic> getConformanceReport() {
    final coreSupport = _getWidgetSupport(coreWidgets);
    final standardSupport = _getWidgetSupport(standardWidgets);
    final advancedSupport = _getWidgetSupport(advancedWidgets);
    
    return {
      'conformanceLevel': getConformanceLevel().toString().split('.').last,
      'core': {
        'supported': coreSupport['supported'],
        'missing': coreSupport['missing'],
        'percentage': coreSupport['percentage'],
      },
      'standard': {
        'supported': standardSupport['supported'],
        'missing': standardSupport['missing'],
        'percentage': standardSupport['percentage'],
      },
      'advanced': {
        'supported': advancedSupport['supported'],
        'missing': advancedSupport['missing'],
        'percentage': advancedSupport['percentage'],
      },
    };
  }
  
  /// Check if all widgets in a list are available
  bool _hasAllWidgets(List<String> widgets) {
    for (final widget in widgets) {
      if (!widgetRegistry.has(widget)) {
        return false;
      }
    }
    return true;
  }
  
  /// Get support information for a list of widgets
  Map<String, dynamic> _getWidgetSupport(List<String> widgets) {
    final supported = <String>[];
    final missing = <String>[];
    
    for (final widget in widgets) {
      if (widgetRegistry.has(widget)) {
        supported.add(widget);
      } else {
        missing.add(widget);
      }
    }
    
    final percentage = widgets.isEmpty 
        ? 100.0 
        : (supported.length / widgets.length * 100).roundToDouble();
    
    return {
      'supported': supported,
      'missing': missing,
      'percentage': percentage,
    };
  }
}