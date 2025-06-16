import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for Drawer widgets
class DrawerWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    
    // Extract properties
    final width = properties['width']?.toDouble();
    final elevation = properties['elevation']?.toDouble() ?? 16.0;
    final shadowColor = parseColor(context.resolve(properties['shadowColor']));
    final surfaceTintColor = parseColor(context.resolve(properties['surfaceTintColor']));
    final backgroundColor = parseColor(context.resolve(properties['backgroundColor']));
    final shape = _parseShapeBorder(properties['shape']);
    final semanticLabel = context.resolve<String?>(properties['semanticLabel']);
    
    // Build child widget - check both properties and definition level
    final childrenData = properties['children'] as List<dynamic>? ?? 
                        definition['children'] as List<dynamic>?;
    Widget? child;
    
    if (childrenData != null && childrenData.isNotEmpty) {
      if (childrenData.length == 1) {
        child = context.renderer.renderWidget(childrenData.first, context);
      } else {
        // Multiple children - wrap in Column
        final children = childrenData
            .map((child) => context.renderer.renderWidget(child, context))
            .toList();
        child = Column(
          children: children,
        );
      }
    }
    
    // Default drawer structure if no child provided
    child ??= Column(
      children: [
        DrawerHeader(
          decoration: BoxDecoration(
            color: Theme.of(context.buildContext!).primaryColor,
          ),
          child: const Text(
            'Menu',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
            ),
          ),
        ),
      ],
    );
    
    Widget drawer = Drawer(
      width: width,
      elevation: elevation,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      backgroundColor: backgroundColor,
      shape: shape,
      semanticLabel: semanticLabel,
      child: child,
    );
    
    return drawer;
  }

  ShapeBorder? _parseShapeBorder(Map<String, dynamic>? shape) {
    if (shape == null) return null;
    
    final type = shape['type'] as String?;
    switch (type) {
      case 'rounded':
        final radius = shape['radius']?.toDouble() ?? 8.0;
        final side = shape['onlyRight'] as bool? ?? false;
        return RoundedRectangleBorder(
          borderRadius: side
              ? BorderRadius.only(
                  topRight: Radius.circular(radius),
                  bottomRight: Radius.circular(radius),
                )
              : BorderRadius.circular(radius),
        );
      default:
        return null;
    }
  }
}