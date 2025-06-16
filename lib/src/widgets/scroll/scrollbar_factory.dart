import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../../renderer/render_context.dart';

/// Factory for scrollbar widget
class ScrollbarWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    final children = definition['children'] as List<dynamic>? ?? [];
    
    Widget child = children.isNotEmpty
        ? context.buildWidget(children.first as Map<String, dynamic>)
        : Container();
    
    return Scrollbar(
      thumbVisibility: properties['thumbVisibility'] ?? false,
      trackVisibility: properties['trackVisibility'] ?? false,
      thickness: properties['thickness']?.toDouble(),
      radius: properties['radius'] != null 
          ? Radius.circular(properties['radius'].toDouble())
          : null,
      child: child,
    );
  }
}