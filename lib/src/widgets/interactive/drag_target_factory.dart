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
      builder: (BuildContext dragContext, List<Object?> candidateData,
          List<dynamic> rejectedData) {
        // Create context with drag state variables
        final dragContext = context.createChildContext(
          variables: {
            'dragData': {
              'candidateData': candidateData,
              'rejectedData': rejectedData,
              'hasCandidates': candidateData.isNotEmpty,
            },
          },
        );
        return context.renderer.renderWidget(builderDef, dragContext);
      },
      onWillAcceptWithDetails: (details) {
        if (onWillAccept != null) {
          // Create context with drag data
          final eventContext = context.createChildContext(
            variables: {
              'event': {
                'data': details.data,
                'offset': {
                  'dx': details.offset.dx,
                  'dy': details.offset.dy,
                },
              },
            },
          );
          context.actionHandler.execute(onWillAccept, eventContext);
          return true;
        }
        return true;
      },
      onAcceptWithDetails: (details) {
        if (onAccept != null) {
          // Create context with drag data
          final eventContext = context.createChildContext(
            variables: {
              'event': {
                'data': details.data,
                'offset': {
                  'dx': details.offset.dx,
                  'dy': details.offset.dy,
                },
              },
            },
          );
          context.actionHandler.execute(onAccept, eventContext);
        }
      },
      onLeave: (data) {
        if (onLeave != null) {
          // Create context with leaving data
          final eventContext = context.createChildContext(
            variables: {
              'event': {
                'data': data,
              },
            },
          );
          context.actionHandler.execute(onLeave, eventContext);
        }
      },
      onMove: (details) {
        if (onMove != null) {
          // Create context with move details
          final eventContext = context.createChildContext(
            variables: {
              'event': {
                'data': details.data,
                'offset': {
                  'dx': details.offset.dx,
                  'dy': details.offset.dy,
                },
              },
            },
          );
          context.actionHandler.execute(onMove, eventContext);
        }
      },
    );
  }
}
