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
    final label = context.resolve<String>(properties[core.PropertyKeys.label] ?? '');
    final icon = properties[core.PropertyKeys.icon] as String?;
    final iconPosition = properties['iconPosition'] as String? ?? 'start';
    final style = properties[core.PropertyKeys.style] as String? ?? 'elevated';
    final size = properties['size'] as String? ?? 'medium';
    final fullWidth = properties['fullWidth'] as bool? ?? false;
    final loading = context.resolve<bool>(properties['loading'] ?? false);
    final enabled = context.resolve(properties['enabled'] ?? true) as bool;
    final onTap = properties[core.PropertyKeys.onTap] as Map<String, dynamic>?;
    
    // Build button content
    Widget buttonChild;
    if (loading) {
      buttonChild = _buildLoadingContent(size);
    } else if (icon != null) {
      buttonChild = _buildIconContent(label, icon, iconPosition);
    } else {
      buttonChild = Text(label);
    }
    
    // Build button
    Widget button = _buildButton(
      style: style,
      child: buttonChild,
      onPressed: onTap != null && !loading && enabled
          ? () async => await context.actionHandler.execute(onTap, context)
          : null,
      size: size,
    );
    
    // Apply full width if needed
    if (fullWidth) {
      button = SizedBox(
        width: double.infinity,
        child: button,
      );
    }
    
    return applyCommonWrappers(button, properties, context);
  }

  Widget _buildButton({
    required String style,
    required Widget child,
    required VoidCallback? onPressed,
    required String size,
  }) {
    final padding = _getButtonPadding(size);
    
    switch (style) {
      case 'elevated':
        return ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            padding: padding,
          ),
          child: child,
        );
      
      case 'filled':
        return FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            padding: padding,
          ),
          child: child,
        );
      
      case 'outlined':
        return OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: padding,
          ),
          child: child,
        );
      
      case 'text':
        return TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: padding,
          ),
          child: child,
        );
      
      default:
        return ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            padding: padding,
          ),
          child: child,
        );
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
      default:
        return Icons.circle;
    }
  }
}