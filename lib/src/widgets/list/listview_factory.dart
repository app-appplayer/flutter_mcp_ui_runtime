import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for ListView widgets
class ListViewWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    
    // Extract properties
    final scrollDirection = _parseAxis(properties['scrollDirection']);
    final reverse = properties['reverse'] as bool? ?? false;
    // Follow MCP UI DSL v1.0 spec: shrinkWrap defaults to false
    final shrinkWrap = properties['shrinkWrap'] as bool? ?? false;
    final physics = _parseScrollPhysics(properties['physics']);
    final padding = parseEdgeInsets(properties['padding']);
    final itemSpacing = properties['itemSpacing']?.toDouble() ?? 0.0;
    
    // Get data source - support both static children and dynamic items
    final childrenProp = definition['children'];
    final resolvedChildren = context.resolve(childrenProp);
    final staticChildren = resolvedChildren is List<dynamic> ? resolvedChildren : null;
    
    // Support both direct list and path-based items
    final itemsProp = properties['items'];
    final resolvedItems = context.resolve(itemsProp);
    final directItems = itemsProp is List ? itemsProp : null;
    final itemsPath = itemsProp is String ? itemsProp : null;
    final itemTemplate = properties['itemTemplate'] as Map<String, dynamic>?;
    
    // Also support itemCount/itemBuilder pattern
    final itemCountValue = properties['itemCount'];
    final itemBuilder = properties['itemBuilder'] as Map<String, dynamic>?;
    
    Widget listView;
    
    if (itemCountValue != null && itemBuilder != null) {
      // Dynamic list with itemCount/itemBuilder pattern
      final itemCount = context.resolve(itemCountValue) as int? ?? 0;
      
      listView = ListView.separated(
        scrollDirection: scrollDirection,
        reverse: reverse,
        shrinkWrap: shrinkWrap,
        physics: physics,
        padding: padding,
        itemCount: itemCount,
        separatorBuilder: itemSpacing > 0 
            ? (context, index) => scrollDirection == Axis.horizontal
                ? SizedBox(width: itemSpacing)
                : SizedBox(height: itemSpacing)
            : (context, index) => Container(),
        itemBuilder: (buildContext, index) {
          // Create child context with index
          final childContext = context.createChildContext(
            variables: {
              'index': index,
              'isFirst': index == 0,
              'isLast': index == itemCount - 1,
              'isEven': index % 2 == 0,
              'isOdd': index % 2 == 1,
            },
          );
          
          return context.renderer.renderWidget(itemBuilder, childContext);
        },
      );
    } else if ((itemsPath != null || resolvedItems != null) && itemTemplate != null) {
      // Dynamic list with data binding
      final items = resolvedItems as List<dynamic>? ?? [];
      
      listView = ListView.separated(
        scrollDirection: scrollDirection,
        reverse: reverse,
        shrinkWrap: shrinkWrap,
        physics: physics,
        padding: padding,
        itemCount: items.length,
        separatorBuilder: itemSpacing > 0 
            ? (context, index) => scrollDirection == Axis.horizontal
                ? SizedBox(width: itemSpacing)
                : SizedBox(height: itemSpacing)
            : (context, index) => Container(),
        itemBuilder: (buildContext, index) {
          // Create child context with item data
          final childContext = context.createChildContext(
            variables: {
              'item': items[index],
              'index': index,
              'isFirst': index == 0,
              'isLast': index == items.length - 1,
              'isEven': index % 2 == 0,
              'isOdd': index % 2 == 1,
            },
          );
          
          return context.renderer.renderWidget(itemTemplate, childContext);
        },
      );
    } else if (directItems != null && directItems.isNotEmpty) {
      // Direct items list (like in showcase_definition.dart)
      final items = directItems;
      
      listView = ListView.separated(
        scrollDirection: scrollDirection,
        reverse: reverse,
        shrinkWrap: shrinkWrap,
        physics: physics,
        padding: padding,
        itemCount: items.length,
        separatorBuilder: itemSpacing > 0 
            ? (buildContext, index) => scrollDirection == Axis.horizontal
                ? SizedBox(width: itemSpacing)
                : SizedBox(height: itemSpacing)
            : (buildContext, index) => Container(),
        itemBuilder: (buildContext, index) {
          // Render each item directly as a widget
          return context.renderer.renderWidget(items[index], context);
        },
      );
    } else if (staticChildren != null && staticChildren.isNotEmpty) {
      // Static list with predefined children
      final children = staticChildren
          .map((child) => context.renderer.renderWidget(child, context))
          .toList();
      
      if (itemSpacing > 0) {
        // Use ListView.separated for spacing
        listView = ListView.separated(
          scrollDirection: scrollDirection,
          reverse: reverse,
          shrinkWrap: shrinkWrap,
          physics: physics,
          padding: padding,
          itemCount: children.length,
          separatorBuilder: (context, index) => scrollDirection == Axis.horizontal
              ? SizedBox(width: itemSpacing)
              : SizedBox(height: itemSpacing),
          itemBuilder: (context, index) => children[index],
        );
      } else {
        // Regular ListView
        listView = ListView(
          scrollDirection: scrollDirection,
          reverse: reverse,
          shrinkWrap: shrinkWrap,
          physics: physics,
          padding: padding,
          children: children,
        );
      }
    } else {
      // Empty list
      listView = ListView(
        shrinkWrap: shrinkWrap,
        physics: physics,
        padding: padding,
      );
    }
    
    // Ensure ListView has proper constraints for stability
    final wrappedListView = _ensureStableConstraints(listView, shrinkWrap);
    
    return applyCommonWrappers(wrappedListView, properties, context);
  }
  
  Widget _ensureStableConstraints(Widget listView, bool shrinkWrap) {
    // If shrinkWrap is true, the ListView handles its own constraints
    if (shrinkWrap) {
      return listView;
    }
    
    // For non-shrinkWrap ListViews, ensure they have bounded constraints
    return LayoutBuilder(
      builder: (context, constraints) {
        // If constraints are already bounded, use them as-is
        if (constraints.hasBoundedHeight) {
          return listView;
        }
        
        // Provide a default height for unbounded contexts
        // This prevents viewport assertion errors in tests
        return SizedBox(
          height: MediaQuery.of(context).size.height,
          child: listView,
        );
      },
    );
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