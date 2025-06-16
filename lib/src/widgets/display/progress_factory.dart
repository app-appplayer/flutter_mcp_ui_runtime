import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../../renderer/render_context.dart';

/// Factory for generic progress indicator
class ProgressWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    final type = properties['indicatorType'] ?? 'circular';
    
    if (type == 'linear') {
      return LinearProgressIndicator(
        value: properties['value']?.toDouble(),
        backgroundColor: resolveColor(properties['backgroundColor']),
        valueColor: properties['color'] != null
            ? AlwaysStoppedAnimation<Color>(resolveColor(properties['color'])!)
            : null,
      );
    } else {
      return CircularProgressIndicator(
        value: properties['value']?.toDouble(),
        backgroundColor: resolveColor(properties['backgroundColor']),
        valueColor: properties['color'] != null
            ? AlwaysStoppedAnimation<Color>(resolveColor(properties['color'])!)
            : null,
        strokeWidth: properties['strokeWidth']?.toDouble() ?? 4.0,
      );
    }
  }
}

/// Factory for circular progress indicator
class CircularProgressWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    
    return CircularProgressIndicator(
      value: properties['value']?.toDouble(),
      backgroundColor: resolveColor(properties['backgroundColor']),
      valueColor: properties['color'] != null
          ? AlwaysStoppedAnimation<Color>(resolveColor(properties['color'])!)
          : null,
      strokeWidth: properties['strokeWidth']?.toDouble() ?? 4.0,
    );
  }
}

/// Factory for linear progress indicator
class LinearProgressWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    
    return LinearProgressIndicator(
      value: properties['value']?.toDouble(),
      backgroundColor: resolveColor(properties['backgroundColor']),
      valueColor: properties['color'] != null
          ? AlwaysStoppedAnimation<Color>(resolveColor(properties['color'])!)
          : null,
      minHeight: properties['minHeight']?.toDouble(),
    );
  }
}