import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for CircleAvatar widgets
class AvatarWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);

    // Extract properties
    final radius = properties['radius']?.toDouble() ?? 20.0;
    final backgroundColor =
        parseColor(context.resolve(properties['backgroundColor']));
    final foregroundColor =
        parseColor(context.resolve(properties['foregroundColor']));
    final backgroundImage = properties['backgroundImage'] as String?;
    final text = context.resolve<String?>(properties['text']);
    final icon = properties['icon'] as String?;

    // Build child widget
    Widget? child;
    if (text != null && text.isNotEmpty) {
      child = Text(
        text.length > 2
            ? text.substring(0, 2).toUpperCase()
            : text.toUpperCase(),
        style: TextStyle(color: foregroundColor),
      );
    } else if (icon != null) {
      child = Icon(
        _parseIconData(icon),
        color: foregroundColor,
        size: radius,
      );
    }

    // Build background image
    ImageProvider? backgroundImageProvider;
    if (backgroundImage != null && backgroundImage.isNotEmpty) {
      if (backgroundImage.startsWith('http://') ||
          backgroundImage.startsWith('https://')) {
        backgroundImageProvider = NetworkImage(backgroundImage);
      } else if (backgroundImage.startsWith('assets/')) {
        backgroundImageProvider = AssetImage(backgroundImage);
      }
    }

    Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      backgroundImage: backgroundImageProvider,
      child: child,
    );

    return applyCommonWrappers(avatar, properties, context);
  }

  IconData _parseIconData(String iconName) {
    // Reuse icon mapping from icon_factory
    switch (iconName) {
      case 'person':
        return Icons.person;
      case 'group':
        return Icons.group;
      case 'account_circle':
        return Icons.account_circle;
      default:
        return Icons.person;
    }
  }
}
