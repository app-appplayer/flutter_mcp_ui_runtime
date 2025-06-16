import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widget_factory.dart';
import '../../renderer/render_context.dart';

/// Factory for creating number input fields
class NumberFieldFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    
    // Extract properties
    final label = properties['label'] as String?;
    final binding = properties['binding'] as String?;
    final hint = properties['hint'] as String?;
    final helperText = context.resolve(properties['helperText']) as String?;
    final errorText = context.resolve(properties['errorText']) as String?;
    final suffix = properties['suffix'] as String?;
    final prefix = properties['prefix'] as String?;
    final min = properties['min'] as num?;
    final max = properties['max'] as num?;
    final step = properties['step'] as num? ?? 1;
    final decimals = properties['decimals'] as int? ?? 0;
    final enabled = context.resolve(properties['enabled'] ?? true) as bool;
    
    // Get current value
    final currentValue = binding != null 
        ? context.resolve("{{$binding}}")
        : properties['value'];
    
    // Create text controller with current value
    final controller = TextEditingController(
      text: currentValue?.toString() ?? '',
    );
    
    // Build input formatters
    final inputFormatters = <TextInputFormatter>[];
    
    // Add numeric formatter
    if (decimals > 0) {
      inputFormatters.add(
        FilteringTextInputFormatter.allow(RegExp(r'^\-?\d*\.?\d*$')),
      );
    } else {
      inputFormatters.add(
        FilteringTextInputFormatter.allow(RegExp(r'^\-?\d*$')),
      );
    }
    
    Widget textField = TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(
        decimal: decimals > 0,
        signed: min == null || min < 0,
      ),
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        errorText: errorText,
        suffixText: suffix,
        prefixText: prefix,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      enabled: enabled,
      onChanged: (value) {
        if (binding != null) {
          // Parse the number value
          num? numValue;
          if (value.isNotEmpty) {
            if (decimals > 0) {
              numValue = double.tryParse(value);
            } else {
              numValue = int.tryParse(value);
            }
          }
          
          // Validate against min/max
          if (numValue != null) {
            if (min != null && numValue < min) {
              numValue = min;
              controller.text = numValue.toString();
            }
            if (max != null && numValue > max) {
              numValue = max;
              controller.text = numValue.toString();
            }
          }
          
          // Update state
          context.setValue(binding, numValue ?? 0);
        }
      },
    );
    
    // Add increment/decrement buttons if step is defined
    if (step > 0) {
      textField = Row(
        children: [
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: enabled ? () {
              final current = num.tryParse(controller.text) ?? 0;
              final newValue = current - step;
              
              // Check bounds
              if (min == null || newValue >= min) {
                controller.text = decimals > 0 
                    ? newValue.toStringAsFixed(decimals)
                    : newValue.toStringAsFixed(0);
                if (binding != null) {
                  context.setValue(binding, newValue);
                }
              }
            } : null,
          ),
          Expanded(child: textField),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: enabled ? () {
              final current = num.tryParse(controller.text) ?? 0;
              final newValue = current + step;
              
              // Check bounds
              if (max == null || newValue <= max) {
                controller.text = decimals > 0 
                    ? newValue.toStringAsFixed(decimals)
                    : newValue.toStringAsFixed(0);
                if (binding != null) {
                  context.setValue(binding, newValue);
                }
              }
            } : null,
          ),
        ],
      );
    }
    
    return applyCommonWrappers(textField, properties, context);
  }
}