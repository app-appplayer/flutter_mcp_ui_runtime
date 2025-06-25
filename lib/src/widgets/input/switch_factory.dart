import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for Switch widgets
class SwitchWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);

    // Extract properties
    final value = context.resolve<bool>(properties['value'] ?? false);
    final label = properties['label'] as String?;
    final enabled = properties['enabled'] as bool? ?? true;
    final onChange = properties['change'] as Map<String, dynamic>?;

    // Build switch
    Widget switchWidget = Switch(
      value: value,
      onChanged: enabled && onChange != null
          ? (newValue) async {
              // Create event context with event.value
              final eventContext = context.createChildContext(
                variables: {
                  'event': {
                    'value': newValue,
                    'type': 'change',
                  },
                },
              );
              // Execute the change action with the event context
              await context.actionHandler.execute(onChange, eventContext);
            }
          : null,
    );

    // If label is provided, wrap in SwitchListTile or Row
    if (label != null) {
      switchWidget = SwitchListTile(
        value: value,
        title: Text(label),
        onChanged: enabled && onChange != null
            ? (newValue) async {
                // Create event context with event.value
                final eventContext = context.createChildContext(
                  variables: {
                    'event': {
                      'value': newValue,
                      'type': 'change',
                    },
                  },
                );
                // Execute the change action with the event context
                await context.actionHandler.execute(onChange, eventContext);
              }
            : null,
      );
    }

    return applyCommonWrappers(switchWidget, properties, context);
  }
}
