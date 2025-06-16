import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for LimitedBox widgets
class LimitedBoxWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    
    // Extract properties
    final maxWidth = properties['maxWidth']?.toDouble() ?? double.infinity;
    final maxHeight = properties['maxHeight']?.toDouble() ?? double.infinity;
    
    // Extract child widget - check both properties and definition level
    final childrenDef = properties['children'] as List<dynamic>? ?? 
                       definition['children'] as List<dynamic>?;
    Widget? child;
    if (childrenDef != null && childrenDef.isNotEmpty) {
      child = context.buildWidget(childrenDef.first as Map<String, dynamic>);
    }
    
    Widget limitedBox = LimitedBox(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      child: child ?? const SizedBox.shrink(),
    );
    
    return applyCommonWrappers(limitedBox, properties, context);
  }
}