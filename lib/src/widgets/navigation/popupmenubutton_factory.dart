import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for PopupMenuButton widgets
class PopupMenuButtonWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);

    // Extract properties
    final tooltip = context.resolve<String?>(properties['tooltip']);
    final elevation = properties['elevation']?.toDouble();
    final padding =
        parseEdgeInsets(properties['padding']) ?? const EdgeInsets.all(8.0);
    final splashRadius = properties['splashRadius']?.toDouble();
    final iconSize = properties['iconSize']?.toDouble();
    final offset = _parseOffset(properties['offset']);
    final enabled = properties['enabled'] as bool? ?? true;
    final shape = _parseShapeBorder(properties['shape']);
    final color = parseColor(context.resolve(properties['color']));
    final shadowColor = parseColor(context.resolve(properties['shadowColor']));
    final surfaceTintColor =
        parseColor(context.resolve(properties['surfaceTintColor']));

    // Extract items
    final itemsData = properties['items'] as List<dynamic>? ?? [];
    final items =
        itemsData.map((item) => _buildPopupMenuItem(item, context)).toList();

    // Extract child widget or icon
    final childrenDef = properties['children'] as List<dynamic>? ??
        definition['children'] as List<dynamic>?;
    Widget? child;
    if (childrenDef != null && childrenDef.isNotEmpty) {
      child = context.renderer
          .renderWidget(childrenDef.first as Map<String, dynamic>, context);
    } else {
      final icon = properties['icon'] as String?;
      if (icon != null) {
        child = Icon(_parseIconData(icon));
      } else {
        // If no child or icon is specified, use default icon
        child = const Icon(Icons.more_vert);
      }
    }

    // Extract action handlers
    final onSelected = properties['onSelected'] as Map<String, dynamic>?;
    final onOpened = properties['onOpened'] as Map<String, dynamic>?;
    final onCanceled = properties['onCanceled'] as Map<String, dynamic>?;

    Widget popupMenuButton = PopupMenuButton<String>(
      itemBuilder: (BuildContext ctx) => items,
      onSelected: onSelected != null
          ? (value) {
              final eventData = Map<String, dynamic>.from(onSelected);
              if (eventData['value'] == '{{event.value}}') {
                eventData['value'] = value;
              }
              context.actionHandler.execute(eventData, context);
            }
          : null,
      onOpened: onOpened != null
          ? () {
              context.actionHandler.execute(onOpened, context);
            }
          : null,
      onCanceled: onCanceled != null
          ? () {
              context.actionHandler.execute(onCanceled, context);
            }
          : null,
      tooltip: tooltip,
      elevation: elevation,
      padding: padding,
      splashRadius: splashRadius,
      iconSize: iconSize,
      offset: offset,
      enabled: enabled,
      shape: shape,
      color: color,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      child: child,
    );

    return applyCommonWrappers(popupMenuButton, properties, context);
  }

  PopupMenuItem<String> _buildPopupMenuItem(
      dynamic itemData, RenderContext context) {
    if (itemData is Map<String, dynamic>) {
      final value = context.resolve<String>(itemData['value']) as String? ?? '';
      final enabled = itemData['enabled'] as bool? ?? true;
      final height = itemData['height']?.toDouble();
      final padding = parseEdgeInsets(itemData['padding']);
      final textStyle = _parseTextStyle(itemData['textStyle'], context);

      final child = itemData['child'] != null
          ? context.renderer
              .renderWidget(itemData['child'] as Map<String, dynamic>, context)
          : Text(context.resolve<String?>(itemData['text']) ?? value);

      // Only set height if it's not null, otherwise use default
      if (height != null) {
        return PopupMenuItem<String>(
          value: value,
          enabled: enabled,
          height: height,
          padding: padding,
          textStyle: textStyle,
          child: child,
        );
      } else {
        return PopupMenuItem<String>(
          value: value,
          enabled: enabled,
          padding: padding,
          textStyle: textStyle,
          child: child,
        );
      }
    }

    return PopupMenuItem<String>(
      value: itemData.toString(),
      child: Text(itemData.toString()),
    );
  }

  IconData _parseIconData(String iconName) {
    switch (iconName) {
      case 'more_vert':
        return Icons.more_vert;
      case 'more_horiz':
        return Icons.more_horiz;
      case 'menu':
        return Icons.menu;
      case 'settings':
        return Icons.settings;
      default:
        return Icons.more_vert;
    }
  }

  Offset _parseOffset(dynamic offset) {
    if (offset == null) return Offset.zero;

    if (offset is Map<String, dynamic>) {
      final dx = offset['dx'];
      final dy = offset['dy'];
      return Offset(
        dx != null ? dx.toDouble() : 0,
        dy != null ? dy.toDouble() : 0,
      );
    }

    return Offset.zero;
  }

  ShapeBorder? _parseShapeBorder(dynamic shape) {
    if (shape == null) return null;

    if (shape is Map<String, dynamic>) {
      final type = shape['type'] as String?;
      switch (type) {
        case 'rounded':
          final radiusValue = shape['radius'];
          final radius = radiusValue != null ? radiusValue.toDouble() : 8.0;
          return RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          );
        default:
          return null;
      }
    }

    return null;
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
