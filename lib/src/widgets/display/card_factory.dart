import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for Card widgets
class CardWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    
    // Extract properties
    final elevation = properties['elevation']?.toDouble() ?? 1.0;
    final shadowColor = parseColor(context.resolve(properties['shadowColor']));
    final surfaceTintColor = parseColor(context.resolve(properties['surfaceTintColor']));
    final color = parseColor(context.resolve(properties['color']));
    final shape = _parseShape(properties['shape']);
    final clipBehavior = _parseClipBehavior(properties['clipBehavior']);
    final semanticContainer = properties['semanticContainer'] as bool? ?? true;
    
    // Extract margin (external spacing)
    final margin = parseEdgeInsets(properties['margin']);
    
    // Card is a single-child widget, so child should be in properties
    Widget? child;
    final childDef = properties['child'] as Map<String, dynamic>?;
    if (childDef != null) {
      child = context.renderer.renderWidget(childDef, context);
    }
    
    Widget card = Card(
      elevation: elevation,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      color: color,
      shape: shape,
      clipBehavior: clipBehavior,
      margin: margin,
      semanticContainer: semanticContainer,
      child: child,
    );
    
    return applyCommonWrappers(card, properties, context);
  }

  ShapeBorder? _parseShape(Map<String, dynamic>? shape) {
    if (shape == null) return null;
    
    final type = shape['type'] as String?;
    switch (type) {
      case 'rounded':
        final radius = shape['radius']?.toDouble() ?? 8.0;
        return RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        );
      case 'circle':
        return const CircleBorder();
      case 'stadium':
        return const StadiumBorder();
      case 'continuous':
        final radius = shape['radius']?.toDouble() ?? 8.0;
        return ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        );
      default:
        return null;
    }
  }

  Clip _parseClipBehavior(String? value) {
    switch (value) {
      case 'antiAlias':
        return Clip.antiAlias;
      case 'antiAliasWithSaveLayer':
        return Clip.antiAliasWithSaveLayer;
      case 'hardEdge':
        return Clip.hardEdge;
      case 'none':
        return Clip.none;
      default:
        return Clip.none;
    }
  }
}