import 'package:flutter/material.dart';

import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for Image widgets
class ImageWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    
    // Extract properties
    final src = context.resolve<String>(properties['src'] ?? '');
    final width = properties['width']?.toDouble();
    final height = properties['height']?.toDouble();
    final fit = _parseBoxFit(properties['fit']);
    final alignment = _parseAlignment(properties['alignment']);
    final placeholder = properties['placeholder'] as String?;
    final errorWidget = properties['errorWidget'] as String?;
    
    Widget image;
    
    if (src.isEmpty) {
      // No source provided
      image = _buildPlaceholder(placeholder, width, height);
    } else if (src.startsWith('http://') || src.startsWith('https://')) {
      // Network image
      image = Image.network(
        src,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        loadingBuilder: placeholder != null ? (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholder(placeholder, width, height);
        } : null,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorWidget(errorWidget, width, height);
        },
      );
    } else if (src.startsWith('assets/')) {
      // Asset image
      image = Image.asset(
        src,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorWidget(errorWidget, width, height);
        },
      );
    } else if (src.startsWith('data:image')) {
      // Base64 image (would need additional implementation)
      image = _buildPlaceholder('Base64 not supported', width, height);
    } else {
      // File path or other
      image = _buildErrorWidget('Invalid image source', width, height);
    }
    
    return applyCommonWrappers(image, properties, context);
  }

  Widget _buildPlaceholder(String? text, double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: Center(
        child: text != null 
            ? Text(text, style: TextStyle(color: Colors.grey[600]))
            : Icon(Icons.image, color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildErrorWidget(String? text, double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Colors.red[100],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.red),
            if (text != null) 
              Text(text, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  BoxFit _parseBoxFit(String? value) {
    switch (value) {
      case 'fill':
        return BoxFit.fill;
      case 'contain':
        return BoxFit.contain;
      case 'cover':
        return BoxFit.cover;
      case 'fitWidth':
        return BoxFit.fitWidth;
      case 'fitHeight':
        return BoxFit.fitHeight;
      case 'none':
        return BoxFit.none;
      case 'scaleDown':
        return BoxFit.scaleDown;
      default:
        return BoxFit.contain;
    }
  }

  AlignmentGeometry _parseAlignment(String? value) {
    switch (value) {
      case 'topLeft':
        return Alignment.topLeft;
      case 'topCenter':
        return Alignment.topCenter;
      case 'topRight':
        return Alignment.topRight;
      case 'centerLeft':
        return Alignment.centerLeft;
      case 'center':
        return Alignment.center;
      case 'centerRight':
        return Alignment.centerRight;
      case 'bottomLeft':
        return Alignment.bottomLeft;
      case 'bottomCenter':
        return Alignment.bottomCenter;
      case 'bottomRight':
        return Alignment.bottomRight;
      default:
        return Alignment.center;
    }
  }
}