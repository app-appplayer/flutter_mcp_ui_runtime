import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for AppBar widgets
class AppBarWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);

    // Extract properties
    final titleData = properties['title'];
    final centerTitle = properties['centerTitle'] as bool?;
    final automaticallyImplyLeading =
        properties['automaticallyImplyLeading'] as bool? ?? true;
    final backgroundColor =
        parseColor(context.resolve(properties['backgroundColor']));
    final foregroundColor =
        parseColor(context.resolve(properties['foregroundColor']));
    final elevation = properties['elevation']?.toDouble();
    final shadowColor = parseColor(context.resolve(properties['shadowColor']));
    final shape = _parseShapeBorder(properties['shape']);
    final toolbarHeight = properties['toolbarHeight']?.toDouble();
    final toolbarOpacity = properties['toolbarOpacity']?.toDouble() ?? 1.0;
    final bottomOpacity = properties['bottomOpacity']?.toDouble() ?? 1.0;

    // Build leading widget
    Widget? leading;
    if (properties['leading'] != null) {
      leading = _buildWidget(properties['leading'], context);
    }

    // Build actions
    List<Widget>? actions;
    final actionsData = properties['actions'] as List<dynamic>?;
    if (actionsData != null) {
      actions = actionsData
          .map((action) => _buildWidget(action, context))
          .where((widget) => widget != null)
          .cast<Widget>()
          .toList();
    }

    // Build bottom (TabBar, etc.)
    PreferredSizeWidget? bottom;
    if (properties['bottom'] != null) {
      final bottomWidget = _buildWidget(properties['bottom'], context);
      if (bottomWidget != null) {
        bottom = PreferredSize(
          preferredSize:
              Size.fromHeight(properties['bottomHeight']?.toDouble() ?? 48.0),
          child: bottomWidget,
        );
      }
    }

    // Build flexible space
    Widget? flexibleSpace;
    if (properties['flexibleSpace'] != null) {
      flexibleSpace = _buildWidget(properties['flexibleSpace'], context);
    }

    // Build title widget
    Widget? titleWidget;
    if (titleData != null) {
      if (titleData is String) {
        titleWidget = Text(titleData);
      } else if (titleData is Map<String, dynamic>) {
        titleWidget = _buildWidget(titleData, context);
      }
    }

    Widget appBar = AppBar(
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      title: titleWidget,
      actions: actions,
      flexibleSpace: flexibleSpace,
      bottom: bottom,
      elevation: elevation,
      shadowColor: shadowColor,
      shape: shape,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      toolbarHeight: toolbarHeight,
      toolbarOpacity: toolbarOpacity,
      bottomOpacity: bottomOpacity,
      centerTitle: centerTitle,
    );

    return appBar;
  }

  Widget? _buildWidget(dynamic widgetDef, RenderContext context) {
    if (widgetDef == null) return null;

    if (widgetDef is Map<String, dynamic>) {
      return context.renderer.renderWidget(widgetDef, context);
    }

    return null;
  }

  ShapeBorder? _parseShapeBorder(Map<String, dynamic>? shape) {
    if (shape == null) return null;

    final type = shape['type'] as String?;
    switch (type) {
      case 'rounded':
        final radius = shape['radius']?.toDouble() ?? 8.0;
        return RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(radius),
          ),
        );
      default:
        return null;
    }
  }
}
