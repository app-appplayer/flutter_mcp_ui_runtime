import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for Divider widgets
class DividerWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    
    // Extract properties
    final height = properties['height']?.toDouble();
    final thickness = properties['thickness']?.toDouble() ?? 1.0;
    final indent = properties['indent']?.toDouble() ?? 0.0;
    final endIndent = properties['endIndent']?.toDouble() ?? 0.0;
    final color = parseColor(context.resolve(properties['color']));
    final isVertical = properties['vertical'] as bool? ?? false;
    
    Widget divider;
    
    if (isVertical) {
      divider = VerticalDivider(
        width: height,
        thickness: thickness,
        indent: indent,
        endIndent: endIndent,
        color: color,
      );
    } else {
      divider = Divider(
        height: height,
        thickness: thickness,
        indent: indent,
        endIndent: endIndent,
        color: color,
      );
    }
    
    return applyCommonWrappers(divider, properties, context);
  }
}