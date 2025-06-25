import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for Visibility widgets
class VisibilityWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);

    // Extract properties
    final visible = context.resolve<bool>(properties['visible'] ?? true);
    final maintainState = properties['maintainState'] as bool? ?? false;
    final maintainAnimation = properties['maintainAnimation'] as bool? ?? false;
    final maintainSize = properties['maintainSize'] as bool? ?? false;
    final maintainSemantics = properties['maintainSemantics'] as bool? ?? false;
    final maintainInteractivity =
        properties['maintainInteractivity'] as bool? ?? false;

    // Extract child
    final childrenData = definition['children'] as List<dynamic>?;
    Widget child = Container();
    if (childrenData != null && childrenData.isNotEmpty) {
      child = context.renderer.renderWidget(childrenData.first, context);
    }

    // Extract replacement widget
    Widget replacement = const SizedBox.shrink();
    if (properties['replacement'] != null &&
        properties['replacement'] is Map<String, dynamic>) {
      replacement =
          context.renderer.renderWidget(properties['replacement'], context);
    }

    return Visibility(
      visible: visible,
      maintainState: maintainState,
      maintainAnimation: maintainAnimation,
      maintainSize: maintainSize,
      maintainSemantics: maintainSemantics,
      maintainInteractivity: maintainInteractivity,
      replacement: replacement,
      child: child,
    );
  }
}
