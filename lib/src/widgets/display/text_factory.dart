import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart' as core;

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for Text widgets
class TextWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);

    // Extract and resolve text value.
    // Canonical key is `text` per spec 17_Naming §17.3.2; `content` and `value`
    // are legacy aliases accepted for backward compatibility.
    final textValue = properties[core.PropertyKeys.text] ??
        properties[core.PropertyKeys.content] ??
        properties[core.PropertyKeys.value] ??
        '';
    var value = context.resolve<String>(textValue);

    // Apply text transform
    final textTransform =
        context.resolve<String?>(properties['textTransform']);
    if (textTransform != null) {
      switch (textTransform) {
        case 'uppercase':
          value = value.toUpperCase();
          break;
        case 'lowercase':
          value = value.toLowerCase();
          break;
        case 'capitalize':
          if (value.isNotEmpty) {
            value = value[0].toUpperCase() + value.substring(1);
          }
          break;
      }
    }

    // Resolve `variant` first (M3 typography role) so it can act as the
    // base TextStyle. Inline `style` then layers on top via `merge`.
    final variantValue =
        context.resolve(properties['variant']) as String?;
    final variantStyle = _resolveVariantStyle(variantValue, context);
    final inlineStyle = _parseTextStyle(
        properties[core.PropertyKeys.style], context);
    final TextStyle? mergedStyle = variantStyle == null
        ? inlineStyle
        : (inlineStyle == null
            ? variantStyle
            : variantStyle.merge(inlineStyle));

    // Build text widget
    Widget text = Text(
      value,
      style: mergedStyle,
      textAlign: _parseTextAlign(
          context.resolve(properties[core.PropertyKeys.textAlign])),
      textDirection:
          _parseTextDirection(context.resolve(properties['textDirection'])),
      overflow: _parseTextOverflow(context.resolve(properties['overflow'])),
      maxLines: context.resolve(properties[core.PropertyKeys.maxLines]) as int?,
      softWrap: context.resolve(properties['softWrap']) as bool? ?? true,
      textScaler: properties['textScaleFactor'] != null
          ? TextScaler.linear(
              parseDimension(context.resolve(properties['textScaleFactor'])) ?? 1.0)
          : null,
      semanticsLabel:
          context.resolve(properties['semanticsLabel']) as String? ??
              context.resolve(properties['ariaLabel'] ?? properties['aria-label']) as String?,
    );

    return applyCommonWrappers(text, properties, context);
  }

  /// Resolve an M3 typography role name to its theme-scoped [TextStyle].
  ///
  /// Accepts the canonical M3 names (`displayLarge` … `labelSmall`) and
  /// returns `null` for unknown values so the caller can fall back to
  /// the inline `style` block. Spec §5.4 + 1.3 widget table § 5.1.
  TextStyle? _resolveVariantStyle(String? variant, RenderContext context) {
    if (variant == null || variant.isEmpty) return null;
    return context.themeManager.getTextStyleValue(variant);
  }

  TextStyle? _parseTextStyle(dynamic style, RenderContext context) {
    if (style == null) return null;

    // String form — `style: "{{theme.typography.displayLarge}}"` is a
    // binding expression that resolves to the role's TextStyle map.
    // Run through the binding resolver first; if the result is a map,
    // re-enter the Map branch below.
    if (style is String) {
      final resolved = context.resolve<dynamic>(style);
      if (resolved is Map) {
        style = Map<String, dynamic>.from(resolved);
      } else {
        return null;
      }
    }

    if (style is Map<String, dynamic>) {
      final colorValue = style[core.PropertyKeys.color];
      final resolvedColor = context.resolve(colorValue);
      final parsedColor = parseColor(resolvedColor, context);

      return TextStyle(
        fontSize:
            parseDimension(context.resolve(style[core.PropertyKeys.fontSize])),
        fontWeight: _parseFontWeight(
            context.resolve(style[core.PropertyKeys.fontWeight])),
        fontStyle: _parseFontStyle(context.resolve(style['fontStyle'])),
        color: parsedColor,
        letterSpacing: parseDimension(context.resolve(style['letterSpacing'])),
        wordSpacing: parseDimension(context.resolve(style['wordSpacing'])),
        height: parseDimension(context.resolve(style['height'])),
        decoration: _parseTextDecoration(context.resolve(style['decoration'])),
        decorationColor: parseColor(context.resolve(style['decorationColor']), context),
        decorationStyle: _parseTextDecorationStyle(
            context.resolve(style['decorationStyle'])),
        decorationThickness:
            parseDimension(context.resolve(style['decorationThickness'])),
        fontFamily:
            context.resolve(style[core.PropertyKeys.fontFamily]) as String?,
        shadows: _parseShadows(style['shadows'], context),
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

  List<Shadow>? _parseShadows(dynamic shadows, RenderContext context) {
    if (shadows == null || shadows is! List) return null;

    return shadows.map((shadow) {
      if (shadow is Map<String, dynamic>) {
        final offset = shadow['offset'] as Map<String, dynamic>?;
        return Shadow(
          color: parseColor(context.resolve(shadow['color']), context) ?? Colors.black,
          offset: offset != null
              ? Offset(
                  parseDimension(context.resolve(offset['x'])) ?? 0,
                  parseDimension(context.resolve(offset['y'])) ?? 0,
                )
              : Offset.zero,
          blurRadius: parseDimension(context.resolve(shadow['blurRadius'])) ?? 0,
        );
      }
      return const Shadow();
    }).toList();
  }
}
