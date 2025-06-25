import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../../renderer/render_context.dart';

/// Factory for creating date range picker widgets
class DateRangePickerFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);

    // Extract properties
    final label = properties['label'] as String?;
    final startBinding = properties['startBinding'] as String?;
    final endBinding = properties['endBinding'] as String?;
    final errorText = context.resolve(properties['errorText']) as String?;
    final enabled = context.resolve(properties['enabled'] ?? true) as bool;

    // Get current values
    String? startDate;
    String? endDate;

    if (startBinding != null) {
      final value = context.resolve("{{$startBinding}}");
      startDate = value?.toString();
    }

    if (endBinding != null) {
      final value = context.resolve("{{$endBinding}}");
      endDate = value?.toString();
    }

    final displayText = (startDate != null && endDate != null)
        ? "$startDate - $endDate"
        : "Select date range";

    Widget rangePicker = InkWell(
      onTap: enabled
          ? () async {
              // Parse current dates
              DateTime? initialStart;
              DateTime? initialEnd;

              try {
                if (startDate != null && startDate.isNotEmpty) {
                  initialStart = DateTime.parse(startDate);
                }
                if (endDate != null && endDate.isNotEmpty) {
                  initialEnd = DateTime.parse(endDate);
                }
              } catch (e) {
                // Invalid dates
              }

              final now = DateTime.now();
              initialStart ??= now;
              initialEnd ??= now.add(const Duration(days: 7));

              final pickedRange = await showDateRangePicker(
                context: context.buildContext!,
                firstDate: DateTime(1900),
                lastDate: DateTime(2100),
                initialDateRange: DateTimeRange(
                  start: initialStart,
                  end: initialEnd,
                ),
              );

              if (pickedRange != null) {
                final formattedStart =
                    "${pickedRange.start.year}-${pickedRange.start.month.toString().padLeft(2, '0')}-${pickedRange.start.day.toString().padLeft(2, '0')}";
                final formattedEnd =
                    "${pickedRange.end.year}-${pickedRange.end.month.toString().padLeft(2, '0')}-${pickedRange.end.day.toString().padLeft(2, '0')}";

                if (startBinding != null) {
                  context.setValue(startBinding, formattedStart);
                }
                if (endBinding != null) {
                  context.setValue(endBinding, formattedEnd);
                }
              }
            }
          : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          suffixIcon: const Icon(Icons.date_range),
          enabled: enabled,
        ),
        child: Text(displayText),
      ),
    );

    return applyCommonWrappers(rangePicker, properties, context);
  }
}
