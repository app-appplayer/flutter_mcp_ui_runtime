import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for Chip widgets
class ChipWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    
    // Extract properties
    final label = context.resolve<String>(properties['label']) as String? ?? '';
    final avatar = properties['avatar'] as Map<String, dynamic>?;
    final deleteIcon = properties['deleteIcon'] as String?;
    final onDeleted = properties['onDeleted'] as Map<String, dynamic>?;
    final onPressed = properties['onPressed'] as Map<String, dynamic>?;
    final backgroundColor = parseColor(context.resolve(properties['backgroundColor']));
    final labelStyle = _parseTextStyle(properties['labelStyle'], context);
    final padding = parseEdgeInsets(properties['padding']);
    final elevation = properties['elevation']?.toDouble();
    final shadowColor = parseColor(context.resolve(properties['shadowColor']));
    final side = _parseBorderSide(properties['side'], context);
    final shape = _parseOutlinedBorder(properties['shape']);
    
    // Build avatar widget
    Widget? avatarWidget;
    if (avatar != null) {
      final avatarText = avatar['text'] as String?;
      final avatarIcon = avatar['icon'] as String?;
      final avatarImage = avatar['image'] as String?;
      
      if (avatarText != null) {
        avatarWidget = CircleAvatar(
          radius: 14,
          child: Text(avatarText.substring(0, 1).toUpperCase()),
        );
      } else if (avatarIcon != null) {
        avatarWidget = CircleAvatar(
          radius: 14,
          child: Icon(_parseIconData(avatarIcon), size: 18),
        );
      } else if (avatarImage != null) {
        avatarWidget = CircleAvatar(
          backgroundImage: NetworkImage(avatarImage),
          radius: 14,
        );
      }
    }
    
    // Build delete icon
    Widget? deleteIconWidget;
    if (deleteIcon != null) {
      deleteIconWidget = Icon(_parseIconData(deleteIcon), size: 18);
    }
    
    Widget chip = Chip(
      label: Text(label),
      avatar: avatarWidget,
      deleteIcon: deleteIconWidget,
      onDeleted: onDeleted != null ? () {
        context.actionHandler.execute(onDeleted, context);
      } : null,
      backgroundColor: backgroundColor,
      labelStyle: labelStyle,
      padding: padding,
      elevation: elevation,
      shadowColor: shadowColor,
      side: side,
      shape: shape,
    );
    
    // Wrap in GestureDetector if onPressed is provided
    if (onPressed != null) {
      chip = GestureDetector(
        onTap: () {
          context.actionHandler.execute(onPressed, context);
        },
        child: chip,
      );
    }
    
    return applyCommonWrappers(chip, properties, context);
  }

  TextStyle? _parseTextStyle(Map<String, dynamic>? style, RenderContext context) {
    if (style == null) return null;
    
    return TextStyle(
      color: parseColor(context.resolve(style['color'])),
      fontSize: style['fontSize']?.toDouble(),
      fontWeight: _parseFontWeight(style['fontWeight']),
    );
  }

  FontWeight? _parseFontWeight(String? value) {
    switch (value) {
      case 'bold':
        return FontWeight.bold;
      case 'normal':
        return FontWeight.normal;
      default:
        return null;
    }
  }

  BorderSide? _parseBorderSide(Map<String, dynamic>? side, RenderContext context) {
    if (side == null) return null;
    
    return BorderSide(
      color: parseColor(context.resolve(side['color'])) ?? Colors.black,
      width: side['width']?.toDouble() ?? 1.0,
    );
  }

  OutlinedBorder? _parseOutlinedBorder(Map<String, dynamic>? shape) {
    if (shape == null) return null;
    
    final type = shape['type'] as String?;
    switch (type) {
      case 'stadium':
        return const StadiumBorder();
      case 'rounded':
        final radius = shape['radius']?.toDouble() ?? 8.0;
        return RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        );
      default:
        return null;
    }
  }

  IconData _parseIconData(String iconName) {
    switch (iconName) {
      case 'close':
        return Icons.close;
      case 'cancel':
        return Icons.cancel;
      case 'clear':
        return Icons.clear;
      default:
        return Icons.close;
    }
  }
}