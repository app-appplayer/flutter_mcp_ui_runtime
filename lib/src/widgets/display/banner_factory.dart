import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for Banner widgets
class BannerWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);

    // Extract properties
    final message =
        context.resolve<String>(properties['message']) as String? ?? '';
    final textDirection = _parseTextDirection(properties['textDirection']);
    final location =
        _parseBannerLocation(properties['location']) ?? BannerLocation.topEnd;
    final color = parseColor(context.resolve(properties['color'])) ??
        const Color(0xFFFF5252); // Default red
    final textStyle = _parseTextStyle(properties['textStyle'], context);
    final layoutDirection = _parseTextDirection(properties['layoutDirection']);

    // Extract child widget
    final childrenDef = properties['children'] as List<dynamic>? ??
        definition['children'] as List<dynamic>?;
    Widget? child;
    if (childrenDef != null && childrenDef.isNotEmpty) {
      child = context.buildWidget(childrenDef.first as Map<String, dynamic>);
    }

    Widget banner = Banner(
      message: message,
      textDirection: textDirection,
      location: location,
      color: color,
      textStyle: textStyle ??
          const TextStyle(
            color: Colors.white,
            fontSize: 12.0,
            fontWeight: FontWeight.bold,
          ),
      layoutDirection: layoutDirection,
      child: child ??
          Container(
            width: 100,
            height: 100,
            color: Colors.grey[300],
          ),
    );

    return applyCommonWrappers(banner, properties, context);
  }

  BannerLocation? _parseBannerLocation(String? value) {
    switch (value) {
      case 'topStart':
        return BannerLocation.topStart;
      case 'topEnd':
        return BannerLocation.topEnd;
      case 'bottomStart':
        return BannerLocation.bottomStart;
      case 'bottomEnd':
        return BannerLocation.bottomEnd;
      default:
        return null;
    }
  }

  TextDirection? _parseTextDirection(String? value) {
    switch (value) {
      case 'ltr':
        return TextDirection.ltr;
      case 'rtl':
        return TextDirection.rtl;
      default:
        return null;
    }
  }

  TextStyle? _parseTextStyle(dynamic style, RenderContext context) {
    if (style == null) return null;

    if (style is Map<String, dynamic>) {
      return TextStyle(
        color: parseColor(context.resolve(style['color'])),
        fontSize: style['fontSize']?.toDouble(),
        fontWeight: style['fontWeight'] == 'bold' ? FontWeight.bold : null,
      );
    }

    return null;
  }
}
