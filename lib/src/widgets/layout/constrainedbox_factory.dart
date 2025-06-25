import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for ConstrainedBox widgets
class ConstrainedBoxWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);

    // Extract constraints
    final constraints =
        parseConstraints(properties['constraints']) ?? const BoxConstraints();

    // Extract child widget - check both properties and definition level
    final childrenDef = properties['children'] as List<dynamic>? ??
        definition['children'] as List<dynamic>?;
    Widget? child;
    if (childrenDef != null && childrenDef.isNotEmpty) {
      child = context.buildWidget(childrenDef.first as Map<String, dynamic>);
    }

    Widget constrainedBox = ConstrainedBox(
      constraints: constraints,
      child: child ?? const SizedBox.shrink(),
    );

    return applyCommonWrappers(constrainedBox, properties, context);
  }
}
