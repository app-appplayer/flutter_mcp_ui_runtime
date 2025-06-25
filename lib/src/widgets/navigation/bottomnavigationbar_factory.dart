import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for BottomNavigationBar widgets
class BottomNavigationBarWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);

    // Extract properties
    final currentIndex =
        context.resolve<int>(properties['currentIndex']) as int? ?? 0;
    final elevation = properties['elevation']?.toDouble();
    final type = _parseBottomNavigationBarType(properties['type']);
    final fixedColor = parseColor(context.resolve(properties['fixedColor']));
    final backgroundColor =
        parseColor(context.resolve(properties['backgroundColor']));
    final iconSize = properties['iconSize']?.toDouble() ?? 24.0;
    final selectedItemColor =
        parseColor(context.resolve(properties['selectedItemColor']));
    final unselectedItemColor =
        parseColor(context.resolve(properties['unselectedItemColor']));
    final selectedIconTheme =
        _parseIconThemeData(properties['selectedIconTheme'], context);
    final unselectedIconTheme =
        _parseIconThemeData(properties['unselectedIconTheme'], context);
    final selectedFontSize = properties['selectedFontSize']?.toDouble() ?? 14.0;
    final unselectedFontSize =
        properties['unselectedFontSize']?.toDouble() ?? 12.0;
    final selectedLabelStyle =
        _parseTextStyle(properties['selectedLabelStyle'], context);
    final unselectedLabelStyle =
        _parseTextStyle(properties['unselectedLabelStyle'], context);
    final showSelectedLabels = properties['showSelectedLabels'] as bool?;
    final showUnselectedLabels = properties['showUnselectedLabels'] as bool?;
    final enableFeedback = properties['enableFeedback'] as bool?;

    // Extract items
    final itemsData = properties['items'] as List<dynamic>? ?? [];
    final items = itemsData.map<BottomNavigationBarItem>((item) {
      if (item is Map<String, dynamic>) {
        return BottomNavigationBarItem(
          icon: _buildIcon(item['icon'], context),
          activeIcon: item['activeIcon'] != null
              ? _buildIcon(item['activeIcon'], context)
              : null,
          label: item['label'] as String?,
          tooltip: item['tooltip'] as String?,
          backgroundColor: parseColor(context.resolve(item['backgroundColor'])),
        );
      }
      return const BottomNavigationBarItem(
        icon: Icon(Icons.home),
        label: 'Item',
      );
    }).toList();

    // Extract action handler
    final onTap = properties['onTap'] as Map<String, dynamic>?;

    Widget bottomBar = BottomNavigationBar(
      items: items,
      currentIndex: currentIndex,
      elevation: elevation,
      type: type,
      fixedColor: fixedColor,
      backgroundColor: backgroundColor,
      iconSize: iconSize,
      selectedItemColor: selectedItemColor,
      unselectedItemColor: unselectedItemColor,
      selectedIconTheme: selectedIconTheme,
      unselectedIconTheme: unselectedIconTheme,
      selectedFontSize: selectedFontSize,
      unselectedFontSize: unselectedFontSize,
      selectedLabelStyle: selectedLabelStyle,
      unselectedLabelStyle: unselectedLabelStyle,
      showSelectedLabels: showSelectedLabels,
      showUnselectedLabels: showUnselectedLabels,
      enableFeedback: enableFeedback,
      onTap: onTap != null
          ? (index) {
              // Update state if bindTo is specified
              final path = properties['bindTo'] as String?;
              if (path != null) {
                context.setValue(path, index);
              }

              // Execute action with index
              final eventData = Map<String, dynamic>.from(onTap);
              if (eventData['value'] == '{{event.index}}') {
                eventData['value'] = index;
              }
              context.actionHandler.execute(eventData, context);
            }
          : null,
    );

    return bottomBar;
  }

  Widget _buildIcon(dynamic iconDef, RenderContext context) {
    if (iconDef == null) return const Icon(Icons.home);

    if (iconDef is Map<String, dynamic>) {
      return context.renderer.renderWidget(iconDef, context);
    } else if (iconDef is String) {
      return Icon(_parseIconData(iconDef));
    }

    return const Icon(Icons.home);
  }

  BottomNavigationBarType _parseBottomNavigationBarType(String? type) {
    switch (type) {
      case 'fixed':
        return BottomNavigationBarType.fixed;
      case 'shifting':
        return BottomNavigationBarType.shifting;
      default:
        return BottomNavigationBarType.fixed;
    }
  }

  IconThemeData? _parseIconThemeData(
      Map<String, dynamic>? data, RenderContext context) {
    if (data == null) return null;

    return IconThemeData(
      color: parseColor(context.resolve(data['color'])),
      size: data['size']?.toDouble(),
      opacity: data['opacity']?.toDouble(),
    );
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

  IconData _parseIconData(String iconName) {
    // Basic icon mapping
    switch (iconName) {
      case 'home':
        return Icons.home;
      case 'search':
        return Icons.search;
      case 'favorite':
        return Icons.favorite;
      case 'person':
        return Icons.person;
      case 'settings':
        return Icons.settings;
      default:
        return Icons.home;
    }
  }
}
