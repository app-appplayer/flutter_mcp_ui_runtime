import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for Checkbox widgets
class CheckboxWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    
    // Extract properties
    final value = context.resolve<bool>(properties['value'] ?? false);
    final label = properties['label'] as String?;
    final enabled = properties['enabled'] as bool? ?? true;
    final tristate = properties['tristate'] as bool? ?? false;
    // MCP UI DSL v1.0 spec
    final onChange = properties['change'] as Map<String, dynamic>?;
    
    // Build checkbox
    Widget checkbox = Checkbox(
      value: value,
      tristate: tristate,
      onChanged: enabled && onChange != null ? (newValue) {
        // Update state if binding is specified
        final path = properties['binding'] as String? ?? properties['bindTo'] as String?;
        if (path != null) {
          context.setValue(path, newValue);
        }
        // Create event context with event.value
        final eventContext = context.createChildContext(
          variables: {
            'event': {
              'value': newValue,
              'type': 'change',
            },
          },
        );
        context.actionHandler.execute(onChange, eventContext);
      } : null,
    );
    
    // If label is provided, wrap in CheckboxListTile or Row
    if (label != null) {
      checkbox = CheckboxListTile(
        value: value,
        title: Text(label),
        tristate: tristate,
        onChanged: enabled && onChange != null ? (newValue) {
          // Update state if binding is specified
          final path = properties['binding'] as String? ?? properties['bindTo'] as String?;
          if (path != null) {
            context.setValue(path, newValue);
          }
          // Create event context with event.value
          final eventContext = context.createChildContext(
            variables: {
              'event': {
                'value': newValue,
                'type': 'change',
              },
            },
          );
          context.actionHandler.execute(onChange, eventContext);
        } : null,
      );
    }
    
    return applyCommonWrappers(checkbox, properties, context);
  }
}