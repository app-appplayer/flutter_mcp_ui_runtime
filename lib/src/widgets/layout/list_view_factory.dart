import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../../renderer/render_context.dart';

/// Factory for creating ListView widgets
class ListViewFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    // Get properties - simplified for now
    final scrollDirectionStr = definition['scrollDirection'] as String?;
    final scrollDirection =
        scrollDirectionStr == 'horizontal' ? Axis.horizontal : Axis.vertical;

    final reverse = definition['reverse'] as bool? ?? false;
    final primary = definition['primary'] as bool?;
    final shrinkWrap = definition['shrinkWrap'] as bool? ?? false;
    final physics = definition['physics'] as String?;

    // Get children
    final childrenData = definition['children'] as List<dynamic>?;
    if (childrenData == null || childrenData.isEmpty) {
      return ListView();
    }

    // Convert children
    final children = childrenData.map((childDef) {
      return context.renderer.renderWidget(childDef, context);
    }).toList();

    return ListView(
      scrollDirection: scrollDirection,
      reverse: reverse,
      primary: primary,
      shrinkWrap: shrinkWrap,
      physics: physics == 'neverScrollable'
          ? const NeverScrollableScrollPhysics()
          : physics == 'alwaysScrollable'
              ? const AlwaysScrollableScrollPhysics()
              : physics == 'bouncing'
                  ? const BouncingScrollPhysics()
                  : physics == 'clamping'
                      ? const ClampingScrollPhysics()
                      : null,
      children: children,
    );
  }
}
