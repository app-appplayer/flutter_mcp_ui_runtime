import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';
import '../../validation/validation_engine.dart';
import '../../utils/debounce.dart';

/// Factory for TextField widgets
class TextFieldWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);

    // Check if debouncing is enabled
    final debounceDelay = properties['debounce'] as int?;

    if (debounceDelay != null && debounceDelay > 0) {
      return _DebouncedTextField(
        definition: definition,
        context: context,
        debounceDelay: debounceDelay,
      );
    }

    return _buildTextField(definition, context);
  }

  Widget _buildTextField(
      Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);

    // Extract properties
    final hint = context.resolve<String?>(properties['hint']) ??
        context.resolve<String?>(properties['placeholder']) ??
        '';
    final label = properties['label'] as String?;
    final helperText = properties['helperText'] as String?;
    final prefixIcon = properties['prefixIcon'] as String?;
    final obscureText = properties['obscureText'] as bool? ?? false;
    final enabled = properties['enabled'] as bool? ?? true;
    final readOnly = properties['readOnly'] as bool? ?? false;
    final maxLines = properties['maxLines'] as int? ?? 1;
    final maxLength = properties['maxLength'] as int?;
    final keyboardType = _parseKeyboardType(properties['keyboardType']);
    final textInputAction =
        _parseTextInputAction(properties['textInputAction']);

    // Parse validation rules if provided
    final validationDef = properties['validation'];
    final validationRules = ValidationEngine.parseValidation(validationDef);
    final hasValidation = validationRules.isNotEmpty;

    // Handle error state
    // The 'error' property can be either a boolean (to show error state) or a string (the error message)
    final errorValue = context.resolve<dynamic>(properties['error']);
    final String? errorText;
    if (errorValue is String && errorValue.isNotEmpty) {
      errorText = errorValue;
    } else if (errorValue is bool && errorValue) {
      errorText = context.resolve<String?>(properties['errorText']);
    } else {
      errorText = null;
    }

    // Get event handlers - MCP UI DSL v1.0 spec
    final changeAction = properties['change'] as Map<String, dynamic>?;
    final submitAction = properties['submit'] as Map<String, dynamic>?;
    final blurAction = properties['blur'] as Map<String, dynamic>?;

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

    // Parse style
    TextStyle? style;
    final styleDef = properties['style'];
    if (styleDef is Map<String, dynamic>) {
      style = TextStyle(
        fontSize: context.resolve<num?>(styleDef['fontSize'])?.toDouble(),
        fontWeight: _parseFontWeight(styleDef['fontWeight']),
        fontStyle: styleDef['fontStyle'] == 'italic' ? FontStyle.italic : null,
        color: parseColor(context.resolve(styleDef['color'])),
        letterSpacing:
            context.resolve<num?>(styleDef['letterSpacing'])?.toDouble(),
        wordSpacing: context.resolve<num?>(styleDef['wordSpacing'])?.toDouble(),
        height: context.resolve<num?>(styleDef['height'])?.toDouble(),
      );
    }

    // Build text field - always use TextField for consistency with tests
    Widget textField = TextField(
      controller: controller,
      style: style,
      decoration: InputDecoration(
        hintText: hint,
        labelText: label,
        helperText: helperText,
        prefixIcon: prefixIcon != null ? Icon(_parseIcon(prefixIcon)) : null,
        border: const OutlineInputBorder(),
        counterText: maxLength != null ? null : '',
        errorText: errorText,
      ),
      obscureText: obscureText,
      enabled: enabled,
      readOnly: readOnly,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: (newValue) {
        // Validate if rules are defined
        if (hasValidation) {
          ValidationEngine.validate(newValue, validationRules);
          // Validation result will be used later if needed
        }

        // Update state if binding is specified
        final path = properties['binding'] as String?;
        if (path != null) {
          context.setValue(path, newValue);
        }

        // Execute action if change is specified
        if (changeAction != null) {
          // Create a child context with event data
          final eventContext = context.createChildContext(
            variables: {
              'event': {
                'value': newValue,
                'type': 'change',
              },
            },
          );
          eventContext.handleAction(changeAction);
        }
      },
      onSubmitted: (newValue) {
        // Update state if binding is specified
        final path = properties['binding'] as String?;
        if (path != null) {
          context.setValue(path, newValue);
        }

        // Execute action if submit is specified
        if (submitAction != null) {
          // Create a child context with event data
          final eventContext = context.createChildContext(
            variables: {
              'event': {
                'value': newValue,
                'type': 'submit',
              },
            },
          );
          eventContext.handleAction(submitAction);
        }
      },
    );

    // Wrap in Focus widget if blur action is needed
    if (blurAction != null) {
      textField = Focus(
        onFocusChange: (hasFocus) {
          if (!hasFocus) {
            // Field lost focus (blur event)
            // Create a child context with event data
            final eventContext = context.createChildContext(
              variables: {
                'event': {
                  'value': controller.text,
                  'type': 'blur',
                },
              },
            );
            eventContext.handleAction(blurAction);
          }
        },
        child: textField,
      );
    }

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
      case 'emailAddress':
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

  FontWeight? _parseFontWeight(String? weight) {
    switch (weight) {
      case 'bold':
        return FontWeight.bold;
      case 'w100':
        return FontWeight.w100;
      case 'w200':
        return FontWeight.w200;
      case 'w300':
        return FontWeight.w300;
      case 'w400':
      case 'normal':
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

/// Debounced text field widget for performance optimization
class _DebouncedTextField extends StatefulWidget {
  final Map<String, dynamic> definition;
  final RenderContext context;
  final int debounceDelay;

  const _DebouncedTextField({
    required this.definition,
    required this.context,
    required this.debounceDelay,
  });

  @override
  State<_DebouncedTextField> createState() => _DebouncedTextFieldState();
}

class _DebouncedTextFieldState extends State<_DebouncedTextField> {
  late TextEditingController _controller;
  late Debouncer _debouncer;
  String? _lastValue;

  @override
  void initState() {
    super.initState();

    final properties = widget.context.renderer.widgetRegistry
        .get('TextField')!
        .extractProperties(widget.definition);

    // Get initial value
    final bindingPath = properties['binding'] as String?;
    String initialValue = '';
    if (bindingPath != null) {
      initialValue = widget.context.getState(bindingPath)?.toString() ?? '';
    } else {
      initialValue = widget.context.resolve<String>(properties['value'] ?? '');
    }

    _controller = TextEditingController(text: initialValue);
    _lastValue = initialValue;
    _debouncer = Debouncer(milliseconds: widget.debounceDelay);
  }

  @override
  void dispose() {
    _controller.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  void _handleChange(String newValue) {
    final properties = widget.context.renderer.widgetRegistry
        .get('TextField')!
        .extractProperties(widget.definition);

    // Update local value immediately for responsive UI
    setState(() {
      _lastValue = newValue;
    });

    // Debounce the actual state update and action execution
    _debouncer.run(() {
      // Parse validation rules if provided
      final validationDef = properties['validation'];
      final validationRules = ValidationEngine.parseValidation(validationDef);
      if (validationRules.isNotEmpty) {
        ValidationEngine.validate(newValue, validationRules);
      }

      // Update state if binding is specified
      final path = properties['binding'] as String?;
      if (path != null) {
        widget.context.setValue(path, newValue);
      }

      // Execute action if change is specified
      final changeAction = properties['change'] as Map<String, dynamic>?;
      if (changeAction != null) {
        final eventContext = widget.context.createChildContext(
          variables: {
            'event': {
              'value': newValue,
              'type': 'change',
            },
          },
        );
        eventContext.handleAction(changeAction);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final factory = widget.context.renderer.widgetRegistry.get('TextField')
        as TextFieldWidgetFactory;
    final properties = factory.extractProperties(widget.definition);

    // Create a modified definition without change action (handled by debouncer)
    final modifiedDefinition = Map<String, dynamic>.from(widget.definition);
    final modifiedProperties = Map<String, dynamic>.from(properties);
    modifiedProperties.remove('change'); // Remove change action as we handle it
    modifiedProperties['value'] = _lastValue; // Use current value

    // Build text field without debouncing
    final textField =
        factory._buildTextField(modifiedDefinition, widget.context);

    // If it's wrapped in Focus, we need to intercept the TextField
    if (textField is Focus) {
      final focusChild = (textField).child;
      if (focusChild is TextField) {
        return Focus(
          onFocusChange: (textField).onFocusChange,
          child: TextField(
            controller: _controller,
            onChanged: _handleChange,
            style: focusChild.style,
            decoration: focusChild.decoration,
            obscureText: focusChild.obscureText,
            enabled: focusChild.enabled,
            readOnly: focusChild.readOnly,
            maxLines: focusChild.maxLines,
            maxLength: focusChild.maxLength,
            keyboardType: focusChild.keyboardType,
            textInputAction: focusChild.textInputAction,
            onSubmitted: focusChild.onSubmitted,
          ),
        );
      }
    }

    // If it's a direct TextField, replace onChanged
    if (textField is TextField) {
      return TextField(
        controller: _controller,
        onChanged: _handleChange,
        style: textField.style,
        decoration: textField.decoration,
        obscureText: textField.obscureText,
        enabled: textField.enabled,
        readOnly: textField.readOnly,
        maxLines: textField.maxLines,
        maxLength: textField.maxLength,
        keyboardType: textField.keyboardType,
        textInputAction: textField.textInputAction,
        onSubmitted: textField.onSubmitted,
      );
    }

    return textField;
  }
}
