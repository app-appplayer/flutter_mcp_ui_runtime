import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for FittedBox widgets
class FittedBoxWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    
    // Extract properties
    final fit = _parseBoxFit(properties['fit']) ?? BoxFit.contain;
    final alignment = parseAlignment(properties['alignment']) ?? Alignment.center;
    final clipBehavior = _parseClip(properties['clipBehavior']) ?? Clip.none;
    
    // Extract child widget - check both properties and definition level
    final childrenDef = properties['children'] as List<dynamic>? ?? 
                       definition['children'] as List<dynamic>?;
    Widget? child;
    if (childrenDef != null && childrenDef.isNotEmpty) {
      child = context.buildWidget(childrenDef.first as Map<String, dynamic>);
    }
    
    Widget fittedBox = FittedBox(
      fit: fit,
      alignment: alignment,
      clipBehavior: clipBehavior,
      child: child,
    );
    
    return applyCommonWrappers(fittedBox, properties, context);
  }

  BoxFit? _parseBoxFit(String? value) {
    switch (value) {
      case 'fill':
        return BoxFit.fill;
      case 'contain':
        return BoxFit.contain;
      case 'cover':
        return BoxFit.cover;
      case 'fitWidth':
        return BoxFit.fitWidth;
      case 'fitHeight':
        return BoxFit.fitHeight;
      case 'none':
        return BoxFit.none;
      case 'scaleDown':
        return BoxFit.scaleDown;
      default:
        return null;
    }
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