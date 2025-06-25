import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../../renderer/render_context.dart';

/// Factory for creating conditional widgets
class ConditionalFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    // Get and evaluate condition
    final condition = definition['condition'];
    if (condition == null) {
      throw Exception('Conditional widget requires a condition property');
    }

    // Resolve the condition (handle bindings)
    final conditionResult = context.resolve<dynamic>(condition);
    final isTrue = _isTruthy(conditionResult);

    // Get then and else widgets
    final thenWidget = definition['then'];
    final elseWidget = definition['orElse'] ??
        definition['else']; // Support both 'orElse' (v1.0) and 'else'

    if (isTrue && thenWidget != null) {
      return context.renderer.renderWidget(thenWidget, context);
    } else if (!isTrue && elseWidget != null) {
      return context.renderer.renderWidget(elseWidget, context);
    }

    // Return empty container if no appropriate widget
    return const SizedBox.shrink();
  }

  /// Check if a value is truthy
  bool _isTruthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.isNotEmpty;
    if (value is List) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }
}
