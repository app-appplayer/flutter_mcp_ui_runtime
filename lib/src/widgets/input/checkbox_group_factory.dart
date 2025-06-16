import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../../renderer/render_context.dart';

/// Factory for creating checkbox group widgets
class CheckboxGroupFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    
    // Extract properties
    final label = properties['label'] as String?;
    final options = properties['options'] as List<dynamic>? ?? [];
    final enabled = context.resolve(properties['enabled'] ?? true) as bool;
    final direction = properties['direction'] as String? ?? 'vertical';
    
    // Build checkboxes
    final checkboxes = options.map((option) {
      String value;
      String label;
      String? binding;
      
      if (option is Map<String, dynamic>) {
        value = option['value']?.toString() ?? '';
        label = option['label']?.toString() ?? value;
        binding = option['binding'] as String?;
      } else {
        value = option.toString();
        label = value;
        binding = null;
      }
      
      // Get current checked state
      final isChecked = binding != null 
          ? context.resolve("{{$binding}}") as bool? ?? false
          : false;
      
      return CheckboxListTile(
        title: Text(label),
        value: isChecked,
        onChanged: enabled && binding != null ? (newValue) {
          if (newValue != null && binding != null) {
            context.setValue(binding, newValue);
          }
        } : null,
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
      );
    }).toList();
    
    Widget checkboxGroup;
    if (direction == 'horizontal') {
      checkboxGroup = Row(
        mainAxisSize: MainAxisSize.min,
        children: checkboxes.map((checkbox) => 
          Flexible(child: checkbox)
        ).toList(),
      );
    } else {
      checkboxGroup = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: checkboxes,
      );
    }
    
    // Add label if provided
    if (label != null) {
      checkboxGroup = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          checkboxGroup,
        ],
      );
    }
    
    return applyCommonWrappers(checkboxGroup, properties, context);
  }
}