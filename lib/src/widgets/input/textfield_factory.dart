import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for TextField widgets
class TextFieldWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    
    // Extract properties
    final hint = context.resolve<String?>(properties['hint']) ?? 
                context.resolve<String?>(properties['placeholder']) ?? '';
    final label = properties['label'] as String?;
    final helperText = properties['helperText'] as String?;
    final prefixIcon = properties['prefixIcon'] as String?;
    final obscureText = properties['obscureText'] as bool? ?? false;
    final enabled = properties['enabled'] as bool? ?? true;
    final readOnly = properties['readOnly'] as bool? ?? false;
    final maxLines = properties['maxLines'] as int? ?? 1;
    final maxLength = properties['maxLength'] as int?;
    final keyboardType = _parseKeyboardType(properties['keyboardType']);
    final textInputAction = _parseTextInputAction(properties['textInputAction']);
    final onChange = properties['onChange'] as Map<String, dynamic>?;
    final onSubmit = properties['onSubmit'] as Map<String, dynamic>?;
    
    // Get initial value from binding or value property
    final bindingPath = properties['binding'] as String?;
    String initialValue = '';
    if (bindingPath != null) {
      initialValue = context.getState(bindingPath)?.toString() ?? '';
    } else {
      initialValue = context.resolve<String>(properties['value'] ?? '');
    }
    
    // Create text editing controller with initial value
    final controller = TextEditingController(text: initialValue);
    
    // Build text field
    Widget textField = TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        labelText: label,
        helperText: helperText,
        prefixIcon: prefixIcon != null ? Icon(_parseIcon(prefixIcon)) : null,
        border: const OutlineInputBorder(),
        counterText: maxLength != null ? null : '',
      ),
      obscureText: obscureText,
      enabled: enabled,
      readOnly: readOnly,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: (newValue) {
        // Update state if binding is specified
        final path = properties['binding'] as String?;
        if (path != null) {
          context.setValue(path, newValue);
        }
        
        // Execute action if onChange is specified
        if (onChange != null) {
          context.actionHandler.execute(onChange, context);
        }
      },
      onSubmitted: (newValue) {
        // Update state if binding is specified
        final path = properties['binding'] as String?;
        if (path != null) {
          context.setValue(path, newValue);
        }
        
        // Execute action if onSubmit is specified
        if (onSubmit != null) {
          context.actionHandler.execute(onSubmit, context);
        }
      },
    );
    
    return applyCommonWrappers(textField, properties, context);
  }

  TextInputType _parseKeyboardType(String? value) {
    switch (value) {
      case 'text':
        return TextInputType.text;
      case 'number':
        return TextInputType.number;
      case 'phone':
        return TextInputType.phone;
      case 'email':
        return TextInputType.emailAddress;
      case 'url':
        return TextInputType.url;
      case 'multiline':
        return TextInputType.multiline;
      case 'datetime':
        return TextInputType.datetime;
      default:
        return TextInputType.text;
    }
  }

  TextInputAction _parseTextInputAction(String? value) {
    switch (value) {
      case 'done':
        return TextInputAction.done;
      case 'go':
        return TextInputAction.go;
      case 'next':
        return TextInputAction.next;
      case 'search':
        return TextInputAction.search;
      case 'send':
        return TextInputAction.send;
      default:
        return TextInputAction.done;
    }
  }

  IconData _parseIcon(String iconName) {
    // This is a simplified icon mapping
    switch (iconName) {
      case 'person':
        return Icons.person;
      case 'email':
        return Icons.email;
      case 'lock':
        return Icons.lock;
      case 'search':
        return Icons.search;
      case 'phone':
        return Icons.phone;
      case 'visibility':
        return Icons.visibility;
      case 'visibility_off':
        return Icons.visibility_off;
      default:
        return Icons.circle;
    }
  }
}