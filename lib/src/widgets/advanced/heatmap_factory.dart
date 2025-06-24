import 'package:flutter/material.dart';
import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for Heatmap widgets
class HeatmapWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    
    // Extract properties
    final data = context.resolve<List<dynamic>>(properties['data']) as List<dynamic>? ?? [];
    final rows = properties['rows'] as int? ?? data.length;
    final columns = properties['columns'] as int?;
    final cellSize = properties['cellSize']?.toDouble() ?? 40.0;
    final cellGap = properties['cellGap']?.toDouble() ?? 2.0;
    final minValue = properties['minValue']?.toDouble() ?? 0.0;
    final maxValue = properties['maxValue']?.toDouble() ?? 100.0;
    final showLabels = properties['showLabels'] as bool? ?? false;
    final rowLabels = context.resolve<List<dynamic>>(properties['rowLabels']) as List<dynamic>? ?? [];
    final columnLabels = context.resolve<List<dynamic>>(properties['columnLabels']) as List<dynamic>? ?? [];
    final colorScheme = properties['colorScheme'] as String? ?? 'blue';
    
    // Parse data into 2D array
    List<List<double>> heatmapData = [];
    if (data.isNotEmpty && data.first is List) {
      // Data is already 2D
      for (var row in data) {
        if (row is List) {
          heatmapData.add(row.map((e) => (e as num).toDouble()).toList());
        }
      }
    } else if (columns != null && columns > 0) {
      // Convert 1D array to 2D based on columns
      for (int i = 0; i < data.length; i += columns) {
        final row = <double>[];
        for (int j = 0; j < columns && i + j < data.length; j++) {
          row.add((data[i + j] as num).toDouble());
        }
        heatmapData.add(row);
      }
    }
    
    if (heatmapData.isEmpty) {
      return const SizedBox();
    }
    
    final actualColumns = heatmapData.first.length;
    
    // Build heatmap
    final List<Widget> heatmapRows = [];
    
    // Add column labels if specified
    if (showLabels && columnLabels.isNotEmpty) {
      final List<Widget> labelRow = [
        if (showLabels && rowLabels.isNotEmpty) SizedBox(width: cellSize + cellGap),
      ];
      for (int i = 0; i < actualColumns && i < columnLabels.length; i++) {
        labelRow.add(
          SizedBox(
            width: cellSize,
            height: cellSize * 0.5,
            child: Center(
              child: Text(
                columnLabels[i].toString(),
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
        if (i < actualColumns - 1) {
          labelRow.add(SizedBox(width: cellGap));
        }
      }
      heatmapRows.add(Row(children: labelRow));
      heatmapRows.add(SizedBox(height: cellGap));
    }
    
    // Add data rows
    for (int i = 0; i < heatmapData.length; i++) {
      final List<Widget> rowWidgets = [];
      
      // Add row label if specified
      if (showLabels && i < rowLabels.length) {
        rowWidgets.add(
          SizedBox(
            width: cellSize,
            height: cellSize,
            child: Center(
              child: Text(
                rowLabels[i].toString(),
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
        rowWidgets.add(SizedBox(width: cellGap));
      }
      
      // Add cells
      for (int j = 0; j < heatmapData[i].length; j++) {
        final value = heatmapData[i][j];
        final normalizedValue = ((value - minValue) / (maxValue - minValue)).clamp(0.0, 1.0);
        final color = _getColorForValue(normalizedValue, colorScheme);
        
        rowWidgets.add(
          Container(
            width: cellSize,
            height: cellSize,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                value.toStringAsFixed(0),
                style: TextStyle(
                  color: normalizedValue > 0.5 ? Colors.white : Colors.black,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        );
        
        if (j < heatmapData[i].length - 1) {
          rowWidgets.add(SizedBox(width: cellGap));
        }
      }
      
      heatmapRows.add(Row(children: rowWidgets));
      if (i < heatmapData.length - 1) {
        heatmapRows.add(SizedBox(height: cellGap));
      }
    }
    
    Widget heatmap = Column(
      mainAxisSize: MainAxisSize.min,
      children: heatmapRows,
    );
    
    return applyCommonWrappers(heatmap, properties, context);
  }
  
  Color _getColorForValue(double value, String colorScheme) {
    switch (colorScheme) {
      case 'red':
        return Color.lerp(Colors.red[50], Colors.red[900], value) ?? Colors.red;
      case 'green':
        return Color.lerp(Colors.green[50], Colors.green[900], value) ?? Colors.green;
      case 'blue':
        return Color.lerp(Colors.blue[50], Colors.blue[900], value) ?? Colors.blue;
      case 'purple':
        return Color.lerp(Colors.purple[50], Colors.purple[900], value) ?? Colors.purple;
      case 'orange':
        return Color.lerp(Colors.orange[50], Colors.orange[900], value) ?? Colors.orange;
      case 'grayscale':
        return Color.lerp(Colors.grey[200], Colors.grey[900], value) ?? Colors.grey;
      default:
        return Color.lerp(Colors.blue[50], Colors.blue[900], value) ?? Colors.blue;
    }
  }
}