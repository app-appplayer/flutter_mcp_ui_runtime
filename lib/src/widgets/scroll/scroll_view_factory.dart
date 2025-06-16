import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../../renderer/render_context.dart';

/// Factory for creating SingleChildScrollView widgets
class ScrollViewFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    
    // Get scroll direction
    final scrollDirectionStr = properties['scrollDirection'] as String?;
    final scrollDirection = scrollDirectionStr == 'horizontal' 
      ? Axis.horizontal 
      : Axis.vertical;
    
    // Get other properties
    final reverse = properties['reverse'] as bool? ?? false;
    final padding = parseEdgeInsets(properties['padding']);
    final primary = properties['primary'] as bool?;
    final physics = _parseScrollPhysics(properties['physics']);
    
    // Get child
    Widget? child;
    final childDef = properties['child'] as Map<String, dynamic>?;
    if (childDef != null) {
      child = context.renderer.renderWidget(childDef, context);
    }
    
    return SingleChildScrollView(
      scrollDirection: scrollDirection,
      reverse: reverse,
      padding: padding,
      primary: primary,
      physics: physics,
      child: child,
    );
  }
  
  ScrollPhysics? _parseScrollPhysics(String? value) {
    switch (value) {
      case 'never':
      case 'neverScrollable':
        return const NeverScrollableScrollPhysics();
      case 'always':
      case 'alwaysScrollable':
        return const AlwaysScrollableScrollPhysics();
      case 'bouncing':
        return const BouncingScrollPhysics();
      case 'clamping':
        return const ClampingScrollPhysics();
      default:
        return null;
    }
  }
}