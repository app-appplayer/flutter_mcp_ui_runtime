import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../../renderer/render_context.dart';

/// Factory for creating time field widgets
class TimeFieldFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);

    // Extract properties
    final label = properties['label'] as String?;
    final binding = properties['binding'] as String?;
    final errorText = context.resolve(properties['errorText']) as String?;
    final enabled = context.resolve(properties['enabled'] ?? true) as bool;
    final use24HourFormat = properties['use24HourFormat'] as bool? ?? false;

    // Get current value
    String? currentValue;
    if (binding != null) {
      final value = context.resolve("{{$binding}}");
      currentValue = value?.toString();
    }

    final controller = TextEditingController(text: currentValue ?? '');

    Widget timeField = GestureDetector(
      onTap: enabled
          ? () async {
              // Parse current time
              TimeOfDay? initialTime;
              if (currentValue != null && currentValue.isNotEmpty) {
                try {
                  final parts = currentValue.split(':');
                  if (parts.length >= 2) {
                    final hour = int.parse(parts[0]);
                    final minute = int.parse(parts[1]);
                    initialTime = TimeOfDay(hour: hour, minute: minute);
                  }
                } catch (e) {
                  // Invalid time
                }
              }
              initialTime ??= TimeOfDay.now();

              final pickedTime = await showTimePicker(
                context: context.buildContext!,
                initialTime: initialTime,
                builder: (context, child) {
                  if (!use24HourFormat) return child!;

                  return MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(alwaysUse24HourFormat: true),
                    child: child!,
                  );
                },
              );

              if (pickedTime != null && binding != null) {
                final formattedTime =
                    "${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}";
                context.setValue(binding, formattedTime);
                controller.text = formattedTime;
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
            suffixIcon: const Icon(Icons.access_time),
          ),
        ),
      ),
    );

    return applyCommonWrappers(timeField, properties, context);
  }
}
