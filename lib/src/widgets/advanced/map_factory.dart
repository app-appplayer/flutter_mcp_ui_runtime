import 'package:flutter/material.dart';
import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for Map widgets (Advanced conformance level)
/// This is a placeholder implementation that displays a message
/// Real implementation would integrate with a mapping library
class MapWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);

    // Extract map properties
    final latitude = context.resolve<double?>(properties['latitude']) ?? 0.0;
    final longitude = context.resolve<double?>(properties['longitude']) ?? 0.0;
    final zoom = context.resolve<double?>(properties['zoom']) ?? 10.0;
    final markers = context.resolve<List<dynamic>>(properties['markers'] ?? []);
    final interactive =
        context.resolve<bool>(properties['interactive'] ?? true);
    final width = context.resolve<double?>(properties['width']);
    final height = context.resolve<double?>(properties['height']) ?? 400.0;

    // Build placeholder map widget
    Widget map = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade100,
      ),
      child: Stack(
        children: [
          // Map background
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.map,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Map Widget',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Zoom: ${zoom.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade400,
                  ),
                ),
                if (markers.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Markers: ${markers.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Interactive indicator
          if (!interactive)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Non-interactive',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return applyCommonWrappers(map, properties, context);
  }
}
