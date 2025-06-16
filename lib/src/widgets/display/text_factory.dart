import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart' as core;

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for Text widgets
class TextWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    
    // Extract and resolve text value  
    final content = properties[core.PropertyKeys.content] ?? properties[core.PropertyKeys.value] ?? '';
    print('TextWidgetFactory: content = $content');
    final value = context.resolve<String>(content);
    print('TextWidgetFactory: resolved value = $value');
    
    // Build text widget
    Widget text = Text(
      value,
      style: _parseTextStyle(properties[core.PropertyKeys.style], context),
      textAlign: _parseTextAlign(context.resolve(properties[core.PropertyKeys.textAlign])),
      textDirection: _parseTextDirection(context.resolve(properties['textDirection'])),
      overflow: _parseTextOverflow(context.resolve(properties['overflow'])),
      maxLines: context.resolve(properties[core.PropertyKeys.maxLines]) as int?,
      softWrap: context.resolve(properties['softWrap']) as bool? ?? true,
      textScaler: properties['textScaleFactor'] != null 
          ? TextScaler.linear(context.resolve(properties['textScaleFactor'])?.toDouble())
          : null,
    );
    
    return applyCommonWrappers(text, properties, context);
  }

  TextStyle? _parseTextStyle(dynamic style, RenderContext context) {
    if (style == null) return null;
    
    if (style is Map<String, dynamic>) {
      return TextStyle(
        fontSize: context.resolve(style[core.PropertyKeys.fontSize])?.toDouble(),
        fontWeight: _parseFontWeight(context.resolve(style[core.PropertyKeys.fontWeight])),
        fontStyle: _parseFontStyle(context.resolve(style['fontStyle'])),
        color: parseColor(context.resolve(style[core.PropertyKeys.color])),
        letterSpacing: context.resolve(style['letterSpacing'])?.toDouble(),
        wordSpacing: context.resolve(style['wordSpacing'])?.toDouble(),
        height: context.resolve(style['height'])?.toDouble(),
        decoration: _parseTextDecoration(context.resolve(style['decoration'])),
        decorationColor: parseColor(context.resolve(style['decorationColor'])),
        decorationStyle: _parseTextDecorationStyle(context.resolve(style['decorationStyle'])),
        fontFamily: context.resolve(style[core.PropertyKeys.fontFamily]) as String?,
      );
    }
    
    return null;
  }

  FontWeight? _parseFontWeight(dynamic value) {
    if (value == null) return null;
    
    if (value is String) {
      switch (value) {
        case 'thin':
        case 'w100':
          return FontWeight.w100;
        case 'extraLight':
        case 'w200':
          return FontWeight.w200;
        case 'light':
        case 'w300':
          return FontWeight.w300;
        case 'normal':
        case 'w400':
          return FontWeight.w400;
        case 'medium':
        case 'w500':
          return FontWeight.w500;
        case 'semiBold':
        case 'w600':
          return FontWeight.w600;
        case 'bold':
        case 'w700':
          return FontWeight.w700;
        case 'extraBold':
        case 'w800':
          return FontWeight.w800;
        case 'black':
        case 'w900':
          return FontWeight.w900;
        default:
          return null;
      }
    }
    
    if (value is int) {
      final index = (value ~/ 100) - 1;
      if (index >= 0 && index < FontWeight.values.length) {
        return FontWeight.values[index];
      }
      return null;
    }
    
    return null;
  }

  FontStyle? _parseFontStyle(String? value) {
    switch (value) {
      case 'italic':
        return FontStyle.italic;
      case 'normal':
        return FontStyle.normal;
      default:
        return null;
    }
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

  TextDirection? _parseTextDirection(String? value) {
    switch (value) {
      case 'ltr':
        return TextDirection.ltr;
      case 'rtl':
        return TextDirection.rtl;
      default:
        return null;
    }
  }

  TextOverflow? _parseTextOverflow(String? value) {
    switch (value) {
      case 'clip':
        return TextOverflow.clip;
      case 'fade':
        return TextOverflow.fade;
      case 'ellipsis':
        return TextOverflow.ellipsis;
      case 'visible':
        return TextOverflow.visible;
      default:
        return null;
    }
  }

  TextDecoration? _parseTextDecoration(String? value) {
    switch (value) {
      case 'none':
        return TextDecoration.none;
      case 'underline':
        return TextDecoration.underline;
      case 'overline':
        return TextDecoration.overline;
      case 'lineThrough':
        return TextDecoration.lineThrough;
      default:
        return null;
    }
  }

  TextDecorationStyle? _parseTextDecorationStyle(String? value) {
    switch (value) {
      case 'solid':
        return TextDecorationStyle.solid;
      case 'double':
        return TextDecorationStyle.double;
      case 'dotted':
        return TextDecorationStyle.dotted;
      case 'dashed':
        return TextDecorationStyle.dashed;
      case 'wavy':
        return TextDecorationStyle.wavy;
      default:
        return null;
    }
  }
}