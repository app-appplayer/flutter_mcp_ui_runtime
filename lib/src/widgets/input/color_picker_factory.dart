import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../../renderer/render_context.dart';

/// Factory for creating color picker widgets
class ColorPickerFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    
    // Extract properties
    final label = properties['label'] as String?;
    final binding = properties['binding'] as String?;
    final enabled = context.resolve(properties['enabled'] ?? true) as bool;
    
    // Get current color value
    final currentValue = binding != null 
        ? context.resolve("{{$binding}}")
        : properties['value'];
    
    // Parse current color
    Color currentColor = parseColor(currentValue) ?? Colors.blue;
    
    // Simple color picker implementation using preset colors
    final colors = [
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.lightBlue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lightGreen,
      Colors.lime,
      Colors.yellow,
      Colors.amber,
      Colors.orange,
      Colors.deepOrange,
      Colors.brown,
      Colors.grey,
      Colors.blueGrey,
      Colors.black,
    ];
    
    Widget colorPicker = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: colors.map((color) {
        final isSelected = currentColor.toString() == color.toString();
        return InkWell(
          onTap: enabled ? () {
            if (binding != null) {
              // Convert color to hex string
              final hexColor = '#${(color.r * 255).round().toRadixString(16).padLeft(2, '0')}${(color.g * 255).round().toRadixString(16).padLeft(2, '0')}${(color.b * 255).round().toRadixString(16).padLeft(2, '0')}'.toUpperCase();
              context.setValue(binding, hexColor);
            }
          } : null,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(
                color: isSelected ? Colors.black : Colors.grey[300]!,
                width: isSelected ? 3 : 1,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }).toList(),
    );
    
    // Add label if provided
    if (label != null) {
      colorPicker = Column(
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
          colorPicker,
        ],
      );
    }
    
    // Add opacity if disabled
    if (!enabled) {
      colorPicker = Opacity(
        opacity: 0.6,
        child: colorPicker,
      );
    }
    
    return applyCommonWrappers(colorPicker, properties, context);
  }
}