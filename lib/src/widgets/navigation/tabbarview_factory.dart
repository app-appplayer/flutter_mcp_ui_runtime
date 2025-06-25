import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../../renderer/render_context.dart';

/// Factory for tab bar view widget
class TabBarViewWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    final children = definition['children'] as List<dynamic>? ?? [];

    return TabBarView(
      physics: _resolveScrollPhysics(properties['physics']),
      dragStartBehavior:
          _resolveDragStartBehavior(properties['dragStartBehavior']),
      children: children
          .map((child) => context.buildWidget(child as Map<String, dynamic>))
          .toList(),
    );
  }

  ScrollPhysics? _resolveScrollPhysics(String? physics) {
    switch (physics) {
      case 'bounce':
        return const BouncingScrollPhysics();
      case 'clamp':
        return const ClampingScrollPhysics();
      case 'never':
        return const NeverScrollableScrollPhysics();
      default:
        return null;
    }
  }

  DragStartBehavior _resolveDragStartBehavior(String? behavior) {
    switch (behavior) {
      case 'down':
        return DragStartBehavior.down;
      case 'start':
        return DragStartBehavior.start;
      default:
        return DragStartBehavior.start;
    }
  }
}
