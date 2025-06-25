import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_runtime/src/optimization/widget_cache.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/renderer.dart';
import 'package:flutter_mcp_ui_runtime/src/renderer/render_context.dart';
import 'package:flutter_mcp_ui_runtime/src/state/state_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/theme/theme_manager.dart';
import 'package:flutter_mcp_ui_runtime/src/actions/action_handler.dart';
import 'package:flutter_mcp_ui_runtime/src/binding/binding_engine.dart';
import 'package:flutter_mcp_ui_runtime/src/runtime/widget_registry.dart';
import 'package:flutter_mcp_ui_runtime/src/widgets/display/text_factory.dart';
import 'package:flutter_mcp_ui_runtime/src/widgets/layout/container_factory.dart';

void main() {
  group('Widget Cache Tests', () {
    late WidgetCache cache;
    late Renderer renderer;
    late StateManager stateManager;
    late ThemeManager themeManager;
    late ActionHandler actionHandler;
    late BindingEngine bindingEngine;
    late WidgetRegistry widgetRegistry;
    late RenderContext context;

    setUp(() {
      cache = WidgetCache.instance;
      cache.clear();
      cache.enable();

      stateManager = StateManager();
      themeManager = ThemeManager();
      actionHandler = ActionHandler();
      bindingEngine = BindingEngine();
      widgetRegistry = WidgetRegistry();
      
      // Register some basic widget factories
      widgetRegistry.register('Text', TextWidgetFactory());
      widgetRegistry.register('Container', ContainerWidgetFactory());

      renderer = Renderer(
        widgetRegistry: widgetRegistry,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        stateManager: stateManager,
      );

      context = RenderContext(
        renderer: renderer,
        stateManager: stateManager,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        themeManager: themeManager,
      );
    });

    tearDown(() {
      cache.clear();
    });

    test('should cache and retrieve widgets correctly', () {
      const definition = {
        'type': 'Text',
        'text': 'Hello World',
      };

      final contextData = {'state': 'test'};
      const widget = Text('Hello World');

      // Cache the widget
      cache.put(definition, contextData, widget);

      // Retrieve from cache
      final cachedWidget = cache.get(definition, contextData);
      expect(cachedWidget, isNotNull);
      expect(identical(cachedWidget, widget), isTrue);
    });

    test('should generate different keys for different definitions', () {
      const definition1 = {
        'type': 'Text',
        'text': 'Hello',
      };

      const definition2 = {
        'type': 'Text', 
        'text': 'World',
      };

      final contextData = {'state': 'test'};
      const widget1 = Text('Hello');
      const widget2 = Text('World');

      cache.put(definition1, contextData, widget1);
      cache.put(definition2, contextData, widget2);

      final cached1 = cache.get(definition1, contextData);
      final cached2 = cache.get(definition2, contextData);

      expect(identical(cached1, widget1), isTrue);
      expect(identical(cached2, widget2), isTrue);
      expect(identical(cached1, cached2), isFalse);
    });

    test('should handle cache expiration', () {
      const definition = {
        'type': 'Text',
        'text': 'Test',
      };

      final contextData = {'state': 'test'};
      const widget = Text('Test');

      cache.put(definition, contextData, widget);
      
      // Should be cached initially
      expect(cache.get(definition, contextData), isNotNull);

      // Clear expired entries (in real scenario this would happen after 30 minutes)
      cache.clearExpired();
      
      // Should still be cached since it's not expired yet
      expect(cache.get(definition, contextData), isNotNull);
    });

    test('should evict oldest entries when cache is full', () {
      // Fill cache to maximum capacity + 1
      for (int i = 0; i <= 100; i++) {
        final definition = {
          'type': 'Text',
          'text': 'Text $i',
        };
        final widget = Text('Text $i');
        cache.put(definition, null, widget);
      }

      // Cache should have evicted the oldest entry
      expect(cache.getStatistics()['size'], equals(100));
    });

    test('should track cache hits and statistics', () {
      const definition = {
        'type': 'Text',
        'text': 'Stats Test',
      };

      const widget = Text('Stats Test');
      cache.put(definition, null, widget);

      // First hit
      cache.get(definition, null);
      // Second hit
      cache.get(definition, null);
      // Third hit
      cache.get(definition, null);

      final stats = cache.getStatistics();
      expect(stats['size'], equals(1));
      expect(stats['totalHits'], equals(3));
    });

    test('should enable and disable caching', () {
      const definition = {
        'type': 'Text',
        'text': 'Enable Test',
      };

      const widget = Text('Enable Test');

      // Disable cache
      cache.disable();
      expect(cache.enabled, isFalse);

      // Try to cache (should not work)
      cache.put(definition, null, widget);
      expect(cache.getStatistics()['size'], equals(0));

      // Enable cache
      cache.enable();
      expect(cache.enabled, isTrue);

      // Now caching should work
      cache.put(definition, null, widget);
      expect(cache.getStatistics()['size'], equals(1));
    });

    testWidgets('should integrate with renderer for caching', (WidgetTester tester) async {
      const definition = {
        'type': 'Text',
        'text': 'Renderer Cache Test',
      };

      // First render - should cache the widget
      final widget1 = renderer.renderWidget(definition, context);
      expect(widget1, isA<Widget>());

      // Second render - should return cached widget
      final widget2 = renderer.renderWidget(definition, context);
      expect(widget2, isA<Widget>());

      // Check cache statistics
      final stats = renderer.getCacheStatistics();
      expect(stats['size'], greaterThan(0));
    });

    test('should not cache widgets with event handlers', () {
      final definition = {
        'type': 'Container',
        'onTap': {
          'type': 'setState',
          'params': {'clicked': true}
        },
      };

      final widget = renderer.renderWidget(definition, context);
      expect(widget, isA<Widget>());

      // Check that nothing was cached
      final stats = renderer.getCacheStatistics();
      expect(stats['size'], equals(0));
    });

    test('should not cache non-cacheable widget types', () {
      final definition = {
        'type': 'TextField',
        'value': 'test',
      };

      // Register TextField factory for test
      widgetRegistry.register('TextField', TextWidgetFactory()); // Use TextWidgetFactory as placeholder

      final widget = renderer.renderWidget(definition, context);
      expect(widget, isA<Widget>());

      // Check that nothing was cached
      final stats = renderer.getCacheStatistics();
      expect(stats['size'], equals(0));
    });

    test('should clear cache on demand', () {
      const definition = {
        'type': 'Text',
        'text': 'Clear Test',
      };

      const widget = Text('Clear Test');
      cache.put(definition, null, widget);
      
      expect(cache.getStatistics()['size'], equals(1));

      renderer.clearCache();
      expect(cache.getStatistics()['size'], equals(0));
    });

    test('should control cache enabled state through renderer', () {
      expect(cache.enabled, isTrue);

      renderer.setCacheEnabled(false);
      expect(cache.enabled, isFalse);

      renderer.setCacheEnabled(true);
      expect(cache.enabled, isTrue);
    });
  });
}