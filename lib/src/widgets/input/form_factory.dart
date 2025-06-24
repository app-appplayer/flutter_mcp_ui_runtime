import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../../renderer/render_context.dart';

/// Factory for form widget
class FormWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    final children = definition['children'] as List<dynamic>? ?? [];
    final actions = definition['actions'] as Map<String, dynamic>?;
    
    // MCP UI DSL v1.0 spec
    final submitAction = properties['submit'] as Map<String, dynamic>? ?? 
                        actions?['submit'] as Map<String, dynamic>?;
    
    // Create a unique form key for this form
    final formKey = GlobalKey<FormState>();
    
    // Store form key in context for validation
    context.setLocal('_formKey', formKey);
    
    // Store submit action in context for submit buttons
    if (submitAction != null) {
      context.setLocal('_formSubmitAction', submitAction);
    }
    
    Widget form = Form(
      key: formKey,
      autovalidateMode: _resolveAutovalidateMode(properties['autovalidateMode']),
      onChanged: actions?['onChange'] != null
          ? () => context.handleAction(actions!['onChange'])
          : null,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children
              .map((child) => context.buildWidget(child as Map<String, dynamic>))
              .toList(),
        ),
      ),
    );
    
    // Handle onSubmit action
    if (actions?['onSubmit'] != null) {
      form = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: form),
          ElevatedButton(
            onPressed: () {
              final formState = formKey.currentState;
              if (formState != null && formState.validate()) {
                formState.save();
                context.handleAction(actions!['onSubmit']);
              }
            },
            child: Text(properties['submitLabel'] ?? 'Submit'),
          ),
        ],
      );
    }
    
    return form;
  }
  
  AutovalidateMode _resolveAutovalidateMode(String? mode) {
    switch (mode) {
      case 'always':
        return AutovalidateMode.always;
      case 'onUserInteraction':
        return AutovalidateMode.onUserInteraction;
      case 'disabled':
        return AutovalidateMode.disabled;
      default:
        return AutovalidateMode.disabled;
    }
  }
}