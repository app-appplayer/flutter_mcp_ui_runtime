import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for TextFormField widgets
class TextFormFieldWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    
    // Extract properties
    final label = context.resolve<String?>(properties['label']);
    final hintText = context.resolve<String?>(properties['hintText']);
    final initialValue = context.resolve<String?>(properties['initialValue']);
    final enabled = properties['enabled'] as bool? ?? true;
    final obscureText = properties['obscureText'] as bool? ?? false;
    final maxLines = properties['maxLines'] as int?;
    final maxLength = properties['maxLength'] as int?;
    final keyboardType = _parseKeyboardType(properties['keyboardType']);
    final validator = properties['validator'] as String?;
    
    // Extract action handlers
    final onChanged = properties['onChanged'] as Map<String, dynamic>?;
    final onSubmitted = properties['onSubmitted'] as Map<String, dynamic>?;
    
    Widget textFormField = TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: const OutlineInputBorder(),
      ),
      enabled: enabled,
      obscureText: obscureText,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      validator: validator != null ? (value) {
        // Simple validation
        if (validator == 'required' && (value == null || value.isEmpty)) {
          return 'This field is required';
        }
        if (validator == 'email' && value != null && value.isNotEmpty) {
          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
            return 'Please enter a valid email';
          }
        }
        return null;
      } : null,
      onChanged: onChanged != null ? (value) {
        // Update state if bindTo is specified
        final path = properties['bindTo'] as String?;
        if (path != null) {
          context.setValue(path, value);
        }
        
        // Execute action
        final eventData = Map<String, dynamic>.from(onChanged);
        if (eventData['value'] == '{{event.value}}') {
          eventData['value'] = value;
        }
        context.actionHandler.execute(eventData, context);
      } : null,
      onFieldSubmitted: onSubmitted != null ? (value) {
        final eventData = Map<String, dynamic>.from(onSubmitted);
        if (eventData['value'] == '{{event.value}}') {
          eventData['value'] = value;
        }
        context.actionHandler.execute(eventData, context);
      } : null,
    );
    
    return applyCommonWrappers(textFormField, properties, context);
  }

  TextInputType? _parseKeyboardType(String? value) {
    switch (value) {
      case 'text':
        return TextInputType.text;
      case 'number':
        return TextInputType.number;
      case 'email':
        return TextInputType.emailAddress;
      case 'phone':
        return TextInputType.phone;
      case 'url':
        return TextInputType.url;
      case 'multiline':
        return TextInputType.multiline;
      default:
        return null;
    }
  }
}