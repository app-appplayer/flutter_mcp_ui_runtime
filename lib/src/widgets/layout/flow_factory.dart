import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../../renderer/render_context.dart';

/// Factory for flow layout widget
class FlowWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    // final properties = extractProperties(definition); // TODO: Use properties for Flow configuration
    final children = definition['children'] as List<dynamic>? ?? [];
    
    return Flow(
      delegate: _SimpleFlowDelegate(),
      children: children
          .map((child) => context.buildWidget(child as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Simple flow delegate that arranges children in a row/column pattern
class _SimpleFlowDelegate extends FlowDelegate {
  @override
  void paintChildren(FlowPaintingContext context) {
    double x = 0;
    double y = 0;
    const double spacing = 8.0;
    
    for (int i = 0; i < context.childCount; i++) {
      final childSize = context.getChildSize(i) ?? Size.zero;
      
      // Simple layout: arrange children in a flow pattern
      if (x + childSize.width > context.size.width) {
        x = 0;
        y += childSize.height + spacing;
      }
      
      context.paintChild(i, transform: Matrix4.translationValues(x, y, 0));
      x += childSize.width + spacing;
    }
  }

  @override
  bool shouldRepaint(covariant FlowDelegate oldDelegate) => false;
}