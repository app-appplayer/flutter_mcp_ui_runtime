import 'package:flutter/material.dart';
import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for creating linear layout widgets (spec v1.0)
/// Supports both vertical and horizontal directions
class LinearLayoutFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);

    // Get direction (default to vertical)
    final direction =
        context.resolve<String>(properties['direction'] ?? 'vertical');
    final isVertical = direction == 'vertical';

    // Get distribution (spec v1.0 replacement for mainAxisAlignment)
    final distribution = context.resolve<String?>(properties['distribution']) ??
        context.resolve<String?>(properties['mainAxisAlignment']) ??
        'start';

    // Get alignment (spec v1.0 for crossAxisAlignment)
    final alignment = context.resolve<String?>(properties['alignment']) ??
        context.resolve<String?>(properties['crossAxisAlignment']) ??
        'center';

    // Get gap (spec v1.0 for spacing between items)
    final gapValue = context.resolve(properties['gap']) ?? 0.0;
    final gap =
        gapValue is int ? gapValue.toDouble() : (gapValue as double? ?? 0.0);

    // Get wrap (spec v1.0 for whether items should wrap)
    final wrap = context.resolve<bool>(properties['wrap'] ?? false);

    // Build children
    final childrenDefs = definition['children'] as List<dynamic>? ?? [];
    final children = <Widget>[];

    for (final childDef in childrenDefs) {
      if (childDef is Map<String, dynamic>) {
        final child = context.buildWidget(childDef);

        // Check if child has flex property
        final flex = childDef['flex'];
        if (flex != null && flex is int && !wrap) {
          // Wrap in Flexible if flex is specified and not in wrap mode
          children.add(Flexible(
            flex: flex,
            child: child,
          ));
        } else {
          children.add(child);
        }
      }
    }

    // If gap is specified, add spacing between children
    List<Widget> spacedChildren = children;
    if (gap > 0 && children.length > 1) {
      spacedChildren = [];
      for (int i = 0; i < children.length; i++) {
        spacedChildren.add(children[i]);
        if (i < children.length - 1) {
          spacedChildren.add(SizedBox(
            width: isVertical ? 0 : gap,
            height: isVertical ? gap : 0,
          ));
        }
      }
    }

    // If wrap is true, use Wrap widget
    if (wrap) {
      return Wrap(
        direction: isVertical ? Axis.vertical : Axis.horizontal,
        alignment: _parseWrapAlignment(distribution),
        crossAxisAlignment: _parseWrapCrossAlignment(alignment),
        spacing: gap,
        runSpacing: gap,
        children: children,
      );
    }

    // Otherwise use Column or Row
    Widget widget = isVertical
        ? Column(
            mainAxisAlignment: _parseMainAxisAlignment(distribution),
            crossAxisAlignment: _parseCrossAxisAlignment(alignment),
            mainAxisSize: MainAxisSize.min,
            children: spacedChildren,
          )
        : Row(
            mainAxisAlignment: _parseMainAxisAlignment(distribution),
            crossAxisAlignment: _parseCrossAxisAlignment(alignment),
            mainAxisSize: MainAxisSize.min,
            children: spacedChildren,
          );

    // Apply padding if specified
    final padding = properties['padding'];
    if (padding != null) {
      widget = Padding(
        padding: parseEdgeInsets(padding) ?? EdgeInsets.zero,
        child: widget,
      );
    }

    return applyCommonWrappers(widget, properties, context);
  }

  MainAxisAlignment _parseMainAxisAlignment(String? value) {
    switch (value) {
      case 'start':
        return MainAxisAlignment.start;
      case 'end':
        return MainAxisAlignment.end;
      case 'center':
        return MainAxisAlignment.center;
      case 'space-between':
      case 'spaceBetween':
        return MainAxisAlignment.spaceBetween;
      case 'space-around':
      case 'spaceAround':
        return MainAxisAlignment.spaceAround;
      case 'space-evenly':
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

  WrapAlignment _parseWrapAlignment(String? value) {
    switch (value) {
      case 'start':
        return WrapAlignment.start;
      case 'end':
        return WrapAlignment.end;
      case 'center':
        return WrapAlignment.center;
      case 'space-between':
      case 'spaceBetween':
        return WrapAlignment.spaceBetween;
      case 'space-around':
      case 'spaceAround':
        return WrapAlignment.spaceAround;
      case 'space-evenly':
      case 'spaceEvenly':
        return WrapAlignment.spaceEvenly;
      default:
        return WrapAlignment.start;
    }
  }

  WrapCrossAlignment _parseWrapCrossAlignment(String? value) {
    switch (value) {
      case 'start':
        return WrapCrossAlignment.start;
      case 'end':
        return WrapCrossAlignment.end;
      case 'center':
        return WrapCrossAlignment.center;
      default:
        return WrapCrossAlignment.center;
    }
  }
}
