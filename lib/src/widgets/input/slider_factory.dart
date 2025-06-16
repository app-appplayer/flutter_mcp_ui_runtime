import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for Slider widgets
class SliderWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    
    // Extract properties
    final resolvedValue = context.resolve<num?>(properties['value']);
    final value = (resolvedValue ?? 0.0).toDouble();
    final min = properties['min']?.toDouble() ?? 0.0;
    final max = properties['max']?.toDouble() ?? 1.0;
    final divisions = properties['divisions'] as int?;
    final label = context.resolve<String?>(properties['label']);
    final activeColor = parseColor(context.resolve(properties['activeColor']));
    final inactiveColor = parseColor(context.resolve(properties['inactiveColor']));
    final thumbColor = parseColor(context.resolve(properties['thumbColor']));
    
    // Extract action handlers
    final onChange = properties['onChange'] as Map<String, dynamic>?;
    final onChangeStart = properties['onChangeStart'] as Map<String, dynamic>?;
    final onChangeEnd = properties['onChangeEnd'] as Map<String, dynamic>?;
    
    Widget slider = Slider(
      value: value.clamp(min, max).toDouble(),
      min: min,
      max: max,
      divisions: divisions,
      label: label,
      activeColor: activeColor,
      inactiveColor: inactiveColor,
      thumbColor: thumbColor,
      onChanged: (onChange != null || properties['bindTo'] != null) ? (newValue) {
        // Update state if bindTo is specified
        final path = properties['bindTo'] as String?;
        if (path != null) {
          context.setValue(path, newValue);
        }
        // Execute action if onChange is specified
        if (onChange != null) {
          final eventData = Map<String, dynamic>.from(onChange);
          if (eventData['value'] == '{{event.value}}') {
            eventData['value'] = newValue;
          }
          context.actionHandler.execute(eventData, context);
        }
      } : null,
      onChangeStart: onChangeStart != null ? (value) {
        final eventData = Map<String, dynamic>.from(onChangeStart);
        if (eventData['value'] == '{{event.value}}') {
          eventData['value'] = value;
        }
        context.actionHandler.execute(eventData, context);
      } : null,
      onChangeEnd: onChangeEnd != null ? (value) {
        final eventData = Map<String, dynamic>.from(onChangeEnd);
        if (eventData['value'] == '{{event.value}}') {
          eventData['value'] = value;
        }
        context.actionHandler.execute(eventData, context);
      } : null,
    );
    
    return applyCommonWrappers(slider, properties, context);
  }
}