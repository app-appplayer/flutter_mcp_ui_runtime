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
    
    // Extract action handlers - MCP UI DSL v1.0 spec
    final changeAction = properties['change'] as Map<String, dynamic>?;
    final changeStartAction = properties['changeStart'] as Map<String, dynamic>?;
    final changeEndAction = properties['changeEnd'] as Map<String, dynamic>?;
    
    Widget slider = Slider(
      value: value.clamp(min, max).toDouble(),
      min: min,
      max: max,
      divisions: divisions,
      label: label,
      activeColor: activeColor,
      inactiveColor: inactiveColor,
      thumbColor: thumbColor,
      onChanged: (changeAction != null || properties['binding'] != null) ? (newValue) {
        // Update state if binding is specified
        final path = properties['binding'] as String?;
        if (path != null) {
          context.setValue(path, newValue);
        }
        // Execute action if change is specified
        if (changeAction != null) {
          // Create a child context with event data
          final eventContext = context.createChildContext(
            variables: {
              'event': {
                'value': newValue,
                'type': 'change',
              },
            },
          );
          eventContext.handleAction(changeAction);
        }
      } : null,
      onChangeStart: changeStartAction != null ? (value) {
        // Create a child context with event data
        final eventContext = context.createChildContext(
          variables: {
            'event': {
              'value': value,
              'type': 'changeStart',
            },
          },
        );
        eventContext.handleAction(changeStartAction);
      } : null,
      onChangeEnd: changeEndAction != null ? (value) {
        // Create a child context with event data
        final eventContext = context.createChildContext(
          variables: {
            'event': {
              'value': value,
              'type': 'changeEnd',
            },
          },
        );
        eventContext.handleAction(changeEndAction);
      } : null,
    );
    
    return applyCommonWrappers(slider, properties, context);
  }
}