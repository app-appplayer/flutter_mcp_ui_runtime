import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for Column widgets
class ColumnWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    
    // Column is a multi-child widget, so children should be at root level
    final childrenProp = definition['children'];
    
    // Resolve children if it's a binding expression
    final resolvedChildren = context.resolve(childrenProp);
    
    List<Widget> children = [];
    if (resolvedChildren is List<dynamic>) {
      children = resolvedChildren
          .map((child) => context.buildWidget(child as Map<String, dynamic>))
          .toList();
    }
    
    // Build column
    Widget column = Column(
      mainAxisAlignment: _parseMainAxisAlignment(properties['mainAxisAlignment']),
      crossAxisAlignment: _parseCrossAxisAlignment(properties['crossAxisAlignment']),
      mainAxisSize: _parseMainAxisSize(properties['mainAxisSize']),
      verticalDirection: _parseVerticalDirection(properties['verticalDirection']),
      children: children,
    );
    
    return applyCommonWrappers(column, properties, context);
  }

  MainAxisAlignment _parseMainAxisAlignment(String? value) {
    switch (value) {
      case 'start':
        return MainAxisAlignment.start;
      case 'end':
        return MainAxisAlignment.end;
      case 'center':
        return MainAxisAlignment.center;
      case 'spaceBetween':
        return MainAxisAlignment.spaceBetween;
      case 'spaceAround':
        return MainAxisAlignment.spaceAround;
      case 'spaceEvenly':
        return MainAxisAlignment.spaceEvenly;
      default:
        return MainAxisAlignment.start;
    }
  }

  CrossAxisAlignment _parseCrossAxisAlignment(String? value) {
    switch (value) {
      case 'start':
        return CrossAxisAlignment.start;
      case 'end':
        return CrossAxisAlignment.end;
      case 'center':
        return CrossAxisAlignment.center;
      case 'stretch':
        return CrossAxisAlignment.stretch;
      case 'baseline':
        return CrossAxisAlignment.baseline;
      default:
        return CrossAxisAlignment.center;
    }
  }

  MainAxisSize _parseMainAxisSize(String? value) {
    switch (value) {
      case 'min':
        return MainAxisSize.min;
      case 'max':
        return MainAxisSize.max;
      default:
        return MainAxisSize.max;
    }
  }

  VerticalDirection _parseVerticalDirection(String? value) {
    switch (value) {
      case 'up':
        return VerticalDirection.up;
      case 'down':
        return VerticalDirection.down;
      default:
        return VerticalDirection.down;
    }
  }
}