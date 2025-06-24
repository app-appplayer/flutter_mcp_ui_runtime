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

  /// Apply common widget wrappers (visibility, tooltip, accessibility, etc.)
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

    // Handle enabled state - skip for widgets that handle it internally
    // Button widgets handle enabled state by setting onPressed to null
    final isButtonWidget = widget is ElevatedButton || 
                          widget is TextButton || 
                          widget is OutlinedButton || 
                          widget is FilledButton ||
                          widget is IconButton ||
                          widget is GestureDetector ||
                          widget is SizedBox && (
                            widget.child is ElevatedButton ||
                            widget.child is TextButton ||
                            widget.child is OutlinedButton ||
                            widget.child is FilledButton ||
                            widget.child is IconButton
                          );
    
    if (!isButtonWidget) {
      final enabled = context.resolve<bool>(properties['enabled'] ?? true);
      if (!enabled) {
        widget = IgnorePointer(
          child: Opacity(
            opacity: 0.6,
            child: widget,
          ),
        );
      }
    }

    // Handle accessibility (MCP UI DSL v1.0)
    widget = _applyAccessibility(widget, properties, context);

    return widget;
  }

  /// Apply accessibility properties to widget
  Widget _applyAccessibility(
    Widget widget,
    Map<String, dynamic> properties,
    RenderContext context,
  ) {
    // Get accessibility properties
    final ariaLabel = context.resolve<String?>(properties['aria-label']);
    final ariaHidden = context.resolve<bool>(properties['aria-hidden'] ?? false);
    final ariaRole = context.resolve<String?>(properties['aria-role']);
    final ariaDescription = context.resolve<String?>(properties['aria-description']);
    final ariaLiveRegion = context.resolve<String?>(properties['aria-live']);
    
    // If aria-hidden is true, exclude from semantics tree
    if (ariaHidden) {
      return ExcludeSemantics(
        child: widget,
      );
    }
    
    // Apply semantic properties if any are specified
    if (ariaLabel != null || ariaRole != null || ariaDescription != null || ariaLiveRegion != null) {
      // Convert aria-live to Flutter's liveness
      bool? isLiveRegion;
      if (ariaLiveRegion != null) {
        isLiveRegion = ariaLiveRegion == 'polite' || ariaLiveRegion == 'assertive';
      }
      
      widget = Semantics(
        label: ariaLabel,
        hint: ariaDescription,
        liveRegion: isLiveRegion,
        // Map common ARIA roles to Flutter semantic properties
        button: ariaRole == 'button',
        link: ariaRole == 'link',
        header: ariaRole == 'heading',
        textField: ariaRole == 'textbox',
        image: ariaRole == 'img',
        slider: ariaRole == 'slider',
        checked: ariaRole == 'checkbox' ? null : null, // Checkbox state handled by widget itself
        child: widget,
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

  /// Parse Color - supports 6-digit (#RRGGBB) and 8-digit (#AARRGGBB) hex formats
  Color? parseColor(dynamic value) {
    if (value == null) return null;
    
    if (value is String) {
      if (value.startsWith('#')) {
        String hex = value.substring(1);
        
        try {
          // 8자리 AARRGGBB 형식
          if (hex.length == 8) {
            return Color(int.parse(hex, radix: 16));
          }
          // 6자리 RRGGBB 형식 (알파 채널 FF 추가)
          else if (hex.length == 6) {
            return Color(int.parse('FF$hex', radix: 16));
          }
          // 3자리 RGB 축약형 지원
          else if (hex.length == 3) {
            String expanded = hex.split('').map((c) => '$c$c').join();
            return Color(int.parse('FF$expanded', radix: 16));
          }
        } catch (e) {
          // 잘못된 hex 문자가 있는 경우 null 반환
          return null;
        }
        
        return null;
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