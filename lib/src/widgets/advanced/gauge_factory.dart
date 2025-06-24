import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for Gauge widgets
class GaugeWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    
    // Extract properties
    final value = context.resolve<num>(properties['value'] ?? 0).toDouble();
    final minValue = properties['min']?.toDouble() ?? 0.0;
    final maxValue = properties['max']?.toDouble() ?? 100.0;
    final size = properties['size']?.toDouble() ?? 200.0;
    final strokeWidth = properties['strokeWidth']?.toDouble() ?? 10.0;
    final backgroundColor = parseColor(context.resolve(properties['backgroundColor'])) ?? Colors.grey[300]!;
    final valueColor = parseColor(context.resolve(properties['valueColor'])) ?? Colors.blue;
    final showLabel = properties['showLabel'] as bool? ?? true;
    final labelFormat = properties['labelFormat'] as String? ?? '{value}%';
    final startAngle = properties['startAngle']?.toDouble() ?? -220.0;
    final sweepAngle = properties['sweepAngle']?.toDouble() ?? 260.0;
    
    // Calculate normalized value
    final normalizedValue = ((value - minValue) / (maxValue - minValue)).clamp(0.0, 1.0);
    
    Widget gauge = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GaugePainter(
          value: normalizedValue,
          backgroundColor: backgroundColor,
          valueColor: valueColor,
          strokeWidth: strokeWidth,
          startAngle: startAngle,
          sweepAngle: sweepAngle,
        ),
        child: showLabel
            ? Center(
                child: Text(
                  labelFormat.replaceAll('{value}', value.toStringAsFixed(0)),
                  style: TextStyle(
                    fontSize: size * 0.15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
      ),
    );
    
    return applyCommonWrappers(gauge, properties, context);
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final Color backgroundColor;
  final Color valueColor;
  final double strokeWidth;
  final double startAngle;
  final double sweepAngle;
  
  _GaugePainter({
    required this.value,
    required this.backgroundColor,
    required this.valueColor,
    required this.strokeWidth,
    required this.startAngle,
    required this.sweepAngle,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2;
    
    // Draw background arc
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _degreesToRadians(startAngle),
      _degreesToRadians(sweepAngle),
      false,
      backgroundPaint,
    );
    
    // Draw value arc
    final valuePaint = Paint()
      ..color = valueColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _degreesToRadians(startAngle),
      _degreesToRadians(sweepAngle * value),
      false,
      valuePaint,
    );
  }
  
  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
  
  @override
  bool shouldRepaint(_GaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.valueColor != valueColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}