import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for TabBar widgets
class TabBarWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);

    // Extract tabs
    final tabsData = properties['tabs'] as List<dynamic>? ?? [];
    final tabs = tabsData.map<Tab>((tab) {
      if (tab is Map<String, dynamic>) {
        return Tab(
          text: (tab['text'] ?? tab['label']) as String?,
          icon: tab['icon'] != null ? Icon(_parseIconData(tab['icon'])) : null,
          iconMargin: parseEdgeInsets(tab['iconMargin']) ??
              const EdgeInsets.only(bottom: 10),
          height: tab['height']?.toDouble(),
        );
      }
      return Tab(text: tab.toString());
    }).toList();

    // Extract properties
    final isScrollable = properties['isScrollable'] as bool? ?? false;
    final padding = parseEdgeInsets(properties['padding']);
    final indicatorColor =
        parseColor(context.resolve(properties['indicatorColor']));
    final indicatorWeight = properties['indicatorWeight']?.toDouble() ?? 2.0;
    final indicatorPadding =
        parseEdgeInsets(properties['indicatorPadding']) ?? EdgeInsets.zero;
    final indicator = _parseDecoration(properties['indicator'], context);
    final indicatorSize =
        _parseTabBarIndicatorSize(properties['indicatorSize']);
    final labelColor = parseColor(context.resolve(properties['labelColor']));
    final labelStyle = _parseTextStyle(properties['labelStyle'], context);
    final labelPadding = parseEdgeInsets(properties['labelPadding']);
    final unselectedLabelColor =
        parseColor(context.resolve(properties['unselectedLabelColor']));
    final unselectedLabelStyle =
        _parseTextStyle(properties['unselectedLabelStyle'], context);
    const dragStartBehavior = DragStartBehavior.start;
    final overlayColor = properties['overlayColor'] != null
        ? WidgetStateProperty.all(
            parseColor(context.resolve(properties['overlayColor'])))
        : null;
    final mouseCursor = _parseMouseCursor(properties['mouseCursor']);
    final enableFeedback = properties['enableFeedback'] as bool?;
    final physics = _parseScrollPhysics(properties['physics']);

    // Extract action handler
    final onTap = properties['onTap'] as Map<String, dynamic>?;

    // Wrap TabBar with DefaultTabController to provide required TabController
    Widget tabBar = DefaultTabController(
      length: tabs.length,
      child: TabBar(
        tabs: tabs,
        isScrollable: isScrollable,
        padding: padding,
        indicatorColor: indicatorColor,
        indicatorWeight: indicatorWeight,
        indicatorPadding: indicatorPadding,
        indicator: indicator,
        indicatorSize: indicatorSize,
        labelColor: labelColor,
        labelStyle: labelStyle,
        labelPadding: labelPadding,
        unselectedLabelColor: unselectedLabelColor,
        unselectedLabelStyle: unselectedLabelStyle,
        dragStartBehavior: dragStartBehavior,
        overlayColor: overlayColor,
        mouseCursor: mouseCursor,
        enableFeedback: enableFeedback,
        onTap: onTap != null
            ? (index) {
                // Execute action with index
                final eventData = Map<String, dynamic>.from(onTap);
                if (eventData['value'] == '{{event.index}}') {
                  eventData['value'] = index;
                }
                context.actionHandler.execute(eventData, context);
              }
            : null,
        physics: physics,
      ),
    );

    return applyCommonWrappers(tabBar, properties, context);
  }

  TabBarIndicatorSize _parseTabBarIndicatorSize(String? size) {
    switch (size) {
      case 'tab':
        return TabBarIndicatorSize.tab;
      case 'label':
        return TabBarIndicatorSize.label;
      default:
        return TabBarIndicatorSize.tab;
    }
  }

  Decoration? _parseDecoration(
      Map<String, dynamic>? decoration, RenderContext context) {
    if (decoration == null) return null;

    final type = decoration['type'] as String?;
    switch (type) {
      case 'underline':
        return UnderlineTabIndicator(
          borderSide: BorderSide(
            width: decoration['width']?.toDouble() ?? 2.0,
            color:
                parseColor(context.resolve(decoration['color'])) ?? Colors.blue,
          ),
          insets: parseEdgeInsets(decoration['insets']) ?? EdgeInsets.zero,
        );
      default:
        return null;
    }
  }

  TextStyle? _parseTextStyle(
      Map<String, dynamic>? style, RenderContext context) {
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

  MouseCursor? _parseMouseCursor(String? cursor) {
    switch (cursor) {
      case 'click':
        return SystemMouseCursors.click;
      case 'basic':
        return SystemMouseCursors.basic;
      default:
        return null;
    }
  }

  ScrollPhysics? _parseScrollPhysics(String? physics) {
    switch (physics) {
      case 'never':
        return const NeverScrollableScrollPhysics();
      case 'bouncing':
        return const BouncingScrollPhysics();
      case 'clamping':
        return const ClampingScrollPhysics();
      default:
        return null;
    }
  }

  IconData _parseIconData(String iconName) {
    // Basic icon mapping
    switch (iconName) {
      case 'home':
        return Icons.home;
      case 'star':
        return Icons.star;
      case 'settings':
        return Icons.settings;
      default:
        return Icons.tab;
    }
  }
}
