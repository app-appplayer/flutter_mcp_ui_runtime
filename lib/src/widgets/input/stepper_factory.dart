import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for Stepper widgets
class StepperWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);

    // Extract properties
    final currentStep = properties['currentStep'] as int? ?? 0;
    final stepperType =
        _parseStepperType(properties['type']) ?? StepperType.vertical;
    final physics = _parseScrollPhysics(properties['physics']);
    final margin = parseEdgeInsets(properties['margin']);

    // Extract steps
    final stepsData = properties['steps'] as List<dynamic>? ?? [];
    final steps =
        stepsData.map((stepData) => _buildStep(stepData, context)).toList();

    // Extract action handlers
    final onStepTapped = properties['onStepTapped'] as Map<String, dynamic>?;
    final onStepContinue =
        properties['onStepContinue'] as Map<String, dynamic>?;
    final onStepCancel = properties['onStepCancel'] as Map<String, dynamic>?;

    Widget stepper = Stepper(
      currentStep: currentStep.clamp(0, steps.length - 1),
      type: stepperType,
      physics: physics,
      margin: margin,
      steps: steps,
      onStepTapped: onStepTapped != null
          ? (step) {
              final eventData = Map<String, dynamic>.from(onStepTapped);
              if (eventData['step'] == '{{event.step}}') {
                eventData['step'] = step;
              }
              context.actionHandler.execute(eventData, context);
            }
          : null,
      onStepContinue: onStepContinue != null
          ? () {
              context.actionHandler.execute(onStepContinue, context);
            }
          : null,
      onStepCancel: onStepCancel != null
          ? () {
              context.actionHandler.execute(onStepCancel, context);
            }
          : null,
    );

    return applyCommonWrappers(stepper, properties, context);
  }

  Step _buildStep(dynamic stepData, RenderContext context) {
    if (stepData is Map<String, dynamic>) {
      final title = stepData['title'] != null
          ? context.buildWidget(stepData['title'] as Map<String, dynamic>)
          : Text(
              context.resolve<String>(stepData['titleText']) as String? ?? '');

      final content = stepData['content'] != null
          ? context.buildWidget(stepData['content'] as Map<String, dynamic>)
          : Container();

      final subtitle = stepData['subtitle'] != null
          ? context.buildWidget(stepData['subtitle'] as Map<String, dynamic>)
          : null;

      final isActive = stepData['isActive'] as bool? ?? false;
      final state = _parseStepState(stepData['state']);

      return Step(
        title: title,
        content: content,
        subtitle: subtitle,
        isActive: isActive,
        state: state ?? StepState.indexed,
      );
    }

    return Step(
      title: const Text('Step'),
      content: Container(),
    );
  }

  StepperType? _parseStepperType(String? value) {
    switch (value) {
      case 'vertical':
        return StepperType.vertical;
      case 'horizontal':
        return StepperType.horizontal;
      default:
        return null;
    }
  }

  ScrollPhysics? _parseScrollPhysics(String? value) {
    switch (value) {
      case 'bouncing':
        return const BouncingScrollPhysics();
      case 'clamping':
        return const ClampingScrollPhysics();
      case 'never':
        return const NeverScrollableScrollPhysics();
      default:
        return null;
    }
  }

  StepState? _parseStepState(String? value) {
    switch (value) {
      case 'indexed':
        return StepState.indexed;
      case 'editing':
        return StepState.editing;
      case 'complete':
        return StepState.complete;
      case 'disabled':
        return StepState.disabled;
      case 'error':
        return StepState.error;
      default:
        return null;
    }
  }
}
