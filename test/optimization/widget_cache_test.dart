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

import 'package:flutter_mcp_ui_runtime/src/runtime/default_widgets.dart';

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

    test('a fresh entry survives a sweep', () {
      const definition = {
        'type': 'Text',
        'text': 'Test',
      };

      final contextData = {'state': 'test'};
      const widget = Text('Test');

      cache.put(definition, contextData, widget);
      expect(cache.get(definition, contextData), isNotNull);

      cache.clearExpired();

      expect(cache.get(definition, contextData), isNotNull,
          reason: 'a sweep that takes fresh entries with it turns the cache '
              'into a cost with no benefit');
    });

    test('an entry past its age is swept, and a read no longer answers it', () {
      const definition = {'type': 'Text', 'text': 'Stale'};
      final contextData = {'state': 'test'};
      const widget = Text('Stale');

      final previousAge = WidgetCache.maxAge;
      addTearDown(() => WidgetCache.maxAge = previousAge);
      // Thirty minutes is the shipped age; the only way to see this path is to
      // shorten it.
      WidgetCache.maxAge = Duration.zero;

      cache.put(definition, contextData, widget);

      expect(cache.get(definition, contextData), isNull,
          reason: 'a read past the age must not answer with the stale widget '
              '— that is a screen showing data that has already changed');

      cache.put(definition, contextData, widget);
      cache.clearExpired();
      expect(cache.getStatistics()['size'], 0,
          reason: 'and the sweep has to actually remove it, or the cache '
              'grows for the life of the process');
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
      // A renderer clears ITS OWN cache, not the process-wide singleton.
      // A cached widget carries closures over the RenderContext that built it,
      // so each renderer keeps its own map (`WidgetCache.isolated`) — sharing
      // one handed a second document a widget wired to the first document's
      // state manager.
      const definition = {
        'type': 'Text',
        'text': 'Clear Test',
      };

      renderer.renderWidget(definition, context);
      expect(renderer.getCacheStatistics()['size'], equals(1));

      renderer.clearCache();
      expect(renderer.getCacheStatistics()['size'], equals(0));

      // And the singleton is untouched by a renderer's own clearing.
      const other = Text('held by the singleton');
      cache.put(definition, null, other);
      renderer.clearCache();
      expect(cache.getStatistics()['size'], equals(1));
      cache.clear();
    });

    test('should control cache enabled state through renderer', () {
      expect(cache.enabled, isTrue);

      renderer.setCacheEnabled(false);
      expect(cache.enabled, isFalse);

      renderer.setCacheEnabled(true);
      expect(cache.enabled, isTrue);
    });
  });

  group('two documents rendering the same widget', () {
    // The cache used to be one process-wide map, and a cached widget is not a
    // pure function of its definition: the closures inside it hold the
    // RenderContext that built it. So the SECOND document to render an
    // identical widget was handed the FIRST document's widget, and its
    // `binding` writes landed in the first document's state — with nothing on
    // screen to say so. Each renderer now owns its cache.
    RenderContext contextWithOwnRenderer(StateManager stateManager) {
      final registry = WidgetRegistry();
      DefaultWidgets.registerAll(registry);
      final bindingEngine = BindingEngine();
      final actionHandler = ActionHandler();
      return RenderContext(
        renderer: Renderer(
          widgetRegistry: registry,
          bindingEngine: bindingEngine,
          actionHandler: actionHandler,
          stateManager: stateManager,
        ),
        stateManager: stateManager,
        bindingEngine: bindingEngine,
        actionHandler: actionHandler,
        themeManager: ThemeManager.instance,
      );
    }

    testWidgets('each keeps its own state', (tester) async {
      const definition = {
        'type': 'combobox',
        'binding': 'choice',
        'options': ['Apple', 'Banana'],
      };

      final firstState = StateManager()..initialize(<String, dynamic>{});
      final firstContext = contextWithOwnRenderer(firstState);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: firstContext.renderer.renderWidget(definition, firstContext),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Apple');
      await tester.pumpAndSettle();
      expect(firstState.get('choice'), 'Apple');

      final secondState = StateManager()..initialize(<String, dynamic>{});
      final secondContext = contextWithOwnRenderer(secondState);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: secondContext.renderer.renderWidget(definition, secondContext),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Banana');
      await tester.pumpAndSettle();

      expect(secondState.get('choice'), 'Banana',
          reason: 'the second document has to receive its own input');
      expect(firstState.get('choice'), 'Apple',
          reason: 'and the first must not be written to by a document it has '
              'never heard of');
    });
  });
}
