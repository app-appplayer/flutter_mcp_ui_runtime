import 'package:flutter/material.dart';
import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for Chart widgets (Advanced conformance level)
/// This is a placeholder implementation that displays a message
/// Real implementation would integrate with a charting library
class ChartWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    
    // Extract chart properties
    final chartType = context.resolve<String>(properties['chartType'] ?? 'line');
    final data = context.resolve<List<dynamic>>(properties['data'] ?? []);
    final title = context.resolve<String?>(properties['title']);
    final width = context.resolve<double?>(properties['width']);
    final height = context.resolve<double?>(properties['height']) ?? 300.0;
    
    // Build placeholder chart widget
    Widget chart = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getChartIcon(chartType),
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Chart Widget',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Type: $chartType',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            if (title != null) ...[
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Data points: ${data.length}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
    
    return applyCommonWrappers(chart, properties, context);
  }
  
  IconData _getChartIcon(String chartType) {
    switch (chartType.toLowerCase()) {
      case 'bar':
        return Icons.bar_chart;
      case 'line':
        return Icons.show_chart;
      case 'pie':
        return Icons.pie_chart;
      case 'scatter':
        return Icons.scatter_plot;
      case 'area':
        return Icons.area_chart;
      case 'radar':
        return Icons.radar;
      case 'bubble':
        return Icons.bubble_chart;
      default:
        return Icons.insert_chart;
    }
  }
}