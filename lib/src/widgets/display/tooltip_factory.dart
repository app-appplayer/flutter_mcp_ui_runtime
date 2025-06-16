import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for Tooltip widgets
class TooltipWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    
    // Extract properties
    final message = context.resolve<String>(properties['message']) as String? ?? '';
    final richMessage = properties['richMessage'] != null 
        ? _buildInlineSpan(properties['richMessage'], context)
        : null;
    final height = properties['height']?.toDouble();
    final padding = parseEdgeInsets(properties['padding']);
    final margin = parseEdgeInsets(properties['margin']);
    final verticalOffset = properties['verticalOffset']?.toDouble();
    final preferBelow = properties['preferBelow'] as bool?;
    final excludeFromSemantics = properties['excludeFromSemantics'] as bool?;
    final decoration = _parseDecoration(properties['decoration'], context);
    final textStyle = _parseTextStyle(properties['textStyle'], context);
    final textAlign = _parseTextAlign(properties['textAlign']);
    final waitDuration = properties['waitDuration'] != null
        ? Duration(milliseconds: properties['waitDuration'])
        : null;
    final showDuration = properties['showDuration'] != null
        ? Duration(milliseconds: properties['showDuration'])
        : null;
    final triggerMode = _parseTriggerMode(properties['triggerMode']);
    final enableFeedback = properties['enableFeedback'] as bool?;
    
    // Extract child widget
    Widget? child;
    final childDef = properties['child'] as Map<String, dynamic>?;
    if (childDef != null) {
      child = context.renderer.renderWidget(childDef, context);
    }
    
    Widget tooltip = Tooltip(
      message: richMessage != null ? '' : message,
      richMessage: richMessage,
      height: height,
      padding: padding,
      margin: margin,
      verticalOffset: verticalOffset,
      preferBelow: preferBelow,
      excludeFromSemantics: excludeFromSemantics,
      decoration: decoration,
      textStyle: textStyle,
      textAlign: textAlign,
      waitDuration: waitDuration,
      showDuration: showDuration,
      triggerMode: triggerMode,
      enableFeedback: enableFeedback,
      child: child ?? const Icon(Icons.info),
    );
    
    return applyCommonWrappers(tooltip, properties, context);
  }

  InlineSpan? _buildInlineSpan(dynamic spanData, RenderContext context) {
    if (spanData == null) return null;
    
    if (spanData is Map<String, dynamic>) {
      final text = context.resolve<String?>(spanData['text']);
      final style = _parseTextStyle(spanData['style'], context);
      final children = spanData['children'] as List<dynamic>?;
      
      if (children != null && children.isNotEmpty) {
        return TextSpan(
          text: text,
          style: style,
          children: children.map((child) => 
            _buildInlineSpan(child, context) ?? const TextSpan()
          ).toList(),
        );
      }
      
      return TextSpan(
        text: text,
        style: style,
      );
    }
    
    return null;
  }

  TextStyle? _parseTextStyle(dynamic style, RenderContext context) {
    if (style == null) return null;
    
    if (style is Map<String, dynamic>) {
      return TextStyle(
        color: parseColor(context.resolve(style['color'])),
        fontSize: style['fontSize']?.toDouble(),
        fontWeight: style['fontWeight'] == 'bold' ? FontWeight.bold : null,
      );
    }
    
    return null;
  }

  TextAlign? _parseTextAlign(String? value) {
    switch (value) {
      case 'left':
        return TextAlign.left;
      case 'right':
        return TextAlign.right;
      case 'center':
        return TextAlign.center;
      case 'justify':
        return TextAlign.justify;
      case 'start':
        return TextAlign.start;
      case 'end':
        return TextAlign.end;
      default:
        return null;
    }
  }

  TooltipTriggerMode? _parseTriggerMode(String? value) {
    switch (value) {
      case 'longPress':
        return TooltipTriggerMode.longPress;
      case 'tap':
        return TooltipTriggerMode.tap;
      case 'manual':
        return TooltipTriggerMode.manual;
      default:
        return null;
    }
  }

  Decoration? _parseDecoration(dynamic decoration, RenderContext context) {
    if (decoration == null) return null;
    
    if (decoration is Map<String, dynamic>) {
      return BoxDecoration(
        color: parseColor(context.resolve(decoration['color'])),
        borderRadius: _parseBorderRadius(decoration['borderRadius']),
        boxShadow: _parseBoxShadow(decoration['shadow'], context),
      );
    }
    
    return null;
  }

  BorderRadius? _parseBorderRadius(dynamic value) {
    if (value == null) return null;
    
    if (value is num) {
      return BorderRadius.circular(value.toDouble());
    }
    
    return null;
  }

  List<BoxShadow>? _parseBoxShadow(dynamic shadow, RenderContext context) {
    if (shadow == null) return null;
    
    if (shadow is Map<String, dynamic>) {
      return [
        BoxShadow(
          color: parseColor(context.resolve(shadow['color'])) ?? Colors.black,
          blurRadius: shadow['blur']?.toDouble() ?? 0,
          spreadRadius: shadow['spread']?.toDouble() ?? 0,
          offset: Offset(
            shadow['offsetX']?.toDouble() ?? 0,
            shadow['offsetY']?.toDouble() ?? 0,
          ),
        ),
      ];
    }
    
    return null;
  }
}