import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../../renderer/render_context.dart';

/// Factory for visibility widget
class VisibilityWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    final children = definition['children'] as List<dynamic>? ?? [];
    
    Widget child = children.isNotEmpty
        ? context.buildWidget(children.first as Map<String, dynamic>)
        : Container();
    
    return Visibility(
      visible: properties['visible'] == true,
      maintainSize: properties['maintainSize'] == true,
      maintainAnimation: properties['maintainAnimation'] == true,
      maintainState: properties['maintainState'] == true,
      maintainInteractivity: properties['maintainInteractivity'] == true,
      replacement: _buildReplacement(properties['replacement'], context),
      child: child,
    );
  }
  
  Widget _buildReplacement(dynamic replacement, RenderContext context) {
    if (replacement is Map<String, dynamic>) {
      return context.buildWidget(replacement);
    }
    return const SizedBox.shrink();
  }
}