import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for DropdownButton widgets
class DropdownWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    
    // Extract label if present
    final label = properties['label'] as String?;
    
    // Extract properties
    final binding = properties['binding'] as String?;
    final value = binding != null 
        ? context.resolve("{{$binding}}")
        : context.resolve(properties['value']);
    final items = context.resolve<List<dynamic>>(properties['items']) as List<dynamic>? ?? [];
    final hint = properties['hint'] as String?;
    final disabledHint = properties['disabledHint'] as String?;
    final elevation = properties['elevation'] as int? ?? 8;
    final style = _parseTextStyle(properties['style'], context);
    final underline = properties['underline'] as bool? ?? true;
    final iconSize = properties['iconSize']?.toDouble() ?? 24.0;
    final isExpanded = properties['isExpanded'] as bool? ?? false;
    final itemHeight = properties['itemHeight']?.toDouble();
    
    // Extract action handler - MCP UI DSL v1.0 spec
    final onChange = properties['change'] as Map<String, dynamic>?;
    
    // Build dropdown items
    final dropdownItems = items.map<DropdownMenuItem<dynamic>>((item) {
      if (item is Map<String, dynamic>) {
        return DropdownMenuItem(
          value: item['value'],
          child: Text(item['text']?.toString() ?? item['label']?.toString() ?? item['value']?.toString() ?? ''),
        );
      } else {
        return DropdownMenuItem(
          value: item,
          child: Text(item.toString()),
        );
      }
    }).toList();
    
    
    Widget dropdown = DropdownButton<dynamic>(
      value: value,
      items: dropdownItems,
      hint: hint != null ? Text(hint) : null,
      disabledHint: disabledHint != null ? Text(disabledHint) : null,
      onChanged: onChange != null || binding != null ? (newValue) {
        // Update state if binding is specified
        if (binding != null) {
          context.setValue(binding, newValue);
        }
        
        // Find the index of the selected item
        int? index;
        for (int i = 0; i < items.length; i++) {
          final item = items[i];
          if (item is Map<String, dynamic>) {
            if (item['value'] == newValue) {
              index = i;
              break;
            }
          } else if (item == newValue) {
            index = i;
            break;
          }
        }
        
        // Execute action if provided with event context
        if (onChange != null) {
          final eventContext = context.createChildContext(
            variables: {
              'event': {
                'value': newValue,
                'index': index,
                'type': 'change',
              },
            },
          );
          context.actionHandler.execute(onChange, eventContext);
        }
      } : null,
      elevation: elevation,
      style: style,
      underline: underline ? null : Container(),
      iconSize: iconSize,
      isExpanded: isExpanded,
      itemHeight: itemHeight,
    );
    
    // Wrap with label if provided
    if (label != null) {
      dropdown = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          dropdown,
        ],
      );
    }
    
    return applyCommonWrappers(dropdown, properties, context);
  }

  TextStyle? _parseTextStyle(Map<String, dynamic>? style, RenderContext context) {
    if (style == null) return null;
    
    return TextStyle(
      color: parseColor(context.resolve(style['color'])),
      fontSize: style['fontSize']?.toDouble(),
      fontWeight: _parseFontWeight(style['fontWeight']),
      fontStyle: style['italic'] == true ? FontStyle.italic : FontStyle.normal,
      letterSpacing: style['letterSpacing']?.toDouble(),
      wordSpacing: style['wordSpacing']?.toDouble(),
      height: style['height']?.toDouble(),
    );
  }

  FontWeight? _parseFontWeight(String? value) {
    switch (value) {
      case 'bold':
        return FontWeight.bold;
      case 'w100':
        return FontWeight.w100;
      case 'w200':
        return FontWeight.w200;
      case 'w300':
        return FontWeight.w300;
      case 'w400':
        return FontWeight.w400;
      case 'w500':
        return FontWeight.w500;
      case 'w600':
        return FontWeight.w600;
      case 'w700':
        return FontWeight.w700;
      case 'w800':
        return FontWeight.w800;
      case 'w900':
        return FontWeight.w900;
      default:
        return null;
    }
  }
}