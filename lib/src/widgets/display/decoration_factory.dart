import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../../renderer/render_context.dart';

/// Factory for decoration widget (implemented as DecoratedBox)
class DecorationWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    final children = definition['children'] as List<dynamic>? ?? [];
    
    final decoration = _resolveBoxDecoration(properties);
    
    Widget child = children.isNotEmpty
        ? context.buildWidget(children.first as Map<String, dynamic>)
        : Container();
    
    return DecoratedBox(
      decoration: decoration,
      position: _resolveDecorationPosition(properties['position']),
      child: child,
    );
  }
  
  BoxDecoration _resolveBoxDecoration(Map<String, dynamic> properties) {
    return BoxDecoration(
      color: resolveColor(properties['color']),
      image: _resolveDecorationImage(properties['image']),
      border: _resolveBorder(properties['border']),
      borderRadius: _resolveBorderRadius(properties['borderRadius']),
      boxShadow: _resolveBoxShadow(properties['boxShadow']),
      gradient: _resolveGradient(properties['gradient']),
      backgroundBlendMode: _resolveBlendMode(properties['backgroundBlendMode']),
      shape: _resolveBoxShape(properties['shape']),
    );
  }
  
  DecorationPosition _resolveDecorationPosition(String? position) {
    switch (position) {
      case 'background':
        return DecorationPosition.background;
      case 'foreground':
        return DecorationPosition.foreground;
      default:
        return DecorationPosition.background;
    }
  }
  
  DecorationImage? _resolveDecorationImage(dynamic image) {
    if (image is Map<String, dynamic>) {
      final src = image['src'] as String?;
      if (src != null) {
        return DecorationImage(
          image: NetworkImage(src),
          fit: _resolveBoxFit(image['fit']),
          alignment: resolveAlignment(image['alignment']) ?? Alignment.center,
          repeat: _resolveImageRepeat(image['repeat']),
        );
      }
    }
    return null;
  }
  
  BoxFit _resolveBoxFit(String? fit) {
    switch (fit) {
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
      case 'scaleDown':
        return BoxFit.scaleDown;
      default:
        return BoxFit.cover;
    }
  }
  
  ImageRepeat _resolveImageRepeat(String? repeat) {
    switch (repeat) {
      case 'repeat':
        return ImageRepeat.repeat;
      case 'repeatX':
        return ImageRepeat.repeatX;
      case 'repeatY':
        return ImageRepeat.repeatY;
      case 'noRepeat':
        return ImageRepeat.noRepeat;
      default:
        return ImageRepeat.noRepeat;
    }
  }
  
  Border? _resolveBorder(dynamic border) {
    if (border is Map<String, dynamic>) {
      if (border.containsKey('all')) {
        final all = border['all'] as Map<String, dynamic>;
        return Border.all(
          color: resolveColor(all['color']) ?? Colors.grey,
          width: all['width']?.toDouble() ?? 1.0,
        );
      }
      
      // Support individual borders (top, right, bottom, left)
      return Border(
        top: _resolveBorderSide(border['top']),
        right: _resolveBorderSide(border['right']),
        bottom: _resolveBorderSide(border['bottom']),
        left: _resolveBorderSide(border['left']),
      );
    }
    return null;
  }
  
  BorderSide _resolveBorderSide(dynamic side) {
    if (side == null) {
      return BorderSide.none;
    }
    
    if (side is Map<String, dynamic>) {
      return BorderSide(
        color: resolveColor(side['color']) ?? Colors.grey,
        width: side['width']?.toDouble() ?? 1.0,
        style: side['style'] == 'none' ? BorderStyle.none : BorderStyle.solid,
      );
    }
    
    return BorderSide.none;
  }
  
  BorderRadius? _resolveBorderRadius(dynamic radius) {
    if (radius is num) {
      return BorderRadius.circular(radius.toDouble());
    }
    if (radius is Map<String, dynamic>) {
      if (radius.containsKey('all')) {
        return BorderRadius.circular(radius['all'].toDouble());
      }
      
      // Support individual corner radius
      return BorderRadius.only(
        topLeft: Radius.circular(radius['topLeft']?.toDouble() ?? 0.0),
        topRight: Radius.circular(radius['topRight']?.toDouble() ?? 0.0),
        bottomLeft: Radius.circular(radius['bottomLeft']?.toDouble() ?? 0.0),
        bottomRight: Radius.circular(radius['bottomRight']?.toDouble() ?? 0.0),
      );
    }
    return null;
  }
  
  List<BoxShadow>? _resolveBoxShadow(dynamic shadow) {
    if (shadow is List) {
      return shadow.map((s) {
        if (s is Map<String, dynamic>) {
          return BoxShadow(
            color: resolveColor(s['color']) ?? Colors.black26,
            offset: Offset(
              s['offsetX']?.toDouble() ?? 0.0,
              s['offsetY']?.toDouble() ?? 0.0,
            ),
            blurRadius: s['blurRadius']?.toDouble() ?? 0.0,
            spreadRadius: s['spreadRadius']?.toDouble() ?? 0.0,
          );
        }
        return const BoxShadow();
      }).toList();
    }
    return null;
  }
  
  Gradient? _resolveGradient(dynamic gradient) {
    if (gradient is Map<String, dynamic>) {
      final type = gradient['type'] as String?;
      final colors = (gradient['colors'] as List?)
          ?.map((c) => resolveColor(c) ?? Colors.transparent)
          .toList();
      
      if (colors == null || colors.isEmpty) return null;
      
      switch (type) {
        case 'linear':
          return LinearGradient(
            colors: colors,
            begin: resolveAlignment(gradient['begin']) ?? Alignment.centerLeft,
            end: resolveAlignment(gradient['end']) ?? Alignment.centerRight,
          );
        case 'radial':
          return RadialGradient(
            colors: colors,
            center: resolveAlignment(gradient['center']) ?? Alignment.center,
            radius: gradient['radius']?.toDouble() ?? 0.5,
          );
        default:
          return LinearGradient(colors: colors);
      }
    }
    return null;
  }
  
  BlendMode? _resolveBlendMode(String? mode) {
    switch (mode) {
      case 'clear':
        return BlendMode.clear;
      case 'src':
        return BlendMode.src;
      case 'dst':
        return BlendMode.dst;
      case 'srcOver':
        return BlendMode.srcOver;
      case 'dstOver':
        return BlendMode.dstOver;
      case 'srcIn':
        return BlendMode.srcIn;
      case 'dstIn':
        return BlendMode.dstIn;
      case 'srcOut':
        return BlendMode.srcOut;
      case 'dstOut':
        return BlendMode.dstOut;
      case 'srcATop':
        return BlendMode.srcATop;
      case 'dstATop':
        return BlendMode.dstATop;
      case 'xor':
        return BlendMode.xor;
      case 'plus':
        return BlendMode.plus;
      case 'modulate':
        return BlendMode.modulate;
      case 'screen':
        return BlendMode.screen;
      case 'overlay':
        return BlendMode.overlay;
      case 'darken':
        return BlendMode.darken;
      case 'lighten':
        return BlendMode.lighten;
      case 'colorDodge':
        return BlendMode.colorDodge;
      case 'colorBurn':
        return BlendMode.colorBurn;
      case 'hardLight':
        return BlendMode.hardLight;
      case 'softLight':
        return BlendMode.softLight;
      case 'difference':
        return BlendMode.difference;
      case 'exclusion':
        return BlendMode.exclusion;
      case 'multiply':
        return BlendMode.multiply;
      case 'hue':
        return BlendMode.hue;
      case 'saturation':
        return BlendMode.saturation;
      case 'color':
        return BlendMode.color;
      case 'luminosity':
        return BlendMode.luminosity;
      default:
        return null;
    }
  }
  
  BoxShape _resolveBoxShape(String? shape) {
    switch (shape) {
      case 'circle':
        return BoxShape.circle;
      case 'rectangle':
        return BoxShape.rectangle;
      default:
        return BoxShape.rectangle;
    }
  }
}