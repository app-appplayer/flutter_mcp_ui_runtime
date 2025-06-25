import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../../renderer/render_context.dart';

/// Factory for margin widget (implemented as Container with margin)
class MarginWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    final children = definition['children'] as List<dynamic>? ?? [];

    final margin = resolveEdgeInsets(properties['margin']) ??
        resolveEdgeInsets(properties['value']) ??
        const EdgeInsets.all(8.0);

    Widget child = children.isNotEmpty
        ? context.buildWidget(children.first as Map<String, dynamic>)
        : Container();

    return Container(
      margin: margin,
      child: child,
    );
  }
}
