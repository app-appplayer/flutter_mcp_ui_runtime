import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for ClipRRect widgets
class ClipRRectWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    
    // Extract properties
    final borderRadius = _parseBorderRadius(properties['borderRadius']) ?? 
                        BorderRadius.zero;
    final clipBehavior = _parseClip(properties['clipBehavior']) ?? Clip.antiAlias;
    
    // Extract child widget
    final childrenDef = properties['children'] as List<dynamic>? ?? 
                       definition['children'] as List<dynamic>?;
    Widget? child;
    if (childrenDef != null && childrenDef.isNotEmpty) {
      child = context.buildWidget(childrenDef.first as Map<String, dynamic>);
    }
    
    Widget clipRRect = ClipRRect(
      borderRadius: borderRadius,
      clipBehavior: clipBehavior,
      child: child,
    );
    
    return applyCommonWrappers(clipRRect, properties, context);
  }

  BorderRadius? _parseBorderRadius(dynamic value) {
    if (value == null) return null;
    
    if (value is num) {
      return BorderRadius.circular(value.toDouble());
    }
    
    if (value is Map<String, dynamic>) {
      if (value.containsKey('all')) {
        return BorderRadius.circular(value['all'].toDouble());
      }
      
      return BorderRadius.only(
        topLeft: Radius.circular(value['topLeft']?.toDouble() ?? 0),
        topRight: Radius.circular(value['topRight']?.toDouble() ?? 0),
        bottomLeft: Radius.circular(value['bottomLeft']?.toDouble() ?? 0),
        bottomRight: Radius.circular(value['bottomRight']?.toDouble() ?? 0),
      );
    }
    
    return null;
  }

  Clip? _parseClip(String? value) {
    switch (value) {
      case 'none':
        return Clip.none;
      case 'hardEdge':
        return Clip.hardEdge;
      case 'antiAlias':
        return Clip.antiAlias;
      case 'antiAliasWithSaveLayer':
        return Clip.antiAliasWithSaveLayer;
      default:
        return null;
    }
  }
}