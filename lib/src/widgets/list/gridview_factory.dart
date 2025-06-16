import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for GridView widgets
class GridViewWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    
    // Extract properties
    final scrollDirection = _parseAxis(properties['scrollDirection']);
    final reverse = properties['reverse'] as bool? ?? false;
    final shrinkWrap = properties['shrinkWrap'] as bool? ?? false;
    final physics = _parseScrollPhysics(properties['physics']);
    final padding = parseEdgeInsets(properties['padding']);
    
    // Grid specific properties
    final crossAxisCount = properties['crossAxisCount'] as int?;
    final maxCrossAxisExtent = properties['maxCrossAxisExtent']?.toDouble();
    final mainAxisSpacing = properties['mainAxisSpacing']?.toDouble() ?? 0.0;
    final crossAxisSpacing = properties['crossAxisSpacing']?.toDouble() ?? 0.0;
    final childAspectRatio = properties['childAspectRatio']?.toDouble() ?? 1.0;
    final mainAxisExtent = properties['mainAxisExtent']?.toDouble();
    
    // Get data source
    final staticChildren = definition['children'] as List<dynamic>?;
    final itemsPath = properties['items'] as String?;
    final itemTemplate = properties['itemTemplate'] as Map<String, dynamic>?;
    
    Widget gridView;
    
    // Determine which delegate to use
    SliverGridDelegate gridDelegate;
    if (crossAxisCount != null) {
      gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        childAspectRatio: childAspectRatio,
        mainAxisExtent: mainAxisExtent,
      );
    } else if (maxCrossAxisExtent != null) {
      gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxCrossAxisExtent,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        childAspectRatio: childAspectRatio,
        mainAxisExtent: mainAxisExtent,
      );
    } else {
      // Default to 2 columns if not specified
      gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        childAspectRatio: childAspectRatio,
      );
    }
    
    if (itemsPath != null && itemTemplate != null) {
      // Dynamic grid with data binding
      final items = context.resolve<List<dynamic>>(properties['items']) as List<dynamic>? ?? [];
      
      gridView = GridView.builder(
        scrollDirection: scrollDirection,
        reverse: reverse,
        shrinkWrap: shrinkWrap,
        physics: physics,
        padding: padding,
        gridDelegate: gridDelegate,
        itemCount: items.length,
        itemBuilder: (buildContext, index) {
          // Create child context with item data
          final row = index ~/ (crossAxisCount ?? 2);
          final col = index % (crossAxisCount ?? 2);
          
          final childContext = context.createChildContext(
            variables: {
              'item': items[index],
              'index': index,
              'row': row,
              'col': col,
              'isFirst': index == 0,
              'isLast': index == items.length - 1,
              'isEven': index % 2 == 0,
              'isOdd': index % 2 == 1,
            },
          );
          
          return context.renderer.renderWidget(itemTemplate, childContext);
        },
      );
    } else if (staticChildren != null && staticChildren.isNotEmpty) {
      // Static grid with predefined children
      final children = staticChildren
          .map((child) => context.renderer.renderWidget(child, context))
          .toList();
      
      gridView = GridView(
        scrollDirection: scrollDirection,
        reverse: reverse,
        shrinkWrap: shrinkWrap,
        physics: physics,
        padding: padding,
        gridDelegate: gridDelegate,
        children: children,
      );
    } else {
      // Empty grid
      gridView = GridView(
        shrinkWrap: shrinkWrap,
        physics: physics,
        padding: padding,
        gridDelegate: gridDelegate,
      );
    }
    
    return applyCommonWrappers(gridView, properties, context);
  }

  Axis _parseAxis(String? value) {
    switch (value) {
      case 'horizontal':
        return Axis.horizontal;
      case 'vertical':
      default:
        return Axis.vertical;
    }
  }

  ScrollPhysics? _parseScrollPhysics(String? value) {
    switch (value) {
      case 'never':
        return const NeverScrollableScrollPhysics();
      case 'always':
        return const AlwaysScrollableScrollPhysics();
      case 'bouncing':
        return const BouncingScrollPhysics();
      case 'clamping':
        return const ClampingScrollPhysics();
      default:
        return null;
    }
  }
}