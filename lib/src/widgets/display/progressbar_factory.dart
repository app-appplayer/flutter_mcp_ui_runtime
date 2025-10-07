import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for ProgressBar (LinearProgressIndicator and CircularProgressIndicator) widgets
class ProgressBarWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);

    // Extract properties
    final resolvedValue = context.resolve<num?>(properties['value']);
    final value = parseDimension(resolvedValue);
    final backgroundColor =
        parseColor(context.resolve(properties['backgroundColor']));
    final color = parseColor(context.resolve(properties['color']));
    final valueColor =
        color != null ? AlwaysStoppedAnimation<Color>(color) : null;
    final minHeight = parseDimension(properties['minHeight']);
    final semanticsLabel =
        context.resolve<String?>(properties['semanticsLabel']);
    final semanticsValue =
        context.resolve<String?>(properties['semanticsValue']);

    // Determine type
    final type = properties['type'] as String? ?? 'linear';

    Widget progressBar;

    if (type == 'circular') {
      final strokeWidth = parseDimension(properties['strokeWidth']) ?? 4.0;
      final size = parseDimension(properties['size']) ?? 36.0;

      progressBar = SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          value: value,
          backgroundColor: backgroundColor,
          valueColor: valueColor,
          strokeWidth: strokeWidth,
          semanticsLabel: semanticsLabel,
          semanticsValue: semanticsValue,
        ),
      );
    } else {
      // Linear progress indicator
      progressBar = LinearProgressIndicator(
        value: value,
        backgroundColor: backgroundColor,
        valueColor: valueColor,
        minHeight: minHeight,
        semanticsLabel: semanticsLabel,
        semanticsValue: semanticsValue,
      );
    }

    return applyCommonWrappers(progressBar, properties, context);
  }
}
