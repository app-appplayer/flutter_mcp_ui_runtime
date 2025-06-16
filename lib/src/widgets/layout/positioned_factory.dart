import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for Positioned widgets
class PositionedWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    
    // Extract properties
    final left = properties['left']?.toDouble();
    final top = properties['top']?.toDouble();
    final right = properties['right']?.toDouble();
    final bottom = properties['bottom']?.toDouble();
    final width = properties['width']?.toDouble();
    final height = properties['height']?.toDouble();
    
    // Extract child
    final childData = definition['child'];
    Widget child = Container();
    if (childData != null) {
      child = context.renderer.renderWidget(childData, context);
    }
    
    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      width: width,
      height: height,
      child: child,
    );
  }
}