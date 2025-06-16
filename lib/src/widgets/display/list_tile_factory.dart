import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../../renderer/render_context.dart';

/// Factory for creating ListTile widgets
class ListTileFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    // Get title widget
    final titleData = definition['title'];
    Widget? title;
    if (titleData != null) {
      title = context.renderer.renderWidget(titleData, context);
    }
    
    // Get subtitle widget
    final subtitleData = definition['subtitle'];
    Widget? subtitle;
    if (subtitleData != null) {
      subtitle = context.renderer.renderWidget(subtitleData, context);
    }
    
    // Get leading widget
    final leadingData = definition['leading'];
    Widget? leading;
    if (leadingData != null) {
      leading = context.renderer.renderWidget(leadingData, context);
    }
    
    // Get trailing widget
    final trailingData = definition['trailing'];
    Widget? trailing;
    if (trailingData != null) {
      trailing = context.renderer.renderWidget(trailingData, context);
    }
    
    // Get other properties
    final isThreeLine = definition['isThreeLine'] as bool? ?? false;
    final dense = definition['dense'] as bool?;
    final enabled = definition['enabled'] as bool? ?? true;
    final selected = definition['selected'] as bool? ?? false;
    
    // Handle onTap
    VoidCallback? onTap;
    final onTapAction = definition['onTap'];
    if (onTapAction != null) {
      onTap = () {
        context.actionHandler.execute(onTapAction, context);
      };
    }
    
    // Handle onLongPress
    VoidCallback? onLongPress;
    final onLongPressAction = definition['onLongPress'];
    if (onLongPressAction != null) {
      onLongPress = () {
        context.actionHandler.execute(onLongPressAction, context);
      };
    }
    
    return ListTile(
      title: title,
      subtitle: subtitle,
      leading: leading,
      trailing: trailing,
      isThreeLine: isThreeLine,
      dense: dense,
      enabled: enabled,
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}