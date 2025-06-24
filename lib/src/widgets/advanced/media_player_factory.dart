import 'package:flutter/material.dart';
import '../../renderer/render_context.dart';
import '../widget_factory.dart';

/// Factory for Media Player widgets (Advanced conformance level)
/// This is a placeholder implementation that displays a message
/// Real implementation would integrate with a media player library
class MediaPlayerWidgetFactory extends WidgetFactory {
  @override
  Widget build(Map<String, dynamic> definition, RenderContext context) {
    final properties = extractProperties(definition);
    
    // Extract media player properties
    final source = context.resolve<String?>(properties['source']);
    final mediaType = context.resolve<String>(properties['mediaType'] ?? 'video');
    final autoplay = context.resolve<bool>(properties['autoplay'] ?? false);
    final controls = context.resolve<bool>(properties['controls'] ?? true);
    final loop = context.resolve<bool>(properties['loop'] ?? false);
    final width = context.resolve<double?>(properties['width']);
    final height = context.resolve<double?>(properties['height']) ?? 300.0;
    
    // Build placeholder media player widget
    Widget player = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  mediaType == 'audio' ? Icons.audiotrack : Icons.videocam,
                  size: 48,
                  color: Colors.white54,
                ),
                const SizedBox(height: 16),
                Text(
                  '${mediaType[0].toUpperCase()}${mediaType.substring(1)} Player',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (source != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      source,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Control bar
          if (controls)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        autoplay ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                      onPressed: () {},
                    ),
                    if (mediaType == 'video') ...[
                      IconButton(
                        icon: const Icon(
                          Icons.fullscreen,
                          color: Colors.white,
                        ),
                        onPressed: () {},
                      ),
                    ],
                  ],
                ),
              ),
            ),
          // Status indicators
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: [
                if (autoplay)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Autoplay',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (loop) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Loop',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    
    return applyCommonWrappers(player, properties, context);
  }
}