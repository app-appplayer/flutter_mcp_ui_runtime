import 'package:flutter/material.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart' as core;

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for Button widgets
class ButtonWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);

    // Extract button properties
    final label =
        context.resolve<String>(properties[core.PropertyKeys.label] ?? '');
    final iconValue = properties[core.PropertyKeys.icon];
    final icon = iconValue is String ? iconValue : null;
    final iconPosValue = properties['iconPosition'];
    final iconPosition = iconPosValue is String ? iconPosValue : 'start';

    // MCP UI DSL v1.0 uses 'variant' property for button styles
    final variantValue = properties['variant'];
    final variant = variantValue is String ? variantValue : 'elevated';

    final sizeValue = properties['size'];
    final size = sizeValue is String ? sizeValue : 'medium';
    final fullWidthValue = properties['fullWidth'];
    final fullWidth = fullWidthValue is bool ? fullWidthValue : false;
    final loading = context.resolve<bool>(properties['loading'] ?? false);
    final enabled = context.resolve(properties['enabled'] ?? true) as bool;

    // Extract style properties from the properties directly
    final backgroundColor = properties['backgroundColor'];
    final foregroundColor = properties['foregroundColor'];
    final elevation = properties['elevation'];
    final borderColor = properties['borderColor'];
    final borderWidth = properties['borderWidth'];

    // MCP UI DSL v1.0 event handlers
    final onClick =
        properties[core.PropertyKeys.click] as Map<String, dynamic>?;
    final onDoubleClick =
        properties[core.PropertyKeys.doubleClick] as Map<String, dynamic>?;
    final onLongPress =
        properties[core.PropertyKeys.longPress] as Map<String, dynamic>?;
    final submit = properties['submit'] as Map<String, dynamic>?;

    // Use click or submit action
    final primaryAction = onClick ?? submit;

    // Build button content
    Widget buttonChild;
    if (loading) {
      buttonChild = _buildLoadingContent(size);
    } else if (icon != null) {
      buttonChild = _buildIconContent(label, icon, iconPosition);
    } else {
      buttonChild = Text(label);
    }

    // Get aria-label for semantic override
    final ariaLabel = context.resolve<String?>(properties['aria-label']);

    // Build button
    Widget button;

    // Special case for icon variant - create IconButton
    if (variant == 'icon' && icon != null) {
      button = IconButton(
        icon: Icon(_parseIcon(icon)),
        onPressed: !loading && enabled
            ? (primaryAction != null
                ? () async {
                    await context.handleAction(primaryAction);
                  }
                : () {}) // Empty handler when no action but enabled
            : null,
        color: foregroundColor != null ? parseColor(foregroundColor) : null,
        iconSize: _getIconSize(size),
        tooltip: ariaLabel ?? label,
      );
    } else {
      button = _buildButton(
        style: variant,
        child: buttonChild,
        onPressed: !loading && enabled
            ? (primaryAction != null
                ? () async {
                    // Handle special submit action
                    if (primaryAction['type'] == 'submit') {
                      // Look for form key and submit action in parent context
                      final formKey =
                          context.getValue<GlobalKey<FormState>>('_formKey');
                      final submitAction = context
                          .getValue<Map<String, dynamic>>('_formSubmitAction');

                      if (formKey != null && formKey.currentState != null) {
                        final formState = formKey.currentState!;
                        if (formState.validate()) {
                          formState.save();
                          // Execute the form's submit action if available
                          if (submitAction != null) {
                            await context.handleAction(submitAction);
                          }
                        }
                      }
                    } else {
                      // Regular action
                      // Regular action - use existing context
                      await context.handleAction(primaryAction);
                    }
                  }
                : () {}) // Empty handler when no action but enabled
            : null,
        size: size,
        semanticLabel: ariaLabel,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        elevation: elevation,
        borderColor: borderColor,
        borderWidth: borderWidth,
      );
    }

    // Wrap with gesture detector for additional events
    if (onDoubleClick != null || onLongPress != null) {
      button = GestureDetector(
        onDoubleTap: onDoubleClick != null && !loading && enabled
            ? () async => await context.handleAction(onDoubleClick)
            : null,
        onLongPress: onLongPress != null && !loading && enabled
            ? () async => await context.handleAction(onLongPress)
            : null,
        child: button,
      );
    }

    // Apply full width if needed
    if (fullWidth) {
      button = SizedBox(
        width: double.infinity,
        child: button,
      );
    }

    // If aria-label was already applied, remove it from properties to avoid double application
    final propsForWrapper = ariaLabel != null
        ? (Map<String, dynamic>.from(properties)..remove('aria-label'))
        : properties;

    return applyCommonWrappers(button, propsForWrapper, context);
  }

  Widget _buildButton({
    required String style,
    required Widget child,
    required VoidCallback? onPressed,
    required String size,
    String? semanticLabel,
    dynamic backgroundColor,
    dynamic foregroundColor,
    dynamic elevation,
    dynamic borderColor,
    dynamic borderWidth,
  }) {
    final padding = _getButtonPadding(size);

    switch (style) {
      case 'elevated':
        final button = ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            padding: padding,
            backgroundColor:
                backgroundColor != null ? parseColor(backgroundColor) : null,
            foregroundColor:
                foregroundColor != null ? parseColor(foregroundColor) : null,
            elevation: elevation?.toDouble(),
            side: borderColor != null || borderWidth != null
                ? BorderSide(
                    color: borderColor != null
                        ? parseColor(borderColor)!
                        : Colors.transparent,
                    width: borderWidth?.toDouble() ?? 1.0,
                  )
                : null,
          ),
          child: child,
        );
        return semanticLabel != null
            ? Semantics(
                label: semanticLabel,
                button: true,
                child: ExcludeSemantics(child: button),
              )
            : button;

      case 'filled':
        final button = FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            padding: padding,
            backgroundColor:
                backgroundColor != null ? parseColor(backgroundColor) : null,
            foregroundColor:
                foregroundColor != null ? parseColor(foregroundColor) : null,
            elevation: elevation?.toDouble(),
            side: borderColor != null || borderWidth != null
                ? BorderSide(
                    color: borderColor != null
                        ? parseColor(borderColor)!
                        : Colors.transparent,
                    width: borderWidth?.toDouble() ?? 1.0,
                  )
                : null,
          ),
          child: child,
        );
        return semanticLabel != null
            ? Semantics(
                label: semanticLabel,
                button: true,
                child: ExcludeSemantics(child: button),
              )
            : button;

      case 'outlined':
        final button = OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: padding,
            backgroundColor:
                backgroundColor != null ? parseColor(backgroundColor) : null,
            foregroundColor:
                foregroundColor != null ? parseColor(foregroundColor) : null,
            elevation: elevation?.toDouble(),
            side: borderColor != null || borderWidth != null
                ? BorderSide(
                    color: borderColor != null
                        ? parseColor(borderColor)!
                        : Colors.grey,
                    width: borderWidth?.toDouble() ?? 1.0,
                  )
                : null,
          ),
          child: child,
        );
        return semanticLabel != null
            ? Semantics(
                label: semanticLabel,
                button: true,
                child: ExcludeSemantics(child: button),
              )
            : button;

      case 'text':
        final button = TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: padding,
            backgroundColor:
                backgroundColor != null ? parseColor(backgroundColor) : null,
            foregroundColor:
                foregroundColor != null ? parseColor(foregroundColor) : null,
            elevation: elevation?.toDouble(),
            side: borderColor != null || borderWidth != null
                ? BorderSide(
                    color: borderColor != null
                        ? parseColor(borderColor)!
                        : Colors.transparent,
                    width: borderWidth?.toDouble() ?? 1.0,
                  )
                : null,
          ),
          child: child,
        );
        return semanticLabel != null
            ? Semantics(
                label: semanticLabel,
                button: true,
                child: ExcludeSemantics(child: button),
              )
            : button;

      default:
        final button = ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            padding: padding,
            backgroundColor:
                backgroundColor != null ? parseColor(backgroundColor) : null,
            foregroundColor:
                foregroundColor != null ? parseColor(foregroundColor) : null,
            elevation: elevation?.toDouble(),
            side: borderColor != null || borderWidth != null
                ? BorderSide(
                    color: borderColor != null
                        ? parseColor(borderColor)!
                        : Colors.transparent,
                    width: borderWidth?.toDouble() ?? 1.0,
                  )
                : null,
          ),
          child: child,
        );
        return semanticLabel != null
            ? Semantics(
                label: semanticLabel,
                button: true,
                child: ExcludeSemantics(child: button),
              )
            : button;
    }
  }

  Widget _buildLoadingContent(String size) {
    final indicatorSize = _getLoadingSize(size);
    return SizedBox(
      width: indicatorSize,
      height: indicatorSize,
      child: const CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }

  Widget _buildIconContent(String label, String iconName, String position) {
    final icon = Icon(_parseIcon(iconName), size: 18);

    if (label.isEmpty) {
      return icon;
    }

    const spacing = SizedBox(width: 8);

    if (position == 'end') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          spacing,
          icon,
        ],
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          spacing,
          Text(label),
        ],
      );
    }
  }

  EdgeInsets _getButtonPadding(String size) {
    switch (size) {
      case 'small':
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
      case 'large':
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
      case 'medium':
      default:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    }
  }

  double _getLoadingSize(String size) {
    switch (size) {
      case 'small':
        return 14;
      case 'large':
        return 24;
      case 'medium':
      default:
        return 18;
    }
  }

  double _getIconSize(String size) {
    switch (size) {
      case 'small':
        return 18;
      case 'large':
        return 28;
      case 'medium':
      default:
        return 24;
    }
  }

  IconData _parseIcon(String iconName) {
    // This is a simplified icon mapping
    // In a real implementation, you would have a comprehensive icon mapping
    switch (iconName) {
      case 'add':
        return Icons.add;
      case 'edit':
        return Icons.edit;
      case 'delete':
        return Icons.delete;
      case 'save':
        return Icons.save;
      case 'close':
        return Icons.close;
      case 'check':
        return Icons.check;
      case 'arrow_back':
        return Icons.arrow_back;
      case 'arrow_forward':
        return Icons.arrow_forward;
      case 'refresh':
        return Icons.refresh;
      case 'search':
        return Icons.search;
      case 'settings':
        return Icons.settings;
      case 'home':
        return Icons.home;
      case 'star':
        return Icons.star;
      default:
        return Icons.circle;
    }
  }
}
