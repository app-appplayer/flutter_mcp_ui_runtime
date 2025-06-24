import 'package:flutter/material.dart';
import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for Timeline widgets
class TimelineWidgetFactory extends WidgetFactory {
  IconData _parseIcon(String iconName) {
    // Basic icon mapping
    switch (iconName) {
      case 'check':
        return Icons.check;
      case 'star':
        return Icons.star;
      case 'error':
        return Icons.error;
      case 'warning':
        return Icons.warning;
      case 'info':
        return Icons.info;
      case 'schedule':
        return Icons.schedule;
      case 'event':
        return Icons.event;
      case 'done':
        return Icons.done;
      case 'pending':
        return Icons.pending;
      case 'flag':
        return Icons.flag;
      default:
        return Icons.circle;
    }
  }
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    
    // Extract properties
    final items = context.resolve<List<dynamic>>(properties['items'] ?? []) as List<dynamic>? ?? [];
    final orientation = properties['orientation'] as String? ?? 'vertical';
    final lineColor = parseColor(context.resolve(properties['lineColor'])) ?? Colors.grey;
    final lineWidth = properties['lineWidth']?.toDouble() ?? 2.0;
    final nodeSize = properties['nodeSize']?.toDouble() ?? 20.0;
    final spacing = properties['spacing']?.toDouble() ?? 20.0;
    
    // Build timeline items
    final List<Widget> timelineItems = [];
    
    for (int i = 0; i < items.length; i++) {
      final item = items[i] as Map<String, dynamic>;
      final isLast = i == items.length - 1;
      
      // Extract item properties
      final title = context.resolve(item['title'] ?? '') as String;
      final subtitle = context.resolve(item['subtitle'] ?? '') as String?;
      final time = context.resolve(item['time'] ?? '') as String?;
      final icon = item['icon'] as String?;
      final color = parseColor(context.resolve(item['color'])) ?? Colors.blue;
      
      Widget timelineItem;
      
      if (orientation == 'vertical') {
        timelineItem = IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline line and node
              Column(
                children: [
                  // Node
                  Container(
                    width: nodeSize,
                    height: nodeSize,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: icon != null
                        ? Icon(
                            _parseIcon(icon),
                            size: nodeSize * 0.6,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  // Line
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: lineWidth,
                        color: lineColor,
                      ),
                    ),
                ],
              ),
              SizedBox(width: spacing),
              // Content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : spacing),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (time != null)
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        // Horizontal timeline
        timelineItem = IntrinsicWidth(
          child: Column(
            children: [
              // Timeline line and node
              Row(
                children: [
                  if (i != 0)
                    Expanded(
                      child: Container(
                        height: lineWidth,
                        color: lineColor,
                      ),
                    ),
                  // Node
                  Container(
                    width: nodeSize,
                    height: nodeSize,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: icon != null
                        ? Icon(
                            _parseIcon(icon),
                            size: nodeSize * 0.6,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        height: lineWidth,
                        color: lineColor,
                      ),
                    ),
                ],
              ),
              SizedBox(height: spacing),
              // Content
              Column(
                children: [
                  if (time != null)
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ],
          ),
        );
      }
      
      timelineItems.add(timelineItem);
    }
    
    Widget timeline;
    if (orientation == 'vertical') {
      timeline = Column(
        children: timelineItems,
      );
    } else {
      timeline = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: timelineItems,
        ),
      );
    }
    
    return applyCommonWrappers(timeline, properties, context);
  }
}