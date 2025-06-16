import 'package:flutter/material.dart';
import '../widget_factory.dart';
import '../../renderer/render_context.dart';

/// Factory for creating DragTarget widgets
class DragTargetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    // Get builder definition
    final builderDef = definition['builder'];
    if (builderDef == null) {
      throw Exception('DragTarget requires a builder property');
    }
    
    // Get event handlers
    final onWillAccept = definition['onWillAccept'];
    final onAccept = definition['onAccept'];
    final onLeave = definition['onLeave'];
    final onMove = definition['onMove'];
    
    return DragTarget<Object>(
      builder: (BuildContext dragContext, List<Object?> candidateData, List<dynamic> rejectedData) {
        // For now, just render the builder without special context
        // TODO: Add support for drag context variables
        return context.renderer.renderWidget(builderDef, context);
      },
      onWillAcceptWithDetails: (details) {
        if (onWillAccept != null) {
          // TODO: Pass drag data to action
          context.actionHandler.execute(onWillAccept, context);
          return true;
        }
        return true;
      },
      onAcceptWithDetails: (details) {
        if (onAccept != null) {
          // TODO: Pass drag data to action
          context.actionHandler.execute(onAccept, context);
        }
      },
      onLeave: (data) {
        if (onLeave != null) {
          context.actionHandler.execute(onLeave, context);
        }
      },
      onMove: (details) {
        if (onMove != null) {
          context.actionHandler.execute(onMove, context);
        }
      },
    );
  }
}