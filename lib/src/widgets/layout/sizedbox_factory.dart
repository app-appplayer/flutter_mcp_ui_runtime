import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for SizedBox widgets
class SizedBoxWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);

    // Extract properties - use parseDimension for MCP UI DSL v1.0 compliance
    final width = parseDimension(properties['width']);
    final height = parseDimension(properties['height']);

    // Build child - check both properties and definition level
    final childrenData = properties['children'] as List<dynamic>? ??
        definition['children'] as List<dynamic>?;
    Widget? child;
    if (childrenData != null && childrenData.isNotEmpty) {
      child = context.renderer.renderWidget(childrenData.first, context);
    }

    Widget sizedBox = SizedBox(
      width: width,
      height: height,
      child: child,
    );

    return applyCommonWrappers(sizedBox, properties, context);
  }
}
