import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for DecoratedBox widgets
class DecoratedBoxWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);

    // Extract decoration
    final decoration = _parseDecoration(properties['decoration'], context) ??
        const BoxDecoration();
    final position = _parseDecorationPosition(properties['position']) ??
        DecorationPosition.background;

    // Extract child widget
    final childrenDef = properties['children'] as List<dynamic>? ??
        definition['children'] as List<dynamic>?;
    Widget? child;
    if (childrenDef != null && childrenDef.isNotEmpty) {
      child = context.buildWidget(childrenDef.first as Map<String, dynamic>);
    }

    Widget decoratedBox = DecoratedBox(
      decoration: decoration,
      position: position,
      child: child ?? const SizedBox.shrink(),
    );

    return applyCommonWrappers(decoratedBox, properties, context);
  }

  Decoration? _parseDecoration(dynamic decoration, RenderContext context) {
    if (decoration == null) return null;

    if (decoration is Map<String, dynamic>) {
      // Check if it's a gradient decoration
      if (decoration.containsKey('gradient')) {
        return BoxDecoration(
          gradient: _parseGradient(decoration['gradient'], context),
          borderRadius: _parseBorderRadius(decoration['borderRadius']),
          border: _parseBorder(decoration['border'], context),
          boxShadow: _parseBoxShadow(decoration['shadow'], context),
          shape: _parseBoxShape(decoration['shape']) ?? BoxShape.rectangle,
        );
      }

      // Standard box decoration
      return BoxDecoration(
        color: parseColor(context.resolve(decoration['color'])),
        image: _parseDecorationImage(decoration['image'], context),
        borderRadius: _parseBorderRadius(decoration['borderRadius']),
        border: _parseBorder(decoration['border'], context),
        boxShadow: _parseBoxShadow(decoration['shadow'], context),
        shape: _parseBoxShape(decoration['shape']) ?? BoxShape.rectangle,
      );
    }

    return null;
  }

  Gradient? _parseGradient(
      Map<String, dynamic>? gradient, RenderContext context) {
    if (gradient == null) return null;

    final type = gradient['type'] as String? ?? 'linear';
    final colors = (gradient['colors'] as List<dynamic>?)
            ?.map((color) =>
                parseColor(context.resolve(color)) ?? Colors.transparent)
            .toList() ??
        [];
    final stops = (gradient['stops'] as List<dynamic>?)
        ?.map((stop) => stop.toDouble())
        .cast<double>()
        .toList();

    switch (type) {
      case 'linear':
        return LinearGradient(
          colors: colors,
          stops: stops,
          begin: parseAlignment(gradient['begin']) ?? Alignment.centerLeft,
          end: parseAlignment(gradient['end']) ?? Alignment.centerRight,
        );
      case 'radial':
        return RadialGradient(
          colors: colors,
          stops: stops,
          center: parseAlignment(gradient['center']) ?? Alignment.center,
          radius: gradient['radius']?.toDouble() ?? 0.5,
        );
      case 'sweep':
        return SweepGradient(
          colors: colors,
          stops: stops,
          center: parseAlignment(gradient['center']) ?? Alignment.center,
          startAngle: gradient['startAngle']?.toDouble() ?? 0.0,
          endAngle: gradient['endAngle']?.toDouble() ?? 6.28319, // 2π
        );
      default:
        return null;
    }
  }

  DecorationImage? _parseDecorationImage(
      Map<String, dynamic>? image, RenderContext context) {
    if (image == null) return null;

    final src = context.resolve<String>(image['src']);
    if (src.isEmpty) return null;

    ImageProvider imageProvider;
    if (src.startsWith('http')) {
      imageProvider = NetworkImage(src);
    } else {
      imageProvider = AssetImage(src);
    }

    return DecorationImage(
      image: imageProvider,
      fit: _parseBoxFit(image['fit']) ?? BoxFit.cover,
      alignment: parseAlignment(image['alignment']) ?? Alignment.center,
      repeat: _parseImageRepeat(image['repeat']) ?? ImageRepeat.noRepeat,
    );
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
          parseColor(context.resolve(border['color'])) ?? Colors.black;
      final width = border['width']?.toDouble() ?? 1.0;

      return Border.all(color: color, width: width);
    }

    return null;
  }

  List<BoxShadow>? _parseBoxShadow(dynamic shadow, RenderContext context) {
    if (shadow == null) return null;

    if (shadow is Map<String, dynamic>) {
      return [
        BoxShadow(
          color: parseColor(context.resolve(shadow['color'])) ?? Colors.black,
          blurRadius: shadow['blur']?.toDouble() ?? 0,
          spreadRadius: shadow['spread']?.toDouble() ?? 0,
          offset: _parseOffset(shadow['offset']),
        ),
      ];
    }

    if (shadow is List) {
      return shadow
          .map((s) => BoxShadow(
                color: parseColor(context.resolve(s['color'])) ?? Colors.black,
                blurRadius: s['blur']?.toDouble() ?? 0,
                spreadRadius: s['spread']?.toDouble() ?? 0,
                offset: _parseOffset(s['offset']),
              ))
          .toList();
    }

    return null;
  }

  Offset _parseOffset(dynamic offset) {
    if (offset == null) return Offset.zero;

    if (offset is Map<String, dynamic>) {
      return Offset(
        offset['x']?.toDouble() ?? 0,
        offset['y']?.toDouble() ?? 0,
      );
    }

    return Offset.zero;
  }

  BoxShape? _parseBoxShape(String? value) {
    switch (value) {
      case 'rectangle':
        return BoxShape.rectangle;
      case 'circle':
        return BoxShape.circle;
      default:
        return null;
    }
  }

  DecorationPosition? _parseDecorationPosition(String? value) {
    switch (value) {
      case 'background':
        return DecorationPosition.background;
      case 'foreground':
        return DecorationPosition.foreground;
      default:
        return null;
    }
  }

  BoxFit? _parseBoxFit(String? value) {
    switch (value) {
      case 'fill':
        return BoxFit.fill;
      case 'contain':
        return BoxFit.contain;
      case 'cover':
        return BoxFit.cover;
      case 'fitWidth':
        return BoxFit.fitWidth;
      case 'fitHeight':
        return BoxFit.fitHeight;
      case 'none':
        return BoxFit.none;
      case 'scaleDown':
        return BoxFit.scaleDown;
      default:
        return null;
    }
  }

  ImageRepeat? _parseImageRepeat(String? value) {
    switch (value) {
      case 'repeat':
        return ImageRepeat.repeat;
      case 'repeatX':
        return ImageRepeat.repeatX;
      case 'repeatY':
        return ImageRepeat.repeatY;
      case 'noRepeat':
        return ImageRepeat.noRepeat;
      default:
        return null;
    }
  }
}
