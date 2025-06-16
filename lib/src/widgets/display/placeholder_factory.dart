import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for Placeholder widgets
class PlaceholderWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    
    // Extract properties
    final color = parseColor(context.resolve(properties['color'])) ?? 
                  const Color(0xFF455A64); // Default grey
    final strokeWidth = properties['strokeWidth']?.toDouble() ?? 2.0;
    final fallbackWidth = properties['fallbackWidth']?.toDouble() ?? 400.0;
    final fallbackHeight = properties['fallbackHeight']?.toDouble() ?? 400.0;
    
    // Extract child widget (usually not used for Placeholder)
    final childrenDef = properties['children'] as List<dynamic>? ?? 
                       definition['children'] as List<dynamic>?;
    Widget? child;
    if (childrenDef != null && childrenDef.isNotEmpty) {
      child = context.buildWidget(childrenDef.first as Map<String, dynamic>);
    }
    
    Widget placeholder = Placeholder(
      color: color,
      strokeWidth: strokeWidth,
      fallbackWidth: fallbackWidth,
      fallbackHeight: fallbackHeight,
      child: child,
    );
    
    return applyCommonWrappers(placeholder, properties, context);
  }
}