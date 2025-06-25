import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../../renderer/render_context.dart';

/// Factory for creating date field widgets
class DateFieldFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);

    // Extract properties
    final label = properties['label'] as String?;
    final binding = properties['binding'] as String?;
    final errorText = context.resolve(properties['errorText']) as String?;
    final enabled = context.resolve(properties['enabled'] ?? true) as bool;

    // Parse date constraints
    final firstDateStr = properties['firstDate'] as String?;
    final lastDateStr = properties['lastDate'] as String?;

    DateTime? firstDate;
    DateTime? lastDate;

    try {
      if (firstDateStr != null) {
        firstDate = DateTime.parse(firstDateStr);
      }
      if (lastDateStr != null) {
        lastDate = DateTime.parse(lastDateStr);
      }
    } catch (e) {
      // Use defaults if parsing fails
    }

    firstDate ??= DateTime(1900);
    lastDate ??= DateTime(2100);

    // Get current value
    String? currentValue;
    if (binding != null) {
      final value = context.resolve("{{$binding}}");
      currentValue = value?.toString();
    }

    final controller = TextEditingController(text: currentValue ?? '');

    Widget dateField = GestureDetector(
      onTap: enabled
          ? () async {
              // Parse current date
              DateTime? initialDate;
              if (currentValue != null && currentValue.isNotEmpty) {
                try {
                  initialDate = DateTime.parse(currentValue);
                } catch (e) {
                  // Invalid date
                }
              }
              initialDate ??= DateTime.now();

              // Ensure initial date is within range
              if (initialDate.isBefore(firstDate!)) {
                initialDate = firstDate;
              } else if (initialDate.isAfter(lastDate!)) {
                initialDate = lastDate;
              }

              final pickedDate = await showDatePicker(
                context: context.buildContext!,
                initialDate: initialDate,
                firstDate: firstDate,
                lastDate: lastDate!,
              );

              if (pickedDate != null && binding != null) {
                final formattedDate =
                    "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                context.setValue(binding, formattedDate);
                controller.text = formattedDate;
              }
            }
          : null,
      child: AbsorbPointer(
        child: TextField(
          controller: controller,
          enabled: enabled,
          decoration: InputDecoration(
            labelText: label,
            errorText: errorText,
            suffixIcon: const Icon(Icons.calendar_today),
          ),
        ),
      ),
    );

    return applyCommonWrappers(dateField, properties, context);
  }
}
