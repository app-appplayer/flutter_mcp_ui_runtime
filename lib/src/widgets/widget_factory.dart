import 'package:flutter/material.dart';

import '../renderer/render_context.dart';

/// Base class for widget factories
abstract class WidgetFactory {
  /// Build a widget from definition and context
  Widget build(
    Map<String, dynamic> definition,
    RenderContext context,
  );

  /// Extract common properties
  Map<String, dynamic> extractProperties(Map<String, dynamic> definition) {
    // With the new flat structure, properties are at the top level
    // We create a copy of the definition without the 'type' key
    final properties = Map<String, dynamic>.from(definition);
    properties.remove('type'); // Remove the type key as it's not a property
    return properties;
  }

  /// Apply common widget wrappers (visibility, tooltip, etc.)
  Widget applyCommonWrappers(
    Widget widget,
    Map<String, dynamic> properties,
    RenderContext context,
  ) {
    // Handle visibility
    final visible = context.resolve<bool>(properties['visible'] ?? true);
    if (!visible) {
      return const SizedBox.shrink();
    }

    // Handle tooltip
    final tooltip = context.resolve<String?>(properties['tooltip']);
    if (tooltip != null && tooltip.isNotEmpty) {
      widget = Tooltip(
        message: tooltip,
        child: widget,
      );
    }

    // Handle enabled state
    final enabled = context.resolve<bool>(properties['enabled'] ?? true);
    if (!enabled) {
      widget = IgnorePointer(
        child: Opacity(
          opacity: 0.6,
          child: widget,
        ),
      );
    }

    return widget;
  }

  /// Parse EdgeInsets
  EdgeInsets? parseEdgeInsets(dynamic value) {
    if (value == null) return null;
    
    if (value is Map<String, dynamic>) {
      if (value.containsKey('all')) {
        return EdgeInsets.all(value['all'].toDouble());
      }
      
      if (value.containsKey('horizontal') || value.containsKey('vertical')) {
        return EdgeInsets.symmetric(
          horizontal: value['horizontal']?.toDouble() ?? 0,
          vertical: value['vertical']?.toDouble() ?? 0,
        );
      }
      
      return EdgeInsets.only(
        left: value['left']?.toDouble() ?? 0,
        top: value['top']?.toDouble() ?? 0,
        right: value['right']?.toDouble() ?? 0,
        bottom: value['bottom']?.toDouble() ?? 0,
      );
    }
    
    if (value is num) {
      return EdgeInsets.all(value.toDouble());
    }
    
    return null;
  }

  /// Resolve Color (alias for parseColor)
  Color? resolveColor(dynamic value) {
    return parseColor(value);
  }

  /// Resolve EdgeInsets (alias for parseEdgeInsets)
  EdgeInsets? resolveEdgeInsets(dynamic value) {
    return parseEdgeInsets(value);
  }

  /// Resolve Alignment (alias for parseAlignment)
  Alignment? resolveAlignment(dynamic value) {
    return parseAlignment(value);
  }

  /// Parse Color
  Color? parseColor(dynamic value) {
    if (value == null) return null;
    
    if (value is String) {
      if (value.startsWith('#')) {
        return Color(int.parse(value.substring(1), radix: 16) + 0xFF000000);
      }
      
      // Named colors
      switch (value.toLowerCase()) {
        case 'red':
          return Colors.red;
        case 'blue':
          return Colors.blue;
        case 'green':
          return Colors.green;
        case 'yellow':
          return Colors.yellow;
        case 'orange':
          return Colors.orange;
        case 'purple':
          return Colors.purple;
        case 'black':
          return Colors.black;
        case 'white':
          return Colors.white;
        case 'grey':
        case 'gray':
          return Colors.grey;
        default:
          return null;
      }
    }
    
    return null;
  }

  /// Parse Alignment
  Alignment? parseAlignment(dynamic value) {
    if (value == null) return null;
    
    if (value is String) {
      switch (value) {
        case 'topLeft':
          return Alignment.topLeft;
        case 'topCenter':
          return Alignment.topCenter;
        case 'topRight':
          return Alignment.topRight;
        case 'centerLeft':
          return Alignment.centerLeft;
        case 'center':
          return Alignment.center;
        case 'centerRight':
          return Alignment.centerRight;
        case 'bottomLeft':
          return Alignment.bottomLeft;
        case 'bottomCenter':
          return Alignment.bottomCenter;
        case 'bottomRight':
          return Alignment.bottomRight;
        default:
          return null;
      }
    }
    
    return null;
  }

  /// Parse BoxConstraints
  BoxConstraints? parseConstraints(dynamic value) {
    if (value == null) return null;
    
    if (value is Map<String, dynamic>) {
      return BoxConstraints(
        minWidth: value['minWidth']?.toDouble() ?? 0.0,
        minHeight: value['minHeight']?.toDouble() ?? 0.0,
        maxWidth: value['maxWidth']?.toDouble() ?? double.infinity,
        maxHeight: value['maxHeight']?.toDouble() ?? double.infinity,
      );
    }
    
    return null;
  }
}