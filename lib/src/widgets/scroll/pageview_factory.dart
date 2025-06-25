import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for PageView widgets
class PageViewWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);

    // Extract properties
    final scrollDirection =
        _parseAxis(properties['scrollDirection']) ?? Axis.horizontal;
    final reverse = properties['reverse'] as bool? ?? false;
    final pageSnapping = properties['pageSnapping'] as bool? ?? true;
    final allowImplicitScrolling =
        properties['allowImplicitScrolling'] as bool? ?? false;
    final padEnds = properties['padEnds'] as bool? ?? true;
    final clipBehavior =
        _parseClip(properties['clipBehavior']) ?? Clip.hardEdge;

    // Extract children
    final childrenDef = properties['children'] as List<dynamic>? ??
        definition['children'] as List<dynamic>?;
    final children = childrenDef
            ?.map((child) => context.buildWidget(child as Map<String, dynamic>))
            .toList() ??
        [];

    // Extract action handlers
    final onPageChanged = properties['onPageChanged'] as Map<String, dynamic>?;

    Widget pageView = PageView(
      scrollDirection: scrollDirection,
      reverse: reverse,
      pageSnapping: pageSnapping,
      allowImplicitScrolling: allowImplicitScrolling,
      padEnds: padEnds,
      clipBehavior: clipBehavior,
      onPageChanged: onPageChanged != null
          ? (index) {
              final eventData = Map<String, dynamic>.from(onPageChanged);
              if (eventData['index'] == '{{event.index}}') {
                eventData['index'] = index;
              }
              context.actionHandler.execute(eventData, context);
            }
          : null,
      children: children,
    );

    return applyCommonWrappers(pageView, properties, context);
  }

  Axis? _parseAxis(String? value) {
    switch (value) {
      case 'horizontal':
        return Axis.horizontal;
      case 'vertical':
        return Axis.vertical;
      default:
        return null;
    }
  }

  Clip? _parseClip(String? value) {
    switch (value) {
      case 'none':
        return Clip.none;
      case 'hardEdge':
        return Clip.hardEdge;
      case 'antiAlias':
        return Clip.antiAlias;
      case 'antiAliasWithSaveLayer':
        return Clip.antiAliasWithSaveLayer;
      default:
        return null;
    }
  }
}
