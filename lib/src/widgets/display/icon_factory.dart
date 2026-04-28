import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../../utils/icon_resolver.dart';
import '../widget_factory.dart';

/// Factory for Icon widgets (spec §2.5).
///
/// Three supported input shapes for the `icon` property:
///
///   1. A string name resolved through [resolveIconData]
///      (e.g. `"home"`, `"folder_open"`). Uses the bundled Material Icons
///      font — offline, zero-latency, tintable.
///   2. A codepoint object `{codepoint, fontFamily?, fontPackage?}` for any
///      Material Icons codepoint that isn't in the resolver map.
///      `{"codepoint": 0xe88a}` renders the same glyph as `"home"`.
///   3. An `http://` / `https://` URL pointing at a raster icon. The
///      runtime fetches via [Image.network], caches, and tints when the
///      color channel allows. SVG is not rendered natively.
class IconWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);

    final iconValue = context.resolve(properties['icon']);
    final size = parseDimension(context.resolve(properties['size'])) ?? 24.0;
    final color = parseColor(context.resolve(properties['color']), context);

    final widget = _buildIconWidget(iconValue, size, color);
    return applyCommonWrappers(widget, properties, context);
  }

  Widget _buildIconWidget(dynamic value, double size, Color? color) {
    if (value is String && _isHttpUrl(value)) {
      return SizedBox(
        width: size,
        height: size,
        child: Image.network(
          value,
          width: size,
          height: size,
          color: color,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            resolveIconData('broken_image'),
            size: size,
            color: color,
          ),
        ),
      );
    }

    return Icon(_resolveIconData(value), size: size, color: color);
  }

  IconData _resolveIconData(dynamic value) {
    if (value is String) return resolveIconData(value);
    if (value is Map<String, dynamic>) {
      final codepoint = value['codepoint'];
      if (codepoint is int) {
        return IconData(
          codepoint,
          fontFamily:
              (value['fontFamily'] as String?) ?? 'MaterialIcons',
          fontPackage: value['fontPackage'] as String?,
        );
      }
      final name = value['name'];
      if (name is String) return resolveIconData(name);
    }
    return resolveIconData('help_outline');
  }

  bool _isHttpUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }
}
