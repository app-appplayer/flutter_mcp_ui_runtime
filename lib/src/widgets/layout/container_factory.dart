import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart' as core;

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for Container widgets
class ContainerWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);

    // Container is a single-child widget, so child should be in properties
    Widget? child;
    final childDef = properties['child'] as Map<String, dynamic>?;
    if (childDef != null) {
      child = context.buildWidget(childDef);
    }

    // Resolve properties that might contain bindings
    final padding =
        _resolveEdgeInsets(properties[core.PropertyKeys.padding], context);
    final margin =
        _resolveEdgeInsets(properties[core.PropertyKeys.margin], context);
    // Use parseDimension to support MCP UI DSL v1.0 format
    final width =
        parseDimension(context.resolve(properties[core.PropertyKeys.width]));
    final height =
        parseDimension(context.resolve(properties[core.PropertyKeys.height]));

    // Check for direct color and borderRadius properties (not in decoration)
    // Support both 'color' and 'backgroundColor' for v1.0 spec
    final directColor =
        properties[core.PropertyKeys.color] ?? properties['backgroundColor'];
    final directBorderRadius = properties[core.PropertyKeys.borderRadius];
    final directBorder = properties[core.PropertyKeys.border];
    // MCP UI DSL v1.0 spec uses 'shadow' property
    final directBoxShadow = properties['shadow'];

    BoxDecoration? decoration;
    if (properties[core.PropertyKeys.decoration] != null) {
      decoration =
          _parseDecoration(properties[core.PropertyKeys.decoration], context);
    } else if (directColor != null ||
        directBorderRadius != null ||
        directBorder != null ||
        directBoxShadow != null) {
      // Build decoration from direct properties
      decoration = BoxDecoration(
        color: parseColor(context.resolve(directColor), context),
        borderRadius: _parseBorderRadius(context.resolve(directBorderRadius)),
        border: _parseBorder(directBorder, context),
        boxShadow: _parseBoxShadow(directBoxShadow, context),
      );
    }

    // Build container
    Widget container = Container(
      padding: padding,
      margin: margin,
      width: width,
      height: height,
      constraints: parseConstraints(properties['constraints']),
      decoration: decoration,
      alignment: parseAlignment(properties[core.PropertyKeys.alignment]),
      child: child,
    );

    return applyCommonWrappers(container, properties, context);
  }

  BoxDecoration? _parseDecoration(dynamic decoration, RenderContext context) {
    if (decoration == null) return null;

    if (decoration is Map<String, dynamic>) {
      // BoxDecoration treats `color` and `gradient` as mutually exclusive
      // (sets gradient win); honour the same rule by skipping `color`
      // resolution when a gradient is declared.
      final gradient = _parseGradient(decoration['gradient'], context);
      return BoxDecoration(
        color: gradient != null
            ? null
            : parseColor(
                context.resolve(decoration[core.PropertyKeys.color]), context),
        gradient: gradient,
        borderRadius:
            _parseBorderRadius(decoration[core.PropertyKeys.borderRadius]),
        border: _parseBorder(decoration[core.PropertyKeys.border], context),
        boxShadow:
            _parseBoxShadow(decoration[core.PropertyKeys.shadow], context),
      );
    }

    return null;
  }

  /// Parse a `LinearGradient` / `RadialGradient` / `SweepGradient`
  /// declaration. Each `colors[]` entry may be a hex string OR a
  /// semantic theme slot (`primary`, `surfaceContainer`, …) — slot names
  /// resolve through the same `parseColor` chain widget properties use.
  Gradient? _parseGradient(dynamic value, RenderContext context) {
    if (value is! Map<String, dynamic>) return null;

    final colorsRaw = value['colors'];
    if (colorsRaw is! List || colorsRaw.length < 2) return null;
    final colors = <Color>[];
    for (final c in colorsRaw) {
      final parsed = parseColor(context.resolve(c), context);
      if (parsed == null) return null;
      colors.add(parsed);
    }

    final stops = (value['stops'] is List)
        ? (value['stops'] as List)
            .map((e) => (e as num).toDouble())
            .toList(growable: false)
        : null;

    final type = (value['type'] as String?) ?? 'linear';
    switch (type) {
      case 'linear':
        return LinearGradient(
          colors: colors,
          stops: stops,
          begin: _parseAlignment(value['begin']) ?? Alignment.centerLeft,
          end: _parseAlignment(value['end']) ?? Alignment.centerRight,
        );
      case 'radial':
        return RadialGradient(
          colors: colors,
          stops: stops,
          center: _parseAlignment(value['center']) ?? Alignment.center,
          radius: (value['radius'] as num?)?.toDouble() ?? 0.5,
        );
      case 'sweep':
        return SweepGradient(
          colors: colors,
          stops: stops,
          center: _parseAlignment(value['center']) ?? Alignment.center,
          startAngle:
              (value['startAngle'] as num?)?.toDouble() ?? 0.0,
          endAngle:
              (value['endAngle'] as num?)?.toDouble() ?? 6.283185307179586,
        );
    }
    return null;
  }

  Alignment? _parseAlignment(dynamic value) {
    if (value is! String) return null;
    switch (value) {
      case 'topLeft':
      case 'topStart':
        return Alignment.topLeft;
      case 'topCenter':
        return Alignment.topCenter;
      case 'topRight':
      case 'topEnd':
        return Alignment.topRight;
      case 'centerLeft':
      case 'centerStart':
        return Alignment.centerLeft;
      case 'center':
        return Alignment.center;
      case 'centerRight':
      case 'centerEnd':
        return Alignment.centerRight;
      case 'bottomLeft':
      case 'bottomStart':
        return Alignment.bottomLeft;
      case 'bottomCenter':
        return Alignment.bottomCenter;
      case 'bottomRight':
      case 'bottomEnd':
        return Alignment.bottomRight;
    }
    return null;
  }

  BorderRadius? _parseBorderRadius(dynamic value) {
    if (value == null) return null;

    if (value is num) {
      return BorderRadius.circular(value.toDouble());
    }

    if (value is Map<String, dynamic>) {
      return BorderRadius.only(
        topLeft: Radius.circular(value['topLeft']?.toDouble() ?? 0),
        topRight: Radius.circular(value['topRight']?.toDouble() ?? 0),
        bottomLeft: Radius.circular(value['bottomLeft']?.toDouble() ?? 0),
        bottomRight: Radius.circular(value['bottomRight']?.toDouble() ?? 0),
      );
    }

    return null;
  }

  Border? _parseBorder(dynamic border, RenderContext context) {
    if (border == null) return null;

    if (border is Map<String, dynamic>) {
      final color =
          parseColor(context.resolve(border[core.PropertyKeys.color]), context) ??
              Colors.black;
      final width = context.resolve(border['width'])?.toDouble() ?? 1.0;

      return Border.all(color: color, width: width);
    }

    return null;
  }

  List<BoxShadow>? _parseBoxShadow(dynamic shadow, RenderContext context) {
    if (shadow == null) return null;

    if (shadow is Map<String, dynamic>) {
      return [
        BoxShadow(
          color: parseColor(context.resolve(shadow[core.PropertyKeys.color]), context) ??
              Colors.black,
          blurRadius: context
                  .resolve(shadow['blur'] ?? shadow['blurRadius'])
                  ?.toDouble() ??
              0,
          spreadRadius: context
                  .resolve(shadow['spread'] ?? shadow['spreadRadius'])
                  ?.toDouble() ??
              0,
          offset: _parseOffset(shadow['offset'], context),
        ),
      ];
    }

    if (shadow is List) {
      return shadow
          .map((s) => BoxShadow(
                color:
                    parseColor(context.resolve(s[core.PropertyKeys.color]), context) ??
                        Colors.black,
                blurRadius:
                    context.resolve(s['blur'] ?? s['blurRadius'])?.toDouble() ??
                        0,
                spreadRadius: context
                        .resolve(s['spread'] ?? s['spreadRadius'])
                        ?.toDouble() ??
                    0,
                offset: _parseOffset(s['offset'], context),
              ))
          .toList();
    }

    return null;
  }

  Offset _parseOffset(dynamic offset, RenderContext context) {
    if (offset == null) return Offset.zero;

    if (offset is Map<String, dynamic>) {
      final dx = context.resolve(offset['dx'] ?? offset['x'])?.toDouble() ?? 0;
      final dy = context.resolve(offset['dy'] ?? offset['y'])?.toDouble() ?? 0;
      return Offset(dx, dy);
    }

    return Offset.zero;
  }

  EdgeInsets? _resolveEdgeInsets(dynamic value, RenderContext context) {
    if (value == null) return null;

    if (value is Map<String, dynamic>) {
      // Resolve all values in the map
      final resolved = <String, dynamic>{};
      value.forEach((key, val) {
        resolved[key] = context.resolve(val);
      });
      return parseEdgeInsets(resolved);
    }

    // For simple values, resolve and parse
    final resolved = context.resolve(value);
    return parseEdgeInsets(resolved);
  }
}
